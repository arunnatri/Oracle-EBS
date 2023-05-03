--
-- XXD_ONT_OEOL_WF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_OEOL_WF_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_OEOL_WF_PKG
    * Design       : This package will be called from OEOL Workflow
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 21-Nov-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE xxd_ont_validate_order_line (itemtype    IN     VARCHAR2,
                                           itemkey     IN     VARCHAR2,
                                           actid       IN     NUMBER,
                                           funcmode    IN     VARCHAR2,
                                           resultout   IN OUT VARCHAR2)
    IS
        CURSOR get_hold_id_c IS
            SELECT TO_NUMBER (lookup_code)
              FROM oe_lookups
             WHERE     lookup_type = 'XXD_ONT_CALLOFF_ORDER_HOLDS'
                   AND meaning = 'NEW'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));

        ln_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_rec                oe_order_pub.line_rec_type;
        l_header_rec              oe_order_pub.header_rec_type;
        l_action_request_tbl      oe_order_pub.request_tbl_type;
        l_request_rec             oe_order_pub.request_rec_type;
        l_line_tbl                oe_order_pub.line_tbl_type;
        l_hold_source_rec         oe_holds_pvt.hold_source_rec_type;
        ln_line_id                NUMBER;
        ln_count                  NUMBER := 0;
        ln_bulk_count             NUMBER := 0;
        ln_hold_id                NUMBER;
        ln_hold_count             NUMBER := 0;
        ln_msg_count              NUMBER := 0;
        ln_msg_index_out          NUMBER;
        lc_msg_data               VARCHAR2 (2000);
        lc_error_message          VARCHAR2 (2000);
        lc_return_status          VARCHAR2 (20);
        lc_status                 VARCHAR2 (20);
    BEGIN
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', fnd_global.org_id);

        ln_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF ln_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key: ' || itemkey);
                oe_debug_pub.ADD ('Within SCHEDULE LINE - Verify Bulk step ');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            oe_line_util.query_row (p_line_id    => ln_line_id,
                                    x_line_rec   => l_line_rec);

            oe_header_util.query_row (p_header_id    => l_line_rec.header_id,
                                      x_header_rec   => l_header_rec);

            IF ln_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'Order Number: ' || l_header_rec.order_number);
                oe_debug_pub.ADD ('Line ID: ' || l_line_rec.line_id);
            END IF;

            -- Validate if the Current Order is Bulk Calloff Order
            SELECT COUNT (1)
              INTO ln_count
              FROM oe_order_headers_all ooha, fnd_lookup_values flv
             WHERE     ooha.header_id = l_line_rec.header_id
                   AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                   AND ooha.org_id = TO_NUMBER (flv.tag)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_ONT_BLK_CALLOFF_ORDER_TYPE';

            IF ln_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Order Type Count: ' || ln_count);
            END IF;

            -- If Calloff then check if there is any open Bulk Order Line
            IF ln_count > 0
            THEN
                SELECT COUNT (1)
                  INTO ln_bulk_count
                  FROM oe_order_headers_all ooha_bulk, oe_order_lines_all oola_bulk, fnd_lookup_values flv
                 WHERE     ooha_bulk.header_id = oola_bulk.header_id
                       AND ooha_bulk.order_type_id =
                           TO_NUMBER (flv.lookup_code)
                       AND ooha_bulk.org_id = TO_NUMBER (flv.tag)
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           flv.start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (
                                                           flv.end_date_active,
                                                           SYSDATE))
                       AND flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                       AND oola_bulk.schedule_ship_date IS NOT NULL
                       AND oola_bulk.ordered_quantity > 0
                       AND oola_bulk.inventory_item_id =
                           l_line_rec.inventory_item_id
                       AND ooha_bulk.sold_to_org_id =
                           l_header_rec.sold_to_org_id
                       AND TRUNC (oola_bulk.schedule_ship_date) <=
                           TRUNC (l_line_rec.latest_acceptable_date);

                IF ln_debug_level > 0
                THEN
                    oe_debug_pub.ADD ('Bulk Count: ' || ln_bulk_count);
                END IF;

                IF ln_bulk_count > 0
                THEN
                    OPEN get_hold_id_c;

                    FETCH get_hold_id_c INTO ln_hold_id;

                    CLOSE get_hold_id_c;

                    l_hold_source_rec.hold_id            := ln_hold_id;
                    l_hold_source_rec.hold_entity_code   := 'O';
                    l_hold_source_rec.hold_entity_id     :=
                        l_line_rec.header_id;
                    l_hold_source_rec.line_id            := ln_line_id;
                    l_hold_source_rec.hold_comment       :=
                        'Applying processing hold on Bulk Call off Order';
                    oe_holds_pub.apply_holds (
                        p_api_version        => 1.0,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        p_hold_source_rec    => l_hold_source_rec,
                        x_msg_count          => ln_msg_count,
                        x_msg_data           => lc_msg_data,
                        x_return_status      => lc_return_status);

                    IF ln_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                            'Hold Status: ' || lc_return_status);
                    END IF;

                    IF lc_return_status = 'S'
                    THEN
                        lc_status   := 'NEW';
                        resultout   := 'COMPLETE:BULK';

                        IF ln_debug_level > 0
                        THEN
                            oe_debug_pub.ADD ('Hold Applied');
                        END IF;
                    ELSE
                        FOR i IN 1 .. oe_msg_pub.count_msg
                        LOOP
                            oe_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => lc_msg_data,
                                p_msg_index_out   => ln_msg_index_out);
                            lc_error_message   :=
                                lc_error_message || lc_msg_data;
                        END LOOP;

                        lc_status   := NULL;
                        resultout   := 'COMPLETE:NONBULK';

                        IF ln_debug_level > 0
                        THEN
                            oe_debug_pub.ADD ('Apply Hold Failed');
                            oe_debug_pub.ADD (lc_error_message);
                        END IF;
                    END IF;
                ELSE
                    -- No Bulk Order Lines
                    lc_status          := NULL;
                    lc_error_message   := NULL;
                    resultout          := 'COMPLETE:NONBULK';

                    IF ln_debug_level > 0
                    THEN
                        oe_debug_pub.ADD ('No Bulk Order Lines');
                    END IF;
                END IF;
            ELSE
                -- Not a true Calloff Order
                lc_status          := NULL;
                lc_error_message   := NULL;
                resultout          := 'COMPLETE:NONBULK';

                IF ln_debug_level > 0
                THEN
                    oe_debug_pub.ADD ('Not a true Calloff Order');
                END IF;
            END IF;

            -- Update Status and Error if any
            UPDATE oe_order_lines_all
               SET global_attribute19 = lc_status, global_attribute20 = SUBSTR (lc_error_message, 1, 240), last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE line_id = ln_line_id;
        END IF;

        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('XXD_ONT_VALIDATE_ORDER_LINE', 'XXD_ONT_VALIDATE_ORDER_LINE', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END xxd_ont_validate_order_line;
END xxd_ont_oeol_wf_pkg;
/
