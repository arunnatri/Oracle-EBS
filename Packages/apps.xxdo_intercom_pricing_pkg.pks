--
-- XXDO_INTERCOM_PRICING_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INTERCOM_PRICING_PKG"
AS
    /*****************************************************************
    * Package:            XXDO_INTERCOM_PRICING_PKG
    *
    * Author:             BT Technology Team
    *
    * Created:            12-FEB-2015
    *
    * Description:
    *
    * Modifications:
    * Date modified        Developer name          Version
    * 2/12/2015            BT Technology Team      Original(1.0)
    * 11/18/2015 Defect 685 Added p_source Parameter to Functions calling MAIN and MIAN
    *****************************************************************/

    FUNCTION MAIN (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER, p_order_type_id IN NUMBER, p_cost_element IN VARCHAR2, p_line_id IN NUMBER DEFAULT NULL
                   , p_source IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2;

    FUNCTION GET_MATERIAL_COST (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITH_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                     , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITHOUT_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                        , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITHOUT_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                       , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITH_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                    , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                       , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_MATERIAL_COST_FACT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                     , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITH_DUTY_FACT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                          , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITHOUT_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                            , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITHOUT_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                           , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITH_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                        , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                           , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_MARKUP (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                         , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_PRICELIST (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                            , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_ORDER_TYPE (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                             , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2;

    PROCEDURE PRICE_LIST_PRICE (p_price_list_id IN NUMBER, p_inventory_item_id IN NUMBER, p_category_id IN NUMBER, p_currency_code IN VARCHAR2, p_uom IN VARCHAR2, p_price_list OUT NUMBER
                                , p_line_id IN NUMBER DEFAULT NULL);

    FUNCTION GET_PRICE_LIST_PRICE (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                   , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_EXCHANGE_RATE (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION CHECK_PRICELIST_FLAG (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                   , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2;

    FUNCTION BUILD_WHERE_CLAUSE (p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_brand IN VARCHAR2, p_reclass IN VARCHAR2
                                 , p_order_currency IN VARCHAR2, p_source_factory IN VARCHAR2, p_line_id IN NUMBER)
        RETURN VARCHAR2;
END XXDO_INTERCOM_PRICING_PKG;
/
