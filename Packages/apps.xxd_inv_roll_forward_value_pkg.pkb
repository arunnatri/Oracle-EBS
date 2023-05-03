--
-- XXD_INV_ROLL_FORWARD_VALUE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_ROLL_FORWARD_VALUE_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_INV_ROLL_FORWARD_VALUE_PKG
    * Description     : This package is used in Deckers Inventory Roll Forward Value Report
    * Notes           :
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date            Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 27-Jun-2022     1.0           Viswanathan Pandian        Initial version
    ************************************************************************************************/
    FUNCTION extract_data
        RETURN BOOLEAN
    AS
    BEGIN
        BEGIN
            SELECT category_set_id, structure_id
              INTO gn_category_set_id, gn_inv_structure_id
              FROM mtl_category_sets
             WHERE (category_set_name) = 'Inventory';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while fetch category_set_name Inventory: '
                    || SQLERRM);
        END;

        BEGIN
            SELECT p_inv_org_id, TO_DATE (fnd_date.canonical_to_date (p_from_date), 'DD-MON-RRRR') from_date, TO_DATE (fnd_date.canonical_to_date (p_to_date), 'DD-MON-RRRR') TO_DATE
              INTO gn_inv_org_id, gd_from_date, gd_to_date
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Exception while converting the input date: ' || SQLERRM);
        END;

        -- OH Data
        BEGIN
            INSERT INTO xxdo.xxd_inv_roll_forward_value_gt (item, inventory_item_id, organization_id, init_target_qty, end_target_qty, init_cost_tab, end_cost_tab, init_value, end_value, po_ir_value, po_ir_qty, soi_value, soi_qty, rma_value, rma_qty, aai_value, aai_qty, subinv_value, subinv_qty, avrg_cost_value, avrg_cost_qty, int_ship_value, int_ship_qty, other_val
                                                            , other_qty)
                SELECT msib.segment1, msib.inventory_item_id, msib.organization_id,
                       onhand.target_qty init_target_qty, 0 end_target_qty, xxd.itemcost init_cost_tab,
                       0 end_cost_tab, 0 init_value, 0 end_value,
                       0 po_ir_value, 0 po_ir_qty, 0 soi_value,
                       0 soi_qty, 0 rma_value, 0 rma_qty,
                       0 aai_value, 0 aai_qty, 0 subinv_value,
                       0 subinv_qty, 0 avrg_cost_value, 0 avrg_cost_qty,
                       0 int_ship_value, 0 int_ship_qty, 0 other_val,
                       0 other_qty
                  FROM mtl_system_items_b msib,
                       xxdo.xxd_inv_givr_cost_detls_t xxd,
                       (  SELECT /*+ALL_ROWS*/
                                 SUM (a.target_qty) target_qty, item_id
                            FROM (  SELECT SUM (oq.target_qty) target_qty, item_id, subinv
                                      FROM (  SELECT moqv.subinventory_code subinv, moqv.inventory_item_id item_id, NVL (SUM (moqv.transaction_quantity), 0) target_qty
                                                FROM mtl_onhand_qty_cost_v moqv
                                               WHERE moqv.organization_id =
                                                     gn_inv_org_id
                                            GROUP BY moqv.subinventory_code, moqv.inventory_item_id, moqv.item_cost
                                            UNION ALL
                                              SELECT /*+LEADING(mmt) index(mmt MTL_MATERIAL_TRANSACTIONS_N1)*/
                                                     mmt.subinventory_code subinv, mmt.inventory_item_id item_id, NVL (-SUM (primary_quantity), 0) target_qty
                                                FROM mtl_material_transactions mmt, mtl_txn_source_types mtst
                                               WHERE     mmt.organization_id =
                                                         gn_inv_org_id
                                                     AND TRUNC (
                                                             mmt.transaction_date) >=
                                                         gd_from_date
                                                     AND mmt.subinventory_code
                                                             IS NOT NULL
                                                     AND mmt.transaction_source_type_id =
                                                         mtst.transaction_source_type_id
                                            GROUP BY mmt.subinventory_code, mmt.inventory_item_id)
                                           oq
                                  GROUP BY item_id, subinv) a,
                                 mtl_secondary_inventories b
                           WHERE     a.subinv = b.secondary_inventory_name
                                 AND b.asset_inventory = 1
                                 AND b.organization_id = gn_inv_org_id
                        GROUP BY item_id) onhand
                 WHERE     msib.inventory_item_id = xxd.inventory_item_id
                       AND msib.organization_id = xxd.organization_id
                       AND msib.inventory_item_id = onhand.item_id
                       AND xxd.snapshot_date = gd_to_date
                       AND msib.organization_id = gn_inv_org_id
                       AND onhand.target_qty > 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Exception while Inserting OH Data: ' || SQLERRM);
        END;

        -- For OH, calculate Init_Value
        UPDATE xxdo.xxd_inv_roll_forward_value_gt
           SET init_value   = init_target_qty * init_cost_tab
         WHERE 1 = 1;

        -- MMT Data
        BEGIN
            INSERT INTO xxdo.xxd_inv_roll_forward_value_gt (item, inventory_item_id, organization_id, init_target_qty, end_target_qty, init_cost_tab, end_cost_tab, init_value, end_value, po_ir_value, po_ir_qty, soi_value, soi_qty, rma_value, rma_qty, aai_value, aai_qty, subinv_value, subinv_qty, avrg_cost_value, avrg_cost_qty, int_ship_value, int_ship_qty, other_val
                                                            , other_qty)
                SELECT xciv.segment1,
                       xciv.inventory_item_id,
                       xciv.organization_id,
                       0   init_target_qty,
                       0   end_target_qty,
                       0   init_cost_tab,
                       0   end_cost_tab,
                       0   init_value,
                       0   end_value,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('PO Receipt')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) po_ir_value,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('PO Receipt', 'Int Req Intr Rcpt')
                            THEN
                                mmt.transaction_quantity
                            ELSE
                                0
                        END) po_ir_qty,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Sales order issue', 'Internal order issue', 'Int Order Intr Ship',
                                      'Int Order Direct Ship')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) soi_value,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Sales order issue', 'Internal order issue', 'Int Order Intr Ship',
                                      'Int Order Direct Ship')
                            THEN
                                mmt.transaction_quantity
                            ELSE
                                0
                        END) soi_qty,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('RMA Receipt')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) rma_value,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('RMA Receipt')
                            THEN
                                mmt.transaction_quantity
                            ELSE
                                0
                        END) rma_qty,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Account alias issue', 'Account alias receipt')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) aai_value,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Account alias issue', 'Account alias receipt')
                            THEN
                                mmt.transaction_quantity
                            ELSE
                                0
                        END) aai_qty,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Subinventory Transfer')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) subinv_value,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Subinventory Transfer')
                            THEN
                                mmt.transaction_quantity
                            ELSE
                                0
                        END) subinv_qty,
                       (CASE
                            WHEN (mtt.transaction_type_name) IN
                                     ('Average cost update')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) avrg_cost_value,
                       0   avrg_cost_qty,
                       0   int_ship_value,
                       0   int_ship_qty,
                       (CASE
                            WHEN mtt.transaction_type_name NOT IN
                                     (SELECT ffvv.flex_value
                                        FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
                                       WHERE     ffvs.flex_value_set_id =
                                                 ffvv.flex_value_set_id
                                             AND ffvs.flex_value_set_name =
                                                 'XXD_INV_TRANS_EXCLUDE_VS'
                                             AND ffvv.enabled_flag = 'Y')
                            THEN
                                DECODE (
                                    mmt.transaction_quantity,
                                    0, (SELECT SUM (mta.base_transaction_value)
                                          FROM mtl_transaction_accounts mta
                                         WHERE     mta.accounting_line_type =
                                                   1
                                               AND mmt.transaction_id =
                                                   mta.transaction_id),
                                      mmt.transaction_quantity
                                    * mmt.actual_cost)
                            ELSE
                                0
                        END) other_val,
                       (CASE
                            WHEN mtt.transaction_type_name NOT IN
                                     (SELECT ffvv.flex_value
                                        FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
                                       WHERE     ffvs.flex_value_set_id =
                                                 ffvv.flex_value_set_id
                                             AND ffvs.flex_value_set_name =
                                                 'XXD_INV_TRANS_EXCLUDE_VS'
                                             AND ffvv.enabled_flag = 'Y')
                            THEN
                                mmt.transaction_quantity
                            ELSE
                                0
                        END) other_qty
                  FROM mtl_system_items_b xciv, mtl_material_transactions mmt, mtl_transaction_types mtt
                 WHERE     1 = 1
                       AND mmt.inventory_item_id = xciv.inventory_item_id
                       AND mmt.organization_id = xciv.organization_id
                       AND mmt.transaction_type_id = mtt.transaction_type_id
                       AND EXISTS
                               (SELECT 1
                                  FROM mtl_secondary_inventories msi
                                 WHERE     msi.organization_id =
                                           mmt.organization_id
                                       AND msi.asset_inventory = 1)
                       AND mmt.organization_id = gn_inv_org_id
                       AND mmt.transaction_date >= gd_from_date
                       AND mmt.transaction_date < gd_to_date + 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Exception while inserting mmt data: ' || SQLERRM);
        END;

        -- update product attributes
        UPDATE /*+parallel(4)*/
               xxdo.xxd_inv_roll_forward_value_gt xxd
           SET (brand, style, color,
                item_type)   =
                   (SELECT mcb.segment1, mcb.attribute7, mcb.segment8,
                           msib.attribute28
                      FROM mtl_system_items_b msib, mtl_item_categories mic, mtl_categories_b mcb
                     WHERE     msib.inventory_item_id = mic.inventory_item_id
                           AND msib.organization_id = mic.organization_id
                           AND mic.category_id = mcb.category_id
                           AND mic.category_set_id = gn_category_set_id
                           AND mcb.structure_id = gn_inv_structure_id
                           AND msib.inventory_item_id = xxd.inventory_item_id
                           AND msib.organization_id = xxd.organization_id)
         WHERE 1 = 1;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'others exception in extract_data: ' || SQLERRM);
            RETURN FALSE;
    END extract_data;
END xxd_inv_roll_forward_value_pkg;
/
