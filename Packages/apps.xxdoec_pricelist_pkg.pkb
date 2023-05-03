--
-- XXDOEC_PRICELIST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PRICELIST_PKG"
AS
    /**********************************************************************************
      * Program Name : XXDOEC_PRICELIST_PKG
      * Description  : This package is used by DOMS to find the price of an item/category
      *
      * History      :
      *
      * ===============================================================================
      * Who                   Version    Comments                          When
      * ===============================================================================
      * Vijay Reddy           1.1        Added Price list ID parameter to  24-JUN-2019
      *                                  xxdoec_get_price_for_mdl_clr - CCR0008008
      *
      ******************************************************************************************************/
    PROCEDURE xxdoec_get_dw_pricelists (o_pricelists OUT t_header_cursor)
    AS
    BEGIN
        OPEN o_pricelists FOR
            SELECT list_header_id, NAME, currency_code,
                   start_date_active, end_date_active, attribute2
              FROM qp_list_headers qlh
             WHERE     qlh.attribute1 = 'Y'
                   AND SYSDATE BETWEEN NVL (qlh.start_date_active, SYSDATE)
                                   AND NVL (qlh.end_date_active, SYSDATE)
                   AND qlh.active_flag = 'Y'
                   AND attribute2 IS NOT NULL;
    END xxdoec_get_dw_pricelists;

    PROCEDURE xxdoec_get_dcd_pricelists (o_pricelists OUT t_header_cursor)
    AS
    BEGIN
        OPEN o_pricelists FOR
            SELECT list_header_id, NAME, currency_code,
                   start_date_active, end_date_active, attribute2
              FROM qp_list_headers qlh
             WHERE     (qlh.attribute1 = 'Y' OR qlh.attribute1 = 'N')
                   AND SYSDATE BETWEEN NVL (qlh.start_date_active, SYSDATE)
                                   AND NVL (qlh.end_date_active, SYSDATE)
                   AND qlh.active_flag = 'Y'
                   AND attribute2 IS NOT NULL;
    END xxdoec_get_dcd_pricelists;

    PROCEDURE xxdoec_get_dw_pricelists (p_site             VARCHAR2,
                                        o_pricelists   OUT t_header_cursor)
    AS
    BEGIN
        OPEN o_pricelists FOR
            SELECT list_header_id, NAME, currency_code,
                   start_date_active, end_date_active, attribute2
              FROM qp_list_headers qlh
             WHERE     SYSDATE BETWEEN NVL (qlh.start_date_active, SYSDATE)
                                   AND NVL (qlh.end_date_active, SYSDATE)
                   AND qlh.active_flag = 'Y'
                   AND attribute2 IS NOT NULL
                   AND attribute2 = p_site;
    END xxdoec_get_dw_pricelists;

    PROCEDURE xxdoec_get_dw_pricelist_items (p_listid       NUMBER,
                                             o_items    OUT t_item_cursor)
    AS
        l_quantity     NUMBER := 1;
        l_sku_type     VARCHAR2 (15) := 'SKU Pricing';
        l_model_type   VARCHAR2 (15) := 'Model Pricing';
    BEGIN
        OPEN o_items FOR
            SELECT NVL (
                       msi.upc_code, --Added by BT Technology team on 11/10/2014
                       -- SELECT NVL (msi.attribute11,                 --commented by Bt Technology team on 11/10/2014
                       (SELECT mcr.cross_reference
                          FROM mtl_cross_references mcr
                         WHERE     mcr.inventory_item_id =
                                   msi.inventory_item_id
                               AND cross_reference_type =
                                   'UPC Cross Reference'
                               AND ROWNUM = 1)) upc,
                   /*msi.segment1 style,
                   -- msi.segment2 color,
                   --msi.segment3 size_, */
                   --commented by BT Technology Team on 11/10/2014
                   msi.style_number style,
                   msi.color_code color,
                   msi.item_size size_, -- Added by BT Technology Team on 11/10/2014
                   qll.operand unit_price,
                   qpa.product_uom_code,
                   qll.start_date_active,
                   qll.end_date_active,
                   l_quantity quantity,
                   --msi.description,                                 -- commented by BT Technology team on 11/10/2014
                   msi.item_description description, -- Added by BT Technology team on 11/10/2014
                   l_sku_type pricing_type
              FROM qp_list_lines_v qll, qp_pricing_attributes qpa, --mtl_system_items_b msi                         --commented by BT Technology Team on 11/10/2014
                                                                   xxd_common_items_v msi --Added by BT Technology Team on 11/10/2014
             WHERE     qpa.list_line_id = qll.list_line_id
                   AND qpa.product_attribute_context = 'ITEM'
                   AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                   AND msi.inventory_item_id =
                       TO_NUMBER (qpa.product_attr_value)
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND SYSDATE BETWEEN NVL (qll.start_date_active, SYSDATE)
                                   AND NVL (qll.end_date_active, SYSDATE)
                   AND qll.list_header_id = p_listid
            UNION ALL
            -- SELECT NVL (msi.attribute11, --commented by Bt Technology team on 11/10/2014
            SELECT NVL (
                       msi.upc_code, --Added by BT Technology team on 11/10/2014
                       (SELECT mcr.cross_reference
                          FROM mtl_cross_references mcr
                         WHERE     mcr.inventory_item_id =
                                   msi.inventory_item_id
                               AND cross_reference_type =
                                   'UPC Cross Reference'
                               AND ROWNUM = 1)) upc,
                   /* --msi.segment1 style,
                     -- msi.segment2 color,
                     --msi.segment3 size_,*/
                   --commented by BT Technology Team on 11/10/2014
                   msi.color_code color,
                   msi.style_number style,
                   msi.item_size size_, -- Added by BT Technology Team on 11/10/2014
                   qll.operand unit_price,
                   qpa.product_uom_code,
                   qll.start_date_active,
                   qll.end_date_active,
                   l_quantity quantity, --msi.description,                 -- commented by BT Technology team on 11/10/2014
                   msi.item_description description, -- Added by BT Technology team on 11/10/2014
                   l_model_type pricing_type
              FROM qp_list_lines_v qll, qp_pricing_attributes qpa, /*-- mtl_item_categories mic,
                                                                    --mtl_categories_b mcb,
                                                                    --mtl_category_sets_b mcs,
                                                                    --mtl_system_items_b msi, */
                                                                   --commented by BT Technology Team on 11/10/2014
                                                                   mtl_default_category_sets mdc,
                   xxd_common_items_v msi, --Added by BT Technology Team on 11/10/2014
                                           fnd_lookup_values flv
             WHERE     qpa.list_line_id = qll.list_line_id
                   AND qpa.product_attribute_context = 'ITEM'
                   AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                   --AND mic.category_id = TO_NUMBER (qpa.product_attr_value)          --commented by BT Technology Team on 11/10/2014
                   AND msi.category_id = TO_NUMBER (qpa.product_attr_value) --Added by BT Technology Team on 11/10/2014
                   /*AND mcb.category_id = mic.category_id
                    AND mic.category_set_id = mcs.category_set_id
                    AND mcb.structure_id = mcs.structure_id
                    AND msi.inventory_item_id = mic.inventory_item_id
                    AND msi.organization_id = mic.organization_id
                    AND mic.organization_id = fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                    AND mcs.category_set_id = mdc.category_set_id*/
                               --commented By BT Technology team on 11/10/2014
                   AND msi.organization_id =
                       fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                   AND msi.category_set_id = mdc.category_set_id --Added by BT Technology Team on 11/10/2014
                   AND mdc.functional_area_id = TO_NUMBER (flv.lookup_code)
                   AND flv.meaning = 'Order Entry'
                   AND flv.lookup_type = 'MTL_FUNCTIONAL_AREAS'
                   AND SYSDATE BETWEEN NVL (qll.start_date_active, SYSDATE)
                                   AND NVL (qll.end_date_active, SYSDATE)
                   AND qll.list_header_id = p_listid;
    END xxdoec_get_dw_pricelist_items;

    PROCEDURE xxdoec_get_price_for_mdl_clr (p_model IN VARCHAR2, p_color IN VARCHAR2, p_size IN VARCHAR2
                                            , p_brand IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                              o_items OUT t_item_cursor)
    AS
        l_price_list_id   NUMBER := NULL;
        l_kco_header_id   NUMBER := -1;
        l_sku_type        VARCHAR2 (15) := 'SKU Pricing';
        l_model_type      VARCHAR2 (15) := 'Model Pricing';
        l_inv_org_id      NUMBER;
        l_erp_org_id      NUMBER;
        l_brand           VARCHAR2 (10);
    BEGIN
        SELECT om_price_list_id, inv_org_id, erp_org_id,
               brand_name
          INTO l_price_list_id, l_inv_org_id, l_erp_org_id, l_brand
          FROM xxdo.xxdoec_country_brand_params
         WHERE website_id = p_brand;

        IF (p_price_list_id IS NOT NULL)
        THEN
            l_price_list_id   := p_price_list_id;                -- CCR0008008

            OPEN o_items FOR
                -- SELECT NVL (msi.attribute11, --commented by Bt Technology team on 11/10/2014
                SELECT NVL (
                           msi.upc_code, --Added by BT Technology team on 11/10/2014
                           (SELECT mcr.cross_reference
                              FROM mtl_cross_references mcr
                             WHERE     mcr.inventory_item_id =
                                       msi.inventory_item_id
                                   AND cross_reference_type =
                                       'UPC Cross Reference'
                                   AND ROWNUM = 1)) upc,
                       /*msi.segment1 style,
                    -- msi.segment2 color,
                    --msi.segment3 size_, */
                       --commented by BT Technology Team on 11/10/2014
                       msi.style_number style,
                       msi.color_code color,
                       msi.item_size size_, -- Added by BT Technology Team on 11/10/2014
                       qll.operand unit_price,
                       qpa.product_uom_code,
                       qll.start_date_active,
                       qll.end_date_active,
                       (SELECT MAX (NVL (inv.atp_qty, 0))
                          FROM xxdo.xxdoec_inventory inv
                         WHERE     inv.inventory_item_id =
                                   msi.inventory_item_id
                               --AND inv.inv_org_id = l_inv_org_id              --commented as one brand can have multiple inv_org_id and a sku can be present in one org and not in other
                               AND inv.brand = l_brand
                               AND inv.erp_org_id = l_erp_org_id) quantity,
                       --msi.description,                             -- commented by BT Technology team on 11/10/2014
                       msi.item_description description, -- Added by BT Technology team on 11/10/2014
                       l_sku_type pricing_type
                  FROM qp_list_lines_v qll, qp_pricing_attributes qpa, --mtl_system_items_b msi  --commented by BT Technology Team on 11/10/2014
                                                                       xxd_common_items_v msi --Added by BT Technology Team on 11/10/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND msi.inventory_item_id =
                           TO_NUMBER (qpa.product_attr_value)
                       AND msi.organization_id =
                           fnd_profile.VALUE ('QP_ORGANIZATION_ID')
                       AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                SYSDATE)
                                       AND NVL (qll.end_date_active, SYSDATE)
                       AND qll.list_header_id = l_price_list_id
                       /*AND msi.segment1= p_model
                        AND msi.segment2 = p_color
                        AND msi.segment3 = p_size*/
                       --commented by BT Technology team on 11/10/2014
                       AND msi.style_number = p_model
                       AND msi.color_code = p_color
                       AND msi.item_size = P_size --Added by BT Technology Team on 11/10/2014
                UNION ALL
                SELECT NVL (
                           msi.upc_code, --Added by BT Technology team on 11/10/2014
                           -- SELECT NVL (msi.attribute11,                 --commented by Bt Technology team on 11/10/2014
                           (SELECT mcr.cross_reference
                              FROM mtl_cross_references mcr
                             WHERE     mcr.inventory_item_id =
                                       msi.inventory_item_id
                                   AND cross_reference_type =
                                       'UPC Cross Reference'
                                   AND ROWNUM = 1)) upc,
                       /*msi.segment1 style,
                      -- msi.segment2 color,
                      --msi.segment3 size_, */
                       --commented by BT Technology Team on 11/10/2014
                       msi.style_number style,
                       msi.color_code color,
                       msi.item_size size_, -- Added by BT Technology Team on 11/10/2014
                       qll.operand unit_price,
                       qpa.product_uom_code,
                       qll.start_date_active,
                       qll.end_date_active,
                       (SELECT MAX (NVL (inv.atp_qty, 0))
                          FROM xxdo.xxdoec_inventory inv
                         WHERE     inv.inventory_item_id =
                                   msi.inventory_item_id
                               --AND inv.inv_org_id = l_inv_org_id              --commented as one brand can have multiple inv_org_id and a sku can be present in one org and not in other
                               AND inv.brand = l_brand
                               AND inv.erp_org_id = l_erp_org_id) quantity,
                       --msi.description,                             -- commented by BT Technology team on 11/10/2014
                       msi.item_description description, -- Added by BT Technology team on 11/10/2014
                       l_model_type pricing_type
                  FROM qp_list_lines_v qll, qp_pricing_attributes qpa, /* mtl_item_categories mic,
                                                                        mtl_categories_b mcb,
                                                                        mtl_category_sets_b mcs,
                                                                         --mtl_system_items_b msi,*/
                                                                       --commented by BT Technology Team on 11/10/2014
                                                                       mtl_default_category_sets mdc,
                       xxd_common_items_v msi, --Added by BT Technology Team on 11/10/2014
                                               fnd_lookup_values flv
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                       /* AND mic.category_id = TO_NUMBER (qpa.product_attr_value)
                        AND mcb.category_id = mic.category_id
                        AND mic.category_set_id = mcs.category_set_id
                        AND mcb.structure_id = mcs.structure_id
                        AND msi.inventory_item_id = mic.inventory_item_id
                        AND msi.organization_id = mic.organization_id
                        AND mic.organization_id =
                                               fnd_profile.VALUE ('QP_ORGANIZATION_ID')

                        AND mcs.category_set_id = mdc.category_set_id*/
                       --commented by BT Technology Team on 11/10/2014
                       AND msi.category_id =
                           TO_NUMBER (qpa.product_attr_value)
                       AND msi.organization_id =
                           fnd_profile.VALUE ('QP_ORGANIZATION_ID') --Added by BT Technology Team on 11/10/2014
                       AND mdc.functional_area_id =
                           TO_NUMBER (flv.lookup_code)
                       AND flv.meaning = 'Order Entry'
                       AND flv.lookup_type = 'MTL_FUNCTIONAL_AREAS'
                       AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                SYSDATE)
                                       AND NVL (qll.end_date_active, SYSDATE)
                       AND qll.list_header_id = l_price_list_id
                       AND msi.style_number = p_model
                       AND msi.color_code = p_color
                       AND msi.item_size = P_size; --Added by BT Technology team on 11/10/2014
        /*AND msi.segment1= p_model
        --AND msi.segment2 = p_color
        --AND msi.segment3 = p_size*/
                               --commented by BT Technology team on 11/10/2014
        ELSE                                        -- p_price_list_id is NULL
            o_items   := NULL;                                   -- CCR0008008
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_items   := NULL;
    END xxdoec_get_price_for_mdl_clr;
END xxdoec_pricelist_pkg;
/
