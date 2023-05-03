--
-- XXD_ONT_BULK_RULES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_RULES_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_RULES_PKG
    * Design       : This package will manage the bulk calloff process
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2020  1.0        Deckers                 Initial Version
    -- 27-Jul-2021  1.1        Deckers                 Updated for CCR0009490
    -- 31-Aug-2021  1.2        Deckers                 Updated for CCR0009567
    -- 31-Aug-2021  1.3        Deckers                 Updated for CCR0009669
    ******************************************************************************************/

    PROCEDURE msg (pc_msg         VARCHAR2,
                   pn_log_level   NUMBER:= 9.99e125,
                   pc_origin      VARCHAR2:= 'Local Delegated Debug')
    IS
    BEGIN
        xxd_debug_tools_pkg.msg (pc_msg         => pc_msg,
                                 pn_log_level   => pn_log_level,
                                 pc_origin      => pc_origin);
    END msg;

    PROCEDURE get_eligible_bulk_lines (pr_line IN oe_order_lines_all%ROWTYPE, pr_header IN oe_order_headers_all%ROWTYPE, pr_line_order_type IN oe_transaction_types_all%ROWTYPE, pr_header_order_type IN oe_transaction_types_all%ROWTYPE, pr_operating_unit IN hr_all_organization_units%ROWTYPE, pr_inventory_org IN mtl_parameters%ROWTYPE, pr_hz_cust_accounts IN hz_cust_accounts%ROWTYPE, pr_hz_parties IN hz_parties%ROWTYPE, xt_eligible_lines OUT xxd_ont_elegible_lines_t_obj
                                       , xc_ret_stat OUT VARCHAR2)
    IS
    BEGIN
        xc_ret_stat   := g_ret_sts_success;
        msg (
               'Get Eligable Bulk Lines - header_id ('
            || pr_header.header_id
            || ') line_id ('
            || pr_line.line_id
            || ') ssd:'
            || TO_CHAR (
                   NVL (pr_line.schedule_ship_date, pr_line.request_date),
                   'MM/DD/YYYY'));

        BEGIN
            SELECT xxd_ont_elegible_line_obj (
                       line_id,
                       inventory_item_id,
                       ROW_NUMBER ()
                           OVER (
                               ORDER BY
                                   forward_cons ASC,
                                   priority_col DESC,
                                   CASE
                                       WHEN    virtual_whse_value IS NOT NULL
                                            OR ship_from_whse_value
                                                   IS NOT NULL
                                       THEN
                                           ord_typ_pri
                                       ELSE
                                           0
                                   END ASC,
                                   distance DESC,
                                   direction ASC,
                                   CASE
                                       WHEN     virtual_whse_value IS NULL
                                            AND ship_from_whse_value IS NULL
                                       THEN
                                           ord_typ_pri
                                       ELSE
                                           0
                                   END ASC,
                                   ord_typ_dir ASC))
              BULK COLLECT INTO xt_eligible_lines
              FROM (SELECT oola.line_id,
                           oola.inventory_item_id,
                           CASE
                               WHEN TRUNC (oola.schedule_ship_date) >
                                    TRUNC (
                                        NVL (pr_line.schedule_ship_date,
                                             pr_line.request_date))
                               THEN
                                     TRUNC (oola.schedule_ship_date)
                                   - TRUNC (
                                         NVL (pr_line.schedule_ship_date,
                                              pr_line.request_date))
                               ELSE
                                   0
                           END forward_cons,
                           CASE
                               WHEN     xxd.salesrep_flag = 'P'
                                    AND oola.salesrep_id =
                                        pr_line.salesrep_id
                               THEN
                                   1
                               WHEN     xxd.customer_flag = 'P'
                                    AND oola.sold_to_org_id =
                                        pr_line.sold_to_org_id
                               THEN
                                   1
                               WHEN     xxd.cust_po_flag = 'P'
                                    AND oola.cust_po_number =
                                        pr_line.cust_po_number
                               THEN
                                   1
                               WHEN     xxd.warehouse_flag = 'P'
                                    AND oola.ship_from_org_id =
                                        pr_line.ship_from_org_id
                               THEN
                                   1
                               WHEN     xxd.order_source_flag = 'P'
                                    AND oola.order_source_id =
                                        pr_line.order_source_id
                               THEN
                                   1
                               WHEN     xxd.sales_channel_flag = 'P'
                                    AND ooha.sales_channel_code =
                                        pr_header.sales_channel_code
                               THEN
                                   1
                               WHEN     xxd.order_currency_flag = 'P'
                                    AND ooha.transactional_curr_code =
                                        pr_header.transactional_curr_code
                               THEN
                                   1
                               WHEN     xxd.bill_to_flag = 'P'
                                    AND oola.invoice_to_org_id =
                                        pr_line.invoice_to_org_id
                               THEN
                                   1
                               WHEN     xxd.ship_to_flag = 'P'
                                    AND oola.ship_to_org_id =
                                        pr_line.ship_to_org_id
                               THEN
                                   1
                               WHEN     xxd.demand_class_flag = 'P'
                                    AND oola.demand_class_code =
                                        pr_line.demand_class_code
                               THEN
                                   1
                               ELSE
                                   0
                           END priority_col,
                           CASE
                               WHEN     xxd.bulk_ord_type_direction_column =
                                        'SSD'
                                    AND xxd.bulk_ord_type_id1_ssd = 'DESC'
                               THEN
                                     TRUNC (oola.schedule_ship_date)
                                   - TRUNC (
                                         NVL (pr_line.schedule_ship_date,
                                              pr_line.request_date))
                               WHEN     xxd.bulk_ord_type_direction_column =
                                        'SSD'
                                    AND xxd.bulk_ord_type_id1_ssd = 'ASC'
                               THEN
                                   ABS (
                                         TRUNC (oola.schedule_ship_date)
                                       - TRUNC (
                                             NVL (pr_line.schedule_ship_date,
                                                  pr_line.request_date)))
                               WHEN xxd.bulk_ord_type_direction_column = 'RD'
                               THEN
                                   ABS (
                                         TRUNC (oola.request_date)
                                       - TRUNC (
                                             NVL (pr_line.schedule_ship_date,
                                                  pr_line.request_date)))
                           END distance,
                           SIGN (
                                 TRUNC (oola.schedule_ship_date)
                               - TRUNC (
                                     NVL (pr_line.schedule_ship_date,
                                          pr_line.request_date))) direction,
                           CASE
                               WHEN xxd.bulk_ord_type_id1 =
                                    ooha.order_type_id
                               THEN
                                   bulk_ord_type_id1_priority
                               WHEN xxd.bulk_ord_type_id2 =
                                    ooha.order_type_id
                               THEN
                                   bulk_ord_type_id2_priority
                               WHEN xxd.bulk_ord_type_id3 =
                                    ooha.order_type_id
                               THEN
                                   bulk_ord_type_id3_priority
                               WHEN xxd.bulk_ord_type_id4 =
                                    ooha.order_type_id
                               THEN
                                   bulk_ord_type_id4_priority
                               ELSE
                                   0
                           END ord_typ_pri,
                           CASE
                               WHEN     xxd.bulk_ord_type_id1 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id1_ssd = 'DESC'
                               THEN
                                   -1
                               WHEN     xxd.bulk_ord_type_id1 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id1_ssd = 'ASC'
                               THEN
                                   1
                               WHEN     xxd.bulk_ord_type_id2 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id2_ssd = 'DESC'
                               THEN
                                   -1
                               WHEN     xxd.bulk_ord_type_id2 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id2_ssd = 'ASC'
                               THEN
                                   1
                               WHEN     xxd.bulk_ord_type_id3 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id3_ssd = 'DESC'
                               THEN
                                   -1
                               WHEN     xxd.bulk_ord_type_id3 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id3_ssd = 'ASC'
                               THEN
                                   1
                               WHEN     xxd.bulk_ord_type_id4 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id4_ssd = 'DESC'
                               THEN
                                   -1
                               WHEN     xxd.bulk_ord_type_id4 =
                                        ooha.order_type_id
                                    AND xxd.bulk_ord_type_id4_ssd = 'ASC'
                               THEN
                                   1
                               ELSE
                                   0
                           END ord_typ_dir,
                           xxd.virtual_whse_value,
                           xxd.ship_from_whse_value
                      FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all otta,
                           xxdo.xxd_ont_consumption_rules_t xxd
                     WHERE     ooha.header_id = oola.header_id
                           AND ooha.order_type_id = otta.transaction_type_id
                           AND xxd.calloff_order_type_id =
                               pr_header.order_type_id
                           AND oola.inventory_item_id =
                               pr_line.inventory_item_id
                           -- Start changes for CCR0009669
                           --AND oola.schedule_ship_date IS NOT NULL
                           AND NVL2 (oola.schedule_ship_date, 1, 0) = 1
                           -- End changes for CCR0009669
                           AND otta.attribute5 = 'BO'
                           -- Start changes for CCR0009490
                           --AND (oola.open_flag = 'Y' OR oola.last_update_date > sysdate-1/24 OR exists (select 1 from table (xxd_ont_bulk_calloff_pkg.string_to_consumption (pr_line.global_attribute19)) where line_id = oola.line_id))
                           --AND (oola.ordered_quantity > 0 OR oola.last_update_date > sysdate-1/24 OR exists (select 1 from table (xxd_ont_bulk_calloff_pkg.string_to_consumption (pr_line.global_attribute19)) where line_id = oola.line_id))
                           AND oola.line_category_code = 'ORDER'
                           AND (oola.open_flag = 'Y' OR oola.last_update_date > SYSDATE - 1 / 24 OR pr_line.global_attribute19 LIKE '%' || oola.line_id || '-%')
                           AND (oola.ordered_quantity > 0 OR oola.last_update_date > SYSDATE - 1 / 24 OR pr_line.global_attribute19 LIKE '%' || oola.line_id || '-%')
                           -- End changes for CCR0009490
                           AND ooha.order_type_id IN (xxd.bulk_ord_type_id1, xxd.bulk_ord_type_id2, xxd.bulk_ord_type_id3,
                                                      xxd.bulk_ord_type_id4)
                           -- Sales Rep
                           AND ((xxd.salesrep_flag IN ('A', 'P') AND 1 = 1) OR (xxd.salesrep_flag = 'M' AND oola.salesrep_id = pr_line.salesrep_id) OR (xxd.salesrep_flag = 'S' AND oola.salesrep_id = xxd.salesrep_value))
                           -- Customer
                           AND ((xxd.customer_flag IN ('A', 'P') AND 1 = 1) OR (xxd.customer_flag = 'M' AND oola.sold_to_org_id = pr_line.sold_to_org_id) OR (xxd.customer_flag = 'S' AND oola.sold_to_org_id = xxd.customer_value))
                           -- Cust PO Number
                           AND ((xxd.cust_po_flag IN ('A', 'P') AND 1 = 1) OR (xxd.customer_flag = 'M' AND oola.cust_po_number = pr_line.cust_po_number) OR (xxd.cust_po_flag = 'S' AND oola.cust_po_number = xxd.cust_po_value))
                           -- Warehouse
                           AND ((xxd.warehouse_flag IN ('A', 'P') AND 1 = 1) OR (xxd.warehouse_flag = 'M' AND oola.ship_from_org_id = pr_line.ship_from_org_id) OR (xxd.warehouse_flag = 'S' AND oola.ship_from_org_id = xxd.warehouse_value))
                           -- Order Source
                           AND ((xxd.order_source_flag IN ('A', 'P') AND 1 = 1) OR (xxd.order_source_flag = 'M' AND oola.order_source_id = pr_line.order_source_id) OR (xxd.order_source_flag = 'S' AND oola.ship_from_org_id = xxd.order_source_value))
                           -- Sales Channel
                           AND ((xxd.sales_channel_flag IN ('A', 'P') AND 1 = 1) OR (xxd.sales_channel_flag = 'M' AND ooha.sales_channel_code = pr_header.sales_channel_code) OR (xxd.sales_channel_flag = 'S' AND ooha.sales_channel_code = xxd.sales_channel_value))
                           -- Order Currency
                           AND ((xxd.order_currency_flag IN ('A', 'P') AND 1 = 1) OR (xxd.order_currency_flag = 'M' AND ooha.transactional_curr_code = pr_header.transactional_curr_code) OR (xxd.order_currency_flag = 'S' AND ooha.transactional_curr_code = xxd.order_currency_value))
                           -- Bill To
                           AND ((xxd.bill_to_flag IN ('A', 'P') AND 1 = 1) OR (xxd.bill_to_flag = 'M' AND oola.invoice_to_org_id = pr_line.invoice_to_org_id) OR (xxd.bill_to_flag = 'S' AND ooha.invoice_to_org_id = xxd.bill_to_value))
                           -- Ship To
                           AND ((xxd.ship_to_flag IN ('A', 'P') AND 1 = 1) OR (xxd.ship_to_flag = 'M' AND oola.ship_to_org_id = pr_line.ship_to_org_id) OR (xxd.ship_to_flag = 'S' AND ooha.ship_to_org_id = xxd.ship_to_value))
                           -- Demand Class
                           AND ((xxd.demand_class_flag IN ('A', 'P') AND 1 = 1) OR (xxd.demand_class_flag = 'M' AND oola.demand_class_code = pr_line.demand_class_code) OR (xxd.demand_class_flag = 'S' AND oola.demand_class_code = xxd.demand_class_value))
                           -- Virtual Whse
                           AND ((xxd.virtual_whse_flag <> 'S' AND 1 = 1) OR (xxd.virtual_whse_flag = 'S' AND pr_line.attribute6 = xxd.virtual_whse_value))
                           -- Start changes for CCR0009567
                           -- Consumption Window From
                           AND ((ooha.attribute18 IS NOT NULL AND TRUNC (pr_line.request_date) >= fnd_date.canonical_to_date (ooha.attribute18)) OR (ooha.attribute18 IS NULL AND 1 = 1))
                           -- Consumption Window To
                           AND ((ooha.attribute19 IS NOT NULL AND TRUNC (pr_line.request_date) <= fnd_date.canonical_to_date (ooha.attribute19)) OR (ooha.attribute19 IS NULL AND 1 = 1))
                           -- End changes for CCR0009567
                           -- DC to DC
                           AND (   (pr_header.order_source_id <> 10 AND 1 = 1)
                                OR (    pr_header.order_source_id = 10
                                    AND (    -- DC to DC Ship From
                                             xxd.ship_from_whse_flag = 'S'
                                         AND pr_line.ship_from_org_id =
                                             xxd.ship_from_whse_value
                                         -- Start changes for CCR0009490
                                         -- DC to DC Ship To
                                         --AND xxd.ship_to_whse_flag = 'S' AND xxd.ship_to_whse_value = (select mp.organization_id from mtl_parameters mp, po_location_associations_all plaa, hz_cust_site_uses_all hcsua where hcsua.site_use_id = plaa.site_use_id AND plaa.organization_id = mp.organization_id AND hcsua.site_use_id = pr_line.ship_to_org_id)
                                         -- DC to DC Transfer Type
                                         --AND xxd.transfer_type_flag = 'S' AND xxd.transfer_type_value = (select prha.attribute1 from po_requisition_headers_all prha where prha.requisition_header_id = pr_line.source_document_id)
                                         -- DC to DC Ship To
                                         AND xxd.ship_to_whse_flag = 'S'
                                         AND EXISTS
                                                 (SELECT 1
                                                    FROM mtl_parameters mp, po_location_associations_all plaa, hz_cust_site_uses_all hcsua
                                                   WHERE     mp.organization_id =
                                                             xxd.ship_to_whse_value
                                                         AND hcsua.site_use_id =
                                                             plaa.site_use_id
                                                         AND plaa.organization_id =
                                                             mp.organization_id
                                                         AND hcsua.site_use_id =
                                                             pr_line.ship_to_org_id)
                                         -- DC to DC Transfer Type
                                         AND xxd.transfer_type_flag = 'S'
                                         AND EXISTS
                                                 (SELECT 1
                                                    FROM po_requisition_headers_all prha
                                                   WHERE     prha.attribute1 =
                                                             xxd.transfer_type_value
                                                         AND prha.requisition_header_id =
                                                             pr_line.source_document_id)-- End changes for CCR0009490
                                                                                        ))));

            IF xt_eligible_lines.COUNT != 0
            THEN
                msg (
                    'Found traditional BULK lines in the eligable criteria; returning those');
                RETURN;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
            WHEN OTHERS
            THEN
                msg ('Unepected error in bulk lines query ' || SQLERRM, 1);
                RAISE;
        END;

        msg ('Fell out the bottom of bulk collection');
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Unepected error in get_eligible_bulk_lines ' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_unexp_error;
    END get_eligible_bulk_lines;
END xxd_ont_bulk_rules_pkg;
/
