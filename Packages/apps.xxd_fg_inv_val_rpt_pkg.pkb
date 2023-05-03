--
-- XXD_FG_INV_VAL_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FG_INV_VAL_RPT_PKG"
AS
    /*******************************************************************************
       * Program Name : XXD_FG_INV_VAL_RPT_PKG
       * Language     : PL/SQL
       * Description  : This package is used by DECKERS FG Inventory Value By brand report
       *
       * History      :
       *
       * WHO                     Desc                                     WHEN
       * -------------- ---------------------------------------------- ---------------
       * BT Technology          1.0 - Initial Version                     MAR/30/2015
       * BT Technology          1.1 - Fix for UAT2 Defect 577             10-Nov-2015
       * BT Technology          1.2 - Fix for UAT2 Defect 689             NOV/26/2015
       *                        Added material cost/ Over head function
       * BT Technology          1.3 - Fix for UAT2 Defect 614             30-Nov-2015
       * BT Technology          1.4 - Fix for UAT2 Defect 763             04-Dec-2015
       * BT Technology          1.5 - Fix for UAT2 Defect 763             09-Dec-2015
       * BT Technology          1.6 - Fix for Incident INC0289144         27-Apr-2016
    * INFOSYS                1.7 - Performance Tuning                  26-May-2016
       * Tejaswi Gangumalla     1.8 - Perofrmance Tuning                  02-Jul-2021
       * --------------------------------------------------------------------------- */

    FUNCTION xxdo_cst_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_return_val    NUMBER;
        v_date          DATE;
        v_inv_item_id   VARCHAR2 (50);
        v_org_id        NUMBER;
    BEGIN
        --SELECT /*+ALL_ROWS*/ new_cost --Commented for change 1.8
        SELECT /*+ ALL_ROWS optimizer_features_enable('11.2.0.4') */
               new_cost                                 --Added for change 1.8
          INTO v_return_val
          FROM cst_cg_cost_history_v
         WHERE     transaction_id =
                   (SELECT MAX (cst2.transaction_id)
                      FROM cst_cg_cost_history_v cst2
                     WHERE     1 = 1
                           AND cst2.organization_id = p_organization_id
                           AND cst2.inventory_item_id = p_inventory_item_id
                           AND (cst2.transaction_costed_date) =
                               (SELECT MAX (cst1.transaction_costed_date)
                                  FROM cst_cg_cost_history_v cst1
                                 WHERE     1 = 1
                                       AND cst1.organization_id =
                                           p_organization_id
                                       AND cst1.inventory_item_id =
                                           p_inventory_item_id
                                       AND TRUNC (-- Start modification by BT Technology Team for Incident INC0289144 on 27-Apr-2016
                                                  --cst1.transaction_costed_date) <=
                                                  cst1.transaction_date) <=
                                           -- End modification by BT Technology Team for Incident INC0289144 on 27-Apr-2016
                                           p_date)) --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
               AND organization_id = p_organization_id
               AND inventory_item_id = p_inventory_item_id;

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_cst_val_fnc;

    --Function to calculate on hand quantity
    FUNCTION xxdo_trans_type_qty_fnc (
        p_inventory_item_id   IN NUMBER,
        p_organization_id     IN NUMBER,
        p_transaction_type1   IN VARCHAR2,
        p_transaction_type2   IN VARCHAR2,
        p_transaction_type3   IN VARCHAR2 DEFAULT NULL,
        p_transaction_type4   IN VARCHAR2 DEFAULT NULL,
        p_from_date           IN DATE,
        p_to_date             IN DATE)
        RETURN NUMBER
    IS
        v_return_val   NUMBER;
    BEGIN
        SELECT /*+LEADING(mmt) index(mmt MTL_MATERIAL_TRANSACTIONS_N1) ALL_ROWS*/
               SUM (mmt.transaction_quantity)
          INTO v_return_val
          FROM mtl_material_transactions mmt, mtl_transaction_types mtt
         WHERE     TRUNC (mmt.transaction_date) >= p_from_date --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
               AND TRUNC (mmt.transaction_date) < p_to_date + 1 --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
               AND mmt.transaction_type_id = mtt.transaction_type_id
               AND mmt.inventory_item_id = p_inventory_item_id
               AND mmt.organization_id = p_organization_id
               AND mtt.transaction_type_name IN
                       (p_transaction_type1, NVL (p_transaction_type2, '0'), NVL (p_transaction_type3, 0),
                        NVL (p_transaction_type4, 0));

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_trans_type_qty_fnc;

    --Function to calculate on hand value
    FUNCTION xxdo_trans_type_value_fnc (
        p_inventory_item_id   IN NUMBER,
        p_organization_id     IN NUMBER,
        p_transaction_type1   IN VARCHAR2,
        p_transaction_type2   IN VARCHAR2,
        p_transaction_type3   IN VARCHAR2 DEFAULT NULL,
        p_transaction_type4   IN VARCHAR2 DEFAULT NULL,
        p_from_date           IN DATE,
        p_to_date             IN DATE)
        RETURN NUMBER
    IS
        v_return_val   NUMBER;
    BEGIN
        SELECT /*+LEADING(mmt) index(mmt MTL_MATERIAL_TRANSACTIONS_N1) ALL_ROWS*/
               SUM (
                   DECODE (
                       mmt.transaction_quantity,
                       0, (SELECT SUM (mta.base_transaction_value)
                             FROM mtl_transaction_accounts mta
                            WHERE     mta.accounting_line_type = 1
                                  AND mmt.transaction_id = mta.transaction_id),
                       --Start modification by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
                       --mmt.transaction_quantity * mmt.new_cost))
                       mmt.transaction_quantity * mmt.actual_cost))
          --End modification by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
          INTO v_return_val
          FROM mtl_material_transactions mmt, mtl_transaction_types mtt
         WHERE     1 = 1
               AND mmt.transaction_type_id = mtt.transaction_type_id
               AND mtt.transaction_type_name IN
                       (p_transaction_type1, NVL (p_transaction_type2, '0'), NVL (p_transaction_type3, 0),
                        NVL (p_transaction_type4, 0))
               AND mmt.inventory_item_id = p_inventory_item_id
               AND mmt.organization_id = p_organization_id
               AND TRUNC (mmt.transaction_date) >= p_from_date --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
               AND TRUNC (mmt.transaction_date) < p_to_date + 1; --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_trans_type_value_fnc;

    FUNCTION xxdo_other_type_value_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_from_date IN DATE
                                        , p_to_date IN DATE)
        RETURN NUMBER
    IS
        v_return_val   NUMBER;
    BEGIN
        SELECT /*+LEADING(mmt) index(mmt MTL_MATERIAL_TRANSACTIONS_N1) ALL_ROWS*/
               SUM (
                   DECODE (
                       mmt.transaction_quantity,
                       0, (SELECT SUM (mta.base_transaction_value)
                             FROM mtl_transaction_accounts mta
                            WHERE     mta.accounting_line_type = 1
                                  AND mmt.transaction_id = mta.transaction_id),
                       --Start modification by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
                       --mmt.transaction_quantity * mmt.new_cost))
                       mmt.transaction_quantity * mmt.actual_cost))
          --End modification by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
          INTO v_return_val
          FROM mtl_material_transactions mmt, mtl_transaction_types mtt
         WHERE     1 = 1
               AND mmt.transaction_type_id = mtt.transaction_type_id
               -- Start modification by BT Technology Team for UAT2 Defect 763 on 04-Dec-2015
               AND NOT EXISTS
                       (SELECT 1
                          FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
                         WHERE     ffvs.flex_value_set_id =
                                   ffvv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_INV_TRANS_EXCLUDE_VS'
                               AND ffvv.enabled_flag = 'Y'
                               AND ffvv.flex_value =
                                   mtt.transaction_type_name)
               -- End modification by BT Technology Team for UAT2 Defect 763 on 04-Dec-2015
               AND mmt.inventory_item_id = p_inventory_item_id
               AND mmt.organization_id = p_organization_id
               AND TRUNC (mmt.transaction_date) >= p_from_date --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
               AND TRUNC (mmt.transaction_date) < p_to_date + 1; --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_other_type_value_fnc;

    FUNCTION xxdo_other_type_qty_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_from_date IN DATE
                                      , p_to_date IN DATE)
        RETURN NUMBER
    IS
        v_return_val   NUMBER;
    BEGIN
        SELECT /*+LEADING(mmt) index(mmt MTL_MATERIAL_TRANSACTIONS_N1) ALL_ROWS*/
               SUM (mmt.transaction_quantity)
          INTO v_return_val
          FROM mtl_material_transactions mmt, mtl_transaction_types mtt
         WHERE     1 = 1
               AND mmt.transaction_type_id = mtt.transaction_type_id
               -- Start modification by BT Technology Team for UAT2 Defect 763 on 04-Dec-2015
               AND NOT EXISTS
                       (SELECT 1
                          FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
                         WHERE     ffvs.flex_value_set_id =
                                   ffvv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_INV_TRANS_EXCLUDE_VS'
                               AND ffvv.enabled_flag = 'Y'
                               AND ffvv.flex_value =
                                   mtt.transaction_type_name)
               -- End modification by BT Technology Team for UAT2 Defect 763 on 04-Dec-2015
               AND mmt.inventory_item_id = p_inventory_item_id
               AND mmt.organization_id = p_organization_id
               AND TRUNC (mmt.transaction_date) >= p_from_date --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
               AND TRUNC (mmt.transaction_date) < p_to_date + 1; --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_other_type_qty_fnc;

    --function to calculate on hand quantity on a specific date
    FUNCTION xxdo_on_hand_qty_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_ret_val   NUMBER;
    BEGIN
        SELECT /*+ALL_ROWS*/
               SUM (a.target_qty)
          INTO v_ret_val
          FROM (  SELECT SUM (oq.target_qty) target_qty, item_id, subinv
                    FROM (  SELECT moqv.subinventory_code subinv, moqv.inventory_item_id item_id, NVL (SUM (moqv.transaction_quantity), 0) target_qty
                              FROM mtl_onhand_qty_cost_v moqv
                             WHERE     moqv.organization_id = p_organization_id
                                   AND moqv.inventory_item_id =
                                       p_inventory_item_id
                          GROUP BY moqv.subinventory_code, moqv.inventory_item_id, moqv.item_cost
                          UNION ALL           -- Added By Raja for Jun 06 2016
                            SELECT /*+LEADING(mmt) index(mmt MTL_MATERIAL_TRANSACTIONS_N1)*/
                                   mmt.subinventory_code subinv, mmt.inventory_item_id item_id, NVL (-SUM (primary_quantity), 0) target_qty
                              FROM mtl_material_transactions mmt, mtl_txn_source_types mtst
                             WHERE     mmt.organization_id = p_organization_id
                                   -- Start modification on 13-May-2016
                                   --AND TRUNC (transaction_date) >= p_date + 1 --Added TRUNC by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
                                   AND TRUNC (mmt.transaction_date) >= p_date
                                   AND mmt.subinventory_code IS NOT NULL
                                   -- End modification on 13-May-2016
                                   AND mmt.transaction_source_type_id =
                                       mtst.transaction_source_type_id
                                   AND mmt.inventory_item_id =
                                       p_inventory_item_id
                          GROUP BY mmt.subinventory_code, mmt.inventory_item_id)
                         oq
                GROUP BY item_id, subinv) a,
               mtl_secondary_inventories b
         WHERE     a.subinv = b.secondary_inventory_name
               AND b.asset_inventory = 1
               AND b.organization_id = p_organization_id;

        RETURN v_ret_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_ret_val   := NULL;
            RETURN v_ret_val;
    END xxdo_on_hand_qty_fnc;

    -- Start modification by BT Technology Team for UAT2 Defect 689 on 26-Nov-2015
    --function to calculate overhead material cost on a specific date
    FUNCTION xxdo_cst_mat_oh_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_ret_val   NUMBER;
    BEGIN
        SELECT /*+ optimizer_features_enable('11.2.0.4') */
               new_material_overhead               --Added hint for change 1.8
          INTO v_ret_val
          FROM cst_cg_cost_history_v
         WHERE     transaction_id =
                   (SELECT MAX (cst2.transaction_id)
                      FROM cst_cg_cost_history_v cst2
                     WHERE     1 = 1
                           AND cst2.organization_id = p_organization_id
                           AND cst2.inventory_item_id = p_inventory_item_id
                           AND (cst2.transaction_costed_date) =
                               (SELECT MAX (cst1.transaction_costed_date)
                                  FROM cst_cg_cost_history_v cst1
                                 WHERE     1 = 1
                                       AND cst1.organization_id =
                                           p_organization_id
                                       AND cst1.inventory_item_id =
                                           p_inventory_item_id
                                       AND TRUNC (-- Start modification by BT Technology Team for Incident INC0289144 on 27-Apr-2016
                                                  --cst1.transaction_costed_date) <=
                                                  cst1.transaction_date) <=
                                           -- End modification by BT Technology Team for Incident INC0289144 on 27-Apr-2016
                                           NVL (p_date, SYSDATE)))
               AND organization_id = p_organization_id
               AND inventory_item_id = p_inventory_item_id;

        RETURN v_ret_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_ret_val   := NULL;
            RETURN v_ret_val;
    END xxdo_cst_mat_oh_val_fnc;

    --function to calculate materila cost on a specific date
    FUNCTION xxdo_cst_mat_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        v_ret_val   NUMBER;
    BEGIN
        SELECT /*+ optimizer_features_enable('11.2.0.4') */
               new_material                             --Added for change 1.8
          INTO v_ret_val
          FROM cst_cg_cost_history_v
         WHERE     transaction_id =
                   (SELECT MAX (cst2.transaction_id)
                      FROM cst_cg_cost_history_v cst2
                     WHERE     1 = 1
                           AND cst2.organization_id = p_organization_id
                           AND cst2.inventory_item_id = p_inventory_item_id
                           AND (cst2.transaction_costed_date) =
                               (SELECT MAX (cst1.transaction_costed_date)
                                  FROM cst_cg_cost_history_v cst1
                                 WHERE     1 = 1
                                       AND cst1.organization_id =
                                           p_organization_id
                                       AND cst1.inventory_item_id =
                                           p_inventory_item_id
                                       AND TRUNC (-- Start modification by BT Technology Team for Incident INC0289144 on 27-Apr-2016
                                                  --cst1.transaction_costed_date) <=
                                                  cst1.transaction_date) <=
                                           -- End modification by BT Technology Team for Incident INC0289144 on 27-Apr-2016
                                           NVL (p_date, SYSDATE)))
               AND organization_id = p_organization_id
               AND inventory_item_id = p_inventory_item_id;

        RETURN v_ret_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_ret_val   := NULL;
            RETURN v_ret_val;
    END xxdo_cst_mat_val_fnc;

    -- End modification by BT Technology Team for UAT2 Defect 689 on 26-Nov-2015
    -- Start changes by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
    FUNCTION get_subinv_fnc (p_subinv_name       IN VARCHAR2,
                             p_organization_id   IN NUMBER)
        RETURN NUMBER
    AS
        CURSOR get_subinv_details_c IS
            SELECT /*+ALL_ROWS*/
                   COUNT (1)
              FROM mtl_secondary_inventories msi
             WHERE     secondary_inventory_name = p_subinv_name
                   AND organization_id = p_organization_id
                   AND asset_inventory = 1
                   AND NOT EXISTS
                           (SELECT 1
                              FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                             WHERE     ff1.flex_value_set_id =
                                       ff2.flex_value_set_id
                                   --AND UPPER (ff1.flex_value_set_name) =   -- 1.7
                                   --     UPPER ('XXDO_SECONDARY_INV_NAME') --1.7
                                   AND ff1.flex_value_set_name =
                                       'XXDO_SECONDARY_INV_NAME'        -- 1.7
                                   AND ff2.enabled_flag = 'Y'
                                   AND ff2.flex_value =
                                       secondary_inventory_name);

        ln_ret_value   NUMBER DEFAULT 0;
    BEGIN
        OPEN get_subinv_details_c;

        FETCH get_subinv_details_c INTO ln_ret_value;

        CLOSE get_subinv_details_c;

        ln_ret_value   :=
            CASE
                WHEN ln_ret_value >= 1 THEN 1
                ELSE ln_ret_value
            END;

        RETURN ln_ret_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_subinv_fnc;

    -- End changes by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015

    -- Start changes by BT Technology Team for UAT2 Defect 763 on 09-Dec-2015
    --Function to calculate Intransit Shipment Value
    FUNCTION xxdo_intransit_ship_value_fnc (
        p_inventory_item_id   IN NUMBER,
        p_organization_id     IN NUMBER,
        p_transaction_type1   IN VARCHAR2,
        p_transaction_type2   IN VARCHAR2,
        p_transaction_type3   IN VARCHAR2 DEFAULT NULL,
        p_transaction_type4   IN VARCHAR2 DEFAULT NULL,
        p_from_date           IN DATE,
        p_to_date             IN DATE)
        RETURN NUMBER
    IS
        v_return_val   NUMBER;
    BEGIN
        SELECT SUM (mta.base_transaction_value)
          INTO v_return_val
          FROM mtl_material_transactions mmt, mtl_transaction_types mtt, mtl_transaction_accounts mta
         WHERE     TRUNC (mmt.transaction_date) >= p_from_date
               AND TRUNC (mmt.transaction_date) < p_to_date + 1
               AND mmt.transaction_type_id = mtt.transaction_type_id
               AND mmt.transaction_id = mta.transaction_id
               AND mta.organization_id = mmt.transfer_organization_id
               AND mta.accounting_line_type = 14                  -- Intransit
               AND mmt.inventory_item_id = p_inventory_item_id
               AND mmt.transfer_organization_id = p_organization_id
               AND mtt.transaction_type_name IN
                       (p_transaction_type1, NVL (p_transaction_type2, '0'), NVL (p_transaction_type3, 0),
                        NVL (p_transaction_type4, 0));

        RETURN v_return_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_return_val   := NULL;
            RETURN v_return_val;
    END xxdo_intransit_ship_value_fnc;
-- End changes by BT Technology Team for UAT2 Defect 763 on 09-Dec-2015

END xxd_fg_inv_val_rpt_pkg;
/
