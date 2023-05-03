--
-- XXD_ONT_PROMOTIONS_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_PROMOTIONS_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_PROMOTIONS_X_PK
    * Design       : This package is used for applying/removing Promotions and Discounts
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 21-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    -- 02-Jan-2018  1.1        Viswanathan Pandian     Modified for CCR0006890
    ******************************************************************************************/
    CURSOR get_discount_modifier IS
        SELECT qpl.modifier_level_code, qph.list_header_id, qpl.list_line_id,
               flv2.lookup_code change_reason_code, flv2.meaning change_reason_text
          FROM qp_list_headers qph, qp_list_lines qpl, fnd_lookup_values flv1,
               fnd_lookup_values flv2
         WHERE     qph.list_header_id = qpl.list_header_id
               AND qpl.list_line_no = flv1.meaning
               AND qph.name = flv1.description
               AND flv1.lookup_type = 'XXD_PROMO_MODIFIER'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (qph.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (qph.end_date_active,
                                                    SYSDATE))
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (qpl.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (qpl.end_date_active,
                                                    SYSDATE))
               AND flv1.enabled_flag = 'Y'
               AND flv1.language = USERENV ('LANG')
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv1.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv1.end_date_active,
                                                    SYSDATE))
               AND flv2.lookup_type = 'CHANGE_CODE'
               AND flv2.lookup_code = flv1.tag
               AND flv2.enabled_flag = 'Y'
               AND flv2.language = USERENV ('LANG')
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv2.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv2.end_date_active,
                                                    SYSDATE));

    -- ===============================================================================
    -- This procedure prints the Debug Messages in Log
    -- ===============================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        IF gc_debug_enable = 'Y'
        THEN
            IF gc_flag = 'N'
            THEN
                oe_debug_pub.debug_on;
                lc_debug_mode   := oe_debug_pub.set_debug_mode ('CONC');
                oe_debug_pub.setdebuglevel (10000);
                fnd_file.put_line (fnd_file.LOG,
                                   'Debug Mode = ' || lc_debug_mode);
                gc_flag         := 'Y';
            END IF;

            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;
    END debug_msg;

    -- ===============================================================================
    -- This procedure calls LOCK_ORDER to lock the order
    -- ===============================================================================
    PROCEDURE lock_current_order (p_header_id IN oe_order_headers_all.header_id%TYPE, p_return_status OUT VARCHAR2, p_return_msg OUT VARCHAR2)
    AS
        lc_sub_prog_name           VARCHAR2 (100) := 'LOCK_CURRENT_ORDER';
        lc_return_status           VARCHAR2 (2000);
        lc_error_message           VARCHAR2 (4000);
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER (10);
        lc_msg_data                VARCHAR2 (1000);
        l_header_rec               oe_order_pub.header_rec_type;
        l_header_val_rec           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_line_val_tbl             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        oe_order_pub.get_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            x_return_status            => lc_return_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lc_msg_data,
            p_header_id                => p_header_id,
            p_org_id                   => gn_org_id,
            x_header_rec               => l_header_rec,
            x_header_val_rec           => l_header_val_rec,
            x_header_adj_tbl           => l_header_adj_tbl,
            x_header_adj_val_tbl       => l_header_adj_val_tbl,
            x_header_price_att_tbl     => l_header_price_att_tbl,
            x_header_adj_att_tbl       => l_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl,
            x_header_scredit_tbl       => l_header_scredit_tbl,
            x_header_scredit_val_tbl   => l_header_scredit_val_tbl,
            x_line_tbl                 => l_line_tbl,
            x_line_val_tbl             => l_line_val_tbl,
            x_line_adj_tbl             => l_line_adj_tbl,
            x_line_adj_val_tbl         => l_line_adj_val_tbl,
            x_line_price_att_tbl       => l_line_price_att_tbl,
            x_line_adj_att_tbl         => l_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl,
            x_line_scredit_tbl         => l_line_scredit_tbl,
            x_line_scredit_val_tbl     => l_line_scredit_val_tbl,
            x_lot_serial_tbl           => l_lot_serial_tbl,
            x_lot_serial_val_tbl       => l_lot_serial_val_tbl);
        debug_msg ('Get Order API Status: ' || lc_return_status);

        IF lc_return_status = fnd_api.g_ret_sts_success
        THEN
            l_header_rec             := oe_order_pub.g_miss_header_rec;
            l_header_rec.header_id   := p_header_id;
            l_header_rec.operation   := oe_globals.g_opr_lock;
            oe_order_pub.lock_order (
                p_org_id                   => gn_org_id,
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data,
                p_header_rec               => l_header_rec,
                p_header_val_rec           => l_header_val_rec,
                p_header_adj_tbl           => l_header_adj_tbl,
                p_header_adj_val_tbl       => l_header_adj_val_tbl,
                p_header_price_att_tbl     => l_header_price_att_tbl,
                p_header_adj_att_tbl       => l_header_adj_att_tbl,
                p_header_adj_assoc_tbl     => l_header_adj_assoc_tbl,
                p_header_scredit_tbl       => l_header_scredit_tbl,
                p_header_scredit_val_tbl   => l_header_scredit_val_tbl,
                p_line_tbl                 => l_line_tbl,
                p_line_val_tbl             => l_line_val_tbl,
                p_line_adj_tbl             => l_line_adj_tbl,
                p_line_adj_val_tbl         => l_line_adj_val_tbl,
                p_line_price_att_tbl       => l_line_price_att_tbl,
                p_line_adj_att_tbl         => l_line_adj_att_tbl,
                p_line_adj_assoc_tbl       => l_line_adj_assoc_tbl,
                p_line_scredit_tbl         => l_line_scredit_tbl,
                p_line_scredit_val_tbl     => l_line_scredit_val_tbl,
                p_lot_serial_tbl           => l_lot_serial_tbl,
                p_lot_serial_val_tbl       => l_lot_serial_val_tbl,
                x_header_rec               => x_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl);
            debug_msg ('Lock Order API Status: ' || lc_return_status);
        END IF;

        IF lc_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. oe_msg_pub.count_msg
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_error_message
                                , p_msg_index_out => ln_msg_index_out);
            END LOOP;

            lc_error_message   := NVL (lc_error_message, 'LOCK_ORDER Failed');
            debug_msg ('API Error: ' || lc_error_message);
        END IF;

        p_return_status   := lc_return_status;
        p_return_msg      := lc_error_message;
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 'E';
            p_return_msg      := SQLERRM;
            debug_msg (
                'Others Exception in LOCK_CURRENT_ORDER : ' || SQLERRM);
    END lock_current_order;

    /*################################################################################
    -- Public Subprograms
    ################################################################################*/

    -- ===============================================================================
    -- This function return Y or N if an order is locked by another session/user
    -- ===============================================================================
    FUNCTION check_order_lock (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_order IS
                SELECT ooha.header_id, oola.line_id
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola
                 WHERE     ooha.header_id = oola.header_id
                       AND oola.open_flag = 'Y'
                       AND ooha.header_id = p_header_id
            FOR UPDATE NOWAIT;

        lc_sub_prog_name   VARCHAR2 (100) := 'CHECK_ORDER_LOCK';
        ln_header_id       oe_order_headers_all.header_id%TYPE;
        ln_line_id         oe_order_lines_all.line_id%TYPE;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        OPEN get_order;

        FETCH get_order INTO ln_header_id, ln_line_id;

        CLOSE get_order;

        debug_msg ('End ' || lc_sub_prog_name);
        RETURN 'N';
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Exception=' || SQLERRM);

            IF get_order%ISOPEN
            THEN
                CLOSE get_order;
            END IF;

            RETURN 'Y';
    END;

    -- ===============================================================================
    -- This function return Y or N if reservation exists
    -- ===============================================================================
    FUNCTION get_reservation (
        p_order_number IN oe_order_headers_all.order_number%TYPE)
        RETURN VARCHAR2
    AS
        lc_return_value   VARCHAR2 (1);
    BEGIN
        SELECT DECODE (COUNT (1), 0, 'N', 'Y')
          INTO lc_return_value
          FROM mtl_reservations mr, mtl_sales_orders mso
         WHERE     mr.demand_source_header_id = mso.sales_order_id
               AND mr.supply_source_type_id = 13 --Inventory. Hard-coded to avoid performance
               AND mso.segment1 = p_order_number
               AND mso.segment3 = 'ORDER ENTRY';

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in GET_RESERVATION : ' || SQLERRM);
            RETURN NULL;
    END get_reservation;

    -- ===============================================================================
    -- This main procedure identifies eligible promotion and applies to the order
    -- ===============================================================================
    PROCEDURE apply_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE)
    AS
        CURSOR get_promotion_records (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE)
        IS
            SELECT xopt.*,
                   ooha.order_number,
                   ooha.header_id,
                   hca.account_number
                       order_customer_number,
                   hp.party_name
                       order_customer_name,
                   ottt.name
                       order_type,
                   oos.name
                       order_source,
                   ooha.ordered_date,
                   ooha.request_date,
                   (SELECT meaning
                      FROM oe_ship_methods_v
                     WHERE lookup_code = ooha.shipping_method_code)
                       order_ship_method,
                   ooha.shipping_method_code
                       order_shipping_method_code,
                   (SELECT meaning
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'FREIGHT_TERMS'
                           AND language = USERENV ('LANG')
                           AND lookup_code = ooha.freight_terms_code)
                       order_freight_term,
                   ooha.freight_terms_code
                       order_freight_terms_code,
                   (SELECT name
                      FROM ra_terms
                     WHERE term_id = ooha.payment_term_id)
                       order_payment_term,
                   ooha.payment_term_id
                       order_payment_term_id,
                   (SELECT MIN (opa.operand)
                      FROM oe_price_adjustments opa
                     WHERE     opa.header_id = ooha.header_id
                           AND opa.line_id IS NULL
                           AND opa.list_header_id = gn_list_header_id
                           AND opa.list_line_id = gn_order_list_line_id)
                       order_header_discount
              FROM oe_order_headers_all ooha, xxd_ont_promotions_t xopt, oe_order_sources oos,
                   oe_transaction_types_tl ottt, hz_cust_accounts hca, hz_parties hp
             WHERE     ooha.attribute5 = xopt.brand
                   AND ooha.org_id = xopt.org_id
                   AND ((ooha.attribute11 = xopt.promotion_code AND gc_override_flag = 'N') OR (gc_override_flag = 'Y' AND 1 = 1))
                   AND ooha.order_source_id = oos.order_source_id
                   AND ooha.order_type_id = ottt.transaction_type_id
                   AND ottt.language = USERENV ('LANG')
                   AND ooha.sold_to_org_id = hca.cust_account_id
                   AND hca.party_id = hp.party_id
                   AND xopt.promotion_level = 'HEADER'
                   AND xopt.promotion_code_status = 'A'
                   AND ooha.header_id = p_header_id
                   AND xopt.promotion_code = p_promotion_code;

        CURSOR get_order_history IS
              SELECT *
                FROM (SELECT oola.line_id,
                             oola.line_number,
                             oola.ordered_item,
                             (SELECT MIN (opa.operand)
                                FROM oe_price_adjustments opa
                               WHERE     opa.line_id = oola.line_id
                                     AND opa.header_id = p_header_id
                                     AND opa.list_line_id =
                                         gn_order_list_line_id
                                     AND opa.list_header_id = gn_list_header_id)
                                 order_line_discount,
                             xopt.promotion_id,
                             xopt.promotion_name,
                             xopt.department,
                             xopt.division,
                             xopt.class,
                             xopt.sub_class,
                             xopt.style_number,
                             xopt.color_code,
                             xopt.line_discount,
                             xopt.promotion_level
                        FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                             oe_order_lines_all oola, xxd_ont_promotions_t xopt
                       WHERE     mic.category_set_id = mcs.category_set_id
                             AND mic.category_id = mc.category_id
                             AND mc.structure_id = mcs.structure_id
                             AND mcs.category_set_name = 'Inventory'
                             AND oola.inventory_item_id = mic.inventory_item_id
                             AND oola.ship_from_org_id = mic.organization_id
                             AND oola.open_flag = 'Y'
                             AND xopt.promotion_level = 'LINE'
                             AND xopt.promotion_code = p_promotion_code
                             AND oola.header_id = p_header_id
                             AND mc.segment1 = xopt.brand
                             AND ((xopt.department IS NULL AND 1 = 1) OR (xopt.department = mc.segment3))
                             AND ((xopt.division IS NULL AND 1 = 1) OR (xopt.division = mc.segment2))
                             AND ((xopt.class IS NULL AND 1 = 1) OR (xopt.class = mc.segment4))
                             AND ((xopt.sub_class IS NULL AND 1 = 1) OR (xopt.sub_class = mc.segment5))
                             AND ((xopt.style_number IS NULL AND 1 = 1) OR (xopt.style_number = mc.attribute7))
                             AND ((xopt.color_code IS NULL AND 1 = 1) OR (xopt.color_code = mc.attribute8))
                      UNION
                      SELECT NULL line_id, NULL line_number, NULL ordered_item,
                             NULL order_line_discount, xopt.promotion_id, xopt.promotion_name,
                             NULL department, NULL division, NULL class,
                             NULL sub_class, NULL style_number, NULL color_code,
                             NULL line_discount, xopt.promotion_level
                        FROM xxd_ont_promotions_t xopt
                       WHERE     xopt.promotion_code = p_promotion_code
                             AND xopt.promotion_level = 'HEADER') lines
               WHERE NOT EXISTS
                         (SELECT 1
                            FROM xxd_ont_promotions_history_t xopht
                           WHERE     xopht.promotion_code = p_promotion_code
                                 AND xopht.header_id = p_header_id
                                 AND xopht.line_id = lines.line_id)
            ORDER BY promotion_level;

        CURSOR get_order_lines IS
            SELECT line_id, line_discount
              FROM (SELECT line_id, line_discount
                      FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                           oe_order_lines_all oola, xxd_ont_promotions_t xopt
                     WHERE     mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND oola.inventory_item_id = mic.inventory_item_id
                           AND oola.ship_from_org_id = mic.organization_id
                           AND oola.open_flag = 'Y'
                           AND xopt.promotion_level = 'LINE'
                           AND xopt.promotion_code = p_promotion_code
                           AND oola.header_id = p_header_id
                           AND mc.segment1 = xopt.brand
                           AND ((xopt.department IS NULL AND 1 = 1) OR (xopt.department = mc.segment3))
                           AND ((xopt.division IS NULL AND 1 = 1) OR (xopt.division = mc.segment2))
                           AND ((xopt.class IS NULL AND 1 = 1) OR (xopt.class = mc.segment4))
                           AND ((xopt.sub_class IS NULL AND 1 = 1) OR (xopt.sub_class = mc.segment5))
                           AND ((xopt.style_number IS NULL AND 1 = 1) OR (xopt.style_number = mc.attribute7))
                           AND ((xopt.color_code IS NULL AND 1 = 1) OR (xopt.color_code = mc.attribute8))
                    UNION
                    SELECT line_id, NULL line_discount
                      FROM oe_order_lines_all oola
                     WHERE     oola.header_id = p_header_id
                           AND oola.open_flag = 'Y'
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                                           xxd_ont_promotions_t xopt
                                     WHERE     mic.category_set_id =
                                               mcs.category_set_id
                                           AND mic.category_id =
                                               mc.category_id
                                           AND mc.structure_id =
                                               mcs.structure_id
                                           AND mcs.category_set_name =
                                               'Inventory'
                                           AND oola.inventory_item_id =
                                               mic.inventory_item_id
                                           AND oola.ship_from_org_id =
                                               mic.organization_id
                                           AND oola.open_flag = 'Y'
                                           AND xopt.promotion_level = 'LINE'
                                           AND xopt.promotion_code =
                                               p_promotion_code
                                           AND oola.header_id = p_header_id
                                           AND mc.segment1 = xopt.brand
                                           AND ((xopt.department IS NULL AND 1 = 1) OR (xopt.department = mc.segment3))
                                           AND ((xopt.division IS NULL AND 1 = 1) OR (xopt.division = mc.segment2))
                                           AND ((xopt.class IS NULL AND 1 = 1) OR (xopt.class = mc.segment4))
                                           AND ((xopt.sub_class IS NULL AND 1 = 1) OR (xopt.sub_class = mc.segment5))
                                           AND ((xopt.style_number IS NULL AND 1 = 1) OR (xopt.style_number = mc.attribute7))
                                           AND ((xopt.color_code IS NULL AND 1 = 1) OR (xopt.color_code = mc.attribute8))))
                   lines
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM oe_price_adjustments opa
                         WHERE     opa.line_id = lines.line_id
                               AND opa.header_id = p_header_id
                               AND opa.list_line_id = gn_line_list_line_id
                               AND opa.list_header_id = gn_list_header_id);

        lc_sub_prog_name           VARCHAR2 (100) := 'APPLY_PROMOTION';
        lc_return_status           VARCHAR2 (1);
        lc_order_locked            VARCHAR2 (1) := 'N';
        lc_order_status            VARCHAR2 (50);
        lc_msg_data                VARCHAR2 (1000);
        lc_error_message           VARCHAR2 (4000);
        lc_reservation_exists      VARCHAR2 (1) := 'N';
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER (10);
        ln_adj_tbl_index           NUMBER := 0;
        ln_line_tbl_index          NUMBER := 0;
        promotion_rec              get_promotion_records%ROWTYPE;
        l_header_rec               oe_order_pub.header_rec_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
    BEGIN
        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('Start ' || lc_sub_prog_name);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        debug_msg ('Start Processing Order Header Id=' || p_header_id);

        OPEN get_promotion_records (p_header_id, p_promotion_code);

        FETCH get_promotion_records INTO promotion_rec;

        IF get_promotion_records%ROWCOUNT = 0
        THEN
            lc_order_status    := 'Ineligible';
            lc_error_message   := 'Invalid Promotion Code';
            debug_msg ('Order Status=' || lc_order_status);
        ELSIF get_promotion_records%ROWCOUNT > 1
        THEN
            lc_order_status    := 'Multiple';
            lc_error_message   := 'Multiple Promotion Records Available';
            debug_msg ('Order Status=' || lc_order_status);
        ELSE
            -- Promotion History. Insert as many order lines as it matches with the promotion hierarchy along with header
            FOR order_history_rec IN get_order_history
            LOOP
                INSERT INTO xxd_ont_promotions_history_t
                     VALUES (xxdo.xxd_ont_promotions_history_s.NEXTVAL, order_history_rec.promotion_id, promotion_rec.promotion_code, order_history_rec.promotion_name, promotion_rec.operating_unit, promotion_rec.org_id, promotion_rec.brand, promotion_rec.currency, promotion_rec.promotion_code_status, NULL, SYSDATE, gn_user_id, SYSDATE, gn_user_id, gn_login_id, gn_request_id, promotion_rec.order_number, promotion_rec.header_id, promotion_rec.order_customer_number, promotion_rec.order_customer_name, promotion_rec.order_type, promotion_rec.order_source, promotion_rec.ordered_date, promotion_rec.request_date, promotion_rec.order_ship_method, promotion_rec.order_shipping_method_code, promotion_rec.order_freight_term, promotion_rec.order_freight_terms_code, promotion_rec.order_payment_term, promotion_rec.order_payment_term_id, promotion_rec.order_header_discount, promotion_rec.ship_method, promotion_rec.shipping_method_code, promotion_rec.freight_term, promotion_rec.freight_terms_code, promotion_rec.payment_term, promotion_rec.payment_term_id, promotion_rec.header_discount, order_history_rec.line_id, order_history_rec.line_number, order_history_rec.ordered_item, order_history_rec.department, order_history_rec.division, order_history_rec.class, order_history_rec.sub_class, order_history_rec.style_number, order_history_rec.color_code, promotion_rec.number_of_styles, promotion_rec.number_of_colors, NULL, order_history_rec.line_discount
                             , order_history_rec.promotion_level, NULL);
            END LOOP;

            debug_msg ('Promotion History Records Count = ' || SQL%ROWCOUNT);

            -- Explicit Lock Check
            lc_order_locked   := check_order_lock (p_header_id);
            debug_msg ('Explicit Order Lock = ' || lc_order_locked);

            IF lc_order_locked = 'N'
            THEN
                -- Lock Current Order
                lock_current_order (p_header_id,
                                    lc_return_status,
                                    lc_error_message);

                IF lc_return_status = fnd_api.g_ret_sts_success
                THEN
                    SAVEPOINT before_order;
                    -- Header Record
                    l_header_rec             := oe_order_pub.g_miss_header_rec;
                    l_header_rec.header_id   := p_header_id;
                    l_header_rec.org_id      := gn_org_id;
                    l_header_rec.operation   := oe_globals.g_opr_update;

                    lc_reservation_exists    :=
                        get_reservation (promotion_rec.order_number);
                    debug_msg (
                        'Reservation Exists = ' || lc_reservation_exists);

                    IF     promotion_rec.shipping_method_code IS NOT NULL
                       AND lc_reservation_exists = 'N'
                    THEN
                        l_header_rec.shipping_method_code   :=
                            promotion_rec.shipping_method_code;
                    ELSIF     promotion_rec.shipping_method_code IS NOT NULL
                          AND lc_reservation_exists = 'Y'
                    THEN
                        lc_order_status   := 'Applied except Ship Method';
                    END IF;

                    IF promotion_rec.freight_terms_code IS NOT NULL
                    THEN
                        l_header_rec.freight_terms_code   :=
                            promotion_rec.freight_terms_code;
                    END IF;

                    IF promotion_rec.payment_term_id IS NOT NULL
                    THEN
                        l_header_rec.payment_term_id   :=
                            promotion_rec.payment_term_id;
                    END IF;

                    IF     promotion_rec.header_discount IS NOT NULL
                       AND promotion_rec.order_header_discount IS NULL
                    THEN
                        ln_adj_tbl_index   := ln_adj_tbl_index + 1;

                        -- Header Adjustment
                        l_header_adj_tbl (ln_adj_tbl_index)   :=
                            oe_order_pub.g_miss_header_adj_rec;
                        l_header_adj_tbl (ln_adj_tbl_index).operation   :=
                            oe_globals.g_opr_create;
                        l_header_adj_tbl (ln_adj_tbl_index).header_id   :=
                            p_header_id;
                        l_header_adj_tbl (ln_adj_tbl_index).automatic_flag   :=
                            'N';
                        l_header_adj_tbl (ln_adj_tbl_index).applied_flag   :=
                            'Y';
                        l_header_adj_tbl (ln_adj_tbl_index).updated_flag   :=
                            'Y';
                        l_header_adj_tbl (ln_adj_tbl_index).list_header_id   :=
                            gn_list_header_id;
                        l_header_adj_tbl (ln_adj_tbl_index).list_line_id   :=
                            gn_order_list_line_id;
                        l_header_adj_tbl (ln_adj_tbl_index).modifier_level_code   :=
                            'ORDER';
                        l_header_adj_tbl (ln_adj_tbl_index).list_line_type_code   :=
                            'DIS';
                        l_header_adj_tbl (ln_adj_tbl_index).operand   :=
                            promotion_rec.header_discount;
                        l_header_adj_tbl (ln_adj_tbl_index).arithmetic_operator   :=
                            '%';
                        l_header_adj_tbl (ln_adj_tbl_index).change_reason_code   :=
                            gc_change_reason_code;
                        l_header_adj_tbl (ln_adj_tbl_index).change_reason_text   :=
                            gc_change_reason_text;
                    END IF;

                    FOR lines_rec IN get_order_lines ()
                    LOOP
                        debug_msg (
                               'Line. Enforce Cascading Effect for Line Id='
                            || lines_rec.line_id);
                        ln_line_tbl_index   := ln_line_tbl_index + 1;
                        l_line_tbl (ln_line_tbl_index)   :=
                            oe_order_pub.g_miss_line_rec;
                        l_line_tbl (ln_line_tbl_index).operation   :=
                            oe_globals.g_opr_update;
                        l_line_tbl (ln_line_tbl_index).header_id   :=
                            p_header_id;
                        l_line_tbl (ln_line_tbl_index).line_id   :=
                            lines_rec.line_id;

                        -- Line Table. Enforce Cascading Effect to all open lines
                        IF     promotion_rec.shipping_method_code IS NOT NULL
                           AND lc_reservation_exists = 'N'
                        THEN
                            l_line_tbl (ln_line_tbl_index).shipping_method_code   :=
                                promotion_rec.shipping_method_code;
                        END IF;

                        IF promotion_rec.freight_terms_code IS NOT NULL
                        THEN
                            l_line_tbl (ln_line_tbl_index).freight_terms_code   :=
                                promotion_rec.freight_terms_code;
                        END IF;

                        IF promotion_rec.payment_term_id IS NOT NULL
                        THEN
                            l_line_tbl (ln_line_tbl_index).payment_term_id   :=
                                promotion_rec.payment_term_id;
                        END IF;

                        IF lines_rec.line_discount IS NOT NULL
                        THEN
                            -- Line Adjustment
                            ln_adj_tbl_index   := ln_adj_tbl_index + 1;
                            l_header_adj_tbl (ln_adj_tbl_index)   :=
                                oe_order_pub.g_miss_header_adj_rec;
                            l_header_adj_tbl (ln_adj_tbl_index).operation   :=
                                oe_globals.g_opr_create;
                            l_header_adj_tbl (ln_adj_tbl_index).header_id   :=
                                p_header_id;
                            l_header_adj_tbl (ln_adj_tbl_index).line_id   :=
                                lines_rec.line_id;
                            l_header_adj_tbl (ln_adj_tbl_index).automatic_flag   :=
                                'N';
                            l_header_adj_tbl (ln_adj_tbl_index).applied_flag   :=
                                'Y';
                            l_header_adj_tbl (ln_adj_tbl_index).updated_flag   :=
                                'Y';
                            l_header_adj_tbl (ln_adj_tbl_index).list_header_id   :=
                                gn_list_header_id;
                            l_header_adj_tbl (ln_adj_tbl_index).list_line_id   :=
                                gn_line_list_line_id;
                            l_header_adj_tbl (ln_adj_tbl_index).modifier_level_code   :=
                                'LINE';
                            l_header_adj_tbl (ln_adj_tbl_index).list_line_type_code   :=
                                'DIS';
                            l_header_adj_tbl (ln_adj_tbl_index).operand   :=
                                lines_rec.line_discount;
                            l_header_adj_tbl (ln_adj_tbl_index).arithmetic_operator   :=
                                '%';
                            l_header_adj_tbl (ln_adj_tbl_index).change_reason_code   :=
                                gc_change_reason_code;
                            l_header_adj_tbl (ln_adj_tbl_index).change_reason_text   :=
                                gc_change_reason_text;
                        END IF;
                    END LOOP;

                    debug_msg ('Call Process Order API');
                    oe_order_pub.process_order (
                        p_org_id                   => gn_org_id,
                        p_api_version_number       => 1.0,
                        p_init_msg_list            => fnd_api.g_false,
                        p_return_values            => fnd_api.g_false,
                        p_action_commit            => fnd_api.g_false,
                        x_return_status            => lc_return_status,
                        x_msg_count                => ln_msg_count,
                        x_msg_data                 => lc_msg_data,
                        p_header_rec               => l_header_rec,
                        p_header_adj_tbl           => l_header_adj_tbl,
                        p_line_tbl                 => l_line_tbl,
                        p_line_adj_tbl             => l_line_adj_tbl,
                        p_action_request_tbl       => l_action_request_tbl,
                        x_header_rec               => x_header_rec,
                        x_header_val_rec           => x_header_val_rec,
                        x_header_adj_tbl           => x_header_adj_tbl,
                        x_header_adj_val_tbl       => x_header_adj_val_tbl,
                        x_header_price_att_tbl     => x_header_price_att_tbl,
                        x_header_adj_att_tbl       => x_header_adj_att_tbl,
                        x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                        x_header_scredit_tbl       => x_header_scredit_tbl,
                        x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                        x_line_tbl                 => x_line_tbl,
                        x_line_val_tbl             => x_line_val_tbl,
                        x_line_adj_tbl             => x_line_adj_tbl,
                        x_line_adj_val_tbl         => x_line_adj_val_tbl,
                        x_line_price_att_tbl       => x_line_price_att_tbl,
                        x_line_adj_att_tbl         => x_line_adj_att_tbl,
                        x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                        x_line_scredit_tbl         => x_line_scredit_tbl,
                        x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                        x_lot_serial_tbl           => x_lot_serial_tbl,
                        x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                        x_action_request_tbl       => x_action_request_tbl);
                    debug_msg (
                        'Process Order API Status: ' || lc_return_status);

                    IF lc_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        FOR i IN 1 .. oe_msg_pub.count_msg
                        LOOP
                            oe_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => lc_error_message,
                                p_msg_index_out   => ln_msg_index_out);
                        END LOOP;

                        lc_order_status   := 'Application Error';
                        lc_error_message   :=
                            NVL (lc_error_message, 'OE_ORDER_PUB Failed');
                        debug_msg (
                               'APPLY_PROMOTION - Process Order API Error: '
                            || lc_error_message);
                        ROLLBACK TO before_order;
                    ELSE
                        lc_order_status    := NVL (lc_order_status, 'Applied');
                        lc_error_message   := NULL;
                    END IF;
                ELSE
                    lc_order_status   := 'Application Error';
                END IF;     -- IF lc_return_status = fnd_api.g_ret_sts_success
            ELSE
                lc_order_status    := 'Application Error';
                lc_error_message   := 'Order Locked. Skipping Application';
            END IF;                                -- IF lc_order_locked = 'N'
        END IF;                       -- IF get_promotion_records%ROWCOUNT = 0

        CLOSE get_promotion_records;

        debug_msg ('Promotion Status=' || lc_order_status);

        -- Direct update on ATTRIBUTE/WHO columns are allowed per Oracle
        -- Promotion Status Update, if there is no lock
        IF lc_order_locked = 'N'
        THEN
            UPDATE oe_order_headers_all
               SET attribute11 = p_promotion_code, attribute12 = lc_order_status, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE header_id = p_header_id;
        END IF;

        -- Update Status in History Table for all applicable lines
        -- If no history records (for ineligible and multiple promotion cases), nothing will be updated
        UPDATE xxd_ont_promotions_history_t
           SET error_message = lc_error_message, action = lc_order_status
         WHERE     promotion_code = p_promotion_code
               AND header_id = p_header_id
               AND request_id = gn_request_id
               AND action IS NULL;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_promotion_records%ISOPEN
            THEN
                CLOSE get_promotion_records;
            END IF;

            debug_msg ('Others Exception in APPLY_PROMOTION : ' || SQLERRM);
    END apply_promotion;

    -- ===============================================================================
    -- This main procedure removes the Promotion applied in the past
    -- ===============================================================================
    PROCEDURE remove_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE)
    AS
        CURSOR get_initial_promotion_history IS
              SELECT xopht.order_number,
                     xopht.promotion_id,
                     xopht.promotion_code,
                     NVL (
                         (  SELECT promotion_name
                              FROM xxd_ont_promotions_t
                             WHERE     promotion_code = p_promotion_code
                                   AND promotion_level <> 'HEADER'
                          GROUP BY promotion_name),
                         xopht.promotion_name) promotion_name,
                     xopht.operating_unit,
                     xopht.org_id,
                     xopht.brand,
                     xopht.currency,
                     xopht.promotion_code_status,
                     xopht.from_ship_method,
                     xopht.from_shipping_method_code,
                     xopht.from_freight_term,
                     xopht.from_freight_terms_code,
                     xopht.from_payment_term,
                     xopht.from_payment_term_id,
                     xopht.from_header_discount
                FROM xxd_ont_promotions_history_t xopht
               WHERE     xopht.header_id = p_header_id
                     AND promotion_code = p_promotion_code
                     AND promotion_level = 'HEADER'
            ORDER BY xopht.promotion_history_id ASC;

        CURSOR get_promotion IS
            SELECT NULL order_number, promotion_id, promotion_code,
                   promotion_name, operating_unit, org_id,
                   brand, currency, promotion_code_status,
                   NULL from_ship_method, NULL from_shipping_method_code, NULL from_freight_term,
                   NULL from_freight_terms_code, NULL from_payment_term, NULL from_payment_term_id,
                   NULL from_header_discount
              FROM xxd_ont_promotions_t
             WHERE     promotion_code = p_promotion_code
                   AND promotion_level = 'HEADER';

        CURSOR get_all_lines IS
            SELECT line_id
              FROM oe_order_lines_all
             WHERE header_id = p_header_id AND open_flag = 'Y';

        CURSOR get_adjustment_records IS
            -- Header Discounts
            SELECT price_adjustment_id
              FROM oe_price_adjustments
             WHERE     header_id = p_header_id
                   AND line_id IS NULL
                   AND list_line_id = gn_order_list_line_id
                   AND list_header_id = gn_list_header_id
            UNION
            -- Line Discounts
            SELECT price_adjustment_id
              FROM oe_price_adjustments
             WHERE     header_id = p_header_id
                   AND line_id IS NOT NULL
                   AND list_line_id = gn_line_list_line_id
                   AND list_header_id = gn_list_header_id;

        CURSOR get_current_order IS
            SELECT ooha.order_number,
                   hca.account_number
                       customer_number,
                   hp.party_name
                       customer_name,
                   ottt.name
                       order_type,
                   oos.name
                       order_source,
                   ooha.ordered_date,
                   ooha.request_date,
                   (SELECT MIN (opa.operand)
                      FROM oe_price_adjustments opa
                     WHERE     opa.header_id = ooha.header_id
                           AND opa.line_id IS NULL
                           AND opa.list_header_id = gn_list_header_id
                           AND opa.list_line_id = gn_order_list_line_id)
                       order_header_discount,
                   (SELECT meaning
                      FROM oe_ship_methods_v
                     WHERE lookup_code = ooha.shipping_method_code)
                       order_ship_method,
                   ooha.shipping_method_code
                       order_shipping_method_code,
                   (SELECT meaning
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'FREIGHT_TERMS'
                           AND language = USERENV ('LANG')
                           AND lookup_code = ooha.freight_terms_code)
                       order_freight_term,
                   ooha.freight_terms_code
                       order_freight_terms_code,
                   (SELECT name
                      FROM ra_terms
                     WHERE term_id = ooha.payment_term_id)
                       order_payment_term,
                   ooha.payment_term_id
                       order_payment_term_id
              FROM oe_order_headers_all ooha, xxd_ont_promotions_t xopt, oe_order_sources oos,
                   oe_transaction_types_tl ottt, hz_cust_accounts hca, hz_parties hp
             WHERE     ooha.order_source_id = oos.order_source_id
                   AND ooha.order_type_id = ottt.transaction_type_id
                   AND ottt.language = USERENV ('LANG')
                   AND ooha.sold_to_org_id = hca.cust_account_id
                   AND hca.party_id = hp.party_id
                   AND header_id = p_header_id;

        lc_sub_prog_name           VARCHAR2 (100) := 'REMOVE_PROMOTION';
        lc_msg_data                VARCHAR2 (1000);
        lc_return_status           VARCHAR2 (2000);
        lc_error_message           VARCHAR2 (4000);
        lc_reservation_exists      VARCHAR2 (1) := 'N';
        lc_order_locked            VARCHAR2 (1) := 'N';
        lc_order_status            VARCHAR2 (50);
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER (10);
        ln_line_tbl_index          NUMBER := 0;
        ln_adj_tbl_index           NUMBER := 0;
        promotion_history_rec      get_initial_promotion_history%ROWTYPE;
        current_order_rec          get_current_order%ROWTYPE;
        l_header_rec               oe_order_pub.header_rec_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
    BEGIN
        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('Start ' || lc_sub_prog_name);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        -- Get Initial Promotion Application Record
        OPEN get_initial_promotion_history;

        FETCH get_initial_promotion_history INTO promotion_history_rec;

        IF get_initial_promotion_history%NOTFOUND
        THEN
            debug_msg ('Initial Promotion Application Record not exists');

            CLOSE get_initial_promotion_history;

            -- If Initial Promotion does not exist, then take record from Promotion Table
            -- This case is applicable for an order which will be copied from another with Promotion
            -- So initial history will not be there
            OPEN get_promotion;

            FETCH get_promotion INTO promotion_history_rec;
        END IF;

        -- Explicit Lock Check
        lc_order_locked   := check_order_lock (p_header_id);

        IF lc_order_locked = 'N'
        THEN
            -- Lock Current Order
            lock_current_order (p_header_id,
                                lc_return_status,
                                lc_error_message);

            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                SAVEPOINT before_order;

                -- Get Current Order Details
                OPEN get_current_order;

                FETCH get_current_order INTO current_order_rec;

                -- Header
                l_header_rec               := oe_order_pub.g_miss_header_rec;
                l_header_rec.header_id     := p_header_id;
                l_header_rec.attribute11   := NULL;
                l_header_rec.attribute12   := NULL;
                l_header_rec.operation     := oe_globals.g_opr_update;

                lc_reservation_exists      :=
                    get_reservation (promotion_history_rec.order_number);

                debug_msg ('Reservation Exists = ' || lc_reservation_exists);

                IF     promotion_history_rec.from_shipping_method_code
                           IS NOT NULL
                   AND lc_reservation_exists = 'N'
                THEN
                    l_header_rec.shipping_method_code   :=
                        promotion_history_rec.from_shipping_method_code;
                ELSIF     promotion_history_rec.from_shipping_method_code
                              IS NOT NULL
                      AND lc_reservation_exists = 'Y'
                THEN
                    lc_order_status   := 'Removed except Ship Method';
                END IF;

                IF promotion_history_rec.from_freight_terms_code IS NOT NULL
                THEN
                    l_header_rec.freight_terms_code   :=
                        promotion_history_rec.from_freight_terms_code;
                END IF;

                IF promotion_history_rec.from_payment_term_id IS NOT NULL
                THEN
                    l_header_rec.payment_term_id   :=
                        promotion_history_rec.from_payment_term_id;
                END IF;

                -- Lines
                FOR all_lines_rec IN get_all_lines
                LOOP
                    ln_line_tbl_index                          := ln_line_tbl_index + 1;
                    l_line_tbl (ln_line_tbl_index)             :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_tbl_index).operation   :=
                        oe_globals.g_opr_update;
                    l_line_tbl (ln_line_tbl_index).header_id   := p_header_id;
                    l_line_tbl (ln_line_tbl_index).line_id     :=
                        all_lines_rec.line_id;

                    IF     promotion_history_rec.from_shipping_method_code
                               IS NOT NULL
                       AND lc_reservation_exists = 'N'
                    THEN
                        l_line_tbl (ln_line_tbl_index).shipping_method_code   :=
                            promotion_history_rec.from_shipping_method_code;
                    END IF;

                    IF promotion_history_rec.from_freight_terms_code
                           IS NOT NULL
                    THEN
                        l_line_tbl (ln_line_tbl_index).freight_terms_code   :=
                            promotion_history_rec.from_freight_terms_code;
                    END IF;

                    IF promotion_history_rec.from_payment_term_id IS NOT NULL
                    THEN
                        l_line_tbl (ln_line_tbl_index).payment_term_id   :=
                            promotion_history_rec.from_payment_term_id;
                    END IF;
                END LOOP;

                -- Header and Line Adjustment
                FOR adjustment_rec IN get_adjustment_records
                LOOP
                    ln_adj_tbl_index   := ln_adj_tbl_index + 1;
                    l_header_adj_tbl (ln_adj_tbl_index)   :=
                        oe_order_pub.g_miss_header_adj_rec;
                    l_header_adj_tbl (ln_adj_tbl_index).operation   :=
                        oe_globals.g_opr_delete;
                    l_header_adj_tbl (ln_adj_tbl_index).price_adjustment_id   :=
                        adjustment_rec.price_adjustment_id;
                END LOOP;

                debug_msg ('Call Process Order API');
                oe_order_pub.process_order (
                    p_org_id                   => gn_org_id,
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_false,
                    p_return_values            => fnd_api.g_false,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => lc_return_status,
                    x_msg_count                => ln_msg_count,
                    x_msg_data                 => lc_msg_data,
                    p_header_rec               => l_header_rec,
                    p_header_adj_tbl           => l_header_adj_tbl,
                    p_line_tbl                 => l_line_tbl,
                    p_line_adj_tbl             => l_line_adj_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    x_header_rec               => x_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_header_adj_tbl           => x_header_adj_tbl,
                    x_header_adj_val_tbl       => x_header_adj_val_tbl,
                    x_header_price_att_tbl     => x_header_price_att_tbl,
                    x_header_adj_att_tbl       => x_header_adj_att_tbl,
                    x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                    x_header_scredit_tbl       => x_header_scredit_tbl,
                    x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                    x_line_tbl                 => x_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_line_adj_tbl             => x_line_adj_tbl,
                    x_line_adj_val_tbl         => x_line_adj_val_tbl,
                    x_line_price_att_tbl       => x_line_price_att_tbl,
                    x_line_adj_att_tbl         => x_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                    x_line_scredit_tbl         => x_line_scredit_tbl,
                    x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                    x_lot_serial_tbl           => x_lot_serial_tbl,
                    x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                    x_action_request_tbl       => x_action_request_tbl);
                debug_msg ('Process Order API Status: ' || lc_return_status);

                IF lc_return_status <> fnd_api.g_ret_sts_success
                THEN
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_error_message
                                        , p_msg_index_out => ln_msg_index_out);
                    END LOOP;

                    lc_order_status   := 'Application Error';
                    lc_error_message   :=
                        NVL (lc_error_message, 'OE_ORDER_PUB Failed');
                    debug_msg (
                           'REMOVE_PROMOTION - Process Order API Error: '
                        || lc_error_message);
                    ROLLBACK TO before_order;
                ELSE
                    lc_order_status    := NVL (lc_order_status, 'Removed');
                    lc_error_message   := NULL;
                END IF;
            ELSE
                lc_order_status   := 'Application Error';
            END IF;         -- IF lc_return_status = fnd_api.g_ret_sts_success
        ELSE
            lc_order_status    := 'Application Error';
            lc_error_message   := 'Order Locked. Skipping Application';
        END IF;                                    -- IF lc_order_locked = 'N'

        -- Promotion History. Insert one record for removal
        INSERT INTO xxd_ont_promotions_history_t
             VALUES (xxdo.xxd_ont_promotions_history_s.NEXTVAL, promotion_history_rec.promotion_id, promotion_history_rec.promotion_code, promotion_history_rec.promotion_name, promotion_history_rec.operating_unit, promotion_history_rec.org_id, promotion_history_rec.brand, promotion_history_rec.currency, promotion_history_rec.promotion_code_status, lc_order_status, SYSDATE, gn_user_id, SYSDATE, gn_user_id, gn_login_id, gn_request_id, current_order_rec.order_number, p_header_id, current_order_rec.customer_number, current_order_rec.customer_name, current_order_rec.order_type, current_order_rec.order_source, current_order_rec.ordered_date, current_order_rec.request_date, current_order_rec.order_ship_method, current_order_rec.order_shipping_method_code, current_order_rec.order_freight_term, current_order_rec.order_freight_terms_code, current_order_rec.order_payment_term, current_order_rec.order_payment_term_id, current_order_rec.order_header_discount, NVL (promotion_history_rec.from_ship_method, current_order_rec.order_ship_method), NVL (promotion_history_rec.from_shipping_method_code, current_order_rec.order_shipping_method_code), NVL (promotion_history_rec.from_freight_term, current_order_rec.order_freight_term), NVL (promotion_history_rec.from_freight_terms_code, current_order_rec.order_freight_terms_code), NVL (promotion_history_rec.from_payment_term, current_order_rec.order_payment_term), NVL (promotion_history_rec.from_payment_term_id, current_order_rec.order_payment_term_id), promotion_history_rec.from_header_discount, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                     , 'HEADER', lc_error_message);

        debug_msg ('Promotion History Records = ' || SQL%ROWCOUNT);

        IF get_current_order%ISOPEN
        THEN
            CLOSE get_current_order;
        END IF;

        IF get_promotion%ISOPEN
        THEN
            CLOSE get_promotion;
        END IF;

        IF get_initial_promotion_history%ISOPEN
        THEN
            CLOSE get_initial_promotion_history;
        END IF;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_current_order%ISOPEN
            THEN
                CLOSE get_current_order;
            END IF;

            IF get_promotion%ISOPEN
            THEN
                CLOSE get_promotion;
            END IF;

            IF get_initial_promotion_history%ISOPEN
            THEN
                CLOSE get_initial_promotion_history;
            END IF;

            debug_msg ('Others Exception in REMOVE_PROMOTION : ' || SQLERRM);
    END remove_promotion;

    -- ===============================================================================
    -- This is the child procedure for the promotion concurrent program
    -- ===============================================================================
    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN hr_operating_units.organization_id%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_exclude_picked_orders IN VARCHAR2, p_reapply_promotion IN VARCHAR2, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_override_promotion IN VARCHAR2, p_override_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_threads IN NUMBER, p_debug IN VARCHAR2
                         , p_run_id IN NUMBER)
    AS
        CURSOR get_orders IS
            SELECT *
              FROM (SELECT xopt.promotion_code, ooha.header_id, NVL (ooha.attribute12, 'Scheduled to Apply') promotion_status,
                           NTILE (p_threads) OVER (ORDER BY ooha.header_id) run_id
                      FROM oe_order_headers_all ooha, xxd_ont_promotions_t xopt
                     WHERE     xopt.promotion_code_status = 'A'
                           AND ooha.attribute5 = xopt.brand
                           AND ooha.org_id = xopt.org_id
                           AND xopt.promotion_level = 'HEADER'
                           AND ooha.flow_status_code = 'BOOKED'
                           AND ooha.attribute11 = xopt.promotion_code
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM oe_order_lines_all oola, fnd_lookup_values flv
                                     WHERE     oe_line_status_pub.get_line_status (
                                                   oola.line_id,
                                                   oola.flow_status_code) =
                                               flv.meaning
                                           AND flv.lookup_type =
                                               'XXD_PROMO_MODIFIER'
                                           AND flv.description =
                                               'FLOW_STATUS_CODE'
                                           AND flv.enabled_flag = 'Y'
                                           AND flv.language =
                                               USERENV ('LANG')
                                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                           NVL (
                                                                               flv.start_date_active,
                                                                               SYSDATE))
                                                                   AND TRUNC (
                                                                           NVL (
                                                                               flv.end_date_active,
                                                                               SYSDATE))
                                           AND oola.header_id =
                                               ooha.header_id)
                           AND NVL (ooha.attribute11, 'XX') =
                               NVL (p_promotion_code,
                                    NVL (ooha.attribute11, 'XX'))
                           AND ((xopt.cust_account_id IS NULL AND 1 = 1) OR (xopt.cust_account_id = ooha.sold_to_org_id AND xopt.cust_account_id = NVL (p_cust_account_id, xopt.cust_account_id)))
                           AND (((xopt.ordered_date_from IS NULL OR xopt.ordered_date_to IS NULL) AND 1 = 1) OR (TRUNC (ooha.ordered_date) BETWEEN xopt.ordered_date_from AND xopt.ordered_date_to AND TRUNC (ooha.ordered_date) BETWEEN NVL (fnd_date.canonical_to_date (p_ordered_date_from), TRUNC (ooha.ordered_date)) AND NVL (fnd_date.canonical_to_date (p_ordered_date_to), TRUNC (ooha.ordered_date))))
                           AND (((xopt.request_date_from IS NULL OR xopt.request_date_to IS NULL) AND 1 = 1) OR (TRUNC (ooha.request_date) BETWEEN xopt.request_date_from AND xopt.request_date_to AND TRUNC (ooha.request_date) BETWEEN NVL (fnd_date.canonical_to_date (p_request_date_from), TRUNC (ooha.request_date)) AND NVL (fnd_date.canonical_to_date (p_request_date_to), TRUNC (ooha.request_date))))
                           AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                           AND EXISTS
                                   (SELECT 1
                                      FROM fnd_lookup_values flv
                                     WHERE     lookup_type =
                                               'XXD_PROMO_ORDER_TYPE_INCLUSION'
                                           AND flv.enabled_flag = 'Y'
                                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                           NVL (
                                                                               flv.start_date_active,
                                                                               SYSDATE))
                                                                   AND TRUNC (
                                                                           NVL (
                                                                               flv.end_date_active,
                                                                               SYSDATE))
                                           AND flv.language =
                                               USERENV ('LANG')
                                           AND flv.lookup_code =
                                               ooha.order_type_id
                                           AND ooha.order_type_id =
                                               NVL (p_order_type_id,
                                                    ooha.order_type_id))
                           AND EXISTS
                                   (SELECT 1
                                      FROM fnd_lookup_values flv
                                     WHERE     lookup_type =
                                               'XXD_PROMO_ORDER_SRC_INCLUSION'
                                           AND flv.enabled_flag = 'Y'
                                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                           NVL (
                                                                               flv.start_date_active,
                                                                               SYSDATE))
                                                                   AND TRUNC (
                                                                           NVL (
                                                                               flv.end_date_active,
                                                                               SYSDATE))
                                           AND flv.language =
                                               USERENV ('LANG')
                                           AND flv.lookup_code =
                                               ooha.order_source_id
                                           AND ooha.order_source_id =
                                               NVL (p_order_source_id,
                                                    ooha.order_source_id))
                           AND ooha.cust_po_number =
                               NVL (p_cust_po_number, ooha.cust_po_number)
                           AND (((p_exclude_picked_orders IS NULL OR p_exclude_picked_orders = 'N') AND 1 = 1) OR xxd_ont_promotions_x_pk.get_reservation (ooha.order_number) = 0)
                           AND ooha.org_id = p_org_id  -- Added for CCR0006890
                           AND ooha.attribute5 = p_brand)
             WHERE run_id = p_run_id;

        lc_sub_prog_name   VARCHAR2 (100) := 'CHILD_PRC';
        lc_no_data         VARCHAR2 (1) := 'Y';
    BEGIN
        gc_debug_enable   := p_debug;
        debug_msg ('Start ' || lc_sub_prog_name);

        FOR orders_rec IN get_orders
        LOOP
            lc_no_data   := 'N';

            IF ((p_reapply_promotion = 'N' AND orders_rec.promotion_status IN ('Scheduled to Apply', 'Ineligible', 'Application Error')) OR (p_reapply_promotion = 'Y' AND orders_rec.promotion_status IN ('Applied', 'Ineligible', 'Application Error')))
            THEN
                apply_promotion (
                    p_header_id        => orders_rec.header_id,
                    p_promotion_code   => orders_rec.promotion_code);
            ELSIF     orders_rec.promotion_status LIKE 'Applied%'
                  AND NVL (p_override_promotion, 'N') = 'Y'
                  AND p_override_promotion_code IS NOT NULL
            THEN
                gc_override_flag   := 'Y';
                remove_promotion (
                    p_header_id        => orders_rec.header_id,
                    p_promotion_code   => orders_rec.promotion_code);

                apply_promotion (
                    p_header_id        => orders_rec.header_id,
                    p_promotion_code   => p_override_promotion_code);
            ELSIF orders_rec.promotion_status = 'Scheduled to Remove'
            THEN
                remove_promotion (
                    p_header_id        => orders_rec.header_id,
                    p_promotion_code   => orders_rec.promotion_code);
            END IF;
        END LOOP;

        IF lc_no_data = 'Y'
        THEN
            x_errbuf    := 'No Data Found';
            x_retcode   := 1;
            debug_msg (x_errbuf);
        END IF;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            debug_msg ('Others Exception in CHILD_PRC : ' || x_errbuf);
    END child_prc;

    -- ===============================================================================
    -- This is the main procedure for the promotion concurrent program
    -- ===============================================================================
    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN hr_operating_units.organization_id%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_dummy_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_exclude_picked_orders IN VARCHAR2, p_reapply_promotion IN VARCHAR2, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_override_promotion IN VARCHAR2, p_dummy_override_promotion IN VARCHAR2, p_override_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE
                          , p_threads IN NUMBER, p_debug IN VARCHAR2)
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'MASTER_PRC';
        ln_req_id          NUMBER;
        lc_req_data        VARCHAR2 (10);
    BEGIN
        lc_req_data   := fnd_conc_global.request_data;

        IF lc_req_data IS NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Start ' || lc_sub_prog_name);

            IF     p_order_number_from IS NULL
               AND p_order_number_to IS NULL
               AND p_ordered_date_from IS NULL
               AND p_ordered_date_to IS NULL
               AND p_request_date_from IS NULL
               AND p_request_date_to IS NULL
            THEN
                x_errbuf    := 'Please specify Order Range or Date Range';
                x_retcode   := 1;
                fnd_file.put_line (fnd_file.LOG, x_errbuf);
            ELSE
                FOR i IN 1 .. p_threads
                LOOP
                    ln_req_id   := 0;

                    ln_req_id   :=
                        fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_PROMO_CHILD', description => NULL, start_time => NULL, sub_request => TRUE, argument1 => p_org_id, argument2 => p_brand, argument3 => p_cust_account_id, argument4 => p_cust_po_number, argument5 => p_order_number_from, argument6 => p_order_number_to, argument7 => p_ordered_date_from, argument8 => p_ordered_date_to, argument9 => p_request_date_from, argument10 => p_request_date_to, argument11 => p_order_source_id, argument12 => p_order_type_id, argument13 => p_exclude_picked_orders, argument14 => p_reapply_promotion, argument15 => p_promotion_code, argument16 => p_override_promotion, argument17 => p_override_promotion_code, argument18 => p_threads, argument19 => p_debug
                                                    , argument20 => i);
                    COMMIT;
                END LOOP;

                fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                                 request_data   => 1);

                fnd_file.put_line (fnd_file.LOG,
                                   'Successfully Submitted Child Threads');
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'End ' || lc_sub_prog_name);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC : ' || x_errbuf);
    END master_prc;

    -- ===============================================================================
    -- This functions returns 1 or 0 if an order is eligible for online promotion
    -- ===============================================================================
    FUNCTION check_promotion_eligibility (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN NUMBER
    AS
        CURSOR get_threshold IS
            SELECT lookup_code, TO_NUMBER (description) threshold
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PROMO_MODIFIER'
                   AND enabled_flag = 'Y'
                   AND lookup_code IN
                           ('ORDER_DATE_THRESHOLD', 'REQUEST_DATE_THRESHOLD', 'ORDER_LINE_COUNT')
                   AND language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));

        CURSOR get_orders (p_ord_date_threshold IN NUMBER, p_req_date_threshold IN NUMBER, p_ord_line_threshold IN NUMBER)
        IS
            SELECT 1
              FROM oe_order_headers_all ooha
             WHERE     ooha.header_id = p_header_id
                   AND (ooha.ordered_date <= SYSDATE OR ooha.ordered_date BETWEEN ooha.ordered_date AND SYSDATE + p_ord_date_threshold)
                   AND (ooha.request_date <= SYSDATE OR ooha.request_date BETWEEN ooha.request_date AND SYSDATE + p_req_date_threshold)
                   AND p_ord_line_threshold >=
                       (SELECT COUNT (oola.line_id)
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = ooha.header_id
                               AND oola.open_flag = 'Y');

        ln_ord_date_threshold   NUMBER := 0;
        ln_req_date_threshold   NUMBER := 0;
        ln_ord_line_threshold   NUMBER := 0;
        ln_return_value         NUMBER := 0;
    BEGIN
        FOR threshold_rec IN get_threshold
        LOOP
            IF threshold_rec.lookup_code = 'ORDER_DATE_THRESHOLD'
            THEN
                ln_ord_date_threshold   := threshold_rec.threshold;
            ELSIF threshold_rec.lookup_code = 'REQUEST_DATE_THRESHOLD'
            THEN
                ln_req_date_threshold   := threshold_rec.threshold;
            ELSIF threshold_rec.lookup_code = 'ORDER_LINE_COUNT'
            THEN
                ln_ord_line_threshold   := threshold_rec.threshold;
            END IF;
        END LOOP;

        FOR orders_rec
            IN get_orders (ln_ord_date_threshold,
                           ln_req_date_threshold,
                           ln_ord_line_threshold)
        LOOP
            ln_return_value   := 1;
        END LOOP;

        RETURN ln_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END check_promotion_eligibility;

    -- ===============================================================================
    -- This functions returns Y or N if any of the line is shipped/invoiced/closed
    -- ===============================================================================
    FUNCTION check_order_line_status (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN NUMBER
    AS
        CURSOR get_order_lines IS
            SELECT COUNT (1)
              FROM oe_order_lines_all oola, fnd_lookup_values flv
             WHERE     oe_line_status_pub.get_line_status (
                           oola.line_id,
                           oola.flow_status_code) =
                       flv.meaning
                   AND flv.lookup_type = 'XXD_PROMO_MODIFIER'
                   AND flv.description = 'FLOW_STATUS_CODE'
                   AND flv.enabled_flag = 'Y'
                   AND flv.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND oola.header_id = p_header_id;

        ln_dummy   NUMBER := 0;
    BEGIN
        OPEN get_order_lines;

        FETCH get_order_lines INTO ln_dummy;

        CLOSE get_order_lines;

        RETURN ln_dummy;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END check_order_line_status;

    -- ===============================================================================
    -- This procedure inactivates Promotion Codes
    -- ===============================================================================
    PROCEDURE inactivate_promotion (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_org_id IN xxd_ont_promotions_t.org_id%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_inactivation_reason IN xxd_ont_promotions_t.inactivation_reason%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2
                                    , p_request_date_to IN VARCHAR2, p_country_code IN xxd_ont_promotions_t.country_code%TYPE, p_state IN xxd_ont_promotions_t.state%TYPE)
    AS
        CURSOR get_promotions IS
            SELECT DISTINCT promotion_code,
                            (SELECT COUNT (1)
                               FROM oe_order_headers_all ooha
                              WHERE     ooha.org_id = xopt.org_id
                                    AND ooha.attribute5 = xopt.brand
                                    AND ooha.attribute11 =
                                        xopt.promotion_code
                                    AND ooha.open_flag = 'Y') order_count
              FROM xxd_ont_promotions_t xopt
             WHERE     xopt.promotion_code_status = 'A'
                   AND xopt.brand = p_brand
                   AND xopt.org_id = p_org_id
                   AND xopt.promotion_code =
                       NVL (p_promotion_code, xopt.promotion_code)
                   AND TRUNC (ordered_date_from) =
                       TRUNC (
                           NVL (
                               fnd_date.canonical_to_date (
                                   p_ordered_date_from),
                               ordered_date_from))
                   AND TRUNC (ordered_date_to) =
                       TRUNC (
                           NVL (
                               fnd_date.canonical_to_date (p_ordered_date_to),
                               ordered_date_to))
                   AND TRUNC (request_date_from) =
                       TRUNC (
                           NVL (
                               fnd_date.canonical_to_date (
                                   p_request_date_from),
                               request_date_from))
                   AND TRUNC (request_date_to) =
                       TRUNC (
                           NVL (
                               fnd_date.canonical_to_date (p_request_date_to),
                               request_date_to))
                   AND NVL (xopt.country_code, 'X') =
                       NVL (p_country_code, NVL (xopt.country_code, 'X'))
                   AND NVL (xopt.state, 'X') =
                       NVL (p_state, NVL (xopt.state, 'X'));

        lc_sub_prog_name   VARCHAR2 (100) := 'INACTIVATE_PROMOTION';
        lc_first_rec       VARCHAR2 (1) := 'Y';
        lc_record_count    NUMBER := 0;
        lc_success_count   NUMBER := 0;
        ln_update_count    NUMBER := 0;
        lc_comments        VARCHAR2 (2000);
        lc_status          VARCHAR2 (100);
        l                  get_promotions%ROWTYPE;
    BEGIN
        fnd_file.put_line (fnd_file.output, RPAD ('=', 155, '='));
        fnd_file.put_line (
            fnd_file.output,
            RPAD (' ', 59, ' ') || 'Deckers Promotions Inactivation Program');
        fnd_file.put_line (fnd_file.output, RPAD ('=', 155, '='));

        IF     p_promotion_code IS NULL
           AND p_ordered_date_from IS NULL
           AND p_ordered_date_to IS NULL
           AND p_request_date_from IS NULL
           AND p_request_date_to IS NULL
        THEN
            x_errbuf    := 'Please specify Promotion Code or Date Range';
            x_retcode   := 1;
            fnd_file.put_line (fnd_file.LOG, x_errbuf);
        ELSE
            FOR promotions_rec IN get_promotions
            LOOP
                lc_record_count   := lc_record_count + 1;
                lc_status         := NULL;
                lc_comments       := NULL;

                IF lc_first_rec = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD ('PROMOTION_CODE', 55, ' ')
                        || RPAD ('STATUS', 27, ' ')
                        || 'COMMENTS');
                    fnd_file.put_line (fnd_file.output, RPAD ('=', 155, '='));
                    lc_first_rec   := 'N';
                END IF;

                IF promotions_rec.order_count = 0
                THEN
                    BEGIN
                        UPDATE xxd_ont_promotions_t
                           SET promotion_code_status = 'I', inactivation_date = SYSDATE, inactivated_by = gn_user_id,
                               inactivation_reason = p_inactivation_reason
                         WHERE promotion_code = promotions_rec.promotion_code;

                        ln_update_count   := SQL%ROWCOUNT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_update_count   := 0;
                            lc_comments       := SUBSTR (SQLERRM, 1, 2000);
                    END;

                    IF ln_update_count > 0
                    THEN
                        lc_status          := 'Inactivated';
                        lc_success_count   := lc_success_count + 1;
                    ELSE
                        lc_status   := 'Failed';
                    END IF;
                ELSE
                    ln_update_count   := 0;
                    lc_status         := 'Failed';
                    lc_comments       :=
                           promotions_rec.order_count
                        || ' Open Order(s) has this Promotion already Applied. Skipping Inactivation';
                END IF;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (promotions_rec.promotion_code, 55, ' ')
                    || RPAD (lc_status, 27, ' ')
                    || lc_comments);
            END LOOP;

            fnd_file.put_line (fnd_file.output, RPAD ('=', 155, '='));
            fnd_file.put_line (
                fnd_file.output,
                'Total Promotion Codes Selected = ' || lc_record_count);
            fnd_file.put_line (
                fnd_file.output,
                'Total Promotion Codes Inactivated = ' || lc_success_count);
            fnd_file.put_line (fnd_file.output, RPAD ('=', 155, '='));

            IF lc_record_count = 0
            THEN
                x_errbuf    := 'No Data Found';
                x_retcode   := 1;
                fnd_file.put_line (fnd_file.LOG, x_errbuf);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in INACTIVATE_PROMOTION : ' || SQLERRM);
    END inactivate_promotion;

    -- ===============================================================================
    -- This procedure will be called from DOE to apply/remove promotion
    -- ===============================================================================
    PROCEDURE apply_remove_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_org_id IN NUMBER, p_is_apply IN NUMBER, x_status_flag OUT VARCHAR2, x_error_message OUT VARCHAR2
                                      , x_clear_flag OUT VARCHAR2)
    AS
        ln_line_check_flag   NUMBER := 0;
        ln_flag              NUMBER := 0;
    BEGIN
        SAVEPOINT before_app_rmv;
        ln_line_check_flag   := check_order_line_status (p_header_id);

        IF ln_line_check_flag = 0
        THEN
            ln_flag   := check_promotion_eligibility (p_header_id);

            IF ln_flag > 0
            THEN
                fnd_global.apps_initialize (user_id        => p_user_id,
                                            resp_id        => p_resp_id,
                                            resp_appl_id   => p_resp_app_id);
                mo_global.set_policy_context ('S', p_org_id);
                mo_global.init ('ONT');

                IF p_is_apply = 1
                THEN
                    -- Direct update on ATTRIBUTE/WHO columns are allowed per Oracle
                    -- Promotion Code Update
                    UPDATE oe_order_headers_all
                       SET attribute11 = p_promotion_code, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                           last_update_login = gn_login_id
                     WHERE header_id = p_header_id;

                    apply_promotion (p_header_id, p_promotion_code);
                ELSE
                    remove_promotion (p_header_id, p_promotion_code);
                END IF;

                COMMIT;
            ELSE
                x_status_flag     := 'E';
                x_error_message   := 'schedule';
            END IF;
        ELSE
            IF p_is_apply = 1
            THEN
                x_clear_flag   := 'Y';                -- Clear Promotion field
            END IF;

            x_status_flag   := 'E';
            x_error_message   :=
                'Selected action is not eligible. One or more lines are Picked/Shipped/Invoiced/Closed.';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO before_app_rmv;
            x_status_flag     := 'Ex';
            x_error_message   := SQLERRM;
    END apply_remove_promotion;

    -- ===============================================================================
    -- This procedure will be called from DOE to Schedule to Apply/Remove
    -- ===============================================================================
    PROCEDURE schedule_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_promotion_status IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER
                                  , p_org_id IN NUMBER, x_status_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    AS
        lc_order_locked   VARCHAR2 (1) := 'N';
    BEGIN
        SAVEPOINT before_sch_doe;
        lc_order_locked   := check_order_lock (p_header_id);

        IF lc_order_locked = 'N'
        THEN
            -- Direct update on ATTRIBUTE/WHO columns are allowed per Oracle
            -- Promotion Code, Status Update
            UPDATE oe_order_headers_all
               SET attribute11 = p_promotion_code, attribute12 = p_promotion_status, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE header_id = p_header_id;

            COMMIT;
        ELSE
            -- Record is locked. Return error message.
            x_status_flag   := 'E';
            x_error_message   :=
                'Record is currently being worked on by another user. Please try to update it later.';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO before_sch_doe;
            x_status_flag     := 'Ex';
            x_error_message   := SQLERRM;
    END schedule_promotion;

    -- ===============================================================================
    -- This procedure will be called from DOE to check whether order is locked
    -- ===============================================================================
    PROCEDURE check_order_lock_doe (p_header_id IN oe_order_headers_all.header_id%TYPE, p_order_locked OUT VARCHAR2, x_status_flag OUT VARCHAR2
                                    , x_error_message OUT VARCHAR2)
    AS
    BEGIN
        SAVEPOINT before_lock_doe;
        p_order_locked   := check_order_lock (p_header_id);
        ROLLBACK TO before_lock_doe;

        IF p_order_locked = 'Y'
        THEN
            -- Record is locked. Return error message.
            x_status_flag   := 'S';
            x_error_message   :=
                'Record is currently being worked on by another user. Please try to update it later.';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO before_lock_doe;
            x_status_flag     := 'Ex';
            x_error_message   := SQLERRM;
    END check_order_lock_doe;
BEGIN
    gn_org_id          := mo_global.get_current_org_id;
    gn_user_id         := fnd_global.user_id;
    gn_login_id        := fnd_global.login_id;
    gn_request_id      := fnd_global.conc_request_id;
    gc_override_flag   := 'N';

    FOR discount_modifier_rec IN get_discount_modifier
    LOOP
        IF discount_modifier_rec.modifier_level_code = 'ORDER'
        THEN
            gn_order_list_line_id   := discount_modifier_rec.list_line_id;
        ELSE
            gn_line_list_line_id   := discount_modifier_rec.list_line_id;
        END IF;

        gn_list_header_id       := discount_modifier_rec.list_header_id;
        gc_change_reason_code   := discount_modifier_rec.change_reason_code;
        gc_change_reason_text   := discount_modifier_rec.change_reason_text;
    END LOOP;
END xxd_ont_promotions_x_pk;
/
