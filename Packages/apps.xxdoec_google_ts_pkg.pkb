--
-- XXDOEC_GOOGLE_TS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_GOOGLE_TS_PKG"
AS
    PROCEDURE shipments_by_day (p_site_id IN VARCHAR2, p_from_date IN DATE, p_to_date IN DATE
                                , p_resultset OUT SYS_REFCURSOR)
    AS
    BEGIN
        OPEN p_resultset FOR
            SELECT ool.cust_po_number order_num, wdd.tracking_number, ool.shipping_method_code ship_method_code,
                   NVL (gcn.gts_carrier_code, 'NOTFOUND') carrier_code, gcn.gts_other_carrier_name other_carrier_name, ool.actual_shipment_date ship_date
              FROM apps.oe_order_lines_all ool
                   JOIN apps.wsh_delivery_details wdd
                       ON ool.line_id = wdd.source_line_id
                   JOIN apps.oe_order_headers_all oha
                       ON oha.header_id = ool.header_id
                   JOIN apps.oe_transaction_types_all tta
                       ON oha.order_type_id = tta.transaction_type_id
                   LEFT JOIN xxdo.xxdoec_google_ship_carriers gsc
                       ON gsc.ship_method_code = ool.shipping_method_code
                   JOIN xxdo.xxdoec_google_carrier_names gcn
                       ON gcn.carrier_id = gsc.carrier_id
             WHERE     ool.actual_shipment_date >= p_from_date
                   AND ool.actual_shipment_date < p_to_date
                   AND tta.attribute13 = 'ES'            -- eCommerce shipment
                   AND tta.attribute12 = p_site_id;
    END;

    PROCEDURE cancellations_by_day (p_site_id IN VARCHAR2, p_from_date IN DATE, p_to_date IN DATE
                                    , p_resultset OUT SYS_REFCURSOR)
    AS
    BEGIN
        OPEN p_resultset FOR
            SELECT DISTINCT ool.cust_po_number order_num, ors.reason_code cancel_code, NVL (gcc.gts_cancel_reason, 'NOTFOUND') cancel_reason
              FROM apps.oe_reasons ors
                   JOIN apps.oe_order_lines_all ool
                       ON ors.entity_id = ool.line_id
                   JOIN apps.oe_order_headers_all oha
                       ON oha.header_id = ool.header_id
                   JOIN apps.oe_transaction_types_all tta
                       ON oha.order_type_id = tta.transaction_type_id
                   LEFT JOIN xxdo.xxdoec_google_cancel_codes gcc
                       ON ors.reason_code = gcc.cancel_code
             WHERE     ors.creation_date >= p_from_date
                   AND ors.creation_date < p_to_date
                   AND tta.attribute13 = 'ES' -- eCommerce "shipment" applies to cancellations too
                   AND tta.attribute12 = p_site_id
                   AND ors.entity_code = 'LINE'
                   AND ors.reason_type = 'CANCEL_CODE'
                   -- subqueries to compare total lines vs cancelled lines --
                   AND (  SELECT COUNT (ool2.header_id)
                            FROM apps.oe_order_lines_all ool2
                           WHERE ool2.header_id = ool.header_id
                        GROUP BY ool2.header_id) =
                       (  SELECT COUNT (ool3.header_id)
                            FROM apps.oe_order_lines_all ool3
                           WHERE     ool3.header_id = ool.header_id
                                 AND ool3.cancelled_flag = 'Y'
                        GROUP BY ool3.header_id);
    END;

    PROCEDURE get_org_id (p_brand     IN     VARCHAR2,
                          p_country   IN     VARCHAR2,
                          p_org_id       OUT INTEGER)
    AS
    BEGIN
        SELECT DISTINCT ERP_ORG_ID
          INTO p_org_id
          FROM xxdo.xxdoec_country_brand_params
         WHERE country_code = p_country AND brand_name = p_brand;
    END;
END XXDOEC_GOOGLE_TS_PKG;
/
