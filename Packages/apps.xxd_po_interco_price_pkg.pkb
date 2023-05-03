--
-- XXD_PO_INTERCO_PRICE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_INTERCO_PRICE_PKG"
AS
    /*****************************************************************
    * Package:            XXDO_INTERCOM_PRICING_PKG
    * Author:            GJensen
    *
    * Created:            29-OCT-2019
    *
    * Description:        Calculate the PO Interco price.
    *
    * Modifications:
    * Date modified        Developer name          Version
    * 10/29/2019           GJensen                 Original(1.0)
    *****************************************************************/
    FUNCTION GET_OVERHEAD_WITH_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                     , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_OVERHEAD_WITH_DUTY (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                -- xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_OVERHEAD_WITH_DUTY : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_OVERHEAD_WITH_DUTY;

    FUNCTION GET_OVERHEAD_WITHOUT_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                        , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_OVERHEAD_WITHOUT_DUTY (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                /*   xxcp_foundation.fndwriteerror (
                      100,
                         'Unhandled Exception in GET_OVERHEAD_WITHOUT_DUTY : '
                      || SQLERRM);*/
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_OVERHEAD_WITHOUT_DUTY;

    FUNCTION GET_FREIGHT_WITHOUT_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                       , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_FREIGHT_WITHOUT_DUTY (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --  xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_FREIGHT_WITHOUT_DUTY : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_FREIGHT_WITHOUT_DUTY;

    FUNCTION GET_FREIGHT_WITH_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                    , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_FREIGHT_WITH_DUTY (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_FREIGHT_WITH_DUTY : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_FREIGHT_WITH_DUTY;

    FUNCTION GET_DUTY (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                       , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_DUTY (cShipFrom_InvOrgID,
                                                    cShipTo_InvOrgID,
                                                    cShipFrom_OrgID,
                                                    cShipTo_OrgID,
                                                    cBrand,
                                                    cInv_ItemID,
                                                    cOrderTypeID,
                                                    cLineID,
                                                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                -- xxcp_foundation.fndwriteerror ( 100, 'Unhandled Exception in GET_DUTY : ' || SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_DUTY;

    FUNCTION GET_MATERIAL_COST_FACT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                     , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_MATERIAL_COST_FACT (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_MATERIAL_COST_FACT : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_MATERIAL_COST_FACT;

    FUNCTION GET_OVERHEAD_WITH_DUTY_FACT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                          , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_OVERHEAD_WITH_DUTY_FACT (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_OVERHEAD_WITH_DUTY_FACT : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_OVERHEAD_WITH_DUTY_FACT;

    FUNCTION GET_OVERHEAD_WITHOUT_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                            , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_OVERHEAD_WITHOUT_DUTY_FCT (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                -- xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_OVERHEAD_WITHOUT_DUTY_FCT : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_OVERHEAD_WITHOUT_DUTY_FCT;

    FUNCTION GET_FREIGHT_WITHOUT_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                           , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_FREIGHT_WITHOUT_DUTY_FCT (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_FREIGHT_WITHOUT_DUTY_FCT : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_FREIGHT_WITHOUT_DUTY_FCT;

    FUNCTION GET_FREIGHT_WITH_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                        , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_FREIGHT_WITH_DUTY_FCT (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_FREIGHT_WITH_DUTY_FCT : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_FREIGHT_WITH_DUTY_FCT;

    FUNCTION GET_DUTY_FCT (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                           , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_DUTY_FCT (cShipFrom_InvOrgID,
                                                        cShipTo_InvOrgID,
                                                        cShipFrom_OrgID,
                                                        cShipTo_OrgID,
                                                        cBrand,
                                                        cInv_ItemID,
                                                        cOrderTypeID,
                                                        cLineID,
                                                        cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_DUTY_FCT : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_DUTY_FCT;

    FUNCTION GET_MARKUP (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                         , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_MARKUP (cShipFrom_InvOrgID,
                                                      cShipTo_InvOrgID,
                                                      cShipFrom_OrgID,
                                                      cShipTo_OrgID,
                                                      cBrand,
                                                      cInv_ItemID,
                                                      cOrderTypeID,
                                                      cLineID,
                                                      cSource);

            IF vResult = 0
            THEN
                vResult   := 1;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_MARKUP : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_MARKUP;

    FUNCTION GET_PRICELIST (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                            , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_PRICELIST (cShipFrom_InvOrgID,
                                                         cShipTo_InvOrgID,
                                                         cShipFrom_OrgID,
                                                         cShipTo_OrgID,
                                                         cBrand,
                                                         cInv_ItemID,
                                                         cOrderTypeID,
                                                         cLineID,
                                                         cSource);

            --Set for Rahesh to always be 0
            vResult   := 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                xxcp_foundation.fndwriteerror (
                    100,
                    'Unhandled Exception in GET_PRICELIST : ' || SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_PRICELIST;

    FUNCTION GET_PRICE_LIST_PRICE (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                   , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_PRICE_LIST_PRICE (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_PRICE_LIST_PRICE : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_PRICE_LIST_PRICE;


    FUNCTION GET_EXCHANGE_RATE (cShipFrom_InvOrgID IN NUMBER, cShipTo_InvOrgID IN NUMBER, cShipFrom_OrgID IN NUMBER, cShipTo_OrgID IN NUMBER, cBrand IN VARCHAR2, cInv_ItemID IN NUMBER
                                , cOrderTypeID IN NUMBER, cLineID IN NUMBER DEFAULT NULL, cSource IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        vResult   NUMBER;
    BEGIN
        BEGIN
            --Get XXDO_INTERCOM_PRICING_PKG function results

            vResult   :=
                XXDO_INTERCOM_PRICING_PKG.GET_EXCHANGE_RATE (
                    cShipFrom_InvOrgID,
                    cShipTo_InvOrgID,
                    cShipFrom_OrgID,
                    cShipTo_OrgID,
                    cBrand,
                    cInv_ItemID,
                    cOrderTypeID,
                    cLineID,
                    cSource);


            IF vResult = 0
            THEN
                vResult   := 1;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                -- Write entry to XXCP_ERRORS table for debug
                --xxcp_foundation.fndwriteerror(100, 'Unhandled Exception in GET_EXCHANGE_RATE : '||SQLERRM);
                vResult   := 0;
        END;



        RETURN (vResult);
    END GET_EXCHANGE_RATE;

    --Main external function to get interco price for PO LIne
    FUNCTION get_interco_price (pn_po_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_unit_price          NUMBER;
        lv_brand               VARCHAR2 (20);
        ln_inventory_item_id   NUMBER;
        ln_line_location_id    NUMBER;
        ln_from_inv_org_id     NUMBER;
        ln_to_inv_org_id       NUMBER;
        ln_from_org_id         NUMBER;
        ln_to_org_id           NUMBER;
        ln_order_type_id       NUMBER;
        ln_line_id             NUMBER;
        ln_oe_line_price       NUMBER;
        ln_calc_price          NUMBER;
        ln_sub_calc_price      NUMBER;
    BEGIN
        --Get PO Line fields
        BEGIN
            SELECT pla.unit_price, pla.attribute1, pla.item_id,
                   plla.line_location_id
              INTO ln_unit_price, lv_brand, ln_inventory_item_id, ln_line_location_id
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_line_id = pn_po_line_id
                   AND pla.po_line_id = plla.po_line_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN 0;
            WHEN OTHERS
            THEN
                RETURN 0;
        END;

        BEGIN
            --Get Order data
            SELECT DISTINCT oola.ship_from_org_id, prla.destination_organization_id, oola.org_id,
                            prla.org_id, ooha.order_type_id, oola.line_id
              INTO ln_from_inv_org_id, ln_to_inv_org_id, ln_from_org_id, ln_to_org_id,
                                     ln_order_type_id, ln_line_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, po_requisition_lines_all prla
             WHERE     oola.header_id = ooha.header_id
                   AND prla.requisition_line_id =
                       oola.source_document_line_id
                   AND prla.item_id = oola.inventory_item_id
                   AND NVL (oola.context, 'NONE') != 'DO eCommerce'
                   AND oola.open_flag = 'Y'
                   AND oola.attribute16 = TO_CHAR (ln_line_location_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    --PO/Order not linked w/Attribute16

                    -- check if drop ship. if so then return oe line price
                    SELECT unit_selling_price
                      INTO ln_oe_line_price
                      FROM oe_order_lines_all oola, oe_drop_ship_sources dss
                     WHERE     oola.line_id = dss.line_id
                           AND dss.line_location_id = ln_line_location_id;

                    RETURN ln_oe_line_price;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --No price needed
                        RETURN NULL;
                END;
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        --Get the calculated price from the formula
        ln_sub_calc_price   :=
              (  ln_unit_price
               * NVL (
                     get_material_cost_fact (
                         cShipFrom_InvOrgID   => ln_from_inv_org_id,
                         cShipTo_InvOrgID     => ln_to_inv_org_id,
                         cShipFrom_OrgID      => ln_from_org_id,
                         cShipTo_OrgID        => ln_to_org_id,
                         cBrand               => lv_brand,
                         cInv_ItemID          => ln_inventory_item_id,
                         cOrderTypeID         => ln_order_type_id,
                         cLineID              => NULL),
                     1))
            + (  get_duty (cShipFrom_InvOrgID => ln_from_inv_org_id, cShipTo_InvOrgID => ln_to_inv_org_id, cShipFrom_OrgID => ln_from_org_id, cShipTo_OrgID => ln_to_org_id, cBrand => lv_brand, cInv_ItemID => ln_inventory_item_id
                           , cOrderTypeID => ln_order_type_id, cLineID => NULL)
               * NVL (
                     get_duty_fct (
                         cShipFrom_InvOrgID   => ln_from_inv_org_id,
                         cShipTo_InvOrgID     => ln_to_inv_org_id,
                         cShipFrom_OrgID      => ln_from_org_id,
                         cShipTo_OrgID        => ln_to_org_id,
                         cBrand               => lv_brand,
                         cInv_ItemID          => ln_inventory_item_id,
                         cOrderTypeID         => ln_order_type_id,
                         cLineID              => NULL),
                     1))
            + (  get_overhead_with_duty (
                     cShipFrom_InvOrgID   => ln_from_inv_org_id,
                     cShipTo_InvOrgID     => ln_to_inv_org_id,
                     cShipFrom_OrgID      => ln_from_org_id,
                     cShipTo_OrgID        => ln_to_org_id,
                     cBrand               => lv_brand,
                     cInv_ItemID          => ln_inventory_item_id,
                     cOrderTypeID         => ln_order_type_id,
                     cLineID              => NULL)
               * NVL (
                     get_overhead_with_duty_fact (
                         cShipFrom_InvOrgID   => ln_from_inv_org_id,
                         cShipTo_InvOrgID     => ln_to_inv_org_id,
                         cShipFrom_OrgID      => ln_from_org_id,
                         cShipTo_OrgID        => ln_to_org_id,
                         cBrand               => lv_brand,
                         cInv_ItemID          => ln_inventory_item_id,
                         cOrderTypeID         => ln_order_type_id,
                         cLineID              => NULL),
                     1))
            + (  get_freight_with_duty (
                     cShipFrom_InvOrgID   => ln_from_inv_org_id,
                     cShipTo_InvOrgID     => ln_to_inv_org_id,
                     cShipFrom_OrgID      => ln_from_org_id,
                     cShipTo_OrgID        => ln_to_org_id,
                     cBrand               => lv_brand,
                     cInv_ItemID          => ln_inventory_item_id,
                     cOrderTypeID         => ln_order_type_id,
                     cLineID              => NULL)
               * NVL (
                     get_freight_with_duty_fct (
                         cShipFrom_InvOrgID   => ln_from_inv_org_id,
                         cShipTo_InvOrgID     => ln_to_inv_org_id,
                         cShipFrom_OrgID      => ln_from_org_id,
                         cShipTo_OrgID        => ln_to_org_id,
                         cBrand               => lv_brand,
                         cInv_ItemID          => ln_inventory_item_id,
                         cOrderTypeID         => ln_order_type_id,
                         cLineID              => NULL),
                     1))
            + (  get_freight_without_duty (
                     cShipFrom_InvOrgID   => ln_from_inv_org_id,
                     cShipTo_InvOrgID     => ln_to_inv_org_id,
                     cShipFrom_OrgID      => ln_from_org_id,
                     cShipTo_OrgID        => ln_to_org_id,
                     cBrand               => lv_brand,
                     cInv_ItemID          => ln_inventory_item_id,
                     cOrderTypeID         => ln_order_type_id,
                     cLineID              => NULL)
               * NVL (
                     get_freight_without_duty_fct (
                         cShipFrom_InvOrgID   => ln_from_inv_org_id,
                         cShipTo_InvOrgID     => ln_to_inv_org_id,
                         cShipFrom_OrgID      => ln_from_org_id,
                         cShipTo_OrgID        => ln_to_org_id,
                         cBrand               => lv_brand,
                         cInv_ItemID          => ln_inventory_item_id,
                         cOrderTypeID         => ln_order_type_id,
                         cLineID              => NULL),
                     1))
            + (  get_overhead_without_duty (
                     cShipFrom_InvOrgID   => ln_from_inv_org_id,
                     cShipTo_InvOrgID     => ln_to_inv_org_id,
                     cShipFrom_OrgID      => ln_from_org_id,
                     cShipTo_OrgID        => ln_to_org_id,
                     cBrand               => lv_brand,
                     cInv_ItemID          => ln_inventory_item_id,
                     cOrderTypeID         => ln_order_type_id,
                     cLineID              => NULL)
               * NVL (
                     get_overhead_without_duty_fct (
                         cShipFrom_InvOrgID   => ln_from_inv_org_id,
                         cShipTo_InvOrgID     => ln_to_inv_org_id,
                         cShipFrom_OrgID      => ln_from_org_id,
                         cShipTo_OrgID        => ln_to_org_id,
                         cBrand               => lv_brand,
                         cInv_ItemID          => ln_inventory_item_id,
                         cOrderTypeID         => ln_order_type_id,
                         cLineID              => NULL),
                     1));

        ln_calc_price   :=
              (  ln_sub_calc_price
               + (  ln_sub_calc_price
                  * NVL (
                        get_markup (
                            cShipFrom_InvOrgID   => ln_from_inv_org_id,
                            cShipTo_InvOrgID     => ln_to_inv_org_id,
                            cShipFrom_OrgID      => ln_from_org_id,
                            cShipTo_OrgID        => ln_to_org_id,
                            cBrand               => lv_brand,
                            cInv_ItemID          => ln_inventory_item_id,
                            cOrderTypeID         => ln_order_type_id,
                            cLineID              => NULL),
                        1)))
            * NVL (
                  get_exchange_rate (
                      cShipFrom_InvOrgID   => ln_from_inv_org_id,
                      cShipTo_InvOrgID     => ln_to_inv_org_id,
                      cShipFrom_OrgID      => ln_from_org_id,
                      cShipTo_OrgID        => ln_to_org_id,
                      cBrand               => lv_brand,
                      cInv_ItemID          => ln_inventory_item_id,
                      cOrderTypeID         => ln_order_type_id,
                      cLineID              => NULL),
                  1);

        RETURN ROUND (ln_calc_price, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;
END XXD_PO_INTERCO_PRICE_PKG;
/
