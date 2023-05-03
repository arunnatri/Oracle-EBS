--
-- XXDQP_UPDATE_COST  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDQP_UPDATE_COST"
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Technology Team
    -- Creation Date           : 31-Mar-2015
    -- File Name               : XXDQP_UPDATE_COST.pks
    -- INCIDENT                : Deckers - Update Price List Line Cost
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                 Remarks
    -- =============================================================================
    -- 08-MAY-2015        1.0         BT Technology Team  Initial development.
    -- 05-OCT-2015        1.1         BT Technology Team  Changes for Defect#3363.
    -- 05-Nov-2015        1.2         BT Technology Team  Changes for Defect#417.
    -- 10-Nov-2015        1.3         BT Technology Team  Changes for Defect#580.
    -------------------------------------------------------------------------------

    PROCEDURE insert_price_list (
        p_price_list_rec        IN     apps.qp_price_list_pub.price_list_rec_type,
        p_price_list_line_tbl   IN     apps.qp_price_list_pub.price_list_line_tbl_type,
        p_pricing_attr_tbl      IN     apps.qp_price_list_pub.pricing_attr_tbl_type,
        x_return_status            OUT VARCHAR2,
        x_error_message            OUT VARCHAR2)
    IS
        c_return_status             VARCHAR2 (20000);
        c_error_data                VARCHAR2 (20000);
        n_msg_count                 NUMBER;
        c_msg_data                  VARCHAR2 (20000);
        n_err_count                 NUMBER;
        l_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_price_list_rec            apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       apps.qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        l_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
        l_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
    BEGIN
        x_error_message   := NULL;
        oe_msg_pub.Initialize;

        --g_process_ind := 11;
        qp_price_list_pub.process_price_list (
            p_api_version_number        => 1.0,
            p_init_msg_list             => fnd_api.g_false,
            p_return_values             => fnd_api.g_false,
            p_commit                    => fnd_api.g_false,
            x_return_status             => c_return_status,
            x_msg_count                 => n_msg_count,
            x_msg_data                  => c_msg_data,
            p_price_list_rec            => p_price_list_rec,
            p_price_list_val_rec        => l_price_list_val_rec,
            p_price_list_line_tbl       => p_price_list_line_tbl,
            p_price_list_line_val_tbl   => l_price_list_line_val_tbl,
            p_qualifiers_tbl            => l_qualifiers_tbl,
            p_qualifiers_val_tbl        => l_qualifiers_val_tbl,
            p_pricing_attr_tbl          => p_pricing_attr_tbl,
            p_pricing_attr_val_tbl      => l_pricing_attr_val_tbl,
            x_price_list_rec            => x_price_list_rec,
            x_price_list_val_rec        => x_price_list_val_rec,
            x_price_list_line_tbl       => x_price_list_line_tbl,
            x_price_list_line_val_tbl   => x_price_list_line_val_tbl,
            x_qualifiers_tbl            => x_qualifiers_tbl,
            x_qualifiers_val_tbl        => x_qualifiers_val_tbl,
            x_pricing_attr_tbl          => x_pricing_attr_tbl,
            x_pricing_attr_val_tbl      => x_pricing_attr_val_tbl);

        x_return_status   := c_return_status;

        IF (c_return_status <> fnd_api.g_ret_sts_success)
        THEN
            -- ROLLBACK; -- Commented by BT Technology Team for defect#580 on 10-Nov-2015
            oe_msg_pub.count_and_get (p_count   => n_err_count,
                                      p_data    => c_error_data);
            c_error_data   := NULL;

            FOR i IN 1 .. n_err_count
            LOOP
                c_msg_data   :=
                    oe_msg_pub.get (p_msg_index   => oe_msg_pub.g_next,
                                    p_encoded     => fnd_api.g_false);
                c_error_data   :=
                    SUBSTR (c_error_data || c_msg_data, 1, 2000);
            END LOOP;

            x_error_message   :=
                'Error in Prepare_end_date_prc :' || c_error_data;
        ELSE
            COMMIT;
        END IF;
    END insert_price_list;

    FUNCTION GET_ITEM_COST (p_cost_element IN VARCHAR2, p_inventory_item_id IN NUMBER, p_costing_org IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_cost_element_cu (p_material_cost IN NUMBER)
        IS
            SELECT DECODE (basis_type, 1, item_cost, ((p_material_cost * item_cost) / 100)) item_cost
              FROM cst_item_cost_details_v
             WHERE     organization_id = p_costing_org
                   AND inventory_item_id = p_inventory_item_id
                   AND UPPER (resource_code) = UPPER (p_cost_element)
                   AND cost_type_id = 1000;

        CURSOR get_sum_cost_element_cu (p_material_cost IN NUMBER)
        IS
            SELECT SUM (DECODE (basis_type, 1, item_cost, ((p_material_cost * item_cost) / 100)))
              FROM cst_item_cost_details_v
             WHERE     organization_id = p_costing_org
                   AND inventory_item_id = p_inventory_item_id
                   AND cost_type_id = 1000;

        CURSOR get_material_cost_cu IS
            -- Start modification by BT Technology Team for defect#417 on 05-Nov-2015
            /*SELECT item_cost
              FROM cst_item_cost_details_v
             WHERE organization_id     = p_costing_org
               AND inventory_item_id   = p_inventory_item_id
               AND cost_element        = 'Material'
               AND cost_type_id        = 2
               AND resource_code IS NULL;*/

            SELECT cicd1.item_cost
              FROM cst_item_cost_type_v cict, cst_item_cost_details_v cicd1, cst_cost_types cct1
             WHERE     1 = 1
                   AND cicd1.cost_type_id = cct1.cost_type_id
                   AND cct1.cost_type = 'Average'
                   AND cict.cost_type_id = cct1.cost_type_id
                   AND cicd1.cost_element = 'Material'
                   AND cicd1.inventory_item_id = cict.inventory_item_id
                   AND cicd1.organization_id = cict.organization_id
                   AND cict.inventory_item_id = p_inventory_item_id
                   AND cict.organization_id = p_costing_org;

        -- End modification by BT Technology Team for defect#417 on 05-Nov-2015

        CURSOR get_material_ohd_cost_cu IS
            -- Start modification by BT Technology Team for defect#417 on 05-Nov-2015
            /*SELECT item_cost
              FROM cst_item_cost_details_v
             WHERE organization_id     = p_costing_org
               AND inventory_item_id   = p_inventory_item_id
               AND cost_element        = 'Material Overhead'
               AND cost_type_id        = 2
               AND resource_code IS NULL;*/
            SELECT cicd1.item_cost
              FROM cst_item_cost_type_v cict, cst_item_cost_details_v cicd1, cst_cost_types cct1
             WHERE     1 = 1
                   AND cicd1.cost_type_id = cct1.cost_type_id
                   AND cct1.cost_type = 'Average'
                   AND cict.cost_type_id = cct1.cost_type_id
                   AND cicd1.cost_element = 'Material Overhead'
                   AND cicd1.inventory_item_id = cict.inventory_item_id
                   AND cicd1.organization_id = cict.organization_id
                   AND cict.inventory_item_id = p_inventory_item_id
                   AND cict.organization_id = p_costing_org;

        -- End modification by BT Technology Team for defect#417 on 05-Nov-2015

        ln_cost                NUMBER;
        ln_material_cost       NUMBER;
        ln_sum_cost            NUMBER;
        ln_material_ohd_cost   NUMBER;
    BEGIN
        ln_cost                := 0;
        ln_material_cost       := 0;
        ln_sum_cost            := 0;
        ln_material_ohd_cost   := 0;


        IF p_cost_element = 'Material'
        THEN
            OPEN get_material_cost_cu;

            FETCH get_material_cost_cu INTO ln_material_cost;

            CLOSE get_material_cost_cu;

            RETURN NVL (ln_material_cost, 0);
        ELSIF p_cost_element = 'DUTY'
        THEN
            OPEN get_material_cost_cu;

            FETCH get_material_cost_cu INTO ln_material_cost;

            CLOSE get_material_cost_cu;

            OPEN get_material_ohd_cost_cu;

            FETCH get_material_ohd_cost_cu INTO ln_material_ohd_cost;

            CLOSE get_material_ohd_cost_cu;

            OPEN get_sum_cost_element_cu (ln_material_cost);

            FETCH get_sum_cost_element_cu INTO ln_sum_cost;

            CLOSE get_sum_cost_element_cu;

            RETURN (NVL (ln_material_ohd_cost, 0) - NVL (ln_sum_cost, 0));
        ELSE
            OPEN get_material_cost_cu;

            FETCH get_material_cost_cu INTO ln_material_cost;

            CLOSE get_material_cost_cu;

            OPEN get_cost_element_cu (ln_material_cost);

            FETCH get_cost_element_cu INTO ln_cost;

            CLOSE get_cost_element_cu;

            RETURN NVL (ln_cost, 0);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_ITEM_COST;

    PROCEDURE UPDATE_COST (P_ERRBUFF              OUT VARCHAR2,
                           P_RETCODE              OUT NUMBER,
                           P_PRICE_LIST        IN     VARCHAR2,
                           P_INV_ORG           IN     VARCHAR2,
                           P_BRAND             IN     VARCHAR2,
                           P_MATERIAL_USE      IN     VARCHAR2,
                           P_OHDUTY_USE        IN     VARCHAR2,
                           P_OHNONDUTY_USE     IN     VARCHAR2,
                           P_FREIGHTDU_USE     IN     VARCHAR2,
                           P_FREIGHT_USE       IN     VARCHAR2,
                           P_DUTY_USE          IN     VARCHAR2,
                           P_UPDATE            IN     VARCHAR2,
                           P_EXCHANGE_TYPE     IN     VARCHAR2,
                           P_FROM_CURR         IN     VARCHAR2,
                           P_TO_CURR           IN     VARCHAR2,
                           P_FROM_PRICE_LIST   IN     VARCHAR2,
                           P_MARKUP            IN     VARCHAR2)
    IS
        --cursor to get all sizes for the style/color
        CURSOR c_item_rec IS
            SELECT mtl.inventory_item_id, mtl.primary_uom_code
              FROM mtl_system_items_b mtl, mtl_item_categories ic, mtl_categories_b c,
                   apps.mtl_parameters mp, apps.cst_item_costs cst, apps.fnd_flex_value_sets ffvs,
                   apps.fnd_flex_values ffv
             WHERE     ic.organization_id = mtl.organization_id
                   AND mtl.organization_id = p_inv_org
                   AND mp.organization_id = mtl.organization_id
                   AND ic.inventory_item_id = mtl.inventory_item_id
                   --AND ic.inventory_item_id      = 4886337 --Need to remove
                   AND ic.category_set_id = 1
                   AND c.category_id = ic.category_id
                   AND c.segment1 = p_brand
                   AND cst.organization_id = mtl.organization_id
                   AND cst.Cost_type_id = mp.primary_cost_method
                   AND cst.Inventory_item_id = mtl.inventory_item_id
                   AND cst.inventory_asset_flag = 1
                   AND ((cst.material_cost > 0) OR (NVL (mtl.list_price_per_unit, 0) > 0))
                   AND ffv.flex_value_set_id = ffvs.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXDO_CST_UPDATE_PRICELIST'
                   AND ffv.attribute1 IN
                           (SELECT name
                              FROM qp_list_headers
                             WHERE list_header_id = p_price_list)
                   AND FFV.parent_flex_value_low = mp.organization_code
                   AND (   (    P_FROM_PRICE_LIST IS NOT NULL
                            AND EXISTS
                                    (SELECT 1
                                       FROM qp_list_lines qll, qp_pricing_attributes qpa
                                      WHERE     qll.list_header_id =
                                                P_FROM_PRICE_LIST
                                            AND qll.list_line_id =
                                                qpa.list_line_id
                                            AND qpa.product_attr_value =
                                                TO_CHAR (
                                                    mtl.inventory_item_id)
                                            AND qpa.product_uom_code =
                                                mtl.primary_uom_code
                                            AND qpa.product_attribute_context =
                                                'ITEM'
                                            AND qpa.product_attribute =
                                                'PRICING_ATTRIBUTE1'
                                            AND qll.list_line_type_code =
                                                'PLL'))
                        OR (P_FROM_PRICE_LIST IS NULL AND 1 = 1));

        CURSOR check_line_exist_c (p_inventory_item_id   IN NUMBER,
                                   p_uom_code            IN VARCHAR2)
        IS
            SELECT qll.list_line_id
              FROM qp_list_lines qll, qp_pricing_attributes qpa
             WHERE     qll.list_header_id = p_price_list
                   AND qll.list_line_id = qpa.list_line_id
                   AND qpa.product_attr_value = TO_CHAR (p_inventory_item_id)
                   AND qpa.product_uom_code = p_uom_code
                   AND qll.list_line_type_code = 'PLL';

        CURSOR get_procedence_c IS
            SELECT qsv.user_precedence
              FROM qp_prc_contexts_v qpc, qp_segments_v qsv
             WHERE     qsv.prc_context_id = qpc.prc_context_id
                   AND prc_context_type = 'PRODUCT'
                   AND prc_context_code = 'ITEM'
                   AND segment_code = 'INVENTORY_ITEM_ID';

        CURSOR get_daily_rate_c IS
            SELECT NVL (conversion_rate, 1)
              FROM gl_daily_rates
             WHERE     from_currency = p_from_curr
                   AND to_currency = p_to_curr
                   AND conversion_date = TRUNC (SYSDATE)
                   AND conversion_type = p_exchange_type;

        -- Started by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015
        CURSOR get_listprice_cu (p_inventory_item_id   IN NUMBER,
                                 p_costing_org         IN NUMBER)
        IS
            SELECT NVL (list_price_per_unit, 0)
              FROM mtl_system_items_b
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id = p_costing_org;

        CURSOR get_pricelist_operand (p_inventory_item_id IN NUMBER, p_pricelist_id IN NUMBER, p_uom_code IN VARCHAR2)
        IS
            SELECT qll.operand
              FROM qp_list_lines qll, qp_pricing_attributes qpa
             WHERE     qll.list_header_id = p_pricelist_id
                   AND qll.list_header_id = qpa.list_header_id
                   AND qll.list_line_id = qpa.list_line_id
                   AND qpa.product_attr_value = p_inventory_item_id
                   AND qpa.product_attribute_context = 'ITEM'
                   AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                   AND qpa.product_uom_code = p_uom_code
                   -- Start changes by BT Technology Team for defect#580 on 10-Nov-2015
                   AND TRUNC (SYSDATE) BETWEEN NVL (start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (end_date_active,
                                                    TRUNC (SYSDATE));

        -- End changes by BT Technology Team for defect#580 on 10-Nov-2015

        -- Ended by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015

        TYPE t_item_rec IS TABLE OF c_item_rec%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_item_rec                  t_item_rec;

        l_price_list_rec1           apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_line_tbl1      apps.qp_price_list_pub.price_list_line_tbl_type;
        l_pricing_attr_tbl1         apps.qp_price_list_pub.pricing_attr_tbl_type;
        l_price_list_rec2           apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_line_tbl2      apps.qp_price_list_pub.price_list_line_tbl_type;
        l_pricing_attr_tbl2         apps.qp_price_list_pub.pricing_attr_tbl_type;
        l_return_status             VARCHAR2 (4000) := NULL;
        l_msg_data                  VARCHAR2 (20000);
        k                           NUMBER := 0;
        s                           NUMBER := 0;
        t                           NUMBER := 0;
        attr_group_no               NUMBER;
        c_return_status             VARCHAR2 (20000);
        c_error_data                VARCHAR2 (20000);
        n_msg_count                 NUMBER;
        c_msg_data                  VARCHAR2 (20000);
        x_error_message             VARCHAR2 (20000);
        n_err_count                 NUMBER;
        l_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_price_list_rec            apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       apps.qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        l_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
        l_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;

        ln_material_cost            NUMBER := 0;
        ln_overhead_duty            NUMBER := 0;
        ln_overhead_nonduty         NUMBER := 0;
        ln_freight_nonduty          NUMBER := 0;
        ln_freight_duty             NUMBER := 0;
        ln_duty                     NUMBER := 0;
        ln_operand                  NUMBER := 0;
        ln_list_line_id             NUMBER := 0;
        ln_precedence               NUMBER := 0;
        ln_exchange_rate            NUMBER := 1;
        -- Started by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015
        ln_listprice_cu             NUMBER := 0;
        ln_cost                     NUMBER := 0;
        ln_price_list               NUMBER := 0;
        ln_markup_cost              NUMBER := 0;
    -- Ended by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'P_PRICE_LIST ' || P_PRICE_LIST);
        fnd_file.put_line (fnd_file.LOG, 'P_INV_ORG ' || P_INV_ORG);
        fnd_file.put_line (fnd_file.LOG, 'P_BRAND ' || P_BRAND);
        fnd_file.put_line (fnd_file.LOG, 'P_MATERIAL_USE ' || P_MATERIAL_USE);
        fnd_file.put_line (fnd_file.LOG, 'P_OHDUTY_USE ' || P_OHDUTY_USE);
        fnd_file.put_line (fnd_file.LOG,
                           'P_OHNONDUTY_USE ' || P_OHNONDUTY_USE);
        fnd_file.put_line (fnd_file.LOG,
                           'P_FREIGHTDU_USE ' || P_FREIGHTDU_USE);
        fnd_file.put_line (fnd_file.LOG, 'P_FREIGHT_USE ' || P_FREIGHT_USE);
        fnd_file.put_line (fnd_file.LOG, 'P_DUTY_USE ' || P_DUTY_USE);
        fnd_file.put_line (fnd_file.LOG, 'P_UPDATE ' || P_UPDATE);
        fnd_file.put_line (fnd_file.LOG,
                           'P_EXCHANGE_TYPE ' || P_EXCHANGE_TYPE);
        fnd_file.put_line (fnd_file.LOG, 'P_FROM_CURR ' || P_FROM_CURR);
        fnd_file.put_line (fnd_file.LOG, 'P_TO_CURR ' || P_TO_CURR);
        fnd_file.put_line (fnd_file.LOG, 'P_MARKUP ' || P_MARKUP);
        fnd_file.put_line (fnd_file.LOG,
                           'P_FROM_PRICE_LIST ' || P_FROM_PRICE_LIST);


        OPEN c_item_rec;

        LOOP
            FETCH c_item_rec BULK COLLECT INTO l_item_rec LIMIT 4000;

            IF l_item_rec.COUNT = 0
            THEN
                -- Start changes by BT Technology Team for defect#580 on 10-Nov-2015
                /*FND_FILE.PUT_LINE (
                   FND_FILE.LOG,
                   'No Lines are added/updated for price list, please check price list is added in the value set XXDO_CST_UPDATE_PRICELIST  ');*/
                -- End changes by BT Technology Team for defect#580 on 10-Nov-2015
                RETURN;
            END IF;

            EXIT WHEN l_item_rec.COUNT = 0;
            k   := 0;
            s   := 0;
            t   := 0;

            FOR i IN 1 .. l_item_rec.COUNT
            LOOP
                ln_list_line_id   := 0;

                IF p_material_use = 'Y'
                THEN
                    ln_material_cost   :=
                        GET_ITEM_COST (
                            p_cost_element        => 'Material',
                            p_inventory_item_id   =>
                                l_item_rec (i).inventory_item_id,
                            p_costing_org         => p_inv_org);

                    -- Started by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015
                    IF ln_material_cost = 0
                    THEN
                        OPEN get_listprice_cu (
                            l_item_rec (i).inventory_item_id,
                            p_inv_org);

                        FETCH get_listprice_cu INTO ln_listprice_cu;

                        CLOSE get_listprice_cu;

                        ln_material_cost   := ln_listprice_cu;
                    END IF;
                -- Ended by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015
                ELSE
                    ln_material_cost   := 0;
                END IF;

                IF P_OHDUTY_USE = 'Y'
                THEN
                    ln_overhead_duty   :=
                        GET_ITEM_COST (
                            p_cost_element        => 'OH DUTY',
                            p_inventory_item_id   =>
                                l_item_rec (i).inventory_item_id,
                            p_costing_org         => p_inv_org);
                ELSE
                    ln_overhead_duty   := 0;
                END IF;

                IF P_OHNONDUTY_USE = 'Y'
                THEN
                    ln_overhead_nonduty   :=
                        GET_ITEM_COST (
                            p_cost_element        => 'OH NONDUTY',
                            p_inventory_item_id   =>
                                l_item_rec (i).inventory_item_id,
                            p_costing_org         => p_inv_org);
                ELSE
                    ln_overhead_nonduty   := 0;
                END IF;

                IF P_FREIGHT_USE = 'Y'
                THEN
                    ln_freight_nonduty   :=
                        GET_ITEM_COST (
                            p_cost_element        => 'FREIGHT',
                            p_inventory_item_id   =>
                                l_item_rec (i).inventory_item_id,
                            p_costing_org         => p_inv_org);
                ELSE
                    ln_freight_nonduty   := 0;
                END IF;

                IF P_FREIGHTDU_USE = 'Y'
                THEN
                    ln_freight_duty   :=
                        GET_ITEM_COST (
                            p_cost_element        => 'FREIGHT DU',
                            p_inventory_item_id   =>
                                l_item_rec (i).inventory_item_id,
                            p_costing_org         => p_inv_org);
                ELSE
                    ln_freight_duty   := 0;
                END IF;

                IF P_DUTY_USE = 'Y'
                THEN
                    ln_duty   :=
                        GET_ITEM_COST (
                            p_cost_element        => 'DUTY',
                            p_inventory_item_id   =>
                                l_item_rec (i).inventory_item_id,
                            p_costing_org         => p_inv_org);
                ELSE
                    ln_duty   := 0;
                END IF;

                OPEN get_daily_rate_c;

                FETCH get_daily_rate_c INTO ln_exchange_rate;

                CLOSE get_daily_rate_c;

                OPEN get_procedence_c;

                FETCH get_procedence_c INTO ln_precedence;

                CLOSE get_procedence_c;

                ln_operand        := 0;

                ln_list_line_id   := 0;

                /*
                -- Started by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015
                ln_operand  := ((ln_material_cost+
                                ln_overhead_duty +
                                ln_overhead_nonduty +
                                ln_freight_nonduty +
                                ln_freight_duty +
                                ln_duty)
                                *NVL(ln_exchange_rate,1)
                                *NVL(p_markup,1));
               */
                ln_price_list     := 0;

                IF P_FROM_PRICE_LIST IS NOT NULL
                THEN
                    OPEN get_pricelist_operand (
                        l_item_rec (i).inventory_item_id,
                        P_FROM_PRICE_LIST,
                        l_item_rec (i).primary_uom_code);

                    FETCH get_pricelist_operand INTO ln_price_list;

                    CLOSE get_pricelist_operand;

                    IF ln_price_list IS NULL
                    THEN
                        ln_price_list   := 0;
                    END IF;
                END IF;

                ln_cost           :=
                      ln_material_cost
                    + ln_overhead_duty
                    + ln_overhead_nonduty
                    + ln_freight_nonduty
                    + ln_freight_duty
                    + ln_duty
                    + ln_price_list;

                ln_markup_cost    := ln_cost * NVL (p_markup / 100, 0);

                ln_operand        :=
                    (ln_cost + ln_markup_cost) * NVL (ln_exchange_rate, 1);


                -- Ended by BT Technology team for Defect#3363 version 1.1 on 05-OCT-2015

                OPEN check_line_exist_c (l_item_rec (i).inventory_item_id,
                                         l_item_rec (i).primary_uom_code);

                FETCH check_line_exist_c INTO ln_list_line_id;

                CLOSE check_line_exist_c;

                -- Start changes by BT Technology Team for defect#580 on 10-Nov-2015
                -- IF ln_list_line_id <> 0 AND p_update = 'Y'
                IF NVL (ln_list_line_id, 0) > 0 AND p_update = 'Y'
                -- End changes by BT Technology Team for defect#580 on 10-Nov-2015
                THEN
                    k                                           := k + 1;

                    l_price_list_rec1.list_header_id            := p_price_list;
                    l_price_list_rec1.list_type_code            := 'PRL';
                    l_price_list_rec1.operation                 :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl1 (k).list_header_id   :=
                        p_price_list;
                    l_price_list_line_tbl1 (k).list_line_id     :=
                        ln_list_line_id;
                    l_price_list_line_tbl1 (k).operation        :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl1 (k).operand          := ln_operand;
                    l_price_list_line_tbl1 (k).product_precedence   :=
                        ln_precedence;
                /*          BEGIN

                           insert_price_list (
                              p_price_list_rec        => l_price_list_rec1,
                              p_price_list_line_tbl   => l_price_list_line_tbl1,
                              p_pricing_attr_tbl      => l_pricing_attr_tbl1,
                              x_return_status         => c_return_status,
                              x_error_message         => c_msg_data);

                          EXCEPTION
                             WHEN OTHERS
                             THEN
                            fnd_file.put_line(FND_FILE.LOG,'Failure '||SQLERRM);
                          END;
                        IF c_return_status <> apps.fnd_api.g_ret_sts_success
                        THEN
                           fnd_file.put_line(FND_FILE.LOG,'Error while updating cost for inventory item id '||l_item_rec(i).inventory_item_id||' is '||c_msg_data);
                       END IF;
                    */
                -- Start changes by BT Technology Team for defect#580 on 10-Nov-2015
                -- ELSE
                ELSIF NVL (ln_list_line_id, 0) = 0
                THEN
                    -- End changes by BT Technology Team for defect#580 on 10-Nov-2015
                    /*   l_price_list_rec2.list_header_id := NULL;
                       l_price_list_rec2.list_type_code := NULL;
                       l_price_list_line_tbl2.delete;
                       l_pricing_attr_tbl2.delete; */

                    --s := 1;
                    s                                                := s + 1;
                    l_price_list_rec2.list_header_id                 := p_price_list;
                    l_price_list_rec2.list_type_code                 := 'PRL';
                    l_price_list_rec2.operation                      :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl2 (s).list_header_id        :=
                        p_price_list;
                    l_price_list_line_tbl2 (s).list_line_id          :=
                        qp_list_lines_s.NEXTVAL;
                    l_price_list_line_tbl2 (s).list_line_type_code   := 'PLL';
                    l_price_list_line_tbl2 (s).operation             :=
                        qp_globals.g_opr_create;
                    l_price_list_line_tbl2 (s).operand               :=
                        ln_operand;
                    l_price_list_line_tbl2 (s).product_precedence    :=
                        ln_precedence;
                    --   l_price_list_line_tbl1 (s).attribute1             := l_price_list_add_rec(l_add).brand;
                    --  l_price_list_line_tbl1 (s).attribute2             := l_price_list_add_rec(l_add).season;
                    l_price_list_line_tbl2 (s).arithmetic_operator   :=
                        'UNIT_PRICE';
                    l_price_list_line_tbl2 (s).start_date_active     := NULL;
                    l_price_list_line_tbl2 (s).end_date_active       := NULL;

                    --t := 1;
                    t                                                := t + 1;

                    SELECT apps.qp_pricing_attr_group_no_s.NEXTVAL
                      INTO attr_group_no
                      FROM DUAL;


                    l_pricing_attr_tbl2 (t).list_line_id             :=
                        l_price_list_line_tbl2 (s).list_line_id;
                    l_pricing_attr_tbl2 (t).product_attribute_context   :=
                        'ITEM';                                      --'ITEM';
                    l_pricing_attr_tbl2 (t).product_attribute        :=
                        'PRICING_ATTRIBUTE1';         -- 'PRICING_ATTRIBUTE1';
                    l_pricing_attr_tbl2 (t).product_attribute_datatype   :=
                        'C';
                    l_pricing_attr_tbl2 (t).product_attr_value       :=
                        l_item_rec (i).inventory_item_id;
                    l_pricing_attr_tbl2 (t).product_uom_code         :=
                        l_item_rec (i).primary_uom_code;
                    l_pricing_attr_tbl2 (t).excluder_flag            :=
                        'N';
                    l_pricing_attr_tbl2 (t).attribute_grouping_no    :=
                        attr_group_no;
                    l_pricing_attr_tbl2 (t).operation                :=
                        qp_globals.g_opr_create;
                /*     BEGIN
                        insert_price_list (
                           p_price_list_rec        => l_price_list_rec2,
                           p_price_list_line_tbl   => l_price_list_line_tbl2,
                           p_pricing_attr_tbl      => l_pricing_attr_tbl2,
                           x_return_status         => c_return_status,
                           x_error_message         => c_msg_data);
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line (fnd_file.log,'Exception while creating line' || '  ' || SQLERRM);
                     END;
                     IF c_return_status <> apps.fnd_api.g_ret_sts_success
                     THEN
                        fnd_file.put_line(FND_FILE.LOG,'Error while updating cost for inventory item id '||l_item_rec(i).inventory_item_id||' is '||c_msg_data);
                    END IF;  */

                END IF;

                IF i = l_item_rec.COUNT
                THEN
                    IF k > 0
                    THEN
                        BEGIN
                            insert_price_list (
                                p_price_list_rec     => l_price_list_rec1,
                                p_price_list_line_tbl   =>
                                    l_price_list_line_tbl1,
                                p_pricing_attr_tbl   => l_pricing_attr_tbl1,
                                x_return_status      => c_return_status,
                                x_error_message      => c_msg_data);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (FND_FILE.LOG,
                                                   'Failure ' || SQLERRM);
                        END;

                        IF c_return_status <> apps.fnd_api.g_ret_sts_success
                        THEN
                            fnd_file.put_line (
                                FND_FILE.LOG,
                                   'Error while updating cost for inventory item id '
                                || l_item_rec (i).inventory_item_id
                                || ' is '
                                || c_msg_data);
                        END IF;

                        l_price_list_rec1.list_header_id   := NULL;
                        l_price_list_rec1.list_type_code   := NULL;
                        l_price_list_line_tbl1.delete;
                        l_pricing_attr_tbl1.delete;
                    END IF;

                    BEGIN
                        insert_price_list (
                            p_price_list_rec        => l_price_list_rec2,
                            p_price_list_line_tbl   => l_price_list_line_tbl2,
                            p_pricing_attr_tbl      => l_pricing_attr_tbl2,
                            x_return_status         => c_return_status,
                            x_error_message         => c_msg_data);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Exception while creating line'
                                || '  '
                                || SQLERRM);
                    END;

                    IF c_return_status <> apps.fnd_api.g_ret_sts_success
                    THEN
                        fnd_file.put_line (
                            FND_FILE.LOG,
                               'Error while updating cost for inventory item id '
                            || l_item_rec (i).inventory_item_id
                            || ' is '
                            || c_msg_data);
                    END IF;

                    l_price_list_rec2.list_header_id   := NULL;
                    l_price_list_rec2.list_type_code   := NULL;
                    l_price_list_line_tbl2.delete;
                    l_pricing_attr_tbl2.delete;
                END IF;                         --IF i = l_item_rec.COUNT THEN
            END LOOP;
        END LOOP;                                            --OPEN c_item_rec

        CLOSE c_item_rec;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception found at UPDATE_COST ' || SQLERRM);
    END UPDATE_COST;
END XXDQP_UPDATE_COST;
/
