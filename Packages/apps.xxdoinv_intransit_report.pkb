--
-- XXDOINV_INTRANSIT_REPORT  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV_INTRANSIT_REPORT"
AS
    /******************************************************************************************
    * Package          :xxdoinv_intransit_report
    * Author           : BT Technology Team
    * Program Name     : In-Transit Inventory Report - Deckers
    *
    * Modification  :
    *----------------------------------------------------------------------------------------------
    *     Date         Developer           Version     Description
    *----------------------------------------------------------------------------------------------
    * 22-APR-2015    BT Technology Team    V1.1       Package being used for create journals in the GL.
    * 10-JUN-2015    BT Tecruhnology Team  V1.2       Fixed the HPQC Defect#2321
    * 10-Sep-2015    BT Technology Team    V1.3       Fixed the HPQC CR#54
    * 10-Dec-2015    BT Technology Team    V1.3       Fixed the HPQC Defect#672
    * 07-Sep-2016    Infosys               V1.4       Modified for the Incident# INC0309112
    * 21-Sep-2016    Infosys               V1.5       Modified for the Incident# INC0316421 ; Identified by INC0316421
    * 15-May-2019    Aravind Kannuri       V1.6       Changes as per CCR0007955
    * 25-Jun-2019    Greg Jensen           V1.7       Changes as per CCR0007979
    *18-Mar-2021     Tejaswi               V1.8       Changes as per CCR0008870
    *08-Sept-2021    Balavenu              V1.9       Changes as per CCR0009519
    * 28-Jan-2022    Showkath Ali          V2.0       Changes as per CCR0009826 -- Marubeni changes
    ************************************************************************************************/
    g_pkg_name   CONSTANT VARCHAR2 (40) := 'XXDOINV_INTRANSIT_REPORT';
    g_category_set_id     NUMBER;
    g_category_set_name   VARCHAR2 (100) := 'OM Sales Category';
    gc_delimiter          VARCHAR2 (100);             -- Added V1.9 CCR0009519
    gn_request_id         NUMBER := fnd_global.conc_request_id; --Added V1.9 CCR0009519
    gn_user_id            NUMBER := fnd_global.user_id; --Added V1.9 CCR0009519
    gn_login_id           NUMBER := fnd_global.login_id; --Added V1.9 CCR0009519

    -- V2.0 Changes start
    PROCEDURE get_cost_element_values (
        p_organization_id         IN     NUMBER,
        p_brand                   IN     VARCHAR2,
        p_supplier                IN     NUMBER,
        p_vs_count                   OUT NUMBER,
        p_vs_duty_cst                OUT NUMBER,
        p_vs_frt_cst                 OUT NUMBER,
        p_vs_fru_du_cst              OUT NUMBER,
        p_vs_oh_du_cst               OUT NUMBER,
        p_vs_oh_nonduty_cst          OUT NUMBER,
        p_vs_ext_duty_cst            OUT NUMBER,
        p_vs_ext_frt_cst             OUT NUMBER,
        p_vs_ext_fru_du_cst          OUT NUMBER,
        p_vs_ext_oh_du_cst           OUT NUMBER,
        p_vs_ext_oh_nonduty_cst      OUT NUMBER)
    IS
    BEGIN
        --fnd_file.put_line(fnd_file.log,'p_organization_id'||p_organization_id);
        --fnd_file.put_line(fnd_file.log,'p_brand'||p_brand);
        -- fnd_file.put_line(fnd_file.log,'p_supplier'||p_supplier);
        BEGIN
              SELECT ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                     ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                     ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                     ffvl.attribute13, COUNT (1)
                INTO p_vs_duty_cst, p_vs_frt_cst, p_vs_fru_du_cst, p_vs_oh_du_cst,
                                  p_vs_oh_nonduty_cst, p_vs_ext_duty_cst, p_vs_ext_frt_cst,
                                  p_vs_ext_fru_du_cst, p_vs_ext_oh_du_cst, p_vs_ext_oh_nonduty_cst,
                                  p_vs_count
                FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
               WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                     AND fvs.flex_value_set_name =
                         'XXD_INV_INTRANSIT_COST_COMP_VS'
                     AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                         TRUNC (SYSDATE)
                     AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                         TRUNC (SYSDATE)
                     AND ffvl.enabled_flag = 'Y'
                     AND TO_NUMBER (ffvl.attribute1) = p_organization_id
                     AND ffvl.attribute2 = p_brand
                     AND TO_NUMBER (ffvl.attribute3) = p_supplier
            GROUP BY ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                     ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                     ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                     ffvl.attribute13;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                      --fnd_file.put_line(fnd_file.log,'in no data found 1');
                      SELECT ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                             ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                             ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                             ffvl.attribute13, COUNT (1)
                        INTO p_vs_duty_cst, p_vs_frt_cst, p_vs_fru_du_cst, p_vs_oh_du_cst,
                                          p_vs_oh_nonduty_cst, p_vs_ext_duty_cst, p_vs_ext_frt_cst,
                                          p_vs_ext_fru_du_cst, p_vs_ext_oh_du_cst, p_vs_ext_oh_nonduty_cst,
                                          p_vs_count
                        FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                       WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                             AND fvs.flex_value_set_name =
                                 'XXD_INV_INTRANSIT_COST_COMP_VS'
                             AND NVL (TRUNC (ffvl.start_date_active),
                                      TRUNC (SYSDATE)) <=
                                 TRUNC (SYSDATE)
                             AND NVL (TRUNC (ffvl.end_date_active),
                                      TRUNC (SYSDATE)) >=
                                 TRUNC (SYSDATE)
                             AND ffvl.enabled_flag = 'Y'
                             AND TO_NUMBER (ffvl.attribute1) =
                                 p_organization_id
                             AND ffvl.attribute2 = p_brand
                             AND ffvl.attribute3 IS NULL
                    GROUP BY ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                             ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                             ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                             ffvl.attribute13;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                              --fnd_file.put_line(fnd_file.log,'in no data found2');
                              SELECT ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                                     ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                                     ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                                     ffvl.attribute13, COUNT (1)
                                INTO p_vs_duty_cst, p_vs_frt_cst, p_vs_fru_du_cst, p_vs_oh_du_cst,
                                                  p_vs_oh_nonduty_cst, p_vs_ext_duty_cst, p_vs_ext_frt_cst,
                                                  p_vs_ext_fru_du_cst, p_vs_ext_oh_du_cst, p_vs_ext_oh_nonduty_cst,
                                                  p_vs_count
                                FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                               WHERE     fvs.flex_value_set_id =
                                         ffvl.flex_value_set_id
                                     AND fvs.flex_value_set_name =
                                         'XXD_INV_INTRANSIT_COST_COMP_VS'
                                     AND NVL (TRUNC (ffvl.start_date_active),
                                              TRUNC (SYSDATE)) <=
                                         TRUNC (SYSDATE)
                                     AND NVL (TRUNC (ffvl.end_date_active),
                                              TRUNC (SYSDATE)) >=
                                         TRUNC (SYSDATE)
                                     AND ffvl.enabled_flag = 'Y'
                                     AND TO_NUMBER (ffvl.attribute1) =
                                         p_organization_id
                                     AND ffvl.attribute2 IS NULL
                                     AND TO_NUMBER (ffvl.attribute3) =
                                         p_supplier
                            GROUP BY ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                                     ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                                     ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                                     ffvl.attribute13;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                      --fnd_file.put_line(fnd_file.log,'in no data found3');
                                      SELECT ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                                             ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                                             ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                                             ffvl.attribute13, COUNT (1)
                                        INTO p_vs_duty_cst, p_vs_frt_cst, p_vs_fru_du_cst, p_vs_oh_du_cst,
                                                          p_vs_oh_nonduty_cst, p_vs_ext_duty_cst, p_vs_ext_frt_cst,
                                                          p_vs_ext_fru_du_cst, p_vs_ext_oh_du_cst, p_vs_ext_oh_nonduty_cst,
                                                          p_vs_count
                                        FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                       WHERE     fvs.flex_value_set_id =
                                                 ffvl.flex_value_set_id
                                             AND fvs.flex_value_set_name =
                                                 'XXD_INV_INTRANSIT_COST_COMP_VS'
                                             AND NVL (
                                                     TRUNC (
                                                         ffvl.start_date_active),
                                                     TRUNC (SYSDATE)) <=
                                                 TRUNC (SYSDATE)
                                             AND NVL (
                                                     TRUNC (
                                                         ffvl.end_date_active),
                                                     TRUNC (SYSDATE)) >=
                                                 TRUNC (SYSDATE)
                                             AND ffvl.enabled_flag = 'Y'
                                             AND TO_NUMBER (ffvl.attribute1) =
                                                 p_organization_id
                                             AND ffvl.attribute2 IS NULL
                                             AND ffvl.attribute3 IS NULL
                                    GROUP BY ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                                             ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                                             ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                                             ffvl.attribute13;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'In others exception when deriving cost elements from value set'
                                            || SQLERRM);
                                        p_vs_duty_cst             := NULL;
                                        p_vs_fru_du_cst           := NULL;
                                        p_vs_fru_du_cst           := NULL;
                                        p_vs_oh_du_cst            := NULL;
                                        p_vs_oh_nonduty_cst       := NULL;
                                        p_vs_count                := 0;
                                        p_vs_ext_duty_cst         := NULL;
                                        p_vs_ext_frt_cst          := NULL;
                                        p_vs_ext_fru_du_cst       := NULL;
                                        p_vs_ext_oh_du_cst        := NULL;
                                        p_vs_ext_oh_nonduty_cst   := NULL;
                                END;
                        END;
                END;
        END;
    END;

    -- V2.0 Changes end


    PROCEDURE load_temp_table (p_as_of_date       IN     DATE,
                               p_inv_org_id       IN     NUMBER,
                               p_cost_type_id     IN     NUMBER,
                               x_ret_stat            OUT VARCHAR2,
                               x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name      VARCHAR2 (80) := g_pkg_name || '.LOAD_TEMP_TABLE';
        l_cost_type_id   NUMBER;
        l_msg_cnt        NUMBER;
    BEGIN
        do_debug_tools.msg ('+' || l_proc_name);
        do_debug_tools.msg (
               'p_as_of_date='
            || NVL (TO_CHAR (p_as_of_date, 'YYYY-MM-DD'), '{None}')
            || ', p_inv_org_id='
            || p_inv_org_id
            || ', p_cost_type_id='
            || NVL (TO_CHAR (p_cost_type_id), '{None}'));

        BEGIN
            l_cost_type_id   := p_cost_type_id;

            IF l_cost_type_id IS NULL
            THEN
                do_debug_tools.msg (
                    ' looping up cost type from inventory organization.');

                SELECT primary_cost_method
                  INTO l_cost_type_id
                  FROM mtl_parameters
                 WHERE organization_id = p_inv_org_id;

                do_debug_tools.msg (
                       ' found cost type '
                    || l_cost_type_id
                    || ' from inventory organization.');
            END IF;

            do_debug_tools.msg (
                ' before call to CST_Inventory_PUB.Calculate_InventoryValue');
            cst_inventory_pub.calculate_inventoryvalue (
                p_api_version          => 1.0,
                p_init_msg_list        => fnd_api.g_false,
                p_commit               => cst_utility_pub.get_true,
                p_organization_id      => p_inv_org_id,
                p_onhand_value         => 0,
                p_intransit_value      => 1,
                p_receiving_value      => 1,
                p_valuation_date       => TRUNC (NVL (p_as_of_date, SYSDATE) + 1),
                p_cost_type_id         => l_cost_type_id,
                p_item_from            => NULL,
                p_item_to              => NULL--Start modification by BT Technology Team on 9-march-2015  'Styles'as replacement for 'OM sales Category'
                                              --,p_category_set_id      => 4
                                              ,
                p_category_set_id      => g_category_set_id--End modification by BT Technology Team on 9-march-2015  'Styles'as replacement for 'OM sales Category'
                                                           ,
                p_category_from        => NULL,
                p_category_to          => NULL,
                p_cost_group_from      => NULL,
                p_cost_group_to        => NULL,
                p_subinventory_from    => NULL,
                p_subinventory_to      => NULL,
                p_qty_by_revision      => 0,
                p_zero_cost_only       => 0,
                p_zero_qty             => 0,
                p_expense_item         => 0,
                p_expense_sub          => 0,
                p_unvalued_txns        => 0,
                p_receipt              => 1,
                p_shipment             => 1,
                p_detail               => 1,
                p_own                  => 0,
                p_cost_enabled_only    => 0,
                p_one_time_item        => 0,
                p_include_period_end   => NULL,
                x_return_status        => x_ret_stat,
                x_msg_count            => l_msg_cnt,
                x_msg_data             => x_error_messages);
            do_debug_tools.msg (
                ' after call to CST_Inventory_PUB.Calculate_InventoryValue');

            SELECT COUNT (1) INTO l_msg_cnt FROM cst_inv_qty_temp;

            do_debug_tools.msg ('count: ' || l_msg_cnt);
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (' others exception: ' || SQLERRM);
                x_ret_stat         := fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
        END;

        do_debug_tools.msg (
               'x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        do_debug_tools.msg ('-' || l_proc_name);
    END;

    /* ---- start chnage V1.9 CCR0009519 ----------------*/
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    FUNCTION xxdo_cst_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_return_val    NUMBER;
        v_date          DATE;
        v_inv_item_id   VARCHAR2 (50);
        v_org_id        NUMBER;
    BEGIN
        SELECT /*+ optimizer_features_enable('11.2.0.4') */
               new_cost
          INTO v_return_val
          FROM xxdo.xxd_cst_cg_cost_history_temp_t
         WHERE     transaction_id =
                   (SELECT MAX (cst2.transaction_id)
                      FROM xxdo.xxd_cst_cg_cost_history_temp_t cst2
                     WHERE     1 = 1
                           AND cst2.organization_id = p_organization_id
                           AND cst2.inventory_item_id = p_inventory_item_id
                           AND request_id = gn_request_id
                           AND (cst2.transaction_costed_date) =
                               (SELECT MAX (cst1.transaction_costed_date)
                                  FROM xxdo.xxd_cst_cg_cost_history_temp_t cst1
                                 WHERE     1 = 1
                                       AND cst1.organization_id =
                                           p_organization_id
                                       AND cst1.inventory_item_id =
                                           p_inventory_item_id
                                       AND request_id = gn_request_id
                                       AND TRUNC (cst1.transaction_date) <=
                                           p_date))
               AND organization_id = p_organization_id
               AND inventory_item_id = p_inventory_item_id
               AND request_id = gn_request_id;

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_cst_val_fnc;

    FUNCTION xxdo_cst_mat_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_ret_val   NUMBER;
    BEGIN
        SELECT /*+ optimizer_features_enable('11.2.0.4') */
               new_material
          INTO v_ret_val
          FROM xxdo.xxd_cst_cg_cost_history_temp_t
         WHERE     transaction_id =
                   (SELECT MAX (cst2.transaction_id)
                      FROM xxdo.xxd_cst_cg_cost_history_temp_t cst2
                     WHERE     1 = 1
                           AND cst2.organization_id = p_organization_id
                           AND cst2.inventory_item_id = p_inventory_item_id
                           AND request_id = gn_request_id
                           AND (cst2.transaction_costed_date) =
                               (SELECT MAX (cst1.transaction_costed_date)
                                  FROM xxdo.xxd_cst_cg_cost_history_temp_t cst1
                                 WHERE     1 = 1
                                       AND cst1.organization_id =
                                           p_organization_id
                                       AND cst1.inventory_item_id =
                                           p_inventory_item_id
                                       AND TRUNC (cst1.transaction_date) <=
                                           NVL (p_date, SYSDATE)
                                       AND request_id = gn_request_id))
               AND organization_id = p_organization_id
               AND inventory_item_id = p_inventory_item_id
               AND request_id = gn_request_id;

        RETURN v_ret_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_ret_val   := NULL;
            RETURN v_ret_val;
    END xxdo_cst_mat_val_fnc;

    FUNCTION xxdo_cst_mat_oh_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_ret_val   NUMBER;
    BEGIN
        SELECT /*+ optimizer_features_enable('11.2.0.4') */
               new_material_overhead
          INTO v_ret_val
          FROM xxdo.xxd_cst_cg_cost_history_temp_t
         WHERE     transaction_id =
                   (SELECT MAX (cst2.transaction_id)
                      FROM xxdo.xxd_cst_cg_cost_history_temp_t cst2
                     WHERE     1 = 1
                           AND cst2.organization_id = p_organization_id
                           AND cst2.inventory_item_id = p_inventory_item_id
                           AND request_id = gn_request_id
                           AND (cst2.transaction_costed_date) =
                               (SELECT MAX (cst1.transaction_costed_date)
                                  FROM xxdo.xxd_cst_cg_cost_history_temp_t cst1
                                 WHERE     1 = 1
                                       AND cst1.organization_id =
                                           p_organization_id
                                       AND cst1.inventory_item_id =
                                           p_inventory_item_id
                                       AND TRUNC (cst1.transaction_date) <=
                                           NVL (p_date, SYSDATE)
                                       AND request_id = gn_request_id))
               AND organization_id = p_organization_id
               AND inventory_item_id = p_inventory_item_id
               AND request_id = gn_request_id;

        RETURN v_ret_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_ret_val   := NULL;
            RETURN v_ret_val;
    END xxdo_cst_mat_oh_val_fnc;

    /* ---- end chnage V1.9 CCR0009519 ----------------*/

    -- changes starts as per  Defect#672
    FUNCTION get_intransit_qty (p_shipment_line_id   IN NUMBER,
                                p_as_of_date         IN DATE,
                                p_region             IN VARCHAR2,
                                p_intransit_type     IN VARCHAR2, --Added for change v1.8
                                p_source_type        IN VARCHAR2 --Added for change v1.8
                                                                )
        RETURN NUMBER
    IS
        ln_qty                 NUMBER;
        l_shipment_line_id     NUMBER;
        l_quantity_received    NUMBER;
        l_quantity_corrected   NUMBER;
        l_quantity_shipped     NUMBER;
        l_quantity_cancelled   NUMBER;
        l_organization_id      NUMBER;                 --Added for change V1.8
        l_quantity_delivered   NUMBER;                 --Added for change V1.8
        lv_stand_receipt       VARCHAR2 (2);           --Added for change V1.8
    BEGIN
        BEGIN
            SELECT                      --rt.transaction_id AS transaction_id,
                   rsl.shipment_line_id AS shipment_line_id,
                   NVL (
                       (SELECT SUM (rt.quantity)
                          FROM rcv_transactions rt
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsh.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.transaction_type = 'RECEIVE'
                               AND rt.source_document_code = 'PO'
                               AND TRUNC (rt.transaction_date) <=
                                   TRUNC (NVL (p_as_of_date, SYSDATE))),
                       0) AS quantity_received,
                   NVL (
                       (SELECT SUM (rt.quantity)
                          FROM rcv_transactions rt
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsh.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.transaction_type = 'CORRECT'
                               AND destination_type_code = 'RECEIVING'
                               AND rt.source_document_code = 'PO'
                               AND TRUNC (rt.transaction_date) <=
                                   TRUNC (NVL (p_as_of_date, SYSDATE))),
                       0) AS quantity_corrected,
                   NVL (rsl.quantity_shipped, 0) AS quantity_shipped,
                   NVL (
                       (SELECT NVL (ROUND (gl.entered_dr / pol.unit_price), 0) - NVL (rsl.quantity_shipped, 0)
                          FROM gl_je_lines gl
                         WHERE     gl.attribute1 = rsl.shipment_line_id
                               AND rsl.shipment_line_status_code =
                                   'CANCELLED'
                               AND gl.description =
                                      'In Transit'
                                   || '-'
                                   || rsh.shipment_num
                                   || ' '
                                   || rsl.shipment_line_id
                               AND gl.CONTEXT =
                                   'In-Transit Journal ' || p_region
                               AND TRUNC (rsl.last_update_date) >
                                   TRUNC (NVL (p_as_of_date, SYSDATE))),
                       0) AS quantity_cancelled,
                   rsl.to_organization_id              --Added for change v1.8
                                         ,
                   NVL (
                       (SELECT SUM (rt.quantity)
                          FROM rcv_transactions rt
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsh.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.transaction_type = 'DELIVER'
                               AND rt.source_document_code = 'PO'
                               AND TRUNC (rt.transaction_date) <=
                                   TRUNC (NVL (p_as_of_date, SYSDATE))),
                       0) AS quantity_delivered        --Added for change v1.8
              INTO l_shipment_line_id, l_quantity_received, l_quantity_corrected, l_quantity_shipped,
                                     l_quantity_cancelled, l_organization_id, --Added for change v1.8
                                                                              l_quantity_delivered --Added for change v1.8
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, po_headers_all poh,
                   po_lines_all pol
             WHERE     1 = 1
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.po_line_id = rsl.po_line_id
                   AND rsl.shipment_line_id = p_shipment_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN 0;
        END;

        BEGIN
            /*Start of changes for v1.8*/
            SELECT 'Y'
              INTO lv_stand_receipt
              FROM fnd_lookup_values fv, org_organization_definitions ood
             WHERE     fv.lookup_type = 'XDO_PO_STAND_RECEIPT_ORGS'
                   AND fv.LANGUAGE = USERENV ('Lang')
                   AND fv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN fv.start_date_active
                                   AND NVL (fv.end_date_active, SYSDATE)
                   AND ood.organization_code = fv.meaning
                   AND ood.organization_id = l_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_stand_receipt   := 'N';
        END;

        IF NVL (lv_stand_receipt, 'N') = 'Y' AND p_intransit_type IS NULL
        THEN
            ln_qty   :=
                  l_quantity_shipped
                + l_quantity_cancelled
                - l_quantity_delivered
                - l_quantity_corrected;
        ELSIF     NVL (lv_stand_receipt, 'N') = 'Y'
              AND p_intransit_type = 'Shipped'
        THEN
            ln_qty   :=
                  l_quantity_shipped
                + l_quantity_cancelled
                - l_quantity_received
                - l_quantity_corrected;
        ELSIF     NVL (lv_stand_receipt, 'N') = 'Y'
              AND p_intransit_type = 'Received'
        THEN
            ln_qty   := l_quantity_received - l_quantity_delivered;
        ELSE
            ln_qty   :=
                  l_quantity_shipped
                + l_quantity_cancelled
                - l_quantity_received
                - l_quantity_corrected;
        END IF;

        /*End of changes for v1.8*/

        --Commented for changes 1.8
        /* ln_qty :=
              l_quantity_shipped
            + l_quantity_cancelled
            - l_quantity_received
            - l_quantity_corrected;*/
        IF ln_qty < 0
        THEN
            RETURN 0;
        ELSE
            RETURN ln_qty;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                   'Others Exception in get_intransit_qty function,so returning zero for shipment line id - '
                || p_shipment_line_id
                || '  '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
            RETURN 0;
    END get_intransit_qty;

    -- changes ends as per  Defect#672

    --change as per CR#54 starts
    FUNCTION get_duty_cost (p_organization_id       IN NUMBER,
                            p_inventory_item_id     IN NUMBER,
                            p_po_header_id          IN NUMBER,
                            p_po_line_id            IN NUMBER,
                            p_po_line_location_id   IN NUMBER)
        RETURN NUMBER
    IS
        ln_itemcost             NUMBER;
        ln_dutyrate             NUMBER;
        ln_dutyfactor           NUMBER;
        ln_ohduty               NUMBER;
        ln_freight_du           NUMBER;
        ln_unitprice            NUMBER;
        ln_firstsale            NUMBER;
        ln_amount               NUMBER;
        ---change for CR#54starts
        ln_unit_selling_price   NUMBER := 0;
        ln_duty                 NUMBER := 0;
        ln_ohduty_rate          NUMBER := 0;
        ln_ohduty_final         NUMBER := 0;
        ln_freight_du_rate      NUMBER := 0;
        ln_freight_du_final     NUMBER := 0;
        ln_dutyrate_base        NUMBER := 0;
        ln_duty_base            NUMBER := 0;
    --change for CR#54ends
    BEGIN
        BEGIN
            SELECT /* NVL (pll.attribute11, 0),
                    NVL (pll.attribute12, 0),
                    NVL (pll.attribute13, 0),
                    NVL (pll.attribute14, 0),
                    NVL (pl.attribute12, 0),
                    pl.unit_price * NVL (rate, 1)
               INTO ln_dutyrate,
                    ln_dutyfactor,
                    ln_ohduty,
                    ln_freight_du,
                    ln_firstsale,
                    ln_unitprice*/
                   --commented for CR#54
                   --change for CR#54starts
                   NVL (pll.attribute11,
                        xxdoget_item_cost ('DUTY', p_organization_id, p_inventory_item_id
                                           , 'Y')),
                   NVL (
                       pll.attribute12,
                       NVL (
                           (SELECT MAX (additional_duty)
                              FROM xxdo.xxdo_invval_duty_cost
                             WHERE     inventory_org = p_organization_id
                                   AND inventory_item_id =
                                       p_inventory_item_id
                                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                   NVL (
                                                                       duty_start_date,
                                                                       SYSDATE))
                                                           AND TRUNC (
                                                                   NVL (
                                                                       duty_end_date,
                                                                       SYSDATE))),
                           0)),
                   NVL (pll.attribute13,
                        xxdoget_item_cost ('OH DUTY', p_organization_id, p_inventory_item_id
                                           , 'Y')),
                   NVL (pll.attribute14,
                        xxdoget_item_cost ('FREIGHT DU', p_organization_id, p_inventory_item_id
                                           , 'Y')),
                   NVL (  pll.attribute11
                        * xxdoget_item_cost ('DUTY FACTOR', p_organization_id, p_inventory_item_id
                                             , 'Y'),
                        xxdoget_item_cost ('DUTY RATE', p_organization_id, p_inventory_item_id
                                           , 'Y')),
                   NVL (  pll.attribute13
                        * xxdoget_item_cost ('OH DUTY FACTOR', p_organization_id, p_inventory_item_id
                                             , 'Y'),
                        xxdoget_item_cost ('OH DUTY RATE', p_organization_id, p_inventory_item_id
                                           , 'Y')),
                   NVL (  pll.attribute14
                        * xxdoget_item_cost ('FREIGHT DU FACTOR', p_organization_id, p_inventory_item_id
                                             , 'Y'),
                        xxdoget_item_cost ('FREIGHT DU RATE', p_organization_id, p_inventory_item_id
                                           , 'Y')),
                   xxdoget_item_cost ('DUTY RATE', p_organization_id, p_inventory_item_id
                                      , 'Y'),
                   xxdoget_item_cost ('DUTY', p_organization_id, p_inventory_item_id
                                      , 'Y'),
                   pl.attribute12
                       first_sale,
                   pl.unit_price
              INTO ln_duty, ln_dutyfactor, ln_ohduty, ln_freight_du,
                          ln_dutyrate, ln_ohduty_rate, ln_freight_du_rate,
                          ln_dutyrate_base, ln_duty_base, ln_firstsale,
                          ln_unitprice
              --change for CR#54ends
              FROM po_headers_all ph, po_lines_all pl, po_line_locations_all pll
             WHERE     1 = 1
                   AND ph.po_header_id = pl.po_header_id
                   AND pl.po_line_id = pll.po_line_id
                   AND pl.po_line_id = p_po_line_id
                   AND pll.line_location_id = p_po_line_location_id
                   AND pl.item_id = p_inventory_item_id
                   AND ph.po_header_id = p_po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_dutyrate     := 0;
                ln_dutyfactor   := 0;
                ln_ohduty       := 0;
                ln_freight_du   := 0;
                ln_firstsale    := 0;
                ln_unitprice    := 0;
        END;

        /* ln_itemcost :=
            (  ln_dutyrate
             * (ln_unitprice + ln_dutyfactor + ln_ohduty + ln_freight_du));*/
        --commented for CR#54
        --change for CR#54starts
        ln_ohduty_final   :=
            NVL ((ln_ohduty_rate * NVL (ln_firstsale, ln_unitprice)),
                 NVL (ln_ohduty, 0));
        ln_freight_du_final   :=
            NVL ((ln_freight_du_rate * NVL (ln_firstsale, ln_unitprice)),
                 NVL (ln_freight_du, 0));
        ln_itemcost   :=
            NVL (
                (ln_dutyrate * (NVL (ln_firstsale, ln_unitprice) + ln_dutyfactor + ln_ohduty_final + ln_freight_du_final)),
                NVL (ln_duty, 0));
        --change for CR#54ends
        RETURN ln_itemcost;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                   'Others Exception in get_amount function,so returning zero for item - '
                || p_inventory_item_id
                || '  '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
            RETURN 0;
    END get_duty_cost;

    --change as per CR#54  ends
    PROCEDURE run_intransit_report (
        psqlstat                     OUT VARCHAR2,
        perrproc                     OUT VARCHAR2,
        p_inv_org_id              IN     NUMBER,
        p_region                  IN     VARCHAR2,
        p_as_of_date              IN     VARCHAR2,
        p_cost_type_id            IN     NUMBER,
        p_brand                   IN     VARCHAR2,
        p_show_color              IN     VARCHAR2,
        p_shipment_num            IN     VARCHAR2,    --aded as per defect#672
        p_show_supplier_details   IN     VARCHAR2,
        -- , p_markup_rate_type in varchar2
        -- , p_elimination_org in varchar2
        -- , p_elimination_rate in varchar2
        --, p_user_rate in number
        p_source_type             IN     VARCHAR2,     --Added for change V1.8
        p_intransit_type          IN     VARCHAR2,     --Added for change V1.8
        p_debug_level             IN     NUMBER := NULL,
        p_material_cost_for_pos   IN     VARCHAR2                      -- V2.0
                                                 )
    IS
        l_proc_name                             VARCHAR2 (80) := g_pkg_name || '.RUN_INTRANSIT_REPORT';
        l_ret_stat                              VARCHAR2 (1);
        l_err_messages                          VARCHAR2 (2000);
        l_use_date                              DATE;
        l_cnt                                   NUMBER;
        v_org_region                            VARCHAR2 (10);
        w_organization_code            CONSTANT NUMBER := 10;
        w_brand                        CONSTANT NUMBER := 10;
        w_style                        CONSTANT NUMBER := 15;
        w_color                        CONSTANT NUMBER := 10;
        w_quantity                     CONSTANT NUMBER := 10;
        w_item_cost                    CONSTANT NUMBER := 10;
        w_material_cost                CONSTANT NUMBER := 10;
        w_material_overhead_cost       CONSTANT NUMBER := 10;
        w_freight_cost                 CONSTANT NUMBER := 10;
        w_duty_cost                    CONSTANT NUMBER := 10;
        w_vendor                       CONSTANT NUMBER := 25;
        w_vendor_reference             CONSTANT NUMBER := 30;
        w_ext_item_cost                CONSTANT NUMBER := 15;
        w_ext_material_cost            CONSTANT NUMBER := 15;
        w_ext_material_overhead_cost   CONSTANT NUMBER := 15;
        w_ext_freight_cost             CONSTANT NUMBER := 15;
        w_ext_duty_cost                CONSTANT NUMBER := 15;
        w_type                         CONSTANT NUMBER := 15;
        w_trx_date                     CONSTANT NUMBER := 10;
        l_fact_invoice_num                      VARCHAR2 (50);
        -- V2.0 changes start
        ln_vs_count                             NUMBER := 0;
        ln_vs_duty_cst                          NUMBER := 0;
        ln_vs_frt_cst                           NUMBER := 0;
        ln_vs_fru_du_cst                        NUMBER := 0;
        ln_vs_oh_du_cst                         NUMBER := 0;
        ln_vs_oh_nonduty_cst                    NUMBER := 0;
        ln_vs_ext_duty_cst                      NUMBER := 0;
        ln_vs_ext_frt_cst                       NUMBER := 0;
        ln_vs_ext_fru_du_cst                    NUMBER := 0;
        ln_vs_ext_oh_du_cst                     NUMBER := 0;
        ln_vs_ext_oh_nonduty_cst                NUMBER := 0;
        ln_duty_cst                             NUMBER := 0;
        ln_frt_cst                              NUMBER := 0;
        ln_fru_du_cst                           NUMBER := 0;
        ln_oh_du_cst                            NUMBER := 0;
        ln_oh_nonduty_cst                       NUMBER := 0;
        ln_ext_duty_cst                         NUMBER := 0;
        ln_ext_frt_cst                          NUMBER := 0;
        ln_ext_fru_du_cst                       NUMBER := 0;
        ln_ext_oh_du_cst                        NUMBER := 0;
        ln_ext_oh_nonduty_cst                   NUMBER := 0;
        ln_item_cst                             NUMBER := 0;
        ln_ext_item_cst                         NUMBER := 0;

        -- V2.0 changes end

        CURSOR c_inv_orgs IS
            SELECT mp.organization_id, mp.organization_code, mp.attribute1 region
              FROM apps.mtl_parameters mp
             WHERE mp.organization_id = NVL (p_inv_org_id, -1)
            UNION
            SELECT mp.organization_id, mp.organization_code, mp.attribute1
              FROM apps.mtl_parameters mp, hr_all_organization_units haou
             WHERE     mp.attribute1 = p_region
                   AND p_inv_org_id IS NULL
                   AND haou.organization_id = mp.organization_id
                   AND NVL (haou.date_to, SYSDATE + 1) >= TRUNC (SYSDATE)
                   AND EXISTS
                           (SELECT NULL
                              FROM mtl_secondary_inventories msi
                             WHERE msi.organization_id = mp.organization_id)
            ORDER BY organization_code;

        /*---------------START V1.9 CCR0009519--------------*/
        CURSOR c_inst (p_use_date DATE)
        IS
            SELECT /*+ parallel(8) optimizer_features_enable('11.2.0.4') */
                   new_cost, transaction_id, organization_id,
                   inventory_item_id, transaction_date, transaction_costed_date,
                   new_material, new_material_overhead
              FROM cst_cg_cost_history_v
             WHERE     transaction_date < p_use_date + 1         -- CCR0009826
                   AND organization_id = p_inv_org_id;


        TYPE xxd_ins_type IS TABLE OF c_inst%ROWTYPE;


        v_ins_type                              xxd_ins_type
                                                    := xxd_ins_type ();
        lv_status                               VARCHAR2 (10) := 'S';
        lv_error_code                           VARCHAR2 (4000) := NULL;
        ln_error_num                            NUMBER;
        lv_error_msg                            VARCHAR2 (4000) := NULL;
        lv_tem_load                             VARCHAR2 (10) := 'N';
        lv_orc_tmp_load                         VARCHAR2 (10) := 'Y';

        /*---------------END V1.9 CCR0009519--------------*/

        CURSOR c_rpt_lines (l_curr_inv_org_id NUMBER)
        IS
            -- Start Changes by BT Technology Team on 10-JUN-2015 for Defect#2321
            SELECT organization_code, organization_id,                 -- V2.0
                                                       brand,
                   style, color, item_type,
                   quantity, item_cost, material_cost,
                   DECODE (item_cost, 0, 0, duty_cost) duty_cost, DECODE (item_cost, 0, 0, freight_cost) freight_cost, DECODE (item_cost, 0, 0, freight_du_cost) freight_du_cost,
                   DECODE (item_cost, 0, 0, oh_duty_cst) oh_duty_cst, DECODE (item_cost, 0, 0, oh_non_duty_cst) oh_non_duty_cst, intransit_type,
                   vendor, vendor_id,                                  -- V2.0
                                      vendor_reference,
                   transaction_date, ext_item_cost, ext_material_cost,
                   DECODE (item_cost, 0, 0, ext_duty_cost) ext_duty_cost, DECODE (item_cost, 0, 0, ext_freight_cost) ext_freight_cost, DECODE (item_cost, 0, 0, ext_freight_du_cost) ext_freight_du_cost,
                   DECODE (item_cost, 0, 0, ext_oh_duty_cst) ext_oh_duty_cst, DECODE (item_cost, 0, 0, ext_oh_non_duty_cst) ext_oh_non_duty_cst, po_header_id,
                   po_line_id, po_line_location_id, packing_slip  --CCR0007979
              FROM (SELECT /*+ use_nl leading (rsh) parallel(8) */
                           organization_code,
                           organization_id,                            -- V2.0
                           brand,
                           style,
                           color,
                           item_type,
                           quantity,
                           ROUND (item_cost, 4)
                               item_cost,
                           ROUND (material_cost, 4)
                               material_cost,
                           -- Start changes by BT Technology Team on 10-Dec-2015 for defect#672
                           /*ROUND (
                                material_overhead_cost
                              - (  freight_cost
                                 + freight_du_cost
                                 + oh_duty_cst
                                 + oh_non_duty_cst),
                              4)
                              duty_cost,
                           ROUND (freight_cost, 4) freight_cost,
                           ROUND (freight_du_cost, 4) freight_du_cost,
                           ROUND (oh_duty_cst, 4) oh_duty_cst,
                           ROUND (oh_non_duty_cst, 4) oh_non_duty_cst,*/
                           -- Start Changed the Order of fetching columns duty cost and Freight cost as per incident INC0316421
                           CASE
                               WHEN (  material_overhead_cost
                                     - (  CASE
                                              WHEN material_overhead_cost >
                                                   freight_du_cost
                                              THEN
                                                  freight_du_cost
                                              ELSE
                                                  material_overhead_cost
                                          END
                                        + CASE
                                              WHEN freight_cost >
                                                     material_overhead_cost
                                                   - freight_du_cost
                                              THEN
                                                    material_overhead_cost
                                                  - freight_du_cost
                                              ELSE
                                                  freight_cost
                                          END
                                        + CASE
                                              WHEN oh_duty_cst >
                                                     material_overhead_cost
                                                   - freight_du_cost
                                                   - freight_cost
                                              THEN
                                                    material_overhead_cost
                                                  - freight_du_cost
                                                  - freight_cost
                                              ELSE
                                                  oh_duty_cst
                                          END
                                        + CASE
                                              WHEN oh_non_duty_cst >
                                                     material_overhead_cost
                                                   - freight_du_cost
                                                   - freight_cost
                                                   - oh_duty_cst
                                              THEN
                                                    material_overhead_cost
                                                  - freight_du_cost
                                                  - freight_cost
                                                  - oh_duty_cst
                                              ELSE
                                                  oh_non_duty_cst
                                          END)) <
                                    0
                               THEN
                                   0
                               ELSE
                                   (  material_overhead_cost
                                    - (  CASE
                                             WHEN material_overhead_cost >
                                                  freight_du_cost
                                             THEN
                                                 freight_du_cost
                                             ELSE
                                                 material_overhead_cost
                                         END
                                       + CASE
                                             WHEN freight_cost >
                                                    material_overhead_cost
                                                  - freight_du_cost
                                             THEN
                                                   material_overhead_cost
                                                 - freight_du_cost
                                             ELSE
                                                 freight_cost
                                         END
                                       + CASE
                                             WHEN oh_duty_cst >
                                                    material_overhead_cost
                                                  - freight_du_cost
                                                  - freight_cost
                                             THEN
                                                   material_overhead_cost
                                                 - freight_du_cost
                                                 - freight_cost
                                             ELSE
                                                 oh_duty_cst
                                         END
                                       + CASE
                                             WHEN oh_non_duty_cst >
                                                    material_overhead_cost
                                                  - freight_du_cost
                                                  - freight_cost
                                                  - oh_duty_cst
                                             THEN
                                                   material_overhead_cost
                                                 - freight_du_cost
                                                 - freight_cost
                                                 - oh_duty_cst
                                             ELSE
                                                 oh_non_duty_cst
                                         END))
                           END
                               duty_cost,
                           CASE
                               WHEN freight_cost >
                                    material_overhead_cost - freight_du_cost
                               THEN
                                   material_overhead_cost - freight_du_cost
                               ELSE
                                   freight_cost
                           END
                               freight_cost,
                           -- End Changed the Order of fetching columns duty cost and Freight cost as per incident INC0316421
                           CASE
                               WHEN material_overhead_cost > freight_du_cost
                               THEN
                                   freight_du_cost
                               ELSE
                                   material_overhead_cost
                           END
                               freight_du_cost,
                           CASE
                               WHEN oh_duty_cst >
                                      material_overhead_cost
                                    - freight_du_cost
                                    - freight_cost
                               THEN
                                     material_overhead_cost
                                   - freight_du_cost
                                   - freight_cost
                               ELSE
                                   oh_duty_cst
                           END
                               oh_duty_cst,
                           CASE
                               WHEN oh_non_duty_cst >
                                      material_overhead_cost
                                    - freight_du_cost
                                    - freight_cost
                                    - oh_duty_cst
                               THEN
                                     material_overhead_cost
                                   - freight_du_cost
                                   - freight_cost
                                   - oh_duty_cst
                               ELSE
                                   oh_non_duty_cst
                           END
                               oh_non_duty_cst,
                           -- End changes by BT Technology Team on 10-Dec-2015 for defect#672
                           'Requisition'
                               AS intransit_type,
                           DECODE (
                               p_show_supplier_details,
                               'N', NULL,
                               (SELECT organization_code
                                  FROM mtl_parameters
                                 WHERE organization_id =
                                       alpha.from_organization_id))
                               AS vendor,
                           NULL
                               vendor_id,                              -- V2.0
                           DECODE (
                               p_show_supplier_details,
                               'N', NULL,
                                  'Req#'
                               || (SELECT MAX (prha.segment1)
                                     FROM po_requisition_headers_all prha, po_requisition_lines_all prla
                                    WHERE     prha.requisition_header_id =
                                              prla.requisition_header_id
                                          AND prla.requisition_line_id =
                                              alpha.max_req_line_id))
                               AS vendor_reference,
                           transaction_date,
                           ROUND (quantity * item_cost, 4)
                               ext_item_cost,
                           ROUND (quantity * material_cost, 4)
                               ext_material_cost,
                           ROUND (
                                 quantity
                               * (material_overhead_cost - (freight_cost + freight_du_cost + oh_duty_cst + oh_non_duty_cst)))
                               ext_duty_cost,
                           ROUND (quantity * freight_cost, 4)
                               ext_freight_cost,
                           ROUND (quantity * freight_du_cost, 4)
                               ext_freight_du_cost,
                           ROUND (quantity * oh_duty_cst, 4)
                               ext_oh_duty_cst,
                           ROUND (quantity * oh_non_duty_cst, 4)
                               ext_oh_non_duty_cst,
                           po_header_id,
                           po_line_id,
                           po_line_location_id,
                           packing_slip                           --CCR0007979
                      FROM (  SELECT citv.brand
                                         AS brand         -- mc.segment1 brand
                                                 ,
                                     mp.organization_code,
                                     mp.organization_id,               -- V2.0
                                     citv.style_number
                                         AS style,
                                     DECODE (p_show_color,
                                             'N', NULL,
                                             citv.color_code)
                                         AS color,
                                     citv.item_type,
                                     --SUM (qty.rollback_qty) --Commented for change v1.8
                                     DECODE (
                                         p_intransit_type,
                                         NULL, SUM (qty.rollback_qty),
                                         'Shipped', SUM (
                                                          rsl.quantity_shipped
                                                        - rsl.quantity_received),
                                         'Received',   (SELECT NVL (SUM (quantity), 0)
                                                          FROM rcv_transactions
                                                         WHERE     shipment_line_id =
                                                                   rsl.shipment_line_id
                                                               AND transaction_type =
                                                                   'RECEIVE')
                                                     - (SELECT NVL (SUM (quantity), 0)
                                                          FROM rcv_transactions
                                                         WHERE     shipment_line_id =
                                                                   rsl.shipment_line_id
                                                               AND transaction_type =
                                                                   'DELIVER'))
                                         quantity,     --Added for change v1.8
                                     -- Start changes by BT Technology Team on 10-Dec-2015 for defect#672
                                     /*xxdoget_item_cost ('ITEMCOST',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'N')
                                        item_cost,
                                     xxdoget_item_cost ('MATERIAL_COST',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'Y')
                                        material_cost,
                                     xxdoget_item_cost ('TOTAL OVERHEAD',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'Y')
                                        material_overhead_cost,
                                     xxdoget_item_cost ('FREIGHT',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'Y')
                                        freight_cost,
                                     xxdoget_item_cost ('FREIGHT DU',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'Y')
                                        freight_du_cost,
                                     xxdoget_item_cost ('OH DUTY',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'Y')
                                        OH_Duty_Cst,
                                     xxdoget_item_cost ('OH NONDUTY',
                                                        cost.organization_id,
                                                        cost.inventory_item_id,
                                                        'Y')
                                        OH_Non_Duty_Cst,*/
                                     --START changes as per V1.6
                                     /* xxd_fg_inv_val_rpt_pkg.xxdo_cst_val_fnc (
                                         cost.inventory_item_id,
                                         cost.organization_id,
                                         l_use_date)
                                         item_cost,
                                      xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc (
                                         cost.inventory_item_id,
                                         cost.organization_id,
                                         l_use_date)
                                         material_cost,  -- NULL
                                      xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_oh_val_fnc (
                                         cost.inventory_item_id,
                                         cost.organization_id,
                                         l_use_date)
                                         material_overhead_cost,  -- NULL  */
                                     /* xxd_fg_inv_val_rpt_pkg.xxdo_cst_val_fnc
                                               (COST.inventory_item_id,
                                                COST.organization_id,
                                                rsh.shipped_date
                                               ) */
                                     -- commented for V1.9 CCR0009519
                                     XXDOINV_INTRANSIT_REPORT.xxdo_cst_val_fnc (
                                         COST.inventory_item_id,
                                         COST.organization_id,
                                         l_use_date --rsh.shipped_date -- CCR0009826
                                                   )
                                         item_cost,   -- Added V1.9 CCR0009519
                                     /*xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc
                                          (COST.inventory_item_id,
                                           COST.organization_id,
                                           rsh.shipped_date -- commented for V1.9 CCR0009519
                                          ) */
                                     XXDOINV_INTRANSIT_REPORT.xxdo_cst_mat_val_fnc (
                                         COST.inventory_item_id,
                                         COST.organization_id,
                                         l_use_date --rsh.shipped_date -- CCR0009826
                                                   )
                                         material_cost, -- Added for V1.9 CCR0009519
                                     /*xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_oh_val_fnc
                                        (COST.inventory_item_id,
                                         COST.organization_id,
                                         rsh.shipped_date
                                        )*/
                                     -- commented for V1.9 CCR0009519
                                     XXDOINV_INTRANSIT_REPORT.xxdo_cst_mat_oh_val_fnc (
                                         COST.inventory_item_id,
                                         COST.organization_id,
                                         l_use_date --rsh.shipped_date -- CCR0009826
                                                   )
                                         material_overhead_cost, -- Added for V1.9 CCR0009519
                                     --END changes as per V1.6
                                     NVL (
                                         (  xxdoget_item_cost ('FREIGHT FACTOR', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          * xxdoget_item_cost ('FREIGHT RATE', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          /*--START changes as per V1.6
                                                                       * xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc (
                                                                            cost.inventory_item_id,
                                                                            cost.organization_id,
                                                                            l_use_date)),  */
                                          * --xxd_fg_inv_val_rpt_pkg
                                            XXDOINV_INTRANSIT_REPORT.xxdo_cst_mat_val_fnc (
                                                COST.inventory_item_id,
                                                COST.organization_id,
                                                l_use_date --rsh.shipped_date CCR0009826
                                                          ) -- Added for V1.9 CCR0009519
                                                           ),
                                         /* NVL (
                                             xxdoget_item_cost (
                                                'FREIGHT',
                                                cost.organization_id,
                                                cost.inventory_item_id,
                                                'Y'),
                                             0))
                                          freight_cost, */
                                         NVL (TO_NUMBER (rsl.attribute7),
                                              NVL (xxdoget_item_cost ('FREIGHT', COST.organization_id, COST.inventory_item_id
                                                                      , 'Y'),
                                                   0)))
                                         freight_cost,
                                     --END changes as per V1.6
                                     NVL (
                                         (  xxdoget_item_cost ('FREIGHT DU FACTOR', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          * xxdoget_item_cost ('FREIGHT DU RATE', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          /*--START changes as per V1.6
                                                                       * xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc (
                                                                            cost.inventory_item_id,
                                                                            cost.organization_id,
                                                                            l_use_date)),  */
                                          * XXDOINV_INTRANSIT_REPORT.xxdo_cst_mat_val_fnc (
                                                COST.inventory_item_id,
                                                COST.organization_id,
                                                l_use_date --rsh.shipped_date -- CCR0009826
                                                          ) --Added for V1.9 CCR0009519
                                                           ),
                                         /*NVL (
                                            xxdoget_item_cost (
                                               'FREIGHT DU',
                                               cost.organization_id,
                                               cost.inventory_item_id,
                                               'Y'),
                                            0))
                                         freight_du_cost, */
                                         NVL (TO_NUMBER (rsl.attribute8),
                                              NVL (xxdoget_item_cost ('FREIGHT DU', COST.organization_id, COST.inventory_item_id
                                                                      , 'Y'),
                                                   0)))
                                         freight_du_cost,
                                     --END changes as per V1.6
                                     NVL (
                                         (  xxdoget_item_cost ('OH DUTY FACTOR', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          * xxdoget_item_cost ('OH DUTY RATE', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          /*--START changes as per V1.6
                                                                       * xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc (
                                                                            cost.inventory_item_id,
                                                                            cost.organization_id,
                                                                            l_use_date)),  */
                                          * XXDOINV_INTRANSIT_REPORT.xxdo_cst_mat_val_fnc (
                                                COST.inventory_item_id,
                                                COST.organization_id,
                                                l_use_date --rsh.shipped_date -- CCR0009826
                                                          ) --Added for V1.9 CCR0009519
                                                           ),
                                         /*NVL (
                                            xxdoget_item_cost (
                                               'OH DUTY',
                                               cost.organization_id,
                                               cost.inventory_item_id,
                                               'Y'),
                                            0))
                                         oh_duty_cst,*/
                                         NVL (TO_NUMBER (rsl.attribute9),
                                              NVL (xxdoget_item_cost ('OH DUTY', COST.organization_id, COST.inventory_item_id
                                                                      , 'Y'),
                                                   0)))
                                         oh_duty_cst,
                                     --END changes as per V1.6
                                     NVL (
                                         (  xxdoget_item_cost ('OH NONDUTY FACTOR', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          * xxdoget_item_cost ('OH NONDUTY RATE', COST.organization_id, COST.inventory_item_id
                                                               , 'Y')
                                          /*--START changes as per V1.6
                                                                       * xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc (
                                                                            cost.inventory_item_id,
                                                                            cost.organization_id,
                                                                            l_use_date)),  */
                                          * XXDOINV_INTRANSIT_REPORT.xxdo_cst_mat_val_fnc (
                                                COST.inventory_item_id,
                                                COST.organization_id,
                                                l_use_date -- rsh.shipped_date -- CCR0009826
                                                          ) -- Added for V1.9 CCR0009519
                                                           ),
                                         /* NVL (
                                             xxdoget_item_cost (
                                                'OH NONDUTY',
                                                cost.organization_id,
                                                cost.inventory_item_id,
                                                'Y'),
                                             0))
                                          oh_non_duty_cst,*/
                                         NVL (TO_NUMBER (rsl.attribute10),
                                              NVL (xxdoget_item_cost ('OH NONDUTY', COST.organization_id, COST.inventory_item_id
                                                                      , 'Y'),
                                                   0)))
                                         oh_non_duty_cst,
                                     --END changes as per V1.6
                                     -- End changes by BT Technology Team on 10-Dec-2015 for defect#672
                                     DECODE (p_show_supplier_details,
                                             'N', NULL,
                                             qty.from_organization_id)
                                         AS from_organization_id,
                                     DECODE (p_show_supplier_details,
                                             'N', NULL,
                                             rsh.shipment_num)
                                         AS shipment_num,
                                     MAX (rsl.requisition_line_id)
                                         AS max_req_line_id,
                                     -- Changes Start INC0316421
                                     --DECODE (p_show_supplier_details,
                                     --      'N', NULL,
                                     --    rsh.shipped_date)
                                     rsh.shipped_date
                                         AS transaction_date,
                                     -- CHanges End INC0316421
                                     rsl.po_header_id,
                                     rsl.po_line_id,
                                     rsl.po_line_location_id,
                                     rsl.packing_slip             --CCR0007979
                                FROM cst_item_list_temp item, cst_inv_qty_temp qty, xxd_common_items_v citv,
                                     mtl_parameters mp, cst_inv_cost_temp COST, rcv_shipment_lines rsl,
                                     rcv_shipment_headers rsh
                               WHERE     qty.inventory_item_id =
                                         item.inventory_item_id
                                     AND qty.cost_type_id = item.cost_type_id
                                     AND qty.organization_id =
                                         l_curr_inv_org_id
                                     AND citv.organization_id =
                                         qty.organization_id
                                     AND citv.inventory_item_id =
                                         qty.inventory_item_id
                                     AND citv.category_set_id = 1
                                     AND citv.brand LIKE NVL (p_brand, '%')
                                     --AND qty.qty_source = 6 -- Back-to-back only -- Commented by BT Technology Team on 10-Dec-2015 for defect#672
                                     AND mp.organization_id =
                                         qty.organization_id
                                     AND rsh.shipment_num =
                                         NVL (p_shipment_num, rsh.shipment_num) --added as per defect#672
                                     AND COST.organization_id(+) =
                                         qty.organization_id
                                     AND COST.inventory_item_id(+) =
                                         qty.inventory_item_id
                                     AND COST.cost_type_id(+) =
                                         qty.cost_type_id
                                     AND rsl.shipment_line_id =
                                         qty.shipment_line_id
                                     AND rsh.shipment_header_id =
                                         rsl.shipment_header_id
                                     AND (rsh.shipped_date IS NOT NULL AND rsh.shipped_date < TO_DATE (NVL (l_use_date, SYSDATE)) + 1)
                                     AND rsl.creation_date <
                                           TO_DATE (
                                               NVL (l_use_date,
                                                    TRUNC (SYSDATE)))
                                         + 1      -- Added for V1.9 CCR0009519
                                     --roll forward date added as per Vishwa's confirmation
                                     AND 1 =
                                         DECODE (p_source_type,
                                                 '', 1,
                                                 'Requisition', 1,
                                                 0)     --Added for chage v1.8
                            GROUP BY citv.brand, mp.organization_code, mp.organization_id, -- V2.0
                                     citv.style_number, citv.item_type, DECODE (p_show_color, 'N', NULL, citv.color_code),
                                     DECODE (p_show_supplier_details, 'N', NULL, qty.from_organization_id), DECODE (p_show_supplier_details, 'N', NULL, rsh.shipment_num), --Changes Start INC0316421
                                                                                                                                                                           --DECODE (p_show_supplier_details,
                                                                                                                                                                           --        'N', NULL,
                                                                                                                                                                           --        rsh.shipped_date),
                                                                                                                                                                           rsh.shipped_date,
                                     --Changes End INC0316421
                                     COST.organization_id, COST.inventory_item_id, rsl.po_header_id,
                                     rsl.po_line_id, rsl.po_line_location_id, rsl.packing_slip, --CCR0007979
                                     rsl.shipment_line_id, --START changes as per V1.6
                                                           rsl.attribute7, rsl.attribute8,
                                     rsl.attribute9, rsl.attribute10
                              --START changes as per V1.6
                              HAVING --SUM (qty.rollback_qty) > 0 --Commented for change v1.8
                                      DECODE (
                                         p_intransit_type,
                                         NULL, SUM (qty.rollback_qty),
                                         'Shipped', SUM (
                                                          rsl.quantity_shipped
                                                        - rsl.quantity_received),
                                         'Received',   (SELECT NVL (SUM (quantity), 0)
                                                          FROM rcv_transactions
                                                         WHERE     shipment_line_id =
                                                                   rsl.shipment_line_id
                                                               AND transaction_type =
                                                                   'RECEIVE')
                                                     - (SELECT NVL (SUM (quantity), 0)
                                                          FROM rcv_transactions
                                                         WHERE     shipment_line_id =
                                                                   rsl.shipment_line_id
                                                               AND transaction_type =
                                                                   'DELIVER')) >
                                     0                 --Added for change v1.8
                                      ) alpha
                    UNION ALL
                    SELECT mp.organization_code
                               AS organization_code,
                           mp.organization_id,                         -- V2.0
                           citv.brand
                               AS brand,
                           citv.style_number
                               AS style,
                           DECODE (p_show_color, 'N', NULL, citv.color_code)
                               AS color,
                           citv.item_type,
                           COST.quantity
                               AS quantity,
                           --change ends as per defect#672
                           /*ROUND (xxdoget_item_cost ('ITEMCOST',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'N'),
                                  4)
               ROUND (xxdoget_item_cost ('MATERIAL_COST',
                                                      cost.organization_id,
                                                      cost.inventory_item_id,
                                                      'Y'),
                                   4) */
                           --START Changes as per V1.6
                           /*
                                             ROUND (  cost.unit_price
                                                    + get_duty_cost (cost.organization_id,
                                                                     cost.inventory_item_id,
                                                                     po_header_id,
                                                                     po_line_id,
                                                                     po_line_location_id)
                                                    + xxdoget_item_cost ('FREIGHT',
                                                                         cost.organization_id,
                                                                         cost.inventory_item_id,
                                                                         'Y')
                                                    + xxdoget_item_cost ('FREIGHT DU',
                                                                         cost.organization_id,
                                                                         cost.inventory_item_id,
                                                                         'Y')
                                                    + xxdoget_item_cost ('OH DUTY',
                                                                         cost.organization_id,
                                                                         cost.inventory_item_id,
                                                                         'Y')
                                                    + xxdoget_item_cost ('OH NONDUTY',
                                                                         cost.organization_id,
                                                                         cost.inventory_item_id,
                                                                         'Y'),
                                                    4)
                                                AS item_cost,
                              */
                           ROUND (
                                 COST.unit_price
                               + NVL (
                                     TO_NUMBER (COST.duty_cost),
                                     get_duty_cost (COST.organization_id,
                                                    COST.inventory_item_id,
                                                    po_header_id,
                                                    po_line_id,
                                                    po_line_location_id))
                               + NVL (TO_NUMBER (COST.freight_cost),
                                      xxdoget_item_cost ('FREIGHT', COST.organization_id, COST.inventory_item_id
                                                         , 'Y'))
                               + NVL (TO_NUMBER (COST.freightdu_cost),
                                      xxdoget_item_cost ('FREIGHT DU', COST.organization_id, COST.inventory_item_id
                                                         , 'Y'))
                               + NVL (TO_NUMBER (COST.ohduty_cost),
                                      xxdoget_item_cost ('OH DUTY', COST.organization_id, COST.inventory_item_id
                                                         , 'Y'))
                               + NVL (TO_NUMBER (COST.oh_nonduty_cost),
                                      xxdoget_item_cost ('OH NONDUTY', COST.organization_id, COST.inventory_item_id
                                                         , 'Y')),
                               4)
                               AS item_cost,
                           ROUND (COST.unit_price, 4)
                               AS material_cost,
                           --END Changes as per V1.6
                           --change ends as per defect#672
                           --change as per CR#54 starts
                           /*  ROUND (xxdoget_item_cost ('DUTY',
                                                       cost.organization_id,
                                                       cost.inventory_item_id,
                                                       'Y'),
                                    4)*/
                           --commented as per CR#54
                           --START Changes as per V1.6
                           /*ROUND (get_duty_cost (cost.organization_id,
                                                 cost.inventory_item_id,
                                                 po_header_id,
                                                 po_line_id,
                                                 po_line_location_id),
                                  4)
                              --change as per CR#54 ends
                              AS duty_cost,
                           ROUND (xxdoget_item_cost ('FREIGHT',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'),
                                  4)
                              AS freight_cost,
                           ROUND (xxdoget_item_cost ('FREIGHT DU',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'),
                                  4)
                              AS freight_du_cst,
                           ROUND (xxdoget_item_cost ('OH DUTY',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'),
                                  4)
                              AS oh_duty_cst,
                           ROUND (xxdoget_item_cost ('OH NONDUTY',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'),
                                  4)
                              AS oh_non_duty_cst,  */
                           ROUND (
                               NVL (
                                   TO_NUMBER (COST.duty_cost),
                                   get_duty_cost (COST.organization_id,
                                                  COST.inventory_item_id,
                                                  po_header_id,
                                                  po_line_id,
                                                  po_line_location_id)),
                               4)
                               AS duty_cost,
                           ROUND (NVL (TO_NUMBER (COST.freight_cost),
                                       xxdoget_item_cost ('FREIGHT', COST.organization_id, COST.inventory_item_id
                                                          , 'Y')),
                                  4)
                               AS freight_cost,
                           ROUND (NVL (TO_NUMBER (COST.freightdu_cost),
                                       xxdoget_item_cost ('FREIGHT DU', COST.organization_id, COST.inventory_item_id
                                                          , 'Y')),
                                  4)
                               AS freight_du_cst,
                           ROUND (NVL (TO_NUMBER (COST.ohduty_cost),
                                       xxdoget_item_cost ('OH DUTY', COST.organization_id, COST.inventory_item_id
                                                          , 'Y')),
                                  4)
                               AS oh_duty_cst,
                           ROUND (NVL (TO_NUMBER (COST.oh_nonduty_cost),
                                       xxdoget_item_cost ('OH NONDUTY', COST.organization_id, COST.inventory_item_id
                                                          , 'Y')),
                                  4)
                               AS oh_non_duty_cst,
                           --END Changes as per V1.6
                           'Purchase Order'
                               AS intransit_type,
                           DECODE (p_show_supplier_details,
                                   'N', NULL,
                                   ap.vendor_name)
                               AS vendor,
                           ap.vendor_id,                               -- V2.0
                           DECODE (p_show_supplier_details,
                                   'N', NULL,
                                   'PO#' || COST.po_num)
                               AS vendor_reference,
                           -- Change Start INC0316421
                           --TO_CHAR (cost.asn_creation_date, 'DD/MM/YYYY')
                           COST.asn_creation_date
                               AS transaction_date,
                           -- Change End INC0316421
                           --change starts as per defect#672
                           /*ROUND (
                              (  cost.Quantity
                               * (xxdoget_item_cost ('ITEMCOST',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'N'))),
                              4)*/
                           --START Changes as per V1.6
                           /*ROUND (
                              (  cost.quantity
                               * (  cost.unit_price
                                  + get_duty_cost (cost.organization_id,
                                                   cost.inventory_item_id,
                                                   po_header_id,
                                                   po_line_id,
                                                   po_line_location_id)
                                  + xxdoget_item_cost ('FREIGHT',
                                                       cost.organization_id,
                                                       cost.inventory_item_id,
                                                       'Y')
                                  + xxdoget_item_cost ('FREIGHT DU',
                                                       cost.organization_id,
                                                       cost.inventory_item_id,
                                                       'Y')
                                  + xxdoget_item_cost ('OH DUTY',
                                                       cost.organization_id,
                                                       cost.inventory_item_id,
                                                       'Y')
                                  + xxdoget_item_cost ('OH NONDUTY',
                                                       cost.organization_id,
                                                       cost.inventory_item_id,
                                                       'Y'))),
                              4)
                              AS ext_item_cost,
                           ROUND ( (cost.quantity * cost.unit_price), 4)
                              AS ext_material_cost,
                           ROUND ( (  cost.quantity
                                    * get_duty_cost (cost.organization_id,
                                                     cost.inventory_item_id,
                                                     po_header_id,
                                                     po_line_id,
                                                     po_line_location_id)),
                                  4)
                              AS ext_duty_cost,
                           --change ends as per defect#672
                           ROUND (
                              (  cost.quantity
                               * (xxdoget_item_cost ('FREIGHT',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'))),
                              4)
                              AS ext_freight_cost,
                           ROUND (
                              (  cost.quantity
                               * (xxdoget_item_cost ('FREIGHT DU',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'))),
                              4)
                              AS ext_freight_du_cst,
                           ROUND (
                              (  cost.quantity
                               * (xxdoget_item_cost ('OH DUTY',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'))),
                              4)
                              AS ext_oh_duty_cst,
                           ROUND (
                              (  cost.quantity
                               * (xxdoget_item_cost ('OH NONDUTY',
                                                     cost.organization_id,
                                                     cost.inventory_item_id,
                                                     'Y'))),
                              4)
                              AS ext_oh_non_duty_cst,
         */
                           ROUND (
                               (  COST.quantity
                                * (  COST.unit_price
                                   + NVL (
                                         TO_NUMBER (COST.duty_cost),
                                         get_duty_cost (
                                             COST.organization_id,
                                             COST.inventory_item_id,
                                             po_header_id,
                                             po_line_id,
                                             po_line_location_id))
                                   + NVL (TO_NUMBER (COST.freight_cost),
                                          xxdoget_item_cost ('FREIGHT', COST.organization_id, COST.inventory_item_id
                                                             , 'Y'))
                                   + NVL (TO_NUMBER (COST.freightdu_cost),
                                          xxdoget_item_cost ('FREIGHT DU', COST.organization_id, COST.inventory_item_id
                                                             , 'Y'))
                                   + NVL (TO_NUMBER (COST.ohduty_cost),
                                          xxdoget_item_cost ('OH DUTY', COST.organization_id, COST.inventory_item_id
                                                             , 'Y'))
                                   + NVL (TO_NUMBER (COST.oh_nonduty_cost),
                                          xxdoget_item_cost ('OH NONDUTY', COST.organization_id, COST.inventory_item_id
                                                             , 'Y')))),
                               4)
                               AS ext_item_cost,
                           ROUND ((COST.quantity * COST.unit_price), 4)
                               AS ext_material_cost,
                           ROUND (
                               (  COST.quantity
                                * (NVL (
                                       TO_NUMBER (COST.duty_cost),
                                       get_duty_cost (COST.organization_id,
                                                      COST.inventory_item_id,
                                                      po_header_id,
                                                      po_line_id,
                                                      po_line_location_id)))),
                               4)
                               AS ext_duty_cost,
                           ROUND ((  COST.quantity
                                   * (NVL (TO_NUMBER (COST.freight_cost),
                                           xxdoget_item_cost ('FREIGHT', COST.organization_id, COST.inventory_item_id
                                                              , 'Y')))),
                                  4)
                               AS ext_freight_cost,
                           ROUND ((  COST.quantity
                                   * (NVL (TO_NUMBER (COST.freightdu_cost),
                                           xxdoget_item_cost ('FREIGHT DU', COST.organization_id, COST.inventory_item_id
                                                              , 'Y')))),
                                  4)
                               AS ext_freight_du_cst,
                           ROUND ((  COST.quantity
                                   * (NVL (TO_NUMBER (COST.ohduty_cost),
                                           xxdoget_item_cost ('OH DUTY', COST.organization_id, COST.inventory_item_id
                                                              , 'Y')))),
                                  4)
                               AS ext_oh_duty_cst,
                           ROUND ((  COST.quantity
                                   * (NVL (TO_NUMBER (COST.oh_nonduty_cost),
                                           xxdoget_item_cost ('OH NONDUTY', COST.organization_id, COST.inventory_item_id
                                                              , 'Y')))),
                                  4)
                               AS ext_oh_non_duty_cst,
                           --END Changes as per V1.6
                           po_header_id,
                           po_line_id,
                           po_line_location_id,
                           packing_slip                           --CCR0007979
                      FROM (  SELECT         --change starts as per defect#672
                                     --rsl.quantity_shipped AS Quantity,
                                     SUM (
                                         get_intransit_qty (
                                             rsl.shipment_line_id,
                                             l_use_date,
                                             v_org_region,
                                             p_intransit_type,
                                             --Added for change V1.8
                                             'Purchase Order'--Added for change V1.8
                                                             ))
                                         AS quantity,
                                     pol.unit_price,
                                     --change ends as per defect#672
                                     rsh.creation_date
                                         asn_creation_date,
                                     msib.organization_id
                                         AS organization_id,
                                     msib.inventory_item_id
                                         AS inventory_item_id,
                                     poh.segment1
                                         AS po_num,
                                     poh.vendor_id
                                         AS vendor_id,
                                     rsl.creation_date
                                         AS creation_date,
                                     poh.po_header_id,
                                     rsl.po_line_id,
                                     rsl.po_line_location_id,
                                     --START Changes as per V1.6
                                     rsl.attribute6
                                         AS duty_cost,
                                     rsl.attribute7
                                         AS freight_cost,
                                     rsl.attribute8
                                         AS freightdu_cost,
                                     rsl.attribute9
                                         AS ohduty_cost,
                                     rsl.attribute10
                                         AS oh_nonduty_cost,
                                     rsl.attribute11
                                         AS overheads_cost,
                                     rsl.packing_slip             --CCR0007979
                                --END Changes as per V1.6
                                FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, mtl_system_items_b msib,
                                     po_headers_all poh, --change starts as per defect#672
                                                         po_lines_all pol, --change ends as per defect#672
                                                                           org_organization_definitions ood
                               WHERE     rsl.shipment_header_id =
                                         rsh.shipment_header_id
                                     AND poh.po_header_id = rsl.po_header_id
                                     --change starts as per defect#672
                                     AND rsl.po_line_id = pol.po_line_id
                                     --change ends as per defect#672
                                     AND msib.inventory_item_id = rsl.item_id
                                     AND ood.organization_id =
                                         l_curr_inv_org_id
                                     AND msib.organization_id =
                                         rsl.to_organization_id
                                     AND rsl.source_document_code = 'PO'
                                     AND rsh.asn_type = 'ASN'
                                     --change starts as per defect#672
                                     -- AND rsl.shipment_line_status_code = 'EXPECTED'
                                     AND NVL (rsl.attribute5, 'N') =
                                         CASE
                                             WHEN rsl.shipment_line_status_code =
                                                  'CANCELLED'
                                             THEN
                                                 'Y'
                                             ELSE
                                                 NVL (rsl.attribute5, 'N')
                                         END
                                     AND rsh.shipment_num =
                                         NVL (p_shipment_num, rsh.shipment_num)
                                     --change ends as per defect#672
                                     AND (rsh.shipped_date IS NOT NULL AND rsh.shipped_date < TO_DATE (NVL (l_use_date, SYSDATE)) + 1)
                                     --roll forward date added as per Vishwa's confirmation
                                     /*AND poh.org_id IN (SELECT organization_id
                                                          FROM hr_operating_units
                                                         WHERE name = 'Deckers US OU')*/
                                     --commented as per CR#54 starts
                                     AND ood.organization_id =
                                         rsl.to_organization_id
                                     AND 1 =
                                         DECODE (p_source_type,
                                                 '', 1,
                                                 'Purchase Order', 1,
                                                 0)    --Added for change v1.8
                                     AND rsl.creation_date <
                                           TO_DATE (
                                               NVL (l_use_date,
                                                    TRUNC (SYSDATE)))
                                         + 1       --Added for V1.9 CCR0009519
                            GROUP BY pol.unit_price, rsh.creation_date, msib.organization_id,
                                     msib.inventory_item_id, poh.segment1, poh.vendor_id,
                                     rsl.creation_date, poh.po_header_id, rsl.po_line_id,
                                     rsl.po_line_location_id, --START Changes as per V1.6
                                                              rsl.attribute6, rsl.attribute7,
                                     rsl.attribute8, rsl.attribute9, rsl.attribute10,
                                     rsl.attribute11, rsl.packing_slip --CCR0007979
                              --END Changes as per V1.6
                              HAVING SUM (
                                         get_intransit_qty (
                                             rsl.shipment_line_id,
                                             l_use_date,
                                             v_org_region,
                                             p_intransit_type,
                                             --Added for change V1.8
                                             'Purchase Order'--Added for change V1.8
                                                             )) >
                                     0) COST,
                           xxd_common_items_v citv,
                           mtl_parameters mp,
                           ap_suppliers ap
                     WHERE     citv.organization_id = COST.organization_id
                           AND citv.inventory_item_id =
                               COST.inventory_item_id
                           AND citv.brand LIKE NVL (p_brand, '%')
                           AND mp.organization_id = citv.organization_id
                           AND COST.vendor_id = ap.vendor_id);
    -----------Start modification by BT Technology Team on  08-april-2015
    /* select  organization_code
                  , brand
                  , style
                  , color
                  , quantity
                  , round(item_cost, 4) item_cost
                  , round(material_cost, 4) material_cost
                  , round(material_overhead_cost-(freight_cost+ freight_du_cost +OH_Duty_Cst +OH_Non_Duty_Cst), 4) duty_cost
                  , round(freight_cost, 4)  freight_cost
                  , round(freight_du_cost, 4)   freight_du_cost
                  , round(OH_Duty_Cst, 4)   OH_Duty_Cst
                  , round(OH_Non_Duty_Cst, 4)  OH_Non_Duty_Cst
                  , 'Requisition' as intransit_type
                  , decode(p_show_supplier_details, 'N', null, (select organization_code from mtl_parameters where organization_id = alpha.from_organization_id)) as vendor
                  , decode(p_show_supplier_details, 'N', null, 'Req#' || (select max(prha.segment1) from po_requisition_headers_all prha, po_requisition_lines_all prla where prha.requisition_header_id = prla.requisition_header_id and prla.requisition_line_id = alpha.max_req_line_id)) as vendor_reference
                  , transaction_date
                  , round(quantity*item_cost, 4) ext_item_cost
                  , round(quantity*material_cost, 4) ext_material_cost
                  , round(quantity*(material_overhead_cost-(freight_cost+ freight_du_cost +OH_Duty_Cst +OH_Non_Duty_Cst))) ext_duty_cost
                  , round(quantity*freight_cost, 4)  ext_freight_cost
                  , round(quantity*freight_du_cost, 4) ext_freight_du_cost
                  , round(quantity*OH_Duty_Cst, 4) ext_oh_Duty_Cst
                  , round(quantity*OH_Non_Duty_Cst, 4) ext_oh_Non_Duty_Cst
           from (
                 select  citv.brand as  brand
                     -- mc.segment1 brand
                       ,mp.organization_code
                       ,citv.style_number as style
                       ,decode(p_show_color, 'N', null, citv.color_code) as color
                     -- , msib.segment1 style
                     -- , decode(:p_show_color, 'N', null, msib.segment2) color
                      , sum(qty.rollback_qty) quantity
                      ,xxdoget_item_cost('ITEMCOST',cost.organization_id,cost.inventory_item_id, 'N') item_cost
                      ,xxdoget_item_cost('MATERIAL_COST',cost.organization_id,cost.inventory_item_id, 'Y')  material_cost
                      ,xxdoget_item_cost('TOTAL OVERHEAD',cost.organization_id,cost.inventory_item_id, 'Y')  material_overhead_cost
                      ,xxdoget_item_cost('FREIGHT',cost.organization_id,cost.inventory_item_id, 'Y')   freight_cost
                      ,xxdoget_item_cost('FREIGHT DU',cost.organization_id,cost.inventory_item_id, 'Y')   freight_du_cost
                      ,xxdoget_item_cost('OH DUTY',cost.organization_id,cost.inventory_item_id, 'Y')    OH_Duty_Cst
                      ,xxdoget_item_cost('OH NONDUTY',cost.organization_id,cost.inventory_item_id, 'Y')  OH_Non_Duty_Cst
                        /* , sum(qty.rollback_qty* (
                                            cost.material_cost +
                                               nvl(cost.material_overhead_cost, 0)
                                           ))/sum(qty.rollback_qty) item_cost
                     , sum(qty.rollback_qty*cost.material_cost) / sum(qty.rollback_qty) material_cost

                     , sum(qty.rollback_qty*
                             decode(mp.primary_cost_method, 5, nvl(cost.material_overhead_cost, 0)
                                                               , nvl(apps.xxdoget_item_cost('STDFREIGHT', qty.organization_id, qty.inventory_item_id, 'N'), 0) + nvl(apps.xxdoget_item_cost('EURATE', qty.organization_id, qty.inventory_item_id, 'N')  * apps.xxdoget_item_cost('LISTPRICE', 113, qty.inventory_item_id, 'N'), 0))
                          ) / sum(qty.rollback_qty) material_overhead_cost
                    , sum(qty.rollback_qty*
                             decode(mp.primary_cost_method, 5, cost.material_cost * apps.xxdoget_item_cost('FREIGHTRATE', qty.organization_id, qty.inventory_item_id, 'N')
                                                               , apps.xxdoget_item_cost('STDFREIGHT', qty.organization_id, qty.inventory_item_id, 'N'))
                          ) / sum(qty.rollback_qty) freight_cost */
                   /*  , decode(p_show_supplier_details, 'N', null, qty.from_organization_id) as from_organization_id
                     , decode(p_show_supplier_details, 'N', null, rsh.shipment_num) as shipment_num
                     , max(rsl.requisition_line_id) as max_req_line_id
                     , decode(p_show_supplier_details, 'N', null, rsh.shipped_date) as transaction_date
                  from cst_item_list_temp item
                     , cst_inv_qty_temp qty
                     , xxd_common_items_v citv
                  --   , mtl_system_items_b msib
                  --  , mtl_item_categories mic
                  --   , mtl_categories mc
                     , mtl_parameters mp
                     , cst_inv_cost_temp cost
                     , rcv_shipment_lines rsl
                     , rcv_shipment_headers rsh
                  where qty.inventory_item_id = item.inventory_item_id
                    and qty.cost_type_id = item.cost_type_id
                    and qty.organization_id = l_curr_inv_org_id
                    and citv.organization_id = qty.organization_id
                    and citv.inventory_item_id = qty.inventory_item_id
                   -- and mic.organization_id = msib.organization_id
                   -- and mic.inventory_item_id = msib.inventory_item_id
                    and citv.category_set_id = 1
                   -- and mc.category_id = mic.category_id
                    and citv.brand like nvl(p_brand,'%')
                   -- and mc.segment1 like nvl(p_brand, '%')
                    and qty.qty_source = 6 -- Back-to-back only --
                    and mp.organization_id = qty.organization_id
                    and cost.organization_id(+) = qty.organization_id
                    and cost.inventory_item_id(+) = qty.inventory_item_id
                    and cost.cost_type_id(+) = qty.cost_type_id
                    and rsl.shipment_line_id = qty.shipment_line_id
                    and rsh.shipment_header_id = rsl.shipment_header_id
                  group by citv.brand
                       --mc.segment1
                         , mp.organization_Code
                         , citv.style_number
                        -- , msib.segment1
                         , decode(p_show_color, 'N', null,citv.color_code)
                         , decode(p_show_supplier_details, 'N', null, qty.from_organization_id)
                         , decode(p_show_supplier_details, 'N', null, rsh.shipment_num)
                         , decode(p_show_supplier_details, 'N', null, rsh.shipped_date)
                         ,cost.organization_id
                         ,cost.inventory_item_id
                    having sum(qty.rollback_qty) > 0
                ) alpha
        union all
     select mp.organization_code as organization_code
       ,citv.BRAND as  brand
       ,citv.style_number as style
      , decode(p_show_color, 'N', null, citv.color_code) as color
       ,cost.Quantity as Quantity
       ,round(xxdoget_item_cost('ITEMCOST',cost.organization_id,cost.inventory_item_id, 'N'),4) as item_cost
       ,round(xxdoget_item_cost('MATERIAL_COST',cost.organization_id,cost.inventory_item_id, 'Y'),4)  as material_cost
       ,round(xxdoget_item_cost('FREIGHT',cost.organization_id,cost.inventory_item_id, 'Y'),4) as freight_cost
       ,round(xxdoget_item_cost('FREIGHT DU',cost.organization_id,cost.inventory_item_id, 'Y'),4) as Freight_DU_Cst
       ,round(xxdoget_item_cost('DUTY',cost.organization_id,cost.inventory_item_id, 'Y'),4)   as duty_cost
       ,round(xxdoget_item_cost('OH DUTY',cost.organization_id,cost.inventory_item_id, 'Y'),4)   as OH_Duty_Cst
       ,round(xxdoget_item_cost('OH NONDUTY',cost.organization_id,cost.inventory_item_id, 'Y'),4)  as OH_Non_Duty_Cst
       ,'Purchase Order' as intransit_type
       ,decode(p_show_supplier_details, 'N', null,ap.Vendor_name) as vendor
       ,decode(p_show_supplier_details, 'N', null,'PO#'||cost.po_num ) as vendor_reference
       ,to_char(cost.asn_creation_date,'DD/MM/YYYY')  as transaction_date
       ,round(( cost.Quantity * (xxdoget_item_cost('ITEMCOST',cost.organization_id,cost.inventory_item_id, 'N'))),4) as ext_item_cost
       ,round(( cost.Quantity * (xxdoget_item_cost('MATERIAL_COST',cost.organization_id,cost.inventory_item_id, 'Y'))),4) as ext_material_cost
       ,round(( cost.Quantity * (xxdoget_item_cost('FREIGHT',cost.organization_id,cost.inventory_item_id, 'Y'))),4) as ext_freight_cost
       ,round(( cost.Quantity * (xxdoget_item_cost('FREIGHT DU',cost.organization_id,cost.inventory_item_id, 'Y'))),4) as Ext_Freight_DU_Cst
       ,round(( cost.Quantity * (xxdoget_item_cost('DUTY',cost.organization_id,cost.inventory_item_id, 'Y'))),4) as ext_duty_cost
       ,round(( cost.Quantity * (xxdoget_item_cost('OH DUTY',cost.organization_id,cost.inventory_item_id, 'Y'))),4) as Ext_OH_Duty_Cst
       ,round(( cost.Quantity * (xxdoget_item_cost('OH NONDUTY',cost.organization_id,cost.inventory_item_id, 'Y'))),4) as Ext_OH_Non_Duty_Cst
from
        (SELECT rsl.quantity_shipped AS Quantity,
                rsh.creation_date AS asn_creation_date,
                msib.organization_id AS organization_id,
                msib.inventory_item_id AS inventory_item_id,
                poh.segment1 AS po_num,
                poh.vendor_Id AS vendor_Id,
                rsl.creation_date AS creation_date
           FROM rcv_shipment_headers rsh,
                rcv_shipment_lines rsl,
                mtl_system_items_b msib,
                po_headers_all poh,
                org_organization_definitions ood
          WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                AND poh.po_header_id = rsl.po_header_id
                AND msib.inventory_item_id = rsl.item_id
                AND ood.organization_id  =l_curr_inv_org_id
                AND msib.ORGANIZATION_ID = rsl.TO_ORGANIZATION_ID
                AND rsl.shipment_line_status_code = 'EXPECTED'
                AND rsl.source_document_code = 'PO'
                AND rsh.asn_type = 'ASN'
                AND poh.org_id IN (SELECT organization_id
                                     FROM hr_operating_units
                                    WHERE name = 'Deckers US OU')
                AND ood.organization_id = rsl.TO_ORGANIZATION_ID) cost
               ,xxd_common_items_v citv
               ,mtl_parameters mp
               ,ap_suppliers ap
     where citv.ORGANIZATION_ID=cost.ORGANIZATION_ID
     AND   citv.INVENTORY_ITEM_ID=cost.INVENTORY_ITEM_ID
     AND   citv.brand like nvl(p_brand,'%')
     AND   mp.ORGANIZATION_ID=citv.ORGANIZATION_ID
     AND   cost.VENDOR_ID=ap.VENDOR_ID;
     */

    /*
         select mcb.segment1 as brand
            , mp.organization_code
            , msib.segment1 as style
            , decode(p_show_color, 'Y', msib.segment2, null) as color
            , sum(beta.quantity) as quantity
            , 'Purchase Order' as intransit_type
            , round(sum(beta.quantity * (beta.trx_material_cost + beta.trx_freight_cost + beta.trx_duty_cost)) / sum(beta.quantity), 4) as item_cost
            , round(sum(beta.quantity * beta.trx_material_cost) / sum(beta.quantity), 4) as material_cost
            , round(sum(beta.quantity * (beta.trx_freight_cost + beta.trx_duty_cost)) / sum(beta.quantity), 4) as material_overhead_cost
            , round(sum(beta.quantity * beta.trx_freight_cost) / sum(beta.quantity), 4) as freight_cost
            , round(sum(beta.quantity * beta.trx_duty_cost) / sum(beta.quantity), 4) as duty_cost
            , ap.vendor_name as vendor
            , beta.po_number as vendor_reference
            , round(sum(beta.quantity * (beta.trx_material_cost + beta.trx_freight_cost + beta.trx_duty_cost)), 4) as ext_item_cost
            , round(sum(beta.quantity * beta.trx_material_cost), 4) as ext_material_cost
            , round(sum(beta.quantity * (beta.trx_freight_cost + beta.trx_duty_cost)), 4) as ext_material_overhead_cost
            , round(sum(beta.quantity * beta.trx_freight_cost), 4) as ext_freight_cost
            , round(sum(beta.quantity * beta.trx_duty_cost), 4) as ext_duty_cost
            , beta.transaction_date as transaction_date
    from (
        select alpha.organization_id
               , alpha.inventory_item_id
               , alpha.rcv_transaction_id
               , sum(alpha.quantity) as quantity
               , nvl((select max(po_unit_price) from xxdo.xxdopo_accrual_lines xal where xal.rcv_transaction_id = alpha.rcv_transaction_id), apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id, 'N')) as trx_material_cost
               , nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines xal where xal.rcv_transaction_id = alpha.rcv_transaction_id and xal.accrual_type = 'Freight')
                       , case
                            when mp.primary_cost_method = 1 then
                                -- Standard Cost --
                                 apps.xxdoget_item_cost ('STDFREIGHT', alpha.organization_id, alpha.inventory_item_id, 'N')
                             else
                                -- Layered Cost --
                                decode(apps.xxdoget_item_cost ('FIFOFREIGHT', alpha.organization_id, alpha.inventory_item_id, 'N')
                                                , 0, apps.xxdoget_item_cost ('FREIGHTRATE', alpha.organization_id, alpha.inventory_item_id, 'N') * apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id, 'N')
                                                , apps.xxdoget_item_cost ('FIFOFREIGHT', alpha.organization_id, alpha.inventory_item_id, 'N')
                                           )
                         end
                 ) as trx_freight_cost
               , nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines xal where xal.rcv_transaction_id = alpha.rcv_transaction_id and xal.accrual_type = 'Duty')
                    , nvl(apps.xxdoget_item_cost ('NONMATERIAL', alpha.organization_id, alpha.inventory_item_id, 'N'), 0)
                       - nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines xal where xal.rcv_transaction_id = alpha.rcv_transaction_id and xal.accrual_type = 'Freight')
                               , case
                                    when mp.primary_cost_method = 1 then
                                        -- Standard Cost --
                                         apps.xxdoget_item_cost ('STDFREIGHT', alpha.organization_id, alpha.inventory_item_id, 'N')
                                     else
                                        -- Layered Cost --
                                        decode(apps.xxdoget_item_cost ('FIFOFREIGHT', alpha.organization_id, alpha.inventory_item_id, 'N')
                                                        , 0, apps.xxdoget_item_cost ('FREIGHTRATE', alpha.organization_id, alpha.inventory_item_id, 'N') * apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id, 'N')
                                                        , apps.xxdoget_item_cost ('FIFOFREIGHT', alpha.organization_id, alpha.inventory_item_id, 'N')
                                                   )
                                 end
                         )
                 ) as trx_duty_cost
               , decode(p_show_supplier_details, 'Y', vendor_id, null) as vendor_id
               , decode(p_show_supplier_details, 'Y', 'PO #' || alpha.po_number, null) as po_number
               , decode(p_show_supplier_details, 'N', null, alpha.transaction_date) as transaction_date
        from (
            select ms.to_organization_id as organization_id
                   , pol.item_id as inventory_item_id
                   , poh.segment1 as po_number
                   , poh.vendor_id
                   , case
                            when nvl(rt.transaction_type, ' ') in ('ACCEPT', 'REJECT', 'TRANSFER') then
                                apps.cst_inventory_pvt.get_parentreceivetxn(ms.rcv_transaction_id)
                            else
                                ms.rcv_transaction_id
                     end as rcv_transaction_id
                   , sum(ms.to_org_primary_quantity) as quantity
                   , trunc(rt.transaction_date) as transaction_date
            from mtl_supply ms
                  , rcv_transactions rt
                  , po_lines_all pol
                  , po_headers_all poh
            where ms.to_organization_id = l_curr_inv_org_id
                and ms.supply_type_code = 'RECEIVING'
                and rt.transaction_id = ms.rcv_transaction_id
                and nvl(rt.consigned_flag, 'N') = 'N'
                and rt.source_document_code = 'PO'
                and pol.po_line_id = rt.po_line_id
                and poh.po_header_id = rt.po_header_id
            group by ms.to_organization_id
                       , pol.item_id
                       , poh.segment1
                       , poh.vendor_id
                       , case
                            when nvl(rt.transaction_type, ' ') in ('ACCEPT', 'REJECT', 'TRANSFER') then
                                apps.cst_inventory_pvt.get_parentreceivetxn(ms.rcv_transaction_id)
                            else
                                ms.rcv_transaction_id
                        end
                   , trunc(rt.transaction_date)
            union all
            select rt.organization_id
                   , pol.item_id as inventory_item_id
                   , poh.segment1 as po_number
                   , poh.vendor_id
                   , case
                            when nvl(rt.transaction_type, ' ') in ('RECEIVE', 'MATCH') then
                                rt.transaction_id
                           else
                                apps.cst_inventory_pvt.get_parentreceivetxn(rt.transaction_id)
                     end as rcv_transaction_id
                   , sum(decode(rt.transaction_type,
                            'RECEIVE', -1 * rt.primary_quantity,
                            'DELIVER', 1 * rt.primary_quantity,
                            'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                            'RETURN TO VENDOR', decode(parent_rt.transaction_type, 'UNORDERED', 0, 1 * rt.primary_quantity),
                            'MATCH', -1 * rt.primary_quantity,
                            'CORRECT', decode(parent_rt.transaction_type,
                                              'UNORDERED', 0,
                                              'RECEIVE', -1 * rt.primary_quantity,
                                              'DELIVER', 1 * rt.primary_quantity,
                                              'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                                              'RETURN TO VENDOR', decode(grparent_rt.transaction_type, 'UNORDERED', 0, 1 * rt.primary_quantity),
                                              'MATCH', -1 * rt.primary_quantity,
                                              0),
                            0)
                     ) quantity
                   , trunc(rt.transaction_date) as transaction_date
            from rcv_transactions rt
                  , rcv_transactions parent_rt
                  , rcv_transactions grparent_rt
                  , po_lines_all pol
                  , po_headers_all poh
            where rt.organization_id = l_curr_inv_org_id
                and nvl(rt.consigned_flag, 'N') = 'N'
                and nvl(rt.dropship_type_code, 3) = 3
                and rt.transaction_date > l_use_date
                and rt.transaction_type in ('RECEIVE', 'DELIVER', 'RETURN TO RECEIVING', 'RETURN TO VENDOR', 'CORRECT', 'MATCH')
                and rt.source_document_code = 'PO'
                and decode(rt.parent_transaction_id, -1, null, 0, null, rt.parent_transaction_id) = parent_rt.transaction_id(+)
                and decode(parent_rt.parent_transaction_id, -1, null, 0, null, parent_rt.parent_transaction_id) = grparent_rt.transaction_id(+)
                and pol.po_line_id = rt.po_line_id
                and poh.po_header_id = rt.po_header_id
            group by rt.organization_id
                        , poh.segment1
                        , poh.vendor_id
                        , pol.item_id
                        , case
                                when nvl(rt.transaction_type, ' ') in ('RECEIVE', 'MATCH') then
                                    rt.transaction_id
                               else
                                    apps.cst_inventory_pvt.get_parentreceivetxn(rt.transaction_id)
                          end
                   , trunc(rt.transaction_date)
            having sum(decode(rt.transaction_type,
                           'RECEIVE', -1 * rt.primary_quantity,
                           'DELIVER', 1 * rt.primary_quantity,
                           'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                           'RETURN TO VENDOR', decode(parent_rt.transaction_type, 'UNORDERED', 0, 1 * rt.primary_quantity),
                           'MATCH', -1 * rt.primary_quantity,
                           'CORRECT', decode(parent_rt.transaction_type,
                                             'UNORDERED', 0,
                                             'RECEIVE', -1 * rt.primary_quantity,
                                             'DELIVER', 1 * rt.primary_quantity,
                                             'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                                             'RETURN TO VENDOR', decode(grparent_rt.transaction_type, 'UNORDERED', 0, 1 * rt.primary_quantity),
                                             'MATCH', -1 * rt.primary_quantity,
                                             0),
                           0)
                   ) <> 0
            ) alpha
            , mtl_parameters mp
        where mp.organization_id = alpha.organization_id
       group by alpha.organization_id
                 , alpha.inventory_item_id
                 , alpha.rcv_transaction_id
                 , mp.primary_cost_method
                 , decode(p_show_supplier_details, 'Y', vendor_id, null)
                 , decode(p_show_supplier_details, 'Y', 'PO #' || alpha.po_number, null)
                 , decode(p_show_supplier_details, 'N', null, alpha.transaction_date)
        having sum(alpha.quantity) != 0
    ) beta
     , mtl_system_items_b msib
     , mtl_item_categories mic
     , mtl_categories_b mcb
     , mtl_parameters mp
     , ap_suppliers ap
    where msib.organization_id = beta.organization_id
       and msib.inventory_item_id = beta.inventory_item_id
       and mic.organization_id = beta.organization_id
       and mic.inventory_item_id = beta.inventory_item_id
       and mic.category_set_id = 1
       and mcb.category_id = mic.category_id
       and mp.organization_id = beta.organization_id
       and ap.vendor_id(+) = beta.vendor_id
       and mcb.segment1 like nvl(p_brand, '%')
    group by beta.organization_id
           --, beta.inventory_item_id
           --, beta.rcv_transaction_id
           , mcb.segment1
           , mp.organization_code
           , msib.segment1
           , decode(p_show_color, 'Y', msib.segment2, null)
           , ap.vendor_name
           , beta.po_number
           , beta.transaction_date
    order by brand
         , organization_code
         , style
         , color;     */
    --End modification by BT Technology Team on 08-MAR-2015
    -- End Changes by BT Tecgnology Team on 10-JUN-2015 for Defect#2321

    /*
           OLD
                select brand
                     , organization_code
                     , style
                     , color
                     , quantity
                     , decode(cost_source, 4, 'Purchase Order', 'Requisition') as intransit_type
                     , round(item_cost, 4) item_cost
                     , round(material_cost, 4) material_cost
                     , round(material_overhead_cost, 4) material_overhead_cost
                     , round(least(freight_cost, material_overhead_cost), 4) freight_cost
                     , greatest(round(material_overhead_cost-freight_cost, 4), 0) duty_cost
                     , decode(cost_source
                                  , null, null
                                  , 4, vendor_name
                                  , 2, (select organization_code from mtl_parameters where organization_id = alpha.from_organization_id)
                                  , null
                        ) vendor
                     , decode(cost_source
                                  , null, null
                                  , 4, 'PO #' || nvl(factory_po_number, '{Unknown}')
                                  , 2, 'Req #' || (select max(prha.segment1) from po_requisition_headers_all prha, po_requisition_lines_all prla where prha.requisition_header_id = prla.requisition_header_id and prla.requisition_line_id = alpha.max_req_line_id) ||' (Ship #' || alpha.shipment_num || ')'
                                  , null
                        ) vendor_reference
                     , quantity*round(item_cost, 4) ext_item_cost
                     , quantity*round(material_cost, 4) ext_material_cost
                     , quantity*round(material_overhead_cost, 4) ext_material_overhead_cost
                     , quantity*round(least(freight_cost, material_overhead_cost), 4) ext_freight_cost
                     , greatest(quantity*round(material_overhead_cost-freight_cost, 4), 0) ext_duty_cost
              from (
                    select mc.segment1 brand
                         , mp.organization_code
                         , msib.segment1 style
                         , decode(p_show_color, 'N', null, msib.segment2) color
                         , sum(qty.rollback_qty) quantity
                         , sum(qty.rollback_qty* (
                                                   decode(cost.cost_source, 4, cost.item_cost,
                                                                            2, cost.material_cost,
                                                                            0) +
                                                   decode(cost.cost_source, 4, nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines where rcv_transaction_id = rt.transaction_id and accrual_type = 'Freight'), 0) + nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines where rcv_transaction_id = rt.transaction_id and accrual_type = 'Duty'), 0),
                                                                            2, nvl(cost.material_overhead_cost, 0),
                                                                            0)
                                                 ))/sum(qty.rollback_qty) item_cost
                         , sum(qty.rollback_qty*
                                   decode(cost.cost_source, 4, cost.item_cost,
                                                            2, cost.material_cost,
                                                            0)
                              ) / sum(qty.rollback_qty) material_cost
                         , sum(qty.rollback_qty*
                                   decode(cost.cost_source, 4, nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines where rcv_transaction_id = rt.transaction_id and accrual_type = 'Freight'), 0) + nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines where rcv_transaction_id = rt.transaction_id and accrual_type = 'Duty'), 0),
                                                            2, decode(mp.primary_cost_method, 5, nvl(cost.material_overhead_cost, 0)
                                                                   , nvl(apps.xxdoget_item_cost('STDFREIGHT', qty.organization_id, qty.inventory_item_id, 'N'), 0) + nvl(apps.xxdoget_item_cost('EURATE', qty.organization_id, qty.inventory_item_id, 'N')  * apps.xxdoget_item_cost('LISTPRICE', 113, qty.inventory_item_id, 'N'), 0))
                                                               ,
                                                            0)
                              ) / sum(qty.rollback_qty) material_overhead_cost
                         , sum(qty.rollback_qty*
                                   decode(cost.cost_source, 4, nvl((select amount_total/quantity_total from xxdo.xxdopo_accrual_lines where rcv_transaction_id = rt.transaction_id and accrual_type = 'Freight'), 0),
                                                            2,  decode(mp.primary_cost_method, 5, cost.material_cost * apps.xxdoget_item_cost('FREIGHTRATE', qty.organization_id, qty.inventory_item_id, 'N')
                                                                   , apps.xxdoget_item_cost('STDFREIGHT', qty.organization_id, qty.inventory_item_id, 'N')),
                                                            0)
                              ) / sum(qty.rollback_qty) freight_cost
                         , decode(p_show_supplier_details, 'N', null, cost.cost_source) as cost_source
                         , decode(p_show_supplier_details, 'N', null, pv.vendor_name) as vendor_name
                         , decode(p_show_supplier_details, 'N', null, qty.from_organization_id) as from_organization_id
                         , decode(p_show_supplier_details, 'N', null, pha.segment1) as factory_po_number
                         , decode(p_show_supplier_details, 'N', null, rsh.shipment_num) as shipment_num
                         , max(rsl.requisition_line_id) as max_req_line_id
                      from cst_item_list_temp item
                         , cst_inv_qty_temp qty
                         , mtl_system_items_b msib
                         , mtl_item_categories mic
                         , mtl_categories mc
                         , mtl_parameters mp
                         , cst_inv_cost_temp cost
                         , rcv_transactions rt
                         , po_vendors pv
                         , po_headers_all pha
                         , rcv_shipment_lines rsl
                         , rcv_shipment_headers rsh
                      where qty.inventory_item_id = item.inventory_item_id
                        and qty.cost_type_id = item.cost_type_id
                        and qty.organization_id = l_curr_inv_org_id
                        and msib.organization_id = qty.organization_id
                        and msib.inventory_item_id = qty.inventory_item_id
                        and mic.organization_id = msib.organization_id
                        and mic.inventory_item_id = msib.inventory_item_id
                        and mic.category_set_id = 1
                        and mc.category_id = mic.category_id
                        and mc.segment1 like nvl(p_brand, '%')
                        and mp.organization_id = qty.organization_id
                        and cost.organization_id = qty.organization_id
                        and cost.inventory_item_id = qty.inventory_item_id
                        and (cost.cost_type_id = qty.cost_type_id
                          or (cost.rcv_transaction_id = qty.rcv_transaction_id)
                            )
                        and rt.transaction_id(+) = cost.rcv_transaction_id
                        and pv.vendor_id(+) = rt.vendor_id
                        and pha.po_header_id (+) = rt.po_header_id
                        and rsl.shipment_line_id = nvl(rt.shipment_line_id, qty.shipment_line_id)
                        and rsh.shipment_header_id = rsl.shipment_header_id
                      group by mc.segment1
                             , mp.organization_Code
                             , msib.segment1
                             , decode(p_show_color, 'N', null, msib.segment2)
                             , decode(p_show_supplier_details, 'N', null, cost.cost_source)
                             , decode(p_show_supplier_details, 'N', null, pv.vendor_name)
                             , decode(p_show_supplier_details, 'N', null, qty.from_organization_id)
                             , decode(p_show_supplier_details, 'N', null, pha.segment1)
                             , decode(p_show_supplier_details, 'N', null, rsh.shipment_num)
                             , decode(p_show_supplier_details, 'N', null, rsh.shipment_num)
                             , decode(cost_source, 4, 'Purchase Order', 'Requisition')
                        having sum(qty.rollback_qty) > 0
                    ) alpha
              order by brand
                     , organization_code
                     , style
                     , color;
    */
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'test1');

        IF NVL (p_debug_level, 0) > 0
        THEN
            do_debug_tools.enable_conc_log (p_debug_level);
        END IF;

        BEGIN
            SELECT category_set_id
              INTO g_category_set_id
              FROM mtl_category_sets
             WHERE category_set_name = g_category_set_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                raise_application_error (-20001,
                                         'Sales Category Not defined.');
        END;

        do_debug_tools.msg ('+' || l_proc_name);
        do_debug_tools.msg (
               'p_inv_org_id='
            || p_inv_org_id
            || ', p_region='
            || p_region
            || ', p_as_of_date='
            || NVL (p_as_of_date, '{None}')
            || ', p_cost_type_id='
            || NVL (TO_CHAR (p_cost_type_id), '{None}')
            || ', p_brand='
            || p_brand
            || ', p_show_color='
            || p_show_color
            || ', p_show_supplier_details='
            || p_show_supplier_details);

        BEGIN
            IF p_inv_org_id IS NULL AND p_region IS NULL
            THEN
                raise_application_error (
                    -20001,
                    'Either an inventory organization or region must be specified');
            END IF;

            --fnd_file.put_line (fnd_file.LOG, 'test2');

            IF p_as_of_date IS NOT NULL
            THEN
                l_use_date   :=
                    TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS');
            END IF;

            --fnd_file.put_line (fnd_file.LOG, 'test3');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Warehouse', 15, ' ')
                || RPAD ('Brand', 12, ' ')
                || RPAD ('Style', 15, ' ')
                || RPAD ('Color', 10, ' ')
                || RPAD ('Item Type', 15, ' ')
                || RPAD ('Quantity', 13, ' ')
                || RPAD ('Item Cst', 20, ' ')
                || RPAD ('Mat Cst', 20, ' ')
                || RPAD ('Duty Cst', 20, ' ')
                || RPAD ('Frt Cst', 20, ' ')
                || RPAD ('Frt Du Cst', 20, ' ')
                || RPAD ('O/H Duty Cst', 20, ' ')
                || RPAD ('O/H NonDuty Cst', 20, ' ')
                || RPAD ('Type', 20, ' ')
                || RPAD ('Vendor', 67, ' ')
                || RPAD ('Reference', 14, ' ')
                || RPAD ('Factory Invoice Num', 25, ' ')
                || RPAD ('Trx Date', 15, ' ')
                || RPAD ('Ext Item Cst', 20, ' ')
                || RPAD ('Ext Mat Cst', 20, ' ')
                || RPAD ('Ext Duty Cst', 20, ' ')
                || RPAD ('Ext Frt Cst', 20, ' ')
                || RPAD ('Ext Frt Du Cst', 20, ' ')
                || RPAD ('Ext O/H Duty Cst', 20, ' ')
                || RPAD ('Ext O/H Non Duty Cst', 20, ' ')
                || CHR (13)
                || CHR (10));
            --);
            fnd_file.put_line (fnd_file.output,
                               RPAD ('=', 500, '=') || CHR (13) || CHR (10));
            /*  rpad('=', w_brand, '=') ||
              rpad('=', w_style, '=') ||
              rpad('=', w_color, '=') ||
              rpad('=', w_quantity, '=') ||
              rpad('=', w_item_cost, '=') ||
              rpad('=', w_material_cost, '=') ||
              rpad('=', w_material_overhead_cost, '=') ||
              rpad('=', w_freight_cost, '=') ||
              rpad('=', w_duty_cost, '=') ||
              rpad('=', w_type, '=') ||
              rpad('=', w_vendor, '=') ||
              rpad('=', w_vendor_reference, '=') ||
              rpad('=', w_trx_date, '=') ||
              rpad('=', w_ext_item_cost, '=') ||
              rpad('=', w_ext_material_cost, '=') ||
              rpad('=', w_ext_material_overhead_cost, '=') ||
              rpad('=', w_ext_freight_cost, '=') ||
              rpad('=', w_ext_duty_cost, '=')
          );*/
            /*
                    insert into aaa_kwg_intrans_rpt
                    values
                    (
                        aaa_kwg_intrans_seq.nextval,
                        rpad('Warehouse', w_organization_code, ' ') ||
                        rpad('Brand', w_brand, ' ') ||
                        rpad('Style', w_style, ' ') ||
                        rpad('Color', w_color, ' ') ||
                        rpad('Quantity', w_quantity, ' ') ||
                        rpad('Item Cst', w_item_cost, ' ') ||
                        rpad('Mat Cst', w_material_cost, ' ') ||
                        rpad('O/H Cst', w_material_overhead_cost, ' ') ||
                        rpad('Frt Cst', w_freight_cost, ' ') ||
                        rpad('Duty Cst', w_duty_cost, ' ') ||
                        rpad('Vendor', w_vendor, ' ') ||
                        rpad('Reference', w_vendor_reference, ' ') ||
                        rpad('Ext Item Cst', w_ext_item_cost, ' ') ||
                        rpad('Ext Mat Cst', w_ext_material_cost, ' ') ||
                        rpad('Ext O/H Cst', w_ext_material_overhead_cost, ' ') ||
                        rpad('Ext Frt Cst', w_ext_freight_cost, ' ') ||
                        rpad('Ext Duty Cst', w_ext_duty_cost, ' ')
                    );
                    insert into aaa_kwg_intrans_rpt
                    values
                    (
                        aaa_kwg_intrans_seq.nextval,
                        rpad('=', w_organization_code, '=') ||
                        rpad('=', w_brand, '=') ||
                        rpad('=', w_style, '=') ||
                        rpad('=', w_color, '=') ||
                        rpad('=', w_quantity, '=') ||
                        rpad('=', w_item_cost, '=') ||
                        rpad('=', w_material_cost, '=') ||
                        rpad('=', w_material_overhead_cost, '=') ||
                        rpad('=', w_freight_cost, '=') ||
                        rpad('=', w_duty_cost, '=') ||
                        rpad('=', w_vendor, '=') ||
                        rpad('=', w_vendor_reference, '=') ||
                        rpad('=', w_ext_item_cost, '=') ||
                        rpad('=', w_ext_material_cost, '=') ||
                        rpad('=', w_ext_material_overhead_cost, '=') ||
                        rpad('=', w_ext_freight_cost, '=') ||
                        rpad('=', w_ext_duty_cost, '=')
                    );
                    */
            do_debug_tools.msg ('  before inventory organization loop');

            FOR c_inv_org IN c_inv_orgs
            LOOP
                --CCR0007979 Get ORG Region to pass to report query
                v_org_region   := c_inv_org.region;
                do_debug_tools.msg (
                    '  processing inventory organization ' || c_inv_org.organization_code);
                do_debug_tools.msg ('  purging temp tables.');

                DELETE FROM cst_item_list_temp item;

                DELETE FROM cst_inv_qty_temp;

                DELETE FROM cst_inv_cost_temp;

                COMMIT;

                /*----------------start for V1.9 CCR0009519 -----------------------*/
                IF ((p_source_type IS NULL AND p_shipment_num IS NULL) OR p_source_type = 'Requisition')
                THEN
                    BEGIN
                        lv_tem_load    := 'Y';
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' Start Insert At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                        OPEN c_inst (l_use_date);

                        LOOP
                            FETCH c_inst
                                BULK COLLECT INTO v_ins_type
                                LIMIT 20000;

                            BEGIN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' Start Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));

                                IF (v_ins_type.COUNT > 0)
                                THEN
                                    FORALL i
                                        IN v_ins_type.FIRST ..
                                           v_ins_type.LAST
                                      SAVE EXCEPTIONS
                                        INSERT INTO xxdo.xxd_cst_cg_cost_history_temp_t (
                                                        new_cost,
                                                        transaction_id,
                                                        organization_id,
                                                        inventory_item_id,
                                                        transaction_date,
                                                        transaction_costed_date,
                                                        new_material,
                                                        new_material_overhead,
                                                        request_id,
                                                        attribute1,
                                                        attribute2,
                                                        attribute3,
                                                        attribute4,
                                                        attribute5,
                                                        attribute6,
                                                        attribute7,
                                                        attribute8,
                                                        attribute9,
                                                        attribute10,
                                                        attribute11,
                                                        attribute12,
                                                        attribute13,
                                                        attribute14,
                                                        attribute15,
                                                        creation_date,
                                                        created_by,
                                                        last_updated_by,
                                                        last_update_date,
                                                        last_update_login)
                                             VALUES (v_ins_type (i).new_cost, v_ins_type (i).transaction_id, v_ins_type (i).organization_id, v_ins_type (i).inventory_item_id, v_ins_type (i).transaction_date, v_ins_type (i).transaction_costed_date, v_ins_type (i).new_material, v_ins_type (i).new_material_overhead, gn_request_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, SYSDATE, gn_user_id, gn_user_id
                                                     , SYSDATE, gn_login_id);

                                    COMMIT;
                                END IF;

                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_tem_load   := 'N';

                                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                                    LOOP
                                        ln_error_num   :=
                                            SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                        lv_error_code   :=
                                            SQLERRM (
                                                  -1
                                                * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                        lv_error_msg   :=
                                            SUBSTR (
                                                (lv_error_msg || ' Error While Insert into Table ' || v_ins_type (ln_error_num).transaction_id || ' ' || lv_error_code || CHR (10)),
                                                1,
                                                4000);

                                        debug_msg (lv_error_msg);
                                        lv_status   := 'E';
                                    END LOOP;

                                    debug_msg (
                                           ' End Insert Record Count '
                                        || v_ins_type.COUNT
                                        || ' at '
                                        || TO_CHAR (
                                               SYSDATE,
                                               'DD-MON-YYYY HH24:MI:SS AM'));
                            END;

                            v_ins_type.delete;
                            EXIT WHEN c_inst%NOTFOUND;
                        END LOOP;

                        CLOSE c_inst;

                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Inserting At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_status   := 'E';
                    END;
                END IF;

                /*----------------End for V1.9 CCR0009519 -----------------------*/
                IF (lv_tem_load = 'Y')
                THEN                                   --added V1.9 CCR0009519
                    debug_msg (
                           ' Start temp At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                    do_debug_tools.msg ('  calling load_temp_table.');
                    load_temp_table (
                        p_as_of_date       => l_use_date,
                        p_inv_org_id       => c_inv_org.organization_id,
                        p_cost_type_id     => p_cost_type_id,
                        x_ret_stat         => l_ret_stat,
                        x_error_messages   => l_err_messages);
                    do_debug_tools.msg (
                           '  call to load_temp_table returned '
                        || l_ret_stat
                        || '.  '
                        || l_err_messages);
                    debug_msg (
                           ' End temp At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    debug_msg (
                           ' Start Insert At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    debug_msg (
                           ' End Insert At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                END IF;                                --added V1.9 CCR0009519

                --start added V1.9 CCR0009519

                IF (lv_tem_load = 'Y')
                THEN                                   --added V1.9 CCR0009519
                    IF NVL (l_ret_stat, fnd_api.g_ret_sts_error) !=
                       fnd_api.g_ret_sts_success
                    THEN
                        lv_orc_tmp_load   := 'N';
                    END IF;
                END IF;

                --end added V1.9 CCR0009519
                IF lv_orc_tmp_load = 'N'               --added V1.9 CCR0009519
                THEN
                    perrproc   := 1;
                    psqlstat   :=
                           'Failed to load details for '
                        || c_inv_org.organization_code
                        || '.  '
                        || l_err_messages;
                ELSE
                    l_cnt   := 0;
                    do_debug_tools.msg (' before report line loop.');

                    FOR c_rpt_line IN c_rpt_lines (c_inv_org.organization_id)
                    LOOP
                        l_cnt   := l_cnt + 1;
                        do_debug_tools.msg (' counter: ' || l_cnt);

                        --Check if Factory Invoice number is in ASN line
                        --CCR0007979
                        IF c_rpt_line.packing_slip IS NOT NULL
                        THEN
                            --Get factory Inv # from ASN line
                            l_fact_invoice_num   := c_rpt_line.packing_slip;
                        ELSE
                            --Fetching Factory Invoice Number
                            BEGIN
                                SELECT ds.invoice_num
                                  INTO l_fact_invoice_num
                                  FROM apps.do_items di, apps.do_containers dc, apps.do_shipments ds
                                 WHERE     1 = 1
                                       AND di.line_location_id =
                                           c_rpt_line.po_line_location_id
                                       AND di.order_line_id =
                                           c_rpt_line.po_line_id
                                       AND di.order_id =
                                           c_rpt_line.po_header_id
                                       AND di.container_id = dc.container_id
                                       AND dc.shipment_id = ds.shipment_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    -- Start INC0309112
                                    BEGIN
                                        SELECT ds.invoice_num
                                          INTO l_fact_invoice_num
                                          FROM apps.do_items di, apps.do_containers dc, apps.do_shipments ds
                                         WHERE     1 = 1
                                               AND di.line_location_id =
                                                   c_rpt_line.po_line_location_id
                                               AND di.order_line_id =
                                                   c_rpt_line.po_line_id
                                               AND di.order_id =
                                                   c_rpt_line.po_header_id
                                               AND di.container_id =
                                                   dc.container_id
                                               AND dc.shipment_id =
                                                   ds.shipment_id
                                               AND ROWNUM = 1;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_fact_invoice_num   := 'NA';
                                    END;
                            --l_fact_invoice_num := 'NA';  -- Commented INC0309112
                            -- End INC0309112
                            END;
                        END IF;                                   --CCR0007979

                        -- V2.0 changes start
                        IF p_material_cost_for_pos = 'Y'
                        THEN
                            get_cost_element_values (
                                c_rpt_line.organization_id,
                                c_rpt_line.brand,
                                c_rpt_line.vendor_id,
                                ln_vs_count,
                                ln_vs_duty_cst,
                                ln_vs_frt_cst,
                                ln_vs_fru_du_cst,
                                ln_vs_oh_du_cst,
                                ln_vs_oh_nonduty_cst,
                                ln_vs_ext_duty_cst,
                                ln_vs_ext_frt_cst,
                                ln_vs_ext_fru_du_cst,
                                ln_vs_ext_oh_du_cst,
                                ln_vs_ext_oh_nonduty_cst);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Value set count to derive cost elements for factory invoice num:'
                                || l_fact_invoice_num
                                || '-'
                                || ln_vs_count);

                            /* fnd_file.put_line(fnd_file.log,'ln_vs_duty_cst'||ln_vs_duty_cst);
                          fnd_file.put_line(fnd_file.log,'ln_vs_frt_cst'||ln_vs_frt_cst);
                          fnd_file.put_line(fnd_file.log,'ln_vs_fru_du_cst'||ln_vs_fru_du_cst);
                          fnd_file.put_line(fnd_file.log,'ln_vs_oh_du_cst'||ln_vs_oh_du_cst);
                          fnd_file.put_line(fnd_file.log,'ln_vs_oh_nonduty_cst'||ln_vs_oh_nonduty_cst);*/

                            IF NVL (ln_vs_count, 0) <> 0
                            THEN
                                ln_duty_cst   :=
                                      NVL (c_rpt_line.duty_cost, 0)
                                    * ln_vs_duty_cst;
                                ln_frt_cst   :=
                                      NVL (c_rpt_line.freight_cost, 0)
                                    * ln_vs_frt_cst;
                                ln_fru_du_cst   :=
                                      NVL (c_rpt_line.freight_du_cost, 0)
                                    * ln_vs_fru_du_cst;
                                ln_oh_du_cst   :=
                                      NVL (c_rpt_line.oh_duty_cst, 0)
                                    * ln_vs_oh_du_cst;
                                ln_oh_nonduty_cst   :=
                                      NVL (c_rpt_line.oh_non_duty_cst, 0)
                                    * ln_vs_oh_nonduty_cst;
                                ln_ext_duty_cst   :=
                                      NVL (c_rpt_line.ext_duty_cost, 0)
                                    * ln_vs_ext_duty_cst;
                                ln_ext_frt_cst   :=
                                      NVL (c_rpt_line.ext_freight_cost, 0)
                                    * ln_vs_ext_frt_cst;
                                ln_ext_fru_du_cst   :=
                                      NVL (c_rpt_line.ext_freight_du_cost, 0)
                                    * ln_vs_ext_fru_du_cst;
                                ln_ext_oh_du_cst   :=
                                      NVL (c_rpt_line.ext_oh_duty_cst, 0)
                                    * ln_vs_ext_oh_du_cst;
                                ln_ext_oh_nonduty_cst   :=
                                      NVL (c_rpt_line.ext_oh_non_duty_cst, 0)
                                    * ln_vs_ext_oh_nonduty_cst;
                                ln_item_cst   :=
                                      NVL (c_rpt_line.material_cost, 0)
                                    + NVL (ln_duty_cst, 0)
                                    + NVL (ln_frt_cst, 0)
                                    + NVL (ln_fru_du_cst, 0)
                                    + NVL (ln_oh_du_cst, 0)
                                    + NVL (ln_oh_nonduty_cst, 0);
                                ln_ext_item_cst   :=
                                      NVL (c_rpt_line.ext_material_cost, 0)
                                    + NVL (ln_ext_duty_cst, 0)
                                    + NVL (ln_ext_frt_cst, 0)
                                    + NVL (ln_ext_fru_du_cst, 0)
                                    + NVL (ln_ext_oh_du_cst, 0)
                                    + NVL (ln_ext_oh_nonduty_cst, 0);
                            ELSE
                                ln_duty_cst   :=
                                    NVL (c_rpt_line.duty_cost, 0);
                                ln_frt_cst   :=
                                    NVL (c_rpt_line.freight_cost, 0);
                                ln_fru_du_cst   :=
                                    NVL (c_rpt_line.freight_du_cost, 0);
                                ln_oh_du_cst   :=
                                    NVL (c_rpt_line.oh_duty_cst, 0);
                                ln_oh_nonduty_cst   :=
                                    NVL (c_rpt_line.oh_non_duty_cst, 0);
                                ln_ext_duty_cst   :=
                                    NVL (c_rpt_line.ext_duty_cost, 0);
                                ln_ext_frt_cst   :=
                                    NVL (c_rpt_line.ext_freight_cost, 0);
                                ln_ext_fru_du_cst   :=
                                    NVL (c_rpt_line.ext_freight_du_cost, 0);
                                ln_ext_oh_du_cst   :=
                                    NVL (c_rpt_line.ext_oh_duty_cst, 0);
                                ln_ext_oh_nonduty_cst   :=
                                    NVL (c_rpt_line.ext_oh_non_duty_cst, 0);
                                ln_item_cst   :=
                                    NVL (c_rpt_line.item_cost, 0);
                                ln_ext_item_cst   :=
                                    NVL (c_rpt_line.ext_item_cost, 0);
                            END IF;
                        ELSE           --IF p_material_cost_for_pos = 'Y' THEN
                            ln_duty_cst   := NVL (c_rpt_line.duty_cost, 0);
                            ln_frt_cst    := NVL (c_rpt_line.freight_cost, 0);
                            ln_fru_du_cst   :=
                                NVL (c_rpt_line.freight_du_cost, 0);
                            ln_oh_du_cst   :=
                                NVL (c_rpt_line.oh_duty_cst, 0);
                            ln_oh_nonduty_cst   :=
                                NVL (c_rpt_line.oh_non_duty_cst, 0);
                            ln_ext_duty_cst   :=
                                NVL (c_rpt_line.ext_duty_cost, 0);
                            ln_ext_frt_cst   :=
                                NVL (c_rpt_line.ext_freight_cost, 0);
                            ln_ext_fru_du_cst   :=
                                NVL (c_rpt_line.ext_freight_du_cost, 0);
                            ln_ext_oh_du_cst   :=
                                NVL (c_rpt_line.ext_oh_duty_cst, 0);
                            ln_ext_oh_nonduty_cst   :=
                                NVL (c_rpt_line.ext_oh_non_duty_cst, 0);
                            ln_item_cst   :=
                                NVL (c_rpt_line.item_cost, 0);
                            ln_ext_item_cst   :=
                                NVL (c_rpt_line.ext_item_cost, 0);
                        END IF;

                        -- V2.0 changes end

                        fnd_file.put_line (
                            fnd_file.output,
                               RPAD (c_rpt_line.organization_code, 15, ' ')
                            || RPAD (NVL (c_rpt_line.brand, ' '), 12, ' ')
                            || RPAD (NVL (c_rpt_line.style, ' '), 15, ' ')
                            || RPAD (NVL (c_rpt_line.color, ' '), 10, ' ')
                            || RPAD (NVL (c_rpt_line.item_type, ' '),
                                     15,
                                     ' ')
                            || RPAD (NVL (c_rpt_line.quantity, 0), 13, ' ')
                            --|| RPAD (NVL (c_rpt_line.item_cost, 0), 20, ' ') -- V2.0
                            || RPAD (NVL (ln_item_cst, 0), 20, ' ')    -- V2.0
                            || RPAD (NVL (c_rpt_line.material_cost, 0),
                                     20,
                                     ' ')
                            -- V2.0
                            /*
                            || RPAD (NVL (c_rpt_line.duty_cost, 0), 20, ' ')
                            || RPAD (NVL (c_rpt_line.freight_cost, 0), 20, ' ')
                            || RPAD (NVL (c_rpt_line.freight_du_cost, 0),
                                     20,
                                     ' '
                                    )
                            || RPAD (NVL (c_rpt_line.oh_duty_cst, 0), 20, ' ')
                            || RPAD (NVL (c_rpt_line.oh_non_duty_cst, 0),
                                     20,
                                     ' '
                                    )*/
                            || RPAD (NVL (ln_duty_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_frt_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_fru_du_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_oh_du_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_oh_nonduty_cst, 0), 20, ' ')
                            -- V2.0
                            || RPAD (NVL (c_rpt_line.intransit_type, ' '),
                                     20,
                                     ' ')
                            || RPAD (NVL (c_rpt_line.vendor, ' '), 67, ' ')
                            || RPAD (NVL (c_rpt_line.vendor_reference, ' '),
                                     14,
                                     ' ')
                            || RPAD (NVL (l_fact_invoice_num, ' '), 25, ' ')
                            || RPAD (
                                   NVL (
                                       TO_CHAR (c_rpt_line.transaction_date),
                                       ' '),
                                   15,
                                   ' ')
                            --|| RPAD (NVL (c_rpt_line.ext_item_cost, 0), 20,
                            --' ')
                            || RPAD (NVL (ln_ext_item_cst, 0), 20, ' ')
                            || RPAD (NVL (c_rpt_line.ext_material_cost, 0),
                                     20,
                                     ' ')
                            /*|| RPAD (NVL (c_rpt_line.ext_duty_cost, 0), 20,
                                     ' ')
                            || RPAD (NVL (c_rpt_line.ext_freight_cost, 0),
                                     20,
                                     ' '
                                    )
                            || RPAD (NVL (c_rpt_line.ext_freight_du_cost, 0),
                                     20,
                                     ' '
                                    )
                            || RPAD (NVL (c_rpt_line.ext_oh_duty_cst, 0),
                                     20,
                                     ' '
                                    )
                            || RPAD (NVL (c_rpt_line.ext_oh_non_duty_cst, 0),
                                     20,
                                     ' '
                                    )*/
                            -- V2.0
                            || RPAD (NVL (ln_ext_duty_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_ext_frt_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_ext_fru_du_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_ext_oh_du_cst, 0), 20, ' ')
                            || RPAD (NVL (ln_ext_oh_nonduty_cst, 0),   -- V2.0
                                                                     20, ' ')
                            || CHR (13)
                            || CHR (10));
                    --  );

                    /*8
                                    insert into aaa_kwg_intrans_rpt
                                    values
                                    (
                                        aaa_kwg_intrans_seq.nextval,
                                        rpad(c_rpt_line.organization_code, w_organization_code, ' ') ||
                                        rpad(nvl(c_rpt_line.brand, ' '), w_brand, ' ') ||
                                        rpad(nvl(c_rpt_line.style, ' '), w_style, ' ') ||
                                        rpad(nvl(c_rpt_line.color, ' '), w_color, ' ') ||
                                        rpad(nvl(c_rpt_line.quantity, 0), w_quantity, ' ') ||
                                        rpad(nvl(c_rpt_line.item_cost, 0), w_item_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.material_cost, 0), w_material_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.material_overhead_cost, 0), w_material_overhead_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.freight_cost, 0), w_freight_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.duty_cost, 0), w_duty_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.vendor, ' '), w_vendor, ' ') ||
                                        rpad(nvl(c_rpt_line.vendor_reference, ' '), w_vendor_reference, ' ') ||
                                        rpad(nvl(c_rpt_line.ext_item_cost, 0), w_ext_item_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.ext_material_cost, 0), w_ext_material_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.ext_material_overhead_cost, 0), w_ext_material_overhead_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.ext_freight_cost, 0), w_ext_freight_cost, ' ') ||
                                        rpad(nvl(c_rpt_line.ext_duty_cost, 0), w_ext_duty_cost, ' ')
                                    );
                                    */
                    END LOOP;

                    do_debug_tools.msg (' after report line loop.');
                END IF;
            END LOOP;

            /* BEGIN
     --   execute immediate 'truncate table xxdo.xxd_cst_cg_cost_history_temp_t';-- Added for V1.9 CCR0009519
             null;
             EXCEPTION WHEN OTHERS THEN
                 do_debug_tools.msg ('  Error While truncate the Records '|| SQLERRM);
             END; */
            do_debug_tools.msg ('  done inventory organization loop');
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (' others exception: ' || SQLERRM);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Othere Exception :: ' || SQLERRM);
                perrproc   := 2;
                psqlstat   := SQLERRM;
        END;

        do_debug_tools.msg (
            'perrproc=' || perrproc || ', psqlstat=' || psqlstat);
        do_debug_tools.msg ('-' || l_proc_name);
    END;
END;
/
