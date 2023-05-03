--
-- XXDOEC_ORDER_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_ORDER_UTILS_PKG"
AS
    -- ==============================================================
    -- Author : VIJAY.REDDY
    -- Created : 11/9/2010 9:12:29 AM
    -- Purpose : Validate and return Oracle ID's for DW Order values
    -- Modification History:
    -- ===============================================================================
    -- Date         Ver.#   Name            Comments
    -- ===============================================================================
    -- Jul-12-2017  1.1     Vijay Reddy     JP DW COD related changes - Validate_order_values updated
    -- MAR-06-2018  1.2     Vijay Reddy     FS-CA Changes CCR0006994 - Get and update order ship to address
    -- Apr-23-2018  1.3     Vijay Reddy     Loyalty Rewards CCR0007232 - Added New get discount details procedure
    -- JUN-24-2019  1.4     Vijay Reddy     Added Price list ID parameter to xxdoec_returns_exchanges.create_shipment call
    -- ===============================================================================
    PROCEDURE validate_order_values (p_website_id IN VARCHAR2, p_currency_code IN VARCHAR2, p_salesrep IN VARCHAR2, p_org_id IN NUMBER, p_ordered_date IN DATE, p_back_ordered_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                                 p_pct_amt_discount IN VARCHAR2, -- P - percent, A - amount
                                                                                                                                                                                                                                 p_pre_paid_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                                                                                              x_order_source_id OUT NUMBER, x_salesrep_id OUT NUMBER, x_cancel_date OUT VARCHAR2, x_order_class OUT VARCHAR2, x_order_category OUT VARCHAR2, x_erp_org_id OUT NUMBER, x_inv_org_id OUT NUMBER, x_om_order_type_id OUT NUMBER, x_ar_gl_id_rev OUT NUMBER, x_dflt_price_list_id OUT NUMBER, x_freight_terms_code OUT VARCHAR2, x_fob_point_code OUT VARCHAR2, x_payment_term_id OUT NUMBER, x_kco_header_id OUT NUMBER, x_transaction_user_id OUT NUMBER, x_erp_login_resp_id OUT NUMBER, x_erp_login_app_id OUT NUMBER, x_dis_list_header_id OUT NUMBER, x_dis_list_line_id OUT NUMBER, x_dis_hdr_line_id OUT NUMBER, x_dis_list_line_type_code OUT VARCHAR2, x_chrg_list_header_id OUT NUMBER, x_chrg_list_line_id OUT NUMBER, x_chrg_dis_line_id OUT NUMBER, x_giftwrap_list_line_id OUT NUMBER, x_cod_list_line_id OUT NUMBER, -- JP DW COD related changes
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 x_chrg_list_line_type_code OUT VARCHAR2, x_sur_list_header_id OUT NUMBER
                                     , x_sur_list_line_id OUT NUMBER, x_sur_list_line_type_code OUT VARCHAR2, x_bling_list_line_id OUT NUMBER)
    IS
        CURSOR c_cb_params (c_website_id IN VARCHAR2)
        IS
            SELECT erp_org_id, inv_org_id, om_order_type_id,
                   om_price_list_id, ar_revenue_account_id, transaction_user_id,
                   erp_login_resp_id, erp_login_app_id, brand_name
              FROM xxdoec_country_brand_params dcbp
             WHERE dcbp.website_id = c_website_id;

        CURSOR c_discount_list_ids (c_dis_list_name IN VARCHAR2)
        IS
            SELECT qlh.list_header_id, qll.list_line_id, qll.modifier_level_code,
                   qll.list_line_type_code
              FROM qp_list_headers qlh, qp_list_lines qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_type_code = 'DLT'
                   AND qlh.active_flag = 'Y'
                   AND qll.list_line_type_code = 'DIS'
                   AND qlh.NAME = c_dis_list_name;

        CURSOR c_surcharge_list_ids (c_sur_list_name IN VARCHAR2)
        IS
            SELECT qlh.list_header_id, qll.list_line_id, qll.modifier_level_code,
                   qll.list_line_type_code
              FROM qp_list_headers qlh, qp_list_lines qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_type_code = 'SLT'
                   AND qlh.active_flag = 'Y'
                   AND qll.list_line_type_code = 'SUR'
                   AND qlh.NAME = c_sur_list_name;

        CURSOR c_charge_list_ids (c_chrg_list_name IN VARCHAR2)
        IS
            SELECT qlh.list_header_id, qll.list_line_id, qll.charge_type_code,
                   qll.list_line_type_code
              FROM qp_list_headers qlh, qp_list_lines qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_type_code = 'CHARGES'
                   AND qlh.active_flag = 'Y'
                   AND qll.list_line_type_code = 'FREIGHT_CHARGE'
                   AND qlh.NAME = c_chrg_list_name;

        l_cancel_days   NUMBER;
        l_cancel_date   DATE;
        l_brand_name    VARCHAR2 (40);
    BEGIN
        -- Country, Brand Parameters lookup
        IF p_website_id IS NOT NULL
        THEN
            OPEN c_cb_params (p_website_id);

            FETCH c_cb_params
                INTO x_erp_org_id, x_inv_org_id, x_om_order_type_id, x_dflt_price_list_id,
                     x_ar_gl_id_rev, x_transaction_user_id, x_erp_login_resp_id,
                     x_erp_login_app_id, l_brand_name;

            IF c_cb_params%NOTFOUND
            THEN
                x_erp_org_id            := NULL;
                x_inv_org_id            := NULL;
                x_om_order_type_id      := NULL;
                x_dflt_price_list_id    := NULL;
                x_ar_gl_id_rev          := NULL;
                x_transaction_user_id   := NULL;
                x_erp_login_resp_id     := NULL;
                x_erp_login_app_id      := NULL;
                l_brand_name            := NULL;

                CLOSE c_cb_params;
            ELSE
                CLOSE c_cb_params;
            END IF;
        ELSE
            x_erp_org_id            := NULL;
            x_inv_org_id            := NULL;
            x_om_order_type_id      := NULL;
            x_dflt_price_list_id    := NULL;
            x_ar_gl_id_rev          := NULL;
            x_transaction_user_id   := NULL;
            x_erp_login_resp_id     := NULL;
            x_erp_login_app_id      := NULL;
            l_brand_name            := NULL;
        END IF;

        -- Prepaid order type
        IF p_pre_paid_flag = 'Y'
        THEN
            BEGIN
                SELECT transaction_type_id
                  INTO x_om_order_type_id
                  FROM oe_transaction_types_all ott
                 WHERE     ott.attribute13 = 'PP'
                       AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                       AND NVL (end_date_active, SYSDATE)
                       AND ott.attribute12 = p_website_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_om_order_type_id   := NULL;
            END;
        END IF;

        -- Order Source
        BEGIN
            SELECT order_source_id
              INTO x_order_source_id
              FROM oe_order_sources
             WHERE NAME = 'Flagstaff';
        EXCEPTION
            WHEN OTHERS
            THEN
                x_order_source_id   := NULL;
        END;

        -- Salesrep ID
        IF p_salesrep IS NOT NULL
        THEN
            BEGIN
                SELECT jrs.salesrep_id
                  INTO x_salesrep_id
                  FROM jtf_rs_salesreps jrs, jtf_rs_resource_extns_vl jre
                 WHERE     jrs.resource_id = jre.resource_id
                       AND jrs.org_id = NVL (p_org_id, x_erp_org_id)
                       AND (LOWER (jre.resource_name) = LOWER (p_salesrep) OR LOWER (jrs.salesrep_number) = LOWER (p_salesrep));
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_salesrep_id   := -3;
            END;
        ELSE
            x_salesrep_id   := -3;
        END IF;

        -- Default Price list, freight terms, FOB based on Order Type
        IF x_om_order_type_id IS NOT NULL
        THEN
            BEGIN
                SELECT freight_terms_code, fob_point_code
                  INTO x_freight_terms_code, x_fob_point_code
                  FROM oe_transaction_types_all a
                 WHERE transaction_type_id = x_om_order_type_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_freight_terms_code   := NULL;
                    x_fob_point_code       := NULL;
            END;
        END IF;

        -- Payment Term ID
        BEGIN
            SELECT term_id
              INTO x_payment_term_id
              FROM ra_terms
             WHERE NAME = 'PREPAY';
        EXCEPTION
            WHEN OTHERS
            THEN
                x_payment_term_id   := NULL;
        END;

        -- Cancel Date (Header Attribute1)
        IF NVL (p_back_ordered_flag, 'N') = 'Y'
        THEN
            l_cancel_days   :=
                NVL (TO_NUMBER (fnd_profile.value_specific (
                                    'XXDOEC_PRE_ORDER_CANCEL_THRESHOLD_DAYS',
                                    NULL,
                                    x_erp_login_resp_id,
                                    x_erp_login_app_id,
                                    NULL,
                                    NULL)),
                     90);
        ELSIF p_pre_paid_flag = 'Y'
        THEN
            l_cancel_days   :=
                NVL (TO_NUMBER (fnd_profile.value_specific (
                                    'XXDOEC_CP_LINE_CANCEL_DAYS',
                                    NULL,
                                    x_erp_login_resp_id,
                                    x_erp_login_app_id,
                                    NULL,
                                    NULL)),
                     15);
        ELSE
            l_cancel_days   :=
                NVL (TO_NUMBER (fnd_profile.value_specific (
                                    'XXDOEC_ORDER_CANCEL_THRESHOLD_DAYS',
                                    NULL,
                                    x_erp_login_resp_id,
                                    x_erp_login_app_id,
                                    NULL,
                                    NULL)),
                     5);
        END IF;

        IF p_ordered_date IS NOT NULL
        THEN
            l_cancel_date   := p_ordered_date + l_cancel_days;
            x_cancel_date   := TO_CHAR (l_cancel_date, 'DD-MON-RR');
        ELSE
            x_cancel_date   := NULL;
        END IF;

        -- Order Class (Header Attribute2)
        IF p_ordered_date BETWEEN TRUNC (SYSDATE, 'Year')
                              AND ADD_MONTHS (TRUNC (SYSDATE, 'Year'), 6) - 1
        THEN
            x_order_class   := 'RE-ORDER SPRING';
        ELSIF p_ordered_date BETWEEN ADD_MONTHS (TRUNC (SYSDATE, 'Year'), 6)
                                 AND   ADD_MONTHS (TRUNC (SYSDATE, 'Year'),
                                                   12)
                                     - 1
        THEN
            x_order_class   := 'RE-ORDER FALL';
        ELSE
            x_order_class   := NULL;
        END IF;

        -- Percent Discount List Header, Line IDs
        IF p_currency_code IS NOT NULL
        THEN
            IF p_pct_amt_discount = 'P'
            THEN
                FOR pct_dis_ids IN c_discount_list_ids (g_pct_dis_list_name)
                LOOP
                    x_dis_list_header_id   := pct_dis_ids.list_header_id;
                    x_dis_list_line_type_code   :=
                        pct_dis_ids.list_line_type_code;

                    IF pct_dis_ids.modifier_level_code = 'LINE'
                    THEN
                        x_dis_list_line_id   := pct_dis_ids.list_line_id;
                    ELSIF pct_dis_ids.modifier_level_code = 'LINEGROUP'
                    THEN
                        x_dis_hdr_line_id   := pct_dis_ids.list_line_id;
                    END IF;
                END LOOP;
            END IF;
        ELSE
            x_dis_list_header_id        := NULL;
            x_dis_list_line_type_code   := NULL;
            x_dis_list_line_id          := NULL;
            x_dis_hdr_line_id           := NULL;
        END IF;

        -- Amount Discount List Header, Line IDs
        IF p_currency_code IS NOT NULL
        THEN
            IF p_pct_amt_discount = 'A'
            THEN
                FOR amt_dis_ids IN c_discount_list_ids (g_amt_dis_list_name)
                LOOP
                    x_dis_list_header_id   := amt_dis_ids.list_header_id;
                    x_dis_list_line_type_code   :=
                        amt_dis_ids.list_line_type_code;

                    IF amt_dis_ids.modifier_level_code = 'LINE'
                    THEN
                        x_dis_list_line_id   := amt_dis_ids.list_line_id;
                    ELSIF amt_dis_ids.modifier_level_code = 'LINEGROUP'
                    THEN
                        x_dis_hdr_line_id   := amt_dis_ids.list_line_id;
                    END IF;
                END LOOP;
            END IF;
        ELSE
            x_dis_list_header_id        := NULL;
            x_dis_list_line_type_code   := NULL;
            x_dis_list_line_id          := NULL;
            x_dis_hdr_line_id           := NULL;
        END IF;

        -- Freight Charge List Header, Line IDs
        IF p_currency_code IS NOT NULL
        THEN
            FOR chrg_ids IN c_charge_list_ids (g_freight_charge_name)
            LOOP
                x_chrg_list_header_id        := chrg_ids.list_header_id;
                x_chrg_list_line_type_code   := chrg_ids.list_line_type_code;

                IF chrg_ids.charge_type_code = 'FTECHARGE'
                THEN
                    x_chrg_list_line_id   := chrg_ids.list_line_id;
                ELSIF chrg_ids.charge_type_code = 'FTEDISCOUNT'
                THEN
                    x_chrg_dis_line_id   := chrg_ids.list_line_id;
                ELSIF chrg_ids.charge_type_code = 'GIFTWRAP'
                THEN
                    x_giftwrap_list_line_id   := chrg_ids.list_line_id;
                ELSIF chrg_ids.charge_type_code = 'BLING'
                THEN
                    x_bling_list_line_id   := chrg_ids.list_line_id;
                -- Start JP DW COD related changes
                ELSIF chrg_ids.charge_type_code = 'CODCHARGE'
                THEN
                    x_cod_list_line_id   := chrg_ids.list_line_id;
                -- End JP DW COD related changes
                END IF;
            END LOOP;
        ELSE
            x_chrg_list_header_id        := NULL;
            x_chrg_list_line_type_code   := NULL;
            x_chrg_list_line_id          := NULL;
            x_chrg_dis_line_id           := NULL;
            x_giftwrap_list_line_id      := NULL;
        END IF;

        -- SurCharge List Header, Line IDs
        IF p_currency_code IS NOT NULL
        THEN
            FOR sur_chrg_ids IN c_surcharge_list_ids (g_surcharge_name)
            LOOP
                x_sur_list_header_id        := sur_chrg_ids.list_header_id;
                x_sur_list_line_type_code   :=
                    sur_chrg_ids.list_line_type_code;
                x_sur_list_line_id          := sur_chrg_ids.list_line_id;
            END LOOP;
        ELSE
            x_sur_list_header_id        := NULL;
            x_sur_list_line_type_code   := NULL;
            x_sur_list_line_id          := NULL;
        END IF;

        -- KCO
        BEGIN
            SELECT kco_header_id
              INTO x_kco_header_id
              FROM xxdo.xxdoec_inv_source
             WHERE     inv_org_id = x_inv_org_id
                   AND erp_org_id = x_erp_org_id
                   AND UPPER (brand_name) = UPPER (l_brand_name)
                   AND SYSDATE BETWEEN NVL (start_date, SYSDATE)
                                   AND NVL (end_date, SYSDATE)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_kco_header_id   := NULL;
        END;

        -- Order Category
        x_order_category   := 'R';
    END validate_order_values;

    --
    PROCEDURE validate_upc (p_website_id IN VARCHAR2, p_item_upc IN VARCHAR2, p_inv_org_id IN NUMBER, p_ordered_date IN DATE, p_pre_back_ordered_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                   p_pre_paid_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                                p_sfs_flag IN VARCHAR2 DEFAULT 'N', -- Y/N
                                                                                                                                                                                                                                    x_inventory_item_id OUT NUMBER, x_style OUT VARCHAR2, x_color OUT VARCHAR2, x_size OUT VARCHAR2, x_primary_uom_code OUT VARCHAR2, x_cancel_date OUT VARCHAR2, x_line_type_id OUT NUMBER, x_inv_org_id OUT NUMBER
                            , x_shipping_method_code OUT VARCHAR2)
    IS
        CURSOR c_cb_params IS
            SELECT erp_login_resp_id, erp_login_app_id, virtual_inv_org_id,
                   erp_org_id
              FROM xxdoec_country_brand_params dcbp
             WHERE dcbp.website_id = p_website_id;

        --
        CURSOR c_line_type (c_item_id IN NUMBER)
        IS
            SELECT ott.transaction_type_id
              FROM apps.fnd_lookup_values_vl flv, apps.oe_transaction_types_tl ott, -------------------------------------------
                                                                                    -- Code Change By Sivakumar Boothathan
                                                                                    -- Commented for XXD and uncommented
                                                                                    -- mtl_system_items_b
                                                                                    -----------------------------------------
                                                                                    apps.mtl_system_items_b msi --commented by BT TEchnology Team on 11/10/2014
                                                                                                               --apps.xxd_common_items_v msi             --Added by BT TEchnology Team on 11/10/2014
                                                                                                               ,
                   apps.mtl_parameters mtp
             WHERE     flv.lookup_type = 'XXDO_GCARD_LINE_TYPE'
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND ott.NAME = flv.description
                   AND ott.LANGUAGE = 'US'
                   AND flv.lookup_code = msi.segment1
                   -- msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3                        --commented by BT TEchnology Team on 11/10/2014
                   --msi.style_number ||  '-' ||msi.color_code  ||  '-'  ||msi.item_size               --Added by BT TEchnology Team on 11/10/2014
                   ----------------------------------------------------------
                   -- Changes By Sivakumar Boothathan For V1.7
                   ----------------------------------------------------------
                   AND msi.organization_id = mtp.organization_id
                   AND mtp.organization_id = mtp.master_organization_id
                   ---------------------------------------------------------
                   -- End Of changes By Sivakumar Boothatan V 1.7
                   ---------------------------------------------------------
                   -- AND msi.organization_id =7                                 -- commented by BT Technology team on 11/10/2014
                   --------------------------------------------------------
                   -- Commented By Sivakumar Boothathan for V1.7
                   ------------------------------------------------------
                   --AND msi.organization_id IN ( select ood.ORGANIZATION_ID
                   --from fnd_lookup_values flv,
                   --org_organization_definitions ood
                   --where lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   --and lookup_code =7
                   --and flv.attribute1 = ood.ORGANIZATION_CODE
                   --and language = userenv('LANG'))                                   ---Added by BT Technology Team on 11/10/2014
                   -------------------------------------------------------
                   -- End of commenting By Sivakumar Boothathan
                   -------------------------------------------------------
                   AND msi.inventory_item_id = c_item_id;

        --
        CURSOR c_item_cat (c_item_id IN NUMBER)
        IS
            -----------------------------------
            -- Begin changes to this cursor
            -- to remove XXD_COMMON_ITEMS_V
            -- AND add mtl_item_categories
            ----------------------------------
            /*SELECT mc.segment4
              FROM apps.mtl_item_categories mic,
              apps.mtl_categories mc*/
            --SELECT msi.master_class
            --FROM xxd_common_items_v msi,
            SELECT mcb.attribute7
              FROM apps.mtl_item_categories mic, apps.mtl_categories_b mcb, apps.mtl_parameters mtp
             WHERE     mic.inventory_item_id = c_item_id
                   AND mic.category_id = mcb.category_id
                   AND mic.organization_id = mtp.organization_id
                   AND mtp.organization_id = mtp.master_organization_id
                   AND mic.category_set_id = 1;

        -- AND mic.organization_id = 7                                          ---commented by BT Technology Team on 11/10/2014
        ------------------------------------------
        -- Commenting By Sivakumar Boothathan
        -- For Performance tuning
        -- V1.7
        ------------------------------------------
        --AND msi.organization_id IN ( select ood.ORGANIZATION_ID
        --from fnd_lookup_values flv,
        --org_organization_definitions ood
        --where lookup_type = 'XXD_1206_INV_ORG_MAPPING'
        --and lookup_code =7
        --and flv.attribute1 = ood.ORGANIZATION_CODE
        --and language = userenv('LANG'));                                          --Added by BT Technology Team On11/10/2014
        --AND mic.category_id = mc.category_id
        --AND mc.structure_id = 101;                              --commented by BT Technology Team on 11/10/2014
        ---------------------------------------------
        -- End of changes By Sivakumar Bootahthan
        ----------------------------------------------

        l_cancel_days     NUMBER;
        l_cancel_date     DATE;
        l_item_category   VARCHAR2 (120);
    BEGIN
        -- Item UPC
        IF p_item_upc IS NOT NULL
        THEN
            BEGIN
                SELECT upc_to_iid (p_item_upc)
                  INTO x_inventory_item_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_inventory_item_id   := NULL;
            END;
        END IF;

        -- Item Primary UOM
        IF x_inventory_item_id IS NOT NULL
        THEN
            BEGIN
                -- SELECT msi.primary_uom_code, msi.segment1, msi.segment2,                                 ----commented by BT TEchnology Team on 11/10/2014
                -- msi.segment3                                                                    --commented by BT TEchnology Team on 11/10/2014
                SELECT msi.primary_uom_code, msi.style_number, msi.color_code,
                       msi.item_size --ADDED by BT TEchnology Team on 11/10/2014
                  INTO x_primary_uom_code, x_style, x_color, x_size
                  --FROM mtl_system_items_b msi                                                 ---- commented by BT TEchnology team on 11/10/2014
                  FROM xxd_common_items_v msi, apps.mtl_parameters mtp -- Added by BT TEchnology team on 11/10/2014
                 WHERE     inventory_item_id = x_inventory_item_id
                       AND mtp.master_organization_id = mtp.organization_id
                       -- AND organization_id = NVL (p_inv_org_id, 7);                                 -- commented by BT TEchnology team on 11/10/2014
                       AND msi.organization_id =
                           NVL (p_inv_org_id, mtp.master_organization_id); -- Added by BT Technology Team on 11/10/2014
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_primary_uom_code   := NULL;
                    x_style              := NULL;
                    x_color              := NULL;
                    x_size               := NULL;
            END;

            l_item_category   := NULL;

            -- Card Items Shipping Method Code
            OPEN c_item_cat (x_inventory_item_id);

            FETCH c_item_cat INTO l_item_category;

            CLOSE c_item_cat;

            IF l_item_category = 'VIRCARD'
            THEN
                x_shipping_method_code   := 'VCRD';
            ELSE
                x_shipping_method_code   := NULL;
            END IF;

            --
            IF     p_pre_paid_flag = 'Y'
               AND x_color <> 'CUSTOM'
               AND x_shipping_method_code IS NULL
            THEN
                x_shipping_method_code   := 'U12';
            END IF;

            -- Card Items Line Type
            OPEN c_line_type (x_inventory_item_id);

            FETCH c_line_type INTO x_line_type_id;

            IF c_line_type%NOTFOUND
            THEN
                CLOSE c_line_type;

                x_line_type_id   := NULL;
            ELSE
                CLOSE c_line_type;
            END IF;

            -- Card Items Warehouse ID
            IF x_line_type_id IS NOT NULL
            THEN
                BEGIN
                    SELECT warehouse_id
                      INTO x_inv_org_id
                      FROM oe_transaction_types_all
                     WHERE transaction_type_id = x_line_type_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_inv_org_id   := NULL;
                END;
            ELSE
                x_inv_org_id   := NULL;
            END IF;
        END IF;

        --
        FOR c_cbp IN c_cb_params
        LOOP
            -- Customized products warehouse ID
            IF x_color = 'CUSTOM'
            THEN
                x_inv_org_id   := c_cbp.virtual_inv_org_id;
            END IF;

            -- SFS Line Type I D
            IF NVL (p_sfs_flag, 'N') = 'Y'
            THEN
                BEGIN
                    SELECT transaction_type_id
                      INTO x_line_type_id
                      FROM oe_transaction_types_all
                     WHERE     transaction_type_code = 'LINE'
                           AND org_id = c_cbp.erp_org_id
                           AND attribute15 = 'SFS';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_line_type_id   := NULL;
                END;
            END IF;

            -- Cancel Date (Line Attribute1)
            IF NVL (p_pre_back_ordered_flag, 'N') = 'Y'
            THEN
                l_cancel_days   :=
                    NVL (TO_NUMBER (fnd_profile.value_specific (
                                        'XXDOEC_PRE_ORDER_CANCEL_THRESHOLD_DAYS',
                                        NULL,
                                        c_cbp.erp_login_resp_id,
                                        c_cbp.erp_login_app_id,
                                        NULL,
                                        NULL)),
                         90);
            ELSIF x_color = 'CUSTOM'
            THEN
                l_cancel_days   :=
                    NVL (TO_NUMBER (fnd_profile.value_specific (
                                        'XXDOEC_CP_LINE_CANCEL_DAYS',
                                        NULL,
                                        c_cbp.erp_login_resp_id,
                                        c_cbp.erp_login_app_id,
                                        NULL,
                                        NULL)),
                         15);
            ELSE
                l_cancel_days   :=
                    NVL (TO_NUMBER (fnd_profile.value_specific (
                                        'XXDOEC_ORDER_CANCEL_THRESHOLD_DAYS',
                                        NULL,
                                        c_cbp.erp_login_resp_id,
                                        c_cbp.erp_login_app_id,
                                        NULL,
                                        NULL)),
                         5);
            END IF;

            --
            IF p_ordered_date IS NOT NULL
            THEN
                l_cancel_date   := p_ordered_date + l_cancel_days;
                x_cancel_date   := TO_CHAR (l_cancel_date, 'DD-MON-RR');
            ELSE
                x_cancel_date   := NULL;
            END IF;
        END LOOP;
    END validate_upc;

    -- *********************************************
    PROCEDURE validate_sku (p_website_id IN VARCHAR2, p_sku IN VARCHAR2, p_inv_org_id IN NUMBER, p_ordered_date IN DATE, p_pre_back_ordered_flag IN VARCHAR2, -- Y/N
                                                                                                                                                              p_pre_paid_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                           p_sfs_flag IN VARCHAR2 DEFAULT 'N', -- Y/N
                                                                                                                                                                                                                               x_inventory_item_id OUT NUMBER, x_style OUT VARCHAR2, x_color OUT VARCHAR2, x_size OUT VARCHAR2, x_primary_uom_code OUT VARCHAR2, x_cancel_date OUT VARCHAR2, x_line_type_id OUT NUMBER, x_inv_org_id OUT NUMBER
                            , x_shipping_method_code OUT VARCHAR2)
    IS
        CURSOR c_item_upc IS
            SELECT msi.attribute11
              FROM mtl_system_items_kfv msi, apps.mtl_parameters mtp
             --WHERE organization_id = 7 --commented by BT Technology Team on 2014/11/05
             -------------------------------------------------------
             -- Commenting Changes For V1.7 By Sivakumar Boothathan
             ------------------------------------------------------
             --WHERE msi.organization_id IN ( select ood.ORGANIZATION_ID
             --from fnd_lookup_values flv,
             --org_organization_definitions ood
             --where lookup_type = 'XXD_1206_INV_ORG_MAPPING'--
             --and lookup_code =7
             --and flv.attribute1 = ood.ORGANIZATION_CODE
             --and language = userenv('LANG'))  ---Added by BT Technology Team on 2014/11/05
             --------------------------------------------------------
             -- End of commenting By Sivakumar Boothathan for V1.7
             --------------------------------------------------------
             -----------------------------------------------------
             -- Start of code change By Sivakumar Boothathan V1.7
             -----------------------------------------------------
             WHERE     mtp.organization_id = msi.organization_id
                   AND mtp.organization_id = mtp.master_organization_id
                   ---------------------------------------------------------
                   -- end of code change By Sivakumar boothathan V1.7
                   ---------------------------------------------------------
                   AND concatenated_segments = p_sku;

        l_item_upc   VARCHAR2 (120);
    BEGIN
        l_item_upc   := NULL;

        OPEN c_item_upc;

        FETCH c_item_upc INTO l_item_upc;

        CLOSE c_item_upc;

        validate_upc (p_website_id => p_website_id, p_item_upc => l_item_upc, p_inv_org_id => p_inv_org_id, p_ordered_date => p_ordered_date, p_pre_back_ordered_flag => p_pre_back_ordered_flag, p_pre_paid_flag => p_pre_paid_flag, p_sfs_flag => p_sfs_flag, x_inventory_item_id => x_inventory_item_id, x_style => x_style, x_color => x_color, x_size => x_size, x_primary_uom_code => x_primary_uom_code, x_cancel_date => x_cancel_date, x_line_type_id => x_line_type_id, x_inv_org_id => x_inv_org_id
                      , x_shipping_method_code => x_shipping_method_code);
    END validate_sku;

    -- Loyalty Rewards CCR0007232 start

    PROCEDURE get_discounts_details (
        x_discounts_tbl OUT t_discount_detail_cursor)
    IS
    BEGIN
        OPEN x_discounts_tbl FOR
            SELECT qlh.name, qlh.list_header_id, qll.list_line_id,
                   qll.list_line_type_code, qll.arithmetic_operator
              FROM qp_list_headers qlh, qp_list_lines qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_type_code = 'DLT'
                   AND qlh.active_flag = 'Y'
                   AND qll.list_line_type_code = 'DIS'
                   AND qll.modifier_level_code = 'LINE'
                   AND qlh.attribute4 = 'Y';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_discounts_tbl   := NULL;
    END get_discounts_details;

    -- Loyalty Rewards CCR0007232 end
    PROCEDURE get_ca_cust_number (p_website_id IN VARCHAR2, p_email_address IN VARCHAR2, x_customer_number OUT VARCHAR2)
    IS
        CURSOR c_cust_number IS
            SELECT hca.account_number
              FROM apps.hz_contact_points hcp, apps.hz_cust_accounts hca
             WHERE     hcp.owner_table_name = 'HZ_PARTIES'
                   AND hcp.contact_point_type = 'EMAIL'
                   AND hcp.status = 'A'
                   AND hcp.primary_flag = 'Y'
                   AND UPPER (hcp.email_address) = UPPER (p_email_address)
                   AND hca.party_id = hcp.owner_table_id
                   AND hca.attribute18 = p_website_id;
    BEGIN
        OPEN c_cust_number;

        FETCH c_cust_number INTO x_customer_number;

        IF c_cust_number%NOTFOUND
        THEN
            CLOSE c_cust_number;

            SELECT TO_CHAR (xxdoec_seq_rtrn_cust_num.NEXTVAL)
              INTO x_customer_number
              FROM DUAL;
        ELSE
            CLOSE c_cust_number;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_customer_number   := NULL;
    END get_ca_cust_number;

    --
    PROCEDURE get_order_ship_to_address (p_cust_po_number IN VARCHAR2, x_customer_number OUT VARCHAR2, x_address1 OUT VARCHAR2, x_address2 OUT VARCHAR2, x_address3 OUT VARCHAR2, x_city OUT VARCHAR2, x_state OUT VARCHAR2, x_county OUT VARCHAR2, x_postal_code OUT VARCHAR2
                                         , x_country OUT VARCHAR2, x_rtn_status OUT VARCHAR2, x_rtn_msg OUT VARCHAR2)
    IS
        CURSOR c_order_ship_to IS
            SELECT hca.account_number, hl.address1, hl.address2,
                   hl.address3, hl.city, hl.state,
                   hl.province, hl.county, hl.postal_code,
                   hl.country
              FROM oe_order_headers_all ooh, hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas,
                   hz_cust_accounts hca, hz_party_sites hps, hz_locations hl
             WHERE     ooh.cust_po_number = p_cust_po_number
                   AND hcsu.site_use_id = ooh.ship_to_org_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hps.party_site_id = hcas.party_site_id
                   AND hl.location_id = hps.location_id;

        l_address_rec   c_order_ship_to%ROWTYPE;
    BEGIN
        OPEN c_order_ship_to;

        FETCH c_order_ship_to INTO l_address_rec;

        IF c_order_ship_to%FOUND
        THEN
            CLOSE c_order_ship_to;

            x_customer_number   := l_address_rec.account_number;
            x_address1          := l_address_rec.address1;
            x_address2          := l_address_rec.address2;
            x_address3          := l_address_rec.address3;
            x_city              := l_address_rec.city;
            x_state             := l_address_rec.state;
            x_county            := l_address_rec.county;
            x_postal_code       := l_address_rec.postal_code;
            x_country           := l_address_rec.country;

            -- SFS-CA changes start
            IF x_country = 'CA'
            THEN
                x_state   := l_address_rec.province;
            END IF;
        -- SFS-CA changes End
        ELSE
            CLOSE c_order_ship_to;
        END IF;
    END get_order_ship_to_address;

    PROCEDURE update_order_ship_to_address (
        p_cust_po_number   IN     VARCHAR2,
        p_address1         IN     VARCHAR2,
        p_address2         IN     VARCHAR2,
        p_address3         IN     VARCHAR2,
        p_city             IN     VARCHAR2,
        p_state            IN     VARCHAR2,
        p_county           IN     VARCHAR2,
        p_postal_code      IN     VARCHAR2,
        p_country          IN     VARCHAR2,
        x_rtn_status          OUT VARCHAR2,
        x_rtn_msg             OUT VARCHAR2)
    IS
        CURSOR c_loc_id IS
            SELECT hl.location_id, hl.object_version_number
              FROM oe_order_headers_all ooh, hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas,
                   hz_party_sites hps, hz_locations hl
             WHERE     ooh.cust_po_number = p_cust_po_number
                   AND hcsu.site_use_id = ooh.ship_to_org_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hps.party_site_id = hcas.party_site_id
                   AND hl.location_id = hps.location_id;

        l_location_id             NUMBER;
        l_location_rec            hz_location_v2pub.location_rec_type;
        l_object_version_number   NUMBER;
        --
        l_user_id                 NUMBER;
        l_responsibility_id       NUMBER;
        l_application_id          NUMBER;
        --
        x_return_status           VARCHAR2 (2000);
        x_msg_count               NUMBER;
        x_msg_data                VARCHAR2 (2000);
    BEGIN
        -- Fetch Location ID to update
        OPEN c_loc_id;

        FETCH c_loc_id INTO l_location_id, l_object_version_number;

        IF c_loc_id%NOTFOUND
        THEN
            CLOSE c_loc_id;

            x_rtn_status   := FND_API.G_RET_STS_ERROR;
            x_rtn_msg      :=
                   'Invalid Order Number to update the ship to Address. customer PO Number: '
                || p_cust_po_number;
        ELSE
            CLOSE c_loc_id;

            -- Initializing the API parameters
            l_location_rec.location_id   := l_location_id;
            l_location_rec.address1      := p_address1;
            l_location_rec.address2      := p_address2;
            l_location_rec.address3      := p_address3;
            l_location_rec.city          := p_city;
            l_location_rec.state         := p_state;
            l_location_rec.county        := p_county;
            l_location_rec.postal_code   := p_postal_code;
            l_location_rec.country       := p_country;

            -- SFS-CA changes start
            IF p_country = 'CA'
            THEN
                l_location_rec.province   := p_state;
                l_location_rec.state      := NULL;
            END IF;

            -- SFS-CA changes end
            hz_location_v2pub.update_location (
                p_init_msg_list           => fnd_api.g_true,
                p_location_rec            => l_location_rec,
                p_object_version_number   => l_object_version_number,
                x_return_status           => x_return_status,
                x_msg_count               => x_msg_count,
                x_msg_data                => x_msg_data);

            IF x_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
            ELSE
                DBMS_OUTPUT.put_line (
                    'Updation of Location failed: ' || x_msg_data);
                ROLLBACK;

                FOR i IN 1 .. x_msg_count
                LOOP
                    x_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                    DBMS_OUTPUT.put_line (i || ') ' || x_msg_data);
                END LOOP;

                x_rtn_status   := FND_API.G_RET_STS_ERROR;
                x_rtn_msg      :=
                       'Failed to update the ship to Address for : '
                    || p_cust_po_number
                    || ' -  Error:  '
                    || x_msg_data;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_rtn_msg      :=
                   'Un handled exception for : '
                || p_cust_po_number
                || ' - Error: '
                || SUBSTR (SQLERRM, 1, 250);
            DBMS_OUTPUT.put_line (
                   'Un handled exception for : '
                || p_cust_po_number
                || ' - Error: '
                || SUBSTR (SQLERRM, 1, 250));
    END update_order_ship_to_address;

    --

    PROCEDURE cancel_unscheduled_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_wait_days IN NUMBER DEFAULT 10
                                        , p_no_of_lines IN NUMBER DEFAULT 1000, p_inv_item IN VARCHAR2, p_cust_po_number IN VARCHAR2)
    IS
        CURSOR c_unscheduled_lines IS
            SELECT ool.line_id, ool.cust_po_number, ool.ordered_item
              FROM apps.oe_order_lines ool, apps.oe_order_headers ooh
             WHERE     ool.header_id = ooh.header_id
                   AND ool.line_category_code = 'ORDER'
                   AND schedule_ship_date IS NULL
                   AND ool.cancelled_flag = 'N'
                   AND ool.attribute20 = 'SCH'
                   AND ool.attribute17 = 'N'
                   AND ooh.ordered_date >= SYSDATE - 15
                   AND SYSDATE - ooh.ordered_date >= p_wait_days
                   AND ool.latest_acceptable_date - ool.request_date <= 30
                   AND ool.ordered_item = NVL (p_inv_item, ool.ordered_item)
                   AND ool.cust_po_number =
                       NVL (p_cust_po_number, ool.cust_po_number)
                   AND ROWNUM <= p_no_of_lines;

        l_rtn_status   VARCHAR2 (1);
        l_rtn_msg      VARCHAR2 (2000);
    BEGIN
        FOR c1 IN c_unscheduled_lines
        LOOP
            l_rtn_status   := FND_API.G_RET_STS_SUCCESS;
            l_rtn_msg      := NULL;

            BEGIN
                xxdoec_process_order_lines.cancel_line (
                    p_line_id        => c1.line_id,
                    p_reason_code    => 'SCH',
                    x_rtn_status     => l_rtn_status,
                    x_rtn_msg_data   => l_rtn_msg);

                IF l_rtn_status = fnd_api.G_RET_STS_SUCCESS
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to Cancel PO# ' || c1.cust_po_number);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Msg: ' || l_rtn_msg);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := -1;
                    x_errbuf    :=
                        'Failed to Cancel some PO#s...Please check concurrent program log files';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to Cancel PO# ' || c1.cust_po_number);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Msg: ' || SQLERRM);
            END;
        END LOOP;
    END Cancel_unscheduled_lines;

    --
    PROCEDURE create_sfs_line (p_order_line_id IN NUMBER, x_order_line_id OUT NUMBER, x_rtn_status OUT VARCHAR2
                               , x_error_msg OUT VARCHAR2)
    IS
        CURSOR c_sfs_order_lines IS
            SELECT ool.*
              FROM apps.oe_order_lines_all ool
             WHERE ool.line_id = p_order_line_id AND ool.cancelled_flag = 'Y';

        CURSOR c_item_upc (c_item_id IN NUMBER, c_org_id IN NUMBER)
        IS
            SELECT attribute11
              FROM mtl_system_items_b
             WHERE     inventory_item_id = c_item_id
                   AND organization_id = c_org_id;

        CURSOR c_order_type (c_hdr_id IN NUMBER)
        IS
            SELECT ott.attribute13
              FROM apps.oe_order_headers_all ooh, apps.oe_transaction_types_all ott
             WHERE     ott.transaction_type_id = ooh.order_type_id
                   AND ooh.header_id = c_hdr_id;

        CURSOR c_tax_rate IS
            SELECT zrb.percentage_rate
              FROM oe_price_adjustments opa, zx_rates_b zrb
             WHERE     opa.line_id = p_order_line_id
                   AND list_line_type_code = 'TAX'
                   AND zrb.tax_rate_id = opa.tax_rate_id;

        l_item_upc        VARCHAR2 (100);
        l_do_order_type   VARCHAR2 (100);
        l_tax_rate        NUMBER;
        l_tax_value       NUMBER;

        x_order_number    NUMBER;
    BEGIN
        FOR c1 IN c_sfs_order_lines
        LOOP
            l_item_upc        := NULL;
            l_do_order_type   := NULL;
            l_tax_value       := NULL;
            x_error_msg       := NULL;
            x_rtn_status      := fnd_api.G_RET_STS_SUCCESS;

            OPEN c_item_upc (c1.inventory_item_id, c1.ship_from_org_id);

            FETCH c_item_upc INTO l_item_upc;

            CLOSE c_item_upc;

            OPEN c_order_type (c1.header_id);

            FETCH c_order_type INTO l_do_order_type;

            CLOSE c_order_type;

            OPEN c_tax_rate;

            FETCH c_tax_rate INTO l_tax_rate;

            CLOSE c_tax_rate;

            l_tax_value       :=
                  c1.unit_list_price
                * c1.cancelled_quantity
                * (l_tax_rate / 100);

            xxdoec_returns_exchanges_pkg.create_shipment (
                p_customer_id             => c1.sold_to_org_id,
                p_bill_to_site_use_id     => c1.invoice_to_org_id,
                p_ship_to_site_use_id     => c1.ship_to_org_id,
                p_requested_item_upc      => l_item_upc,
                p_ordered_quantity        => c1.cancelled_quantity,
                p_ship_from_org_id        => NULL,
                p_ship_method_code        => c1.shipping_method_code,
                p_price_list_id           => NULL,               -- CCR0008008
                p_unit_list_price         => c1.unit_list_price,
                p_unit_selling_price      => c1.unit_selling_price,
                p_tax_code                => c1.tax_code,
                p_tax_date                => c1.tax_date,
                p_tax_value               => l_tax_value,
                p_sfs_flag                => 'Y',
                p_fluid_recipe_id         => NULL,
                p_order_type              => l_do_order_type,
                p_orig_sys_document_ref   => NULL,
                p_order_header_id         => c1.header_id,
                x_order_line_id           => x_order_line_id,
                x_order_number            => x_order_number,
                x_rtn_status              => x_rtn_status,
                x_error_msg               => x_error_msg);
        --dbms_output.put_line ('Return Status: ' ||   x_rtn_status);
        --dbms_output.put_line ('Error Message: ' || x_error_msg);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    -- DBMS_OUTPUT.put_line ('Error Msg: ' || SQLERRM);
    END create_sfs_line;

    --
    PROCEDURE open_order_lines_count (
        p_web_order_numbers   IN     t_order_list,
        o_order_lines_count      OUT t_order_lines_count)
    IS
        l_web_order_counts   xxdoec_dw_order_list := xxdoec_dw_order_list ();
    BEGIN
        l_web_order_counts.EXTEND (p_web_order_numbers.COUNT);

        FOR i IN p_web_order_numbers.FIRST .. p_web_order_numbers.LAST
        LOOP
            l_web_order_counts (i)   := p_web_order_numbers (i);
        END LOOP;

        OPEN o_order_lines_count FOR
            SELECT ooh.orig_sys_document_ref AS order_number,
                   (SELECT COUNT (*)
                      FROM apps.oe_order_lines_all ool
                     WHERE     ool.open_flag = 'Y'
                           AND ool.header_id = ooh.header_id) linecount
              FROM TABLE (l_web_order_counts) ords
                   JOIN apps.oe_order_headers_all ooh
                       ON ooh.orig_sys_document_ref = ords.COLUMN_VALUE
             --WHERE ooh.order_source_id = 1044;       --commented by BT Technology Team on 2104/11/05
             WHERE ooh.order_source_id IN (SELECT ORDER_SOURCE_ID
                                             FROM oe_order_sources
                                            WHERE name = 'Flagstaff'); -- Added by BT Technology team on 2014/11/05
    EXCEPTION
        WHEN OTHERS
        THEN
            o_order_lines_count   := NULL;
    END open_order_lines_count;

    --
    FUNCTION get_orig_order (p_order_header_id IN NUMBER, p_rtn_status OUT VARCHAR2, p_rtn_message OUT VARCHAR2)
        RETURN VARCHAR2
    AS
        l_do_order_type        VARCHAR2 (10);
        l_orig_order_id        NUMBER;
        l_next_orig_order_id   NUMBER;
        l_orig_order           VARCHAR2 (120);

        CURSOR c_do_order_type (c_header_id IN NUMBER)
        IS
            SELECT ott.attribute13 do_order_type
              FROM oe_transaction_types_all ott, oe_order_headers_all ooh
             WHERE     ott.transaction_type_id = ooh.order_type_id
                   AND ooh.header_id = c_header_id;

        CURSOR c_orig_order_id (c_header_id IN NUMBER)
        IS
            SELECT reference_header_id
              FROM oe_order_lines_all ool
             WHERE     ool.header_id = c_header_id
                   AND ool.line_category_code = 'RETURN';

        CURSOR c_cust_po_number (c_orig_header_id IN NUMBER)
        IS
            SELECT cust_po_number
              FROM oe_order_headers_all ooh
             WHERE ooh.header_id = c_orig_header_id;
    BEGIN
        p_rtn_status      := fnd_api.g_ret_sts_success;

        OPEN c_do_order_type (p_order_header_id);

        FETCH c_do_order_type INTO l_do_order_type;

        CLOSE c_do_order_type;

        l_orig_order_id   := p_order_header_id;

        IF NVL (l_do_order_type, '~') IN ('EE', 'ER', 'CR',
                                          'CE', 'PE')
        THEN
            WHILE l_orig_order_id IS NOT NULL
            LOOP
                OPEN c_orig_order_id (l_orig_order_id);

                FETCH c_orig_order_id INTO l_next_orig_order_id;

                IF c_orig_order_id%NOTFOUND
                THEN
                    CLOSE c_orig_order_id;

                    EXIT;
                ELSE
                    CLOSE c_orig_order_id;

                    IF l_next_orig_order_id IS NULL
                    THEN
                        EXIT;
                    ELSE
                        l_orig_order_id   := l_next_orig_order_id;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        --
        OPEN c_cust_po_number (l_orig_order_id);

        FETCH c_cust_po_number INTO l_orig_order;

        CLOSE c_cust_po_number;

        --
        RETURN (l_orig_order);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_rtn_status    := fnd_api.g_ret_sts_unexp_error;
            p_rtn_message   := SQLERRM;
    END get_orig_order;

    PROCEDURE get_db_apps_values (x_user_id   OUT NUMBER,
                                  x_org_id    OUT NUMBER,
                                  x_resp_id   OUT NUMBER)
    IS
    BEGIN
        SELECT apps.fnd_global.user_id, apps.fnd_global.org_id, apps.fnd_global.resp_id
          INTO x_user_id, x_org_id, x_resp_id
          FROM DUAL;
    END;

    PROCEDURE get_orig_order_type (p_order_cust_po_num IN VARCHAR2, x_original_order_type OUT VARCHAR2, x_rtn_status OUT VARCHAR2
                                   , x_rtn_message OUT VARCHAR2)
    IS
    BEGIN
        SELECT DISTINCT oott.attribute13
          INTO x_original_order_type
          FROM apps.oe_order_lines_all oola
               JOIN apps.oe_order_headers_all ooha
                   ON oola.header_id = ooha.header_id
               JOIN apps.oe_transaction_types_all oott
                   ON ooha.order_type_id = oott.transaction_type_id
         WHERE     oola.cust_po_number = p_order_cust_po_num
               --AND oola.order_source_id IN (1044);                                          --commented by BT Technology Team on 11/10/2014
               AND oola.order_source_id IN (SELECT ORDER_SOURCE_ID
                                              FROM oe_order_sources
                                             WHERE name = 'Flagstaff'); --Added by Bt Technology Team on 11/10/2014
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status    := fnd_api.g_ret_sts_unexp_error;
            x_rtn_message   := SQLERRM;
    END get_orig_order_type;

    PROCEDURE check_cp_shipped (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_tmplt_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                , p_result OUT NOCOPY NUMBER)
    IS
        l_line_id                NUMBER := oe_line_security.g_record.line_id;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_shipment_id            NUMBER;
    BEGIN
        p_result   := 0;

        IF NVL (l_line_id, fnd_api.g_miss_num) = fnd_api.g_miss_num
        THEN
            RETURN;
        END IF;

        SELECT shipment_id
          INTO l_shipment_id
          FROM xxdoec_cp_shipment_dtls_stg csd, oe_order_lines_all ool
         WHERE     csd.order_id = ool.cust_po_number
               AND csd.fluid_recipe_id = ool.customer_job
               AND ool.line_id = l_line_id;

        IF l_shipment_id IS NOT NULL
        THEN
            p_result   := 1;
        ELSE
            p_result   := 0;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_result   := 0;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('No Data Found in Check_CP_Shipped', 4);
            END IF;
        WHEN OTHERS
        THEN
            p_result   := 1;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('When Others in Check_CP_Shipped', 4);
            END IF;
    END check_cp_shipped;

    PROCEDURE get_sku_from_upc (p_upc       IN     VARCHAR2,
                                p_inv_org   IN     NUMBER,
                                x_sku          OUT VARCHAR2)
    IS
        CURSOR c_item_sku (c_item_id IN NUMBER)
        IS
            SELECT msi.concatenated_segments
              FROM mtl_system_items_kfv msi, apps.mtl_parameters mtp
             WHERE     msi.inventory_item_id = c_item_id
                   AND mtp.organization_id = mtp.master_organization_id
                   AND msi.organization_id =
                       NVL (p_inv_org, mtp.master_organization_id);

        --AND msi.organization_id IN (p_inv_org, 7)                         --commented by BT Technlogy team on 11/10/2014
        -------------------------------------------------------
        -- Changes By Sivakumar Boothathan for V1.7
        -------------------------------------------------------
        --AND msi.organization_id IN (p_inv_org,( select ood.ORGANIZATION_ID
        --from fnd_lookup_values flv,
        --org_organization_definitions ood
        --where lookup_type = 'XXD_1206_INV_ORG_MAPPING'
        --and lookup_code =7
        --and flv.attribute1 = ood.ORGANIZATION_CODE
        --and language = userenv('LANG')))                            --Added by BT Technology Team on 11/10/2014
        ------------------------------------------------------
        -- End of changes By Sivakumar Boothathan for V1.7
        ------------------------------------------------------
        ------------------------------------------------------------
        --  Beginning of new changes By Sivakumar Boothathan V1.7
        ------------------------------------------------------------
        --and msi.organization_id in (p_inv_org,(select master_organization_id
        --from apps.mtl_parameters
        --where organization_id = master_organization_id));
        ---------------------------------------------
        -- COmmenting the ROWNUM = 1
        ----------------------------------------------
        --AND ROWNUM = 1;

        l_item_id   NUMBER;
    BEGIN
        SELECT upc_to_iid (p_upc) INTO l_item_id FROM DUAL;

        OPEN c_item_sku (l_item_id);

        FETCH c_item_sku INTO x_sku;

        CLOSE c_item_sku;
    END get_sku_from_upc;

    PROCEDURE get_header_id (p_cust_po_number       VARCHAR2,
                             x_header_id        OUT NUMBER)
    IS
    BEGIN
        SELECT header_id
          INTO x_header_id
          FROM oe_order_headers_all
         WHERE cust_po_number = p_cust_po_number;
    END;

    PROCEDURE get_line_id (p_header_id         NUMBER,
                           p_line_number       NUMBER,
                           x_line_id       OUT NUMBER)
    IS
    BEGIN
        SELECT line_id
          INTO x_line_id
          FROM oe_order_lines_all
         WHERE header_id = p_header_id AND line_number = p_line_number;
    END;

    PROCEDURE get_line_number (p_line_id NUMBER, x_line_number OUT NUMBER)
    IS
    BEGIN
        SELECT line_number
          INTO x_line_number
          FROM oe_order_lines_all
         WHERE line_id = p_line_id;
    END;
END xxdoec_order_utils_pkg;
/
