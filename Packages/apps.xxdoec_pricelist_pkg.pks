--
-- XXDOEC_PRICELIST_PKG  (Package) 
--
--  Dependencies: 
--   MTL_CROSS_REFERENCES (Synonym)
--   QP_LIST_HEADERS (Synonym)
--   QP_LIST_LINES_V (View)
--   QP_PRICING_ATTRIBUTES (Synonym)
--   XXD_COMMON_ITEMS_V (View)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_PRICELIST_PKG"
AS
    TYPE xxdoec_pricelist_header IS RECORD
    (
        header_id        qp_list_headers.list_header_id%TYPE,
        list_name        qp_list_headers.NAME%TYPE,
        currency         qp_list_headers.currency_code%TYPE,
        startdate        qp_list_headers.start_date_active%TYPE,
        enddate          qp_list_headers.end_date_active%TYPE,
        ecommercesite    qp_list_headers.attribute2%TYPE
    );

    TYPE xxdoec_pricelist_item IS RECORD
    (
        upc             mtl_cross_references.cross_reference%TYPE,
        -- l_style        mtl_system_items_b.segment1%TYPE,                                  --commented by BT Technology team on 11/10/2014
        l_style         xxd_common_items_v.style_number%TYPE, --Added By BT Technology Team on 11/10/2014
        -- color          mtl_system_items_b.segment2%TYPE,                   --commented by BT Technology team on 11/10/2014
        color           xxd_common_items_v.color_code%TYPE, --Added By BT Technology Team on 11/10/2014
        --l_size         mtl_system_items_b.segment3%TYPE,                  --commented by BT Technology team on 11/10/2014
        l_size          xxd_common_items_v.item_size%TYPE, --Added By BT Technology Team on 11/10/2014
        unit_price      qp_list_lines_v.operand%TYPE,
        uom_code        qp_pricing_attributes.product_uom_code%TYPE,
        start_date      qp_list_lines_v.start_date_active%TYPE,
        end_date        qp_list_lines_v.end_date_active%TYPE,
        quantity        NUMBER,
        -- description    mtl_system_items_b.description%TYPE,                  -- --commented by BT Technology team on 11/10/2014
        description     xxd_common_items_v.item_description%TYPE,
        pricing_type    VARCHAR2 (30)
    );

    TYPE t_header_cursor IS REF CURSOR
        RETURN xxdoec_pricelist_header;

    TYPE t_item_cursor IS REF CURSOR
        RETURN xxdoec_pricelist_item;

    PROCEDURE xxdoec_get_dw_pricelists (o_pricelists OUT t_header_cursor);

    PROCEDURE xxdoec_get_dcd_pricelists (o_pricelists OUT t_header_cursor);

    PROCEDURE xxdoec_get_dw_pricelists (p_site             VARCHAR2,
                                        o_pricelists   OUT t_header_cursor);

    PROCEDURE xxdoec_get_dw_pricelist_items (p_listid       NUMBER,
                                             o_items    OUT t_item_cursor);

    PROCEDURE xxdoec_get_price_for_mdl_clr (p_model IN VARCHAR2, p_color IN VARCHAR2, p_size IN VARCHAR2
                                            , p_brand IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                              o_items OUT t_item_cursor);
END xxdoec_pricelist_pkg;
/
