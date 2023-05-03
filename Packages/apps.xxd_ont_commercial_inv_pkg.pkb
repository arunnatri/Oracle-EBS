--
-- XXD_ONT_COMMERCIAL_INV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_COMMERCIAL_INV_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_COMMERCIAL_INV_PKG
    * Design       : This package is used for Commercial Invoice Printing
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 23-Oct-2017  1.0        Viswanathan Pandian     Initial Version
    -- 08-Jan-2018  1.1        Viswanathan Pandian     Modified for CCR0006972
    -- 14-Sep-2020  1.2        Viswanathan Pandian     Modified for CCR0008507
    ******************************************************************************************/
    gc_shipment_type   VARCHAR2 (20);                  -- Added for CCR0008507

    FUNCTION insert_data
        RETURN BOOLEAN
    AS
        CURSOR get_headers_c IS
            SELECT ds.shipment_id shipment_id, -- Start changes for CCR0006972
                                               -- TO_CHAR (SYSDATE, 'DD-MON-YYYY') run_date,
                                               TO_CHAR (ds.ownership_fob_date, 'DD-MON-YYYY') run_date, -- End changes for CCR0006972
                                                                                                        ds.invoice_num factory_inv_num,
                   ds.vessel_name vessel_name, TO_CHAR (ds.etd, 'DD-MON-YYYY') est_dep_date, DECODE (ds.shipment_type,  'BOAT', 'Ocean',  'AIR', 'Air',  ds.shipment_type) mode_of_trans,
                   rsh.shipment_header_id header_id, 'STANDALONE' program_mode
              FROM custom.do_shipments ds, rcv_shipment_headers rsh
             WHERE     TO_CHAR (ds.shipment_id) = REGEXP_SUBSTR (rsh.shipment_num, '[^-]+', 1
                                                                 , 1)
                   AND ((p_factory_inv_num IS NOT NULL AND ds.invoice_num = p_factory_inv_num) OR (p_factory_inv_num IS NULL AND 1 = 1))
                   AND ((p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND ds.ownership_fob_date IS NOT NULL AND TRUNC (ds.ownership_fob_date) BETWEEN TRUNC (fnd_date.canonical_to_date (p_from_date)) AND TRUNC (fnd_date.canonical_to_date (p_to_date))) OR ((p_from_date IS NULL OR p_to_date IS NULL) AND 1 = 1))
                   AND p_shipment_type = 'Factory Shipment to Subsidiaries'
                   AND p_sch_run = 'N'
            UNION
            SELECT NULL shipment_id, -- Start changes for CCR0006972
                                     -- TO_CHAR (SYSDATE, 'DD-MON-YYYY') run_date,
                                     NULL run_date, -- End changes for CCR0006972
                                                    NULL factory_inv_num,
                   NULL vessel_name, NULL est_dep_date, NULL mode_of_trans,
                   ooha.header_id, 'STANDALONE' program_mode
              FROM oe_order_headers_all ooha
             WHERE     p_shipment_type = 'DC to DC Transfer'
                   AND p_sch_run = 'N'
                   AND (   (p_order_number IS NOT NULL AND ooha.order_number = p_order_number)
                        OR (    p_from_date IS NOT NULL
                            AND p_to_date IS NOT NULL
                            AND EXISTS
                                    (SELECT 1
                                       FROM oe_order_lines_all oola, wsh_delivery_details wdd, wsh_new_deliveries wnd,
                                            wsh_delivery_assignments wda, oe_order_sources oos
                                      WHERE     oola.header_id =
                                                ooha.header_id
                                            AND oola.cancelled_flag = 'N'
                                            AND wdd.source_header_id =
                                                ooha.header_id
                                            AND wdd.source_line_id =
                                                oola.line_id
                                            AND wdd.source_code = 'OE'
                                            AND wdd.delivery_detail_id =
                                                wda.delivery_detail_id
                                            AND wda.delivery_id =
                                                wnd.delivery_id
                                            AND ooha.order_source_id =
                                                oos.order_source_id
                                            AND oos.name = 'Internal'
                                            AND ooha.flow_status_code NOT IN
                                                    ('ENTERED', 'CANCELLED')
                                            AND ooha.org_id =
                                                fnd_global.org_id
                                            AND TRUNC (wnd.confirm_date) BETWEEN TRUNC (
                                                                                     fnd_date.canonical_to_date (
                                                                                         p_from_date))
                                                                             AND TRUNC (
                                                                                     fnd_date.canonical_to_date (
                                                                                         p_to_date)))))
            UNION
            SELECT shipment_id, run_date, factory_inv_num,
                   vessel_name, est_dep_date, mode_of_trans,
                   shipment_header_id header_id, program_mode
              FROM xxdo.xxd_ont_commercial_inv_t
             WHERE     program_mode = 'BACK_TO_BACK'
                   AND record_status = 'N'
                   AND p_sch_run = 'Y'
                   AND creation_date <=
                         SYSDATE
                       - (NVL (TO_NUMBER (fnd_profile.VALUE ('XXD_ONT_COMM_INV_DELAY_TIME')), 1) / 24)
                   AND p_factory_inv_num IS NULL
            ORDER BY header_id;

        CURSOR get_details_c (p_header_id IN NUMBER, p_shipment_id IN NUMBER)
        IS
              SELECT 'FAC'
                         shipment_type,
                     NULL
                         lines_mode_of_trans,
                     NULL
                         lines_est_dep_date,
                     ooha.order_number
                         sales_order,
                     ooha.transactional_curr_code
                         curr_code,
                        'CI'
                     || p_shipment_id
                     || '-'
                     || TO_CHAR (MIN (rsh.creation_date), 'YYYYMMDD')
                         inv_num,
                     -- Start changes for CCR0006972
                     TO_CHAR (MIN (rsh.creation_date), 'DD-MON-YYYY')
                         line_run_date,
                     -- End changes for CCR0006972
                     rsl.item_description
                         item_desc,
                     mc.attribute7
                         style_number,
                     mc.attribute8
                         color_code,
                     SUM (rsl.quantity_shipped)
                         quantity,
                     oola.unit_selling_price
                         price,
                     ROUND (
                         SUM (rsl.quantity_shipped * oola.unit_selling_price),
                         2)
                         total,
                     pha.segment1
                         factory_po,
                     vend_dtls.geography_name
                         country_of_origin,
                     xxd_ont_commercial_inv_pkg.get_hts_code (
                         mc.attribute7,
                         ood.organization_id)
                         hts_comm_code,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'NAME')
                         sold_by,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE1')
                         sold_by_line1,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE2')
                         sold_by_line2,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE3')
                         sold_by_line3,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE4')
                         sold_by_line4,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'NAME')
                         sold_to,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE1')
                         sold_to_line1,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE2')
                         sold_to_line2,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE3')
                         sold_to_line3,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE4')
                         sold_to_line4,
                     -- Start changes for CCR0008507
                     NULL
                         ship_to,
                     -- End changes for CCR0008507
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE1')
                         ship_to_line1,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE2')
                         ship_to_line2,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE3')
                         ship_to_line3,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE4')
                         ship_to_line4,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE5')
                         ship_to_line5,
                     xxd_ont_commercial_inv_pkg.get_vat (
                         ooha.invoice_to_org_id,
                         ooha.ship_to_org_id)
                         vat,
                     'FOB' || ' ' || vend_dtls.city
                         shipping_terms,
                     (SELECT NVL (hcsu.attribute1, 'deckers.citeam@deckers.com')
                        FROM hz_cust_site_uses_all hcsu
                       WHERE hcsu.site_use_id = ooha.ship_to_org_id)
                         email_address,
                     -- Start changes for CCR0008507
                     NULL
                         ship_from,
                     NULL
                         ship_from_line1,
                     NULL
                         ship_from_line2,
                     NULL
                         ship_from_line3,
                     NULL
                         ship_from_line4,
                     NULL
                         ship_from_line5,
                     NULL
                         ship_from_vat,
                     NULL
                         sold_by_vat,
                     NULL
                         sold_to_vat,
                     NULL
                         ship_to_vat,
                     NULL
                         tax_code,
                     NULL
                         tax_rate,
                     NULL
                         tax_amt,
                     NULL
                         tax_stmt
                -- End changes for CCR0008507
                FROM oe_order_headers_all ooha,
                     oe_order_lines_all oola,
                     mtl_item_categories mic,
                     mtl_category_sets mcs,
                     mtl_categories mc,
                     po_headers_all pha,
                     po_lines_all pla,
                     rcv_shipment_lines rsl,
                     rcv_shipment_headers rsh,
                     po_location_associations_all plaa,
                     org_organization_definitions ood,
                     (SELECT hg.geography_name, apsa.city, apsa.vendor_id,
                             apsa.vendor_site_code, apsa.org_id
                        FROM ap_supplier_sites_all apsa, hz_geographies hg
                       WHERE     apsa.country = hg.geography_code
                             AND hg.geography_type = 'COUNTRY') vend_dtls
               WHERE     ooha.header_id = oola.header_id
                     AND mic.category_set_id = mcs.category_set_id
                     AND mic.category_id = mc.category_id
                     AND mc.structure_id = mcs.structure_id
                     AND mcs.category_set_name = 'Inventory'
                     AND oola.inventory_item_id = mic.inventory_item_id
                     AND oola.ship_from_org_id = mic.organization_id
                     AND pla.po_line_id = rsl.po_line_id
                     AND pha.po_header_id = rsl.po_header_id
                     AND rsh.shipment_header_id = rsl.shipment_header_id
                     AND ood.organization_id = plaa.organization_id
                     AND plaa.site_use_id(+) = ooha.ship_to_org_id
                     AND vend_dtls.vendor_id = pha.vendor_id
                     AND vend_dtls.vendor_site_code(+) = pla.attribute7
                     AND vend_dtls.org_id(+) = pla.org_id
                     AND rsh.shipment_header_id = p_header_id
                     AND oola.attribute16 = TO_CHAR (rsl.po_line_location_id)
                     AND oola.line_id = TO_NUMBER (rsl.attribute3) -- Added for CCR0006972
                     AND p_shipment_type = 'Factory Shipment to Subsidiaries'
            GROUP BY rsl.item_description, mc.attribute7, mc.attribute8,
                     ooha.order_number, pha.segment1, ooha.org_id,
                     ooha.transactional_curr_code, ood.operating_unit, ood.organization_id,
                     ooha.invoice_to_org_id, ooha.ship_to_org_id, vend_dtls.geography_name,
                     vend_dtls.city, oola.unit_selling_price
            UNION
              SELECT 'DC'
                         shipment_type,
                     DECODE (MIN (wnd.mode_of_transport),
                             'BOAT', 'Ocean',
                             'AIR', 'Air',
                             'PARCEL', 'Parcel',
                             MIN (wnd.mode_of_transport))
                         lines_mode_of_trans,
                     TO_CHAR (MIN (wnd.initial_pickup_date), 'DD-MON-YYYY')
                         lines_est_dep_date,
                     ooha.order_number
                         sales_order,
                     ooha.transactional_curr_code
                         curr_code,
                        'CI'
                     || wnd.delivery_id
                     || '-'
                     || TO_CHAR (MIN (wnd.confirm_date), 'YYYYMMDD')
                         inv_num,
                     TO_CHAR (MIN (wnd.confirm_date), 'DD-MON-YYYY')
                         line_run_date,                -- Added for CCR0006972
                     msib.description
                         item_desc,
                     mc.attribute7
                         style_number,
                     mc.attribute8
                         color_code,
                     SUM (wdd.requested_quantity)
                         quantity,
                     oola.unit_selling_price
                         price,
                     ROUND (
                         SUM (wdd.requested_quantity * oola.unit_selling_price),
                         2)
                         total,
                     NULL
                         factory_po,
                     NULL
                         country_of_origin,
                     xxd_ont_commercial_inv_pkg.get_hts_code (
                         mc.attribute7,
                         ood.organization_id)
                         hts_comm_code,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'NAME')
                         sold_by,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE1')
                         sold_by_line1,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE2')
                         sold_by_line2,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'LINE3')
                         sold_by_line3,
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id, 'TER')
                         sold_by_line4,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'NAME')
                         sold_to,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE1')
                         sold_to_line1,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE2')
                         sold_to_line2,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'LINE3')
                         sold_to_line3,
                     xxd_ont_commercial_inv_pkg.le_address (ood.operating_unit,
                                                            'TER')
                         sold_to_line4,
                     -- Modified all Ship_To column mappings for CCR0008507
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LE')
                         ship_to,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE1')
                         ship_to_line1,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE2')
                         ship_to_line2,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE3')
                         ship_to_line3,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE4')
                         ship_to_line4,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         ood.organization_id,
                         'LINE5')
                         ship_to_line5,
                     -- Start changes for CCR0008507
                     --xxd_ont_commercial_inv_pkg.get_vat (ooha.invoice_to_org_id,
                     --                                    ooha.ship_to_org_id)
                     NULL
                         -- End changes for CCR0008507
                         vat,
                     -- Start changes for CCR0008507
                     CASE
                         WHEN mp.organization_code IN ('ME1', 'ME2')
                         THEN
                             'FCA'
                         ELSE
                             -- End changes for CCR0008507
                             (SELECT 'Ex Works' || NVL2 (NVL (hl.state, hl.province), ', ' || NVL (hl.state, hl.province), NULL)
                                FROM hz_locations hl, hz_party_sites hps, hz_cust_acct_sites_all hcsa,
                                     hz_cust_site_uses_all hcsu
                               WHERE     hcsu.cust_acct_site_id =
                                         hcsa.cust_acct_site_id
                                     AND hcsa.party_site_id = hps.party_site_id
                                     AND hps.location_id = hl.location_id
                                     AND hcsu.site_use_id = ooha.ship_to_org_id)
                     END                               -- Added for CCR0008507
                         shipping_terms,
                     NULL
                         email_address,
                     -- Start changes for CCR0008507
                     xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                            'NAME')
                         ship_from,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         oola.ship_from_org_id,
                         'LINE1')
                         ship_from_line1,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         oola.ship_from_org_id,
                         'LINE2')
                         ship_from_line2,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         oola.ship_from_org_id,
                         'LINE3')
                         ship_from_line3,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         oola.ship_from_org_id,
                         'LINE4')
                         ship_from_line4,
                     xxd_ont_commercial_inv_pkg.org_address (
                         ood.operating_unit,
                         oola.ship_from_org_id,
                         'LINE5')
                         ship_from_line5,
                        'VAT Registration: '
                     || xxd_ont_commercial_inv_pkg.org_address (
                            ood.operating_unit,
                            oola.ship_from_org_id,
                            'VAT')
                         ship_from_vat,
                        'VAT Registration: '
                     || xxd_ont_commercial_inv_pkg.le_address (ooha.org_id,
                                                               'VAT')
                         sold_by_vat,
                        'VAT Registration: '
                     || xxd_ont_commercial_inv_pkg.le_address (
                            ood.operating_unit,
                            'VAT')
                         sold_to_vat,
                        'VAT Registration: '
                     || xxd_ont_commercial_inv_pkg.org_address (
                            ood.operating_unit,
                            ood.organization_id,
                            'VAT')
                         ship_to_vat,
                     (SELECT MIN (zrb.tax_rate_code)
                        FROM zx_rates_b zrb, oe_price_adjustments opa, oe_order_lines_all oola1
                       WHERE     zrb.tax_rate_id = opa.tax_rate_id
                             AND opa.header_id = ooha.header_id
                             AND opa.line_id = oola1.line_id
                             AND opa.header_id = oola1.header_id
                             AND SUBSTR (oola1.ordered_item,
                                         1,
                                           INSTR (oola1.ordered_item, '-', 1,
                                                  2)
                                         - 1) =
                                 mc.attribute7 || '-' || mc.attribute8
                             AND opa.list_line_type_code = 'TAX')
                         tax_code,
                     (SELECT MIN (opa.operand)
                        FROM oe_price_adjustments opa, oe_order_lines_all oola1
                       WHERE     opa.header_id = ooha.header_id
                             AND opa.line_id = oola1.line_id
                             AND opa.header_id = oola1.header_id
                             AND SUBSTR (oola1.ordered_item,
                                         1,
                                           INSTR (oola1.ordered_item, '-', 1,
                                                  2)
                                         - 1) =
                                 mc.attribute7 || '-' || mc.attribute8
                             AND opa.list_line_type_code = 'TAX')
                         tax_rate,
                     NVL (
                         (SELECT SUM (opa.adjusted_amount)
                            FROM oe_price_adjustments opa, oe_order_lines_all oola1
                           WHERE     opa.header_id = ooha.header_id
                                 AND opa.line_id = oola1.line_id
                                 AND opa.header_id = oola1.header_id
                                 AND SUBSTR (oola1.ordered_item,
                                             1,
                                               INSTR (oola1.ordered_item, '-', 1
                                                      , 2)
                                             - 1) =
                                     mc.attribute7 || '-' || mc.attribute8
                                 AND opa.list_line_type_code = 'TAX'),
                         0)
                         tax_amt,
                     CASE
                         WHEN mp.organization_code IN ('ME1', 'ME2')
                         THEN
                             'Article 156. b- Exemption Transfer of own goods between customs warehouse arrangements'
                         ELSE
                             NULL
                     END
                         tax_stmt
                -- End changes for CCR0008507
                FROM oe_order_headers_all ooha, oe_order_lines_all oola, mtl_system_items_b msib,
                     mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                     po_location_associations_all plaa, org_organization_definitions ood, wsh_delivery_details wdd,
                     wsh_new_deliveries wnd, mtl_parameters mp, -- Added for CCR0008507
                                                                wsh_delivery_assignments wda
               WHERE     ooha.header_id = oola.header_id
                     AND mic.category_set_id = mcs.category_set_id
                     AND mic.category_id = mc.category_id
                     AND mc.structure_id = mcs.structure_id
                     AND mcs.category_set_name = 'Inventory'
                     AND oola.inventory_item_id = msib.inventory_item_id
                     AND oola.ship_from_org_id = msib.organization_id
                     AND oola.cancelled_flag = 'N'
                     AND mic.inventory_item_id = msib.inventory_item_id
                     AND mic.organization_id = msib.organization_id
                     AND ood.organization_id = plaa.organization_id
                     AND plaa.site_use_id(+) = ooha.ship_to_org_id
                     AND wdd.source_header_id = ooha.header_id
                     AND wdd.source_line_id = oola.line_id
                     AND mp.organization_id = oola.ship_from_org_id -- Added for CCR0008507
                     AND wdd.source_code = 'OE'
                     AND wdd.delivery_detail_id = wda.delivery_detail_id
                     AND wda.delivery_id = wnd.delivery_id
                     AND ooha.header_id = p_header_id
                     AND p_shipment_type = 'DC to DC Transfer'
            GROUP BY msib.description, mc.attribute7, mc.attribute8,
                     ooha.order_number, ooha.org_id, ooha.transactional_curr_code,
                     ood.operating_unit, ood.organization_id, ooha.invoice_to_org_id,
                     ooha.ship_to_org_id, -- Start changes for CCR0008507
                                          ooha.header_id, oola.ship_from_org_id,
                     mp.organization_code, -- End changes for CCR0008507
                                           wnd.delivery_id, oola.unit_selling_price
            ORDER BY sales_order, style_number, color_code;
    BEGIN
        IF     p_shipment_type = 'Factory Shipment to Subsidiaries'
           AND p_sch_run = 'N'
           AND p_factory_inv_num IS NULL
           AND (p_from_date IS NULL OR p_to_date IS NULL)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Either Factory Invoice Number or Data Range should be passed');
            RETURN FALSE;
        ELSIF     p_shipment_type = 'DC to DC Transfer'
              AND p_order_number IS NULL
              AND (p_from_date IS NULL OR p_to_date IS NULL)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Either Order Number or Data Range should be passed');
            RETURN FALSE;
        ELSE
            -- Start changes for CCR0008507
            IF p_shipment_type = 'Factory Shipment to Subsidiaries'
            THEN
                gc_shipment_type   := 'FAC';
            ELSE
                gc_shipment_type   := 'DC';
            END IF;

            -- End changes for CCR0008507
            FOR headers_rec IN get_headers_c
            LOOP
                FOR details_rec
                    IN get_details_c (headers_rec.header_id,
                                      headers_rec.shipment_id)
                LOOP
                    INSERT INTO xxdo.xxd_ont_commercial_inv_t (
                                    shipment_type,
                                    inv_num,
                                    run_date,
                                    factory_inv_num,
                                    shipment_header_id,
                                    shipment_id,
                                    sales_order,
                                    header_id,
                                    vessel_name,
                                    est_dep_date,
                                    mode_of_trans,
                                    curr_code,
                                    item_desc,
                                    style_number,
                                    color_code,
                                    quantity,
                                    price,
                                    total,
                                    factory_po,
                                    country_of_origin,
                                    hts_comm_code,
                                    sold_by,
                                    sold_by_line1,
                                    sold_by_line2,
                                    sold_by_line3,
                                    sold_by_line4,
                                    sold_to,
                                    sold_to_line1,
                                    sold_to_line2,
                                    sold_to_line3,
                                    sold_to_line4,
                                    ship_to,           -- Added for CCR0008507
                                    ship_to_line1,
                                    ship_to_line2,
                                    ship_to_line3,
                                    ship_to_line4,
                                    ship_to_line5,
                                    vat,
                                    shipping_terms,
                                    email_address,
                                    send_email,
                                    -- Start changes for CCR0008507
                                    ship_from,
                                    ship_from_line1,
                                    ship_from_line2,
                                    ship_from_line3,
                                    ship_from_line4,
                                    ship_from_line5,
                                    ship_from_vat,
                                    sold_by_vat,
                                    sold_to_vat,
                                    ship_to_vat,
                                    tax_code,
                                    tax_rate,
                                    tax_amt,
                                    tax_stmt,
                                    -- End changes for CCR0008507
                                    program_from_date,
                                    program_to_date,
                                    program_mode,
                                    record_status,
                                    org_id,
                                    request_id,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (details_rec.shipment_type, details_rec.inv_num, -- Start changes for CCR0006972
                                                                                 -- headers_rec.run_date,
                                                                                 NVL (headers_rec.run_date, details_rec.line_run_date), -- End changes for CCR0006972
                                                                                                                                        headers_rec.factory_inv_num, DECODE (details_rec.shipment_type, 'FAC', headers_rec.header_id, NULL), headers_rec.shipment_id, details_rec.sales_order, DECODE (details_rec.shipment_type, 'DC', headers_rec.header_id, NULL), headers_rec.vessel_name, NVL (headers_rec.est_dep_date, details_rec.lines_est_dep_date), NVL (headers_rec.mode_of_trans, details_rec.lines_mode_of_trans), details_rec.curr_code, details_rec.item_desc, details_rec.style_number, details_rec.color_code, details_rec.quantity, details_rec.price, details_rec.total, details_rec.factory_po, details_rec.country_of_origin, details_rec.hts_comm_code, details_rec.sold_by, details_rec.sold_by_line1, details_rec.sold_by_line2, details_rec.sold_by_line3, details_rec.sold_by_line4, details_rec.sold_to, details_rec.sold_to_line1, details_rec.sold_to_line2, details_rec.sold_to_line3, details_rec.sold_to_line4, details_rec.ship_to, -- Added for CCR0008507
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      details_rec.ship_to_line1, details_rec.ship_to_line2, details_rec.ship_to_line3, details_rec.ship_to_line4, details_rec.ship_to_line5, details_rec.vat, details_rec.shipping_terms, details_rec.email_address, p_send_email, -- Start changes for CCR0008507
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   details_rec.ship_from, details_rec.ship_from_line1, details_rec.ship_from_line2, details_rec.ship_from_line3, details_rec.ship_from_line4, details_rec.ship_from_line5, details_rec.ship_from_vat, details_rec.sold_by_vat, details_rec.sold_to_vat, details_rec.ship_to_vat, details_rec.tax_code, details_rec.tax_rate, details_rec.tax_amt, details_rec.tax_stmt, -- End changes for CCR0008507
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        TRUNC (fnd_date.canonical_to_date (p_from_date)), TRUNC (fnd_date.canonical_to_date (p_to_date)), headers_rec.program_mode, 'I', fnd_global.org_id, fnd_global.conc_request_id, SYSDATE, fnd_global.user_id
                                 , SYSDATE, fnd_global.user_id);
                END LOOP;
            END LOOP;

            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'OTHERS Exception in INSERT_DATA:' || SQLERRM);
            RETURN FALSE;
    END insert_data;

    FUNCTION le_address (p_organization_id IN hr_all_organization_units.organization_id%TYPE, p_output_type IN VARCHAR2)
        RETURN VARCHAR2
    AS
        CURSOR get_le_address_c IS
            SELECT xep.name, hl.address_line_1, hl.address_line_2,
                   hl.town_or_city, hl.postal_code, ftv.territory_short_name,
                   hl.country                          -- Added for CCR0008507
              FROM xle_entity_profiles xep, xle_registrations xr, hr_operating_units hou,
                   hr_all_organization_units haou, hr_locations_all hl, gl_legal_entities_bsvs gleb,
                   fnd_territories_vl ftv
             WHERE     xep.transacting_entity_flag = 'Y'
                   AND xep.legal_entity_id = xr.source_id
                   AND xr.source_table = 'XLE_ENTITY_PROFILES'
                   AND xr.identifying_flag = 'Y'
                   AND xep.legal_entity_id = hou.default_legal_context_id
                   AND xr.location_id = hl.location_id
                   AND xep.legal_entity_id = gleb.legal_entity_id
                   AND haou.organization_id = hou.organization_id
                   AND ftv.territory_code = hl.country
                   AND haou.organization_id = p_organization_id;

        lc_return_value   VARCHAR2 (1000);
        lcu_le_address    get_le_address_c%ROWTYPE;
    BEGIN
        OPEN get_le_address_c;

        FETCH get_le_address_c INTO lcu_le_address;

        CLOSE get_le_address_c;

        IF p_output_type = 'NAME'
        THEN
            lc_return_value   := lcu_le_address.name;
        ELSIF p_output_type = 'LINE1'
        THEN
            IF lcu_le_address.address_line_1 IS NOT NULL
            THEN
                lc_return_value   := lcu_le_address.address_line_1;
            ELSE
                lc_return_value   := lcu_le_address.address_line_2;
            END IF;
        ELSIF p_output_type = 'LINE2'
        THEN
            IF     lcu_le_address.address_line_1 IS NOT NULL
               AND lcu_le_address.address_line_2 IS NOT NULL
            THEN
                lc_return_value   := lcu_le_address.address_line_2;
            ELSIF     lcu_le_address.address_line_1 IS NOT NULL
                  AND lcu_le_address.address_line_2 IS NULL
            THEN
                IF     lcu_le_address.town_or_city IS NOT NULL
                   AND lcu_le_address.postal_code IS NOT NULL
                THEN
                    lc_return_value   :=
                           lcu_le_address.town_or_city
                        || ', '
                        || lcu_le_address.postal_code;
                ELSIF     lcu_le_address.town_or_city IS NOT NULL
                      AND lcu_le_address.postal_code IS NULL
                THEN
                    lc_return_value   := lcu_le_address.town_or_city;
                END IF;
            END IF;
        ELSIF p_output_type = 'LINE3'
        THEN
            IF     lcu_le_address.address_line_1 IS NOT NULL
               AND lcu_le_address.address_line_2 IS NOT NULL
            THEN
                IF     lcu_le_address.town_or_city IS NOT NULL
                   AND lcu_le_address.postal_code IS NOT NULL
                THEN
                    lc_return_value   :=
                           lcu_le_address.town_or_city
                        || ', '
                        || lcu_le_address.postal_code;
                ELSIF     lcu_le_address.town_or_city IS NOT NULL
                      AND lcu_le_address.postal_code IS NULL
                THEN
                    lc_return_value   := lcu_le_address.town_or_city;
                END IF;
            ELSIF     lcu_le_address.address_line_1 IS NOT NULL
                  AND lcu_le_address.address_line_2 IS NULL
            THEN
                lc_return_value   := lcu_le_address.territory_short_name;
            END IF;
        ELSIF p_output_type = 'LINE4'
        THEN
            IF     lcu_le_address.address_line_1 IS NOT NULL
               AND lcu_le_address.address_line_2 IS NOT NULL
            THEN
                lc_return_value   := lcu_le_address.territory_short_name;
            ELSE
                lc_return_value   := NULL;
            END IF;
        END IF;

        -- Start changes for CCR0008507
        IF p_output_type = 'VAT'
        THEN
            BEGIN
                SELECT MIN (xcd.attribute5)
                  INTO lc_return_value
                  FROM xle_entity_profiles xep, xxcp_cust_data xcd
                 WHERE     xep.legal_entity_identifier = xcd.attribute1
                       AND xcd.category_name = 'ONESOURCE GEO VAT MATRIX'
                       AND xcd.attribute5 IS NOT NULL
                       AND xcd.attribute4 = lcu_le_address.country
                       AND xep.name = lcu_le_address.name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_return_value   := NULL;
            END;
        END IF;

        -- End changes for CCR0008507

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END le_address;

    FUNCTION org_address (p_operating_unit IN hr_all_organization_units.organization_id%TYPE, p_organization_id IN mtl_parameters.organization_id%TYPE, p_output_type IN VARCHAR2)
        RETURN VARCHAR2
    AS
        CURSOR get_org_address_c IS
            SELECT mp.organization_code,
                   houv.address_line_1,
                   houv.address_line_2,
                   houv.town_or_city,
                   houv.postal_code,
                   ftv.territory_short_name,
                   houv.attribute5 le_name,
                   -- Start changes for CCR0008507
                   (SELECT hl.description
                      FROM hr_locations hl
                     WHERE hl.location_id = houv.location_id) org_desc,
                   houv.country
              -- End changes for CCR0008507
              FROM mtl_parameters mp, hr_organization_units_v houv, fnd_territories_vl ftv
             WHERE     mp.organization_id = houv.organization_id
                   AND houv.country = ftv.territory_code
                   AND mp.organization_id = p_organization_id;

        lc_return_value   VARCHAR2 (1000);
        lcu_org_address   get_org_address_c%ROWTYPE;
        lc_name           VARCHAR2 (1000);
        lc_desc           VARCHAR2 (1000);             -- Added for CCR0008507
    BEGIN
        OPEN get_org_address_c;

        FETCH get_org_address_c INTO lcu_org_address;

        CLOSE get_org_address_c;

        lc_name   :=
            NVL (
                lcu_org_address.le_name,
                xxd_ont_commercial_inv_pkg.le_address (p_operating_unit,
                                                       'NAME'));

        lc_desc   := lcu_org_address.org_desc;         -- Added for CCR0008507

        IF lcu_org_address.organization_code = 'EU3'
        THEN
            IF p_output_type = 'LINE1'
            THEN
                lc_return_value   := lc_name;
            ELSIF p_output_type = 'LINE2'
            THEN
                lc_return_value   := 'Limited Fiscal Representation';
            ELSIF p_output_type = 'LINE3'
            THEN
                IF lcu_org_address.address_line_1 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.address_line_1;
                ELSE
                    lc_return_value   := lcu_org_address.address_line_2;
                END IF;
            ELSIF p_output_type = 'LINE4'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.address_line_2;
                ELSIF     lcu_org_address.address_line_1 IS NOT NULL
                      AND lcu_org_address.address_line_2 IS NULL
                THEN
                    IF     lcu_org_address.town_or_city IS NOT NULL
                       AND lcu_org_address.postal_code IS NOT NULL
                    THEN
                        lc_return_value   :=
                               lcu_org_address.town_or_city
                            || ', '
                            || lcu_org_address.postal_code;
                    ELSIF     lcu_org_address.town_or_city IS NOT NULL
                          AND lcu_org_address.postal_code IS NULL
                    THEN
                        lc_return_value   := lcu_org_address.town_or_city;
                    END IF;
                END IF;
            ELSIF p_output_type = 'LINE5'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    IF     lcu_org_address.town_or_city IS NOT NULL
                       AND lcu_org_address.postal_code IS NOT NULL
                    THEN
                        lc_return_value   :=
                               lcu_org_address.town_or_city
                            || ', '
                            || lcu_org_address.postal_code;
                    ELSIF     lcu_org_address.town_or_city IS NOT NULL
                          AND lcu_org_address.postal_code IS NULL
                    THEN
                        lc_return_value   := lcu_org_address.town_or_city;
                    END IF;
                ELSE
                    lc_return_value   := lcu_org_address.territory_short_name;
                END IF;
            END IF;
        -- Start changes for CCR0008507
        -- ELSE
        ELSIF gc_shipment_type = 'FAC'
        THEN
            -- End changes for CCR0008507
            IF p_output_type = 'LINE1'
            THEN
                lc_return_value   := lc_name;
            ELSIF p_output_type = 'LINE2'
            THEN
                IF lcu_org_address.address_line_1 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.address_line_1;
                ELSE
                    lc_return_value   := lcu_org_address.address_line_2;
                END IF;
            ELSIF p_output_type = 'LINE3'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.address_line_2;
                ELSIF     lcu_org_address.address_line_1 IS NOT NULL
                      AND lcu_org_address.address_line_2 IS NULL
                THEN
                    IF     lcu_org_address.town_or_city IS NOT NULL
                       AND lcu_org_address.postal_code IS NOT NULL
                    THEN
                        lc_return_value   :=
                               lcu_org_address.town_or_city
                            || ', '
                            || lcu_org_address.postal_code;
                    ELSIF     lcu_org_address.town_or_city IS NOT NULL
                          AND lcu_org_address.postal_code IS NULL
                    THEN
                        lc_return_value   := lcu_org_address.town_or_city;
                    END IF;
                END IF;
            ELSIF p_output_type = 'LINE4'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    IF     lcu_org_address.town_or_city IS NOT NULL
                       AND lcu_org_address.postal_code IS NOT NULL
                    THEN
                        lc_return_value   :=
                               lcu_org_address.town_or_city
                            || ', '
                            || lcu_org_address.postal_code;
                    ELSIF     lcu_org_address.town_or_city IS NOT NULL
                          AND lcu_org_address.postal_code IS NULL
                    THEN
                        lc_return_value   := lcu_org_address.town_or_city;
                    END IF;
                ELSE
                    lc_return_value   := lcu_org_address.territory_short_name;
                END IF;
            ELSIF p_output_type = 'LINE5'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.territory_short_name;
                END IF;
            END IF;
        -- Start changes for CCR0008507
        -- END IF;
        ELSE
            IF p_output_type = 'LE'
            THEN
                lc_return_value   := lc_name;
            ELSIF p_output_type = 'LINE1'
            THEN
                lc_return_value   := lc_desc;
            ELSIF p_output_type = 'LINE2'
            THEN
                IF lcu_org_address.address_line_1 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.address_line_1;
                ELSE
                    lc_return_value   := lcu_org_address.address_line_2;
                END IF;
            ELSIF p_output_type = 'LINE3'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.address_line_2;
                ELSE
                    IF     lcu_org_address.town_or_city IS NOT NULL
                       AND lcu_org_address.postal_code IS NOT NULL
                    THEN
                        lc_return_value   :=
                               lcu_org_address.town_or_city
                            || ', '
                            || lcu_org_address.postal_code;
                    ELSIF     lcu_org_address.town_or_city IS NOT NULL
                          AND lcu_org_address.postal_code IS NULL
                    THEN
                        lc_return_value   := lcu_org_address.town_or_city;
                    END IF;
                END IF;
            ELSIF p_output_type = 'LINE4'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    IF     lcu_org_address.town_or_city IS NOT NULL
                       AND lcu_org_address.postal_code IS NOT NULL
                    THEN
                        lc_return_value   :=
                               lcu_org_address.town_or_city
                            || ', '
                            || lcu_org_address.postal_code;
                    ELSIF     lcu_org_address.town_or_city IS NOT NULL
                          AND lcu_org_address.postal_code IS NULL
                    THEN
                        lc_return_value   := lcu_org_address.town_or_city;
                    END IF;
                ELSE
                    lc_return_value   := lcu_org_address.territory_short_name;
                END IF;
            ELSIF p_output_type = 'LINE5'
            THEN
                IF     lcu_org_address.address_line_1 IS NOT NULL
                   AND lcu_org_address.address_line_2 IS NOT NULL
                THEN
                    lc_return_value   := lcu_org_address.territory_short_name;
                END IF;
            END IF;
        END IF;

        IF p_output_type = 'VAT'
        THEN
            BEGIN
                SELECT MIN (xcd.attribute5)
                  INTO lc_return_value
                  FROM xle_entity_profiles xep, xxcp_cust_data xcd
                 WHERE     xep.legal_entity_identifier = xcd.attribute1
                       AND xcd.category_name = 'ONESOURCE GEO VAT MATRIX'
                       AND xcd.attribute5 IS NOT NULL
                       AND xcd.attribute4 = lcu_org_address.country
                       AND xep.name = lc_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_return_value   := NULL;
            END;
        END IF;

        -- End changes for CCR0008507
        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END org_address;

    FUNCTION get_vat (p_bill_to_site_use_id hz_cust_site_uses_all.site_use_id%TYPE, p_ship_to_site_use_id hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_vat_c IS
            SELECT NVL2 (NVL (hcsu_ship.tax_reference, hcsu_bill.tax_reference), 'VAT# ' || NVL (hcsu_ship.tax_reference, hcsu_bill.tax_reference), NULL)
              FROM hz_parties hp, hz_cust_accounts hca, hz_cust_acct_sites_all hcas,
                   hz_cust_site_uses_all hcsu_bill, hz_cust_site_uses_all hcsu_ship
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu_bill.cust_acct_site_id
                   AND hcas.cust_acct_site_id = hcsu_ship.cust_acct_site_id
                   AND hcsu_bill.cust_acct_site_id =
                       hcsu_ship.cust_acct_site_id
                   AND hcsu_bill.site_use_id = p_bill_to_site_use_id
                   AND hcsu_ship.site_use_id = p_ship_to_site_use_id;

        lc_return_value   VARCHAR2 (1000);
    BEGIN
        OPEN get_vat_c;

        FETCH get_vat_c INTO lc_return_value;

        CLOSE get_vat_c;

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_vat;

    FUNCTION get_hts_code (p_style_number IN xxd_common_items_v.style_number%TYPE, p_organization_id IN mtl_parameters.organization_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_hts_code_c IS
            SELECT dhtc.harmonized_tariff_code
              FROM do_custom.do_harmonized_tariff_codes dhtc, fnd_lookup_values flv, mtl_parameters mp
             WHERE     dhtc.country = flv.description
                   AND mp.organization_code = flv.lookup_code
                   AND flv.lookup_type = 'XXD_INV_HTS_REGION_INV_ORG_MAP'
                   AND flv.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.enabled_flag = 'Y'
                   AND mp.organization_id = p_organization_id
                   AND dhtc.style_number = p_style_number;

        lc_return_value   VARCHAR2 (1000);
    BEGIN
        OPEN get_hts_code_c;

        FETCH get_hts_code_c INTO lc_return_value;

        CLOSE get_hts_code_c;

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_hts_code;

    FUNCTION submit_bursting
        RETURN BOOLEAN
    AS
        lb_result       BOOLEAN := TRUE;
        ln_req_id       NUMBER;
        ln_data_count   NUMBER;
        lc_flag         VARCHAR2 (2);
    BEGIN
        SELECT COUNT (1)
          INTO ln_data_count
          FROM xxdo.xxd_ont_commercial_inv_t
         WHERE request_id = fnd_global.conc_request_id;

        IF     p_shipment_type = 'Factory Shipment to Subsidiaries'
           AND p_send_email = 'Y'
           AND ln_data_count > 0
        THEN
            ln_req_id   :=
                fnd_request.submit_request (
                    application   => 'XDO',
                    program       => 'XDOBURSTREP',
                    description   => 'Bursting',
                    argument1     => 'Y',
                    argument2     => fnd_global.conc_request_id,
                    argument3     => 'Y');

            IF ln_req_id != 0
            THEN
                lb_result   := TRUE;
            ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to launch bursting request');
                lb_result   := FALSE;
            END IF;
        ELSIF     p_shipment_type = 'Factory Shipment to Subsidiaries'
              AND ln_data_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'No Data Found; Skipping Bursting Program');
        END IF;

        -- Update Record Status for Standalone Requests
        UPDATE xxdo.xxd_ont_commercial_inv_t
           SET record_status   = 'S'
         WHERE record_status = 'I' AND program_mode = 'STANDALONE';

        -- Update Record Status for Request Set Data
        UPDATE xxdo.xxd_ont_commercial_inv_t xocit
           SET record_status   = 'S'
         WHERE     record_status IN ('I', 'N')
               AND program_mode = 'BACK_TO_BACK'
               AND (SELECT COUNT (DISTINCT record_status)
                      FROM xxdo.xxd_ont_commercial_inv_t xocit1
                     WHERE     xocit.factory_inv_num = xocit1.factory_inv_num
                           AND xocit1.program_mode = 'BACK_TO_BACK') >
                   1;

        -- Delete Six Months Old Records
        DELETE xxdo.xxd_ont_commercial_inv_t
         WHERE TRUNC (creation_date) <= ADD_MONTHS (TRUNC (SYSDATE), -6);

        RETURN lb_result;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in SUBMIT_BURSTING: ' || SQLERRM);
            RETURN FALSE;
    END submit_bursting;
END xxd_ont_commercial_inv_pkg;
/
