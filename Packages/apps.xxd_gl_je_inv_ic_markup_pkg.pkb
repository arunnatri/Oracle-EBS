--
-- XXD_GL_JE_INV_IC_MARKUP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_JE_INV_IC_MARKUP_PKG"
AS
    /******************************************************************************************
     NAME           : XXD_GL_JE_INV_IC_MARKUP_PKG
     Desc           : Deckers Inventory IC Markup for Onhand Journal Creation Program

     REVISIONS:
     Date        Author             Version  Description
     ---------   ----------         -------  ---------------------------------------------------
     08-MAR-2023 Thirupathi Gajula  1.0      Created this package XXD_GL_JE_INV_IC_MARKUP_PKG
                                             for Inventory IC Markup GL Journal Import
    *********************************************************************************************/
    -- ATTRIBUTE1 --> ROUND((ret_oh_rec(i).oh_mrgn_value_local * ret_oh_rec(i).conv_rate), 2),
    -- ATTRIBUTE2 --> Total Item Cost
    -- ATTRIBUTE3 --> oh_markup_local_at_usd
    -- ATTRIBUTE4 --> MARKUP CALC, RATE TYPE, JL RATE TYPE
    -- ATTRIBUTE5 --> curr_active_season
    --Global constants
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_user_name               VARCHAR2 (500) := fnd_global.user_name;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_limit_rec      CONSTANT NUMBER := 500;
    gn_commit_rows    CONSTANT NUMBER := 1000;
    gd_cut_of_date             DATE;
    gn_inv_org_id              NUMBER;
    gv_region                  VARCHAR2 (50);
    gv_brand                   VARCHAR2 (50);
    gv_markup_calc_cur         VARCHAR2 (10);
    gv_onhand_jour_cur         VARCHAR2 (10);
    gv_rate_type               VARCHAR2 (50);
    gv_jl_rate_type            VARCHAR2 (50);
    gv_oh_import_status        VARCHAR2 (500);
    g_category_set_id          NUMBER;
    g_category_set_name        VARCHAR2 (100) := 'OM Sales Category';

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Error in - Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    PROCEDURE load_temp_table (p_as_of_date       IN     DATE,
                               p_inv_org_id       IN     NUMBER,
                               p_cost_type_id     IN     NUMBER,
                               x_ret_stat            OUT VARCHAR2,
                               x_error_messages      OUT VARCHAR2)
    IS
        l_cost_type_id   NUMBER;
        l_msg_cnt        NUMBER;
    BEGIN
        BEGIN
            l_cost_type_id   := p_cost_type_id;

            IF l_cost_type_id IS NULL
            THEN
                SELECT primary_cost_method
                  INTO l_cost_type_id
                  FROM mtl_parameters
                 WHERE organization_id = p_inv_org_id;
            END IF;

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
                p_item_to              => NULL,
                p_category_set_id      => g_category_set_id,
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
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat         := fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
        END;
    END;

    /***********************************************************************************************
    **************************** Procedure for Insert records into Staging *************************
    ************************************************************************************************/

    PROCEDURE insert_oh_records (x_ret_message OUT VARCHAR2)
    AS
        CURSOR Inv_oh_cur IS
            SELECT ood.organization_name,
                   oh_det.organization_id,
                   xcv.item_number,
                   oh_det.inventory_item_id,
                   oh_det.onhand_qty,
                   oh_det.rpt_intrans_qty,
                   oh_det.rec_intrans_qty,
                   gd_cut_of_date
                       as_of_date,
                   apps.xxdoget_item_cost ('ITEMCOST', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'N')
                       item_cost,
                   apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'N')
                       material_cost,
                   apps.xxdoget_item_cost ('NONMATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'N')
                       non_material_cost,
                   apps.xxdoget_item_cost ('DUTY RATE', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'Y')
                       duty_rate,
                   apps.xxdoget_item_cost ('FREIGHT DU', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'Y')
                       freight_du_cost,
                   apps.xxdoget_item_cost ('FREIGHT', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'Y')
                       freight_cost,
                   apps.xxdoget_item_cost ('OH DUTY', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'Y')
                       overhead_du_cost,
                   apps.xxdoget_item_cost ('OH NONDUTY', oh_det.organization_id, oh_det.inventory_item_id
                                           , 'Y')
                       oh_nondu_cost,
                   (SELECT CASE
                               WHEN (apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                                             , 'N')) <
                                    xopm.avg_mrgn_cst_local
                               THEN
                                   apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                                           , 'N')
                               ELSE
                                   NVL (xopm.avg_mrgn_cst_local, 0)
                           END
                      FROM DUAL)
                       oh_mrgn_cst_local,
                   (SELECT CASE
                               WHEN (apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                                             , 'N')) <
                                    xopm.avg_mrgn_cst_local
                               THEN
                                   ROUND (
                                       (  (  NVL (apps.xxdoget_item_cost (
                                                      'MATERIAL',
                                                      oh_det.organization_id,
                                                      oh_det.inventory_item_id,
                                                      'N'),
                                                  0)
                                           / (DECODE (NVL (xopm.avg_mrgn_cst_local, 1), 0, 1, NVL (xopm.avg_mrgn_cst_local, 1))))
                                        * NVL (xopm.avg_mrgn_cst_usd, 0)),
                                       2)
                               ELSE
                                   NVL (xopm.avg_mrgn_cst_usd, 0)
                           END
                      FROM DUAL)
                       oh_mrgn_cst_usd,
                   (  (NVL (oh_det.onhand_qty, 0) + NVL (oh_det.rpt_intrans_qty, 0))
                    * (SELECT CASE
                                  WHEN (apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                                                , 'N')) <
                                       xopm.avg_mrgn_cst_local
                                  THEN
                                      apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                                              , 'N')
                                  ELSE
                                      NVL (xopm.avg_mrgn_cst_local, 0)
                              END
                         FROM DUAL))
                       oh_mrgn_value_local,
                   (  (NVL (oh_det.onhand_qty, 0) + NVL (oh_det.rpt_intrans_qty, 0))
                    * (SELECT CASE
                                  WHEN (apps.xxdoget_item_cost ('MATERIAL', oh_det.organization_id, oh_det.inventory_item_id
                                                                , 'N')) <
                                       xopm.avg_mrgn_cst_local
                                  THEN
                                      ROUND (
                                          (  (  NVL (apps.xxdoget_item_cost (
                                                         'MATERIAL',
                                                         oh_det.organization_id,
                                                         oh_det.inventory_item_id,
                                                         'N'),
                                                     0)
                                              / (DECODE (NVL (xopm.avg_mrgn_cst_local, 1), 0, 1, NVL (xopm.avg_mrgn_cst_local, 1))))
                                           * NVL (xopm.avg_mrgn_cst_usd, 0)),
                                          2)
                                  ELSE
                                      NVL (xopm.avg_mrgn_cst_usd, 0)
                              END
                         FROM DUAL))
                       oh_mrgn_value_usd,
                   gv_onhand_jour_cur
                       oh_journal_currency,
                   (SELECT gl.currency_code
                      FROM gl_ledgers gl, org_organization_definitions ood1
                     WHERE     ood1.set_of_books_id = gl.ledger_id
                           AND ood1.organization_id = ood.organization_id)
                       org_currency,
                   ood.operating_unit
                       ou_id,
                   xcv.brand,
                   xcv.style_number,
                   xcv.color_code,
                   TO_CHAR (xcv.item_size),
                   xcv.curr_active_season,
                   (SELECT DISTINCT gdr.conversion_rate
                      FROM apps.gl_daily_rates gdr
                     WHERE     1 = 1
                           AND gdr.conversion_type = gv_rate_type
                           AND gdr.from_currency =
                               (SELECT gl.currency_code
                                  FROM gl_ledgers gl, org_organization_definitions ood1
                                 WHERE     ood1.set_of_books_id =
                                           gl.ledger_id
                                       AND ood1.organization_id =
                                           ood.organization_id)
                           AND gdr.to_currency = 'USD'
                           AND gdr.conversion_date = gd_cut_of_date)
                       conv_rate
              FROM xxdo.xxd_ont_po_margin_calc_t xopm,
                   apps.xxd_common_items_v xcv,
                   org_organization_definitions ood,
                   (  SELECT sub_qry1.organization_id, sub_qry1.inventory_item_id, SUM (sub_qry1.quantity) quantity,
                             SUM (DECODE (sub_qry1.tpe, 'ONHAND', sub_qry1.quantity, 0)) onhand_qty, SUM (DECODE (sub_qry1.tpe,  'ONHAND', 0,  'RD', 0,  sub_qry1.quantity)) rpt_intrans_qty, SUM (DECODE (sub_qry1.tpe, 'RD', sub_qry1.quantity, 0)) rec_intrans_qty
                        FROM (  SELECT 'ONHAND' tpe, moqd.organization_id, moqd.inventory_item_id,
                                       SUM (moqd.transaction_quantity) AS quantity
                                  FROM apps.mtl_secondary_inventories msi, apps.mtl_onhand_quantities moqd, apps.xxd_common_items_v xcv,
                                       mtl_parameters mp
                                 WHERE     1 = 1
                                       AND xcv.inventory_item_id =
                                           moqd.inventory_item_id
                                       AND xcv.organization_id =
                                           moqd.organization_id
                                       AND xcv.organization_id =
                                           mp.organization_id
                                       AND moqd.organization_id =
                                           mp.organization_id
                                       AND xcv.organization_id =
                                           NVL (gn_inv_org_id,
                                                xcv.organization_id)
                                       AND NVL (mp.attribute1, 'XX') =
                                           NVL (NVL (gv_region, mp.attribute1),
                                                'XX')
                                       AND xcv.brand = NVL (gv_brand, xcv.brand)
                                       AND msi.organization_id =
                                           moqd.organization_id
                                       AND msi.secondary_inventory_name =
                                           moqd.subinventory_code
                                       AND msi.asset_inventory = 1
                                       AND msi.secondary_inventory_name NOT IN
                                               (SELECT ff2.flex_value
                                                  FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                                                 WHERE     ff1.flex_value_set_id =
                                                           ff2.flex_value_set_id
                                                       AND UPPER (
                                                               ff1.flex_value_set_name) =
                                                           UPPER (
                                                               'XXDO_SECONDARY_INV_NAME')
                                                       AND SYSDATE BETWEEN NVL (
                                                                               ff2.start_date_active,
                                                                                 SYSDATE
                                                                               - 1)
                                                                       AND NVL (
                                                                               ff2.end_date_active,
                                                                                 SYSDATE
                                                                               + 1)
                                                       AND ff2.enabled_flag = 'Y')
                              GROUP BY moqd.inventory_item_id, moqd.organization_id
                              UNION ALL
                                SELECT 'ONHAND' tpe, mmt.organization_id, mmt.inventory_item_id,
                                       SUM (-mmt.primary_quantity) AS quantity
                                  FROM apps.mtl_secondary_inventories msi, apps.mtl_material_transactions mmt, apps.xxd_common_items_v xcv,
                                       apps.mtl_parameters mp
                                 WHERE     1 = 1
                                       AND xcv.inventory_item_id =
                                           mmt.inventory_item_id
                                       AND xcv.organization_id =
                                           mmt.organization_id
                                       AND xcv.organization_id =
                                           mp.organization_id
                                       AND mmt.organization_id =
                                           mp.organization_id
                                       AND mmt.transaction_date >=
                                           gd_cut_of_date + 1
                                       AND xcv.organization_id =
                                           NVL (gn_inv_org_id,
                                                xcv.organization_id)
                                       AND NVL (mp.attribute1, 'XX') =
                                           NVL (NVL (gv_region, mp.attribute1),
                                                'XX')
                                       AND xcv.brand = NVL (gv_brand, xcv.brand)
                                       AND msi.organization_id =
                                           mmt.organization_id
                                       AND msi.secondary_inventory_name =
                                           mmt.subinventory_code
                                       AND msi.asset_inventory = 1
                                       AND msi.secondary_inventory_name NOT IN
                                               (SELECT ff2.flex_value
                                                  FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                                                 WHERE     ff1.flex_value_set_id =
                                                           ff2.flex_value_set_id
                                                       AND UPPER (
                                                               ff1.flex_value_set_name) =
                                                           UPPER (
                                                               'XXDO_SECONDARY_INV_NAME')
                                                       AND SYSDATE BETWEEN NVL (
                                                                               ff2.start_date_active,
                                                                                 SYSDATE
                                                                               - 1)
                                                                       AND NVL (
                                                                               ff2.end_date_active,
                                                                                 SYSDATE
                                                                               + 1)
                                                       AND ff2.enabled_flag = 'Y')
                              GROUP BY mmt.organization_id, mmt.inventory_item_id
                              UNION ALL
                              SELECT 'B2B' AS tpe,
                                     rsl.to_organization_id,
                                     rsl.item_id AS inventory_item_id,
                                     NVL (
                                         (SELECT SUM (rt.quantity)
                                            FROM apps.rcv_transactions rt
                                           WHERE     rt.transaction_type =
                                                     'DELIVER'
                                                 AND rt.shipment_line_id =
                                                     rsl.shipment_line_id
                                                 AND rt.transaction_date >=
                                                     gd_cut_of_date + 1),
                                         0) AS quantity
                                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.xxd_common_items_v xcv,
                                     mtl_parameters mp
                               WHERE     1 = 1
                                     AND xcv.organization_id =
                                         mp.organization_id
                                     AND xcv.inventory_item_id = rsl.item_id
                                     AND xcv.organization_id =
                                         NVL (gn_inv_org_id,
                                              xcv.organization_id)
                                     AND NVL (mp.attribute1, 'XX') =
                                         NVL (NVL (gv_region, mp.attribute1),
                                              'XX')
                                     AND xcv.brand = NVL (gv_brand, xcv.brand)
                                     AND rsl.to_organization_id =
                                         xcv.organization_id
                                     AND rsl.source_document_code = 'REQ'
                                     AND rsl.shipment_header_id =
                                         rsh.shipment_header_id
                                     AND rsh.shipped_date < gd_cut_of_date + 1
                                     AND EXISTS
                                             (SELECT NULL
                                                FROM apps.rcv_transactions rt
                                               WHERE     rt.transaction_type =
                                                         'DELIVER'
                                                     AND rt.shipment_line_id =
                                                         rsl.shipment_line_id
                                                     AND rt.transaction_date >=
                                                         gd_cut_of_date)
                                     AND rsl.to_organization_id NOT IN
                                             (SELECT ood.organization_id
                                                FROM fnd_lookup_values fl, org_organization_definitions ood
                                               WHERE     fl.lookup_type =
                                                         'XDO_PO_STAND_RECEIPT_ORGS'
                                                     AND fl.meaning =
                                                         ood.organization_code)
                              UNION ALL
                              SELECT 'B2B' AS tpe, rsl.to_organization_id, rsl.item_id AS inventory_item_id,
                                     rsl.quantity_shipped - rsl.quantity_received AS quantity
                                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.xxd_common_items_v xcv,
                                     mtl_parameters mp
                               WHERE     1 = 1
                                     AND xcv.organization_id =
                                         mp.organization_id
                                     AND xcv.inventory_item_id = rsl.item_id
                                     AND xcv.organization_id =
                                         NVL (gn_inv_org_id,
                                              xcv.organization_id)
                                     AND NVL (mp.attribute1, 'XX') =
                                         NVL (NVL (gv_region, mp.attribute1),
                                              'XX')
                                     AND xcv.brand = NVL (gv_brand, xcv.brand)
                                     AND rsl.to_organization_id =
                                         xcv.organization_id
                                     AND rsl.source_document_code = 'REQ'
                                     AND rsh.shipment_header_id =
                                         rsl.shipment_header_id
                                     AND rsh.shipped_date < gd_cut_of_date + 1
                                     AND quantity_received < quantity_shipped
                                     AND rsl.to_organization_id NOT IN
                                             (SELECT ood.organization_id
                                                FROM fnd_lookup_values fl, org_organization_definitions ood
                                               WHERE     fl.lookup_type =
                                                         'XDO_PO_STAND_RECEIPT_ORGS'
                                                     AND fl.meaning =
                                                         ood.organization_code)
                              UNION ALL
                                SELECT 'RD' AS tpe, organization_id, inventory_item_id,
                                       SUM (quantity) quantity
                                  FROM (  SELECT ms.to_organization_id AS organization_id, pol.item_id AS inventory_item_id, SUM (ms.to_org_primary_quantity) quantity
                                            FROM mtl_supply ms, rcv_transactions rt, po_lines_all pol,
                                                 apps.xxd_common_items_v xcv, mtl_parameters mp
                                           WHERE     ms.to_organization_id =
                                                     xcv.organization_id
                                                 AND xcv.organization_id =
                                                     mp.organization_id
                                                 AND ms.supply_type_code =
                                                     'RECEIVING'
                                                 AND xcv.inventory_item_id =
                                                     pol.item_id
                                                 AND rt.transaction_id =
                                                     ms.rcv_transaction_id
                                                 AND NVL (rt.consigned_flag, 'N') =
                                                     'N'
                                                 AND rt.source_document_code = 'PO'
                                                 AND pol.po_line_id = rt.po_line_id
                                                 AND xcv.organization_id =
                                                     NVL (gn_inv_org_id,
                                                          xcv.organization_id)
                                                 AND NVL (mp.attribute1, 'XX') =
                                                     NVL (
                                                         NVL (gv_region,
                                                              mp.attribute1),
                                                         'XX')
                                                 AND xcv.brand =
                                                     NVL (gv_brand, xcv.brand)
                                        GROUP BY ms.to_organization_id,
                                                 pol.item_id,
                                                 CASE
                                                     WHEN NVL (
                                                              rt.transaction_type,
                                                              ' ') IN
                                                              ('ACCEPT', 'REJECT', 'TRANSFER')
                                                     THEN
                                                         apps.cst_inventory_pvt.get_parentreceivetxn (
                                                             ms.rcv_transaction_id)
                                                     ELSE
                                                         ms.rcv_transaction_id
                                                 END
                                        UNION ALL
                                          SELECT rt.organization_id, pol.item_id AS inventory_item_id, SUM (DECODE (rt.transaction_type,  'RECEIVE', -1 * rt.primary_quantity,  'DELIVER', 1 * rt.primary_quantity,  'RETURN TO RECEIVING', -1 * rt.primary_quantity,  'RETURN TO VENDOR', DECODE (parent_rt.transaction_type, 'UNORDERED', 0, 1 * rt.primary_quantity),  'MATCH', -1 * rt.primary_quantity,  'CORRECT', DECODE (parent_rt.transaction_type,  'UNORDERED', 0,  'RECEIVE', -1 * rt.primary_quantity,  'DELIVER', 1 * rt.primary_quantity,  'RETURN TO RECEIVING', -1 * rt.primary_quantity,  'RETURN TO VENDOR', DECODE (grparent_rt.transaction_type, 'UNORDERED', 0, 1 * rt.primary_quantity),  'MATCH', -1 * rt.primary_quantity,  0),  0)) quantity
                                            FROM rcv_transactions rt, rcv_transactions parent_rt, rcv_transactions grparent_rt,
                                                 po_lines_all pol, apps.xxd_common_items_v xcv, mtl_parameters mp
                                           WHERE     rt.organization_id =
                                                     xcv.organization_id
                                                 AND xcv.organization_id =
                                                     mp.organization_id
                                                 AND xcv.inventory_item_id =
                                                     pol.item_id
                                                 AND xcv.organization_id =
                                                     NVL (gn_inv_org_id,
                                                          xcv.organization_id)
                                                 AND NVL (mp.attribute1, 'XX') =
                                                     NVL (
                                                         NVL (gv_region,
                                                              mp.attribute1),
                                                         'XX')
                                                 AND xcv.brand =
                                                     NVL (gv_brand, xcv.brand)
                                                 AND NVL (rt.consigned_flag, 'N') =
                                                     'N'
                                                 AND NVL (rt.dropship_type_code, 3) =
                                                     3
                                                 AND rt.transaction_date >
                                                     gd_cut_of_date + 1
                                                 AND rt.transaction_type IN
                                                         ('RECEIVE', 'DELIVER', 'RETURN TO RECEIVING',
                                                          'RETURN TO VENDOR', 'CORRECT', 'MATCH')
                                                 AND rt.source_document_code = 'PO'
                                                 AND DECODE (
                                                         rt.parent_transaction_id,
                                                         -1, NULL,
                                                         0, NULL,
                                                         rt.parent_transaction_id) =
                                                     parent_rt.transaction_id(+)
                                                 AND DECODE (
                                                         parent_rt.parent_transaction_id,
                                                         -1, NULL,
                                                         0, NULL,
                                                         parent_rt.parent_transaction_id) =
                                                     grparent_rt.transaction_id(+)
                                                 AND pol.po_line_id = rt.po_line_id
                                                 AND rt.organization_id NOT IN
                                                         (SELECT ood.organization_id
                                                            FROM fnd_lookup_values fl, org_organization_definitions ood
                                                           WHERE     fl.lookup_type =
                                                                     'XDO_PO_STAND_RECEIPT_ORGS'
                                                                 AND fl.meaning =
                                                                     ood.organization_code)
                                        GROUP BY rt.organization_id, pol.item_id
                                          HAVING SUM (
                                                     DECODE (
                                                         rt.transaction_type,
                                                         'RECEIVE', -1 * rt.primary_quantity,
                                                         'DELIVER', 1 * rt.primary_quantity,
                                                         'RETURN TO RECEIVING',   -1
                                                                                * rt.primary_quantity,
                                                         'RETURN TO VENDOR', DECODE (
                                                                                 parent_rt.transaction_type,
                                                                                 'UNORDERED', 0,
                                                                                   1
                                                                                 * rt.primary_quantity),
                                                         'MATCH', -1 * rt.primary_quantity,
                                                         'CORRECT', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        'RECEIVE',   -1
                                                                                   * rt.primary_quantity,
                                                                        'DELIVER',   1
                                                                                   * rt.primary_quantity,
                                                                        'RETURN TO RECEIVING',   -1
                                                                                               * rt.primary_quantity,
                                                                        'RETURN TO VENDOR', DECODE (
                                                                                                grparent_rt.transaction_type,
                                                                                                'UNORDERED', 0,
                                                                                                  1
                                                                                                * rt.primary_quantity),
                                                                        'MATCH',   -1
                                                                                 * rt.primary_quantity,
                                                                        0),
                                                         0)) <>
                                                 0) alpha
                              GROUP BY organization_id, inventory_item_id
                                HAVING SUM (quantity) != 0
                              UNION ALL
                                SELECT 'B2B' AS tpe, organization_id, inventory_item_id,
                                       SUM (quantity) AS quantity
                                  FROM (  SELECT ms.to_organization_id AS organization_id, pol.item_id AS inventory_item_id, SUM (ms.to_org_primary_quantity) quantity
                                            FROM mtl_supply ms, rcv_transactions rt, po_requisition_lines_all pol,
                                                 apps.xxd_common_items_v xcv, mtl_parameters mp
                                           WHERE     ms.to_organization_id =
                                                     xcv.organization_id
                                                 AND xcv.organization_id =
                                                     mp.organization_id
                                                 AND xcv.inventory_item_id =
                                                     pol.item_id
                                                 AND ms.supply_type_code =
                                                     'RECEIVING'
                                                 AND rt.transaction_id =
                                                     ms.rcv_transaction_id
                                                 AND NVL (rt.consigned_flag, 'N') =
                                                     'N'
                                                 AND rt.source_document_code =
                                                     'REQ'
                                                 AND pol.requisition_line_id =
                                                     rt.requisition_line_id
                                                 AND xcv.organization_id =
                                                     NVL (gn_inv_org_id,
                                                          xcv.organization_id)
                                                 AND NVL (mp.attribute1, 'XX') =
                                                     NVL (
                                                         NVL (gv_region,
                                                              mp.attribute1),
                                                         'XX')
                                                 AND xcv.brand =
                                                     NVL (gv_brand, xcv.brand)
                                                 AND rt.organization_id NOT IN
                                                         (SELECT ood.organization_id
                                                            FROM fnd_lookup_values fl, org_organization_definitions ood
                                                           WHERE     fl.lookup_type =
                                                                     'XDO_PO_STAND_RECEIPT_ORGS'
                                                                 AND fl.meaning =
                                                                     ood.organization_code)
                                        GROUP BY ms.to_organization_id,
                                                 pol.item_id,
                                                 CASE
                                                     WHEN NVL (
                                                              rt.transaction_type,
                                                              ' ') IN
                                                              ('ACCEPT', 'REJECT', 'TRANSFER')
                                                     THEN
                                                         apps.cst_inventory_pvt.get_parentreceivetxn (
                                                             ms.rcv_transaction_id)
                                                     ELSE
                                                         ms.rcv_transaction_id
                                                 END) alpha
                              GROUP BY organization_id, inventory_item_id
                                HAVING SUM (quantity) != 0
                              UNION ALL
                              SELECT 'B2B' AS tpe, rsl.to_organization_id, rsl.item_id AS inventory_item_id,
                                     qty.rollback_qty AS quantity
                                FROM cst_item_list_temp item, cst_inv_qty_temp qty, xxd_common_items_v citv,
                                     mtl_parameters mp, cst_inv_cost_temp COST, rcv_shipment_lines rsl,
                                     rcv_shipment_headers rsh
                               --xxdo.xxdoinv_cir_orgs xco
                               WHERE     qty.inventory_item_id =
                                         item.inventory_item_id
                                     AND qty.cost_type_id = item.cost_type_id
                                     --AND qty.organization_id = xco.organization_id
                                     AND citv.organization_id =
                                         qty.organization_id
                                     AND citv.inventory_item_id =
                                         qty.inventory_item_id
                                     AND citv.category_set_id = 1
                                     AND mp.organization_id =
                                         qty.organization_id
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
                                     AND citv.organization_id =
                                         NVL (gn_inv_org_id,
                                              citv.organization_id)
                                     AND NVL (mp.attribute1, 'XX') =
                                         NVL (NVL (gv_region, mp.attribute1),
                                              'XX')
                                     AND citv.brand =
                                         NVL (gv_brand, citv.brand)
                                     AND (rsh.shipped_date IS NOT NULL AND rsh.shipped_date < TO_DATE (NVL (gd_cut_of_date, SYSDATE)) + 1)
                                     AND rsl.creation_date <
                                           TO_DATE (
                                               NVL (gd_cut_of_date,
                                                    TRUNC (SYSDATE)))
                                         + 1
                                     AND rsl.to_organization_id IN
                                             (SELECT ood.organization_id
                                                FROM fnd_lookup_values fl, org_organization_definitions ood
                                               WHERE     fl.lookup_type =
                                                         'XDO_PO_STAND_RECEIPT_ORGS'
                                                     AND fl.meaning =
                                                         ood.organization_code))
                             sub_qry1
                    GROUP BY sub_qry1.organization_id, sub_qry1.inventory_item_id)
                   oh_det
             WHERE     1 = 1
                   AND xopm.inventory_item_id(+) = oh_det.inventory_item_id
                   AND xopm.destination_organization_id(+) =
                       oh_det.organization_id
                   AND xcv.inventory_item_id = oh_det.inventory_item_id
                   AND xcv.organization_id = oh_det.organization_id
                   AND ood.organization_id = oh_det.organization_id
                   AND ood.organization_id = xcv.organization_id
                   AND oh_det.quantity <> 0
                   AND xxdoinv_consol_inv_extract_pkg.get_max_seq_value (
                           oh_det.inventory_item_id,
                           oh_det.organization_id,
                           gd_cut_of_date + 1) =
                       xopm.sequence_number(+)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t stg1
                             WHERE     stg1.as_of_date =
                                       TRUNC (gd_cut_of_date)
                                   AND stg1.record_status = 'P'
                                   AND stg1.organization_id =
                                       xcv.organization_id
                                   AND stg1.inventory_item_id =
                                       xcv.inventory_item_id
                                   AND stg1.brand = xcv.brand);

        --Local variables
        TYPE Inv_oh_rec_type IS RECORD
        (
            organization_name      VARCHAR2 (240),
            organization_id        NUMBER,
            item_number            VARCHAR2 (40),
            inventory_item_id      NUMBER,
            onhand_qty             NUMBER,
            rpt_intrans_qty        NUMBER,
            rec_intrans_qty        NUMBER,
            as_of_date             DATE,
            item_cost              NUMBER,
            material_cost          NUMBER,
            non_material_cost      NUMBER,
            duty_rate              NUMBER,
            freight_du_cost        NUMBER,
            freight_cost           NUMBER,
            overhead_du_cost       NUMBER,
            oh_nondu_cost          NUMBER,
            oh_mrgn_cst_local      NUMBER,
            oh_mrgn_cst_usd        NUMBER,
            oh_mrgn_value_local    NUMBER,
            oh_mrgn_value_usd      NUMBER,
            oh_journal_currency    VARCHAR2 (10),
            org_currency           VARCHAR2 (10),
            ou_id                  NUMBER,
            brand                  VARCHAR2 (40),
            style                  VARCHAR2 (150),
            color                  VARCHAR2 (150),
            item_size              VARCHAR2 (240),
            curr_active_season     VARCHAR2 (240),
            conv_rate              NUMBER
        );

        TYPE Inv_oh_rec_typ IS TABLE OF Inv_oh_rec_type
            INDEX BY BINARY_INTEGER;

        ret_oh_rec     Inv_oh_rec_typ;
        forall_err     EXCEPTION;
        PRAGMA EXCEPTION_INIT (forall_err, -24381);
        l_onhand_cnt   NUMBER;
    BEGIN
        --Delete the data from the ret_oh_rec if exists
        IF ret_oh_rec.COUNT > 0
        THEN
            ret_oh_rec.DELETE;
        END IF;

        --Opening the Cursor
        OPEN Inv_oh_cur;

        LOOP
            FETCH Inv_oh_cur BULK COLLECT INTO ret_oh_rec LIMIT gn_limit_rec;

            IF ret_oh_rec.COUNT > 0
            THEN
                --Bulk Insert of Inventory Onhand data into staging table
                FORALL i IN ret_oh_rec.FIRST .. ret_oh_rec.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T (
                                    organization_name,
                                    organization_id,
                                    item_number,
                                    inventory_item_id,
                                    onhand_qty,
                                    intransit_qty,
                                    total_qty,
                                    as_of_date,
                                    item_cost,
                                    material_cost,
                                    non_material_cost,
                                    duty_rate,
                                    duty,
                                    freight_du_cost,
                                    freight_cost,
                                    overhead_du_cost,
                                    oh_nondu_cost,
                                    oh_mrgn_cst_local,
                                    oh_mrgn_cst_usd,
                                    oh_mrgn_value_local,
                                    oh_mrgn_value_usd,
                                    oh_journal_currency,
                                    org_currency,
                                    ou_id,
                                    region,
                                    inv_org_id,
                                    brand,
                                    style,
                                    color,
                                    item_size,
                                    record_status,
                                    attribute1,
                                    attribute2,
                                    attribute4,
                                    attribute5,
                                    request_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login)
                         VALUES (ret_oh_rec (i).organization_name, ret_oh_rec (i).organization_id, ret_oh_rec (i).item_number, ret_oh_rec (i).inventory_item_id, ret_oh_rec (i).onhand_qty, ret_oh_rec (i).rpt_intrans_qty, -- Intransit Qty
                                                                                                                                                                                                                            (NVL (ret_oh_rec (i).onhand_qty, 0) + NVL (ret_oh_rec (i).rpt_intrans_qty, 0)), -- Total Qty
                                                                                                                                                                                                                                                                                                            ret_oh_rec (i).as_of_date, ret_oh_rec (i).item_cost, ret_oh_rec (i).material_cost, ret_oh_rec (i).non_material_cost, ret_oh_rec (i).duty_rate, ABS (ret_oh_rec (i).non_material_cost - (ret_oh_rec (i).freight_du_cost + ret_oh_rec (i).freight_cost + ret_oh_rec (i).overhead_du_cost + ret_oh_rec (i).oh_nondu_cost)), ret_oh_rec (i).freight_du_cost, ret_oh_rec (i).freight_cost, ret_oh_rec (i).overhead_du_cost, ret_oh_rec (i).oh_nondu_cost, ret_oh_rec (i).oh_mrgn_cst_local, ret_oh_rec (i).oh_mrgn_cst_usd, ret_oh_rec (i).oh_mrgn_value_local, ret_oh_rec (i).oh_mrgn_value_usd, ret_oh_rec (i).oh_journal_currency, ret_oh_rec (i).org_currency, ret_oh_rec (i).ou_id, gv_region, NVL (gn_inv_org_id, ret_oh_rec (i).organization_id), ret_oh_rec (i).brand, ret_oh_rec (i).style, ret_oh_rec (i).color, ret_oh_rec (i).item_size, 'N', ROUND ((ret_oh_rec (i).oh_mrgn_value_local * ret_oh_rec (i).conv_rate), 2), -- -- attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             ((NVL (ret_oh_rec (i).onhand_qty, 0) + NVL (ret_oh_rec (i).rpt_intrans_qty, 0)) * ret_oh_rec (i).item_cost), -- attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gv_markup_calc_cur || ',' || gv_rate_type || ',' || gv_jl_rate_type, -- attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ret_oh_rec (i).curr_active_season, -- attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  gn_request_id, gn_user_id, SYSDATE, gn_user_id
                                 , SYSDATE, gn_login_id);

                COMMIT;
                ret_oh_rec.DELETE;
            --Inventory Onhand Data Cursor records Else
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no Inventory Onhand records for the Parameters provided.');
            END IF;

            EXIT WHEN Inv_oh_cur%NOTFOUND;
        END LOOP;

        CLOSE Inv_oh_cur;
    EXCEPTION
        WHEN forall_err
        THEN
            FOR errs IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (errs).ERROR_CODE));
            END LOOP;

            x_ret_message   := SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to open the Insert rec cursor. Please check the cursor query.'
                || SQLERRM);

            --Close the cursor
            CLOSE Inv_oh_cur;

            x_ret_message   := SQLERRM;
    END insert_oh_records;

    /***********************************************************************************************
    ******************* Procedure for Qty <> 0 and Previous Items Insert into Staging **************
    ************************************************************************************************/

    PROCEDURE insert_oh_prev_records (x_ret_message OUT VARCHAR2)
    AS
        CURSOR inv_oh_cur IS
            SELECT organization_name, organization_id, item_number,
                   inventory_item_id, 0 onhand_qty, 0 intransit_qty,
                   0 total_qty, as_of_date, item_cost,
                   material_cost, non_material_cost, duty_rate,
                   duty, freight_du_cost, freight_cost,
                   overhead_du_cost, oh_nondu_cost, oh_dr_company,
                   oh_dr_brand, oh_dr_geo, oh_dr_channel,
                   oh_dr_dept, oh_dr_account, oh_dr_intercom,
                   oh_dr_future, oh_cr_company, oh_cr_brand,
                   oh_cr_geo, oh_cr_channel, oh_cr_dept,
                   oh_cr_account, oh_cr_intercom, oh_cr_future,
                   0 oh_mrgn_cst_local, 0 oh_mrgn_cst_usd, 0 oh_mrgn_value_local,
                   0 oh_mrgn_value_usd, oh_journal_currency, org_currency,
                   ou_id, brand, style,
                   color, item_size
              FROM apps.xxd_gl_je_inv_ic_markup_stg_t a
             WHERE     a.organization_id =
                       NVL (gn_inv_org_id, a.organization_id)
                   AND NOT EXISTS
                           (SELECT inventory_item_id
                              FROM apps.xxd_gl_je_inv_ic_markup_stg_t b
                             WHERE     a.inventory_item_id =
                                       b.inventory_item_id
                                   AND a.organization_id = b.organization_id
                                   AND b.organization_id =
                                       NVL (gn_inv_org_id, b.organization_id)
                                   AND b.as_of_date = gd_cut_of_date)
                   AND a.as_of_date =
                       (SELECT MAX (c.as_of_date)
                          FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t c
                         WHERE     1 = 1
                               AND c.organization_id =
                                   NVL (gn_inv_org_id, c.organization_id)
                               AND c.record_status = 'P'
                               AND TRUNC (c.as_of_date) >
                                   TRUNC (gd_cut_of_date) - 93)
                   AND a.total_qty <> 0;

        --Local variables
        TYPE inv_oh_rec_type IS RECORD
        (
            organization_name      VARCHAR2 (240),
            organization_id        NUMBER,
            item_number            VARCHAR2 (40),
            inventory_item_id      NUMBER,
            onhand_qty             NUMBER,
            rpt_intrans_qty        NUMBER,
            rec_intrans_qty        NUMBER,
            as_of_date             DATE,
            item_cost              NUMBER,
            material_cost          NUMBER,
            non_material_cost      NUMBER,
            duty_rate              NUMBER,
            duty                   NUMBER,
            freight_du_cost        NUMBER,
            freight_cost           NUMBER,
            overhead_du_cost       NUMBER,
            oh_nondu_cost          NUMBER,
            oh_dr_company          NUMBER,
            oh_dr_brand            NUMBER,
            oh_dr_geo              NUMBER,
            oh_dr_channel          NUMBER,
            oh_dr_dept             NUMBER,
            oh_dr_account          NUMBER,
            oh_dr_intercom         NUMBER,
            oh_dr_future           NUMBER,
            oh_cr_company          NUMBER,
            oh_cr_brand            NUMBER,
            oh_cr_geo              NUMBER,
            oh_cr_channel          NUMBER,
            oh_cr_dept             NUMBER,
            oh_cr_account          NUMBER,
            oh_cr_intercom         NUMBER,
            oh_cr_future           NUMBER,
            oh_mrgn_cst_local      NUMBER,
            oh_mrgn_cst_usd        NUMBER,
            oh_mrgn_value_local    NUMBER,
            oh_mrgn_value_usd      NUMBER,
            oh_journal_currency    VARCHAR2 (10),
            org_currency           VARCHAR2 (10),
            ou_id                  NUMBER,
            brand                  VARCHAR2 (40),
            style                  VARCHAR2 (150),
            color                  VARCHAR2 (150),
            item_size              VARCHAR2 (240)
        );

        TYPE inv_oh_rec_typ IS TABLE OF inv_oh_rec_type
            INDEX BY BINARY_INTEGER;

        ret_oh_rec     inv_oh_rec_typ;
        forall_err     EXCEPTION;
        PRAGMA EXCEPTION_INIT (forall_err, -24381);
        l_onhand_cnt   NUMBER;
    BEGIN
        --Delete the data from the ret_oh_rec if exists
        IF ret_oh_rec.COUNT > 0
        THEN
            ret_oh_rec.DELETE;
        END IF;

        --Opening the Cursor
        OPEN inv_oh_cur;

        LOOP
            FETCH inv_oh_cur BULK COLLECT INTO ret_oh_rec LIMIT gn_limit_rec;

            IF ret_oh_rec.COUNT > 0
            THEN
                --Bulk Insert of Inventory Onhand data into staging table
                FORALL i IN ret_oh_rec.FIRST .. ret_oh_rec.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxd_gl_je_inv_ic_markup_stg_t (
                                    organization_name,
                                    organization_id,
                                    item_number,
                                    inventory_item_id,
                                    onhand_qty,
                                    intransit_qty,
                                    total_qty,
                                    as_of_date,
                                    item_cost,
                                    material_cost,
                                    non_material_cost,
                                    duty_rate,
                                    duty,
                                    freight_du_cost,
                                    freight_cost,
                                    overhead_du_cost,
                                    oh_nondu_cost,
                                    oh_mrgn_cst_local,
                                    oh_mrgn_cst_usd,
                                    oh_mrgn_value_local,
                                    oh_mrgn_value_usd,
                                    oh_journal_currency,
                                    org_currency,
                                    ou_id,
                                    region,
                                    inv_org_id,
                                    brand,
                                    style,
                                    color,
                                    item_size,
                                    record_status,
                                    attribute1,
                                    attribute2,
                                    attribute4,
                                    request_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login)
                         VALUES (ret_oh_rec (i).organization_name, ret_oh_rec (i).organization_id, ret_oh_rec (i).item_number, ret_oh_rec (i).inventory_item_id, ret_oh_rec (i).onhand_qty, ret_oh_rec (i).rpt_intrans_qty, -- Intransit Qty
                                                                                                                                                                                                                            (NVL (ret_oh_rec (i).onhand_qty, 0) + NVL (ret_oh_rec (i).rpt_intrans_qty, 0)), -- Total Qty
                                                                                                                                                                                                                                                                                                            gd_cut_of_date, -- ret_oh_rec(i).as_of_date,
                                                                                                                                                                                                                                                                                                                            ret_oh_rec (i).item_cost, ret_oh_rec (i).material_cost, ret_oh_rec (i).non_material_cost, ret_oh_rec (i).duty_rate, ABS (ret_oh_rec (i).non_material_cost - (ret_oh_rec (i).freight_du_cost + ret_oh_rec (i).freight_cost + ret_oh_rec (i).overhead_du_cost + ret_oh_rec (i).oh_nondu_cost)), ret_oh_rec (i).freight_du_cost, ret_oh_rec (i).freight_cost, ret_oh_rec (i).overhead_du_cost, ret_oh_rec (i).oh_nondu_cost, ret_oh_rec (i).oh_mrgn_cst_local, ret_oh_rec (i).oh_mrgn_cst_usd, ret_oh_rec (i).oh_mrgn_value_local, ret_oh_rec (i).oh_mrgn_value_usd, ret_oh_rec (i).oh_journal_currency, ret_oh_rec (i).org_currency, ret_oh_rec (i).ou_id, gv_region, NVL (gn_inv_org_id, ret_oh_rec (i).organization_id), ret_oh_rec (i).brand, ret_oh_rec (i).style, ret_oh_rec (i).color, ret_oh_rec (i).item_size, 'N', 0, -- attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         0, -- attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            gv_markup_calc_cur || ',' || gv_rate_type || ',' || gv_jl_rate_type, -- attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 gn_request_id, gn_user_id, SYSDATE, gn_user_id, SYSDATE
                                 , gn_login_id);

                COMMIT;
                ret_oh_rec.DELETE;
            --Inventory Onhand Data Cursor records Else
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no Inventory Onhand records for the Parameters provided.');
            END IF;

            EXIT WHEN inv_oh_cur%NOTFOUND;
        END LOOP;

        CLOSE inv_oh_cur;
    EXCEPTION
        WHEN forall_err
        THEN
            FOR errs IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (errs).ERROR_CODE));
            END LOOP;

            x_ret_message   := SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to open the Insert rec cursor. Please check the cursor query.'
                || SQLERRM);

            --Close the cursor
            CLOSE inv_oh_cur;

            x_ret_message   := SQLERRM;
    END insert_oh_prev_records;

    /***********************************************************************************************
    **************************** Function to get ledger currency ***********************************
    ************************************************************************************************/

    FUNCTION get_ledger_currency (p_ledger_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ledger_currency   VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT currency_code
              INTO l_ledger_currency
              FROM gl_ledgers
             WHERE ledger_id = p_ledger_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to get Ledger urrency:' || SQLERRM);
        END;

        RETURN l_ledger_currency;
    END get_ledger_currency;

    /***********************************************************************************************
    **************************** Function to get period name ***************************************
    ************************************************************************************************/

    FUNCTION get_period_name (p_ledger_id IN NUMBER, p_gl_date IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_period_name   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT period_name
              INTO lv_period_name
              FROM gl_period_statuses
             WHERE     application_id = 101
                   AND ledger_id = p_ledger_id
                   AND closing_status = 'O'
                   AND p_gl_date BETWEEN start_date AND end_date;

            fnd_file.put_line (fnd_file.LOG,
                               'Period Name is:' || lv_period_name);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Open Period is not found for Date : '
                    || p_gl_date
                    || CHR (9)
                    || ' ledger ID = '
                    || p_ledger_id);

                lv_period_name   := NULL;
            WHEN TOO_MANY_ROWS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Multiple Open periods found for date : '
                    || p_gl_date
                    || CHR (9)
                    || ' ledger ID = '
                    || p_ledger_id);

                lv_period_name   := NULL;
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Exception found while getting open period date for  : '
                    || p_gl_date
                    || CHR (9)
                    || SQLERRM);

                lv_period_name   := NULL;
        END;

        RETURN lv_period_name;
    END get_period_name;

    /***********************************************************************************************
    ************************** Function to Get Conversion Rate *************************************
    ************************************************************************************************/

    FUNCTION get_conv_rate (pv_from_currency IN VARCHAR2, pv_to_currency IN VARCHAR2, pv_conversion_type IN VARCHAR2
                            , pd_conversion_date IN DATE)
        RETURN NUMBER
    IS
        ln_conversion_rate   NUMBER := 0;
    BEGIN
        SELECT gdr.conversion_rate
          INTO ln_conversion_rate
          FROM apps.gl_daily_rates gdr
         WHERE     1 = 1
               AND gdr.conversion_type = pv_conversion_type
               AND gdr.from_currency = pv_from_currency
               AND gdr.to_currency = pv_to_currency
               AND gdr.conversion_date = pd_conversion_date;

        RETURN ln_conversion_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in GET_CONV_RATE Procedure -' || SQLERRM);
            ln_conversion_rate   := 0;
            RETURN ln_conversion_rate;
    END get_conv_rate;

    /***********************************************************************************************
    ****************** Procedure to update Segment and Markup values details ***********************
    ************************************************************************************************/

    PROCEDURE update_seg_markupvalues (x_ret_msg OUT NOCOPY VARCHAR2)
    IS
        lv_js_elimination                gl_je_sources.user_je_source_name%TYPE;
        lv_journal_cat_elimination       gl_je_categories.user_je_category_name%TYPE;
        lv_oh_period_name                gl_periods.period_name%TYPE;
        l_journal_batch                  VARCHAR2 (500);
        l_journal_name                   VARCHAR2 (500);
        l_onhand_ledger                  VARCHAR2 (240);
        l_onhand_source                  VARCHAR2 (240);
        l_onhand_category                VARCHAR2 (240);
        l_oh_journal_batch               VARCHAR2 (500);
        l_oh_journal_name                VARCHAR2 (500);
        ln_oh_prev_margin_value_local    NUMBER;
        ln_oh_prev_margin_value_usd      NUMBER;
        ln_oh_prev_markup_local_at_usd   NUMBER;
        ln_oh_markup_local_at_usd        NUMBER;
        ln_oh_markup_local               NUMBER;
        ln_oh_markup_usd                 NUMBER;
        ln_ou_id                         NUMBER;
        ln_mrgn_cst_local                NUMBER;
        ln_mrgn_value_local              NUMBER;
        ln_ledger_id                     NUMBER;
        lv_ledger_currency               VARCHAR2 (10);
        l_oh_dr_company                  VARCHAR2 (50);
        l_oh_dr_brand                    VARCHAR2 (50);
        l_oh_dr_geo                      VARCHAR2 (50);
        l_oh_dr_channel                  VARCHAR2 (50);
        l_oh_dr_dept                     VARCHAR2 (50);
        l_oh_dr_account                  VARCHAR2 (50);
        l_oh_dr_intercom                 VARCHAR2 (50);
        l_oh_dr_future                   VARCHAR2 (50);
        l_oh_cr_company                  VARCHAR2 (50);
        l_oh_cr_brand                    VARCHAR2 (50);
        l_oh_cr_geo                      VARCHAR2 (50);
        l_oh_cr_channel                  VARCHAR2 (50);
        l_oh_cr_dept                     VARCHAR2 (50);
        l_oh_cr_account                  VARCHAR2 (50);
        l_oh_cr_intercom                 VARCHAR2 (50);
        l_oh_cr_future                   VARCHAR2 (50);
        lv_mat_conc_seg                  VARCHAR2 (50);
        lv_mat_company                   VARCHAR2 (50);
        lv_mat_brand                     VARCHAR2 (50);
        lv_mat_geo                       VARCHAR2 (50);
        lv_mat_channel                   VARCHAR2 (50);
        lv_mat_dept                      VARCHAR2 (50);
        lv_mat_acct                      VARCHAR2 (50);
        lv_mat_intercom                  VARCHAR2 (50);
        lv_mat_future                    VARCHAR2 (50);
        lv_dr_code_comb                  VARCHAR2 (50);
        lv_cr_code_comb                  VARCHAR2 (50);
        ln_conv_rate_usd                 NUMBER;
        lv_itm_conc_seg                  VARCHAR2 (50);
        lv_itm_company                   VARCHAR2 (50);
        lv_itm_brand                     VARCHAR2 (50);
        lv_itm_geo                       VARCHAR2 (50);
        lv_itm_channel                   VARCHAR2 (50);
        lv_itm_dept                      VARCHAR2 (50);
        lv_itm_acct                      VARCHAR2 (50);
        lv_itm_intercom                  VARCHAR2 (50);
        lv_itm_future                    VARCHAR2 (50);

        CURSOR c_oh_markup_data IS
            SELECT stg.ROWID oh_row_id, stg.*
              FROM xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T stg
             WHERE request_id = gn_request_id AND record_status = 'N';
    BEGIN
        write_log ('Start update_seg_markupvalues');

        FOR r_oh_markup_data IN c_oh_markup_data
        LOOP
            ln_oh_prev_margin_value_local   := 0;
            ln_oh_prev_margin_value_usd     := 0;
            ln_oh_markup_local              := 0;
            ln_oh_markup_usd                := 0;
            ln_mrgn_cst_local               := 0;
            ln_mrgn_value_local             := 0;
            l_oh_dr_company                 := NULL;
            l_oh_dr_brand                   := NULL;
            l_oh_dr_geo                     := NULL;
            l_oh_dr_channel                 := NULL;
            l_oh_dr_dept                    := NULL;
            l_oh_dr_account                 := NULL;
            l_oh_dr_intercom                := NULL;
            l_oh_dr_future                  := NULL;
            l_oh_cr_company                 := NULL;
            l_oh_cr_brand                   := NULL;
            l_oh_cr_geo                     := NULL;
            l_oh_cr_channel                 := NULL;
            l_oh_cr_dept                    := NULL;
            l_oh_cr_account                 := NULL;
            l_oh_cr_intercom                := NULL;
            l_oh_cr_future                  := NULL;
            lv_mat_conc_seg                 := NULL;
            lv_mat_company                  := NULL;
            lv_mat_brand                    := NULL;
            lv_mat_geo                      := NULL;
            lv_mat_channel                  := NULL;
            lv_mat_dept                     := NULL;
            lv_mat_acct                     := NULL;
            lv_mat_intercom                 := NULL;
            lv_mat_future                   := NULL;
            lv_dr_code_comb                 := NULL;
            lv_cr_code_comb                 := NULL;
            ln_ledger_id                    := NULL;
            ln_conv_rate_usd                := NULL;
            lv_ledger_currency              := NULL;
            lv_itm_conc_seg                 := NULL;
            lv_itm_company                  := NULL;
            lv_itm_brand                    := NULL;
            lv_itm_geo                      := NULL;
            lv_itm_channel                  := NULL;
            lv_itm_dept                     := NULL;
            lv_itm_acct                     := NULL;
            lv_itm_intercom                 := NULL;
            lv_itm_future                   := NULL;

            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3,
                       ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                       ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                       ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                       ffvl.attribute13, ffvl.attribute14, ffvl.attribute15,
                       ffvl.attribute16
                  INTO l_oh_dr_company, l_oh_dr_brand, l_oh_dr_geo, l_oh_dr_channel,
                                      l_oh_dr_dept, l_oh_dr_account, l_oh_dr_intercom,
                                      l_oh_dr_future, l_oh_cr_company, l_oh_cr_brand,
                                      l_oh_cr_geo, l_oh_cr_channel, l_oh_cr_dept,
                                      l_oh_cr_account, l_oh_cr_intercom, l_oh_cr_future
                  FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ffvl
                 WHERE     ff1.flex_value_set_id = ffvl.flex_value_set_id
                       AND UPPER (ff1.flex_value_set_name) =
                           UPPER ('XXD_INV_IC_MARKUP_VS')
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE - 1)
                                       AND NVL (ffvl.end_date_active,
                                                SYSDATE + 1)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.flex_value = r_oh_markup_data.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            SELECT gcc1.concatenated_segments, gcc1.segment1, gcc2.segment2,
                   gcc1.segment3, gcc1.segment4, gcc1.segment5,
                   gcc1.segment6, gcc1.segment7, gcc1.segment8,
                   gcc2.concatenated_segments, gcc2.segment1, gcc2.segment2,
                   gcc2.segment3, gcc2.segment4, gcc2.segment5,
                   gcc2.segment6, gcc2.segment7, gcc2.segment8
              INTO lv_mat_conc_seg, lv_mat_company, lv_mat_brand, lv_mat_geo,
                                  lv_mat_channel, lv_mat_dept, lv_mat_acct,
                                  lv_mat_intercom, lv_mat_future, lv_itm_conc_seg,
                                  lv_itm_company, lv_itm_brand, lv_itm_geo,
                                  lv_itm_channel, lv_itm_dept, lv_itm_acct,
                                  lv_itm_intercom, lv_itm_future
              FROM apps.gl_code_combinations_kfv gcc1, apps.mtl_parameters mp, apps.mtl_system_items_b msib,
                   apps.gl_code_combinations_kfv gcc2
             WHERE     1 = 1
                   AND gcc1.code_combination_id = mp.material_account
                   AND gcc2.code_combination_id = msib.cost_of_sales_account
                   AND mp.organization_id = r_oh_markup_data.inv_org_id
                   AND msib.organization_id = mp.organization_id
                   AND msib.inventory_item_id =
                       r_oh_markup_data.inventory_item_id;

            IF l_oh_dr_company IS NULL
            THEN
                l_oh_dr_company   := lv_mat_company;
            END IF;

            IF l_oh_dr_brand IS NULL
            THEN
                l_oh_dr_brand   := lv_mat_brand;
            END IF;

            IF l_oh_dr_geo IS NULL
            THEN
                l_oh_dr_geo   := lv_mat_geo;
            END IF;

            IF l_oh_dr_channel IS NULL
            THEN
                l_oh_dr_channel   := lv_mat_channel;
            END IF;

            IF l_oh_dr_dept IS NULL
            THEN
                l_oh_dr_dept   := lv_mat_dept;
            END IF;

            IF l_oh_dr_account IS NULL
            THEN
                l_oh_dr_account   := lv_mat_acct;
            END IF;

            IF l_oh_dr_intercom IS NULL
            THEN
                l_oh_dr_intercom   := lv_mat_intercom;
            END IF;

            IF l_oh_dr_future IS NULL
            THEN
                l_oh_dr_future   := lv_mat_future;
            END IF;

            IF l_oh_cr_company IS NULL
            THEN
                l_oh_cr_company   := lv_mat_company;
            END IF;

            IF l_oh_cr_brand IS NULL
            THEN
                l_oh_cr_brand   := lv_mat_brand;
            END IF;

            IF l_oh_cr_geo IS NULL
            THEN
                l_oh_cr_geo   := lv_mat_geo;
            END IF;

            IF l_oh_cr_channel IS NULL
            THEN
                l_oh_cr_channel   := lv_mat_channel;
            END IF;

            IF l_oh_cr_dept IS NULL
            THEN
                l_oh_cr_dept   := lv_mat_dept;
            END IF;

            IF l_oh_cr_account IS NULL
            THEN
                l_oh_cr_account   := lv_mat_acct;
            END IF;

            IF l_oh_cr_intercom IS NULL
            THEN
                l_oh_cr_intercom   := lv_mat_intercom;
            END IF;

            IF l_oh_cr_future IS NULL
            THEN
                l_oh_cr_future   := lv_mat_future;
            END IF;

            lv_dr_code_comb                 :=
                   l_oh_dr_company
                || '.'
                || l_oh_dr_brand
                || '.'
                || l_oh_dr_geo
                || '.'
                || l_oh_dr_channel
                || '.'
                || l_oh_dr_dept
                || '.'
                || l_oh_dr_account
                || '.'
                || l_oh_dr_intercom
                || '.'
                || l_oh_dr_future;
            lv_cr_code_comb                 :=
                   l_oh_cr_company
                || '.'
                || l_oh_cr_brand
                || '.'
                || l_oh_cr_geo
                || '.'
                || l_oh_cr_channel
                || '.'
                || l_oh_cr_dept
                || '.'
                || l_oh_cr_account
                || '.'
                || l_oh_cr_intercom
                || '.'
                || l_oh_cr_future;

            BEGIN
                SELECT ffvl.attribute6
                  INTO ln_ledger_id
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_name = 'DO_GL_COMPANY'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffvl.flex_value = l_oh_dr_company;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            lv_ledger_currency              :=
                get_ledger_currency (ln_ledger_id);

            BEGIN
                SELECT NVL (
                           CASE
                               WHEN     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                       , 1) = 'Local'
                                    AND oh_journal_currency = 'USD'
                               THEN
                                     NVL (attribute1, 0)
                                   * (SELECT NVL (gdr.conversion_rate, 0)
                                        FROM apps.gl_daily_rates gdr
                                       WHERE     gdr.conversion_type =
                                                 REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                                , 2)
                                             AND gdr.from_currency = 'USD'
                                             AND gdr.to_currency =
                                                 org_currency
                                             AND gdr.conversion_date =
                                                 TRUNC (as_of_date))
                               WHEN REGEXP_SUBSTR (attribute4, '[^,]+', 1,
                                                   1) = 'USD' --AND oh_journal_currency = 'USD'
                               THEN
                                     NVL (oh_mrgn_value_usd, 0)
                                   * (SELECT NVL (gdr.conversion_rate, 0)
                                        FROM apps.gl_daily_rates gdr
                                       WHERE     gdr.conversion_type =
                                                 REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                                , 2)
                                             AND gdr.from_currency = 'USD'
                                             AND gdr.to_currency =
                                                 org_currency
                                             AND gdr.conversion_date =
                                                 TRUNC (as_of_date))
                               WHEN     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                       , 1) = 'Local'
                                    AND oh_journal_currency = 'Local'
                               THEN
                                   NVL (oh_mrgn_value_local, 0)
                               ELSE
                                   NVL (oh_mrgn_value_local, 0)
                           END,
                           0)
                  INTO ln_oh_prev_margin_value_local
                  FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY as_of_date DESC) rn
                          FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t a
                         WHERE     1 = 1
                               AND a.organization_id =
                                   r_oh_markup_data.organization_id
                               AND a.inventory_item_id =
                                   r_oh_markup_data.inventory_item_id
                               AND a.record_status = 'P')
                 WHERE rn = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_prev_margin_value_local   := 0;
            END;

            BEGIN
                SELECT NVL (
                           CASE
                               WHEN     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                       , 1) = 'Local'
                                    AND oh_journal_currency = 'USD'
                               THEN
                                   NVL (TO_NUMBER (attribute1), 0)
                               WHEN REGEXP_SUBSTR (attribute4, '[^,]+', 1,
                                                   1) = 'USD' --AND oh_journal_currency = 'USD'
                               THEN
                                   NVL (oh_mrgn_value_usd, 0)
                               WHEN     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                       , 1) = 'Local'
                                    AND oh_journal_currency = 'Local'
                               THEN
                                     NVL (oh_mrgn_value_local, 0)
                                   * (SELECT NVL (gdr.conversion_rate, 0)
                                        FROM apps.gl_daily_rates gdr
                                       WHERE     gdr.conversion_type =
                                                 REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                                , 2)
                                             AND gdr.from_currency =
                                                 org_currency
                                             AND gdr.to_currency = 'USD'
                                             AND gdr.conversion_date =
                                                 TRUNC (as_of_date))
                               ELSE
                                   NVL (oh_mrgn_value_usd, 0)
                           END,
                           0)
                  INTO ln_oh_prev_margin_value_usd
                  FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY as_of_date DESC) rn
                          FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t a
                         WHERE     1 = 1
                               AND a.organization_id =
                                   r_oh_markup_data.organization_id
                               AND a.inventory_item_id =
                                   r_oh_markup_data.inventory_item_id
                               AND a.record_status = 'P')
                 WHERE rn = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_prev_margin_value_usd   := 0;
            END;

            BEGIN
                SELECT NVL (
                           CASE
                               WHEN     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                       , 1) = 'Local'
                                    AND oh_journal_currency = 'USD'
                               THEN
                                   NVL (TO_NUMBER (attribute1), 0)
                               WHEN REGEXP_SUBSTR (attribute4, '[^,]+', 1,
                                                   1) = 'USD' --AND oh_journal_currency = 'USD'
                               THEN
                                   NVL (oh_mrgn_value_usd, 0)
                               WHEN     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                       , 1) = 'Local'
                                    AND oh_journal_currency = 'Local'
                               THEN
                                   NVL (
                                       TO_NUMBER (attribute1),
                                         NVL (oh_mrgn_value_local, 0)
                                       * (SELECT NVL (gdr.conversion_rate, 0)
                                            FROM apps.gl_daily_rates gdr
                                           WHERE     gdr.conversion_type =
                                                     REGEXP_SUBSTR (attribute4, '[^,]+', 1
                                                                    , 2)
                                                 AND gdr.from_currency =
                                                     org_currency
                                                 AND gdr.to_currency = 'USD'
                                                 AND gdr.conversion_date =
                                                     TRUNC (as_of_date)))
                               ELSE
                                   NVL (TO_NUMBER (attribute1),
                                        NVL (oh_mrgn_value_usd, 0))
                           END,
                           0)
                  INTO ln_oh_prev_markup_local_at_usd
                  FROM (SELECT a.*, ROW_NUMBER () OVER (ORDER BY as_of_date DESC) rn
                          FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t a
                         WHERE     1 = 1
                               AND a.organization_id =
                                   r_oh_markup_data.organization_id
                               AND a.inventory_item_id =
                                   r_oh_markup_data.inventory_item_id
                               AND a.record_status = 'P')
                 WHERE rn = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_prev_markup_local_at_usd   := 0;
            END;

            ln_oh_markup_local              :=
                (r_oh_markup_data.oh_mrgn_value_local - ln_oh_prev_margin_value_local);
            ln_oh_markup_usd                :=
                (r_oh_markup_data.oh_mrgn_value_usd - ln_oh_prev_margin_value_usd);
            ln_oh_markup_local_at_usd       :=
                (r_oh_markup_data.attribute1 - ln_oh_prev_markup_local_at_usd);

            BEGIN
                UPDATE xxdo.xxd_gl_je_inv_ic_markup_stg_t
                   SET oh_markup_local = ln_oh_markup_local, oh_markup_usd = ln_oh_markup_usd, attribute3 = ln_oh_markup_local_at_usd,
                       ledger_currency = lv_ledger_currency, oh_dr_company = l_oh_dr_company, oh_dr_brand = l_oh_dr_brand,
                       oh_dr_geo = l_oh_dr_geo, oh_dr_channel = l_oh_dr_channel, oh_dr_dept = l_oh_dr_dept,
                       oh_dr_account = l_oh_dr_account, oh_dr_intercom = l_oh_dr_intercom, oh_dr_future = l_oh_dr_future,
                       oh_cr_company = l_oh_cr_company, oh_cr_brand = l_oh_cr_brand, oh_cr_geo = l_oh_cr_geo,
                       oh_cr_channel = l_oh_cr_channel, oh_cr_dept = l_oh_cr_dept, oh_cr_account = l_oh_cr_account,
                       oh_cr_intercom = l_oh_cr_intercom, oh_cr_future = l_oh_cr_future, oh_debit_code_comb = lv_dr_code_comb,
                       oh_credit_code_comb = lv_cr_code_comb, ledger_id = ln_ledger_id
                 WHERE     ROWID = r_oh_markup_data.oh_row_id
                       AND organization_id = r_oh_markup_data.organization_id
                       AND inventory_item_id =
                           r_oh_markup_data.inventory_item_id
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('update_seg_markupvalues' || SQLERRM);
            x_ret_msg   := 'update_seg_markupvalues-' || SQLERRM;
    END update_seg_markupvalues;

    /***********************************************************************************************
    **************************** Function to get journal source for Elimination ********************
    ************************************************************************************************/

    FUNCTION get_js_elimination (p_onhand_source VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_je_source_elimination   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT user_je_source_name
              INTO lv_je_source_elimination
              FROM gl_je_sources
             WHERE user_je_source_name = p_onhand_source AND language = 'US';

            fnd_file.put_line (
                fnd_file.LOG,
                   'Journal Source for Elimination is: '
                || lv_je_source_elimination);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_source_elimination   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch Journal source for elimination '
                    || SQLERRM);
        END;

        RETURN lv_je_source_elimination;
    END get_js_elimination;

    /***********************************************************************************************
    *************************** Function to get journal Category Elimination ***********************
    ************************************************************************************************/

    FUNCTION get_journal_cat_elimination (p_onhand_category VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_je_cat_elimination   VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT user_je_category_name
              INTO lv_je_cat_elimination
              FROM gl_je_categories
             WHERE     user_je_category_name = p_onhand_category
                   AND language = 'US';

            fnd_file.put_line (
                fnd_file.LOG,
                   'Journal Category for elimination is: '
                || lv_je_cat_elimination);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_cat_elimination   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch Journal Category for elimination '
                    || SQLERRM);
        END;

        RETURN lv_je_cat_elimination;
    END get_journal_cat_elimination;

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================

    PROCEDURE generate_setup_err_prc (p_setup_err IN VARCHAR2)
    IS
        lv_message      VARCHAR2 (32000);
        lv_recipients   VARCHAR2 (4000);
        lv_result       VARCHAR2 (100);
        lv_result_msg   VARCHAR2 (4000);
    BEGIN
        lv_message   :=
               p_setup_err
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please do not reply.';

        BEGIN
            SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
              INTO lv_recipients
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_GL_COMMON_EMAILS_LKP'
                   AND lookup_code = '10002'
                   AND enabled_flag = 'Y'
                   AND language = 'US'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_recipients   := NULL;
        END;

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => lv_recipients,
            pv_ccrecipients   => NULL,
            pv_subject        =>
                'Deckers Inventory IC Markup for Onhand Journal output',
            pv_message        => lv_message,
            pv_attachments    => NULL,
            xv_result         => lv_result,
            xv_result_msg     => lv_result_msg);

        write_log ('Result is - ' || lv_result);
        write_log ('Result MSG is - ' || lv_result_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            write_log ('Exception in generate_setup_err_prc- ' || SQLERRM);
    END generate_setup_err_prc;

    /***********************************************************************************************
    ************************** Procedure to validate staging GL Data *******************************
    ************************************************************************************************/

    PROCEDURE validate_gl_data (x_ret_msg OUT NOCOPY VARCHAR2)
    IS
        lv_js_elimination            gl_je_sources.user_je_source_name%TYPE;
        lv_journal_cat_elimination   gl_je_categories.user_je_category_name%TYPE;
        lv_cur_code                  fnd_currencies.currency_code%TYPE;
        lv_ledger_id                 NUMBER;
        lv_ret_status                VARCHAR2 (1);
        lv_ret_msg                   VARCHAR2 (4000);
        lv_credit_ccid               VARCHAR2 (2000);
        lv_debit_ccid                VARCHAR2 (2000);
        ln_structure_number          NUMBER;
        lb_sucess                    BOOLEAN;
        v_seg_count                  NUMBER;
        lv_ledger_name               gl_ledgers.name%TYPE;
        l_onhand_ledger              VARCHAR2 (240);
        lv_oh_period_name            gl_periods.period_name%TYPE;
        lv_ledger_currency           VARCHAR2 (3);
        l_onhand_source              VARCHAR2 (240);
        l_onhand_category            VARCHAR2 (240);
        l_oh_journal_batch           VARCHAR2 (500);
        l_oh_journal_name            VARCHAR2 (500);
        ln_ledger_id                 NUMBER;

        CURSOR c_gl_oh_data IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T stg
             WHERE request_id = gn_request_id AND record_status = 'N';
    BEGIN
        write_log ('Start validate_gl_data');
        lv_ret_status        := 'S';
        lv_ret_msg           := NULL;
        lv_oh_period_name    := NULL;
        lv_ledger_currency   := NULL;

        BEGIN
            SELECT stg.ledger_id
              INTO ln_ledger_id
              FROM xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T stg
             WHERE request_id = gn_request_id AND record_status = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        lv_oh_period_name    :=
            get_period_name (ln_ledger_id, gd_cut_of_date);

        SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3,
               ffvl.attribute4, ffvl.attribute5
          INTO l_onhand_ledger, l_onhand_source, l_onhand_category, l_oh_journal_batch,
                              l_oh_journal_name
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_name = 'XXD_GL_JE_IC_MARKUP_TYPES'
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND flex_value = 'INV_IC_MARKUP'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE + 1)
               AND ffvl.enabled_flag = 'Y';

        -- Update status and derived values in to STG table
        UPDATE xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T
           SET period_name = lv_oh_period_name, --ledger_currency = lv_ledger_currency,
                                                user_je_source_name = l_onhand_source, user_je_category_name = l_onhand_category,
               journal_batch_name = l_oh_journal_batch || ' ' || lv_oh_period_name || ' ' || NVL (TO_CHAR (gd_cut_of_date, 'DD-MON-RRRR'), TRUNC (SYSDATE)), journal_name = l_oh_journal_name || ' ' || lv_oh_period_name || ' ' || NVL (TO_CHAR (gd_cut_of_date, 'DD-MON-RRRR'), TRUNC (SYSDATE))
         WHERE 1 = 1 AND request_id = gn_request_id AND record_status = 'N';

        COMMIT;

        ---- SOURCE NAME Validation -----
        lv_js_elimination    := get_js_elimination (l_onhand_source);

        IF (lv_js_elimination IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || ' - '
                || 'The SOURCE NAME for ELIMINATION is not correct.';
            write_log ('Error Occured in user_je_source_name-' || SQLERRM);
        END IF;

        write_log ('Source Validation completed');

        ---- CATEGORY NAME Validation -----
        lv_journal_cat_elimination   :=
            get_journal_cat_elimination (l_onhand_category);

        IF (lv_journal_cat_elimination IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || ' - '
                || 'The SOURCE CATEGORY for ELIMINATION is not correct.';
            write_log ('Error Occured in user_je_source_name-' || SQLERRM);
        END IF;

        write_log ('Category Validation completed');

        IF (lv_oh_period_name IS NULL)
        THEN
            lv_ret_status   := 'E';
            lv_ret_msg      :=
                   lv_ret_msg
                || CHR (10)
                || 'Period is either Not Opened or Closed.';
            write_log (
                   'Error Occured in Period is either not Opened or Closed-'
                || SQLERRM);
        END IF;

        write_log ('lv_ret_status-' || lv_ret_status);

        IF lv_ret_status = 'S'
        THEN
            FOR r_gl_oh_data IN c_gl_oh_data
            LOOP
                lv_ret_status    := 'S';
                lv_ret_msg       := NULL;
                lv_debit_ccid    := NULL;
                lv_credit_ccid   := NULL;

                ---- Code combination validation for Debit segments ----
                BEGIN
                    ln_structure_number   := NULL;
                    lb_sucess             := NULL;
                    lv_ledger_name        := NULL;

                    SELECT chart_of_accounts_id, name
                      INTO ln_structure_number, lv_ledger_name
                      FROM gl_ledgers
                     WHERE ledger_id = r_gl_oh_data.ledger_id;

                    lv_debit_ccid         := r_gl_oh_data.oh_debit_code_comb;
                    lb_sucess             :=
                        fnd_flex_keyval.validate_segs (
                            operation          => 'CREATE_COMBINATION',
                            appl_short_name    => 'SQLGL',
                            key_flex_code      => 'GL#',
                            structure_number   => ln_structure_number,
                            concat_segments    => lv_debit_ccid,
                            validation_date    => SYSDATE);

                    write_log ('lv_debit_ccid:' || lv_debit_ccid);

                    IF lb_sucess
                    THEN
                        write_log (
                               'Successful. Onhand Debit Code Combination ID:'
                            || fnd_flex_keyval.combination_id ());
                    ELSE
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'One or more provided Onhand Debit Segment values are not correct combination.';
                        write_log (
                               'Error creating a Onhand Debit Code Combination ID for '
                            || lv_debit_ccid
                            || 'Error:'
                            || fnd_flex_keyval.error_message ());
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error creating a Code Combination ID with provided Onhand Debit Segment values.';
                        write_log (
                               'Unable to create a Onhand Debit Code Combination ID for '
                            || lv_debit_ccid
                            || 'Error:'
                            || SQLERRM ());
                END;

                ---- Code combination validation for Credit segments ----

                BEGIN
                    ln_structure_number   := NULL;
                    lb_sucess             := NULL;

                    SELECT chart_of_accounts_id
                      INTO ln_structure_number
                      FROM gl_ledgers
                     WHERE ledger_id = r_gl_oh_data.ledger_id;

                    lv_credit_ccid        := r_gl_oh_data.oh_credit_code_comb;
                    lb_sucess             :=
                        fnd_flex_keyval.validate_segs (
                            operation          => 'CREATE_COMBINATION',
                            appl_short_name    => 'SQLGL',
                            key_flex_code      => 'GL#',
                            structure_number   => ln_structure_number,
                            concat_segments    => lv_credit_ccid,
                            validation_date    => SYSDATE);

                    write_log ('lv_credit_ccid:' || lv_credit_ccid);

                    IF lb_sucess
                    THEN
                        write_log (
                               'Successful. Onhand Credit Code Combination ID:'
                            || fnd_flex_keyval.combination_id ());
                    ELSE
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'One or more provided Onhand Credit Segment values are not correct combination.';
                        write_log (
                               'Error creating a Onhand Credit Code Combination ID for '
                            || lv_credit_ccid
                            || 'Error:'
                            || fnd_flex_keyval.error_message ());
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error creating a Code Combination ID with provided Onahnd Credit Segment values.';
                        write_log (
                               'Unable to create a Onhand Credit Code Combination ID for '
                            || lv_credit_ccid
                            || 'Error:'
                            || SQLERRM ());
                END;

                -- Update status and derived values in to STG table
                UPDATE xxdo.xxd_gl_je_inv_ic_markup_stg_t
                   SET ledger_name = lv_ledger_name, record_status = lv_ret_status, error_msg = error_msg || lv_ret_msg
                 WHERE     ROWID = r_gl_oh_data.ROWID
                       AND request_id = gn_request_id;
            END LOOP;
        ELSE
            -- Send an email notification if Setup issues
            generate_setup_err_prc (lv_ret_msg);
            x_ret_msg   := 'Setup validations error-' || SQLERRM;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('validate_gl_data' || SQLERRM);
            x_ret_msg   := 'validate_data-' || SQLERRM;
    END validate_gl_data;

    /***********************************************************************************************
    ************************** Procedure to Insert into GL_INTERFACE *******************************
    ************************************************************************************************/

    PROCEDURE populate_gl_int (x_ret_msg OUT NOCOPY VARCHAR2)
    IS
        --Get Valid records from staging

        CURSOR get_valid_onhand_data IS
              SELECT ledger_id, user_je_source_name, user_je_category_name,
                     org_currency, organization_name, as_of_date,
                     TRUNC (creation_date) creation_date, SUM (oh_markup_usd) oh_markup_usd, SUM (oh_markup_local) oh_markup_local,
                     oh_cr_company, oh_cr_brand, oh_cr_geo,
                     oh_cr_channel, oh_cr_dept, oh_cr_account,
                     oh_cr_intercom, oh_cr_future, oh_dr_company,
                     oh_dr_brand, oh_dr_geo, oh_dr_channel,
                     oh_dr_dept, oh_dr_account, oh_dr_intercom,
                     oh_dr_future, journal_batch_name, journal_name,
                     ledger_currency, SUM (attribute3) attribute3
                FROM xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND record_status = 'S'
            GROUP BY ledger_id, user_je_source_name, user_je_category_name,
                     org_currency, organization_name, as_of_date,
                     TRUNC (creation_date), oh_cr_company, oh_cr_brand,
                     oh_cr_geo, oh_cr_channel, oh_cr_dept,
                     oh_cr_account, oh_cr_intercom, oh_cr_future,
                     oh_dr_company, oh_dr_brand, oh_dr_geo,
                     oh_dr_channel, oh_dr_dept, oh_dr_account,
                     oh_dr_intercom, oh_dr_future, journal_batch_name,
                     journal_name, ledger_currency;

        ln_count           NUMBER := 0;
        ln_count1          NUMBER := 0;
        ln_count2          NUMBER := 0;
        ln_err_count       NUMBER := 0;
        ln_err_count1      NUMBER := 0;
        v_seq              NUMBER;
        v_group_id         NUMBER;
        l_oh_journal_val   NUMBER;
        ln_conv_rate_usd   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate GL Interface');

        SELECT COUNT (*)
          INTO ln_err_count
          FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t stg
         WHERE 1 = 1 AND request_id = gn_request_id AND record_status = 'E';

        write_log ('ln_err_count:' || ln_err_count);

        IF ln_err_count = 0
        THEN
            FOR valid_onhand_data_rec IN get_valid_onhand_data
            LOOP
                IF (NVL (valid_onhand_data_rec.oh_markup_usd, 0) + NVL (valid_onhand_data_rec.oh_markup_local, 0)) <>
                   0
                THEN
                    ln_count           := ln_count + 1;
                    ln_conv_rate_usd   := 0;
                    l_oh_journal_val   := 0;

                    IF     gv_markup_calc_cur = 'USD'
                       AND gv_onhand_jour_cur = 'Local'
                    THEN
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     => 'USD',
                                pv_to_currency       =>
                                    valid_onhand_data_rec.org_currency,
                                pv_conversion_type   => gv_rate_type,
                                pd_conversion_date   =>
                                    TRUNC (valid_onhand_data_rec.as_of_date));
                    ELSIF     gv_markup_calc_cur = 'Local'
                          AND gv_onhand_jour_cur = 'USD'
                    THEN
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency     =>
                                    valid_onhand_data_rec.org_currency,
                                pv_to_currency       => 'USD',
                                pv_conversion_type   => gv_rate_type,
                                pd_conversion_date   =>
                                    TRUNC (valid_onhand_data_rec.as_of_date));
                    END IF;

                    BEGIN
                        SELECT CASE
                                   WHEN     gv_markup_calc_cur = 'USD'
                                        AND gv_onhand_jour_cur = 'USD'
                                   THEN
                                       ROUND (
                                           valid_onhand_data_rec.oh_markup_usd,
                                           2)                    -- OH Amt USD
                                   WHEN     gv_markup_calc_cur = 'Local'
                                        AND gv_onhand_jour_cur = 'Local'
                                   THEN
                                       ROUND (
                                           valid_onhand_data_rec.oh_markup_local,
                                           (SELECT PRECISION
                                              FROM FND_CURRENCIES
                                             WHERE CURRENCY_CODE =
                                                   valid_onhand_data_rec.org_currency)) -- OH Amt Local
                                   WHEN     gv_markup_calc_cur = 'USD'
                                        AND gv_onhand_jour_cur = 'Local'
                                   THEN
                                       ROUND (
                                             valid_onhand_data_rec.oh_markup_usd
                                           * ln_conv_rate_usd,
                                           (SELECT PRECISION
                                              FROM FND_CURRENCIES
                                             WHERE CURRENCY_CODE =
                                                   valid_onhand_data_rec.org_currency)) -- OH Amt USD
                                   WHEN     gv_markup_calc_cur = 'Local'
                                        AND gv_onhand_jour_cur = 'USD'
                                   THEN
                                       ROUND (
                                           valid_onhand_data_rec.attribute3,
                                           2)                  -- OH Amt Local
                               END
                          INTO l_oh_journal_val
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_oh_journal_val   := 0;
                    END;

                    INSERT INTO gl_interface (status,
                                              ledger_id,
                                              GROUP_ID,
                                              user_je_source_name,
                                              user_je_category_name,
                                              currency_code,
                                              actual_flag,
                                              accounting_date,
                                              date_created,
                                              created_by,
                                              entered_dr,
                                              entered_cr,
                                              segment1,
                                              segment2,
                                              segment3,
                                              segment4,
                                              segment5,
                                              segment6,
                                              segment7,
                                              segment8,
                                              reference1,        -- batch_name
                                              reference4,      -- journal_name
                                              --reference5,
                                              reference10,      -- Description
                                              currency_conversion_date,
                                              user_currency_conversion_type)
                             VALUES (
                                        'NEW',
                                        valid_onhand_data_rec.ledger_id,
                                        99991,                    -- group_id,
                                        valid_onhand_data_rec.user_je_source_name,
                                        valid_onhand_data_rec.user_je_category_name,
                                        CASE
                                            WHEN gv_onhand_jour_cur = 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                valid_onhand_data_rec.org_currency -- Local Currency
                                        END,
                                        'A',
                                        valid_onhand_data_rec.as_of_date,
                                        valid_onhand_data_rec.creation_date,
                                        gn_user_id,
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                NULL
                                            ELSE
                                                ABS (l_oh_journal_val)
                                        END,                     -- entered_dr
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                ABS (l_oh_journal_val)
                                            ELSE
                                                NULL
                                        END,                     -- entered_cr
                                        valid_onhand_data_rec.oh_cr_company,
                                        valid_onhand_data_rec.oh_cr_brand,
                                        valid_onhand_data_rec.oh_cr_geo,
                                        valid_onhand_data_rec.oh_cr_channel,
                                        valid_onhand_data_rec.oh_cr_dept,
                                        valid_onhand_data_rec.oh_cr_account,
                                        valid_onhand_data_rec.oh_cr_intercom,
                                        valid_onhand_data_rec.oh_cr_future,
                                        valid_onhand_data_rec.journal_batch_name,
                                           valid_onhand_data_rec.organization_name
                                        || ','
                                        || valid_onhand_data_rec.as_of_date
                                        || ','
                                        || valid_onhand_data_rec.journal_name,
                                           --valid_onhand_data_rec.journal_name, -- Header description,
                                           valid_onhand_data_rec.organization_name
                                        || ','
                                        || valid_onhand_data_rec.as_of_date
                                        || ','
                                        || valid_onhand_data_rec.journal_name, -- Line description
                                        gd_cut_of_date,
                                        DECODE (
                                            (CASE
                                                 WHEN gv_onhand_jour_cur =
                                                      'USD'
                                                 THEN
                                                     'USD'     -- USD Currency
                                                 ELSE
                                                     valid_onhand_data_rec.org_currency -- Local Currency
                                             END),
                                            valid_onhand_data_rec.ledger_currency, NULL,
                                            gv_jl_rate_type));

                    INSERT INTO gl_interface (status,
                                              ledger_id,
                                              GROUP_ID,
                                              user_je_source_name,
                                              user_je_category_name,
                                              currency_code,
                                              actual_flag,
                                              accounting_date,
                                              date_created,
                                              created_by,
                                              entered_dr,
                                              entered_cr,
                                              segment1,
                                              segment2,
                                              segment3,
                                              segment4,
                                              segment5,
                                              segment6,
                                              segment7,
                                              segment8,
                                              reference1,
                                              reference4,
                                              --reference5,
                                              reference10,      -- description
                                              currency_conversion_date,
                                              user_currency_conversion_type)
                             VALUES (
                                        'NEW',
                                        valid_onhand_data_rec.ledger_id,
                                        99991,                    -- group_id,
                                        valid_onhand_data_rec.user_je_source_name,
                                        valid_onhand_data_rec.user_je_category_name,
                                        CASE
                                            WHEN gv_onhand_jour_cur = 'USD'
                                            THEN
                                                'USD'          -- USD Currency
                                            ELSE
                                                valid_onhand_data_rec.org_currency -- Local Currency
                                        END,
                                        'A',
                                        valid_onhand_data_rec.as_of_date, -- soh_date_ts,
                                        valid_onhand_data_rec.creation_date,
                                        gn_user_id,
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                ABS (l_oh_journal_val)
                                            ELSE
                                                NULL
                                        END,                     -- entered_dr
                                        CASE
                                            WHEN l_oh_journal_val > 0
                                            THEN
                                                NULL
                                            ELSE
                                                ABS (l_oh_journal_val)
                                        END,                     -- entered_cr
                                        valid_onhand_data_rec.oh_dr_company,
                                        valid_onhand_data_rec.oh_dr_brand,
                                        valid_onhand_data_rec.oh_dr_geo,
                                        valid_onhand_data_rec.oh_dr_channel,
                                        valid_onhand_data_rec.oh_dr_dept,
                                        valid_onhand_data_rec.oh_dr_account,
                                        valid_onhand_data_rec.oh_dr_intercom,
                                        valid_onhand_data_rec.oh_dr_future,
                                        valid_onhand_data_rec.journal_batch_name,
                                           valid_onhand_data_rec.organization_name
                                        || ','
                                        || valid_onhand_data_rec.as_of_date
                                        || ','
                                        || valid_onhand_data_rec.journal_name,
                                           --valid_onhand_data_rec.journal_name,
                                           valid_onhand_data_rec.organization_name
                                        || ','
                                        || valid_onhand_data_rec.as_of_date
                                        || ','
                                        || valid_onhand_data_rec.journal_name, -- description
                                        gd_cut_of_date,
                                        DECODE (
                                            (CASE
                                                 WHEN gv_onhand_jour_cur =
                                                      'USD'
                                                 THEN
                                                     'USD'     -- USD Currency
                                                 ELSE
                                                     valid_onhand_data_rec.org_currency -- Local Currency
                                             END),
                                            valid_onhand_data_rec.ledger_currency, NULL,
                                            gv_jl_rate_type));

                    ---- Update status to STG table for processed records
                    UPDATE xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T
                       SET record_status   = 'P'
                     WHERE 1 = 1 AND request_id = gn_request_id;
                --AND ROWID = valid_onhand_data_rec.rowid;

                END IF;
            END LOOP;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error records in ONHAND Staging Table Count: '
                || ln_err_count);
        END IF;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG,
                           'GL_INTERFACE ONHAND Record Count: ' || ln_count);
        x_ret_msg   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_GL_INT:' || SQLERRM);
    END populate_gl_int;

    /***********************************************************************************************
    ******************** Procedure to Import Elimination Onhand into GL ****************************
    ************************************************************************************************/

    PROCEDURE import_onhand_gl (x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_oh_gl_src IS
            SELECT DISTINCT GROUP_ID, ledger_id, user_je_source_name
              FROM gl_interface
             WHERE     status = 'NEW'
                   AND user_je_source_name = 'Elimination'
                   AND GROUP_ID = 99991;

        ln_access_set_id   NUMBER;
        l_source_name      gl_je_sources.je_source_name%TYPE;
        v_req_id           NUMBER;
        v_phase            VARCHAR2 (2000);
        v_wait_status      VARCHAR2 (2000);
        v_dev_phase        VARCHAR2 (2000);
        v_dev_status       VARCHAR2 (2000);
        v_message          VARCHAR2 (2000);
        v_request_status   BOOLEAN;
        l_imp_req_id       NUMBER;
        l_imp_phase        VARCHAR2 (10);
        l_imp_status       VARCHAR2 (10);
    BEGIN
        FOR j IN c_oh_gl_src
        LOOP
            gv_oh_import_status   := NULL;

            BEGIN
                SELECT je_source_name
                  INTO l_source_name
                  FROM gl_je_sources
                 WHERE user_je_source_name = j.user_je_source_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            BEGIN
                SELECT access_set_id
                  INTO ln_access_set_id
                  FROM (  SELECT gas.access_set_id
                            FROM gl_access_sets gas, gl_ledgers gl
                           WHERE     gas.default_ledger_id = gl.ledger_id
                                 AND gl.ledger_id = j.ledger_id
                        ORDER BY gas.access_set_id)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_access_set_id   :=
                        fnd_profile.VALUE ('GL_ACCESS_SET_ID');
            END;

            v_req_id              :=
                fnd_request.submit_request (application   => 'SQLGL',
                                            program       => 'GLLEZLSRS', -- Short Name of program
                                            description   => NULL,
                                            start_time    => NULL,
                                            sub_request   => FALSE,
                                            argument1     => ln_access_set_id, --Data Access Set ID
                                            argument2     => l_source_name,
                                            argument3     => j.ledger_id,
                                            argument4     => j.GROUP_ID,
                                            argument5     => 'N', --Post Errors to Suspense
                                            argument6     => 'N', --Create Summary Journals
                                            argument7     => 'O'  --Import DFF
                                                                );

            COMMIT;

            IF v_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || fnd_message.get
                    || '".');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Journal Import Program submitted succesfully. Request id :'
                    || v_req_id);
            END IF;

            IF v_req_id > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    '   Waiting for the Journal Import Program');

                LOOP
                    v_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => v_req_id,
                            INTERVAL     => 60, --interval Number of seconds to wait between checks
                            max_wait     => 0, --Maximum number of seconds to wait for the request completion
                            phase        => v_phase,
                            status       => v_wait_status,
                            dev_phase    => v_dev_phase,
                            dev_status   => v_dev_status,
                            MESSAGE      => v_message);

                    EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
                              OR UPPER (v_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       '  Journal Import Program Request Phase'
                    || '-'
                    || v_dev_phase);
                fnd_file.put_line (
                    fnd_file.LOG,
                       '  Journal Import Program Request Dev status'
                    || '-'
                    || v_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   '  v_message' || '-' || v_message);
                fnd_file.put_line (fnd_file.LOG,
                                   '  v_wait_status' || '-' || v_wait_status);

                BEGIN
                        SELECT request_id, phase_code, status_code
                          INTO l_imp_req_id, l_imp_phase, l_imp_status
                          FROM apps.fnd_concurrent_requests fcr
                         WHERE 1 = 1
                    START WITH fcr.parent_request_id = v_req_id
                    CONNECT BY PRIOR fcr.request_id = fcr.parent_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                IF UPPER (l_imp_phase) = 'C' AND UPPER (l_imp_status) = 'C'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inventory Onhand Journal Import successfully completed for Request ID: '
                        || l_imp_req_id);
                    gv_oh_import_status   :=
                           'Inventory Onhand Records Inserted to GL Interface Succesfully. Journal Import successfully completed for Request ID: '
                        || l_imp_req_id;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'The Inventory Onhand Journal Import request failed.Review log for Oracle Request ID: '
                        || l_imp_req_id);
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);
                    gv_oh_import_status   :=
                           'Inventory Onhand Records Inserted to GL Interface Succesfully. Journal Import got warning/error out for Request ID: '
                        || l_imp_req_id;
                    RETURN;
                END IF;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_message   := SQLERRM;
    END import_onhand_gl;

    /***************************************************************************
    -- PROCEDURE create_final_zip_prc
    -- PURPOSE: This Procedure Converts the file to zip file
    ***************************************************************************/

    FUNCTION file_to_blob_fnc (pv_directory_name   IN VARCHAR2,
                               pv_file_name        IN VARCHAR2)
        RETURN BLOB
    IS
        dest_loc   BLOB := EMPTY_BLOB ();
        src_loc    BFILE := BFILENAME (pv_directory_name, pv_file_name);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           ' Start of Convering the file to BLOB');

        DBMS_LOB.OPEN (src_loc, DBMS_LOB.LOB_READONLY);

        DBMS_LOB.CREATETEMPORARY (lob_loc   => dest_loc,
                                  cache     => TRUE,
                                  dur       => DBMS_LOB.session);

        DBMS_LOB.OPEN (dest_loc, DBMS_LOB.LOB_READWRITE);

        DBMS_LOB.LOADFROMFILE (dest_lob   => dest_loc,
                               src_lob    => src_loc,
                               amount     => DBMS_LOB.getLength (src_loc));

        DBMS_LOB.CLOSE (dest_loc);

        DBMS_LOB.CLOSE (src_loc);

        RETURN dest_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in Converting the file to BLOB - ' || SQLERRM);

            RETURN NULL;
    END file_to_blob_fnc;

    PROCEDURE save_zip_prc (pb_zipped_blob     BLOB,
                            pv_dir             VARCHAR2,
                            pv_zip_file_name   VARCHAR2)
    IS
        t_fh    UTL_FILE.file_type;
        t_len   PLS_INTEGER := 32767;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of save_zip_prc Procedure');

        t_fh   := UTL_FILE.fopen (pv_dir, pv_zip_file_name, 'wb');

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (pb_zipped_blob) - 1) / t_len)
        LOOP
            UTL_FILE.put_raw (
                t_fh,
                DBMS_LOB.SUBSTR (pb_zipped_blob, t_len, i * t_len + 1));
        END LOOP;

        UTL_FILE.fclose (t_fh);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);
    END save_zip_prc;

    PROCEDURE create_final_zip_prc (pv_directory_name IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2)
    IS
        lb_file   BLOB;
        lb_zip    BLOB;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of file_to_blob_fnc ');

        lb_file   := file_to_blob_fnc (pv_directory_name, pv_file_name);

        fnd_file.put_line (fnd_file.LOG, pv_directory_name || pv_file_name);

        fnd_file.put_line (fnd_file.LOG, ' Start of add_file PROC ');

        APEX_200200.WWV_FLOW_ZIP.add_file (lb_zip, pv_file_name, lb_file);

        fnd_file.put_line (fnd_file.LOG, ' Start of finish PROC ');

        APEX_200200.wwv_flow_zip.finish (lb_zip);

        fnd_file.put_line (fnd_file.LOG, ' Start of Saving ZIP File PROC ');

        save_zip_prc (lb_zip, pv_directory_name, pv_zip_file_name);
    END create_final_zip_prc;

    -- ======================================================================================
    -- This procedure will write the ouput data into file for report
    -- ======================================================================================

    PROCEDURE generate_exception_report_prc (
        pv_directory_path   IN     VARCHAR2,
        pv_exc_file_name       OUT VARCHAR2)
    IS
        CURSOR c_oh_rpt IS
              SELECT *
                FROM xxdo.XXD_GL_JE_INV_IC_MARKUP_STG_T oh
               WHERE     oh.request_id = gn_request_id
                     AND NVL (oh.oh_markup_usd, 0) <> 0
            ORDER BY oh.organization_id;

        --DEFINE VARIABLES
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
    BEGIN
        lv_outbound_file    :=
               gn_request_id
            || '_IC_Inventory_Onhand_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.xls';

        lv_directory_path   := pv_directory_path;
        lv_output_file      :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'Ledger Name'
                || CHR (9)
                || 'User JE Source Name'
                || CHR (9)
                || 'User JE Category Name'
                || CHR (9)
                || 'Journal Name'
                || CHR (9)
                || 'Onhand Journal Currency'
                || CHR (9)
                || 'Organization Name'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'As of Date'
                || CHR (9)
                || 'Onhand Qty'
                || CHR (9)
                || 'Intransit Qty'
                || CHR (9)
                || 'Total Qty'
                || CHR (9)
                || 'Total Cost'
                || CHR (9)
                || 'Item Cost'
                || CHR (9)
                || 'Material Cost'
                || CHR (9)
                || 'Non Material Cost'
                || CHR (9)
                || 'Duty Rate'
                || CHR (9)
                || 'Duty'
                || CHR (9)
                || 'Freight Dutiable Cost'
                || CHR (9)
                || 'Freight Cost'
                || CHR (9)
                || 'Overhead Dutiable Cost'
                || CHR (9)
                || 'Overhead Non Dutiable Cost'
                || CHR (9)
                || 'Onhand Margin CST Local'
                || CHR (9)
                || 'Onhand Margin CST USD'
                || CHR (9)
                || 'Onhand Margin Value Local'
                || CHR (9)
                || 'Onhand Margin Value USD'
                || CHR (9)
                || 'Onhand Margin Value Local_at_Corp'
                || CHR (9)
                || 'Onhand Journal Local'
                || CHR (9)
                || 'Onhand Journal USD'
                || CHR (9)
                || 'Onhand Debit Code Combination'
                || CHR (9)
                || 'Onhand Credit Code Combination'
                || CHR (9)
                || 'Request ID'
                || CHR (9)
                || 'Record Status'
                || CHR (9)
                || 'Error Message';

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR r_oh_rpt IN c_oh_rpt
            LOOP
                lv_line   :=
                       NVL (r_oh_rpt.ledger_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.user_je_source_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.user_je_category_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.journal_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_journal_currency, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.organization_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.item_number, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.as_of_date, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.onhand_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.intransit_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.total_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.attribute2, '')
                    || CHR (9)
                    || ROUND (NVL (r_oh_rpt.item_cost, ''), 2)
                    || CHR (9)
                    || ROUND (NVL (r_oh_rpt.material_cost, ''), 2)
                    || CHR (9)
                    || ROUND (NVL (r_oh_rpt.non_material_cost, ''), 2)
                    || CHR (9)
                    || ROUND (NVL (r_oh_rpt.duty_rate, ''), 2)
                    || CHR (9)
                    || ROUND (NVL (r_oh_rpt.duty, ''), 2)
                    || CHR (9)
                    || NVL (r_oh_rpt.freight_du_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.freight_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.overhead_du_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_nondu_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_cst_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_cst_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_value_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_value_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.attribute1, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_markup_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_markup_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_debit_code_comb, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_credit_code_comb, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.request_id, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.record_status, '')
                    || CHR (9)
                    || NVL (SUBSTR (r_oh_rpt.error_msg, 1, 200), '');

                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for Onhand data writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);
        pv_exc_file_name    := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report_prc;

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================

    PROCEDURE generate_report_prc
    IS
        ln_oh_rec_fail          NUMBER;
        ln_oh_rec_total         NUMBER;
        ln_oh_rec_success       NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_directory_path       VARCHAR2 (1000);
        l_exception             EXCEPTION;
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        ln_war_rec              NUMBER;
        l_file_name_str         VARCHAR2 (1000);
        lv_onhand_file_zip      VARCHAR2 (1000);
    BEGIN
        ln_oh_rec_fail      := 0;
        ln_oh_rec_total     := 0;
        ln_oh_rec_success   := 0;
        ln_war_rec          := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_oh_rec_total
              FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t oh
             WHERE     1 = 1
                   AND oh.request_id = gn_request_id
                   AND NVL (oh.oh_markup_usd, 0) <> 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_oh_rec_total   := 0;
        END;

        IF ln_oh_rec_total <= 0
        THEN
            write_log (
                'No eligible markup records. There is nothing to Process...');
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_oh_rec_success
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t oh
                 WHERE     oh.request_id = gn_request_id
                       AND oh.record_status IN ('P')
                       AND NVL (oh.oh_markup_usd, 0) <> 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_oh_rec_success   := 0;
            END;

            ln_oh_rec_fail      := ln_oh_rec_total - ln_oh_rec_success;
            lv_exc_file_name    := NULL;
            lv_directory_path   := NULL;

            -- Derive the directory Path
            BEGIN
                lv_exc_directory_path   := NULL;

                SELECT directory_path
                  INTO lv_exc_directory_path
                  FROM dba_directories
                 WHERE     1 = 1
                       AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_ARC_DIR'; -- 'XXD_GL_ACCT_CONTROL_EXC_DIR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exc_directory_path   := NULL;
                    lv_message              :=
                           'Exception Occurred while retriving the Exception Directory-'
                        || SQLERRM;
                    RAISE l_exception;
            END;

            generate_exception_report_prc (lv_exc_directory_path,
                                           lv_exc_file_name);

            IF ln_oh_rec_total <= 15000
            THEN
                lv_onhand_file_zip   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_exc_file_name;
            ELSE
                lv_onhand_file_zip   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || SUBSTR (lv_exc_file_name,
                               1,
                               (INSTR (lv_exc_file_name, '.', -1) - 1))
                    || '.zip';

                create_final_zip_prc (
                    pv_directory_name   => 'XXD_GL_CCID_UPLOAD_ARC_DIR',
                    pv_file_name        => lv_exc_file_name,
                    pv_zip_file_name    => lv_onhand_file_zip);
            END IF;

            lv_message          :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please find the attached Deckers Inventory IC Markup for Onhand Journal Interface Output. '
                || CHR (10)
                || CHR (10)
                || l_file_name_str
                || CHR (10)
                || ' Number of Rows in the Onhand File                     - '
                || ln_oh_rec_total
                || CHR (10)
                || ' Number of Rows Errored in Onhand File               - '
                || ln_oh_rec_fail
                || CHR (10)
                || ' Number of Rows Processed to GL Interface          - '
                || ln_oh_rec_success
                || CHR (10)
                || CHR (10)
                || gv_oh_import_status
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            BEGIN
                SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
                  INTO lv_recipients
                  FROM fnd_lookup_values flv
                 WHERE     lookup_type = 'XXD_GL_COMMON_EMAILS_LKP'
                       AND lookup_code = '10002'
                       AND enabled_flag = 'Y'
                       AND language = 'US'
                       AND SYSDATE BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                                 NVL (end_date_active,
                                                      SYSDATE)
                                               + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_recipients   := NULL;
            END;

            IF ln_oh_rec_total > 0
            THEN
                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_recipients,
                    pv_ccrecipients   => NULL,
                    pv_subject        =>
                        'Deckers Inventory IC Markup for Onhand Journal Interface output',
                    pv_message        => lv_message,
                    pv_attachments    => lv_onhand_file_zip,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);
            END IF;

            BEGIN
                UTL_FILE.fremove (lv_exc_directory_path, lv_onhand_file_zip);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Unable to delete the execption report file- '
                        || SQLERRM);
            END;

            write_log ('Onhand Result is - ' || lv_result);
            write_log ('Onhand Result MSG is - ' || lv_result_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exception in generate_report_prc- ' || SQLERRM);
    END generate_report_prc;

    -- ======================================================================================
    -- This procedure will write the ouput data into file for report based on parameter
    -- ======================================================================================
    PROCEDURE generate_arc_report_prc (pv_directory_path   IN     VARCHAR2,
                                       pv_exc_file_name       OUT VARCHAR2)
    IS
        CURSOR c_oh_rpt IS
              SELECT xcv.item_description item_desc, xcv.department dept, xcv.master_class class,
                     xcv.sub_class, xcv.curr_active_season current_season, xcv.intro_season,
                     oh.*
                FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t oh, apps.xxd_common_items_v xcv
               WHERE     1 = 1
                     AND oh.organization_id = xcv.organization_id
                     AND oh.inventory_item_id = xcv.inventory_item_id
                     AND TRUNC (oh.as_of_date) = TRUNC (gd_cut_of_date)
                     AND NVL (oh.inv_org_id, 1) =
                         NVL (NVL (gn_inv_org_id, oh.inv_org_id), 1)
                     AND NVL (oh.region, 1) =
                         NVL (NVL (gv_region, oh.region), 1)
                     AND NVL (oh.brand, 1) = NVL (NVL (gv_brand, oh.brand), 1)
                     AND oh.record_status = 'P'
            ORDER BY oh.organization_id;

        --DEFINE VARIABLES
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
    BEGIN
        lv_outbound_file    :=
               gn_request_id
            || '_IC_Inventory_OHRPT_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.xls';

        lv_directory_path   := pv_directory_path;
        lv_output_file      :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'Organization Name'
                || CHR (9)
                || 'Organization ID'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'Style'
                || CHR (9)
                || 'Color'
                || CHR (9)
                || 'Item Size'
                || CHR (9)
                || 'Item Desc'
                || CHR (9)
                || 'Dept'
                || CHR (9)
                || 'Class'
                || CHR (9)
                || 'Sub Class'
                || CHR (9)
                || 'Current Season'
                || CHR (9)
                || 'Intro Season'
                || CHR (9)
                || 'Cut Off Date'
                || CHR (9)
                || 'Onhand Qty'
                || CHR (9)
                || 'Intransit Qty'
                || CHR (9)
                || 'Total Qty'
                || CHR (9)
                || 'Total Cost'
                || CHR (9)
                || 'Item Cost'
                || CHR (9)
                || 'Material Cost'
                || CHR (9)
                || 'Non Material Cost'
                || CHR (9)
                || 'Duty Rate'
                || CHR (9)
                || 'Duty'
                || CHR (9)
                || 'Freight DU Cost'
                || CHR (9)
                || 'Freight Cost'
                || CHR (9)
                || 'Overhead DU Cost'
                || CHR (9)
                || 'OH NonDU Cost'
                || CHR (9)
                || 'OH Dr Company'
                || CHR (9)
                || 'OH Dr Brand'
                || CHR (9)
                || 'OH Dr Geo'
                || CHR (9)
                || 'OH Dr Channel'
                || CHR (9)
                || 'OH Dr Dept'
                || CHR (9)
                || 'OH Dr Account'
                || CHR (9)
                || 'OH Dr Intercom'
                || CHR (9)
                || 'OH Dr Future'
                || CHR (9)
                || 'OH Cr Company'
                || CHR (9)
                || 'OH Cr Brand'
                || CHR (9)
                || 'OH Cr Geo'
                || CHR (9)
                || 'OH Cr Channel'
                || CHR (9)
                || 'OH Cr Dept'
                || CHR (9)
                || 'OH Cr Account'
                || CHR (9)
                || 'OH Cr Intercom'
                || CHR (9)
                || 'OH Cr Future'
                || CHR (9)
                || 'OH Debit Code Combination'
                || CHR (9)
                || 'OH Credit Code Combination'
                || CHR (9)
                || 'OH Mrgn CST Local'
                || CHR (9)
                || 'OH Mrgn CST USD'
                || CHR (9)
                || 'OH Mrgn Value Local'
                || CHR (9)
                || 'OH Mrgn Value USD'
                || CHR (9)
                || 'OH Mrgn Value Local_at_Corp'
                || CHR (9)
                || 'OH JL Markup Local'
                || CHR (9)
                || 'OH JL Markup USD'
                || CHR (9)
                || 'OH JL Markup Local at USD'
                || CHR (9)
                || 'OH Local Markup Percentage'
                || CHR (9)
                || 'User JE Category Name'
                || CHR (9)
                || 'User JE Source Name';

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR r_oh_rpt IN c_oh_rpt
            LOOP
                lv_line   :=
                       NVL (r_oh_rpt.organization_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.organization_id, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.item_number, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.brand, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.style, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.color, '')
                    || CHR (9)
                    || TO_CHAR (NVL (r_oh_rpt.item_size, ''))
                    || CHR (9)
                    || NVL (r_oh_rpt.item_desc, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.dept, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.class, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.sub_class, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.current_season, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.intro_season, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.as_of_date, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.onhand_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.intransit_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.total_qty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.attribute2, '')             -- Total Cost
                    || CHR (9)
                    || NVL (r_oh_rpt.item_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.material_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.non_material_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.duty_rate, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.duty, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.freight_du_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.freight_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.overhead_du_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_nondu_cost, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_company, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_brand, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_geo, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_channel, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_dept, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_account, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_intercom, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_dr_future, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_company, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_brand, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_geo, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_channel, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_dept, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_account, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_intercom, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_cr_future, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_debit_code_comb, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_credit_code_comb, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_cst_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_cst_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_value_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_mrgn_value_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.attribute1, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_markup_local, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.oh_markup_usd, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.attribute3, '')
                    || CHR (9)
                    || ROUND (
                             (NVL (r_oh_rpt.oh_mrgn_value_local, 0) / NVL ((r_oh_rpt.attribute2 + .001), 1))
                           * 100,
                           2)
                    || CHR (9)
                    || NVL (r_oh_rpt.user_je_category_name, '')
                    || CHR (9)
                    || NVL (r_oh_rpt.user_je_source_name, '');

                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for Onhand data writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);
        pv_exc_file_name    := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_arc_report_prc;

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================

    PROCEDURE mail_report_type_prc
    IS
        ln_oh_rec_fail          NUMBER;
        ln_oh_rec_total         NUMBER;
        ln_oh_rec_success       NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_directory_path       VARCHAR2 (1000);
        l_exception             EXCEPTION;
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        ln_war_rec              NUMBER;
        l_file_name_str         VARCHAR2 (1000);
        lv_onhand_file_zip1     VARCHAR2 (1000);
        l_Org_code              VARCHAR2 (100);
        lv_user_email           VARCHAR2 (500);
    BEGIN
        ln_oh_rec_fail      := 0;
        ln_oh_rec_total     := 0;
        ln_oh_rec_success   := 0;
        ln_war_rec          := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_oh_rec_total
              FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t oh
             WHERE     1 = 1
                   AND TRUNC (oh.as_of_date) = TRUNC (gd_cut_of_date)
                   AND NVL (oh.inv_org_id, 1) =
                       NVL (NVL (gn_inv_org_id, oh.inv_org_id), 1)
                   AND NVL (oh.region, 1) =
                       NVL (NVL (gv_region, oh.region), 1)
                   AND NVL (oh.brand, 1) = NVL (NVL (gv_brand, oh.brand), 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_oh_rec_total   := 0;
        END;

        lv_exc_file_name    := NULL;
        lv_directory_path   := NULL;

        -- Derive the directory Path
        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_ARC_DIR'; -- 'XXD_GL_ACCT_CONTROL_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Exception Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        generate_arc_report_prc (lv_exc_directory_path, lv_exc_file_name);

        IF ln_oh_rec_total <= 15000
        THEN
            lv_onhand_file_zip1   :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || lv_exc_file_name;
        ELSE
            lv_onhand_file_zip1   :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || SUBSTR (lv_exc_file_name,
                           1,
                           (INSTR (lv_exc_file_name, '.', -1) - 1))
                || '.zip';

            create_final_zip_prc (
                pv_directory_name   => 'XXD_GL_CCID_UPLOAD_ARC_DIR',
                pv_file_name        => lv_exc_file_name,
                pv_zip_file_name    => lv_onhand_file_zip1);
        END IF;

        BEGIN
            SELECT NVL (organization_code, 'No Org Selected')
              INTO l_Org_code
              FROM apps.mtl_parameters
             WHERE organization_id = gn_inv_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_Org_code   := 'No Org Selected';
        END;

        lv_message          :=
               'Hello Team,'
            || CHR (10)
            || CHR (10)
            || 'Please find the attached Deckers Inventory IC Markup for Onhand Journal Report Output for the parameters provided. '
            || CHR (10)
            || CHR (10)
            || 'Organization Name: '
            || l_Org_code
            || CHR (10)
            || CHR (10)
            || 'Region: '
            || NVL (gv_region, 'No Region Selected')
            || CHR (10)
            || CHR (10)
            || 'Brand:'
            || NVL (gv_brand, 'No Brand Selected')
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please do not reply.';

        SELECT email_address
          INTO lv_user_email
          FROM apps.FND_USER
         WHERE user_id = gn_user_id;

        BEGIN
            SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
              INTO lv_recipients
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_GL_COMMON_EMAILS_LKP'
                   AND lookup_code = '10002'
                   AND enabled_flag = 'Y'
                   AND language = 'US'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_recipients   := NULL;
        END;

        lv_recipients       := lv_recipients || ',' || lv_user_email;

        IF ln_oh_rec_total > 0
        THEN
            xxdo_mail_pkg.send_mail (
                pv_sender         => 'erp@deckers.com',
                pv_recipients     => lv_recipients,
                pv_ccrecipients   => NULL,
                pv_subject        =>
                    'Deckers Inventory IC Markup for Onhand Journal Report output',
                pv_message        => lv_message,
                pv_attachments    => lv_onhand_file_zip1,
                xv_result         => lv_result,
                xv_result_msg     => lv_result_msg);
        END IF;

        BEGIN
            UTL_FILE.fremove (lv_exc_directory_path, lv_onhand_file_zip1);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                    'Unable to delete the execption report file- ' || SQLERRM);
        END;

        write_log ('Onhand Result is - ' || lv_result);
        write_log ('Onhand Result MSG is - ' || lv_result_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exception in mail_report_type_prc- ' || SQLERRM);
    END mail_report_type_prc;

    /***********************************************************************************************
    ************************** Markup Retail - MAIN Procedure **************************************
    ************************************************************************************************/

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_as_of_date IN VARCHAR2, p_inv_org_id IN NUMBER, p_region IN VARCHAR2, p_brand IN VARCHAR2, p_markup_calc_cur IN VARCHAR2, p_onhand_jour_cur IN VARCHAR2, p_rate_type IN VARCHAR2
                        , p_jl_rate_type IN VARCHAR2, p_type IN VARCHAR2)
    AS
        lv_ret_message   VARCHAR2 (4000);
        lv_exception     EXCEPTION;
        l_max_run_date   DATE;
        l_ret_stat       VARCHAR2 (1);
        l_err_messages   VARCHAR2 (2000);
        l_jpy_intran     VARCHAR2 (10);
    BEGIN
        gd_cut_of_date       := TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS');
        gn_inv_org_id        := p_inv_org_id;
        gv_region            := p_region;
        gv_brand             := p_brand;
        gv_markup_calc_cur   := p_markup_calc_cur;
        gv_onhand_jour_cur   := p_onhand_jour_cur;
        gv_rate_type         := p_rate_type;
        gv_jl_rate_type      := p_jl_rate_type;
        lv_ret_message       := NULL;

        write_log ('gd_cut_of_date - ' || gd_cut_of_date);
        write_log ('gn_inv_org_id - ' || gn_inv_org_id);
        write_log ('gv_region - ' || gv_region);
        write_log ('gv_brand - ' || gv_brand);
        write_log ('gv_markup_calc_cur - ' || gv_markup_calc_cur);
        write_log ('gv_onhand_jour_cur - ' || gv_onhand_jour_cur);
        write_log ('gv_rate_type - ' || gv_rate_type);
        write_log ('gv_jl_rate_type - ' || gv_jl_rate_type);

        IF gn_inv_org_id IS NOT NULL AND gv_region IS NOT NULL
        THEN
            BEGIN
                SELECT MAX (as_of_date)
                  INTO l_max_run_date
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t
                 WHERE     1 = 1
                       AND region = gv_region
                       AND inv_org_id = gn_inv_org_id
                       AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_run_date   := TRUNC (SYSDATE);
            END;
        ELSIF gn_inv_org_id IS NOT NULL AND gv_region IS NULL
        THEN
            BEGIN
                SELECT MAX (as_of_date)
                  INTO l_max_run_date
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t
                 WHERE     1 = 1
                       AND inv_org_id = gn_inv_org_id
                       AND region IS NULL
                       AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_run_date   := TRUNC (SYSDATE);
            END;
        ELSIF gn_inv_org_id IS NULL AND gv_region IS NOT NULL
        THEN
            BEGIN
                SELECT MAX (as_of_date)
                  INTO l_max_run_date
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t
                 WHERE 1 = 1 AND region = gv_region AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_run_date   := TRUNC (SYSDATE);
            END;
        ELSIF     gn_inv_org_id IS NOT NULL
              AND gv_region IS NOT NULL
              AND gv_brand IS NOT NULL
        THEN
            BEGIN
                SELECT MAX (as_of_date)
                  INTO l_max_run_date
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t
                 WHERE     1 = 1
                       AND inv_org_id = gn_inv_org_id
                       AND region = gv_region
                       AND brand = gv_brand
                       AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_run_date   := TRUNC (SYSDATE);
            END;
        ELSIF gn_inv_org_id IS NOT NULL AND gv_brand IS NOT NULL
        THEN
            BEGIN
                SELECT MAX (as_of_date)
                  INTO l_max_run_date
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t
                 WHERE     1 = 1
                       AND inv_org_id = gn_inv_org_id
                       AND brand = gv_brand
                       AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_run_date   := TRUNC (SYSDATE);
            END;
        ELSIF gv_region IS NOT NULL AND gv_brand IS NOT NULL
        THEN
            BEGIN
                SELECT MAX (as_of_date)
                  INTO l_max_run_date
                  FROM xxdo.xxd_gl_je_inv_ic_markup_stg_t
                 WHERE     1 = 1
                       AND region = gv_region
                       AND brand = gv_brand
                       AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_run_date   := TRUNC (SYSDATE);
            END;
        END IF;

        IF p_type = 'Report'
        THEN
            mail_report_type_prc;
        ELSE
            IF gd_cut_of_date < l_max_run_date
            THEN
                generate_setup_err_prc (
                       'Entered Cut off date should be greater than to Max Run Date.. '
                    || 'Max Run Date: '
                    || l_max_run_date);
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       'Entered Cut off date should be greater than to Max Run Date.. '
                    || 'Max Run Date: '
                    || l_max_run_date);
                raise_application_error (
                    -20001,
                       'Entered Cut off date should be greater than to Max Run Date.. '
                    || 'Max Run Date: '
                    || l_max_run_date);
            ELSIF gd_cut_of_date = l_max_run_date
            THEN
                generate_setup_err_prc (
                       'Inventory Onhand data already processed to GL_INTERFACE for submitted date.'
                    || 'Submitted Date: '
                    || l_max_run_date);
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       'Inventory Onhand data already processed to GL_INTERFACE for submitted date.'
                    || 'Submitted Date: '
                    || l_max_run_date);
                raise_application_error (
                    -20001,
                       'Inventory Onhand data already processed to GL_INTERFACE for submitted date.'
                    || 'Submitted Date: '
                    || l_max_run_date);
            END IF;

            IF p_inv_org_id IS NULL AND p_region IS NULL
            THEN
                generate_setup_err_prc (
                    'Either an Inventory Organization or Region must be specified.');
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    'Either an Inventory Organization or Region must be specified.');
                raise_application_error (
                    -20001,
                    'Either an inventory organization or region must be specified.');
            END IF;

            SELECT attribute17
              INTO l_jpy_intran
              FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ffvl
             WHERE     ff1.flex_value_set_id = ffvl.flex_value_set_id
                   AND UPPER (ff1.flex_value_set_name) =
                       UPPER ('XXD_INV_IC_MARKUP_VS')
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                            SYSDATE - 1)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value = gn_inv_org_id;

            IF NVL (l_jpy_intran, 'N') = 'YES'
            THEN
                BEGIN
                    SELECT category_set_id
                      INTO g_category_set_id
                      FROM mtl_category_sets
                     WHERE category_set_name = g_category_set_name;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        raise_application_error (
                            -20001,
                            'Sales Category Not defined.');
                END;

                load_temp_table (p_as_of_date       => gd_cut_of_date,
                                 p_inv_org_id       => gn_inv_org_id,
                                 p_cost_type_id     => NULL,
                                 x_ret_stat         => l_ret_stat,
                                 x_error_messages   => l_err_messages);
            END IF;

            lv_ret_message   := NULL;
            insert_oh_records (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            insert_oh_prev_records (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            update_seg_markupvalues (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            validate_gl_data (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            populate_gl_int (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            lv_ret_message   := NULL;
            import_onhand_gl (lv_ret_message);

            IF lv_ret_message IS NOT NULL
            THEN
                RAISE lv_exception;
            END IF;

            generate_report_prc;
        END IF;

        write_log ('End main_prc-');
    EXCEPTION
        WHEN lv_exception
        THEN
            write_log (lv_ret_message);
        WHEN OTHERS
        THEN
            write_log ('Error in main_prc-' || SQLERRM);
    END main_prc;
END XXD_GL_JE_INV_IC_MARKUP_PKG;
/
