--
-- XXDOINT_OM_ORDER_IMPORT_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_OM_ORDER_IMPORT_UTILS"
AS
    G_PKG_NAME   CONSTANT VARCHAR2 (40) := 'xxdoint_om_order_import_utils';
    g_n_temp              NUMBER;
    l_buffer_number       NUMBER;

    --Start Changes by BT Technology Team for BT on 20-Mar-2015,  v1.0
    gn_user_id            NUMBER;
    gn_user_id1           NUMBER;
    gn_resp_id            NUMBER;
    gn_appln_id           NUMBER;

    --End Changes by BT Technology Team for BT on 20-Mar-2015,  v1.0

    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;

    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
    END;



    FUNCTION customer_number_to_customer_id (p_customer_number VARCHAR2)
        RETURN NUMBER --BT Change: Infosys - 11-Mar-2014: Changed data type of p_customer_number
    IS
        l_proc_name     VARCHAR2 (240) := 'CUSTOMER_NUMBER_TO_CUSTOMER_ID';
        x_customer_id   NUMBER;
    BEGIN
        SELECT customer_id
          INTO x_customer_id
          FROM ra_Hcustomers
         WHERE customer_number = p_customer_number; --BT Change: Infosys - 11-Mar-2014: Changed ra_customer to ra_HCustomer

        RETURN x_customer_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_packing_instructions (p_customer_number   IN VARCHAR2,
                                       p_brand             IN VARCHAR2)
        RETURN VARCHAR2
    IS --BT Change: Infosys - 11-Mar-2014: Changed data type of p_customer_number
        l_ret           do_custom.do_customer_lookups.attribute_large%TYPE;
        l_customer_id   NUMBER;
    BEGIN
        l_customer_id   := customer_number_to_customer_id (p_customer_number);

        SELECT attribute_large
          INTO l_ret
          FROM (  SELECT attribute_large
                    FROM do_custom.do_customer_lookups
                   WHERE     lookup_type = 'DO_DEF_PACKING_INSTRUCTS'
                         AND brand IN ('ALL', p_brand)
                         AND customer_id = l_customer_id
                         AND enabled_flag = 'Y'
                ORDER BY DECODE (brand, 'ALL', 1, 0))
         WHERE ROWNUM = 1;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_shipping_instructions (p_customer_number   IN VARCHAR2,
                                        p_brand             IN VARCHAR2)
        RETURN VARCHAR2
    IS --BT Change: Infosys - 11-Mar-2014: Changed data type of p_customer_number
        l_ret           do_custom.do_customer_lookups.attribute_large%TYPE;
        l_customer_id   NUMBER;
    BEGIN
        l_customer_id   := customer_number_to_customer_id (p_customer_number);

        SELECT attribute_large
          INTO l_ret
          FROM (  SELECT attribute_large
                    FROM do_custom.do_customer_lookups
                   WHERE     lookup_type = 'DO_DEF_SHIPPING_INSTRUCTS'
                         AND brand IN ('ALL', p_brand)
                         AND customer_id = l_customer_id
                         AND enabled_flag = 'Y'
                ORDER BY DECODE (brand, 'ALL', 1, 0))
         WHERE ROWNUM = 1;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;



    FUNCTION billToAddress_to_location (p_customer_number IN VARCHAR2, p_operating_unit_id IN NUMBER, p_street1 IN VARCHAR2, p_street2 IN VARCHAR2, p_city IN VARCHAR2, p_state IN VARCHAR2
                                        , p_country IN VARCHAR2)
        RETURN VARCHAR2
    IS --BT Change: Infosys - 11-Mar-2014: Changed data type of p_customer_number
        x_location   VARCHAR2 (100);
    BEGIN
        SELECT site_name
          INTO x_location
          FROM XXDO.xxdoint_ar_cust_unified_v
         WHERE     account_number = p_customer_number
               AND operating_unit_id = p_operating_unit_id
               AND NVL (UPPER (address1), '%') LIKE
                       NVL (UPPER (p_street1), '%')
               AND NVL (UPPER (address2), '%') LIKE
                       NVL (UPPER (p_street2), '%')
               AND NVL (UPPER (city), '%') LIKE NVL (UPPER (p_city), '%')
               AND NVL (UPPER (state), '%') LIKE NVL (UPPER (p_state), '%')
               AND account_type_code = 'ORGANIZATION'
               AND site_type = 'BILL_TO';

        RETURN x_location;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;



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
                               x_list_price          OUT NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_price_list_id   NUMBER;
        l_list_price      NUMBER;
        l_proc_name       VARCHAR2 (240) := 'GET_ADJ_DETAILS';
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        msg ('Brand: ' || p_brand);

        ---------------BT Change: 20-Mar-2015
        SELECT user_id
          INTO gn_user_id
          FROM fnd_user
         WHERE user_name = 'BATCH';


        SELECT user_id
          INTO gn_user_id1
          FROM fnd_user
         --  WHERE user_name = 'BBURNS';
         WHERE user_name = 'BRIANB';                        -- Changed for BT.

        SELECT responsibility_id
          INTO gn_resp_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = 'Order Management Super User - US';


        SELECT application_id
          INTO gn_appln_id
          FROM fnd_application_vl
         WHERE application_name = 'Order Management';

        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0

        SELECT COUNT (*)
          INTO g_n_temp
          FROM v$database
         WHERE name = 'PROD';

        ---------------BT Change: 20-Mar-2015


        IF NVL (fnd_global.user_id, -1) = -1
        THEN
            IF g_n_temp = 1 AND NVL (fnd_global.user_id, -1) = -1
            THEN                          -- if it's prod then log in as BATCH
                /*fnd_global.apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);
                fnd_global.initialize(l_buffer_number,1037,50225,20003,0,-1,-1,-1,-1,-1,666,-1);
             */
                --Start BT Change on 20-Mar-2015
                fnd_global.apps_initialize (user_id        => gn_user_id,
                                            resp_id        => gn_resp_id,
                                            resp_appl_id   => gn_appln_id);
            --Start BT Change on 20-Mar-2015
            ELSE                                 -- otherwise log in as BBURNS
                /*      fnd_global.apps_initialize(user_id => 1062,resp_id => 50225,resp_appl_id => 20003);
                      fnd_global.initialize(l_buffer_number,1062,50225,20003,0,-1,-1,-1,-1,-1,666,-1);
                   */
                                              --Start BT Change on 20-Mar-2015
                fnd_global.apps_initialize (user_id        => gn_user_id1,
                                            resp_id        => gn_resp_id,
                                            resp_appl_id   => gn_appln_id);
            --Start BT Change on 20-Mar-2015
            END IF;

            fnd_file.put_names (
                'EDI_UTILS_' || USERENV ('SESSIONID') || '.log',
                'EDI_UTILS_' || USERENV ('SESSIONID') || '.out',
                '/usr/tmp');
        END IF;

        l_price_list_id   := p_price_list_id;
        msg ('Price List ID [' || l_price_list_id || ']');

        BEGIN
            l_list_price   :=
                do_oe_utils.do_get_price_list_value (
                    p_price_list_id            => l_price_list_id,
                    p_inventory_item_id        => sku_to_iid (p_sku),
                    p_use_oracle_pricing_api   => 'Y');

            IF l_list_price IS NULL
            THEN
                msg ('Oracle Standard return <null> trying custom');
                l_list_price   :=
                    do_oe_utils.do_get_price_list_value (
                        p_price_list_id            => l_price_list_id,
                        p_inventory_item_id        => sku_to_iid (p_sku),
                        p_use_oracle_pricing_api   => 'N');
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Exception with oracle API [' || SQLERRM || ']');
                l_list_price   :=
                    do_oe_utils.do_get_price_list_value (
                        p_price_list_id            => l_price_list_id,
                        p_inventory_item_id        => sku_to_iid (p_sku),
                        p_use_oracle_pricing_api   => 'N');
        END;

        x_list_price      := l_list_price;
        msg ('List Price [' || l_list_price || ']');

        IF NVL (l_list_price, 0) = 0
        THEN
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            x_line_type_code   := 'ERROR';
            RETURN;
        END IF;

        x_percentage      :=
            ROUND (ABS (p_unit_price / l_list_price - 1) * 100, 2);
        msg ('Percentage [' || x_percentage || ']');

        IF p_unit_price > l_list_price
        THEN
            SELECT qll.list_header_id, qll.list_line_id, qll.list_line_type_code
              INTO x_list_header_id, x_list_line_id, x_line_type_code
              FROM qp_list_headers qlh, qp_list_headers_b qlhb, qp_list_lines qll
             WHERE     qlh.list_header_id = qlhb.list_header_id
                   AND qll.list_header_id = qlhb.list_header_id
                   AND qlhb.list_type_code = 'SLT'
                   AND qlhb.automatic_flag = 'N'
                   AND TRUNC (SYSDATE) BETWEEN NVL (qlhb.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (qlhb.end_date_active,
                                                    SYSDATE + 1)
                   AND qlhb.active_flag = 'Y'
                   AND qlhb.currency_code = p_currency
                   AND (qlhb.global_flag = 'Y' OR NVL (qlhb.orig_org_id, p_org_id) = p_org_id)
                   AND qll.list_line_type_code = 'SUR'
                   AND qll.modifier_level_code = 'LINE'
                   AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE + 1)
                   AND qll.automatic_flag = 'N'
                   AND qll.override_flag = 'Y'
                   AND NVL (qll.operand, 0) = 0;
        ELSIF p_unit_price < l_list_price
        THEN
            SELECT qll.list_header_id, qll.list_line_id, qll.list_line_type_code
              INTO x_list_header_id, x_list_line_id, x_line_type_code
              FROM qp_list_headers qlh, qp_list_headers_b qlhb, qp_list_lines qll
             WHERE     qlh.list_header_id = qlhb.list_header_id
                   AND qll.list_header_id = qlhb.list_header_id
                   AND qlhb.list_type_code = 'DLT'
                   AND qlhb.automatic_flag = 'N'
                   AND TRUNC (SYSDATE) BETWEEN NVL (qlhb.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (qlhb.end_date_active,
                                                    SYSDATE + 1)
                   AND qlhb.active_flag = 'Y'
                   AND qlhb.currency_code = p_currency
                   AND (qlhb.global_flag = 'Y' OR NVL (qlhb.orig_org_id, p_org_id) = p_org_id)
                   AND qll.list_line_type_code = 'DIS'
                   AND qll.modifier_level_code = 'LINE'
                   AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE + 1)
                   AND qll.automatic_flag = 'N'
                   AND qll.override_flag = 'Y'
                   AND NVL (qll.operand, 0) = 0;
        ELSE
            x_list_header_id   := NULL;
            x_list_line_id     := NULL;
            x_line_type_code   := 'NONE';
        END IF;

        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
    END;



    FUNCTION get_adj_list_header_id (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                     , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_LIST_HEADER_ID';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        get_adj_details (p_brand            => p_brand,
                         p_org_id           => p_org_id,
                         p_currency         => p_currency,
                         p_price_list_id    => p_price_list_id,
                         p_sku              => p_sku,
                         p_unit_price       => p_unit_price,
                         x_list_header_id   => x_list_header_id,
                         x_list_line_id     => x_list_line_id,
                         x_line_type_code   => x_line_type_code,
                         x_percentage       => x_percentage,
                         x_list_price       => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_list_header_id
            || ')');
        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
        RETURN x_list_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_list_line_id (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                   , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_LIST_LINE_ID';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        get_adj_details (p_brand            => p_brand,
                         p_org_id           => p_org_id,
                         p_currency         => p_currency,
                         p_price_list_id    => p_price_list_id,
                         p_sku              => p_sku,
                         p_unit_price       => p_unit_price,
                         x_list_header_id   => x_list_header_id,
                         x_list_line_id     => x_list_line_id,
                         x_line_type_code   => x_line_type_code,
                         x_percentage       => x_percentage,
                         x_list_price       => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_list_line_id
            || ')');
        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
        RETURN x_list_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_line_type_code (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                     , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN VARCHAR2
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_LINE_TYPE_CODE';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        get_adj_details (p_brand            => p_brand,
                         p_org_id           => p_org_id,
                         p_currency         => p_currency,
                         p_price_list_id    => p_price_list_id,
                         p_sku              => p_sku,
                         p_unit_price       => p_unit_price,
                         x_list_header_id   => x_list_header_id,
                         x_list_line_id     => x_list_line_id,
                         x_line_type_code   => x_line_type_code,
                         x_percentage       => x_percentage,
                         x_list_price       => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_line_type_code
            || ')');
        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
        RETURN x_line_type_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_percentage (p_brand IN VARCHAR2, p_org_id IN NUMBER, p_currency IN VARCHAR2
                                 , p_price_list_id IN NUMBER, p_sku IN VARCHAR2, p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_PERCENTAGE';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        get_adj_details (p_brand            => p_brand,
                         p_org_id           => p_org_id,
                         p_currency         => p_currency,
                         p_price_list_id    => p_price_list_id,
                         p_sku              => p_sku,
                         p_unit_price       => p_unit_price,
                         x_list_header_id   => x_list_header_id,
                         x_list_line_id     => x_list_line_id,
                         x_line_type_code   => x_line_type_code,
                         x_percentage       => x_percentage,
                         x_list_price       => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_percentage
            || ')');
        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
        RETURN x_percentage;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_list_price (p_brand           IN VARCHAR2,
                             p_org_id          IN NUMBER,
                             p_currency        IN VARCHAR2,
                             p_price_list_id   IN NUMBER,
                             p_sku             IN VARCHAR2,
                             p_unit_price      IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_LIST_PRICE';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        get_adj_details (p_brand            => p_brand,
                         p_org_id           => p_org_id,
                         p_currency         => p_currency,
                         p_price_list_id    => p_price_list_id,
                         p_sku              => p_sku,
                         p_unit_price       => p_unit_price,
                         x_list_header_id   => x_list_header_id,
                         x_list_line_id     => x_list_line_id,
                         x_line_type_code   => x_line_type_code,
                         x_percentage       => x_percentage,
                         x_list_price       => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_list_price
            || ')');
        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
        RETURN x_list_price;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION adj_required (p_brand           IN VARCHAR2,
                           p_org_id          IN NUMBER,
                           p_currency        IN VARCHAR2,
                           p_price_list_id   IN NUMBER,
                           p_sku             IN VARCHAR2,
                           p_unit_price      IN NUMBER)
        RETURN VARCHAR2
    IS
        l_proc_name        VARCHAR2 (240) := 'ADJ_REQUIRED';
        x_adj              VARCHAR2 (240);
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || G_PKG_NAME || '.' || l_proc_name);
        get_adj_details (p_brand            => p_brand,
                         p_org_id           => p_org_id,
                         p_currency         => p_currency,
                         p_price_list_id    => p_price_list_id,
                         p_sku              => p_sku,
                         p_unit_price       => p_unit_price,
                         x_list_header_id   => x_list_header_id,
                         x_list_line_id     => x_list_line_id,
                         x_line_type_code   => x_line_type_code,
                         x_percentage       => x_percentage,
                         x_list_price       => x_list_price);

        IF NVL (x_line_type_code, 'NONE') = 'NONE'
        THEN
            x_adj   := 'N';
        ELSIF x_line_type_code = 'ERROR'
        THEN
            x_adj   := 'E';
        ELSE
            x_adj   := 'Y';
        END IF;

        msg ('Function ' || l_proc_name || ' returning (' || x_adj || ')');
        msg ('-' || G_PKG_NAME || '.' || l_proc_name);
        RETURN x_adj;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION isDropShipLocation (p_customer_number     IN VARCHAR2,
                                 p_operating_unit_id   IN NUMBER,
                                 p_location_code       IN VARCHAR2,
                                 p_street1             IN VARCHAR2,
                                 p_street2             IN VARCHAR2,
                                 p_city                IN VARCHAR2,
                                 p_state               IN VARCHAR2,
                                 p_country             IN VARCHAR2)
        RETURN VARCHAR2
    IS --BT Change: Infosys - 11-Mar-2014: Changed data type of p_customer_number
        x_flag            VARCHAR2 (1);
        x_address_count   NUMBER;
    BEGIN
        x_flag   := 'N';

        SELECT COUNT (1)
          INTO x_address_count
          FROM XXDO.xxdoint_ar_cust_unified_v
         WHERE     account_number = p_customer_number
               AND operating_unit_id = p_operating_unit_id
               AND TRIM (site_code) = TRIM (p_location_code)
               AND account_type_code = 'ORGANIZATION'
               AND site_type = 'SHIP_TO'
               AND NVL (UPPER (TRIM (address1)), '%') LIKE
                       NVL (UPPER (TRIM (p_street1)), '%')
               AND NVL (UPPER (TRIM (address2)), '%') LIKE
                       NVL (UPPER (TRIM (p_street2)), '%')
               AND NVL (UPPER (TRIM (city)), '%') LIKE
                       NVL (UPPER (TRIM (p_city)), '%')
               -- and nvl(upper(trim(state)),'%') like nvl(upper(trim(p_state)),'%')
               AND ((NVL (UPPER (TRIM (state)), '%') LIKE NVL (UPPER (TRIM (p_state)), '%')) OR (NVL (UPPER (TRIM (province)), '%') LIKE NVL (UPPER (TRIM (p_state)), '%')) OR (NVL (UPPER (TRIM (county)), '%') LIKE NVL (UPPER (TRIM (p_state)), '%')));

        IF x_address_count = 0
        THEN
            x_flag   := 'Y';
        END IF;

        RETURN x_flag;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_OM_ORDER_IMPORT_UTILS TO SOA_INT
/
