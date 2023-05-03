--
-- XXD_PO_INTERCO_PRICE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_INTERCO_PRICE_PKG"
AS
    /*****************************************************************
    * Package:           XXD_PO_INTERCO_PRICE
    *
    * Author:            GJensen
    *
    * Created:            29-OCT-2019
    *
    * Description:
    *
    * Modifications:
    * Date modified        Developer name          Version
    * 10/29/2019           GJensen                 Original(1.0)
    *****************************************************************/
    FUNCTION GET_OVERHEAD_WITH_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                     , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITHOUT_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                        , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITHOUT_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                       , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITH_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                    , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                       , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_MATERIAL_COST_FACT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                     , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITH_DUTY_FACT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                          , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_OVERHEAD_WITHOUT_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                            , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITHOUT_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                           , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_FREIGHT_WITH_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                        , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                           , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_MARKUP (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                         , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_PRICELIST (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                            , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    /*   FUNCTION GET_ORDER_TYPE (p_from_inv_org        IN NUMBER,
                                p_to_inv_org          IN NUMBER,
                                p_from_org_id         IN NUMBER,
                                p_to_org_id           IN NUMBER,
                                p_brand               IN VARCHAR2,
                                p_inventory_item_id   IN NUMBER,
                                p_order_type_id       IN NUMBER,
                                p_line_id             IN NUMBER DEFAULT NULL,
                                p_source              IN VARCHAR2 DEFAULT NULL)
          RETURN VARCHAR2;*/

    /*   PROCEDURE PRICE_LIST_PRICE (
          p_price_list_id       IN     NUMBER,
          p_inventory_item_id   IN     NUMBER,
          p_category_id         IN     NUMBER,
          p_currency_code       IN     VARCHAR2,
          p_uom                 IN     VARCHAR2,
          p_price_list             OUT NUMBER,
          p_line_id             IN     NUMBER DEFAULT NULL);*/

    FUNCTION GET_PRICE_LIST_PRICE (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                   , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION GET_EXCHANGE_RATE (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION get_interco_price (pn_po_line_id IN NUMBER)
        RETURN NUMBER;
END XXD_PO_INTERCO_PRICE_PKG;
/
