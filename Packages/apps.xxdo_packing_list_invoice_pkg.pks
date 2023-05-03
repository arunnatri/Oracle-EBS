--
-- XXDO_PACKING_LIST_INVOICE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_packing_list_invoice_pkg
AS
    P_ORG_ID              NUMBER;
    P_BRAND               VARCHAR2 (30);
    P_ORDER_NUMBER_FROM   NUMBER;
    P_ORDER_NUMBER_TO     NUMBER;
    P_CUSTOMER_NUMBER     VARCHAR2 (60);
    P_CUSTOMER_NAME       VARCHAR2 (180);
    P_ORDER_DATE_FROM     DATE;
    P_ORDER_DATE_TO       DATE;
    P_TRX_NUMBER_FROM     NUMBER;
    P_TRX_NUMBER_TO       NUMBER;
    lc_dyn_where_clause   VARCHAR2 (4000);

    FUNCTION beforeReport
        RETURN BOOLEAN;

    FUNCTION om_line_id_to_invoice_number (p_line_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION delivery_detail_container (p_delivery_detail_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION delivery_detail_container_wt (p_delivery_detail_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION delivery_detail_container_qty (p_delivery_detail_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_item_uom_conv (p_brand IN VARCHAR2, p_customer_id IN NUMBER, p_inventory_item_id IN NUMBER
                                , p_organization_id IN NUMBER)
        RETURN NUMBER;
END;
/
