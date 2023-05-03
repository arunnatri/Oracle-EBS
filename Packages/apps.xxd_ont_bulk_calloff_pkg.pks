--
-- XXD_ONT_BULK_CALLOFF_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_LINES_ALL (Synonym)
--   OE_ORDER_PUB (Package)
--   XXD_ONT_CONSUMPTION_LINE_T_OBJ (Type)
--   XXD_ONT_ELEGIBLE_LINES_T_OBJ (Type)
--   XXD_ONT_LINES_T_OBJ (Type)
--   STANDARD (Package)
--   XXD_ONT_ORD_LINE_OBJ (Type)
--
/* Formatted on 4/26/2023 4:22:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BULK_CALLOFF_PKG"
    AUTHID DEFINER
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_CALLOFF_PKG
    * Design       : This package will will manage the bulk calloff process
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2020  1.0        Deckers                 Initial Version
    ******************************************************************************************/
    g_miss_num              CONSTANT NUMBER := 9.99e125;
    g_miss_char             CONSTANT VARCHAR2 (1) := CHR (0);
    g_miss_date             CONSTANT DATE := TO_DATE ('1', 'j');
    g_ret_sts_success       CONSTANT VARCHAR2 (1) := 'S';
    g_ret_sts_error         CONSTANT VARCHAR2 (1) := 'E';
    g_ret_sts_unexp_error   CONSTANT VARCHAR2 (1) := 'U';
    g_true                  CONSTANT VARCHAR2 (1) := 'T';
    g_false                 CONSTANT VARCHAR2 (1) := 'F';
    g_consumption_flag               BOOLEAN := FALSE;
    gt_excluded_line_ids             xxd_ont_elegible_lines_t_obj;
    gt_identified_line_ids           xxd_ont_elegible_lines_t_obj;
    gt_collected_line_ids            xxd_ont_lines_t_obj;
    gc_no_unconsumption              VARCHAR2 (1) := 'N';
    gc_commiting_flag                VARCHAR2 (1) := 'N';
    gn_idx                           NUMBER := 0;

    TYPE recs_table IS TABLE OF xxd_ne.xxd_ont_ord_line_obj
        INDEX BY PLS_INTEGER; -- Can be changed to oe_order_lines_all%rowtype >12c

    TYPE char_table IS TABLE OF VARCHAR2 (10)
        INDEX BY PLS_INTEGER;

    gt_operations                    char_table;
    gt_new_recs                      recs_table;
    gt_old_recs                      recs_table;

    PROCEDURE sync_exclusion;

    PROCEDURE lock_lines;

    PROCEDURE collect_lines (pc_action VARCHAR2, pr_new_obj xxd_ne.xxd_ont_ord_line_obj, pr_old_obj xxd_ne.xxd_ont_ord_line_obj); -- Can be changed to oe_order_lines_all%rowtype >12c

    PROCEDURE process_order_line_change (pc_action VARCHAR2, pr_new_obj xxd_ne.xxd_ont_ord_line_obj, pr_old_obj xxd_ne.xxd_ont_ord_line_obj); -- Can be changed to oe_order_lines_all%rowtype >12c

    PROCEDURE add_line_id_to_exclusion (pn_line_id IN NUMBER, pn_inventory_item_id IN NUMBER, pn_priority IN NUMBER:= 0);

    PROCEDURE clear_excluded_line_ids;

    PROCEDURE store_info (p_line_rec IN oe_order_lines_all%ROWTYPE);

    PROCEDURE store_info (
        p_line_rec       IN apps.oe_order_pub.line_rec_type,
        p_old_line_rec   IN apps.oe_order_pub.line_rec_type);

    FUNCTION consumption_to_string (
        pt_consumption xxd_ont_consumption_line_t_obj)
        RETURN VARCHAR;

    FUNCTION string_to_consumption (pc_consumption VARCHAR2)
        RETURN xxd_ont_consumption_line_t_obj;

    FUNCTION get_root_line_id (pn_child NUMBER)
        RETURN NUMBER;

    FUNCTION get_child_qty (pn_parent_line_id NUMBER)
        RETURN NUMBER;
END xxd_ont_bulk_calloff_pkg;
/
