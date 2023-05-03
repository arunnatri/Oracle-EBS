--
-- XXD_FG_INV_VAL_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FG_INV_VAL_RPT_PKG"
IS
    /*******************************************************************************
       * Program Name : XXD_FG_INV_VAL_RPT_PKG
       * Language     : PL/SQL
       * Description  : This package is used by DECKARES FG Inventory Value By brand report
       *
       * History      :
       *
       * WHO                   Desc                                           WHEN
       * ------------------    ---------------------------------------------- ---------------
       * BT Technology Team    1.0 - Initial Version                          MAR/30/2015
       * BT Technology Team    1.1 - Fix for UAT2 Defect 689                  NOV/26/2015
       *                       Added material cost/ Over head function
       * BT Technology Team    1.2 - Fix for UAT2 Defect 614                  30-Nov-2015
       * BT Technology Team    1.3 - Fix for UAT2 Defect 763                  09-Dec-2015
       * ------------------------------------------------------------------------------------ */
    FUNCTION xxdo_cst_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_trans_type_qty_fnc (
        p_inventory_item_id   IN NUMBER,
        p_organization_id     IN NUMBER,
        p_transaction_type1   IN VARCHAR2,
        p_transaction_type2   IN VARCHAR2,
        p_transaction_type3   IN VARCHAR2 DEFAULT NULL,
        p_transaction_type4   IN VARCHAR2 DEFAULT NULL,
        p_from_date           IN DATE,
        p_to_date             IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_trans_type_value_fnc (
        p_inventory_item_id   IN NUMBER,
        p_organization_id     IN NUMBER,
        p_transaction_type1   IN VARCHAR2,
        p_transaction_type2   IN VARCHAR2,
        p_transaction_type3   IN VARCHAR2 DEFAULT NULL,
        p_transaction_type4   IN VARCHAR2 DEFAULT NULL,
        p_from_date           IN DATE,
        p_to_date             IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_other_type_value_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_from_date IN DATE
                                        , p_to_date IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_other_type_qty_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_from_date IN DATE
                                      , p_to_date IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_on_hand_qty_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    -- Start modification by BT Technology Team for UAT2 Defect 689 on 26-Nov-2015
    FUNCTION xxdo_cst_mat_oh_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_cst_mat_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    -- End modification by BT Technology Team for UAT2 Defect 689 on 26-Nov-2015
    -- Start changes by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
    FUNCTION get_subinv_fnc (p_subinv_name       IN VARCHAR2,
                             p_organization_id   IN NUMBER)
        RETURN NUMBER;

    -- End changes by BT Technology Team for UAT2 Defect 614 on 30-Nov-2015
    -- Start changes by BT Technology Team for UAT2 Defect 763 on 09-Dec-2015
    FUNCTION xxdo_intransit_ship_value_fnc (
        p_inventory_item_id   IN NUMBER,
        p_organization_id     IN NUMBER,
        p_transaction_type1   IN VARCHAR2,
        p_transaction_type2   IN VARCHAR2,
        p_transaction_type3   IN VARCHAR2 DEFAULT NULL,
        p_transaction_type4   IN VARCHAR2 DEFAULT NULL,
        p_from_date           IN DATE,
        p_to_date             IN DATE)
        RETURN NUMBER;
-- End changes by BT Technology Team for UAT2 Defect 763 on 09-Dec-2015

END XXD_FG_INV_VAL_RPT_PKG;
/
