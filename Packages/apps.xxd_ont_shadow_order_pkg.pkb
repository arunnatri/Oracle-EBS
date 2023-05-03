--
-- XXD_ONT_SHADOW_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SHADOW_ORDER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_SHADOW_ORDER_PKG
    * Design       : This package will will manage the shadow order process
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 01-Jul-2021  1.0        Deckers                 Initial Version
    -- 03-Aug-2021  1.1        Deckers                 Updated for CCR0009505
    -- 16-Sep-2021  1.2        Laltu Kumar             Updated for CCR0009461
    -- 08-Oct-2021  1.3        Viswanathan Pandian     Updated for CCR0009695
    ******************************************************************************************/
    gn_shadow_bulk_ord_type_id   oe_transaction_types_all.transaction_type_id%TYPE;
    gn_record_set                NUMBER;               -- Added for CCR0009461

    PROCEDURE msg (pc_msg VARCHAR2, pn_log_level NUMBER:= 9.99e125, pc_origin VARCHAR2:= 'Local Delegated Debug'
                   , p_debug VARCHAR2 DEFAULT 'N')
    AS
    BEGIN
        IF p_debug = 'Y'
        THEN
            xxd_debug_tools_pkg.msg (pc_msg         => 'Shadow Bulk: ' || pc_msg,
                                     pn_log_level   => pn_log_level,
                                     pc_origin      => pc_origin);
            fnd_file.put_line (fnd_file.LOG, pc_msg);
        END IF;
    END msg;

    PROCEDURE create_new_bulk_header (pn_old_bulk_header_id IN oe_order_headers_all.header_id%TYPE, xn_new_bulk_header_id OUT oe_order_headers_all.header_id%TYPE, xc_ret_stat OUT VARCHAR2)
    AS
        lr_old_bulk_header            oe_order_headers_all%ROWTYPE;
        lr_new_bulk_header            oe_order_headers_all%ROWTYPE;
        ln_new_bulk_header_id         oe_order_headers_all.header_id%TYPE;
        lr_new_item_attribute_value   applsys.wf_item_attribute_values%ROWTYPE;
        lr_new_item_status            applsys.wf_item_activity_statuses%ROWTYPE;
        lr_new_item                   applsys.wf_items%ROWTYPE;
        lr_header                     oe_order_pub.header_rec_type; -- Added for CCR0009505
        l_debug                       VARCHAR2 (10) := 'Y';
    BEGIN
        SELECT *
          INTO lr_old_bulk_header
          FROM oe_order_headers_all
         WHERE header_id = pn_old_bulk_header_id;

        lr_new_bulk_header                           := lr_old_bulk_header;
        ln_new_bulk_header_id                        := oe_order_headers_s.NEXTVAL;
        -- Assign Header Values
        lr_new_bulk_header.header_id                 := ln_new_bulk_header_id;
        lr_new_bulk_header.order_number              := fnd_doc_seq_1984_s.NEXTVAL;
        lr_new_bulk_header.order_type_id             := gn_shadow_bulk_ord_type_id;
        lr_new_bulk_header.order_source_id           := 2;             -- Copy
        lr_new_bulk_header.source_document_type_id   := 2;
        lr_new_bulk_header.source_document_id        := pn_old_bulk_header_id;
        lr_new_bulk_header.orig_sys_document_ref     :=
            'OE_ORDER_HEADERS_ALL' || ln_new_bulk_header_id;
        lr_new_bulk_header.cancelled_flag            := 'N';
        lr_new_bulk_header.open_flag                 := 'Y';
        lr_new_bulk_header.booked_flag               := 'Y';
        lr_new_bulk_header.creation_date             := SYSDATE;
        lr_new_bulk_header.created_by                := fnd_global.user_id;
        lr_new_bulk_header.last_update_date          := SYSDATE;
        lr_new_bulk_header.last_updated_by           := fnd_global.user_id;
        lr_new_bulk_header.last_update_login         := fnd_global.login_id;
        lr_new_bulk_header.global_attribute1         := 'BK'; -- Added for CCR0009461

        INSERT INTO oe_order_headers_all
             VALUES lr_new_bulk_header;

        FOR rec
            IN (SELECT *
                  FROM applsys.wf_item_attribute_values
                 WHERE     item_type = 'OEOH'
                       AND item_key = TO_CHAR (pn_old_bulk_header_id))
        LOOP
            lr_new_item_attribute_value   := rec;
            lr_new_item_attribute_value.item_key   :=
                TO_CHAR (ln_new_bulk_header_id);

            INSERT INTO applsys.wf_item_attribute_values
                 VALUES lr_new_item_attribute_value;
        END LOOP;

        FOR rec
            IN (SELECT *
                  FROM applsys.wf_item_activity_statuses
                 WHERE     item_type = 'OEOH'
                       AND item_key = TO_CHAR (pn_old_bulk_header_id))
        LOOP
            lr_new_item_status            := rec;
            lr_new_item_status.item_key   := TO_CHAR (ln_new_bulk_header_id);

            INSERT INTO applsys.wf_item_activity_statuses
                 VALUES lr_new_item_status;
        END LOOP;

        FOR rec
            IN (SELECT *
                  FROM applsys.wf_items
                 WHERE     item_type = 'OEOH'
                       AND item_key = TO_CHAR (pn_old_bulk_header_id))
        LOOP
            lr_new_item            := rec;
            lr_new_item.item_key   := TO_CHAR (ln_new_bulk_header_id);
            lr_new_item.user_key   :=
                'Sales Order ' || lr_new_bulk_header.order_number;

            INSERT INTO applsys.wf_items
                 VALUES lr_new_item;
        END LOOP;

        msg (
               'Successfully created new order header ID: '
            || ln_new_bulk_header_id,
            p_debug   => l_debug);

        -- Start changes for CCR0009505
        oe_header_util.query_row (p_header_id    => ln_new_bulk_header_id,
                                  x_header_rec   => lr_header);

        -- Create MSO Record
        oe_order_sch_util.insert_into_mtl_sales_orders (
            p_header_rec => lr_header);
        -- End changes for CCR0009505

        xn_new_bulk_header_id                        := ln_new_bulk_header_id;
        xc_ret_stat                                  := g_ret_sts_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in create_new_bulk_header: ' || SQLERRM,
                 p_debug   => l_debug);
            xc_ret_stat   := g_ret_sts_error;
    END create_new_bulk_header;

    PROCEDURE check_bulk_header (pn_bulk_line_id IN oe_order_lines_all.line_id%TYPE, xn_bulk_header_id OUT oe_order_headers_all.header_id%TYPE, xc_ret_stat OUT VARCHAR2)
    AS
        lr_bulk_header      oe_order_headers_all%ROWTYPE;
        lr_bulk_line        oe_order_lines_all%ROWTYPE;
        ln_bulk_header_id   oe_order_headers_all.header_id%TYPE;
        lc_ret_stat         VARCHAR2 (1);
        l_debug             VARCHAR2 (10) := 'Y';
    BEGIN
        SELECT *
          INTO lr_bulk_line
          FROM oe_order_lines_all
         WHERE line_id = pn_bulk_line_id;

        SELECT *
          INTO lr_bulk_header
          FROM oe_order_headers_all
         WHERE header_id = lr_bulk_line.header_id;

        BEGIN
            SELECT DISTINCT TO_NUMBER (attribute3)
              INTO gn_shadow_bulk_ord_type_id
              FROM fnd_lookup_values flv
             WHERE     TO_NUMBER (flv.attribute1) = lr_bulk_header.org_id
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND lookup_type = 'XXD_SHADOW_BO_CRITERIA'
                   AND TO_NUMBER (flv.attribute2) =
                       lr_bulk_line.sold_to_org_id; --Added changes for CCR0009461
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Unable to derive Shawdow Order Type: ' || SQLERRM,
                     p_debug   => l_debug);
                xc_ret_stat   := g_ret_sts_error;
                RETURN;
        END;

        SELECT MAX (header_id)
          INTO ln_bulk_header_id
          FROM oe_order_headers_all ooha, fnd_lookup_values flv
         WHERE     ooha.org_id = TO_NUMBER (flv.attribute1)
               AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute2)
               AND ooha.order_type_id = TO_NUMBER (flv.attribute3)
               AND flv.language = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (end_date_active, SYSDATE))
               AND lookup_type = 'XXD_SHADOW_BO_CRITERIA'
               AND ooha.sold_to_org_id = lr_bulk_header.sold_to_org_id
               AND ooha.open_flag = 'Y'
               AND cust_po_number = lr_bulk_header.cust_po_number
               AND ooha.flow_status_code = 'BOOKED';

        IF ln_bulk_header_id IS NOT NULL
        THEN
            msg ('Found existing bulk header ID: ' || ln_bulk_header_id,
                 p_debug   => l_debug);
            lc_ret_stat   := g_ret_sts_success;
        ELSE
            msg ('Creating a new shadow bulk order', p_debug => l_debug);
            create_new_bulk_header (
                pn_old_bulk_header_id   => lr_bulk_line.header_id,
                xn_new_bulk_header_id   => ln_bulk_header_id,
                xc_ret_stat             => lc_ret_stat);
        END IF;

        xn_bulk_header_id   := ln_bulk_header_id;
        xc_ret_stat         := lc_ret_stat;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in check_bulk_header: ' || SQLERRM,
                 p_debug   => l_debug);
            xc_ret_stat   := g_ret_sts_error;
    END check_bulk_header;

    PROCEDURE check_bulk_line (pn_old_bulk_line_id IN oe_order_lines_all.line_id%TYPE, pn_new_bulk_header_id IN oe_order_headers_all.header_id%TYPE, pn_ordered_qty IN oe_order_lines_all.ordered_quantity%TYPE
                               , xn_new_bulk_line_id OUT oe_order_lines_all.line_id%TYPE, xc_ret_stat OUT VARCHAR2)
    AS
        lr_old_bulk_line              oe_order_lines_all%ROWTYPE;
        lr_new_bulk_line              oe_order_lines_all%ROWTYPE;
        lr_new_bulk_header            oe_order_headers_all%ROWTYPE;
        ln_old_bulk_order             oe_order_headers_all.order_number%TYPE;
        ln_new_bulk_line_id           oe_order_lines_all.line_id%TYPE;
        ln_line_type_id               oe_order_lines_all.line_type_id%TYPE;
        ln_reason_id                  oe_reasons.reason_id%TYPE;
        lr_new_item_attribute_value   applsys.wf_item_attribute_values%ROWTYPE;
        lr_new_item_status            applsys.wf_item_activity_statuses%ROWTYPE;
        lr_new_item                   applsys.wf_items%ROWTYPE;
        lc_ret_stat                   VARCHAR2 (1);
        ln_latest_cancel_qty          NUMBER;
        l_debug                       VARCHAR2 (10) := 'Y';
    BEGIN
        SELECT *
          INTO lr_new_bulk_header
          FROM oe_order_headers_all
         WHERE header_id = pn_new_bulk_header_id;

        SELECT *
          INTO lr_old_bulk_line
          FROM oe_order_lines_all
         WHERE line_id = pn_old_bulk_line_id;

        SELECT ooha.order_number
          INTO ln_old_bulk_order
          FROM oe_order_lines_all oola, oe_order_headers_all ooha
         WHERE     ooha.header_id = oola.header_id
               AND oola.line_id = pn_old_bulk_line_id;

        -- Validate if line exists
        SELECT MAX (line_id)
          INTO ln_new_bulk_line_id
          FROM oe_order_lines_all
         WHERE     header_id = pn_new_bulk_header_id
               AND inventory_item_id = lr_old_bulk_line.inventory_item_id
               AND cust_po_number = lr_old_bulk_line.cust_po_number
               AND schedule_ship_date <= lr_old_bulk_line.schedule_ship_date;

        IF ln_new_bulk_line_id IS NULL
        THEN
            msg (
                   'No existing line for this order. Creating a new line for qty: '
                || pn_ordered_qty,
                p_debug   => l_debug);

            BEGIN
                SELECT default_outbound_line_type_id
                  INTO ln_line_type_id
                  FROM oe_transaction_types_all
                 WHERE transaction_type_id = gn_shadow_bulk_ord_type_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('Unable to derive Shawdow Line Type: ' || SQLERRM,
                         p_debug   => l_debug);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;

            ln_new_bulk_line_id                              := oe_order_lines_s.NEXTVAL;
            lr_new_bulk_line                                 := lr_old_bulk_line;

            BEGIN
                SELECT NVL (MAX (line_number), 0) + 1
                  INTO lr_new_bulk_line.line_number
                  FROM oe_order_lines_all
                 WHERE header_id = pn_new_bulk_header_id;
            END;

            -- Assign Line Values
            lr_new_bulk_line.line_id                         := ln_new_bulk_line_id;
            lr_new_bulk_line.header_id                       := pn_new_bulk_header_id;
            lr_new_bulk_line.orig_sys_document_ref           :=
                lr_new_bulk_header.orig_sys_document_ref;
            lr_new_bulk_line.orig_sys_line_ref               :=
                'OE_ORDER_LINES_ALL' || ln_new_bulk_line_id;
            lr_new_bulk_line.split_from_line_id              := NULL;
            lr_new_bulk_line.shipment_number                 := 1;
            lr_new_bulk_line.flow_status_code                := 'CANCELLED';
            lr_new_bulk_line.ordered_quantity                := 0;
            lr_new_bulk_line.pricing_quantity                := 0;
            lr_new_bulk_line.shipping_quantity               := NULL;
            lr_new_bulk_line.shipped_quantity                := NULL;
            lr_new_bulk_line.fulfilled_quantity              := NULL;
            lr_new_bulk_line.cancelled_quantity              := pn_ordered_qty;
            lr_new_bulk_line.cancelled_flag                  := 'Y';
            lr_new_bulk_line.open_flag                       := 'N';
            lr_new_bulk_line.booked_flag                     := 'Y';
            lr_new_bulk_line.shipping_interfaced_flag        := 'N';
            lr_new_bulk_line.line_type_id                    := ln_line_type_id;
            lr_new_bulk_line.visible_demand_flag             := NULL;
            lr_new_bulk_line.schedule_status_code            := NULL;
            lr_new_bulk_line.invoice_interface_status_code   :=
                'NOT_ELIGIBLE';                        -- Added for CCR0009505
            lr_new_bulk_line.global_attribute19              := NULL;
            lr_new_bulk_line.creation_date                   := SYSDATE;
            lr_new_bulk_line.created_by                      :=
                fnd_global.user_id;
            lr_new_bulk_line.last_update_date                := SYSDATE;
            lr_new_bulk_line.last_updated_by                 :=
                fnd_global.user_id;
            lr_new_bulk_line.last_update_login               :=
                fnd_global.login_id;

            INSERT INTO oe_order_lines_all
                 VALUES lr_new_bulk_line;

            FOR rec
                IN (SELECT *
                      FROM applsys.wf_item_attribute_values
                     WHERE     item_type = 'OEOL'
                           AND item_key = TO_CHAR (lr_old_bulk_line.line_id))
            LOOP
                lr_new_item_attribute_value   := rec;
                lr_new_item_attribute_value.item_key   :=
                    TO_CHAR (ln_new_bulk_line_id);

                INSERT INTO applsys.wf_item_attribute_values
                     VALUES lr_new_item_attribute_value;
            END LOOP;

            FOR rec
                IN (SELECT *
                      FROM applsys.wf_item_activity_statuses
                     WHERE     item_type = 'OEOL'
                           AND item_key = TO_CHAR (lr_old_bulk_line.line_id))
            LOOP
                lr_new_item_status   := rec;
                lr_new_item_status.item_key   :=
                    TO_CHAR (ln_new_bulk_line_id);

                INSERT INTO applsys.wf_item_activity_statuses
                     VALUES lr_new_item_status;
            END LOOP;

            FOR rec
                IN (SELECT *
                      FROM applsys.wf_items
                     WHERE     item_type = 'OEOL'
                           AND item_key = TO_CHAR (lr_old_bulk_line.line_id))
            LOOP
                lr_new_item            := rec;
                lr_new_item.item_key   := TO_CHAR (ln_new_bulk_line_id);
                lr_new_item.parent_item_key   :=
                    TO_CHAR (lr_new_bulk_header.header_id); -- Added for CCR0009695
                lr_new_item.user_key   :=
                       'Sales Order '
                    || lr_new_bulk_header.order_number
                    || '. Line '
                    || lr_new_bulk_line.line_number
                    || '.'
                    || lr_new_bulk_line.shipment_number
                    || '..';

                INSERT INTO applsys.wf_items
                     VALUES lr_new_item;
            END LOOP;

            msg (
                   'Successfully created new order line ID: '
                || ln_new_bulk_line_id,
                p_debug   => l_debug);
        ELSE
            msg ('Updating existing line ID: ' || ln_new_bulk_line_id,
                 p_debug   => l_debug);

            SELECT *
              INTO lr_new_bulk_line
              FROM oe_order_lines_all
             WHERE line_id = ln_new_bulk_line_id;

            -- Update Order Line
            UPDATE oe_order_lines_all
               SET cancelled_quantity = NVL (lr_new_bulk_line.cancelled_quantity, 0) + pn_ordered_qty
             WHERE line_id = ln_new_bulk_line_id;

            msg ('Order Line updated successfully', p_debug => l_debug);
        END IF;

        xn_new_bulk_line_id   := ln_new_bulk_line_id;
        xc_ret_stat           := g_ret_sts_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in check_bulk_line: ' || SQLERRM,
                 p_debug   => l_debug);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
    END check_bulk_line;

    PROCEDURE create_shadow_order (pn_bulk_line_id IN oe_order_lines_all.line_id%TYPE, pn_ordered_qty IN oe_order_lines_all.ordered_quantity%TYPE, xn_new_bulk_line_id OUT oe_order_lines_all.line_id%TYPE
                                   , xc_ret_stat OUT VARCHAR2)
    AS
        ln_bulk_header_id     oe_order_headers_all.header_id%TYPE;
        ln_new_bulk_line_id   oe_order_lines_all.line_id%TYPE;
        lc_ret_stat           VARCHAR2 (1);
        l_debug               VARCHAR2 (10) := 'Y';
    BEGIN
        -- Check Header
        check_bulk_header (pn_bulk_line_id     => pn_bulk_line_id,
                           xn_bulk_header_id   => ln_bulk_header_id,
                           xc_ret_stat         => lc_ret_stat);

        msg ('Bulk header status: ' || lc_ret_stat, p_debug => l_debug);

        IF lc_ret_stat = g_ret_sts_success AND ln_bulk_header_id IS NOT NULL
        THEN
            -- Check Line
            check_bulk_line (pn_old_bulk_line_id     => pn_bulk_line_id,
                             pn_new_bulk_header_id   => ln_bulk_header_id,
                             pn_ordered_qty          => pn_ordered_qty,
                             xn_new_bulk_line_id     => ln_new_bulk_line_id,
                             xc_ret_stat             => lc_ret_stat);

            msg ('Bulk Line status: ' || lc_ret_stat, p_debug => l_debug);

            IF     lc_ret_stat <> g_ret_sts_success
               AND ln_new_bulk_line_id IS NULL
            THEN
                msg ('Line creation or update failed', p_debug => l_debug);
            ELSE
                xn_new_bulk_line_id   := ln_new_bulk_line_id;
            END IF;

            xc_ret_stat   := lc_ret_stat;
        ELSE
            msg ('Header creation or derivation failed', p_debug => l_debug);
        END IF;

        xc_ret_stat   := lc_ret_stat;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in create_shadow_order: ' || SQLERRM,
                 p_debug   => l_debug);
            xc_ret_stat   := g_ret_sts_error;
    END create_shadow_order;

    FUNCTION rec_to_obj (pr_line IN oe_order_lines_all%ROWTYPE)
        RETURN xxd_ne.xxd_ont_ord_line_obj
    AS
        lr_old    xxd_ne.xxd_ont_ord_line_obj;
        l_debug   VARCHAR2 (10) := 'Y';
    BEGIN
        lr_old                                  := NEW xxd_ne.xxd_ont_ord_line_obj (NULL);
        lr_old.line_id                          := pr_line.line_id;
        lr_old.org_id                           := pr_line.org_id;
        lr_old.header_id                        := pr_line.header_id;
        lr_old.line_type_id                     := pr_line.line_type_id;
        lr_old.line_number                      := pr_line.line_number;
        lr_old.ordered_item                     := pr_line.ordered_item;
        lr_old.request_date                     := pr_line.request_date;
        lr_old.promise_date                     := pr_line.promise_date;
        lr_old.schedule_ship_date               := pr_line.schedule_ship_date;
        lr_old.order_quantity_uom               := pr_line.order_quantity_uom;
        lr_old.pricing_quantity                 := pr_line.pricing_quantity;
        lr_old.pricing_quantity_uom             := pr_line.pricing_quantity_uom;
        lr_old.cancelled_quantity               := pr_line.cancelled_quantity;
        lr_old.shipped_quantity                 := pr_line.shipped_quantity;
        lr_old.ordered_quantity                 := pr_line.ordered_quantity;
        lr_old.fulfilled_quantity               := pr_line.fulfilled_quantity;
        lr_old.shipping_quantity                := pr_line.shipping_quantity;
        lr_old.shipping_quantity_uom            := pr_line.shipping_quantity_uom;
        lr_old.delivery_lead_time               := pr_line.delivery_lead_time;
        lr_old.tax_exempt_flag                  := pr_line.tax_exempt_flag;
        lr_old.tax_exempt_number                := pr_line.tax_exempt_number;
        lr_old.tax_exempt_reason_code           := pr_line.tax_exempt_reason_code;
        lr_old.ship_from_org_id                 := pr_line.ship_from_org_id;
        lr_old.ship_to_org_id                   := pr_line.ship_to_org_id;
        lr_old.invoice_to_org_id                := pr_line.invoice_to_org_id;
        lr_old.deliver_to_org_id                := pr_line.deliver_to_org_id;
        lr_old.ship_to_contact_id               := pr_line.ship_to_contact_id;
        lr_old.deliver_to_contact_id            := pr_line.deliver_to_contact_id;
        lr_old.invoice_to_contact_id            := pr_line.invoice_to_contact_id;
        lr_old.intmed_ship_to_org_id            := pr_line.intmed_ship_to_org_id;
        lr_old.intmed_ship_to_contact_id        :=
            pr_line.intmed_ship_to_contact_id;
        lr_old.sold_from_org_id                 := pr_line.sold_from_org_id;
        lr_old.sold_to_org_id                   := pr_line.sold_to_org_id;
        lr_old.cust_po_number                   := pr_line.cust_po_number;
        lr_old.ship_tolerance_above             := pr_line.ship_tolerance_above;
        lr_old.ship_tolerance_below             := pr_line.ship_tolerance_below;
        lr_old.demand_bucket_type_code          := pr_line.demand_bucket_type_code;
        lr_old.veh_cus_item_cum_key_id          := pr_line.veh_cus_item_cum_key_id;
        lr_old.rla_schedule_type_code           := pr_line.rla_schedule_type_code;
        lr_old.customer_dock_code               := pr_line.customer_dock_code;
        lr_old.customer_job                     := pr_line.customer_job;
        lr_old.customer_production_line         :=
            pr_line.customer_production_line;
        lr_old.cust_model_serial_number         :=
            pr_line.cust_model_serial_number;
        lr_old.project_id                       := pr_line.project_id;
        lr_old.task_id                          := pr_line.task_id;
        lr_old.inventory_item_id                := pr_line.inventory_item_id;
        lr_old.tax_date                         := pr_line.tax_date;
        lr_old.tax_code                         := pr_line.tax_code;
        lr_old.tax_rate                         := pr_line.tax_rate;
        lr_old.invoice_interface_status_code    :=
            pr_line.invoice_interface_status_code;
        lr_old.demand_class_code                := pr_line.demand_class_code;
        lr_old.price_list_id                    := pr_line.price_list_id;
        lr_old.pricing_date                     := pr_line.pricing_date;
        lr_old.shipment_number                  := pr_line.shipment_number;
        lr_old.agreement_id                     := pr_line.agreement_id;
        lr_old.shipment_priority_code           :=
            pr_line.shipment_priority_code;
        lr_old.shipping_method_code             :=
            pr_line.shipping_method_code;
        lr_old.freight_carrier_code             :=
            pr_line.freight_carrier_code;
        lr_old.freight_terms_code               := pr_line.freight_terms_code;
        lr_old.fob_point_code                   := pr_line.fob_point_code;
        lr_old.tax_point_code                   := pr_line.tax_point_code;
        lr_old.payment_term_id                  := pr_line.payment_term_id;
        lr_old.invoicing_rule_id                := pr_line.invoicing_rule_id;
        lr_old.accounting_rule_id               := pr_line.accounting_rule_id;
        lr_old.source_document_type_id          :=
            pr_line.source_document_type_id;
        lr_old.orig_sys_document_ref            :=
            pr_line.orig_sys_document_ref;
        lr_old.source_document_id               := pr_line.source_document_id;
        lr_old.orig_sys_line_ref                := pr_line.orig_sys_line_ref;
        lr_old.source_document_line_id          :=
            pr_line.source_document_line_id;
        lr_old.reference_line_id                := pr_line.reference_line_id;
        lr_old.reference_type                   := pr_line.reference_type;
        lr_old.reference_header_id              := pr_line.reference_header_id;
        lr_old.item_revision                    := pr_line.item_revision;
        lr_old.unit_selling_price               := pr_line.unit_selling_price;
        lr_old.unit_list_price                  := pr_line.unit_list_price;
        lr_old.tax_value                        := pr_line.tax_value;
        lr_old.context                          := pr_line.context;
        lr_old.attribute1                       := pr_line.attribute1;
        lr_old.attribute2                       := pr_line.attribute2;
        lr_old.attribute3                       := pr_line.attribute3;
        lr_old.attribute4                       := pr_line.attribute4;
        lr_old.attribute5                       := pr_line.attribute5;
        lr_old.attribute6                       := pr_line.attribute6;
        lr_old.attribute7                       := pr_line.attribute7;
        lr_old.attribute8                       := pr_line.attribute8;
        lr_old.attribute9                       := pr_line.attribute9;
        lr_old.attribute10                      := pr_line.attribute10;
        lr_old.attribute11                      := pr_line.attribute11;
        lr_old.attribute12                      := pr_line.attribute12;
        lr_old.attribute13                      := pr_line.attribute13;
        lr_old.attribute14                      := pr_line.attribute14;
        lr_old.attribute15                      := pr_line.attribute15;
        lr_old.global_attribute_category        :=
            pr_line.global_attribute_category;
        lr_old.global_attribute1                := pr_line.global_attribute1;
        lr_old.global_attribute2                := pr_line.global_attribute2;
        lr_old.global_attribute3                := pr_line.global_attribute3;
        lr_old.global_attribute4                := pr_line.global_attribute4;
        lr_old.global_attribute5                := pr_line.global_attribute5;
        lr_old.global_attribute6                := pr_line.global_attribute6;
        lr_old.global_attribute7                := pr_line.global_attribute7;
        lr_old.global_attribute8                := pr_line.global_attribute8;
        lr_old.global_attribute9                := pr_line.global_attribute9;
        lr_old.global_attribute10               := pr_line.global_attribute10;
        lr_old.global_attribute11               := pr_line.global_attribute11;
        lr_old.global_attribute12               := pr_line.global_attribute12;
        lr_old.global_attribute13               := pr_line.global_attribute13;
        lr_old.global_attribute14               := pr_line.global_attribute14;
        lr_old.global_attribute15               := pr_line.global_attribute15;
        lr_old.global_attribute16               := pr_line.global_attribute16;
        lr_old.global_attribute17               := pr_line.global_attribute17;
        lr_old.global_attribute18               := pr_line.global_attribute18;
        lr_old.global_attribute19               := pr_line.global_attribute19;
        lr_old.global_attribute20               := pr_line.global_attribute20;
        lr_old.pricing_context                  := pr_line.pricing_context;
        lr_old.pricing_attribute1               := pr_line.pricing_attribute1;
        lr_old.pricing_attribute2               := pr_line.pricing_attribute2;
        lr_old.pricing_attribute3               := pr_line.pricing_attribute3;
        lr_old.pricing_attribute4               := pr_line.pricing_attribute4;
        lr_old.pricing_attribute5               := pr_line.pricing_attribute5;
        lr_old.pricing_attribute6               := pr_line.pricing_attribute6;
        lr_old.pricing_attribute7               := pr_line.pricing_attribute7;
        lr_old.pricing_attribute8               := pr_line.pricing_attribute8;
        lr_old.pricing_attribute9               := pr_line.pricing_attribute9;
        lr_old.pricing_attribute10              := pr_line.pricing_attribute10;
        lr_old.industry_context                 := pr_line.industry_context;
        lr_old.industry_attribute1              := pr_line.industry_attribute1;
        lr_old.industry_attribute2              := pr_line.industry_attribute2;
        lr_old.industry_attribute3              := pr_line.industry_attribute3;
        lr_old.industry_attribute4              := pr_line.industry_attribute4;
        lr_old.industry_attribute5              := pr_line.industry_attribute5;
        lr_old.industry_attribute6              := pr_line.industry_attribute6;
        lr_old.industry_attribute7              := pr_line.industry_attribute7;
        lr_old.industry_attribute8              := pr_line.industry_attribute8;
        lr_old.industry_attribute9              := pr_line.industry_attribute9;
        lr_old.industry_attribute10             :=
            pr_line.industry_attribute10;
        lr_old.industry_attribute11             :=
            pr_line.industry_attribute11;
        lr_old.industry_attribute13             :=
            pr_line.industry_attribute13;
        lr_old.industry_attribute12             :=
            pr_line.industry_attribute12;
        lr_old.industry_attribute14             :=
            pr_line.industry_attribute14;
        lr_old.industry_attribute15             :=
            pr_line.industry_attribute15;
        lr_old.industry_attribute16             :=
            pr_line.industry_attribute16;
        lr_old.industry_attribute17             :=
            pr_line.industry_attribute17;
        lr_old.industry_attribute18             :=
            pr_line.industry_attribute18;
        lr_old.industry_attribute19             :=
            pr_line.industry_attribute19;
        lr_old.industry_attribute20             :=
            pr_line.industry_attribute20;
        lr_old.industry_attribute21             :=
            pr_line.industry_attribute21;
        lr_old.industry_attribute22             :=
            pr_line.industry_attribute22;
        lr_old.industry_attribute23             :=
            pr_line.industry_attribute23;
        lr_old.industry_attribute24             :=
            pr_line.industry_attribute24;
        lr_old.industry_attribute25             :=
            pr_line.industry_attribute25;
        lr_old.industry_attribute26             :=
            pr_line.industry_attribute26;
        lr_old.industry_attribute27             :=
            pr_line.industry_attribute27;
        lr_old.industry_attribute28             :=
            pr_line.industry_attribute28;
        lr_old.industry_attribute29             :=
            pr_line.industry_attribute29;
        lr_old.industry_attribute30             :=
            pr_line.industry_attribute30;
        lr_old.creation_date                    := pr_line.creation_date;
        lr_old.created_by                       := pr_line.created_by;
        lr_old.last_update_date                 := pr_line.last_update_date;
        lr_old.last_updated_by                  := pr_line.last_updated_by;
        lr_old.last_update_login                := pr_line.last_update_login;
        lr_old.program_application_id           :=
            pr_line.program_application_id;
        lr_old.program_id                       := pr_line.program_id;
        lr_old.program_update_date              := pr_line.program_update_date;
        lr_old.request_id                       := pr_line.request_id;
        lr_old.top_model_line_id                := pr_line.top_model_line_id;
        lr_old.link_to_line_id                  := pr_line.link_to_line_id;
        lr_old.component_sequence_id            :=
            pr_line.component_sequence_id;
        lr_old.component_code                   := pr_line.component_code;
        lr_old.config_display_sequence          :=
            pr_line.config_display_sequence;
        lr_old.sort_order                       := pr_line.sort_order;
        lr_old.item_type_code                   := pr_line.item_type_code;
        lr_old.option_number                    := pr_line.option_number;
        lr_old.option_flag                      := pr_line.option_flag;
        lr_old.dep_plan_required_flag           :=
            pr_line.dep_plan_required_flag;
        lr_old.visible_demand_flag              := pr_line.visible_demand_flag;
        lr_old.line_category_code               := pr_line.line_category_code;
        lr_old.actual_shipment_date             :=
            pr_line.actual_shipment_date;
        lr_old.customer_trx_line_id             :=
            pr_line.customer_trx_line_id;
        lr_old.return_context                   := pr_line.return_context;
        lr_old.return_attribute1                := pr_line.return_attribute1;
        lr_old.return_attribute2                := pr_line.return_attribute2;
        lr_old.return_attribute3                := pr_line.return_attribute3;
        lr_old.return_attribute4                := pr_line.return_attribute4;
        lr_old.return_attribute5                := pr_line.return_attribute5;
        lr_old.return_attribute6                := pr_line.return_attribute6;
        lr_old.return_attribute7                := pr_line.return_attribute7;
        lr_old.return_attribute8                := pr_line.return_attribute8;
        lr_old.return_attribute9                := pr_line.return_attribute9;
        lr_old.return_attribute10               := pr_line.return_attribute10;
        lr_old.return_attribute11               := pr_line.return_attribute11;
        lr_old.return_attribute12               := pr_line.return_attribute12;
        lr_old.return_attribute13               := pr_line.return_attribute13;
        lr_old.return_attribute14               := pr_line.return_attribute14;
        lr_old.return_attribute15               := pr_line.return_attribute15;
        lr_old.actual_arrival_date              := pr_line.actual_arrival_date;
        lr_old.ato_line_id                      := pr_line.ato_line_id;
        lr_old.auto_selected_quantity           :=
            pr_line.auto_selected_quantity;
        lr_old.component_number                 := pr_line.component_number;
        lr_old.earliest_acceptable_date         :=
            pr_line.earliest_acceptable_date;
        lr_old.explosion_date                   := pr_line.explosion_date;
        lr_old.latest_acceptable_date           :=
            pr_line.latest_acceptable_date;
        lr_old.model_group_number               := pr_line.model_group_number;
        lr_old.schedule_arrival_date            :=
            pr_line.schedule_arrival_date;
        lr_old.ship_model_complete_flag         :=
            pr_line.ship_model_complete_flag;
        lr_old.schedule_status_code             :=
            pr_line.schedule_status_code;
        lr_old.source_type_code                 := pr_line.source_type_code;
        lr_old.cancelled_flag                   := pr_line.cancelled_flag;
        lr_old.open_flag                        := pr_line.open_flag;
        lr_old.booked_flag                      := pr_line.booked_flag;
        lr_old.salesrep_id                      := pr_line.salesrep_id;
        lr_old.return_reason_code               := pr_line.return_reason_code;
        lr_old.arrival_set_id                   := pr_line.arrival_set_id;
        lr_old.ship_set_id                      := pr_line.ship_set_id;
        lr_old.split_from_line_id               := pr_line.split_from_line_id;
        lr_old.cust_production_seq_num          :=
            pr_line.cust_production_seq_num;
        lr_old.authorized_to_ship_flag          :=
            pr_line.authorized_to_ship_flag;
        lr_old.over_ship_reason_code            :=
            pr_line.over_ship_reason_code;
        lr_old.over_ship_resolved_flag          :=
            pr_line.over_ship_resolved_flag;
        lr_old.ordered_item_id                  := pr_line.ordered_item_id;
        lr_old.item_identifier_type             :=
            pr_line.item_identifier_type;
        lr_old.configuration_id                 := pr_line.configuration_id;
        lr_old.commitment_id                    := pr_line.commitment_id;
        lr_old.shipping_interfaced_flag         :=
            pr_line.shipping_interfaced_flag;
        lr_old.credit_invoice_line_id           :=
            pr_line.credit_invoice_line_id;
        lr_old.first_ack_code                   := pr_line.first_ack_code;
        lr_old.first_ack_date                   := pr_line.first_ack_date;
        lr_old.last_ack_code                    := pr_line.last_ack_code;
        lr_old.last_ack_date                    := pr_line.last_ack_date;
        lr_old.planning_priority                := pr_line.planning_priority;
        lr_old.order_source_id                  := pr_line.order_source_id;
        lr_old.orig_sys_shipment_ref            :=
            pr_line.orig_sys_shipment_ref;
        lr_old.change_sequence                  := pr_line.change_sequence;
        lr_old.drop_ship_flag                   := pr_line.drop_ship_flag;
        lr_old.customer_line_number             :=
            pr_line.customer_line_number;
        lr_old.customer_shipment_number         :=
            pr_line.customer_shipment_number;
        lr_old.customer_item_net_price          :=
            pr_line.customer_item_net_price;
        lr_old.customer_payment_term_id         :=
            pr_line.customer_payment_term_id;
        lr_old.fulfilled_flag                   := pr_line.fulfilled_flag;
        lr_old.end_item_unit_number             :=
            pr_line.end_item_unit_number;
        lr_old.config_header_id                 := pr_line.config_header_id;
        lr_old.config_rev_nbr                   := pr_line.config_rev_nbr;
        lr_old.mfg_component_sequence_id        :=
            pr_line.mfg_component_sequence_id;
        lr_old.shipping_instructions            :=
            pr_line.shipping_instructions;
        lr_old.packing_instructions             :=
            pr_line.packing_instructions;
        lr_old.invoiced_quantity                := pr_line.invoiced_quantity;
        lr_old.reference_customer_trx_line_id   :=
            pr_line.reference_customer_trx_line_id;
        lr_old.split_by                         := pr_line.split_by;
        lr_old.line_set_id                      := pr_line.line_set_id;
        lr_old.service_txn_reason_code          :=
            pr_line.service_txn_reason_code;
        lr_old.service_txn_comments             :=
            pr_line.service_txn_comments;
        lr_old.service_duration                 := pr_line.service_duration;
        lr_old.service_start_date               := pr_line.service_start_date;
        lr_old.service_end_date                 := pr_line.service_end_date;
        lr_old.service_coterminate_flag         :=
            pr_line.service_coterminate_flag;
        lr_old.unit_list_percent                := pr_line.unit_list_percent;
        lr_old.unit_selling_percent             :=
            pr_line.unit_selling_percent;
        lr_old.unit_percent_base_price          :=
            pr_line.unit_percent_base_price;
        lr_old.service_number                   := pr_line.service_number;
        lr_old.service_period                   := pr_line.service_period;
        lr_old.shippable_flag                   := pr_line.shippable_flag;
        lr_old.model_remnant_flag               := pr_line.model_remnant_flag;
        lr_old.re_source_flag                   := pr_line.re_source_flag;
        lr_old.flow_status_code                 := pr_line.flow_status_code;
        lr_old.tp_context                       := pr_line.tp_context;
        lr_old.tp_attribute1                    := pr_line.tp_attribute1;
        lr_old.tp_attribute2                    := pr_line.tp_attribute2;
        lr_old.tp_attribute3                    := pr_line.tp_attribute3;
        lr_old.tp_attribute4                    := pr_line.tp_attribute4;
        lr_old.tp_attribute5                    := pr_line.tp_attribute5;
        lr_old.tp_attribute6                    := pr_line.tp_attribute6;
        lr_old.tp_attribute7                    := pr_line.tp_attribute7;
        lr_old.tp_attribute8                    := pr_line.tp_attribute8;
        lr_old.tp_attribute9                    := pr_line.tp_attribute9;
        lr_old.tp_attribute10                   := pr_line.tp_attribute10;
        lr_old.tp_attribute11                   := pr_line.tp_attribute11;
        lr_old.tp_attribute12                   := pr_line.tp_attribute12;
        lr_old.tp_attribute13                   := pr_line.tp_attribute13;
        lr_old.tp_attribute14                   := pr_line.tp_attribute14;
        lr_old.tp_attribute15                   := pr_line.tp_attribute15;
        lr_old.fulfillment_method_code          :=
            pr_line.fulfillment_method_code;
        lr_old.marketing_source_code_id         :=
            pr_line.marketing_source_code_id;
        lr_old.service_reference_type_code      :=
            pr_line.service_reference_type_code;
        lr_old.service_reference_line_id        :=
            pr_line.service_reference_line_id;
        lr_old.service_reference_system_id      :=
            pr_line.service_reference_system_id;
        lr_old.calculate_price_flag             :=
            pr_line.calculate_price_flag;
        lr_old.upgraded_flag                    := pr_line.upgraded_flag;
        lr_old.revenue_amount                   := pr_line.revenue_amount;
        lr_old.fulfillment_date                 := pr_line.fulfillment_date;
        lr_old.preferred_grade                  := pr_line.preferred_grade;
        lr_old.ordered_quantity2                := pr_line.ordered_quantity2;
        lr_old.ordered_quantity_uom2            :=
            pr_line.ordered_quantity_uom2;
        lr_old.shipping_quantity2               := pr_line.shipping_quantity2;
        lr_old.cancelled_quantity2              :=
            pr_line.cancelled_quantity2;
        lr_old.shipped_quantity2                := pr_line.shipped_quantity2;
        lr_old.shipping_quantity_uom2           :=
            pr_line.shipping_quantity_uom2;
        lr_old.fulfilled_quantity2              :=
            pr_line.fulfilled_quantity2;
        lr_old.mfg_lead_time                    := pr_line.mfg_lead_time;
        lr_old.lock_control                     := pr_line.lock_control;
        lr_old.subinventory                     := pr_line.subinventory;
        lr_old.unit_list_price_per_pqty         :=
            pr_line.unit_list_price_per_pqty;
        lr_old.unit_selling_price_per_pqty      :=
            pr_line.unit_selling_price_per_pqty;
        lr_old.price_request_code               := pr_line.price_request_code;
        lr_old.original_inventory_item_id       :=
            pr_line.original_inventory_item_id;
        lr_old.original_ordered_item_id         :=
            pr_line.original_ordered_item_id;
        lr_old.original_ordered_item            :=
            pr_line.original_ordered_item;
        lr_old.original_item_identifier_type    :=
            pr_line.original_item_identifier_type;
        lr_old.item_substitution_type_code      :=
            pr_line.item_substitution_type_code;
        lr_old.override_atp_date_code           :=
            pr_line.override_atp_date_code;
        lr_old.late_demand_penalty_factor       :=
            pr_line.late_demand_penalty_factor;
        lr_old.accounting_rule_duration         :=
            pr_line.accounting_rule_duration;
        lr_old.attribute16                      := pr_line.attribute16;
        lr_old.attribute17                      := pr_line.attribute17;
        lr_old.attribute18                      := pr_line.attribute18;
        lr_old.attribute19                      := pr_line.attribute19;
        lr_old.attribute20                      := pr_line.attribute20;
        lr_old.user_item_description            :=
            pr_line.user_item_description;
        lr_old.unit_cost                        := pr_line.unit_cost;
        lr_old.item_relationship_type           :=
            pr_line.item_relationship_type;
        lr_old.blanket_line_number              :=
            pr_line.blanket_line_number;
        lr_old.blanket_number                   := pr_line.blanket_number;
        lr_old.blanket_version_number           :=
            pr_line.blanket_version_number;
        lr_old.sales_document_type_code         :=
            pr_line.sales_document_type_code;
        lr_old.firm_demand_flag                 := pr_line.firm_demand_flag;
        lr_old.earliest_ship_date               := pr_line.earliest_ship_date;
        lr_old.transaction_phase_code           :=
            pr_line.transaction_phase_code;
        lr_old.source_document_version_number   :=
            pr_line.source_document_version_number;
        lr_old.payment_type_code                := pr_line.payment_type_code;
        lr_old.minisite_id                      := pr_line.minisite_id;
        lr_old.end_customer_id                  := pr_line.end_customer_id;
        lr_old.end_customer_contact_id          :=
            pr_line.end_customer_contact_id;
        lr_old.end_customer_site_use_id         :=
            pr_line.end_customer_site_use_id;
        lr_old.ib_owner                         := pr_line.ib_owner;
        lr_old.ib_current_location              :=
            pr_line.ib_current_location;
        lr_old.ib_installed_at_location         :=
            pr_line.ib_installed_at_location;
        lr_old.retrobill_request_id             :=
            pr_line.retrobill_request_id;
        lr_old.original_list_price              :=
            pr_line.original_list_price;
        lr_old.service_credit_eligible_code     :=
            pr_line.service_credit_eligible_code;
        lr_old.order_firmed_date                := pr_line.order_firmed_date;
        lr_old.actual_fulfillment_date          :=
            pr_line.actual_fulfillment_date;
        lr_old.charge_periodicity_code          :=
            pr_line.charge_periodicity_code;
        lr_old.contingency_id                   := pr_line.contingency_id;
        lr_old.revrec_event_code                := pr_line.revrec_event_code;
        lr_old.revrec_expiration_days           :=
            pr_line.revrec_expiration_days;
        lr_old.accepted_quantity                := pr_line.accepted_quantity;
        lr_old.accepted_by                      := pr_line.accepted_by;
        lr_old.revrec_comments                  := pr_line.revrec_comments;
        lr_old.revrec_reference_document        :=
            pr_line.revrec_reference_document;
        lr_old.revrec_signature                 := pr_line.revrec_signature;
        lr_old.revrec_signature_date            :=
            pr_line.revrec_signature_date;
        lr_old.revrec_implicit_flag             :=
            pr_line.revrec_implicit_flag;
        lr_old.bypass_sch_flag                  := pr_line.bypass_sch_flag;
        lr_old.pre_exploded_flag                := pr_line.pre_exploded_flag;
        lr_old.inst_id                          := pr_line.inst_id;
        lr_old.tax_line_value                   := pr_line.tax_line_value;
        lr_old.service_bill_profile_id          :=
            pr_line.service_bill_profile_id;
        lr_old.service_cov_template_id          :=
            pr_line.service_cov_template_id;
        lr_old.service_subs_template_id         :=
            pr_line.service_subs_template_id;
        lr_old.service_bill_option_code         :=
            pr_line.service_bill_option_code;
        lr_old.service_first_period_amount      :=
            pr_line.service_first_period_amount;
        lr_old.service_first_period_enddate     :=
            pr_line.service_first_period_enddate;
        lr_old.subscription_enable_flag         :=
            pr_line.subscription_enable_flag;
        lr_old.fulfillment_base                 := pr_line.fulfillment_base;
        lr_old.container_number                 := pr_line.container_number;
        lr_old.equipment_id                     := pr_line.equipment_id;
        RETURN lr_old;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in rec_to_obj: ' || SQLERRM, p_debug => l_debug);
            RETURN NULL;
    END rec_to_obj;

    PROCEDURE shadow_line (pn_calloff_line_id IN oe_order_lines_all.line_id%TYPE, xc_ret_stat OUT VARCHAR2)
    AS
        lr_calloff_line          oe_order_lines_all%ROWTYPE;
        lr_calloff_root_line     oe_order_lines_all%ROWTYPE;
        lr_calloff_header        oe_order_headers_all%ROWTYPE;
        lr_lookup                fnd_lookup_values%ROWTYPE;
        lt_consumption           xxd_ont_consumption_line_t_obj;
        lr_old                   xxd_ne.xxd_ont_ord_line_obj;
        lr_new                   xxd_ne.xxd_ont_ord_line_obj;
        lc_ret_stat              VARCHAR2 (1);
        lc_current_consumption   VARCHAR2 (2000);
        ln_shadow_line_qty       NUMBER;
        ln_shadow_bulk_line      NUMBER;
        ln_idx                   NUMBER;
        ln_cnt                   NUMBER;
        ln_consum_diff_qty       NUMBER;
        l_debug                  VARCHAR2 (10) := 'Y';
    BEGIN
        msg ('Start Shadow Bulk Process', p_debug => l_debug);

        SELECT *
          INTO lr_calloff_line
          FROM oe_order_lines_all
         WHERE line_id = pn_calloff_line_id;

        SELECT *
          INTO lr_calloff_root_line
          FROM oe_order_lines_all
         WHERE line_id =
               xxd_ont_bulk_calloff_pkg.get_root_line_id (pn_calloff_line_id);

        SELECT *
          INTO lr_calloff_header
          FROM oe_order_headers_all
         WHERE header_id = lr_calloff_line.header_id;

        BEGIN
            SELECT *
              INTO lr_lookup
              FROM fnd_lookup_values flv
             WHERE     lr_calloff_header.org_id = TO_NUMBER (flv.attribute1)
                   AND lr_calloff_header.sold_to_org_id =
                       TO_NUMBER (flv.attribute2)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND lookup_type = 'XXD_SHADOW_BO_CRITERIA';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg ('Not an eligible Shadow Bulk Customer. Exiting!',
                     p_debug   => l_debug);
                xc_ret_stat   := g_ret_sts_error;
                RETURN;
        END;

        msg ('Eligible Shadow Bulk Customer. Proceeding!', p_debug => l_debug);
        xxd_debug_tools_pkg.set_attributes (1, lr_calloff_line.header_id);
        xxd_debug_tools_pkg.set_attributes (2, lr_calloff_line.line_id);
        xxd_debug_tools_pkg.set_attributes (3, lr_calloff_line.org_id);
        xxd_ont_bulk_calloff_pkg.gc_commiting_flag   := 'N';
        lt_consumption                               :=
            xxd_ont_consumption_line_t_obj (NULL);

        IF lr_calloff_root_line.global_attribute19 IS NULL
        THEN
            msg ('GA19 is null', p_debug => l_debug);
        ELSE
            lt_consumption   :=
                xxd_ont_bulk_calloff_pkg.string_to_consumption (
                    lr_calloff_root_line.global_attribute19);
        END IF;

        SELECT NVL (xxd_ont_bulk_calloff_pkg.get_child_qty (lr_calloff_root_line.line_id), 0) - NVL (SUM (quantity), 0)
          INTO ln_consum_diff_qty
          FROM TABLE (lt_consumption);

        msg ('Difference in OQ and Consumed Qty is: ' || ln_consum_diff_qty,
             p_debug   => l_debug);

        IF NVL (ln_consum_diff_qty, 0) > 0
        THEN
            lt_consumption.EXTEND;
            lt_consumption (lt_consumption.LAST)   :=
                xxd_ont_consumption_line_obj (0, ln_consum_diff_qty);
            msg ('Successfully created a free atp cosnumption record',
                 p_debug   => l_debug);
        END IF;

        SELECT SUM (quantity)
          INTO ln_shadow_line_qty
          FROM TABLE (lt_consumption)
         WHERE line_id = 0;

        IF NVL (ln_shadow_line_qty, 0) <= 0
        THEN
            msg ('No Free ATP Consumption Details', p_debug => l_debug);
            xc_ret_stat   := g_ret_sts_success;
            RETURN;
        END IF;

        create_shadow_order (pn_bulk_line_id => lr_calloff_line.line_id, pn_ordered_qty => ln_shadow_line_qty, xn_new_bulk_line_id => ln_shadow_bulk_line
                             , xc_ret_stat => lc_ret_stat);

        ln_idx                                       := lt_consumption.FIRST;

        WHILE ln_idx IS NOT NULL
        LOOP
            IF lt_consumption (ln_idx).line_id = 0
            THEN
                lt_consumption (ln_idx).line_id   := ln_shadow_bulk_line;
            END IF;

            ln_idx   := lt_consumption.NEXT (ln_idx);
        END LOOP;

        lc_current_consumption                       :=
            xxd_ont_bulk_calloff_pkg.consumption_to_string (lt_consumption);
        msg (
               'Changing consumption on line_id ('
            || lr_calloff_root_line.line_id
            || ') from ('
            || lr_calloff_root_line.global_attribute19
            || ') to ('
            || lc_current_consumption
            || ')',
            p_debug   => l_debug);

        UPDATE oe_order_lines_all
           SET global_attribute19 = lc_current_consumption, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
         WHERE line_id = lr_calloff_root_line.line_id;

        -- Mimic consumption call
        SELECT COUNT (*) INTO ln_cnt FROM xxdo.xxd_ont_on_commit_lines_gt;

        msg ('Existing COMMIT_LINES_GT Record Count: ' || ln_cnt,
             p_debug   => l_debug);

        IF ln_cnt = 0
        THEN
            INSERT INTO xxdo.xxd_ont_on_commit_lines_gt
                 VALUES (USERENV ('commitscn'));

            msg ('COMMIT_LINES_GT Insert Count: ' || SQL%ROWCOUNT,
                 p_debug   => l_debug);
        END IF;

        msg (
            'Before Consumption Calloff Line ID: ' || lr_calloff_root_line.line_id,
            p_debug   => l_debug);
        lr_old                                       :=
            rec_to_obj (lr_calloff_root_line);
        lr_new                                       := lr_old;

        INSERT INTO xxdo.xxd_ont_consumption_gt
                 VALUES (1,
                         'FORCE',
                         lr_new,
                         lr_old,
                         lr_calloff_root_line.line_id,
                         lr_calloff_root_line.inventory_item_id);

        msg ('CONSUMPTION_GT Insert Count: ' || SQL%ROWCOUNT,
             p_debug   => l_debug);

        xc_ret_stat                                  := g_ret_sts_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in shadow_line: ' || SQLERRM, p_debug => l_debug);
            xc_ret_stat   := g_ret_sts_error;
    END shadow_line;

    --Start changes for CCR0009461
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_cust_acct_id VARCHAR2, p_order_type_id VARCHAR2, p_req_date_from VARCHAR2, p_req_date_to VARCHAR2, -- Start changes for CCR0009695
                                                                                                                                                                                        p_order_number_from NUMBER, p_order_number_to NUMBER
                    , p_threads NUMBER, -- End changes for CCR0009695
                                        p_debug VARCHAR2)
    AS
        CURSOR c_order_cur IS
            SELECT gn_record_set record_set, ROWNUM record_id, ooha.org_id,
                   ooha.header_id oe_header_id, ooha.order_number oe_order_number, ooha.sold_to_org_id cust_account_id,
                   oola.line_id oe_line_id, oola.ship_from_org_id, oola.inventory_item_id,
                   SYSDATE last_update_date, fnd_global.user_id last_updated_by, fnd_global.login_id last_update_login,
                   SYSDATE creation_date, fnd_global.user_id created_by, NULL batch_id,
                   NULL status, NULL err_msg, fnd_global.conc_request_id request_id,
                   ooha.cust_po_number
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all otta,
                   fnd_lookup_values flv
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND otta.transaction_type_id = ooha.order_type_id
                   AND ooha.open_flag = 'Y'
                   AND oola.open_flag = 'Y'
                   AND otta.attribute5 = 'CO'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_SHADOW_BO_CRITERIA'
                   AND ooha.org_id = TO_NUMBER (flv.attribute1)
                   AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute2)
                   AND ooha.order_type_id <> TO_NUMBER (flv.attribute3)
                   AND (oola.global_attribute19 LIKE '0-%' -- Consumed only from Free ATP
                                                           OR oola.global_attribute19 LIKE '%;0-%') -- Consumed from Bulk and Free ATP
                   -- Operating Unit
                   AND ooha.org_id = p_org_id
                   -- Customer Account
                   AND ((p_cust_acct_id IS NOT NULL AND ooha.sold_to_org_id = p_cust_acct_id) OR (p_cust_acct_id IS NULL AND 1 = 1))
                   -- Shadow Order Type
                   AND ((p_order_type_id IS NOT NULL AND TO_NUMBER (flv.attribute3) = p_order_type_id) OR (p_order_type_id IS NULL AND 1 = 1))
                   -- Request Date From
                   AND ((p_req_date_from IS NOT NULL AND oola.request_date > fnd_date.canonical_to_date (p_req_date_from) - 1) OR (p_req_date_from IS NULL AND 1 = 1))
                   -- Request Date To
                   AND ((p_req_date_to IS NOT NULL AND oola.request_date < fnd_date.canonical_to_date (p_req_date_to) + 1) OR (p_req_date_to IS NULL AND 1 = 1))
                   -- Start changes for CCR0009695
                   -- Order Number
                   AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number >= p_order_number_from AND ooha.order_number <= p_order_number_to) OR ((p_order_number_from IS NULL OR p_order_number_to IS NULL) AND 1 = 1));

        CURSOR get_headers_c IS
              SELECT oe_header_id header_id, MIN (oe_line_id) line_id
                FROM xxdo.xxd_ont_shadow_bulk_orders_t
               WHERE record_set = gn_record_set
            GROUP BY oe_header_id;

        -- End changes for CCR0009695

        CURSOR get_batches IS
              SELECT bucket, MIN (batch_id) from_batch_id, MAX (batch_id) to_batch_id
                FROM (SELECT batch_id, NTILE (p_threads) OVER (ORDER BY batch_id) bucket -- Added p_threads instead of 10 for CCR0009695
                        FROM (SELECT DISTINCT batch_id
                                FROM xxdo.xxd_ont_shadow_bulk_orders_t
                               WHERE record_set = gn_record_set))
            GROUP BY bucket
            ORDER BY 1;

        TYPE array IS TABLE OF c_order_cur%ROWTYPE;

        TYPE conc_request_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_conc_request_tbl   conc_request_tbl;
        lb_req_status        BOOLEAN;
        lc_status            VARCHAR2 (10);
        lc_phase             VARCHAR2 (100);
        lc_dev_phase         VARCHAR2 (100);
        lc_dev_status        VARCHAR2 (100);
        lc_message           VARCHAR2 (4000);
        ln_req_count         NUMBER := 0;
        order_cur_rec        array;
        ln_row_limit         NUMBER := 1000;
        l_debug              VARCHAR2 (10);
        l_max_batch_id       NUMBER;
        ln_from_batch_id     NUMBER;
        ln_to_batch_id       NUMBER;
        ln_request_id        NUMBER;
        ln_max_batch_id      NUMBER;
        ln_running_prg       NUMBER;
        ln_batch_count       NUMBER;
        ln_record_count      NUMBER;
        -- Start changes for CCR0009695
        ln_bulk_header_id    NUMBER;
        lc_ret_stat          VARCHAR2 (10);
    -- End changes for CCR0009695
    BEGIN
        l_debug   := NVL (p_debug, 'N');
        msg (pc_msg => 'Started main procedure ', p_debug => l_debug);

        SELECT TO_NUMBER (TO_CHAR (SYS_EXTRACT_UTC (SYSTIMESTAMP), 'SSSSSFF3'))
          INTO gn_record_set
          FROM DUAL;

        msg (pc_msg => 'Calling the cursor c_order_cur ', p_debug => l_debug);

        DELETE FROM xxdo.xxd_ont_shadow_bulk_orders_t
              WHERE creation_date < SYSDATE - 30;

        BEGIN
            OPEN c_order_cur;

            LOOP
                FETCH c_order_cur
                    BULK COLLECT INTO order_cur_rec
                    LIMIT ln_row_limit;

                EXIT WHEN order_cur_rec.COUNT = 0;

                FORALL i IN 1 .. order_cur_rec.COUNT
                    INSERT INTO xxdo.xxd_ont_shadow_bulk_orders_t
                         VALUES order_cur_rec (i);

                COMMIT;
            END LOOP;

            CLOSE c_order_cur;
        END;

        COMMIT;

        SELECT COUNT (1)
          INTO ln_record_count
          FROM xxdo.xxd_ont_shadow_bulk_orders_t
         WHERE record_set = gn_record_set;

        msg (
            pc_msg    =>
                   'Inserted record into xxd_ont_shadow_bulk_orders_t count: '
                || ln_record_count,
            p_debug   => l_debug);

        IF ln_record_count > 0
        THEN
            -- Update Batches
            MERGE INTO xxdo.xxd_ont_shadow_bulk_orders_t xosb
                 USING (SELECT ROWID, DENSE_RANK () OVER (ORDER BY inventory_item_id, ship_from_org_id) batch_id
                          FROM xxdo.xxd_ont_shadow_bulk_orders_t xxd
                         WHERE record_set = gn_record_set) xxd
                    ON (xosb.ROWID = xxd.ROWID)
            WHEN MATCHED
            THEN
                UPDATE SET xosb.batch_id   = xxd.batch_id;

            COMMIT;

            SELECT COUNT (DISTINCT batch_id)
              INTO ln_batch_count
              FROM xxdo.xxd_ont_shadow_bulk_orders_t
             WHERE record_set = gn_record_set;

            msg (pc_msg    => 'Total Batches: ' || ln_batch_count,
                 p_debug   => l_debug);

            -- Start changes for CCR0009695
            msg ('Creating Shadow Order Headers');

            FOR rec IN get_headers_c
            LOOP
                ln_bulk_header_id   := NULL;
                check_bulk_header (pn_bulk_line_id     => rec.line_id,
                                   xn_bulk_header_id   => ln_bulk_header_id,
                                   xc_ret_stat         => lc_ret_stat);

                IF lc_ret_stat = 'S' AND ln_bulk_header_id IS NOT NULL
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                    msg (
                           'Failed to create header for ID: '
                        || rec.header_id
                        || ' and line ID: '
                        || rec.line_id);
                END IF;
            END LOOP;

            -- End changes for CCR0009695

            -- Submit Child Programs
            FOR i IN get_batches
            LOOP
                ln_req_count   := ln_req_count + 1;
                l_conc_request_tbl (ln_req_count)   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_ONT_SHADOW_ORDER_CHILD',
                        description   => NULL,
                        start_time    => SYSDATE,
                        sub_request   => FALSE,
                        argument1     => i.from_batch_id,
                        argument2     => i.to_batch_id,
                        argument3     => gn_record_set,
                        argument4     => l_debug);
                COMMIT;
            END LOOP;

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
        ELSE
            msg (pc_msg => 'No data found', p_debug => l_debug);
        END IF;

        msg (pc_msg => 'End Main procedure ', p_debug => l_debug);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            msg (pc_msg    => 'Error in Main Procedure: ' || SQLERRM,
                 p_debug   => l_debug);
    END main;

    PROCEDURE shadow_line_child (errbuf            OUT VARCHAR2,
                                 retcode           OUT VARCHAR2,
                                 p_batch_id_from       NUMBER,
                                 p_batch_id_to         NUMBER,
                                 p_record_set          NUMBER,
                                 p_debug               VARCHAR2)
    AS
        CURSOR c_order_cur IS
            SELECT *
              FROM xxdo.xxd_ont_shadow_bulk_orders_t
             WHERE     record_set = p_record_set
                   AND batch_id >= p_batch_id_from
                   AND batch_id <= p_batch_id_to;

        x_ret_stat          VARCHAR2 (1000);
        l_debug             VARCHAR2 (10);
        -- Start changes for CCR0009695
        ln_bulk_header_id   NUMBER;
        lr_bulk_header      oe_order_headers_all%ROWTYPE;
        lc_err_msg          VARCHAR2 (1000);
    -- End changes for CCR0009695
    BEGIN
        l_debug   := NVL (p_debug, 'N');
        msg (pc_msg    => 'Started shadow_line_child procedure ',
             p_debug   => l_debug);

        FOR c_order_rec IN c_order_cur
        LOOP
            x_ret_stat          := NULL;
            -- Start changes for CCR0009695
            ln_bulk_header_id   := NULL;

            BEGIN
                -- Lock the Shadow Bulk Order Header
                SELECT MAX (header_id)
                  INTO ln_bulk_header_id
                  FROM oe_order_headers_all ooha, fnd_lookup_values flv
                 WHERE     ooha.org_id = TO_NUMBER (flv.attribute1)
                       AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute2)
                       AND ooha.order_type_id = TO_NUMBER (flv.attribute3)
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_SHADOW_BO_CRITERIA'
                       AND ooha.open_flag = 'Y'
                       AND ooha.flow_status_code = 'BOOKED'
                       AND ooha.sold_to_org_id = c_order_rec.cust_account_id
                       AND ooha.cust_po_number = c_order_rec.cust_po_number;

                SELECT *
                  INTO lr_bulk_header
                  FROM oe_order_headers_all
                 WHERE header_id = ln_bulk_header_id
                FOR UPDATE;

                -- End changes for CCR0009695

                shadow_line (pn_calloff_line_id   => c_order_rec.oe_line_id,
                             xc_ret_stat          => x_ret_stat);

                -- Start changes for CCR0009695
                IF x_ret_stat <> 'S'
                THEN
                    lc_err_msg   :=
                           'Error while calling shadow_line for line id:-'
                        || c_order_rec.oe_line_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := 'E';
                    lc_err_msg   :=
                           'Unable to lock the Shadow Bulk Header ID for Calloff Order '
                        || c_order_rec.oe_order_number;
            END;

            UPDATE xxdo.xxd_ont_shadow_bulk_orders_t
               SET status = x_ret_stat, err_msg = lc_err_msg
             WHERE     oe_line_id = c_order_rec.oe_line_id
                   AND batch_id >= p_batch_id_from
                   AND batch_id <= p_batch_id_to
                   AND record_set = p_record_set;

            -- End changes for CCR0009695

            COMMIT;
        END LOOP;

        msg (pc_msg => 'End shadow_line_child procedure ', p_debug => l_debug);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            msg (
                pc_msg    =>
                    'Error in shadow_line_child Procedure: ' || SQLERRM,
                p_debug   => l_debug);
    END shadow_line_child;
--End changes for CCR0009461
END xxd_ont_shadow_order_pkg;
/
