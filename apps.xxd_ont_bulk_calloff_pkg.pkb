--
-- XXD_ONT_BULK_CALLOFF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_CALLOFF_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_CALLOFF_PKG
    * Design       : This package will manage the bulk calloff process
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2020  1.0        Deckers                 Initial Version
    -- 02-Aug-2021  1.1        Deckers                 Updated for CCR0009499
    -- 16-Aug-2021  1.2        Deckers                 Updated for CCR0009529 to replace the DB link name
    -- 08-Nov-2021  1.3        Viswanathan Pandian     Updated for CCR0009692 to add all exception block
    --                                                 messages as primary debug level 1
    ******************************************************************************************/

    gc_inserting   VARCHAR2 (10) := 'INSERTING';
    gc_updating    VARCHAR2 (10) := 'UPDATING';
    gc_deleting    VARCHAR2 (10) := 'DELETING';
    gc_consume     VARCHAR2 (10) := 'CONSUME';
    gc_unconsume   VARCHAR2 (10) := 'UNCONSUME';
    gc_reconsume   VARCHAR2 (10) := 'RECONSUME';
    gc_split       VARCHAR2 (1);

    PROCEDURE msg (pc_msg         VARCHAR2,
                   pn_log_level   NUMBER:= 9.99e125,
                   pc_origin      VARCHAR2:= 'Local Delegated Debug')
    IS
    BEGIN
        xxd_debug_tools_pkg.msg (pc_msg         => pc_msg,
                                 pn_log_level   => pn_log_level,
                                 pc_origin      => pc_origin);
    END msg;

    PROCEDURE sync_exclusion
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        xxd_atp_customization_pkg.clear_excluded_line_ids@BT_EBS_TO_ASCP.US.ORACLE.COM (); -- Added the full DB name for CCR0009529

        FOR rec IN (  SELECT *
                        FROM TABLE (gt_excluded_line_ids)
                    ORDER BY seq ASC)
        LOOP
            xxd_atp_customization_pkg.add_line_id_to_exclusion@BT_EBS_TO_ASCP.US.ORACLE.COM (
                rec.line_id);
        END LOOP;

        COMMIT;
    END sync_exclusion;

    PROCEDURE add_line_id_to_exclusion (pn_line_id IN NUMBER, pn_inventory_item_id IN NUMBER, pn_priority IN NUMBER:= 0)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ln_existing   NUMBER;
    BEGIN
        IF gc_split = 'Y'
        THEN
            oe_sys_parameters_pvt.gc_override_split   := 'Q';
        END IF;

        IF     pn_line_id IS NOT NULL
           AND pn_line_id > 0
           AND pn_line_id = TRUNC (pn_line_id)
        THEN
            msg (
                   'Adding line_id ('
                || pn_line_id
                || ') to exclusion list with priority ('
                || pn_priority
                || ')');

            SELECT COUNT (*)
              INTO ln_existing
              FROM TABLE (gt_excluded_line_ids)
             WHERE line_id = pn_line_id;

            IF ln_existing != 0
            THEN
                msg (
                       'Line_id ('
                    || pn_line_id
                    || ') already located in exclusion list');
                COMMIT;
                RETURN;
            END IF;

            IF gt_excluded_line_ids (gt_excluded_line_ids.LAST).line_id !=
               g_miss_num
            THEN
                gt_excluded_line_ids.EXTEND;
            END IF;

            gt_excluded_line_ids (gt_excluded_line_ids.LAST)   :=
                xxd_ont_elegible_line_obj (pn_line_id,
                                           pn_inventory_item_id,
                                           pn_priority);
            xxd_atp_customization_pkg.add_line_id_to_exclusion@BT_EBS_TO_ASCP.US.ORACLE.COM (
                pn_line_id);          -- Added the full DB name for CCR0009529
        END IF;

        COMMIT;
    END add_line_id_to_exclusion;

    PROCEDURE add_line_id_to_identified (pn_line_id IN NUMBER, pn_inventory_item_id NUMBER, pn_priority IN NUMBER:= 0)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ln_existing   NUMBER;
    BEGIN
        IF     pn_line_id IS NOT NULL
           AND pn_line_id > 0
           AND pn_line_id = TRUNC (pn_line_id)
        THEN
            msg ('Adding line_id (' || pn_line_id || ') to identified list');

            SELECT COUNT (*)
              INTO ln_existing
              FROM TABLE (gt_identified_line_ids)
             WHERE     line_id = pn_line_id
                   AND inventory_item_id = pn_inventory_item_id;

            IF ln_existing != 0
            THEN
                msg (
                       'Line_id ('
                    || pn_line_id
                    || ') already located in identified list');
                COMMIT;
                RETURN;
            END IF;

            IF gt_identified_line_ids (gt_identified_line_ids.LAST).line_id !=
               g_miss_num
            THEN
                gt_identified_line_ids.EXTEND;
            END IF;

            gt_identified_line_ids (gt_identified_line_ids.LAST)   :=
                xxd_ont_elegible_line_obj (pn_line_id,
                                           pn_inventory_item_id,
                                           pn_priority);
        END IF;

        COMMIT;
    END add_line_id_to_identified;

    PROCEDURE clear_excluded_line_ids
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        oe_sys_parameters_pvt.gc_override_split   := NULL;
        msg ('Clearing Excluded Bulk Line IDs');

        FOR rec IN (  SELECT *
                        FROM TABLE (gt_excluded_line_ids)
                    ORDER BY seq ASC)
        LOOP
            msg ('Clearing Line ID ' || rec.line_id);
        END LOOP;

        gt_excluded_line_ids.delete;
        gt_excluded_line_ids.EXTEND;
        gt_excluded_line_ids (gt_excluded_line_ids.LAST)   :=
            xxd_ont_elegible_line_obj (g_miss_num, g_miss_num);
        msg ('Clearing Identified Bulk Line IDs');

        FOR rec IN (  SELECT *
                        FROM TABLE (gt_identified_line_ids)
                    ORDER BY seq ASC)
        LOOP
            msg ('Clearing Line ID ' || rec.line_id);
        END LOOP;

        gt_identified_line_ids.delete;
        gt_identified_line_ids.EXTEND;
        gt_identified_line_ids (gt_identified_line_ids.LAST)   :=
            xxd_ont_elegible_line_obj (g_miss_num, g_miss_num);
        xxd_atp_customization_pkg.clear_excluded_line_ids@BT_EBS_TO_ASCP.US.ORACLE.COM (); -- Added the full DB name for CCR0009529
        xxd_debug_tools_pkg.clear_attributes;
        COMMIT;
    END clear_excluded_line_ids;

    FUNCTION is_identified_line (pn_line_id IN NUMBER)
        RETURN BOOLEAN
    AS
        ln_existing   NUMBER;
    BEGIN
        IF     pn_line_id IS NOT NULL
           AND pn_line_id > 0
           AND pn_line_id = TRUNC (pn_line_id)
        THEN
            SELECT COUNT (*)
              INTO ln_existing
              FROM TABLE (gt_identified_line_ids)
             WHERE line_id = pn_line_id;

            IF ln_existing != 0
            THEN
                msg (
                       'Line_id ('
                    || pn_line_id
                    || ') already located in identified list');
                RETURN TRUE;
            END IF;
        END IF;

        RETURN FALSE;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END is_identified_line;

    PROCEDURE collect_order_details (pr_order_line IN oe_order_lines_all%ROWTYPE, xr_header OUT oe_order_headers_all%ROWTYPE, xr_line_order_type OUT oe_transaction_types_all%ROWTYPE, xr_header_order_type OUT oe_transaction_types_all%ROWTYPE, xr_operating_unit OUT hr_all_organization_units%ROWTYPE, xr_inventory_org OUT mtl_parameters%ROWTYPE
                                     , xr_hz_cust_accounts OUT hz_cust_accounts%ROWTYPE, xr_hz_parties OUT hz_parties%ROWTYPE, xc_ret_stat OUT VARCHAR2)
    IS
        ln_line_id   NUMBER;
    BEGIN
        msg ('Begin order detail collection');
        xc_ret_stat   := g_ret_sts_success;
        ln_line_id    := pr_order_line.line_id;
        msg (
               'Line Details - order_source_id: '
            || pr_order_line.order_source_id
            || '. Org_id: '
            || pr_order_line.org_id
            || '. ship_from_org_id: '
            || pr_order_line.ship_from_org_id
            || '. line_type_id: '
            || pr_order_line.line_type_id
            || '. header_id: '
            || pr_order_line.header_id
            || '. order_type_id: '
            || xr_header.order_type_id
            || '. sold_to_org_id: '
            || xr_header.sold_to_org_id
            || '. party_id: '
            || xr_hz_cust_accounts.party_id);

        -- Set Split Flag based on Order Source
        BEGIN
            SELECT DECODE (name, 'Flagstaff', 'N', 'Y')
              INTO gc_split
              FROM oe_order_sources
             WHERE order_source_id = pr_order_line.order_source_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_split   := 'N';
        END;

        IF     pr_order_line.org_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_operating_unit
                  FROM hr_all_organization_units
                 WHERE organization_id = pr_order_line.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unable to locate org '
                        || pr_order_line.org_id
                        || ' something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                'Org is missing from both old and new records, something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        IF     pr_order_line.ship_from_org_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_inventory_org
                  FROM mtl_parameters
                 WHERE organization_id = pr_order_line.ship_from_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unable to locate inventory org '
                        || pr_order_line.ship_from_org_id
                        || ' something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                'Inventory org is missing from both old and new records, something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        IF     pr_order_line.line_type_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_line_order_type
                  FROM oe_transaction_types_all
                 WHERE transaction_type_id = pr_order_line.line_type_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unable to locate order type '
                        || pr_order_line.line_type_id
                        || ' something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                'Line type is missing from both old and new records, something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        IF     pr_order_line.header_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_header
                  FROM oe_order_headers_all
                 WHERE header_id = pr_order_line.header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Header ('
                        || pr_order_line.header_id
                        || ') something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                   'Header not populated in OOLA ('
                || pr_order_line.header_id
                || ') something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        IF     xr_header.order_type_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_header_order_type
                  FROM oe_transaction_types_all
                 WHERE transaction_type_id = xr_header.order_type_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unable to locate order type '
                        || xr_header.order_type_id
                        || ' something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                   'Header Order type is not populated in OOHA '
                || xr_header.header_id
                || ', something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        IF     xr_header.sold_to_org_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_hz_cust_accounts
                  FROM hz_cust_accounts
                 WHERE cust_account_id = xr_header.sold_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unable to locate cust_account_id '
                        || xr_header.sold_to_org_id
                        || ' something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                   'Header sold_to_org_id is not populated in OOHA '
                || xr_header.header_id
                || ', something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        IF     xr_hz_cust_accounts.party_id IS NOT NULL
           AND xc_ret_stat = g_ret_sts_success
        THEN
            BEGIN
                SELECT *
                  INTO xr_hz_parties
                  FROM hz_parties
                 WHERE party_id = xr_hz_cust_accounts.party_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unable to locate party_id '
                        || xr_hz_cust_accounts.party_id
                        || ' something is very wrong!',
                        2);
                    xc_ret_stat   := g_ret_sts_error;
                    RETURN;
            END;
        ELSE
            msg (
                   'Header party_id is not populated in hz_cust_accounts '
                || xr_hz_cust_accounts.cust_account_id
                || ', something is very wrong!',
                2);
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;

        msg ('End order detail collection');
    EXCEPTION
        WHEN OTHERS
        THEN
            xc_ret_stat   := g_ret_sts_unexp_error;

            BEGIN
                msg ('Something went very wrong! (' || SQLERRM || ')', 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
    END collect_order_details;

    FUNCTION check_valid_order (pr_line IN oe_order_lines_all%ROWTYPE)
        RETURN VARCHAR2
    AS
        lc_flag   VARCHAR2 (1) := 'N';
    BEGIN
        -- Exit if it is a Return Order
        IF pr_line.line_category_code = 'RETURN'
        THEN
            g_consumption_flag   := FALSE;
            lc_flag              := 'N';
            msg ('Return Order. Consumption can be skipped');
        ELSE
            -- Exit if it is not a Calloff Order
            SELECT DECODE (COUNT (1), 0, 'N', 'Y')
              INTO lc_flag
              FROM oe_order_headers_all ooha, oe_transaction_types_all otta, xxdo.xxd_ont_consumption_rules_t xxd
             WHERE     ooha.order_type_id = otta.transaction_type_id
                   AND ooha.order_type_id = xxd.calloff_order_type_id
                   AND otta.attribute5 = 'CO'
                   AND ooha.header_id = pr_line.header_id;

            IF lc_flag = 'N'
            THEN
                g_consumption_flag   := FALSE;
            END IF;
        END IF;

        msg ('Calloff Order Flag = ' || lc_flag);
        RETURN lc_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END check_valid_order;

    PROCEDURE store_info (p_line_rec IN oe_order_lines_all%ROWTYPE)
    IS
        lr_line                oe_order_lines_all%ROWTYPE := p_line_rec;
        lr_header              oe_order_headers_all%ROWTYPE;
        lr_line_order_type     oe_transaction_types_all%ROWTYPE;
        lr_header_order_type   oe_transaction_types_all%ROWTYPE;
        lr_operating_unit      hr_all_organization_units%ROWTYPE;
        lr_inventory_org       mtl_parameters%ROWTYPE;
        lr_hz_parties          hz_parties%ROWTYPE;
        lr_hz_cust_accounts    hz_cust_accounts%ROWTYPE;
        lt_eligable_lines      xxd_ont_elegible_lines_t_obj;
        lc_ret_stat            VARCHAR2 (1);
        ln_index               NUMBER := 0;
    BEGIN
        IF check_valid_order (p_line_rec) = 'N'
        THEN
            RETURN;
        END IF;

        xxd_debug_tools_pkg.set_attributes (1, p_line_rec.header_id);
        xxd_debug_tools_pkg.set_attributes (2, p_line_rec.line_id);
        xxd_debug_tools_pkg.set_attributes (3, p_line_rec.org_id);
        sync_exclusion;
        add_line_id_to_identified (p_line_rec.line_id,
                                   p_line_rec.inventory_item_id);
        msg (
               'Received Request to store Bulk info using rowtype for line_id ('
            || p_line_rec.line_id
            || ')');

        collect_order_details (pr_order_line          => lr_line,
                               xr_header              => lr_header,
                               xr_line_order_type     => lr_line_order_type,
                               xr_header_order_type   => lr_header_order_type,
                               xr_operating_unit      => lr_operating_unit,
                               xr_inventory_org       => lr_inventory_org,
                               xr_hz_cust_accounts    => lr_hz_cust_accounts,
                               xr_hz_parties          => lr_hz_parties,
                               xc_ret_stat            => lc_ret_stat);

        msg ('Calling bulk rules');
        xxd_ont_bulk_rules_pkg.get_eligible_bulk_lines (
            pr_line                => lr_line,
            pr_header              => lr_header,
            pr_line_order_type     => lr_line_order_type,
            pr_header_order_type   => lr_header_order_type,
            pr_operating_unit      => lr_operating_unit,
            pr_inventory_org       => lr_inventory_org,
            pr_hz_cust_accounts    => lr_hz_cust_accounts,
            pr_hz_parties          => lr_hz_parties,
            xt_eligible_lines      => lt_eligable_lines,
            xc_ret_stat            => lc_ret_stat);
        msg (
               'Bulk rules returned ('
            || lt_eligable_lines.COUNT
            || ') eligable lines');

        IF lt_eligable_lines.COUNT > 0
        THEN
            FOR rec IN (  SELECT *
                            FROM TABLE (lt_eligable_lines)
                        ORDER BY seq ASC)
            LOOP
                ln_index   := ln_index + 1;
                add_line_id_to_exclusion (
                    pn_line_id             => rec.line_id,
                    pn_inventory_item_id   => rec.inventory_item_id,
                    pn_priority            => ln_index);
            END LOOP;
        ELSE
            msg ('Found no eligable bulk lines to exclude');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('store_info caused an unhandled exception ' || SQLERRM, 1);
            RAISE;
    END store_info;

    PROCEDURE store_info (
        p_line_rec       IN apps.oe_order_pub.line_rec_type,
        p_old_line_rec   IN apps.oe_order_pub.line_rec_type)
    IS
        lr_line   oe_order_lines_all%ROWTYPE;
    BEGIN
        msg (
            'Received Request to store Bulk info using oe_order_pub line types');

        IF gc_no_unconsumption = 'Y'
        THEN
            RETURN;
        END IF;

        IF 1 = 1
        THEN                -- using this to hide generated mapping statements
            --select '  lr_line.'||column_name||' := p_line_rec.'||column_name||';'  from all_tab_columns where owner = 'ONT' and table_name = 'OE_ORDER_LINES_ALL' order by column_id asc
            lr_line.line_id                          := p_line_rec.line_id;
            lr_line.org_id                           := p_line_rec.org_id;
            lr_line.header_id                        := p_line_rec.header_id;
            lr_line.line_type_id                     := p_line_rec.line_type_id;
            lr_line.line_number                      := p_line_rec.line_number;
            lr_line.ordered_item                     := p_line_rec.ordered_item;
            lr_line.request_date                     := p_line_rec.request_date;
            lr_line.promise_date                     := p_line_rec.promise_date;
            lr_line.schedule_ship_date               := p_line_rec.schedule_ship_date;
            lr_line.order_quantity_uom               := p_line_rec.order_quantity_uom;
            lr_line.pricing_quantity                 := p_line_rec.pricing_quantity;
            lr_line.pricing_quantity_uom             := p_line_rec.pricing_quantity_uom;
            lr_line.cancelled_quantity               := p_line_rec.cancelled_quantity;
            lr_line.shipped_quantity                 := p_line_rec.shipped_quantity;
            lr_line.ordered_quantity                 := p_line_rec.ordered_quantity;
            lr_line.fulfilled_quantity               := p_line_rec.fulfilled_quantity;
            lr_line.shipping_quantity                := p_line_rec.shipping_quantity;
            lr_line.shipping_quantity_uom            :=
                p_line_rec.shipping_quantity_uom;
            lr_line.delivery_lead_time               := p_line_rec.delivery_lead_time;
            lr_line.tax_exempt_flag                  := p_line_rec.tax_exempt_flag;
            lr_line.tax_exempt_number                := p_line_rec.tax_exempt_number;
            lr_line.tax_exempt_reason_code           :=
                p_line_rec.tax_exempt_reason_code;
            lr_line.ship_from_org_id                 := p_line_rec.ship_from_org_id;
            lr_line.ship_to_org_id                   := p_line_rec.ship_to_org_id;
            lr_line.invoice_to_org_id                := p_line_rec.invoice_to_org_id;
            lr_line.deliver_to_org_id                := p_line_rec.deliver_to_org_id;
            lr_line.ship_to_contact_id               := p_line_rec.ship_to_contact_id;
            lr_line.deliver_to_contact_id            :=
                p_line_rec.deliver_to_contact_id;
            lr_line.invoice_to_contact_id            :=
                p_line_rec.invoice_to_contact_id;
            --  lr_line.intmed_ship_to_org_id := p_line_rec.intmed_ship_to_org_id;
            --lr_line.intmed_ship_to_contact_id := p_line_rec.intmed_ship_to_contact_id;
            lr_line.sold_from_org_id                 := p_line_rec.sold_from_org_id;
            lr_line.sold_to_org_id                   := p_line_rec.sold_to_org_id;
            lr_line.cust_po_number                   := p_line_rec.cust_po_number;
            lr_line.ship_tolerance_above             :=
                p_line_rec.ship_tolerance_above;
            lr_line.ship_tolerance_below             :=
                p_line_rec.ship_tolerance_below;
            lr_line.demand_bucket_type_code          :=
                p_line_rec.demand_bucket_type_code;
            lr_line.veh_cus_item_cum_key_id          :=
                p_line_rec.veh_cus_item_cum_key_id;
            lr_line.rla_schedule_type_code           :=
                p_line_rec.rla_schedule_type_code;
            lr_line.customer_dock_code               :=
                p_line_rec.customer_dock_code;
            lr_line.customer_job                     := p_line_rec.customer_job;
            lr_line.customer_production_line         :=
                p_line_rec.customer_production_line;
            lr_line.cust_model_serial_number         :=
                p_line_rec.cust_model_serial_number;
            lr_line.project_id                       := p_line_rec.project_id;
            lr_line.task_id                          := p_line_rec.task_id;
            lr_line.inventory_item_id                :=
                p_line_rec.inventory_item_id;
            lr_line.tax_date                         := p_line_rec.tax_date;
            lr_line.tax_code                         := p_line_rec.tax_code;
            lr_line.tax_rate                         := p_line_rec.tax_rate;
            lr_line.invoice_interface_status_code    :=
                p_line_rec.invoice_interface_status_code;
            lr_line.demand_class_code                :=
                p_line_rec.demand_class_code;
            lr_line.price_list_id                    :=
                p_line_rec.price_list_id;
            lr_line.pricing_date                     :=
                p_line_rec.pricing_date;
            lr_line.shipment_number                  :=
                p_line_rec.shipment_number;
            lr_line.agreement_id                     :=
                p_line_rec.agreement_id;
            lr_line.shipment_priority_code           :=
                p_line_rec.shipment_priority_code;
            lr_line.shipping_method_code             :=
                p_line_rec.shipping_method_code;
            lr_line.freight_carrier_code             :=
                p_line_rec.freight_carrier_code;
            lr_line.freight_terms_code               :=
                p_line_rec.freight_terms_code;
            lr_line.fob_point_code                   :=
                p_line_rec.fob_point_code;
            lr_line.tax_point_code                   :=
                p_line_rec.tax_point_code;
            lr_line.payment_term_id                  :=
                p_line_rec.payment_term_id;
            lr_line.invoicing_rule_id                :=
                p_line_rec.invoicing_rule_id;
            lr_line.accounting_rule_id               :=
                p_line_rec.accounting_rule_id;
            lr_line.source_document_type_id          :=
                p_line_rec.source_document_type_id;
            lr_line.orig_sys_document_ref            :=
                p_line_rec.orig_sys_document_ref;
            lr_line.source_document_id               :=
                p_line_rec.source_document_id;
            lr_line.orig_sys_line_ref                :=
                p_line_rec.orig_sys_line_ref;
            lr_line.source_document_line_id          :=
                p_line_rec.source_document_line_id;
            lr_line.reference_line_id                :=
                p_line_rec.reference_line_id;
            lr_line.reference_type                   :=
                p_line_rec.reference_type;
            lr_line.reference_header_id              :=
                p_line_rec.reference_header_id;
            lr_line.item_revision                    :=
                p_line_rec.item_revision;
            lr_line.unit_selling_price               :=
                p_line_rec.unit_selling_price;
            lr_line.unit_list_price                  :=
                p_line_rec.unit_list_price;
            lr_line.tax_value                        := p_line_rec.tax_value;
            lr_line.context                          := p_line_rec.context;
            lr_line.attribute1                       := p_line_rec.attribute1;
            lr_line.attribute2                       := p_line_rec.attribute2;
            lr_line.attribute3                       := p_line_rec.attribute3;
            lr_line.attribute4                       := p_line_rec.attribute4;
            lr_line.attribute5                       := p_line_rec.attribute5;
            lr_line.attribute6                       := p_line_rec.attribute6;
            lr_line.attribute7                       := p_line_rec.attribute7;
            lr_line.attribute8                       := p_line_rec.attribute8;
            lr_line.attribute9                       := p_line_rec.attribute9;
            lr_line.attribute10                      := p_line_rec.attribute10;
            lr_line.attribute11                      := p_line_rec.attribute11;
            lr_line.attribute12                      := p_line_rec.attribute12;
            lr_line.attribute13                      := p_line_rec.attribute13;
            lr_line.attribute14                      := p_line_rec.attribute14;
            lr_line.attribute15                      := p_line_rec.attribute15;
            lr_line.global_attribute_category        :=
                p_line_rec.global_attribute_category;
            lr_line.global_attribute1                :=
                p_line_rec.global_attribute1;
            lr_line.global_attribute2                :=
                p_line_rec.global_attribute2;
            lr_line.global_attribute3                :=
                p_line_rec.global_attribute3;
            lr_line.global_attribute4                :=
                p_line_rec.global_attribute4;
            lr_line.global_attribute5                :=
                p_line_rec.global_attribute5;
            lr_line.global_attribute6                :=
                p_line_rec.global_attribute6;
            lr_line.global_attribute7                :=
                p_line_rec.global_attribute7;
            lr_line.global_attribute8                :=
                p_line_rec.global_attribute8;
            lr_line.global_attribute9                :=
                p_line_rec.global_attribute9;
            lr_line.global_attribute10               :=
                p_line_rec.global_attribute10;
            lr_line.global_attribute11               :=
                p_line_rec.global_attribute11;
            lr_line.global_attribute12               :=
                p_line_rec.global_attribute12;
            lr_line.global_attribute13               :=
                p_line_rec.global_attribute13;
            lr_line.global_attribute14               :=
                p_line_rec.global_attribute14;
            lr_line.global_attribute15               :=
                p_line_rec.global_attribute15;
            lr_line.global_attribute16               :=
                p_line_rec.global_attribute16;
            lr_line.global_attribute17               :=
                p_line_rec.global_attribute17;
            lr_line.global_attribute18               :=
                p_line_rec.global_attribute18;
            lr_line.global_attribute19               :=
                p_line_rec.global_attribute19;
            lr_line.global_attribute20               :=
                p_line_rec.global_attribute20;
            lr_line.pricing_context                  :=
                p_line_rec.pricing_context;
            lr_line.pricing_attribute1               :=
                p_line_rec.pricing_attribute1;
            lr_line.pricing_attribute2               :=
                p_line_rec.pricing_attribute2;
            lr_line.pricing_attribute3               :=
                p_line_rec.pricing_attribute3;
            lr_line.pricing_attribute4               :=
                p_line_rec.pricing_attribute4;
            lr_line.pricing_attribute5               :=
                p_line_rec.pricing_attribute5;
            lr_line.pricing_attribute6               :=
                p_line_rec.pricing_attribute6;
            lr_line.pricing_attribute7               :=
                p_line_rec.pricing_attribute7;
            lr_line.pricing_attribute8               :=
                p_line_rec.pricing_attribute8;
            lr_line.pricing_attribute9               :=
                p_line_rec.pricing_attribute9;
            lr_line.pricing_attribute10              :=
                p_line_rec.pricing_attribute10;
            lr_line.industry_context                 :=
                p_line_rec.industry_context;
            lr_line.industry_attribute1              :=
                p_line_rec.industry_attribute1;
            lr_line.industry_attribute2              :=
                p_line_rec.industry_attribute2;
            lr_line.industry_attribute3              :=
                p_line_rec.industry_attribute3;
            lr_line.industry_attribute4              :=
                p_line_rec.industry_attribute4;
            lr_line.industry_attribute5              :=
                p_line_rec.industry_attribute5;
            lr_line.industry_attribute6              :=
                p_line_rec.industry_attribute6;
            lr_line.industry_attribute7              :=
                p_line_rec.industry_attribute7;
            lr_line.industry_attribute8              :=
                p_line_rec.industry_attribute8;
            lr_line.industry_attribute9              :=
                p_line_rec.industry_attribute9;
            lr_line.industry_attribute10             :=
                p_line_rec.industry_attribute10;
            lr_line.industry_attribute11             :=
                p_line_rec.industry_attribute11;
            lr_line.industry_attribute13             :=
                p_line_rec.industry_attribute13;
            lr_line.industry_attribute12             :=
                p_line_rec.industry_attribute12;
            lr_line.industry_attribute14             :=
                p_line_rec.industry_attribute14;
            lr_line.industry_attribute15             :=
                p_line_rec.industry_attribute15;
            lr_line.industry_attribute16             :=
                p_line_rec.industry_attribute16;
            lr_line.industry_attribute17             :=
                p_line_rec.industry_attribute17;
            lr_line.industry_attribute18             :=
                p_line_rec.industry_attribute18;
            lr_line.industry_attribute19             :=
                p_line_rec.industry_attribute19;
            lr_line.industry_attribute20             :=
                p_line_rec.industry_attribute20;
            lr_line.industry_attribute21             :=
                p_line_rec.industry_attribute21;
            lr_line.industry_attribute22             :=
                p_line_rec.industry_attribute22;
            lr_line.industry_attribute23             :=
                p_line_rec.industry_attribute23;
            lr_line.industry_attribute24             :=
                p_line_rec.industry_attribute24;
            lr_line.industry_attribute25             :=
                p_line_rec.industry_attribute25;
            lr_line.industry_attribute26             :=
                p_line_rec.industry_attribute26;
            lr_line.industry_attribute27             :=
                p_line_rec.industry_attribute27;
            lr_line.industry_attribute28             :=
                p_line_rec.industry_attribute28;
            lr_line.industry_attribute29             :=
                p_line_rec.industry_attribute29;
            lr_line.industry_attribute30             :=
                p_line_rec.industry_attribute30;
            lr_line.creation_date                    :=
                p_line_rec.creation_date;
            lr_line.created_by                       := p_line_rec.created_by;
            lr_line.last_update_date                 :=
                p_line_rec.last_update_date;
            lr_line.last_updated_by                  :=
                p_line_rec.last_updated_by;
            lr_line.last_update_login                :=
                p_line_rec.last_update_login;
            lr_line.program_application_id           :=
                p_line_rec.program_application_id;
            lr_line.program_id                       := p_line_rec.program_id;
            lr_line.program_update_date              :=
                p_line_rec.program_update_date;
            lr_line.request_id                       := p_line_rec.request_id;
            lr_line.top_model_line_id                :=
                p_line_rec.top_model_line_id;
            lr_line.link_to_line_id                  :=
                p_line_rec.link_to_line_id;
            lr_line.component_sequence_id            :=
                p_line_rec.component_sequence_id;
            lr_line.component_code                   :=
                p_line_rec.component_code;
            lr_line.config_display_sequence          :=
                p_line_rec.config_display_sequence;
            lr_line.sort_order                       := p_line_rec.sort_order;
            lr_line.item_type_code                   :=
                p_line_rec.item_type_code;
            lr_line.option_number                    :=
                p_line_rec.option_number;
            lr_line.option_flag                      := p_line_rec.option_flag;
            lr_line.dep_plan_required_flag           :=
                p_line_rec.dep_plan_required_flag;
            lr_line.visible_demand_flag              :=
                p_line_rec.visible_demand_flag;
            lr_line.line_category_code               :=
                p_line_rec.line_category_code;
            lr_line.actual_shipment_date             :=
                p_line_rec.actual_shipment_date;
            lr_line.customer_trx_line_id             :=
                p_line_rec.customer_trx_line_id;
            lr_line.return_context                   :=
                p_line_rec.return_context;
            lr_line.return_attribute1                :=
                p_line_rec.return_attribute1;
            lr_line.return_attribute2                :=
                p_line_rec.return_attribute2;
            lr_line.return_attribute3                :=
                p_line_rec.return_attribute3;
            lr_line.return_attribute4                :=
                p_line_rec.return_attribute4;
            lr_line.return_attribute5                :=
                p_line_rec.return_attribute5;
            lr_line.return_attribute6                :=
                p_line_rec.return_attribute6;
            lr_line.return_attribute7                :=
                p_line_rec.return_attribute7;
            lr_line.return_attribute8                :=
                p_line_rec.return_attribute8;
            lr_line.return_attribute9                :=
                p_line_rec.return_attribute9;
            lr_line.return_attribute10               :=
                p_line_rec.return_attribute10;
            lr_line.return_attribute11               :=
                p_line_rec.return_attribute11;
            lr_line.return_attribute12               :=
                p_line_rec.return_attribute12;
            lr_line.return_attribute13               :=
                p_line_rec.return_attribute13;
            lr_line.return_attribute14               :=
                p_line_rec.return_attribute14;
            lr_line.return_attribute15               :=
                p_line_rec.return_attribute15;
            lr_line.actual_arrival_date              :=
                p_line_rec.actual_arrival_date;
            lr_line.ato_line_id                      := p_line_rec.ato_line_id;
            lr_line.auto_selected_quantity           :=
                p_line_rec.auto_selected_quantity;
            lr_line.component_number                 :=
                p_line_rec.component_number;
            lr_line.earliest_acceptable_date         :=
                p_line_rec.earliest_acceptable_date;
            lr_line.explosion_date                   :=
                p_line_rec.explosion_date;
            lr_line.latest_acceptable_date           :=
                p_line_rec.latest_acceptable_date;
            lr_line.model_group_number               :=
                p_line_rec.model_group_number;
            lr_line.schedule_arrival_date            :=
                p_line_rec.schedule_arrival_date;
            lr_line.ship_model_complete_flag         :=
                p_line_rec.ship_model_complete_flag;
            lr_line.schedule_status_code             :=
                p_line_rec.schedule_status_code;
            lr_line.source_type_code                 :=
                p_line_rec.source_type_code;
            lr_line.cancelled_flag                   :=
                p_line_rec.cancelled_flag;
            lr_line.open_flag                        := p_line_rec.open_flag;
            lr_line.booked_flag                      := p_line_rec.booked_flag;
            lr_line.salesrep_id                      := p_line_rec.salesrep_id;
            lr_line.return_reason_code               :=
                p_line_rec.return_reason_code;
            lr_line.arrival_set_id                   :=
                p_line_rec.arrival_set_id;
            lr_line.ship_set_id                      := p_line_rec.ship_set_id;
            lr_line.split_from_line_id               :=
                p_line_rec.split_from_line_id;
            lr_line.cust_production_seq_num          :=
                p_line_rec.cust_production_seq_num;
            lr_line.authorized_to_ship_flag          :=
                p_line_rec.authorized_to_ship_flag;
            lr_line.over_ship_reason_code            :=
                p_line_rec.over_ship_reason_code;
            lr_line.over_ship_resolved_flag          :=
                p_line_rec.over_ship_resolved_flag;
            lr_line.ordered_item_id                  :=
                p_line_rec.ordered_item_id;
            lr_line.item_identifier_type             :=
                p_line_rec.item_identifier_type;
            lr_line.configuration_id                 :=
                p_line_rec.configuration_id;
            lr_line.commitment_id                    :=
                p_line_rec.commitment_id;
            lr_line.shipping_interfaced_flag         :=
                p_line_rec.shipping_interfaced_flag;
            lr_line.credit_invoice_line_id           :=
                p_line_rec.credit_invoice_line_id;
            lr_line.first_ack_code                   :=
                p_line_rec.first_ack_code;
            lr_line.first_ack_date                   :=
                p_line_rec.first_ack_date;
            lr_line.last_ack_code                    :=
                p_line_rec.last_ack_code;
            lr_line.last_ack_date                    :=
                p_line_rec.last_ack_date;
            lr_line.planning_priority                :=
                p_line_rec.planning_priority;
            lr_line.order_source_id                  :=
                p_line_rec.order_source_id;
            lr_line.orig_sys_shipment_ref            :=
                p_line_rec.orig_sys_shipment_ref;
            lr_line.change_sequence                  :=
                p_line_rec.change_sequence;
            lr_line.drop_ship_flag                   :=
                p_line_rec.drop_ship_flag;
            lr_line.customer_line_number             :=
                p_line_rec.customer_line_number;
            lr_line.customer_shipment_number         :=
                p_line_rec.customer_shipment_number;
            lr_line.customer_item_net_price          :=
                p_line_rec.customer_item_net_price;
            lr_line.customer_payment_term_id         :=
                p_line_rec.customer_payment_term_id;
            lr_line.fulfilled_flag                   :=
                p_line_rec.fulfilled_flag;
            lr_line.end_item_unit_number             :=
                p_line_rec.end_item_unit_number;
            lr_line.config_header_id                 :=
                p_line_rec.config_header_id;
            lr_line.config_rev_nbr                   :=
                p_line_rec.config_rev_nbr;
            lr_line.mfg_component_sequence_id        :=
                p_line_rec.mfg_component_sequence_id;
            lr_line.shipping_instructions            :=
                p_line_rec.shipping_instructions;
            lr_line.packing_instructions             :=
                p_line_rec.packing_instructions;
            lr_line.invoiced_quantity                :=
                p_line_rec.invoiced_quantity;
            lr_line.reference_customer_trx_line_id   :=
                p_line_rec.reference_customer_trx_line_id;
            lr_line.split_by                         := p_line_rec.split_by;
            lr_line.line_set_id                      :=
                p_line_rec.line_set_id;
            lr_line.service_txn_reason_code          :=
                p_line_rec.service_txn_reason_code;
            lr_line.service_txn_comments             :=
                p_line_rec.service_txn_comments;
            lr_line.service_duration                 :=
                p_line_rec.service_duration;
            lr_line.service_start_date               :=
                p_line_rec.service_start_date;
            lr_line.service_end_date                 :=
                p_line_rec.service_end_date;
            lr_line.service_coterminate_flag         :=
                p_line_rec.service_coterminate_flag;
            lr_line.unit_list_percent                :=
                p_line_rec.unit_list_percent;
            lr_line.unit_selling_percent             :=
                p_line_rec.unit_selling_percent;
            lr_line.unit_percent_base_price          :=
                p_line_rec.unit_percent_base_price;
            lr_line.service_number                   :=
                p_line_rec.service_number;
            lr_line.service_period                   :=
                p_line_rec.service_period;
            lr_line.shippable_flag                   :=
                p_line_rec.shippable_flag;
            lr_line.model_remnant_flag               :=
                p_line_rec.model_remnant_flag;
            lr_line.re_source_flag                   :=
                p_line_rec.re_source_flag;
            lr_line.flow_status_code                 :=
                p_line_rec.flow_status_code;
            lr_line.tp_context                       := p_line_rec.tp_context;
            lr_line.tp_attribute1                    :=
                p_line_rec.tp_attribute1;
            lr_line.tp_attribute2                    :=
                p_line_rec.tp_attribute2;
            lr_line.tp_attribute3                    :=
                p_line_rec.tp_attribute3;
            lr_line.tp_attribute4                    :=
                p_line_rec.tp_attribute4;
            lr_line.tp_attribute5                    :=
                p_line_rec.tp_attribute5;
            lr_line.tp_attribute6                    :=
                p_line_rec.tp_attribute6;
            lr_line.tp_attribute7                    :=
                p_line_rec.tp_attribute7;
            lr_line.tp_attribute8                    :=
                p_line_rec.tp_attribute8;
            lr_line.tp_attribute9                    :=
                p_line_rec.tp_attribute9;
            lr_line.tp_attribute10                   :=
                p_line_rec.tp_attribute10;
            lr_line.tp_attribute11                   :=
                p_line_rec.tp_attribute11;
            lr_line.tp_attribute12                   :=
                p_line_rec.tp_attribute12;
            lr_line.tp_attribute13                   :=
                p_line_rec.tp_attribute13;
            lr_line.tp_attribute14                   :=
                p_line_rec.tp_attribute14;
            lr_line.tp_attribute15                   :=
                p_line_rec.tp_attribute15;
            lr_line.fulfillment_method_code          :=
                p_line_rec.fulfillment_method_code;
            lr_line.marketing_source_code_id         :=
                p_line_rec.marketing_source_code_id;
            lr_line.service_reference_type_code      :=
                p_line_rec.service_reference_type_code;
            lr_line.service_reference_line_id        :=
                p_line_rec.service_reference_line_id;
            lr_line.service_reference_system_id      :=
                p_line_rec.service_reference_system_id;
            lr_line.calculate_price_flag             :=
                p_line_rec.calculate_price_flag;
            lr_line.upgraded_flag                    :=
                p_line_rec.upgraded_flag;
            lr_line.revenue_amount                   :=
                p_line_rec.revenue_amount;
            lr_line.fulfillment_date                 :=
                p_line_rec.fulfillment_date;
            lr_line.preferred_grade                  :=
                p_line_rec.preferred_grade;
            lr_line.ordered_quantity2                :=
                p_line_rec.ordered_quantity2;
            lr_line.ordered_quantity_uom2            :=
                p_line_rec.ordered_quantity_uom2;
            lr_line.shipping_quantity2               :=
                p_line_rec.shipping_quantity2;
            lr_line.cancelled_quantity2              :=
                p_line_rec.cancelled_quantity2;
            lr_line.shipped_quantity2                :=
                p_line_rec.shipped_quantity2;
            lr_line.shipping_quantity_uom2           :=
                p_line_rec.shipping_quantity_uom2;
            lr_line.fulfilled_quantity2              :=
                p_line_rec.fulfilled_quantity2;
            lr_line.mfg_lead_time                    :=
                p_line_rec.mfg_lead_time;
            lr_line.lock_control                     :=
                p_line_rec.lock_control;
            lr_line.subinventory                     :=
                p_line_rec.subinventory;
            lr_line.unit_list_price_per_pqty         :=
                p_line_rec.unit_list_price_per_pqty;
            lr_line.unit_selling_price_per_pqty      :=
                p_line_rec.unit_selling_price_per_pqty;
            lr_line.price_request_code               :=
                p_line_rec.price_request_code;
            lr_line.original_inventory_item_id       :=
                p_line_rec.original_inventory_item_id;
            lr_line.original_ordered_item_id         :=
                p_line_rec.original_ordered_item_id;
            lr_line.original_ordered_item            :=
                p_line_rec.original_ordered_item;
            lr_line.original_item_identifier_type    :=
                p_line_rec.original_item_identifier_type;
            lr_line.item_substitution_type_code      :=
                p_line_rec.item_substitution_type_code;
            lr_line.override_atp_date_code           :=
                p_line_rec.override_atp_date_code;
            lr_line.late_demand_penalty_factor       :=
                p_line_rec.late_demand_penalty_factor;
            lr_line.accounting_rule_duration         :=
                p_line_rec.accounting_rule_duration;
            lr_line.attribute16                      :=
                p_line_rec.attribute16;
            lr_line.attribute17                      :=
                p_line_rec.attribute17;
            lr_line.attribute18                      :=
                p_line_rec.attribute18;
            lr_line.attribute19                      :=
                p_line_rec.attribute19;
            lr_line.attribute20                      :=
                p_line_rec.attribute20;
            lr_line.user_item_description            :=
                p_line_rec.user_item_description;
            lr_line.unit_cost                        := p_line_rec.unit_cost;
            lr_line.item_relationship_type           :=
                p_line_rec.item_relationship_type;
            lr_line.blanket_line_number              :=
                p_line_rec.blanket_line_number;
            lr_line.blanket_number                   :=
                p_line_rec.blanket_number;
            lr_line.blanket_version_number           :=
                p_line_rec.blanket_version_number;
            --  lr_line.sales_document_type_code := p_line_rec.sales_document_type_code;
            lr_line.firm_demand_flag                 :=
                p_line_rec.firm_demand_flag;
            lr_line.earliest_ship_date               :=
                p_line_rec.earliest_ship_date;
            lr_line.transaction_phase_code           :=
                p_line_rec.transaction_phase_code;
            lr_line.source_document_version_number   :=
                p_line_rec.source_document_version_number;
            --  lr_line.payment_type_code := p_line_rec.payment_type_code;
            lr_line.minisite_id                      :=
                p_line_rec.minisite_id;
            lr_line.end_customer_id                  :=
                p_line_rec.end_customer_id;
            lr_line.end_customer_contact_id          :=
                p_line_rec.end_customer_contact_id;
            lr_line.end_customer_site_use_id         :=
                p_line_rec.end_customer_site_use_id;
            lr_line.ib_owner                         := p_line_rec.ib_owner;
            lr_line.ib_current_location              :=
                p_line_rec.ib_current_location;
            lr_line.ib_installed_at_location         :=
                p_line_rec.ib_installed_at_location;
            lr_line.retrobill_request_id             :=
                p_line_rec.retrobill_request_id;
            lr_line.original_list_price              :=
                p_line_rec.original_list_price;
            --  lr_line.service_credit_eligible_code := p_line_rec.service_credit_eligible_code;
            lr_line.order_firmed_date                :=
                p_line_rec.order_firmed_date;
            lr_line.actual_fulfillment_date          :=
                p_line_rec.actual_fulfillment_date;
            lr_line.charge_periodicity_code          :=
                p_line_rec.charge_periodicity_code;
            lr_line.contingency_id                   :=
                p_line_rec.contingency_id;
            lr_line.revrec_event_code                :=
                p_line_rec.revrec_event_code;
            lr_line.revrec_expiration_days           :=
                p_line_rec.revrec_expiration_days;
            lr_line.accepted_quantity                :=
                p_line_rec.accepted_quantity;
            lr_line.accepted_by                      :=
                p_line_rec.accepted_by;
            lr_line.revrec_comments                  :=
                p_line_rec.revrec_comments;
            lr_line.revrec_reference_document        :=
                p_line_rec.revrec_reference_document;
            lr_line.revrec_signature                 :=
                p_line_rec.revrec_signature;
            lr_line.revrec_signature_date            :=
                p_line_rec.revrec_signature_date;
            lr_line.revrec_implicit_flag             :=
                p_line_rec.revrec_implicit_flag;
            lr_line.bypass_sch_flag                  :=
                p_line_rec.bypass_sch_flag;
            lr_line.pre_exploded_flag                :=
                p_line_rec.pre_exploded_flag;
            --  lr_line.inst_id := p_line_rec.inst_id;
            --  lr_line.tax_line_value := p_line_rec.tax_line_value;
            lr_line.service_bill_profile_id          :=
                p_line_rec.service_bill_profile_id;
            lr_line.service_cov_template_id          :=
                p_line_rec.service_cov_template_id;
            lr_line.service_subs_template_id         :=
                p_line_rec.service_subs_template_id;
            lr_line.service_bill_option_code         :=
                p_line_rec.service_bill_option_code;
            lr_line.service_first_period_amount      :=
                p_line_rec.service_first_period_amount;
            lr_line.service_first_period_enddate     :=
                p_line_rec.service_first_period_enddate;
            lr_line.subscription_enable_flag         :=
                p_line_rec.subscription_enable_flag;
            lr_line.fulfillment_base                 :=
                p_line_rec.fulfillment_base;
            lr_line.container_number                 :=
                p_line_rec.container_number;
            lr_line.equipment_id                     :=
                p_line_rec.equipment_id;
        -- endregion generated code
        END IF;

        store_info (p_line_rec => lr_line);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('store_info caused an unhandled exception ' || SQLERRM, 1);
    END store_info;

    FUNCTION consumption_to_string (
        pt_consumption xxd_ont_consumption_line_t_obj)
        RETURN VARCHAR
    IS
        ln_idx      NUMBER;
        lc_string   oe_order_lines_all.global_attribute19%TYPE := NULL;
        lc_buffer   oe_order_lines_all.global_attribute19%TYPE := NULL;
    BEGIN
        msg ('Consumption count: ' || pt_consumption.COUNT);

        IF pt_consumption.COUNT > 0
        THEN
            ln_idx   := pt_consumption.FIRST;

            WHILE ln_idx IS NOT NULL
            LOOP
                IF     pt_consumption (ln_idx).line_id IS NOT NULL
                   AND pt_consumption (ln_idx).quantity IS NOT NULL
                   AND pt_consumption (ln_idx).line_id != g_miss_num
                   AND pt_consumption (ln_idx).quantity != g_miss_num
                   AND pt_consumption (ln_idx).quantity > 0
                THEN
                    lc_buffer   :=
                           pt_consumption (ln_idx).line_id
                        || '-'
                        || pt_consumption (ln_idx).quantity
                        || ';';

                    IF   NVL (LENGTH (lc_buffer), 0)
                       + NVL (LENGTH (lc_string), 0) <=
                       240
                    THEN
                        lc_string   := lc_string || lc_buffer;
                    END IF;
                END IF;

                ln_idx   := pt_consumption.NEXT (ln_idx);
            END LOOP;
        END IF;

        msg ('Consumption string returned: ' || lc_string);
        RETURN lc_string;
    END consumption_to_string;

    FUNCTION string_to_consumption (pc_consumption VARCHAR2)
        RETURN xxd_ont_consumption_line_t_obj
    IS
        ln_string     oe_order_lines_all.global_attribute19%TYPE
                          := pc_consumption;
        ln_buf        oe_order_lines_all.global_attribute19%TYPE;
        lt_result     xxd_ont_consumption_line_t_obj;
        ln_line_id    NUMBER;
        ln_quantity   NUMBER;
        lb_error      BOOLEAN := FALSE;
    BEGIN
        msg ('Consumption string provided: ' || pc_consumption);
        lt_result   := xxd_ont_consumption_line_t_obj (NULL);
        lt_result.delete;

        WHILE INSTR (ln_string, ';') > 0
        LOOP
            ln_buf      := SUBSTR (ln_string, 1, INSTR (ln_string, ';') - 1);
            ln_string   := SUBSTR (ln_string, INSTR (ln_string, ';') + 1);

            BEGIN
                ln_line_id   :=
                    TO_NUMBER (SUBSTR (ln_buf, 1, INSTR (ln_buf, '-') - 1));
            EXCEPTION
                WHEN OTHERS
                THEN
                    lb_error   := TRUE;
            END;

            BEGIN
                ln_quantity   :=
                    TO_NUMBER (SUBSTR (ln_buf, INSTR (ln_buf, '-') + 1));
            EXCEPTION
                WHEN OTHERS
                THEN
                    lb_error   := TRUE;
            END;

            IF NOT lb_error
            THEN
                lt_result.EXTEND;
                lt_result (lt_result.LAST)   :=
                    xxd_ont_consumption_line_obj (ln_line_id, ln_quantity);
            END IF;
        END LOOP;

        RETURN lt_result;
    END string_to_consumption;

    FUNCTION get_root_line_id (pn_child NUMBER)
        RETURN NUMBER
    IS
        ln_parent   NUMBER;
        ln_child    NUMBER;
    BEGIN
        SELECT line_id, split_From_line_id
          INTO ln_child, ln_parent
          FROM oe_order_lines_all
         WHERE line_id = pn_child;

        WHILE ln_parent IS NOT NULL
        LOOP
            SELECT line_id, split_From_line_id
              INTO ln_child, ln_parent
              FROM oe_order_lines_all
             WHERE line_id = ln_parent;
        END LOOP;

        RETURN ln_child;
    END get_root_line_id;

    FUNCTION get_child_qty (pn_parent_line_id NUMBER)
        RETURN NUMBER
    AS
        ln_sum_qty   NUMBER := 0;
        lr_oola      oe_order_lines_all%ROWTYPE;
    BEGIN
        SELECT *
          INTO lr_oola
          FROM oe_order_lines_all
         WHERE line_category_code = 'ORDER' AND line_id = pn_parent_line_id;

        IF lr_oola.schedule_ship_date IS NOT NULL
        THEN
            ln_sum_qty   := NVL (lr_oola.ordered_quantity, 0);
        ELSE
            ln_sum_qty   := 0;
        END IF;

        FOR i
            IN (SELECT *
                  FROM oe_order_lines_all
                 WHERE     line_category_code = 'ORDER'
                       AND split_from_line_id = pn_parent_line_id)
        LOOP
            ln_sum_qty   := ln_sum_qty + get_child_qty (i.line_id);
        END LOOP;

        RETURN ln_sum_qty;
    END get_child_qty;

    PROCEDURE resync_consumption (pn_line_id    IN     NUMBER,
                                  xc_ret_stat      OUT VARCHAR2)
    AS
        ln_consumed               NUMBER;
        ln_root_line_id           NUMBER;
        ln_calloff_order_count    NUMBER;
        ln_total_qty              NUMBER := 0;
        ln_new_qty                NUMBER := 0;
        ln_unconsum_qty           NUMBER := 0;
        ln_required               NUMBER;
        ln_idx                    NUMBER;
        ln_idx_buffer             NUMBER;
        lc_original_consumption   oe_order_lines_all.attribute19%TYPE;
        lc_current_consumption    oe_order_lines_all.attribute19%TYPE;
        lt_consumption            xxd_ont_consumption_line_t_obj;
    BEGIN
        xc_ret_stat              := g_ret_sts_success;
        ln_root_line_id          := get_root_line_id (pn_line_id);
        msg ('resync_consumption - Root line id ' || ln_root_line_id);

        BEGIN
            SELECT global_attribute19
              INTO lc_original_consumption
              FROM oe_order_lines_all
             WHERE line_id = ln_root_line_id
            FOR UPDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'resync_consumption - Other exception in GA19 check before unconsumption: '
                    || SQLERRM,
                    1);
                lc_original_consumption   := NULL;
        END;

        lt_consumption           := string_to_consumption (lc_original_consumption);

        IF lt_consumption.COUNT > 0
        THEN
            SELECT SUM (quantity)
              INTO ln_consumed
              FROM TABLE (lt_consumption);

            msg (
                   'resync_consumption - found existing consumption for ('
                || ln_consumed
                || ')');
        ELSE
            ln_consumed          := 0;
            msg (
                'resync_consumption - No changes needed to the calloff since no consumption found');
            g_consumption_flag   := FALSE;
            RETURN;
        END IF;

        ln_total_qty             := get_child_qty (ln_root_line_id);
        ln_required              := NVL (ln_total_qty, 0) - NVL (ln_consumed, 0);
        msg ('resync_consumption - total qty = ' || ln_total_qty);
        msg ('resync_consumption - consumed qty = ' || ln_consumed);

        IF ln_required = 0
        THEN
            msg (
                'resync_consumption - No changes needed to the calloff since ln_required is 0');
            g_consumption_flag   := FALSE;
            RETURN;
        ELSIF ln_required < 0
        THEN
            -- Unconsumption
            msg ('resync_consumption - Unconsumption Start');
            ln_unconsum_qty   := ABS (ln_required);
            ln_idx            := lt_consumption.LAST;

            WHILE ln_idx IS NOT NULL OR ln_unconsum_qty != 0
            LOOP
                msg (
                       'resync_consumption - Going through consumed lines ('
                    || lt_consumption (ln_idx).line_id
                    || ') with Unconsumed qty as '
                    || ln_unconsum_qty);
                ln_new_qty                         :=
                    GREATEST (
                        0,
                        lt_consumption (ln_idx).quantity - ln_unconsum_qty);
                ln_unconsum_qty                    :=
                    GREATEST (
                        0,
                        ln_unconsum_qty - lt_consumption (ln_idx).quantity);
                msg ('resync_consumption - New qty = ' || ln_new_qty);
                lt_consumption (ln_idx).quantity   := ln_new_qty;
                ln_idx_buffer                      :=
                    lt_consumption.PRIOR (ln_idx);
                ln_idx                             := ln_idx_buffer;
            END LOOP;
        ELSIF ln_required > 0
        THEN
            -- Consumption
            msg ('resync_consumption - Consumption Start');
            ln_idx   := lt_consumption.LAST;

            IF lt_consumption (ln_idx).line_id = 0
            THEN
                lt_consumption (ln_idx).quantity   :=
                    lt_consumption (ln_idx).quantity + ln_required;
            ELSE
                lt_consumption.EXTEND;
                lt_consumption (lt_consumption.LAST)   :=
                    xxd_ont_consumption_line_obj (0, ln_required);
            END IF;
        END IF;

        lc_current_consumption   := consumption_to_string (lt_consumption);

        IF NVL (lc_current_consumption, g_miss_char) !=
           NVL (lc_original_consumption, g_miss_char)
        THEN
            msg (
                   'resync_consumption - Changing consumption on line_id ('
                || ln_root_line_id
                || ') for changes on line_id ('
                || pn_line_id
                || ' from ('
                || lc_original_consumption
                || ') to ('
                || lc_current_consumption
                || ')');

            UPDATE oe_order_lines_all
               SET global_attribute19 = lc_current_consumption, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
             WHERE line_id = ln_root_line_id;
        ELSE
            msg ('resync_consumption - No changes in consumption recorded');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in resync_consumption: ' || SQLERRM, 1);
            xc_ret_stat          := g_ret_sts_error;
            g_consumption_flag   := FALSE;
    END resync_consumption;

    PROCEDURE collect_lines (pc_action VARCHAR2, pr_new_obj xxd_ne.xxd_ont_ord_line_obj, pr_old_obj xxd_ne.xxd_ont_ord_line_obj) -- Can be changed to oe_order_lines_all%rowtype >12c
    IS
        ln_line_id                 NUMBER;
        ln_idx                     NUMBER;
        ln_idx_buffer              NUMBER;
        ln_exists_idx              NUMBER;
        ln_required                NUMBER;
        ln_consumed                NUMBER;
        ln_cancelled               NUMBER;
        ln_increased               NUMBER;
        ln_root_line_id            NUMBER;
        ln_inventory_item_id       NUMBER;
        ln_calloff_order_type_id   NUMBER;
        ln_calloff_order_count     NUMBER;
        lc_original_consumption    oe_order_lines_all.attribute19%TYPE;
        lc_current_consumption     oe_order_lines_all.attribute19%TYPE;
        lt_consumption             xxd_ont_consumption_line_t_obj;
        lc_ret_stat                VARCHAR2 (1);
        lc_exists_flag             VARCHAR2 (1);
        lc_unconsump_flag          VARCHAR2 (1);
        lc_ret_status              VARCHAR2 (1);
        ln_total_qty               NUMBER := 0;
        ln_bulk_ord_qty            NUMBER := 0;
        lr_order_line              oe_order_lines_all%ROWTYPE;
        pr_new                     oe_order_lines_all%ROWTYPE
            := xxd_ont_order_utils_pkg.oola_obj_to_rec_fnc (pr_new_obj); -- Can be changed to oe_order_lines_all%rowtype >12c
        pr_old                     oe_order_lines_all%ROWTYPE
            := xxd_ont_order_utils_pkg.oola_obj_to_rec_fnc (pr_old_obj); -- Can be changed to oe_order_lines_all%rowtype >12c
        le_consumption_error       EXCEPTION;
    BEGIN
        ln_line_id             := NVL (pr_new.line_id, pr_old.line_id);
        ln_inventory_item_id   :=
            NVL (pr_new.inventory_item_id, pr_old.inventory_item_id);

        IF check_valid_order (pr_new) = 'N'
        THEN
            RETURN;
        END IF;

        --Validate Consumption occurs only one time for a line
        IF g_consumption_flag
        THEN
            RETURN;
        END IF;

        msg (
               'Collect Lines - Process Order Line ('
            || ln_line_id
            || ') Change executed for action: '
            || pc_action
            || ' with ('
            || gt_excluded_line_ids.COUNT
            || ') excluded line_ids in memory');
        clear_excluded_line_ids;
        sync_exclusion;
        msg ('Collect Lines - Line id (' || ln_line_id || ')');
        store_info (pr_new);

        ln_root_line_id        := get_root_line_id (ln_line_id);
        msg ('Collect Lines - Root line id ' || ln_root_line_id);

        BEGIN
            SELECT global_attribute19
              INTO lc_original_consumption
              FROM oe_order_lines_all
             WHERE line_id = ln_root_line_id
            FOR UPDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Collect Lines - Other exception in GA19 check before unconsumption: '
                    || SQLERRM,
                    1);
                lc_original_consumption   := NULL;
        END;

        lt_consumption         :=
            string_to_consumption (lc_original_consumption);
        msg ('Collect Lines - Consumption String');

        IF lt_consumption.COUNT > 0
        THEN
            SELECT SUM (quantity)
              INTO ln_consumed
              FROM TABLE (lt_consumption);

            msg (
                   'Collect Lines - found existing consumption for ('
                || ln_consumed
                || ')');
        ELSE
            ln_consumed   := 0;
        END IF;

        ln_total_qty           := get_child_qty (ln_root_line_id);
        ln_required            :=
            NVL (ln_total_qty, 0) - NVL (ln_consumed, 0);

        msg ('Collect Lines - Required Qty = ' || ln_required);
        msg ('Collect Lines - Consumed Qty = ' || ln_consumed);
        msg (
               'Collect Lines - New SSD = '
            || pr_new.schedule_ship_date
            || '. Old SSD = '
            || pr_old.schedule_ship_date);

        IF     ln_required = 0
           AND pc_action <> 'FORCE'
           AND ((pr_old.schedule_ship_date IS NOT NULL AND pr_new.schedule_ship_date IS NOT NULL AND TRUNC (pr_old.schedule_ship_date) = TRUNC (pr_new.schedule_ship_date)) OR (pr_old.schedule_ship_date IS NULL AND pr_new.schedule_ship_date IS NULL AND 1 = 1))
        THEN
            msg (
                   'Collect Lines - No bulk operation required for ('
                || NVL (pr_new.line_id, pr_old.line_id)
                || ') returning');
            RETURN;
        END IF;

        lc_unconsump_flag      := 'Y';

        IF     pr_new.ordered_quantity IS NOT NULL
           AND pr_old.ordered_quantity IS NOT NULL
           AND pr_new.ordered_quantity = pr_old.ordered_quantity
           AND pr_new.schedule_ship_date IS NOT NULL
           AND pr_old.schedule_ship_date IS NOT NULL
           AND pr_new.schedule_ship_date = pr_old.schedule_ship_date
        THEN
            lc_unconsump_flag   := 'N';
            msg ('Collect Lines - No Unconsumption required');
        END IF;

        IF pc_action = 'FORCE'
        THEN
            msg ('Collect Lines - FORCE action. So Unconsumption is must');
            lc_unconsump_flag   := 'Y';
        END IF;

        -- Collect all consumed bulk lines
        IF lc_unconsump_flag = 'Y' AND lt_consumption.COUNT != 0
        THEN
            BEGIN
                ln_idx   := lt_consumption.FIRST;

                WHILE ln_idx IS NOT NULL
                LOOP
                    IF     lt_consumption (ln_idx).line_id IS NOT NULL
                       AND lt_consumption (ln_idx).line_id != g_miss_num
                    THEN
                        BEGIN
                            gt_collected_line_ids.EXTEND;
                            gt_collected_line_ids (
                                gt_collected_line_ids.LAST)   :=
                                xxd_ont_lines_obj (
                                    lt_consumption (ln_idx).line_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                msg (
                                       'Collect Lines - Unconsumption - no_data_found for Line; '
                                    || lt_consumption (ln_idx).line_id,
                                    1);
                        END;
                    END IF;

                    ln_idx   := lt_consumption.NEXT (ln_idx);
                END LOOP;

                msg (
                    'Collect Lines - Unconsumption - Collected all bulk order lines');
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Collect Lines - Unconsumption - Exception in Collecting all bulk order lines: '
                        || SQLERRM,
                        1);
                    RAISE le_consumption_error;
            END;
        END IF;

        -- Collect all identified bulk lines
        IF gt_excluded_line_ids.COUNT != 0
        THEN
            BEGIN
                ln_idx   := gt_excluded_line_ids.FIRST;

                WHILE ln_idx IS NOT NULL
                LOOP
                    IF     gt_excluded_line_ids (ln_idx).line_id IS NOT NULL
                       AND gt_excluded_line_ids (ln_idx).line_id !=
                           g_miss_num
                    THEN
                        BEGIN
                            gt_collected_line_ids.EXTEND;
                            gt_collected_line_ids (
                                gt_collected_line_ids.LAST)   :=
                                xxd_ont_lines_obj (
                                    gt_excluded_line_ids (ln_idx).line_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                msg (
                                       'Collect Lines - Consumption - no_data_found for Line; '
                                    || gt_excluded_line_ids (ln_idx).line_id,
                                    1);
                        END;
                    END IF;

                    ln_idx   := gt_excluded_line_ids.NEXT (ln_idx);
                END LOOP;

                msg (
                    'Collect Lines - Consumption - Collected all bulk order lines');
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Collect Lines - Consumption - Exception in Collecting all bulk order lines: '
                        || SQLERRM,
                        1);
                    RAISE le_consumption_error;
            END;
        END IF;

        clear_excluded_line_ids;
        sync_exclusion;
    EXCEPTION
        WHEN le_consumption_error
        THEN
            msg ('Collect Lines error!', 1);
            RAISE;
        WHEN OTHERS
        THEN
            msg (
                   'Something went very wrong in Collect Lines! ('
                || SQLERRM
                || ')',
                1);
    END collect_lines;

    PROCEDURE lock_lines
    IS
        TYPE lt_line IS TABLE OF oe_order_lines_all.line_id%TYPE
            INDEX BY PLS_INTEGER;

        lt_line_ids      lt_line;
        ln_loops         NUMBER
            := NVL (fnd_profile.VALUE ('XXD_ONT_LOCK_ATTEMPT'), 86400); --default is a day
        ln_loop_period   NUMBER
            := NVL (fnd_profile.VALUE ('XXD_ONT_LOCK_LOOP_PERIOD'), 1); --default is 1 second
        -- Start changed for CCR0009499
        resource_busy    EXCEPTION;
        PRAGMA EXCEPTION_INIT (resource_busy, -54);
    -- End changed for CCR0009499
    BEGIN
        FOR i IN 1 .. ln_loops
        LOOP
            BEGIN
                SELECT oola.line_id
                  BULK COLLECT INTO lt_line_ids
                  FROM TABLE (gt_collected_line_ids) xxd, oe_order_lines_all oola
                 WHERE     xxd.line_id != g_miss_num
                       AND xxd.line_id IS NOT NULL
                       AND xxd.line_id <> 0
                       AND oola.line_id = xxd.line_id
                FOR UPDATE OF
                    oola.line_id, oola.ordered_quantity, oola.schedule_ship_date
                    NOWAIT;                     -- Added nowait for CCR0009499

                msg ('OOLA Row Locks Obtained');
                EXIT;
            EXCEPTION
                -- Start changed for CCR0009499
                -- when others then msg('Unable to lock all rows');dbms_lock.sleep(ln_loop_period);
                WHEN resource_busy
                THEN
                    msg ('Unable to lock all rows!! Retrying!');
                    DBMS_LOCK.sleep (ln_loop_period);
                WHEN OTHERS
                THEN
                    msg ('Unable to lock all rows!! Exiting.', 1);
                    RAISE;
            -- End changed for CCR0009499
            END;
        END LOOP;

        gt_collected_line_ids.delete;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Something went very wrong in Lock Lines! ('
                || SQLERRM
                || ')',
                1);
            RAISE;
    END lock_lines;

    PROCEDURE process_order_line_change (pc_action VARCHAR2, pr_new_obj xxd_ne.xxd_ont_ord_line_obj, pr_old_obj xxd_ne.xxd_ont_ord_line_obj) -- Can be changed to oe_order_lines_all%rowtype >12c
    IS
        ln_line_id                 NUMBER;
        ln_idx                     NUMBER;
        ln_idx_buffer              NUMBER;
        ln_exists_idx              NUMBER;
        ln_required                NUMBER;
        ln_consumed                NUMBER;
        ln_cancelled               NUMBER;
        ln_increased               NUMBER;
        ln_root_line_id            NUMBER;
        ln_inventory_item_id       NUMBER;
        ln_calloff_order_type_id   NUMBER;
        ln_calloff_order_count     NUMBER;
        lc_original_consumption    oe_order_lines_all.attribute19%TYPE;
        lc_current_consumption     oe_order_lines_all.attribute19%TYPE;
        lt_consumption             xxd_ont_consumption_line_t_obj;
        lc_ret_stat                VARCHAR2 (1);
        lc_exists_flag             VARCHAR2 (1);
        lc_unconsump_flag          VARCHAR2 (1);
        lc_ret_status              VARCHAR2 (1);
        ln_total_qty               NUMBER := 0;
        ln_bulk_ord_qty            NUMBER := 0;
        lr_order_line              oe_order_lines_all%ROWTYPE;
        pr_new                     oe_order_lines_all%ROWTYPE
            := xxd_ont_order_utils_pkg.oola_obj_to_rec_fnc (pr_new_obj); -- Can be changed to oe_order_lines_all%rowtype >12c
        pr_old                     oe_order_lines_all%ROWTYPE
            := xxd_ont_order_utils_pkg.oola_obj_to_rec_fnc (pr_old_obj); -- Can be changed to oe_order_lines_all%rowtype >12c
        le_consumption_error       EXCEPTION;
    BEGIN
        ln_line_id                  := NVL (pr_new.line_id, pr_old.line_id);
        ln_inventory_item_id        :=
            NVL (pr_new.inventory_item_id, pr_old.inventory_item_id);

        IF check_valid_order (pr_new) = 'N'
        THEN
            RETURN;
        END IF;

        IF gc_no_unconsumption = 'Y'
        THEN
            msg ('unconsumption not required');
            resync_consumption (ln_line_id, lc_ret_status);
            msg ('resync_consumption status - ' || lc_ret_status);
            RETURN;
        END IF;

        --Validate Consumption occurs only one time for a line
        IF g_consumption_flag
        THEN
            RETURN;
        ELSE
            g_consumption_flag   := TRUE;
        END IF;

        msg (
               'Process Order Line ('
            || ln_line_id
            || ') Change executed for action: '
            || pc_action
            || ' with ('
            || gt_excluded_line_ids.COUNT
            || ') excluded line_ids in memory');
        clear_excluded_line_ids;
        sync_exclusion;
        msg ('Line id (' || ln_line_id || '). Org id ' || pr_new.org_id);
        ln_root_line_id             := get_root_line_id (ln_line_id);
        msg ('Root line id ' || ln_root_line_id);

        BEGIN
            SELECT global_attribute19
              INTO lc_original_consumption
              FROM oe_order_lines_all
             WHERE line_id = ln_root_line_id
            FOR UPDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Other exception in GA19 check before unconsumption: '
                    || SQLERRM,
                    1);
                lc_original_consumption   := NULL;
        END;

        pr_new.global_attribute19   := lc_original_consumption;
        store_info (pr_new);

        lt_consumption              :=
            string_to_consumption (lc_original_consumption);
        msg ('Consumption String');

        IF lt_consumption.COUNT > 0
        THEN
            SELECT SUM (quantity)
              INTO ln_consumed
              FROM TABLE (lt_consumption);

            msg ('found existing consumption for (' || ln_consumed || ')');
        ELSE
            ln_consumed   := 0;
        END IF;

        ln_total_qty                := get_child_qty (ln_root_line_id);
        ln_required                 :=
            NVL (ln_total_qty, 0) - NVL (ln_consumed, 0);

        msg ('Total Qty = ' || ln_total_qty);
        msg ('Required Qty = ' || ln_required);
        msg ('Consumed Qty = ' || ln_consumed);
        msg (
               'New SSD = '
            || pr_new.schedule_ship_date
            || '. Old SSD = '
            || pr_old.schedule_ship_date);

        IF     ln_required = 0
           AND pc_action <> 'FORCE'
           AND ((pr_old.schedule_ship_date IS NOT NULL AND pr_new.schedule_ship_date IS NOT NULL AND TRUNC (pr_old.schedule_ship_date) = TRUNC (pr_new.schedule_ship_date)) OR (pr_old.schedule_ship_date IS NULL AND pr_new.schedule_ship_date IS NULL))
        THEN
            msg (
                   'No bulk operation required for ('
                || NVL (pr_new.line_id, pr_old.line_id)
                || ') returning');
            g_consumption_flag   := FALSE;
            RETURN;
        END IF;

        lc_unconsump_flag           := 'Y';

        IF     pr_new.ordered_quantity IS NOT NULL
           AND pr_old.ordered_quantity IS NOT NULL
           AND pr_new.ordered_quantity = pr_old.ordered_quantity
           AND pr_new.schedule_ship_date IS NOT NULL
           AND pr_old.schedule_ship_date IS NOT NULL
           AND pr_new.schedule_ship_date = pr_old.schedule_ship_date
        THEN
            lc_unconsump_flag   := 'N';
            msg ('No Unconsumption required');
        END IF;

        IF pc_action = 'FORCE'
        THEN
            msg ('FORCE action. So Unconsumption is must');
            lc_unconsump_flag   := 'Y';
        END IF;

        -- Unconsumption
        IF lc_unconsump_flag = 'Y' AND ln_consumed > 0
        THEN
            msg ('Unconsumption Start');

            IF ln_required = 0
            THEN
                ln_required   := -NVL (ln_total_qty, 0);
            END IF;          -- Needed for RD, LAD changes without qty changes

            ln_idx   := lt_consumption.LAST;

            WHILE ln_idx IS NOT NULL AND ln_required < 0
            LOOP
                msg (
                       'Going through consumed lines ('
                    || lt_consumption (ln_idx).line_id
                    || ')');

                IF    lt_consumption (ln_idx).line_id = 0
                   OR lt_consumption (ln_idx).line_id = g_miss_num
                   OR lt_consumption (ln_idx).line_id IS NULL
                THEN
                    ln_increased   :=
                        LEAST (-ln_required,
                               NVL (lt_consumption (ln_idx).quantity, 0));
                    msg ('ATP Qty is ' || ln_increased);
                    lc_ret_stat   := g_ret_sts_success;
                ELSE
                    msg (
                           'Increase quantity for lines ('
                        || lt_consumption (ln_idx).line_id
                        || ' with qty as '
                        || LEAST (-ln_required,
                                  lt_consumption (ln_idx).quantity)
                        || ')');
                    xxd_ont_order_utils_pkg.increase_line_qty (
                        pn_line_id              => lt_consumption (ln_idx).line_id,
                        pn_increase_quantity    =>
                            LEAST (-ln_required,
                                   NVL (lt_consumption (ln_idx).quantity, 0)),
                        pn_calloff_line_id      => ln_line_id,
                        pd_calloff_old_ssd      =>
                            TRUNC (pr_old.schedule_ship_date),
                        xn_increased_quantity   => ln_increased,
                        xc_ret_stat             => lc_ret_stat);
                END IF;

                ln_idx_buffer   := lt_consumption.PRIOR (ln_idx);

                IF lc_ret_stat = g_ret_sts_success AND ln_increased > 0
                THEN
                    ln_required   := ln_required + ln_increased;
                    lt_consumption (ln_idx).quantity   :=
                        lt_consumption (ln_idx).quantity - ln_increased;

                    IF lt_consumption (ln_idx).quantity <= 0
                    THEN
                        msg (
                               'Deleting Record for line id '
                            || lt_consumption (ln_idx).line_id);
                        lt_consumption.delete (ln_idx);
                    END IF;
                ELSE
                    RAISE le_consumption_error;
                END IF;

                ln_idx          := ln_idx_buffer;
            END LOOP;
        ELSE
            msg ('UnConsumption called without consumed lines');
        END IF;

        msg ('Required qty after unconsumption = ' || ln_required);

        IF lt_consumption.COUNT > 0
        THEN
            SELECT SUM (quantity)
              INTO ln_consumed
              FROM TABLE (lt_consumption);

            msg ('Found existing consumption for (' || ln_consumed || ')');
        ELSE
            ln_consumed   := 0;
        END IF;

        ln_total_qty                := get_child_qty (ln_root_line_id);
        ln_required                 :=
            NVL (ln_total_qty, 0) - NVL (ln_consumed, 0);
        msg ('Total Qty = ' || ln_total_qty);
        msg ('Required Qty = ' || ln_required);
        msg ('Consumed Qty = ' || ln_consumed);

        -- Consumption
        IF ln_required > 0
        THEN
            msg ('Consumption Start');

            IF gt_excluded_line_ids.COUNT != 0
            THEN
                ln_idx   := gt_excluded_line_ids.FIRST;

                WHILE ln_idx IS NOT NULL AND ln_required > 0
                LOOP
                    msg (
                           'Going through exclude line IDs: '
                        || gt_excluded_line_ids (ln_idx).line_id);

                    -- Check if current bulk ord qty is greater than zero. Zero lines are purposefully included
                    BEGIN
                        SELECT NVL (SUM (ordered_quantity), 0)
                          INTO ln_bulk_ord_qty
                          FROM oe_order_lines_all
                         WHERE line_id =
                               gt_excluded_line_ids (ln_idx).line_id;

                        msg (
                               'Ordered Qty is ('
                            || NVL (ln_bulk_ord_qty, 0)
                            || ') for excluded line_id ('
                            || gt_excluded_line_ids (ln_idx).line_id
                            || ')');

                        IF NVL (ln_bulk_ord_qty, 0) = 0
                        THEN
                            ln_idx   := gt_excluded_line_ids.NEXT (ln_idx);
                            msg (
                                'Ordered Qty is 0. Skipping this excluded line id');
                            CONTINUE;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                   'Exception in bulk ord qty check: '
                                || SQLERRM,
                                1);
                            ln_idx   := gt_excluded_line_ids.NEXT (ln_idx);
                            CONTINUE;
                    END;

                    msg (
                           'Going through eligible lines ('
                        || gt_excluded_line_ids (ln_idx).line_id
                        || ')');

                    IF gt_excluded_line_ids (ln_idx).inventory_item_id =
                       ln_inventory_item_id
                    THEN
                        msg (
                               'Requesting ('
                            || ln_required
                            || ') units from line_id ('
                            || gt_excluded_line_ids (ln_idx).line_id
                            || ')');

                        IF gt_excluded_line_ids (ln_idx).line_id !=
                           g_miss_num
                        THEN
                            xxd_ont_order_utils_pkg.cancel_line_qty (
                                pn_line_id              =>
                                    gt_excluded_line_ids (ln_idx).line_id,
                                pc_reason_code          => 'BLK_ADJ_PGM',
                                pc_comment              =>
                                    'Qty Cancelled for Bulk/Calloff Consumption',
                                pn_cancel_quantity      => ln_required,
                                xn_cancelled_quantity   => ln_cancelled,
                                xc_ret_stat             => lc_ret_stat);
                            msg (
                                   'Returned from cancel_line_quantity with a ret_stat ('
                                || lc_ret_stat
                                || ') having requested ('
                                || ln_required
                                || ') and received ('
                                || ln_cancelled
                                || ')');

                            IF     lc_ret_stat = g_ret_sts_success
                               AND ln_cancelled > 0
                            THEN
                                msg (
                                       'Successfully consumed ('
                                    || ln_cancelled
                                    || ') units from line_id ('
                                    || gt_excluded_line_ids (ln_idx).line_id
                                    || ')');
                                ln_required      := ln_required - ln_cancelled;
                                ln_exists_idx    := lt_consumption.FIRST;
                                lc_exists_flag   := 'N';

                                WHILE     ln_exists_idx IS NOT NULL
                                      AND lc_exists_flag = 'N'
                                LOOP
                                    IF lt_consumption (ln_exists_idx).line_id =
                                       gt_excluded_line_ids (ln_idx).line_id
                                    THEN
                                        lc_exists_flag   := 'Y';
                                        lt_consumption (ln_exists_idx).quantity   :=
                                              lt_consumption (ln_exists_idx).quantity
                                            + ln_cancelled;
                                    END IF;

                                    ln_exists_idx   :=
                                        lt_consumption.NEXT (ln_exists_idx);
                                END LOOP;

                                IF lc_exists_flag <> 'Y'
                                THEN
                                    lt_consumption.EXTEND;
                                    lt_consumption (lt_consumption.LAST)   :=
                                        xxd_ont_consumption_line_obj (
                                            gt_excluded_line_ids (ln_idx).line_id,
                                            ln_cancelled);
                                END IF;
                            ELSE
                                RAISE le_consumption_error;
                            END IF;
                        END IF;
                    END IF;

                    ln_idx   := gt_excluded_line_ids.NEXT (ln_idx);
                END LOOP;

                -- If not enough Bulk ATP, then add 0-qty to consumption table
                IF ln_required > 0
                THEN
                    msg (
                           'Not enough Bulk Qty. Adding Free ATP Qty with '
                        || ln_required);

                    IF     lt_consumption.LAST IS NOT NULL
                       AND lt_consumption (lt_consumption.LAST).line_id = 0
                    THEN
                        lt_consumption (lt_consumption.LAST).quantity   :=
                              lt_consumption (lt_consumption.LAST).quantity
                            + ln_required;
                    ELSE
                        lt_consumption.EXTEND;
                        lt_consumption (lt_consumption.LAST)   :=
                            xxd_ont_consumption_line_obj (0, ln_required);
                    END IF;
                END IF;
            ELSE
                msg (
                    'Consumption called without excluded (eligable lines) stored');
            END IF;
        ELSE
            msg ('Nothing required. Skipping consumption');
        END IF;

        lc_current_consumption      := consumption_to_string (lt_consumption);

        IF NVL (lc_current_consumption, g_miss_char) !=
           NVL (lc_original_consumption, g_miss_char)
        THEN
            msg (
                   'Changing consumption on line_id ('
                || ln_root_line_id
                || ') for changes on line_id ('
                || ln_line_id
                || ' from ('
                || lc_original_consumption
                || ') to ('
                || lc_current_consumption
                || ')');

            UPDATE oe_order_lines_all
               SET global_attribute19 = lc_current_consumption, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
             WHERE line_id = ln_root_line_id;
        ELSE
            msg ('No changes in consumption recorded');
        END IF;

        g_consumption_flag          := FALSE;
        clear_excluded_line_ids;
        sync_exclusion;
    EXCEPTION
        WHEN le_consumption_error
        THEN
            msg ('Consumption Error!', 1);
            RAISE;
        WHEN OTHERS
        THEN
            msg ('Something went very wrong! (' || SQLERRM || ')', 1);
            g_consumption_flag   := FALSE;
    END process_order_line_change;
BEGIN
    gt_excluded_line_ids     := xxd_ont_elegible_lines_t_obj (NULL);
    gt_identified_line_ids   := xxd_ont_elegible_lines_t_obj (NULL);
    gt_collected_line_ids    := xxd_ont_lines_t_obj (NULL);
    clear_excluded_line_ids;
END xxd_ont_bulk_calloff_pkg;
/
