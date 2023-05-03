--
-- XXDOEC_ORDER_RECONCILE_STATUS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_ORDER_RECONCILE_STATUS"
AS
    PROCEDURE get_order_detail (
        p_order_number   IN     VARCHAR2,
        o_order_detail      OUT t_order_detail_cursor)
    IS
    BEGIN
        OPEN o_order_detail FOR
              SELECT ool.header_id header_id,
                     ool.attribute18 line_grp_id,
                     ool.line_id line_id,
                     ooh.cust_po_number order_number,
                     ooh.ordered_date,
                     (SELECT SUM (ool.unit_selling_price * ool.ordered_quantity)
                        FROM oe_order_lines_all ool
                       WHERE ool.header_id = ooh.header_id) total_order_amount,
                     CASE                         -- un-prefix customer number
                         WHEN SUBSTR (hca.account_number, 1, 2) = 'DW'
                         THEN
                             SUBSTR (hca.account_number, 3)
                         WHEN SUBSTR (hca.account_number, 1, 2) = '90'
                         THEN
                             SUBSTR (hca.account_number, 3)
                         ELSE
                             hca.account_number
                     END customer_number,
                     hca.account_name,
                     hp.email_address,
                     ooh.flow_status_code order_status,
                     ool.actual_shipment_date shipping_date,
                     msi.segment1 model_number,
                     msi.segment2 color_code,
                     msi.segment3 product_size,
                     msi.description product_name,
                     ool.inventory_item_id,
                     ool.ordered_quantity,
                     ool.unit_selling_price,
                     ool.ordered_quantity * ool.unit_selling_price subtotal,
                     ool.flow_status_code line_status,
                     ool.open_flag,
                     ool.cancelled_flag,
                     ool.booked_flag,
                     (SELECT NVL (SUM (ordered_quantity), 0)
                        FROM apps.oe_order_lines_all ool_r
                       WHERE     ool_r.reference_line_id = ool.line_id
                             AND ool_r.line_category_code = 'RETURN'
                             AND NVL (ool_r.cancelled_flag, 'N') = 'N'
                             AND SUBSTR (
                                     ool_r.orig_sys_document_ref,
                                       INSTR (ool_r.orig_sys_document_ref, '_')
                                     + 1) =
                                 'RT') return_quantity,
                     (SELECT NVL (SUM (ordered_quantity), 0)
                        FROM apps.oe_order_lines_all ool_r
                       WHERE     ool_r.reference_line_id = ool.line_id
                             AND ool_r.line_category_code = 'RETURN'
                             AND NVL (ool_r.cancelled_flag, 'N') = 'N'
                             AND SUBSTR (
                                     ool_r.orig_sys_document_ref,
                                       INSTR (ool_r.orig_sys_document_ref, '_')
                                     + 1) =
                                 'EX') exchange_quantity,
                     (SELECT flv.meaning
                        FROM oe_reasons ors, fnd_lookup_values flv
                       WHERE     entity_code = 'LINE'
                             AND entity_id = ool.line_id
                             AND flv.lookup_type = 'CANCEL_CODE'
                             AND flv.language = 'US'
                             AND flv.lookup_code = ors.reason_code
                             AND ool.cancelled_flag = 'Y'
                             AND ROWNUM = 1) cancel_reason
                FROM oe_order_headers_all ooh,
                     oe_order_lines_all ool,
                     hz_cust_accounts hca,
                     hz_cust_site_uses_all hcsu_b,
                     hz_cust_acct_sites_all hcas_b,
                     hz_party_sites hps_b,
                     hz_locations hl_b,
                     mtl_system_items_b msi,
                     hz_parties hp,
                     (SELECT tracking_number, wc.freight_code carrier, flv_smc.meaning shipping_method,
                             wdd.source_line_id
                        FROM wsh_delivery_details wdd, fnd_lookup_values flv_smc, wsh_carriers wc
                       WHERE     wdd.source_code = 'OE'
                             AND wc.carrier_id = wdd.carrier_id
                             AND flv_smc.lookup_type = 'SHIP_METHOD'
                             AND flv_smc.language = 'US'
                             AND flv_smc.lookup_code = wdd.ship_method_code) dd
               WHERE     ool.header_id = ooh.header_id
                     AND hca.cust_account_id = ooh.sold_to_org_id
                     AND hcsu_b.site_use_id = ooh.invoice_to_org_id
                     AND hcas_b.cust_acct_site_id = hcsu_b.cust_acct_site_id
                     AND hps_b.party_site_id = hcas_b.party_site_id
                     AND hl_b.location_id = hps_b.location_id
                     AND msi.inventory_item_id = ool.inventory_item_id
                     AND msi.organization_id = ool.ship_from_org_id
                     AND ool.line_id = dd.source_line_id(+) -- for tracking_number, carrier, shipping_method
                     AND hp.party_id = hca.party_id       -- for email_address
                     AND ooh.cust_po_number = p_order_number
            ORDER BY ooh.order_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            INSERT INTO xxdo.XXDOEC_ORDER_RCNCL_STATUS_LOG (order_number,
                                                            called_with,
                                                            createdate)
                     VALUES (
                                p_order_number,
                                   'ERROR calling with order number:  '
                                || p_order_number
                                || '.',
                                SYSDATE);

            COMMIT;
    END;
END XXDOEC_ORDER_RECONCILE_STATUS;
/
