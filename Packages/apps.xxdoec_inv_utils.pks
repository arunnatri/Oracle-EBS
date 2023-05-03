--
-- XXDOEC_INV_UTILS  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   MTL_CATEGORIES_B (Synonym)
--   MTL_CROSS_REFERENCES (Synonym)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   OE_REASONS (Synonym)
--   XXD_COMMON_ITEMS_V (View)
--   MTL_SYSTEM_ITEMS_B (Table)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOEC_INV_UTILS
AS
    /****************************************************************************************
    * Package      : XXDOEC_INV_UTILS
    * Author       : BT Technology Team
    * Created      : 03-NOV-2014
    * Program Name :
    * Description  : Ecomm-29 - Catalog integration with EBS and E-commerce application
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 03-NOV-2014   BT Technology Team         1.00       Initial BT Version
    ****************************************************************************************/

    G_APPLICATION   VARCHAR2 (300) := 'APPS.XXDOEC_INV_UTILS';

    -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
    --   TYPE brand_list IS RECORD (brand apps.mtl_categories_b.segment1%TYPE);
    TYPE brand_list IS RECORD
    (
        brand    apps.xxd_common_items_v.brand%TYPE
    );

    -- End modification by BT Technology Team on 03-Nov-2014 v1.0

    TYPE t_brand_cursor IS REF CURSOR
        RETURN brand_list;

    TYPE season_list -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
                     --IS RECORD (season apps.mtl_system_items_b.attribute1%TYPE);
                     IS RECORD
    (
        season    apps.xxd_common_items_v.curr_active_season%TYPE
    );

    -- End modification by BT Technology Team on 03-Nov-2014 v1.0

    TYPE styleColorSize_list IS RECORD
    (
        -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
        /*
              style   apps.mtl_system_items_b.segment1%TYPE,
              color   apps.mtl_system_items_b.segment2%TYPE,
              sze     apps.mtl_system_items_b.segment3%TYPE
        */
        style    apps.xxd_common_items_v.style_number%TYPE,
        color    apps.xxd_common_items_v.color_code%TYPE,
        sze      apps.xxd_common_items_v.item_size%TYPE
    -- End modification by BT Technology Team on 03-Nov-2014 v1.0
    );

    TYPE t_styleColorSize_cursor IS REF CURSOR
        RETURN styleColorSize_list;

    TYPE t_season_cursor IS REF CURSOR
        RETURN season_list;

    TYPE sku_list IS RECORD
    (
        upc            apps.mtl_cross_references.cross_reference%TYPE,
        oraclesku      VARCHAR2 (50),
        -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
        /*
              style         apps.mtl_system_items_b.segment1%TYPE,
              color         apps.mtl_system_items_b.segment2%TYPE,
              sze           apps.mtl_system_items_b.segment3%TYPE,
              color_name    apps.fnd_flex_values_vl.description%TYPE,
              description   apps.mtl_system_items_b.description%TYPE
        */
        style          apps.xxd_common_items_v.style_number%TYPE,
        color          apps.xxd_common_items_v.color_code%TYPE,
        sze            apps.xxd_common_items_v.item_size%TYPE,
        color_name     apps.xxd_common_items_v.color_desc%TYPE,
        -- End modification by BT Technology Team on 03-Nov-2014 v1.0
        description    apps.mtl_system_items_b.description%TYPE
    );

    TYPE t_sku_cursor IS REF CURSOR
        RETURN sku_list;

    TYPE orders_shipped_list IS RECORD
    (
        cust_po_number             apps.oe_order_lines_all.cust_po_number%TYPE,
        --line_id             apps.oe_order_lines_all.line_id%TYPE,
        attribute20                apps.oe_order_lines_all.attribute20%TYPE,
        meaning                    apps.fnd_lookup_values.meaning%TYPE,
        back_ordered               VARCHAR2 (10),
        inventory_item_id          inv.mtl_system_items_b.inventory_item_id%TYPE,
        attribute11                inv.mtl_system_items_b.attribute11%TYPE,
        cancel_code                apps.oe_reasons.reason_code%TYPE,
        cancel_meaning             apps.fnd_lookup_values.meaning%TYPE,
        ship_method_description    apps.fnd_lookup_values.description%TYPE,
        gift_wrap                  VARCHAR2 (4)
    );

    TYPE t_orders_shipped_list IS REF CURSOR
        RETURN orders_shipped_list;

    TYPE t_order_array IS TABLE OF VARCHAR2 (30)
        INDEX BY BINARY_INTEGER;

    FUNCTION is_excluded (p_inventory_item_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION next_calendar_date (p_date IN DATE DEFAULT NULL)
        RETURN DATE;

    -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
    /*
       FUNCTION kco_header_default (p_erporg_id      NUMBER,
                                    p_invorg_id   IN NUMBER,
                                    p_brand       IN VARCHAR2)
          RETURN NUMBER;
    */
    -- End modification by BT Technology Team on 03-Nov-2014 v1.0

    FUNCTION least_not_null (p_num1 IN NUMBER, p_num2 IN NUMBER)
        RETURN NUMBER;

    FUNCTION TO_NUMBER (p_date IN DATE)
        RETURN NUMBER;

    FUNCTION to_seconds (p_date_left IN DATE, p_date_right IN DATE)
        RETURN VARCHAR2;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I');

    PROCEDURE GetBrands (brand_list OUT t_brand_cursor);

    PROCEDURE GetSeasons (season_list OUT t_season_cursor);

    PROCEDURE GetSkus (p_brand IN apps.mtl_system_items_b.attribute1%TYPE, p_season IN apps.mtl_categories_b.segment1%TYPE, sku_list OUT t_sku_cursor);

    PROCEDURE GetStyleColorSize (p_upc IN apps.mtl_system_items_b.attribute11%TYPE, styleColorSize_list OUT t_styleColorSize_cursor);

    PROCEDURE GetOrderSummaryMods (
        p_list                IN     t_order_array,
        orders_shipped_list      OUT t_orders_shipped_list);
END XXDOEC_INV_UTILS;
/
