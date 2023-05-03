--
-- XXDOINT_OM_ORDER_IMPORT_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINT_OM_ORDER_IMPORT_UTILS"
    AUTHID DEFINER
AS
    FUNCTION get_packing_instructions (p_customer_number   IN VARCHAR2, --BT Change: Infosys - 11-Mar-2014
                                       p_brand             IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_shipping_instructions (p_customer_number   IN VARCHAR2, --BT Change: Infosys - 11-Mar-2014
                                        p_brand             IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION billToAddress_to_location (p_customer_number IN VARCHAR2, --BT Change: Infosys - 11-Mar-2014
                                                                       p_operating_unit_id IN NUMBER, p_street1 IN VARCHAR2, p_street2 IN VARCHAR2, p_city IN VARCHAR2, p_state IN VARCHAR2
                                        , p_country IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_list_price (p_brand           IN VARCHAR2,
                             p_org_id          IN NUMBER,
                             p_currency        IN VARCHAR2,
                             p_price_list_id   IN NUMBER,
                             p_sku             IN VARCHAR2,
                             p_unit_price      IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_adj_percentage (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                 , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_adj_line_type_code (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                     , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_adj_list_line_id (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                   , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_adj_list_header_id (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                     , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN NUMBER;

    FUNCTION adj_required (p_brand           IN VARCHAR2,
                           p_org_id          IN NUMBER,
                           p_currency        IN VARCHAR2,
                           p_price_list_id   IN NUMBER,
                           p_sku             IN VARCHAR2,
                           p_unit_price      IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE get_adj_details (p_brand            IN     VARCHAR2,
                               p_org_id           IN     NUMBER,
                               p_currency         IN     VARCHAR2,
                               p_price_list_id    IN     NUMBER,
                               p_sku              IN     VARCHAR2,
                               p_unit_price       IN     NUMBER,
                               x_list_header_id      OUT NUMBER,
                               x_list_line_id        OUT NUMBER,
                               x_line_type_code      OUT VARCHAR2,
                               x_percentage          OUT NUMBER,
                               x_list_price          OUT NUMBER);

    FUNCTION isDropShipLocation (p_customer_number     IN VARCHAR2, --BT Change: Infosys - 11-Mar-2014
                                 p_operating_unit_id   IN NUMBER,
                                 p_location_code       IN VARCHAR2,
                                 p_street1             IN VARCHAR2,
                                 p_street2             IN VARCHAR2,
                                 p_city                IN VARCHAR2,
                                 p_state               IN VARCHAR2,
                                 p_country             IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION customer_number_to_customer_id (p_customer_number VARCHAR2) --BT Change: Infosys - 11-Mar-2014
        RETURN NUMBER;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_OM_ORDER_IMPORT_UTILS TO SOA_INT
/
