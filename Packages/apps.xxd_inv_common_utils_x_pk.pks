--
-- XXD_INV_COMMON_UTILS_X_PK  (Package) 
--
--  Dependencies: 
--   MRP_ATP_PUB (Package)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_ORDER_HEADERS (Synonym)
--   OE_ORDER_LINES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_COMMON_UTILS_X_PK"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 06-Jan-2015  1.0        BT Technology Team      Initial Version
    -- 23-May-2019  1.1        Viswanathan Pandian     Modified for CCR0007687
    ******************************************************************************************/
    PROCEDURE get_atp_details_prc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_inventory_item_name IN mtl_system_items_b.segment1%TYPE DEFAULT NULL, p_quantity_ordered IN oe_order_lines.ordered_quantity%TYPE, p_quantity_uom IN oe_order_lines.order_quantity_uom%TYPE, p_requested_ship_date IN oe_order_lines.request_date%TYPE, p_source_organization_id IN mtl_system_items_b.organization_id%TYPE, p_demand_class IN oe_order_headers.demand_class_code%TYPE, x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_atp_supply_demand OUT NOCOPY mrp_atp_pub.atp_supply_demand_typ, x_atp_period OUT NOCOPY mrp_atp_pub.atp_period_typ, x_atp_details OUT NOCOPY mrp_atp_pub.atp_details_typ, x_return_status OUT VARCHAR2
                                   , x_error_message OUT VARCHAR2);

    PROCEDURE get_atp_batch_prc (p_atp_rec IN mrp_atp_pub.atp_rec_typ, -- p_inventory_item_id     IN              mtl_system_items_b.inventory_item_id%TYPE,
                                                                       --  p_inventory_item_name   IN              mtl_system_items_b.segment1%TYPE
                                                                       --       DEFAULT NULL,
                                                                       x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_atp_supply_demand OUT NOCOPY mrp_atp_pub.atp_supply_demand_typ, x_atp_period OUT NOCOPY mrp_atp_pub.atp_period_typ, x_atp_details OUT NOCOPY mrp_atp_pub.atp_details_typ, x_return_status OUT NOCOPY VARCHAR2
                                 , x_error_message OUT NOCOPY VARCHAR2);

    PROCEDURE get_atr_details_prc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_organization_id IN mtl_system_items_b.organization_id%TYPE, p_subinventory_code IN VARCHAR2 DEFAULT NULL
                                   ,           -- Added for 1.1 for CCR0007687
                                     x_qty_atr OUT NOCOPY NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2);

    FUNCTION get_atr_qty_fnc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_organization_id IN mtl_system_items_b.organization_id%TYPE)
        RETURN NUMBER;

    FUNCTION get_atp_qty_fnc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_quantity_ordered IN oe_order_lines.ordered_quantity%TYPE, p_quantity_uom IN oe_order_lines.order_quantity_uom%TYPE
                              , p_requested_ship_date IN oe_order_lines.request_date%TYPE, p_source_organization_id IN mtl_system_items_b.organization_id%TYPE, p_demand_class IN oe_order_headers.demand_class_code%TYPE)
        RETURN NUMBER;
END xxd_inv_common_utils_x_pk;
/


GRANT EXECUTE ON APPS.XXD_INV_COMMON_UTILS_X_PK TO APPSRO
/
