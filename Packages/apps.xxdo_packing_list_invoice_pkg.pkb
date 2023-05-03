--
-- XXDO_PACKING_LIST_INVOICE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_PACKING_LIST_INVOICE_PKG
AS
    FUNCTION beforeReport
        RETURN BOOLEAN
    IS
        lb_fnd   BOOLEAN;
        ln_cnt   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside package - ' || P_BRAND);

        IF P_BRAND IS NOT NULL
        THEN
            lc_dyn_where_clause   := ' AND ooha.attribute5  = :P_BRAND ';
        END IF;

        IF P_ORDER_NUMBER_FROM IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND ooha.order_number   >= :P_ORDER_NUMBER_FROM ';
        END IF;

        IF P_ORDER_NUMBER_TO IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND ooha.order_number   <= :P_ORDER_NUMBER_TO ';
        END IF;

        IF P_CUSTOMER_NUMBER IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND custs.customer_number = :P_CUSTOMER_NUMBER ';
        END IF;

        IF P_CUSTOMER_NAME IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND custs.customer_name = :P_CUSTOMER_NAME ';
        END IF;


        IF P_ORDER_DATE_FROM IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND TRUNC(ooha.ordered_date) >= TRUNC(:P_ORDER_DATE_FROM) ';
        END IF;

        IF P_ORDER_DATE_TO IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND TRUNC(ooha.ordered_date) <= TRUNC(:P_ORDER_DATE_TO) ';
        END IF;

        IF P_TRX_NUMBER_FROM IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND xxdo_packing_list_invoice_pkg.om_line_id_to_invoice_number (oola.line_id) >= :P_TRX_NUMBER_FROM ';
        END IF;

        IF P_TRX_NUMBER_TO IS NOT NULL
        THEN
            lc_dyn_where_clause   :=
                   lc_dyn_where_clause
                || ' AND xxdo_packing_list_invoice_pkg.om_line_id_to_invoice_number (oola.line_id) <= :P_TRX_NUMBER_TO ';
        END IF;

        IF    P_BRAND IS NOT NULL
           OR P_ORDER_NUMBER_FROM IS NOT NULL
           OR P_ORDER_NUMBER_TO IS NOT NULL
           OR P_CUSTOMER_NUMBER IS NOT NULL
           OR P_CUSTOMER_NAME IS NOT NULL
           OR P_ORDER_DATE_FROM IS NOT NULL
           OR P_ORDER_DATE_TO IS NOT NULL
           OR P_TRX_NUMBER_FROM IS NOT NULL
           OR P_TRX_NUMBER_TO IS NOT NULL
        THEN
            lc_dyn_where_clause   := lc_dyn_where_clause || ' AND 1 = 1 ';
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                ' Please provide a value to any one parameter. ');
            lc_dyn_where_clause   := lc_dyn_where_clause || ' AND 1 != 1 ';
            lb_fnd                :=
                FND_CONCURRENT.SET_COMPLETION_STATUS (
                    'WARNING',
                    ' Please provide a value to any one parameter. ');
            fnd_file.put_line (
                fnd_file.LOG,
                ' Please provide a value to any one parameter. ');
        END IF;

        RETURN TRUE;
    END;

    FUNCTION om_line_id_to_invoice_number (p_line_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   apps.ra_customer_trx_all.trx_number%TYPE;
    BEGIN
        SELECT trx_number
          INTO l_ret
          FROM apps.ra_customer_trx_all rta, apps.ra_customer_trx_lines_all rtla
         WHERE     rtla.interface_line_context IN
                       ('ORDER ENTRY', 'INTERCOMPANY')
               AND rtla.interface_line_attribute6 = TO_CHAR (p_line_id)
               AND NVL (rtla.interface_line_attribute11, '0') = '0'
               AND rtla.line_type = 'LINE'
               AND rta.customer_trx_id = rtla.customer_trx_id;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION delivery_detail_container (p_delivery_detail_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   wsh_delivery_details.container_name%TYPE;
    BEGIN
        SELECT wdd.container_name
          INTO l_ret
          FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     wda.delivery_detail_id = p_delivery_detail_id
               AND wdd.delivery_detail_id = wda.parent_delivery_detail_id
               AND wdd.source_code = 'WSH'
               AND wdd.container_flag = 'Y';

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION delivery_detail_container_wt (p_delivery_detail_id IN NUMBER)
        RETURN NUMBER
    IS
        l_ret   NUMBER;
    BEGIN
        SELECT SUM (NVL (msib.unit_weight, 2) * wdd_itm.shipped_quantity)
          INTO l_ret
          FROM xxd_common_items_v msib,             --mtl_system_items_b msib,
                                        wsh_delivery_details wdd_itm, wsh_delivery_assignments wda_itm,
               wsh_delivery_assignments wda
         WHERE     wda.delivery_detail_id = wdd_itm.delivery_detail_id
               AND msib.organization_id = wdd_itm.organization_id
               AND msib.inventory_item_id = wdd_itm.inventory_item_id
               AND wda_itm.delivery_detail_id = p_delivery_detail_id
               AND wda.parent_delivery_detail_id =
                   wda_itm.parent_delivery_detail_id;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION delivery_detail_container_qty (p_delivery_detail_id IN NUMBER)
        RETURN NUMBER
    IS
        l_ret   NUMBER;
    BEGIN
        SELECT SUM (  shipped_quantity
                    * get_item_uom_conv (ooha.attribute5, ooha.sold_to_org_id, wdd.inventory_item_id
                                         , 7))
          INTO l_ret
          FROM oe_order_headers_all ooha, wsh_delivery_details wdd, wsh_delivery_assignments wda1,
               wsh_delivery_assignments wda
         WHERE     wda.delivery_detail_id = p_delivery_detail_id
               AND wda1.parent_delivery_detail_id =
                   wda.parent_delivery_detail_id
               AND wdd.delivery_detail_id = wda1.delivery_detail_id
               AND ooha.header_id = wdd.source_header_id;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_lookup_value (p_lookup_type IN VARCHAR2, p_brand IN VARCHAR2, p_lookup_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_value   custom.do_edi_lookup_values.meaning%TYPE;
    BEGIN
        SELECT meaning
          INTO l_value
          FROM custom.do_edi_lookup_values
         WHERE     lookup_type = p_lookup_type
               AND lookup_code = p_lookup_code
               AND brand IN ('ALL', p_brand)
               AND enabled_flag = 'Y';

        RETURN l_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_item_uom_conv (p_brand IN VARCHAR2, p_customer_id IN NUMBER, p_inventory_item_id IN NUMBER
                                , p_organization_id IN NUMBER)
        RETURN NUMBER
    IS
        l_ret   NUMBER := 1;
    BEGIN
        IF NVL (
               TO_NUMBER (
                   get_lookup_value ('UOM_CONV_REQUIRED',
                                     p_brand,
                                     p_customer_id)),
               0) >
           0
        THEN
            SELECT TO_NUMBER (lookup_value)
              INTO l_ret
              FROM do_custom.do_item_lookups
             WHERE     lookup_type = 'EDI_UOM_CONV'
                   AND brand = NVL (p_brand, brand)
                   AND inventory_item_id = NVL (p_inventory_item_id, -1)
                   AND organization_id = NVL (p_organization_id, 7);
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END;
END XXDO_PACKING_LIST_INVOICE_PKG;
/
