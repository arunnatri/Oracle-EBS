--
-- XXDO_OM_QUALIFIER_CONTEXT  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_OM_QUALIFIER_CONTEXT"
AS
    /*----------------------------------------------------------------------------------------------------------------------*/
    /* Ver No     Developer                                Date                             Description                     */
    /*                                                                                                                      */
    /*----------------------------------------------------------------------------------------------------------------------*/
    /* 1.0            BT Technology Team        28-Oct-2014               Used in OraclePricing attribute mapping           */
    /* 1.1            BT Dev Team               25-Jul-2016               Post go live code change                          */
    /* 1.2            Mithun Mathew             6-Jun-2017                CCR0006406 State derivation from Ship-To/Bill-To  */
    /* 1.3            Viswanathan Pandian       06-Sep-2017               CCR0006622 Hoka Program $3 Freight Charge         */
    /* 1.4            Viswanathan Pandian       25-Jan-2018               CCR0007022 Changes in get_order_type_incl         */
    /* 1.5            Aravind Kannuri           26-Jan-2018               CCR0006849 Added 4 Functions for Promotion Apply  */
    /************************************************************************************************************************/
    g_category_set_name   VARCHAR2 (100) := 'Inventory';

    FUNCTION get_brand (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_brand   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment1
          INTO l_brand
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_gender (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_gender   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment2
          INTO l_gender
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_gender;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_product_group (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_product   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment3
          INTO l_product
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_product;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_product_class (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_product_class   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment4
          INTO l_product_class
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_product_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_product_class;

    FUNCTION get_sub_class (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_sub_class   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment5
          INTO l_sub_class
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_sub_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_sub_class;

    FUNCTION get_master_style (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_master_style   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment6
          INTO l_master_style
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_master_style;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_master_style;

    FUNCTION get_sub_style (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_sub_style   VARCHAR2 (40);
    BEGIN
        SELECT mcat.segment7
          INTO l_sub_style
          FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
               mtl_system_items_vl msi, apps.oe_order_lines_all line
         WHERE     mcats.category_set_name LIKE g_category_set_name
               AND micat.category_set_id = mcats.category_set_id
               AND micat.category_id = mcat.category_id
               AND msi.inventory_item_id = micat.inventory_item_id
               AND msi.organization_id = micat.organization_id
               AND msi.organization_id = line.ship_from_org_id
               AND msi.inventory_item_id = line.inventory_item_id
               AND line.line_id = l_line_id;

        RETURN l_sub_style;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_sub_style;

    -- Start Code change on 25-Jul-2016

    FUNCTION get_style_number (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_style_number   VARCHAR2 (40);
    BEGIN
        SELECT xciv.style_number
          INTO l_style_number
          FROM xxd_common_items_v xciv, apps.oe_order_lines_all line
         WHERE     xciv.inventory_item_id = line.inventory_item_id
               AND xciv.organization_id = line.ship_from_org_id
               AND line.line_id = l_line_id;

        RETURN l_style_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_style_number;

    FUNCTION get_color_code (l_line_id NUMBER)
        RETURN VARCHAR2
    IS
        l_color_code   VARCHAR2 (40);
    BEGIN
        SELECT xciv.color_code
          INTO l_color_code
          FROM xxd_common_items_v xciv, apps.oe_order_lines_all line
         WHERE     xciv.inventory_item_id = line.inventory_item_id
               AND xciv.organization_id = line.ship_from_org_id
               AND line.line_id = l_line_id;

        RETURN l_color_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_color_code;

    -- End Code change on 25-Jul-2016

    -- Start Code change ver 1.2
    FUNCTION get_hdr_shipto_state (p_ship_to_org_id NUMBER)
        RETURN VARCHAR2
    IS
        l_shipto_state   VARCHAR2 (40);
    BEGIN
        SELECT hl.state
          INTO l_shipto_state
          FROM hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu, hz_party_sites hps,
               hz_locations hl
         WHERE     hcsu.site_use_id = p_ship_to_org_id
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcas.party_site_id = hps.party_site_id
               AND hps.location_id = hl.location_id;

        RETURN l_shipto_state;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_hdr_shipto_state;

    FUNCTION get_hdr_billto_state (p_invoice_to_org_id NUMBER)
        RETURN VARCHAR2
    IS
        l_billto_state   VARCHAR2 (40);
    BEGIN
        SELECT hl.state
          INTO l_billto_state
          FROM hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu, hz_party_sites hps,
               hz_locations hl
         WHERE     hcsu.site_use_id = p_invoice_to_org_id
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcas.party_site_id = hps.party_site_id
               AND hps.location_id = hl.location_id;

        RETURN l_billto_state;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_hdr_billto_state;

    -- End Code change ver 1.2

    -- Start changes for CCR0006622
    FUNCTION get_order_type_incl
        RETURN VARCHAR2
    IS
        lc_include_flag   VARCHAR2 (1);
    BEGIN
        SELECT DECODE (COUNT (1), 0, 'N', 'Y')
          INTO lc_include_flag
          FROM oe_order_headers_all ooha, oe_transaction_types_all otta, oe_transaction_types_tl ottt, -- Added for CCR0007022
               fnd_lookup_values flv
         WHERE     otta.transaction_type_id = ooha.order_type_id
               AND flv.lookup_type = 'XXD_QP_ORDER_TYPE_INCL'
               AND flv.language = USERENV ('LANG')
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE))
               AND flv.enabled_flag = 'Y'
               AND flv.tag = ooha.attribute5
               -- Start changes for CCR0007022
               --AND REGEXP_SUBSTR (flv.lookup_code,
               --                   '[^-]+',
               --                   1,
               --                   1) = 'ORDERTYPE'
               AND flv.description = ottt.name
               AND ottt.language = USERENV ('LANG')
               AND otta.transaction_type_id = ottt.transaction_type_id
               -- End changes for CCR0007022
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (otta.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (otta.end_date_active,
                                                    SYSDATE))
               AND otta.transaction_type_id =
                   oe_order_pub.g_hdr.order_type_id
               AND ooha.header_id = oe_order_pub.g_hdr.header_id;

        RETURN lc_include_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_order_type_incl;

    FUNCTION get_ship_to_incl
        RETURN VARCHAR2
    IS
        lc_include_flag   VARCHAR2 (1);
    BEGIN
        SELECT DECODE (COUNT (1), 0, 'N', 'Y')
          INTO lc_include_flag
          FROM oe_order_headers_all ooha, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu,
               hz_party_sites hps, hz_locations hl, fnd_lookup_values flv
         WHERE     ooha.ship_to_org_id = hcsu.site_use_id
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcas.party_site_id = hps.party_site_id
               AND hps.location_id = hl.location_id
               AND hcsu.site_use_code = 'SHIP_TO'
               AND flv.lookup_type = 'XXD_QP_SHIP_TO_STATE_INCL'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE))
               AND flv.enabled_flag = 'Y'
               AND flv.tag = ooha.attribute5
               AND flv.description = hl.state
               AND REGEXP_SUBSTR (flv.lookup_code, '[^-]+', 1,
                                  1) = 'SHIPSTATE'
               AND hcsu.site_use_id = oe_order_pub.g_hdr.ship_to_org_id
               AND ooha.header_id = oe_order_pub.g_hdr.header_id;

        RETURN lc_include_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_ship_to_incl;

    -- End changes for CCR0006622

    -- Start changes for CCR0006849
    FUNCTION get_customer_spring_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2
    IS
        lc_spring_tier   VARCHAR2 (150);
    BEGIN
        SELECT attribute2
          INTO lc_spring_tier
          FROM apps.fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_QP_CUSTOMER_TIER'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND flv.attribute_category = 'XXD_QP_CUSTOMER_TIER'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE))
               AND TO_NUMBER (flv.attribute1) = p_cust_acct_id;

        RETURN lc_spring_tier;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_customer_spring_tier;

    FUNCTION get_customer_fall_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2
    IS
        lc_fall_tier   VARCHAR2 (150);
    BEGIN
        SELECT attribute3
          INTO lc_fall_tier
          FROM apps.fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_QP_CUSTOMER_TIER'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND flv.attribute_category = 'XXD_QP_CUSTOMER_TIER'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE))
               AND TO_NUMBER (flv.attribute1) = p_cust_acct_id;

        RETURN lc_fall_tier;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_customer_fall_tier;

    FUNCTION get_customer_future1_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2
    IS
        lc_future1_tier   VARCHAR2 (150);
    BEGIN
        SELECT attribute4
          INTO lc_future1_tier
          FROM apps.fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_QP_CUSTOMER_TIER'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND flv.attribute_category = 'XXD_QP_CUSTOMER_TIER'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE))
               AND TO_NUMBER (flv.attribute1) = p_cust_acct_id;

        RETURN lc_future1_tier;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_customer_future1_tier;

    FUNCTION get_customer_future2_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2
    IS
        lc_future2_tier   VARCHAR2 (150);
    BEGIN
        SELECT attribute5
          INTO lc_future2_tier
          FROM apps.fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_QP_CUSTOMER_TIER'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND flv.attribute_category = 'XXD_QP_CUSTOMER_TIER'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE))
               AND TO_NUMBER (flv.attribute1) = p_cust_acct_id;

        RETURN lc_future2_tier;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_customer_future2_tier;

    FUNCTION get_distribution_channel (p_cust_acct_id NUMBER)
        RETURN VARCHAR2
    IS
        lc_dist_channel   VARCHAR2 (150);
    BEGIN
        SELECT attribute3
          INTO lc_dist_channel
          FROM hz_cust_accounts
         WHERE cust_account_id = p_cust_acct_id;

        RETURN lc_dist_channel;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_distribution_channel;
-- End changes for CCR0006849

END xxdo_om_qualifier_context;
/
