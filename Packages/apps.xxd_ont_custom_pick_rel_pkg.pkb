--
-- XXD_ONT_CUSTOM_PICK_REL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CUSTOM_PICK_REL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CUSTOM_PICK_REL_PKG
    * Design       : This package is used for Deckers Custom Pick Release Process
    * Notes        :
    * Modification :
    -- =======================================================================================
    -- Date         Version#   Name                    Comments
    -- =======================================================================================
    -- 29-Apr-2019  1.0        Viswanathan Pandian     Initial Version for Direct Ship Phase 2
    -- 11-Sep-2019  1.1        Viswanathan Pandian     Updated for CCR0008125
    ******************************************************************************************/
    gn_org_id               NUMBER := fnd_global.org_id;
    gn_user_id              NUMBER := fnd_global.user_id;
    gn_login_id             NUMBER := fnd_global.login_id;
    gn_request_id           NUMBER := fnd_global.conc_request_id;
    gn_application_id       NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id    NUMBER := fnd_profile.VALUE ('RESP_ID');
    gc_debug_enable         VARCHAR2 (1);
    gc_pick_confirm_flag    VARCHAR2 (1);
    gc_pick_subinventory    VARCHAR2 (100);
    gc_stage_subinventory   VARCHAR2 (100);            -- Added for CCR0008125

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
    -- This procedure will be used to perform credit check
    -- ======================================================================================
    PROCEDURE credit_check (p_header_id IN oe_order_headers_all.header_id%TYPE, x_return_status OUT NOCOPY VARCHAR2, x_return_msg OUT NOCOPY VARCHAR2)
    AS
        CURSOR get_calling_action IS
            SELECT (CASE
                        WHEN otta.entry_credit_check_rule_id IS NOT NULL
                        THEN
                            'BOOKING'
                        WHEN otta.picking_credit_check_rule_id IS NOT NULL
                        THEN
                            'PICKING'
                        WHEN otta.packing_credit_check_rule_id IS NOT NULL
                        THEN
                            'PACKING'
                        WHEN otta.shipping_credit_check_rule_id IS NOT NULL
                        THEN
                            'SHIPPING'
                        ELSE
                            'BOOKING'
                    END) calling_action
              FROM oe_order_headers_all ooha, oe_transaction_types_all otta
             WHERE     ooha.order_type_id = otta.transaction_type_id
                   AND header_id = p_header_id;

        lc_return_status       VARCHAR2 (1);
        lc_calling_action      VARCHAR2 (50);
        lc_msg_data            VARCHAR2 (4000);
        lc_return_msg          VARCHAR2 (4000);
        ln_msg_count           NUMBER;
        ln_msg_index           NUMBER;
        ln_credit_hold_count   NUMBER := 0;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        debug_msg ('Start CREDIT_CHECK');

        OPEN get_calling_action;

        FETCH get_calling_action INTO lc_calling_action;

        lc_calling_action   := NVL (lc_calling_action, 'BOOKING');

        CLOSE get_calling_action;

        SELECT COUNT (1)
          INTO ln_credit_hold_count
          FROM oe_hold_definitions ohd, oe_hold_sources_all ohsa, oe_order_holds_all ooha
         WHERE     ooha.header_id = p_header_id
               AND ohsa.hold_source_id = ooha.hold_source_id
               AND ohd.hold_id = ohsa.hold_id
               AND ooha.hold_release_id IS NULL
               AND ohd.name = 'Credit Check Failure';

        IF ln_credit_hold_count > 0
        THEN
            -- Hold already available
            debug_msg ('Order already on Credit Check Failure Hold');
            debug_msg ('End CREDIT_CHECK');
            lc_return_status   := 'E';   -- Modifed to E from S for CCR0008125
        ELSE
            oe_verify_payment_pub.verify_payment (
                p_header_id        => p_header_id,
                p_calling_action   => lc_calling_action,
                p_msg_count        => ln_msg_count,
                p_msg_data         => lc_msg_data,
                p_return_status    => lc_return_status);

            debug_msg ('Credit Check API Status - ' || lc_return_status);

            IF (lc_return_status <> fnd_api.g_ret_sts_success)
            THEN
                lc_return_status   := 'E';

                FOR j IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => j, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index);
                    lc_return_msg   :=
                        lc_return_msg || ln_msg_index || '-' || lc_msg_data;
                END LOOP;

                lc_return_msg      :=
                    NVL (lc_return_msg, 'Credit Check Failure');
                debug_msg ('Credit Check API Error - ' || lc_return_msg);
            ELSE
                COMMIT;             -- Save the hold created if API is success

                SELECT COUNT (1)
                  INTO ln_credit_hold_count
                  FROM oe_hold_definitions ohd, oe_hold_sources_all ohsa, oe_order_holds_all ooha
                 WHERE     ooha.header_id = p_header_id
                       AND ohsa.hold_source_id = ooha.hold_source_id
                       AND ohd.hold_id = ohsa.hold_id
                       AND ooha.hold_release_id IS NULL
                       AND ohd.name = 'Credit Check Failure';

                IF ln_credit_hold_count > 0
                THEN
                    lc_return_status   := 'E';
                    lc_return_msg      := 'Credit Check Failure';
                ELSE
                    lc_return_status   := 'S';
                    lc_return_msg      := NULL;
                END IF;
            END IF;
        END IF;

        x_return_status     := lc_return_status;
        x_return_msg        := lc_return_msg;
        debug_msg ('End CREDIT_CHECK');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            x_return_msg      := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CREDIT_CHECK = ' || x_return_msg);
            debug_msg ('End CREDIT_CHECK');
    END credit_check;

    -- ======================================================================================
    -- This procedure will be used to create/assign delivery
    -- ======================================================================================
    PROCEDURE autocreate_delivery (
        p_line_rows       IN            wsh_util_core.id_tab_type,
        x_return_status      OUT NOCOPY VARCHAR2,
        x_return_msg         OUT NOCOPY VARCHAR2,
        x_del_rows           OUT NOCOPY wsh_util_core.id_tab_type)
    AS
        l_line_rows        wsh_util_core.id_tab_type;
        lx_del_rows        wsh_util_core.id_tab_type;
        lc_return_status   VARCHAR2 (1);
        lc_msg_data        VARCHAR2 (4000);
        lc_error_message   VARCHAR2 (4000);
        ln_msg_count       NUMBER;
        ln_msg_index_out   NUMBER;
    BEGIN
        l_line_rows       := p_line_rows;
        debug_msg ('Start AUTOCREATE_DELIVERY');
        wsh_delivery_details_pub.autocreate_deliveries (
            p_api_version_number   => 1.0,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => fnd_api.g_false,
            x_return_status        => lc_return_status,
            x_msg_count            => ln_msg_count,
            x_msg_data             => lc_msg_data,
            p_line_rows            => l_line_rows,
            x_del_rows             => lx_del_rows);
        debug_msg ('Auto Create Delivery Status = ' || lc_return_status);

        IF lc_return_status <> fnd_api.g_ret_sts_success
        THEN
            -- Retrieve messages
            FOR i IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                 , p_msg_index_out => ln_msg_index_out);
                lc_error_message   :=
                    SUBSTR (lc_error_message || lc_msg_data || CHR (13),
                            1,
                            4000);
            END LOOP;

            debug_msg ('Auto Create Delivery Error = ' || lc_error_message);
        ELSE
            FOR i IN 1 .. lx_del_rows.COUNT
            LOOP
                debug_msg ('Delivery ID = ' || lx_del_rows (i));
            END LOOP;

            x_del_rows   := lx_del_rows;
        END IF;

        x_return_status   := lc_return_status;
        x_return_msg      := lc_error_message;
        debug_msg ('End AUTOCREATE_DELIVERY');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            x_return_msg      := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in AUTOCREATE_DELIVERY = ' || x_return_msg);
            debug_msg ('End AUTOCREATE_DELIVERY');
    END autocreate_delivery;

    -- ======================================================================================
    -- This procedure will be used to create/release batch
    -- ======================================================================================
    PROCEDURE create_release_batch (p_organization_id IN mtl_parameters.organization_id%TYPE, p_line_rows IN wsh_util_core.id_tab_type, x_return_status OUT NOCOPY VARCHAR2
                                    , x_return_msg OUT NOCOPY VARCHAR2)
    AS
        l_batch_rec        wsh_picking_batches_pub.batch_info_rec;
        l_line_rows        wsh_util_core.id_tab_type;
        lc_return_status   VARCHAR2 (1);
        lc_msg_data        VARCHAR2 (4000);
        lc_error_message   VARCHAR2 (4000);
        lc_phase           VARCHAR2 (250) := NULL;
        lc_status          VARCHAR2 (250) := NULL;
        lc_dev_phase       VARCHAR2 (250) := NULL;
        lc_dev_status      VARCHAR2 (250) := NULL;
        lc_message         VARCHAR2 (250) := NULL;
        ln_batch_prefix    VARCHAR2 (10);
        ln_msg_count       NUMBER;
        ln_new_batch_id    NUMBER;
        ln_request_id      NUMBER;
        ln_count           NUMBER := 0;
        lb_req_status      BOOLEAN;
    BEGIN
        debug_msg ('Start CREATE_RELEASE_BATCH');

        l_line_rows       := p_line_rows;

        FOR ln_index IN 1 .. l_line_rows.COUNT
        LOOP
            debug_msg ('Delivery ID ' || l_line_rows (ln_index));
            debug_msg ('Start Create Batch');
            debug_msg (
                'Pick Confirm Flag is set as ' || gc_pick_confirm_flag);
            l_batch_rec.delivery_id                  := l_line_rows (ln_index);
            l_batch_rec.organization_id              := p_organization_id;
            l_batch_rec.auto_pick_confirm_flag       := gc_pick_confirm_flag;
            l_batch_rec.autodetail_pr_flag           := 'Y';
            l_batch_rec.autocreate_delivery_flag     := 'N';
            l_batch_rec.backorders_only_flag         := 'I';
            l_batch_rec.allocation_method            := 'I';
            l_batch_rec.autopack_flag                := 'N';
            l_batch_rec.append_flag                  := 'N';
            l_batch_rec.pick_from_subinventory       := gc_pick_subinventory;
            l_batch_rec.default_stage_subinventory   := gc_stage_subinventory; -- Added for CCR0008125

            wsh_picking_batches_pub.create_batch (
                p_api_version     => 1.0,
                p_init_msg_list   => fnd_api.g_true,
                p_commit          => fnd_api.g_false,
                x_return_status   => lc_return_status,
                x_msg_count       => ln_msg_count,
                x_msg_data        => lc_msg_data,
                p_batch_rec       => l_batch_rec,
                x_batch_id        => ln_new_batch_id);
            debug_msg ('Create Batch Status = ' || lc_return_status);

            IF lc_return_status <> 'S'
            THEN
                IF ln_msg_count = 1
                THEN
                    lc_error_message   :=
                        'Create Batch Error = ' || lc_msg_data;
                    debug_msg (lc_error_message);
                ELSIF ln_msg_count > 1
                THEN
                    LOOP
                        ln_count   := ln_count + 1;
                        lc_msg_data   :=
                            fnd_msg_pub.get (fnd_msg_pub.g_next,
                                             fnd_api.g_false);

                        IF lc_msg_data IS NULL
                        THEN
                            EXIT;
                        END IF;

                        lc_error_message   :=
                               'Create Batch Error '
                            || ln_count
                            || '-'
                            || lc_msg_data;
                        debug_msg (lc_error_message);
                    END LOOP;
                END IF;
            ELSE
                debug_msg (
                       'Pick Release Batch Created Successfully = '
                    || ln_new_batch_id);
                debug_msg ('Start Release Batch');
                -- Release the batch created above
                wsh_picking_batches_pub.release_batch (
                    p_api_version     => 1.0,
                    p_init_msg_list   => fnd_api.g_true,
                    p_commit          => fnd_api.g_true,
                    x_return_status   => lc_return_status,
                    x_msg_count       => ln_msg_count,
                    x_msg_data        => lc_msg_data,
                    p_batch_id        => ln_new_batch_id,
                    p_log_level       => 1,
                    p_release_mode    => 'CONCURRENT',
                    x_request_id      => ln_request_id);
                debug_msg ('Release Batch Status = ' || lc_return_status);
                debug_msg (
                       'Pick Selection List Generation Request ID = '
                    || ln_request_id);

                IF ln_request_id <> 0
                THEN
                    LOOP
                        lb_req_status   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_request_id,
                                interval     => 10,
                                max_wait     => 0,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);
                        EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                                  OR UPPER (lc_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;
                ELSE
                    IF ln_msg_count = 1
                    THEN
                        lc_error_message   :=
                            'Release Batch Error = ' || lc_msg_data;
                        debug_msg (lc_error_message);
                    ELSIF ln_msg_count > 1
                    THEN
                        LOOP
                            ln_count   := ln_count + 1;
                            lc_msg_data   :=
                                fnd_msg_pub.get (fnd_msg_pub.g_next,
                                                 fnd_api.g_false);

                            IF lc_msg_data IS NULL
                            THEN
                                EXIT;
                            END IF;

                            lc_error_message   :=
                                   'Release Batch Error '
                                || ln_count
                                || '-'
                                || lc_msg_data;
                            debug_msg (lc_error_message);
                        END LOOP;
                    END IF;
                END IF;                                      -- Release Status
            END IF;                                            -- Batch Status
        END LOOP;

        x_return_status   := lc_return_status;
        x_return_msg      := lc_error_message;
        debug_msg ('End CREATE_RELEASE_BATCH');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            x_return_msg      := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CREATE_RELEASE_BATCH = ' || x_return_msg);
            debug_msg ('End CREATE_RELEASE_BATCH');
    END create_release_batch;

    -- ======================================================================================
    -- This procedure will call create/assign delivery and pick release/confirm
    -- ======================================================================================
    PROCEDURE pick_release (
        p_order_type     IN VARCHAR2,
        p_so_header_id   IN oe_order_headers_all.header_id%TYPE)
    AS
        CURSOR get_details_c IS
              SELECT attribute8 asn_number, source_header_id, organization_id,
                     customer_id, fob_code, freight_terms_code,
                     ship_to_location_id, ship_method_code
                FROM wsh_delivery_details
               WHERE     source_code = 'OE'
                     AND released_status = 'R'         -- Added for CCR0008125
                     AND source_header_id = p_so_header_id
                     AND p_order_type = 'DIRECT_SHIP_US'
                     AND attribute8 IS NOT NULL
            GROUP BY attribute8, source_header_id, organization_id,
                     customer_id, fob_code, freight_terms_code,
                     ship_to_location_id, ship_method_code
            UNION
              SELECT NULL asn_number, source_header_id, organization_id,
                     customer_id, fob_code, freight_terms_code,
                     ship_to_location_id, ship_method_code
                FROM wsh_delivery_details
               WHERE     source_code = 'OE'
                     AND released_status = 'R'         -- Added for CCR0008125
                     AND source_header_id = p_so_header_id
                     AND p_order_type = 'SPECIAL_VAS_US'
            GROUP BY source_header_id, organization_id, customer_id,
                     fob_code, freight_terms_code, ship_to_location_id,
                     ship_method_code;

        l_line_rows        wsh_util_core.id_tab_type;
        l_del_rows         wsh_util_core.id_tab_type;
        lc_return_status   VARCHAR2 (1);
        lc_return_msg      VARCHAR2 (4000);
        lc_error_message   VARCHAR2 (4000);
        ln_index           NUMBER := 0;
    BEGIN
        debug_msg ('Start PICK_RELEASE');
        init;
        debug_msg (RPAD ('=', 75, '='));

        -- Create Separate Delivery by ASN, Order and Delivery Setup
        FOR details_rec IN get_details_c
        LOOP
            debug_msg ('SO Header ID = ' || details_rec.source_header_id);
            ln_index   := 0;
            l_line_rows.delete;

            -- Collect all Delivery Details
            FOR j
                IN (SELECT wdd.delivery_detail_id
                      FROM wsh_delivery_details wdd
                     WHERE     wdd.source_header_id =
                               details_rec.source_header_id
                           AND wdd.source_code = 'OE'
                           AND released_status = 'R'   -- Added for CCR0008125
                           AND wdd.organization_id =
                               details_rec.organization_id
                           AND wdd.customer_id = details_rec.customer_id
                           AND wdd.fob_code = details_rec.fob_code
                           AND wdd.freight_terms_code =
                               details_rec.freight_terms_code
                           AND wdd.ship_to_location_id =
                               details_rec.ship_to_location_id
                           AND wdd.ship_method_code =
                               details_rec.ship_method_code
                           AND ((details_rec.asn_number IS NOT NULL AND wdd.attribute8 = details_rec.asn_number) OR (details_rec.asn_number IS NULL AND 1 = 1))
                           -- Ignore if Delivery Created and Assigned
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM wsh_delivery_assignments wda
                                     WHERE     wda.delivery_detail_id =
                                               wdd.delivery_detail_id
                                           AND wda.delivery_id IS NOT NULL))
            LOOP
                ln_index                 := ln_index + 1;
                l_line_rows (ln_index)   := j.delivery_detail_id;
            END LOOP;

            debug_msg ('Total Delivery Details Count = ' || ln_index);

            IF l_line_rows.COUNT > 0
            THEN
                -- Create and Assign Delivery
                autocreate_delivery (p_line_rows => l_line_rows, x_return_status => lc_return_status, x_return_msg => lc_return_msg
                                     , x_del_rows => l_del_rows);
                debug_msg (
                    'Autocreate Delivery Status = ' || lc_return_status);
                debug_msg ('Updating ASN in Delivery DFF');

                FOR i IN 1 .. l_del_rows.COUNT
                LOOP
                    UPDATE wsh_new_deliveries
                       SET attribute8   = details_rec.asn_number
                     WHERE delivery_id = l_del_rows (i);
                END LOOP;
            ELSE
                debug_msg ('No Deliveries to Create/Assign');
                lc_return_status   := 'S';
            END IF;

            IF lc_return_status = 'S' AND l_line_rows.COUNT > 0
            THEN
                COMMIT;
                debug_msg ('Successfully Delivery Created/Assigned');
                -- Create and Release Batch
                create_release_batch (p_organization_id => details_rec.organization_id, p_line_rows => l_del_rows, x_return_status => lc_return_status
                                      , x_return_msg => lc_return_msg);

                IF lc_return_status = 'S'
                THEN
                    COMMIT;
                    debug_msg ('Successfully Pick Released/Confirmed');
                ELSE
                    ROLLBACK;
                    lc_error_message   :=
                        SUBSTR (
                            'Create Release Batch Error ' || lc_return_msg,
                            1,
                            4000);
                    debug_msg (lc_error_message);
                END IF;
            ELSE
                ROLLBACK;
                lc_error_message   :=
                    SUBSTR ('Autocreate Delivery Error ' || lc_return_msg,
                            1,
                            4000);
                debug_msg (lc_error_message);
            END IF;

            UPDATE xxd_ont_shipment_details_t
               SET record_status = NVL (lc_return_status, 'S'), error_message = lc_return_msg
             WHERE     so_header_id = details_rec.source_header_id
                   AND ((details_rec.asn_number IS NOT NULL AND oracle_inbound_asn_number = details_rec.asn_number) OR (details_rec.asn_number IS NULL AND 1 = 1))
                   AND request_id = gn_request_id
                   AND record_status = 'N';

            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 75, '='));
        debug_msg ('End PICK_RELEASE');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in PICK_RELEASE = ' || lc_error_message);
            debug_msg ('End PICK_RELEASE');

            UPDATE xxd_ont_shipment_details_t
               SET record_status = 'E', error_message = lc_error_message
             WHERE     so_header_id = p_so_header_id
                   AND request_id = gn_request_id
                   AND record_status = 'N';
    END pick_release;

    -- ======================================================================================
    -- This procedure will select eligible records and spawn child program for processing
    -- ======================================================================================
    PROCEDURE pick_release_master (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_factory_invoice_num IN rcv_shipment_headers.packing_slip%TYPE, p_container_num IN rcv_shipment_lines.container_num%TYPE, p_order_header_id IN oe_order_headers_all.header_id%TYPE
                                   , p_partial_order_fulfill IN VARCHAR2, p_threads IN NUMBER, p_debug IN VARCHAR2)
    AS
        CURSOR get_details_c IS
            SELECT xxdo.xxd_ont_shipment_details_s.NEXTVAL
                       record_id,
                   flv.lookup_code
                       order_type,
                   ooha.org_id,
                   REGEXP_SUBSTR (rsh.shipment_num, '[^-]+', 1,
                                  1)
                       shipment_id,
                   rsh.packing_slip
                       factory_invoice_number,
                   (SELECT ds.asn_reference_no
                      FROM custom.do_shipments ds
                     WHERE ds.shipment_id = REGEXP_SUBSTR (rsh.shipment_num, '[^-]+', 1
                                                           , 1))
                       factory_asn_number,
                   REGEXP_SUBSTR (rsh.shipment_num, '[^-]+', 1,
                                  2)
                       container_id,
                   rsl.container_num
                       factory_container_number,
                   pha.po_header_id,
                   pha.segment1
                       po_number,
                   pla.po_line_id,
                   pla.line_num
                       po_line_number,
                   rsl.po_line_location_id,
                   rsl.line_num
                       po_shipment_number,
                   rsh.shipment_num
                       oracle_inbound_asn_number,
                   pla.quantity
                       po_quantity,
                   rsl.quantity_shipped,
                   rsl.quantity_received,
                   rsl.shipment_line_status_code,
                   rsl.to_organization_id
                       receiving_organization_id,
                   flv.attribute3
                       receiving_sub_inventory,
                   (SELECT hca.account_name
                      FROM hz_cust_accounts hca
                     WHERE hca.cust_account_id = ooha.sold_to_org_id)
                       so_customer,
                   ooha.cust_po_number
                       so_cust_po_number,
                   ooha.order_number
                       so_order_number,
                   ooha.header_id
                       so_header_id,
                   ooha.order_type_id
                       so_order_type_id,
                   oola.line_id
                       so_line_id,
                   oola.line_number || '.' || oola.shipment_number
                       so_order_line_num,
                   oola.flow_status_code
                       so_line_flow_status_code,
                   oola.ordered_item,
                   oola.ordered_quantity
                       so_ordered_qty,
                   'N'
                       record_status,
                   NULL
                       error_message,
                   gn_request_id
                       request_id,
                   gn_user_id
                       created_by,
                   SYSDATE
                       creation_date,
                   gn_user_id
                       last_updated_by,
                   SYSDATE
                       last_update_date
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, fnd_lookup_values flv,
                   po_headers_all pha, po_lines_all pla, rcv_shipment_headers rsh,
                   rcv_shipment_lines rsl, wsh_delivery_details wdd
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.open_flag = 'Y'
                   AND oola.open_flag = 'Y'
                   AND flv.lookup_type = 'XXD_ONT_CUSTOM_PICK_LKP'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                   AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                   AND ooha.order_type_id = TO_NUMBER (flv.attribute1)
                   AND oola.ship_from_org_id = TO_NUMBER (flv.attribute2)
                   AND pha.po_header_id = pla.po_header_id
                   AND pha.po_header_id = rsl.po_header_id
                   AND pla.po_line_id = rsl.po_line_id
                   AND rsh.shipment_header_id = rsl.shipment_header_id
                   -- Back-to-back Links
                   AND ((flv.lookup_code = 'DIRECT_SHIP_US' AND oola.attribute16 = TO_CHAR (rsl.po_line_location_id)) OR (flv.lookup_code = 'SPECIAL_VAS_US' AND oola.attribute15 = TO_CHAR (rsl.po_line_location_id)))
                   AND oola.line_id = TO_NUMBER (rsl.attribute3)
                   -- Delivery Restriction
                   AND wdd.source_code = 'OE'
                   AND wdd.source_header_id = ooha.header_id
                   AND wdd.source_line_id = oola.line_id
                   AND ((flv.lookup_code = 'DIRECT_SHIP_US' AND wdd.released_status NOT IN ('C', 'Y')) OR (flv.lookup_code = 'SPECIAL_VAS_US' AND wdd.released_status <> 'S'))
                   -- Input Parameters
                   AND ooha.org_id = gn_org_id
                   AND ((p_order_type_id IS NOT NULL AND ooha.order_type_id = p_order_type_id) OR (p_order_type_id IS NULL AND 1 = 1))
                   AND ((p_factory_invoice_num IS NOT NULL AND rsh.packing_slip = p_factory_invoice_num) OR (p_factory_invoice_num IS NULL AND 1 = 1))
                   AND ((p_container_num IS NOT NULL AND rsl.container_num = p_container_num) OR (p_container_num IS NULL AND 1 = 1))
                   AND ((p_order_header_id IS NOT NULL AND ooha.header_id = p_order_header_id) OR (p_order_header_id IS NULL AND 1 = 1));

        CURSOR get_batches IS
              SELECT bucket, MIN (shipment_id) from_batch_id, MAX (shipment_id) to_batch_id
                FROM (SELECT shipment_id, NTILE (p_threads) OVER (ORDER BY shipment_id) bucket
                        FROM (SELECT DISTINCT shipment_id
                                FROM xxd_ont_shipment_details_t
                               WHERE     request_id = gn_request_id
                                     AND record_status = 'N'))
            GROUP BY bucket
            ORDER BY 1;

        TYPE details_tbl_typ IS TABLE OF get_details_c%ROWTYPE;

        l_details_tbl_typ   details_tbl_typ;
        ln_req_id           NUMBER;
        ln_record_count     NUMBER := 0;
        lc_req_data         VARCHAR2 (10);
        lc_status           VARCHAR2 (10);
    BEGIN
        lc_req_data       := fnd_conc_global.request_data;

        IF lc_req_data = 'MASTER'
        THEN
            -- Ignore unprocessed record
            UPDATE xxd_ont_shipment_details_t
               SET record_status = 'I', error_message = 'Ignored Records for the current run.'
             WHERE request_id = gn_request_id AND record_status = 'N';

            RETURN;
        END IF;

        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_debug, 'N'));
        debug_msg ('Start PICK_RELEASE_MASTER');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        DELETE xxd_ont_shipment_details_t
         WHERE creation_date <= SYSDATE - 30;

        debug_msg ('30 Days Older Records Purge Count = ' || SQL%ROWCOUNT);

        OPEN get_details_c;

       <<details>>
        LOOP
            FETCH get_details_c
                BULK COLLECT INTO l_details_tbl_typ
                LIMIT 2000;

            EXIT details WHEN l_details_tbl_typ.COUNT = 0;

            FORALL i IN 1 .. l_details_tbl_typ.COUNT
                INSERT INTO xxd_ont_shipment_details_t
                     VALUES l_details_tbl_typ (i);

            ln_record_count   := ln_record_count + SQL%ROWCOUNT;
            COMMIT;
        END LOOP details;

        CLOSE get_details_c;

        COMMIT;

        IF ln_record_count > 0
        THEN
            debug_msg ('Total Record Count = ' || ln_record_count);
            debug_msg (RPAD ('=', 100, '='));

            -- 1. Mark Error if Inventory period is not open
            MERGE INTO xxd_ont_shipment_details_t xosdt
                 USING (SELECT DISTINCT xxd.receiving_organization_id,
                                        (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                                           FROM org_acct_periods oap
                                          WHERE     oap.organization_id =
                                                    xxd.receiving_organization_id
                                                AND oap.open_flag = 'Y'
                                                AND (TRUNC (SYSDATE) BETWEEN TRUNC (oap.period_start_date) AND TRUNC (oap.schedule_close_date))) open_flag
                          FROM xxd_ont_shipment_details_t xxd
                         WHERE     xxd.request_id = gn_request_id
                               AND xxd.record_status = 'N') xosdt1
                    ON (xosdt.receiving_organization_id = xosdt1.receiving_organization_id AND xosdt1.open_flag = 'N')
            WHEN MATCHED
            THEN
                UPDATE SET
                    xosdt.record_status = 'E', xosdt.error_message = 'Inventory Period is not open for the current Organization.'
                         WHERE     xosdt.request_id = gn_request_id
                               AND xosdt.record_status = 'N';

            debug_msg (
                   '1. Records with Inventory Period not open Count = '
                || SQL%ROWCOUNT);

            -- 2. Mark Error if order has active hold
            MERGE INTO xxd_ont_shipment_details_t xosdt
                 USING (SELECT DISTINCT xxd.so_header_id
                          FROM xxd_ont_shipment_details_t xxd, oe_hold_definitions ohd, oe_hold_sources_all ohsa,
                               oe_order_holds_all holds
                         WHERE     ohsa.hold_source_id = holds.hold_source_id
                               AND ohd.hold_id = ohsa.hold_id
                               AND ohsa.released_flag = 'N'
                               AND holds.released_flag = 'N'
                               AND holds.header_id = xxd.so_header_id
                               AND xxd.request_id = gn_request_id
                               AND xxd.record_status = 'N') xosdt1
                    ON (xosdt.so_header_id = xosdt1.so_header_id)
            WHEN MATCHED
            THEN
                UPDATE SET
                    xosdt.record_status = 'E', xosdt.error_message = 'Order has active hold.'
                         WHERE     xosdt.request_id = gn_request_id
                               AND xosdt.record_status = 'N';

            debug_msg ('2. Orders with hold Count = ' || SQL%ROWCOUNT);

            -- 3. Mark Error for Non Inventory Reservations
            MERGE INTO xxd_ont_shipment_details_t xosdt
                 USING (SELECT DISTINCT xxd.so_line_id
                          FROM xxd_ont_shipment_details_t xxd, mtl_reservations mr
                         WHERE     mr.demand_source_line_id = xxd.so_line_id
                               AND (   (    xxd.order_type = 'DIRECT_SHIP_US'
                                        AND (   (    p_partial_order_fulfill =
                                                     'Y'
                                                 AND NOT EXISTS
                                                         (SELECT 1
                                                            FROM mtl_reservations mr1
                                                           WHERE     mr.demand_source_line_id =
                                                                     mr1.demand_source_line_id
                                                                 AND mr1.supply_source_type_id =
                                                                     13))
                                             OR (p_partial_order_fulfill = 'N' AND mr.supply_source_type_id <> 13)))
                                    OR (xxd.order_type = 'SPECIAL_VAS_US' AND mr.supply_source_type_id <> 13))
                               AND xxd.request_id = gn_request_id
                               AND xxd.record_status = 'N') xosdt1
                    ON (xosdt.so_line_id = xosdt1.so_line_id)
            WHEN MATCHED
            THEN
                UPDATE SET
                    xosdt.record_status = 'E', xosdt.error_message = 'Reservations are not of Inventory.'
                         WHERE     xosdt.request_id = gn_request_id
                               AND xosdt.record_status = 'N';

            debug_msg (
                   'Records of non Inventory Reservation Count = '
                || SQL%ROWCOUNT);

            -- 4. Mark Error for incorrect subinventory
            MERGE INTO xxd_ont_shipment_details_t xosdt
                 USING (SELECT DISTINCT xxd.so_line_id
                          FROM xxd_ont_shipment_details_t xxd, mtl_reservations mr
                         WHERE     mr.demand_source_line_id = xxd.so_line_id
                               AND (   (    xxd.order_type = 'DIRECT_SHIP_US'
                                        AND (   (    p_partial_order_fulfill =
                                                     'Y'
                                                 AND NOT EXISTS
                                                         (SELECT 1
                                                            FROM mtl_reservations mr1
                                                           WHERE     mr.demand_source_line_id =
                                                                     mr1.demand_source_line_id
                                                                 AND NVL (
                                                                         mr1.subinventory_code,
                                                                         'XX') =
                                                                     xxd.receiving_sub_inventory))
                                             OR (p_partial_order_fulfill = 'N' AND NVL (mr.subinventory_code, 'XX') <> xxd.receiving_sub_inventory)))
                                    OR (xxd.order_type = 'SPECIAL_VAS_US' AND NVL (mr.subinventory_code, 'XX') <> xxd.receiving_sub_inventory))
                               AND xxd.request_id = gn_request_id
                               AND xxd.record_status = 'N') xosdt1
                    ON (xosdt.so_line_id = xosdt1.so_line_id)
            WHEN MATCHED
            THEN
                UPDATE SET
                    xosdt.record_status = 'E', xosdt.error_message = 'Reservations are not of Inventory.'
                         WHERE     xosdt.request_id = gn_request_id
                               AND xosdt.record_status = 'N';

            debug_msg (
                   'Records of with Blank or Incorrect Subinventory Reservation Count = '
                || SQL%ROWCOUNT);

            -- Partial Fulfillment Check for Direct Ship
            IF p_partial_order_fulfill = 'N'
            THEN
                -- 5. Mark Error if partial receipt
                MERGE INTO xxd_ont_shipment_details_t xosdt
                     USING (SELECT DISTINCT xxd.so_header_id
                              FROM xxd_ont_shipment_details_t xxd
                             WHERE     xxd.shipment_line_status_code <>
                                       'FULLY RECEIVED'
                                   AND xxd.order_type = 'DIRECT_SHIP_US'
                                   AND xxd.request_id = gn_request_id
                                   AND xxd.record_status = 'N') xosdt1
                        ON (xosdt.so_header_id = xosdt1.so_header_id)
                WHEN MATCHED
                THEN
                    UPDATE SET
                        xosdt.record_status = 'E', xosdt.error_message = 'Partial Receipt Not Allowed.'
                             WHERE     xosdt.request_id = gn_request_id
                                   AND xosdt.record_status = 'N';

                debug_msg (
                       'Direct Ship - POs with Partial Receipt marked as Error Count = '
                    || SQL%ROWCOUNT);

                -- Start for CCR0008125
                -- 5.1 Mark whole order as Error if one or more order lines are not associated with ASN
                MERGE INTO xxd_ont_shipment_details_t xosdt
                     USING (SELECT DISTINCT xxd.so_header_id
                              FROM xxd_ont_shipment_details_t xxd, oe_order_lines_all oola
                             WHERE     xxd.so_header_id = oola.header_id
                                   AND oola.open_flag = 'Y'
                                   AND xxd.order_type = 'DIRECT_SHIP_US'
                                   AND xxd.request_id = gn_request_id
                                   AND xxd.record_status = 'N'
                                   AND NOT EXISTS
                                           (SELECT 1
                                              FROM mtl_reservations mr
                                             WHERE mr.demand_source_line_id =
                                                   oola.line_id)) xosdt1
                        ON (xosdt.so_header_id = xosdt1.so_header_id)
                WHEN MATCHED
                THEN
                    UPDATE SET
                        xosdt.record_status = 'E', xosdt.error_message = 'One or more order lines are not associated with ASN.'
                             WHERE     xosdt.request_id = gn_request_id
                                   AND xosdt.record_status = 'N';

                debug_msg (
                       'One or more order lines are not associated with ASN. Count = '
                    || SQL%ROWCOUNT);

                -- End for CCR0008125

                -- 6. Mark whole shipment as Error if one or more error for Direct Ship
                MERGE INTO xxd_ont_shipment_details_t xosdt
                     USING (SELECT DISTINCT shipment_id
                              FROM xxd_ont_shipment_details_t xxd
                             WHERE     request_id = gn_request_id
                                   AND xxd.order_type = 'DIRECT_SHIP_US'
                                   AND record_status = 'E') xosdt1
                        ON (xosdt.shipment_id = xosdt1.shipment_id)
                WHEN MATCHED
                THEN
                    UPDATE SET
                        xosdt.record_status = 'E', xosdt.error_message = 'One or more Order in this Shipment has errors.'
                             WHERE     xosdt.request_id = gn_request_id
                                   AND xosdt.record_status = 'N';

                debug_msg (
                       'Direct Ship - Marking Error for other Orders in the same ASN. Count = '
                    || SQL%ROWCOUNT);
            END IF;

            -- 7. Mark Error if partial receipt for Special VAS
            MERGE INTO xxd_ont_shipment_details_t xosdt
                 USING (SELECT DISTINCT xxd.so_header_id
                          FROM xxd_ont_shipment_details_t xxd
                         WHERE     xxd.shipment_line_status_code <>
                                   'FULLY RECEIVED'
                               AND xxd.order_type = 'SPECIAL_VAS_US'
                               AND xxd.request_id = gn_request_id) xosdt1
                    ON (xosdt.so_header_id = xosdt1.so_header_id)
            WHEN MATCHED
            THEN
                UPDATE SET
                    xosdt.record_status = 'E', xosdt.error_message = 'Partial Receipt Not Allowed.'
                         WHERE     xosdt.request_id = gn_request_id
                               AND xosdt.record_status = 'N';

            debug_msg (
                   'Special VAS - POs with Partial Receipt marked as Error Count = '
                || SQL%ROWCOUNT);

            -- 8. Mark whole order as Error if one or more error for Special VAS
            MERGE INTO xxd_ont_shipment_details_t xosdt
                 USING (SELECT DISTINCT xxd.so_header_id
                          FROM xxd_ont_shipment_details_t xxd
                         WHERE     xxd.order_type = 'SPECIAL_VAS_US'
                               AND xxd.request_id = gn_request_id
                               AND xxd.record_status = 'E') xosdt1
                    ON (xosdt.so_header_id = xosdt1.so_header_id)
            WHEN MATCHED
            THEN
                UPDATE SET
                    xosdt.record_status = 'E', xosdt.error_message = 'One or more line in this Order has errors.'
                         WHERE     xosdt.request_id = gn_request_id
                               AND xosdt.record_status = 'N';

            debug_msg (
                   'Special VAS - Marking Error for lines in the same Order. Count = '
                || SQL%ROWCOUNT);

            COMMIT;

            debug_msg ('Submit Child Programs');

            -- Submit Child Programs
            FOR i IN get_batches
            LOOP
                ln_req_id   := 0;

                ln_req_id   :=
                    fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_CUST_PICK_REL_CHILD', description => NULL, start_time => NULL, sub_request => TRUE, argument1 => i.from_batch_id, argument2 => i.to_batch_id, argument3 => gn_request_id, argument4 => p_threads
                                                , argument5 => p_debug);
                COMMIT;
                debug_msg ('Child Request ID = ' || ln_req_id);
            END LOOP;

            debug_msg ('Successfully Submitted Child Threads');
            debug_msg (RPAD ('=', 100, '='));

            IF ln_req_id IS NOT NULL
            THEN
                fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                                 request_data   => 'MASTER');
            END IF;
        ELSE
            debug_msg ('No Data Found to Process');
            debug_msg (RPAD ('=', 100, '='));
        END IF;

        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End PICK_RELEASE_MASTER');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            debug_msg ('End PICK_RELEASE_MASTER');
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in PICK_RELEASE_MASTER = ' || SQLERRM);

            UPDATE xxd_ont_shipment_details_t
               SET record_status = 'E', error_message = x_errbuf
             WHERE request_id = gn_request_id AND record_status = 'N';
    END pick_release_master;

    -- ======================================================================================
    -- This procedure will process each Shipment based on the parameters
    -- ======================================================================================
    PROCEDURE pick_release_child (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_from_batch_id IN NUMBER, p_to_batch_id IN NUMBER, p_request_id IN NUMBER, p_threads IN NUMBER
                                  , p_debug IN VARCHAR2)
    AS
        CURSOR get_orders_c IS
              SELECT DISTINCT xosdt.shipment_id, xosdt.order_type, xosdt.oracle_inbound_asn_number asn_number,
                              xosdt.so_header_id, flv.attribute3 pick_subinventory, flv.attribute4 pick_confirm_flag,
                              flv.attribute5 stage_subinventory -- Added for CCR0008125
                FROM xxd_ont_shipment_details_t xosdt, fnd_lookup_values flv
               WHERE     flv.language = USERENV ('LANG')
                     AND flv.enabled_flag = 'Y'
                     AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                     AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                     AND flv.lookup_type = 'XXD_ONT_CUSTOM_PICK_LKP'
                     AND flv.lookup_code = xosdt.order_type
                     AND xosdt.request_id = p_request_id
                     AND xosdt.record_status = 'N'
                     AND xosdt.shipment_id BETWEEN p_from_batch_id
                                               AND p_to_batch_id
            ORDER BY 1, 2;

        lc_return_status   VARCHAR2 (1);
        lc_return_msg      VARCHAR2 (4000);
    BEGIN
        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_debug, 'N'));
        gn_request_id     := p_request_id;
        debug_msg ('Start PICK_RELEASE_CHILD');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        FOR orders_rec IN get_orders_c
        LOOP
            debug_msg ('Shipment ID = ' || orders_rec.shipment_id);
            debug_msg ('Order Type = ' || orders_rec.order_type);
            debug_msg ('ASN Number = ' || orders_rec.asn_number);
            gc_pick_confirm_flag    := orders_rec.pick_confirm_flag;
            gc_pick_subinventory    := orders_rec.pick_subinventory;
            gc_stage_subinventory   := orders_rec.stage_subinventory; -- Added for CCR0008125

            -- Credit Check for Special VAS Orders
            IF orders_rec.order_type = 'SPECIAL_VAS_US'
            THEN
                credit_check (p_header_id       => orders_rec.so_header_id,
                              x_return_status   => lc_return_status,
                              x_return_msg      => lc_return_msg);

                IF lc_return_status = 'E'
                THEN
                    UPDATE xxd_ont_shipment_details_t
                       SET record_status = 'E', error_message = lc_return_msg
                     WHERE     shipment_id BETWEEN p_from_batch_id
                                               AND p_to_batch_id
                           AND so_header_id = orders_rec.so_header_id
                           AND request_id = p_request_id
                           AND record_status = 'N';
                END IF;
            ELSE
                -- Ignore Credit Check for Direct Ship
                lc_return_status   := 'S';
            END IF;

            IF lc_return_status = 'S'
            THEN
                -- Pick Release
                pick_release (p_order_type     => orders_rec.order_type,
                              p_so_header_id   => orders_rec.so_header_id);
            END IF;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End PICK_RELEASE_CHILD');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            debug_msg ('End PICK_RELEASE_CHILD');
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in PICK_RELEASE_CHILD = ' || x_errbuf);

            UPDATE xxd_ont_shipment_details_t
               SET record_status = 'E', error_message = x_errbuf
             WHERE     shipment_id BETWEEN p_from_batch_id AND p_to_batch_id
                   AND request_id = p_request_id
                   AND record_status = 'N';
    END pick_release_child;
END xxd_ont_custom_pick_rel_pkg;
/
