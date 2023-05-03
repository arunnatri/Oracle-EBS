--
-- XXDOEC_ORDER_TESTER  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoec_order_tester
AS
    PROCEDURE get_customer_records (
        p_max_records       NUMBER,
        o_customers     OUT t_cust_records_cursor)
    IS
    BEGIN
        OPEN o_customers FOR
              SELECT hca.account_number, hp.person_first_name, hp.person_last_name,
                     hp.email_address, TRIM (SUBSTR (hcsu_b.location, 0, LENGTH (hcsu_b.location) - 10)) billing_name, hl_b.address1 bill_to_address1,
                     hl_b.address2 bill_to_address2, hl_b.city bill_to_city, hl_b.state bill_to_state,
                     hl_b.province bill_to_province, hl_b.postal_code bill_to_postal_code, hl_b.country bill_to_country,
                     TRIM (SUBSTR (hcsu_s.location, 0, LENGTH (hcsu_s.location) - 10)) shipping_name, hl_s.address1 ship_to_address1, hl_s.address2 ship_to_address2,
                     hl_s.city ship_to_city, hl_s.state ship_to_state, hl_s.province ship_to_province,
                     hl_s.postal_code ship_to_postal_code, hl_s.country ship_to_country, hca.attribute18 website_id,
                     hca.attribute17 local_id
                FROM hz_cust_accounts hca, hz_parties hp, hz_cust_acct_sites_all hcas_b,
                     hz_cust_site_uses_all hcsu_b, hz_cust_acct_sites_all hcas_s, hz_cust_site_uses_all hcsu_s,
                     hz_party_sites hps_b, hz_party_sites hps_s, hz_locations hl_b,
                     hz_locations hl_s
               WHERE     RTRIM (LTRIM (UPPER (hca.attribute_category))) =
                         'PERSON'
                     AND hca.created_by = 1170
                     AND hca.creation_date > ADD_MONTHS (CURRENT_DATE, -24)
                     AND hp.party_id = hca.party_id
                     AND hcas_b.cust_account_id = hca.cust_account_id
                     AND hcas_b.bill_to_flag = 'P'
                     AND hps_b.party_site_id = hcas_b.party_site_id
                     AND hcas_b.cust_acct_site_id = hcsu_b.cust_acct_site_id
                     AND hl_b.location_id = hps_b.location_id
                     AND hcas_s.cust_account_id = hca.cust_account_id
                     AND hcas_s.ship_to_flag = 'P'
                     AND hps_s.party_site_id = hcas_s.party_site_id
                     AND hcas_s.cust_acct_site_id = hcsu_s.cust_acct_site_id
                     AND hl_s.location_id = hps_s.location_id
                     AND ROWNUM <= p_max_records
            GROUP BY hca.account_number, hp.person_first_name, hp.person_last_name,
                     hp.email_address, TRIM (SUBSTR (hcsu_b.location, 0, LENGTH (hcsu_b.location) - 10)), hl_b.address1,
                     hl_b.address2, hl_b.city, hl_b.state,
                     hl_b.province, hl_b.postal_code, hl_b.country,
                     TRIM (SUBSTR (hcsu_s.location, 0, LENGTH (hcsu_s.location) - 10)), hl_s.address1, hl_s.address2,
                     hl_s.city, hl_s.state, hl_s.province,
                     hl_s.postal_code, hl_s.country, hca.attribute18,
                     hca.attribute17;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_customers   := NULL;
    END get_customer_records;

    PROCEDURE get_customer_records_for_site (p_web_site_id VARCHAR2, p_max_records NUMBER, o_customers OUT t_cust_records_cursor)
    IS
    BEGIN
        OPEN o_customers FOR
              SELECT hca.account_number, hp.person_first_name, hp.person_last_name,
                     hp.email_address, TRIM (SUBSTR (hcsu_b.location, 0, LENGTH (hcsu_b.location) - 10)) billing_name, hl_b.address1 bill_to_address1,
                     hl_b.address2 bill_to_address2, hl_b.city bill_to_city, hl_b.state bill_to_state,
                     hl_b.province bill_to_province, hl_b.postal_code bill_to_postal_code, hl_b.country bill_to_country,
                     TRIM (SUBSTR (hcsu_s.location, 0, LENGTH (hcsu_s.location) - 10)) shipping_name, hl_s.address1 ship_to_address1, hl_s.address2 ship_to_address2,
                     hl_s.city ship_to_city, hl_s.state ship_to_state, hl_s.province ship_to_province,
                     hl_s.postal_code ship_to_postal_code, hl_s.country ship_to_country, hca.attribute18 website_id,
                     hca.attribute17 local_id
                FROM hz_cust_accounts hca, hz_parties hp, hz_cust_acct_sites_all hcas_b,
                     hz_cust_site_uses_all hcsu_b, hz_cust_acct_sites_all hcas_s, hz_cust_site_uses_all hcsu_s,
                     hz_party_sites hps_b, hz_party_sites hps_s, hz_locations hl_b,
                     hz_locations hl_s
               WHERE     RTRIM (LTRIM (UPPER (hca.attribute_category))) =
                         'PERSON'
                     AND hca.attribute18 = p_web_site_id
                     AND hca.created_by = 1170
                     AND hca.creation_date > ADD_MONTHS (CURRENT_DATE, -6)
                     AND hp.party_id = hca.party_id
                     AND hcas_b.cust_account_id = hca.cust_account_id
                     AND hcas_b.bill_to_flag = 'P'
                     AND hps_b.party_site_id = hcas_b.party_site_id
                     AND hcas_b.cust_acct_site_id = hcsu_b.cust_acct_site_id
                     AND hl_b.location_id = hps_b.location_id
                     AND hcas_s.cust_account_id = hca.cust_account_id
                     AND hcas_s.ship_to_flag = 'P'
                     AND hps_s.party_site_id = hcas_s.party_site_id
                     AND hcas_s.cust_acct_site_id = hcsu_s.cust_acct_site_id
                     AND hl_s.location_id = hps_s.location_id
                     AND ROWNUM <= p_max_records
            GROUP BY hca.account_number, hp.person_first_name, hp.person_last_name,
                     hp.email_address, TRIM (SUBSTR (hcsu_b.location, 0, LENGTH (hcsu_b.location) - 10)), hl_b.address1,
                     hl_b.address2, hl_b.city, hl_b.state,
                     hl_b.province, hl_b.postal_code, hl_b.country,
                     TRIM (SUBSTR (hcsu_s.location, 0, LENGTH (hcsu_s.location) - 10)), hl_s.address1, hl_s.address2,
                     hl_s.city, hl_s.state, hl_s.province,
                     hl_s.postal_code, hl_s.country, hca.attribute18,
                     hca.attribute17;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_customers   := NULL;
    END get_customer_records_for_site;

    PROCEDURE get_customer_records_by_email (
        p_email_addr       VARCHAR2,
        o_customers    OUT t_cust_records_cursor)
    IS
    BEGIN
        OPEN o_customers FOR
            SELECT DISTINCT hca.account_number, hp.person_first_name, hp.person_last_name,
                            hp.email_address, TRIM (SUBSTR (hcsu_b.location, 0, LENGTH (hcsu_b.location) - 10)) billing_name, hl_b.address1 bill_to_address1,
                            hl_b.address2 bill_to_address2, hl_b.city bill_to_city, hl_b.state bill_to_state,
                            hl_b.province bill_to_province, hl_b.postal_code bill_to_postal_code, hl_b.country bill_to_country,
                            TRIM (SUBSTR (hcsu_s.location, 0, LENGTH (hcsu_s.location) - 10)) shipping_name, hl_s.address1 ship_to_address1, hl_s.address2 ship_to_address2,
                            hl_s.city ship_to_city, hl_s.state ship_to_state, hl_s.province ship_to_province,
                            hl_s.postal_code ship_to_postal_code, hl_s.country ship_to_country, hca.attribute18 website_id,
                            hca.attribute17 local_id
              FROM hz_cust_accounts hca, hz_parties hp, hz_cust_acct_sites_all hcas_b,
                   hz_cust_site_uses_all hcsu_b, hz_cust_acct_sites_all hcas_s, hz_cust_site_uses_all hcsu_s,
                   hz_party_sites hps_b, hz_party_sites hps_s, hz_locations hl_b,
                   hz_locations hl_s
             WHERE     RTRIM (LTRIM (UPPER (hca.attribute_category))) =
                       'PERSON'
                   AND hca.created_by = 1170
                   AND hp.email_address = p_email_addr
                   AND hp.party_id = hca.party_id
                   AND hcas_b.cust_account_id = hca.cust_account_id
                   AND hcas_b.bill_to_flag = 'P'
                   AND hps_b.party_site_id = hcas_b.party_site_id
                   AND hcas_b.cust_acct_site_id = hcsu_b.cust_acct_site_id
                   AND hl_b.location_id = hps_b.location_id
                   AND hcas_s.cust_account_id = hca.cust_account_id
                   AND hcas_s.ship_to_flag = 'P'
                   AND hps_s.party_site_id = hcas_s.party_site_id
                   AND hcas_s.cust_acct_site_id = hcsu_s.cust_acct_site_id
                   AND hl_s.location_id = hps_s.location_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_customers   := NULL;
    END get_customer_records_by_email;

    PROCEDURE get_customer_records_by_id (
        p_customerId       VARCHAR2,
        o_customers    OUT t_cust_records_cursor)
    IS
    BEGIN
        OPEN o_customers FOR
            SELECT DISTINCT hca.account_number, hp.person_first_name, hp.person_last_name,
                            hp.email_address, TRIM (SUBSTR (hcsu_b.location, 0, LENGTH (hcsu_b.location) - 10)) billing_name, hl_b.address1 bill_to_address1,
                            hl_b.address2 bill_to_address2, hl_b.city bill_to_city, hl_b.state bill_to_state,
                            hl_b.province bill_to_province, hl_b.postal_code bill_to_postal_code, hl_b.country bill_to_country,
                            TRIM (SUBSTR (hcsu_s.location, 0, LENGTH (hcsu_s.location) - 10)) shipping_name, hl_s.address1 ship_to_address1, hl_s.address2 ship_to_address2,
                            hl_s.city ship_to_city, hl_s.state ship_to_state, hl_s.province ship_to_province,
                            hl_s.postal_code ship_to_postal_code, hl_s.country ship_to_country, hca.attribute18 website_id,
                            hca.attribute17 local_id
              FROM hz_cust_accounts hca, hz_parties hp, hz_cust_acct_sites_all hcas_b,
                   hz_cust_site_uses_all hcsu_b, hz_cust_acct_sites_all hcas_s, hz_cust_site_uses_all hcsu_s,
                   hz_party_sites hps_b, hz_party_sites hps_s, hz_locations hl_b,
                   hz_locations hl_s
             WHERE     RTRIM (LTRIM (UPPER (hca.attribute_category))) =
                       'PERSON'
                   AND hca.created_by = 1170
                   AND hca.account_number = p_customerId
                   AND hp.party_id = hca.party_id
                   AND hcas_b.cust_account_id = hca.cust_account_id
                   AND hcas_b.bill_to_flag = 'P'
                   AND hps_b.party_site_id = hcas_b.party_site_id
                   AND hcas_b.cust_acct_site_id = hcsu_b.cust_acct_site_id
                   AND hl_b.location_id = hps_b.location_id
                   AND hcas_s.cust_account_id = hca.cust_account_id
                   AND hcas_s.ship_to_flag = 'P'
                   AND hps_s.party_site_id = hcas_s.party_site_id
                   AND hcas_s.cust_acct_site_id = hcsu_s.cust_acct_site_id
                   AND hl_s.location_id = hps_s.location_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_customers   := NULL;
    END get_customer_records_by_id;

    PROCEDURE get_line_items_by_site (p_site_id VARCHAR2, p_max_records NUMBER, o_line_items OUT t_line_items_cursor)
    IS
        l_price_list_id   NUMBER;
        l_inv_org_id      NUMBER;
        l_erp_org_id      NUMBER;
    BEGIN
        SELECT om_price_list_id, inv_org_id, erp_org_id
          INTO l_price_list_id, l_inv_org_id, l_erp_org_id
          FROM XXDO.XXDOEC_COUNTRY_BRAND_PARAMS
         WHERE website_id = p_site_id;

        OPEN o_line_items FOR
            SELECT inv.upc upc, inv.sku sku, qll.operand cost_per_unit,
                   NVL (inv.atp_qty, 0) quantity, NVL (inv.pre_back_order_qty, 0) pre_back_order_qty, l_price_list_id price_list_id,
                   msi.item_description
              FROM xxdo.xxdoec_inventory inv
                   INNER JOIN qp_list_lines_v qll
                       ON inv.inventory_item_id =
                          TO_NUMBER (qll.product_attr_value)
                   LEFT OUTER JOIN xxd_common_items_v msi
                       ON msi.inventory_item_id = inv.inventory_item_id
             WHERE     inv.inv_org_id = l_inv_org_id
                   AND inv.erp_org_id = l_erp_org_id
                   AND qll.list_header_id = l_price_list_id
                   AND inv.inventory_item_id = qll.product_attr_value
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND ROWNUM <= p_max_records;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_line_items   := NULL;
    END get_line_items_by_site;

    PROCEDURE get_line_items_by_site_new (p_site_id VARCHAR2, p_max_records NUMBER, o_line_items OUT t_line_items_cursor
                                          , o_zero_line_items OUT t_line_items_cursor, o_backorder_line_items OUT t_line_items_cursor, o_sale_line_items OUT t_line_items_cursor)
    IS
        l_price_list_id        NUMBER;
        l_sale_price_list_id   NUMBER;
        l_inv_org_id           NUMBER;
        l_erp_org_id           NUMBER;
    BEGIN
        SELECT om_price_list_id, inv_org_id, erp_org_id
          INTO l_price_list_id, l_inv_org_id, l_erp_org_id
          FROM XXDO.XXDOEC_COUNTRY_BRAND_PARAMS
         WHERE website_id = p_site_id;

        OPEN o_line_items FOR
            SELECT inv.upc upc, inv.sku sku, qll.operand cost_per_unit,
                   NVL (inv.atp_qty, 0) quantity, NVL (inv.pre_back_order_qty, 0) pre_back_order_qty, l_price_list_id price_list_id,
                   msi.item_description
              FROM xxdo.xxdoec_inventory inv
                   INNER JOIN qp_list_lines_v qll
                       ON inv.inventory_item_id =
                          TO_NUMBER (qll.product_attr_value)
                   LEFT OUTER JOIN xxd_common_items_v msi
                       ON msi.inventory_item_id = inv.inventory_item_id
             WHERE     inv.inv_org_id = l_inv_org_id
                   AND inv.erp_org_id = l_erp_org_id
                   AND qll.list_header_id = l_price_list_id
                   AND inv.inventory_item_id = qll.product_attr_value
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND inv.atp_qty >= 20
                   AND ROWNUM <= p_max_records;

        OPEN o_zero_line_items FOR
            SELECT inv.upc upc, inv.sku sku, qll.operand cost_per_unit,
                   NVL (inv.atp_qty, 0) quantity, NVL (inv.pre_back_order_qty, 0) pre_back_order_qty, l_price_list_id price_list_id,
                   msi.item_description
              FROM xxdo.xxdoec_inventory inv
                   INNER JOIN qp_list_lines_v qll
                       ON inv.inventory_item_id =
                          TO_NUMBER (qll.product_attr_value)
                   LEFT OUTER JOIN xxd_common_items_v msi
                       ON msi.inventory_item_id = inv.inventory_item_id
             WHERE     inv.inv_org_id = l_inv_org_id
                   AND inv.erp_org_id = l_erp_org_id
                   AND qll.list_header_id = l_price_list_id
                   AND inv.inventory_item_id = qll.product_attr_value
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND inv.atp_qty <= 0
                   AND ROWNUM <= 250;

        OPEN o_backorder_line_items FOR
            SELECT inv.upc upc, inv.sku sku, qll.operand cost_per_unit,
                   NVL (inv.atp_qty, 0) quantity, NVL (inv.pre_back_order_qty, 0) pre_back_order_qty, l_price_list_id price_list_id,
                   msi.item_description
              FROM xxdo.xxdoec_inventory inv
                   INNER JOIN qp_list_lines_v qll
                       ON inv.inventory_item_id =
                          TO_NUMBER (qll.product_attr_value)
                   LEFT OUTER JOIN xxd_common_items_v msi
                       ON msi.inventory_item_id = inv.inventory_item_id
             WHERE     inv.inv_org_id = l_inv_org_id
                   AND inv.erp_org_id = l_erp_org_id
                   AND qll.list_header_id = l_price_list_id
                   AND inv.inventory_item_id = qll.product_attr_value
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND inv.atp_qty <= 0
                   AND inv.pre_back_order_mode <> 0
                   AND inv.pre_back_order_qty > 0
                   AND ROWNUM <= 250;

        --Get the sale pricebook id for the website
        SELECT list_header_id
          INTO l_sale_price_list_id
          FROM qp_list_headers qlh
         WHERE     1 = 1
               AND attribute2 IS NOT NULL
               AND qlh.attribute1 IN ('Y')
               AND LOWER (name) LIKE '%sale'
               AND LOWER (name) NOT LIKE '%pre_sale'
               AND LOWER (attribute2) = LOWER (p_site_id);

        OPEN o_sale_line_items FOR
            SELECT inv.upc upc, inv.sku sku, qll.operand cost_per_unit,
                   NVL (inv.atp_qty, 0) quantity, NVL (inv.pre_back_order_qty, 0) pre_back_order_qty, l_sale_price_list_id price_list_id,
                   msi.item_description
              FROM xxdo.xxdoec_inventory inv
                   INNER JOIN qp_list_lines_v qll
                       ON inv.inventory_item_id =
                          TO_NUMBER (qll.product_attr_value)
                   LEFT OUTER JOIN xxd_common_items_v msi
                       ON msi.inventory_item_id = inv.inventory_item_id
             WHERE     inv.inv_org_id = l_inv_org_id
                   AND inv.erp_org_id = l_erp_org_id
                   AND qll.list_header_id = NVL (l_sale_price_list_id, 0)
                   AND inv.inventory_item_id = qll.product_attr_value
                   AND inv.atp_qty > 0
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND ROWNUM <= p_max_records;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_line_items   := NULL;
    END get_line_items_by_site_new;

    PROCEDURE get_line_item_by_upc (
        p_upc          IN     VARCHAR2,
        p_site_id      IN     VARCHAR2,
        o_line_items      OUT t_line_items_cursor)
    IS
        l_price_list_id   NUMBER;
        l_inv_org_id      NUMBER;
        l_erp_org_id      NUMBER;
    BEGIN
        SELECT om_price_list_id, inv_org_id, erp_org_id
          INTO l_price_list_id, l_inv_org_id, l_erp_org_id
          FROM XXDO.XXDOEC_COUNTRY_BRAND_PARAMS
         WHERE website_id = p_site_id;

        OPEN o_line_items FOR
            SELECT inv.upc upc, inv.sku sku, qll.operand cost_per_unit,
                   NVL (inv.atp_qty, 0) quantity, NVL (inv.pre_back_order_qty, 0) pre_back_order_qty, l_price_list_id price_list_id,
                   msi.item_description
              FROM xxdo.xxdoec_inventory inv
                   INNER JOIN qp_list_lines_v qll
                       ON inv.inventory_item_id =
                          TO_NUMBER (qll.product_attr_value)
                   LEFT OUTER JOIN xxd_common_items_v msi
                       ON msi.inventory_item_id = inv.inventory_item_id
             WHERE     inv.inv_org_id = l_inv_org_id
                   AND inv.erp_org_id = l_erp_org_id
                   AND inv.upc = p_upc
                   AND qll.list_header_id = l_price_list_id
                   AND inv.inventory_item_id = qll.product_attr_value
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID');
    EXCEPTION
        WHEN OTHERS
        THEN
            o_line_items   := NULL;
    END get_line_item_by_upc;

    PROCEDURE get_next_order_number (x_return_number OUT NUMBER)
    AS
    BEGIN
        SELECT APPS.XXDOEC_SEQ_TESTER_ORDER_NUM.NEXTVAL
          INTO x_return_number
          FROM DUAL;
    END get_next_order_number;

    PROCEDURE get_next_cust_number (x_return_number OUT NUMBER)
    AS
    BEGIN
        SELECT APPS.XXDOEC_SEQ_TESTER_CUST_NUM.NEXTVAL
          INTO x_return_number
          FROM DUAL;
    END get_next_cust_number;

    PROCEDURE get_upc_from_sku (p_sku IN VARCHAR2, x_return_upc OUT VARCHAR)
    AS
    BEGIN
        SELECT msi.upc_code
          INTO x_return_upc
          FROM xxd_common_items_v msi
         WHERE     organization_id = fnd_profile.VALUE ('QP_ORGANIZATION_ID')
               AND item_number = p_sku;
    END get_upc_from_sku;
END xxdoec_order_tester;
/
