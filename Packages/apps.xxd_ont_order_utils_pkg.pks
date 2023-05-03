--
-- XXD_ONT_ORDER_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_LINES_ALL (Synonym)
--   STANDARD (Package)
--   XXD_ONT_ORD_LINE_OBJ (Type)
--
/* Formatted on 4/26/2023 4:23:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_ORDER_UTILS_PKG"
    AUTHID DEFINER
AS
    /****************************************************************************************
    * Package      : XXD_ONT_ORDER_UTILS_PKG
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
    gc_skip_neg_unconsumption        VARCHAR2 (1) := 'N';

    PROCEDURE create_oe_reason (pn_line_id IN NUMBER, pc_reason_type IN VARCHAR2, pc_reason_code IN VARCHAR2
                                , pc_comment IN VARCHAR2, xn_reason_id OUT NUMBER, xc_ret_stat OUT VARCHAR2);

    PROCEDURE create_order_line_history (
        pr_oe_order_lines    IN     oe_order_lines_all%ROWTYPE,
        pn_cancel_quantity   IN     NUMBER,
        pn_reason_id         IN     NUMBER,
        pc_hist_type_code    IN     VARCHAR2,
        xc_ret_stat             OUT VARCHAR2);

    PROCEDURE cancel_line_qty (pn_line_id IN NUMBER, pc_reason_code IN VARCHAR2, pc_comment IN VARCHAR2
                               , pn_cancel_quantity IN NUMBER, xn_cancelled_quantity OUT NUMBER, xc_ret_stat OUT VARCHAR2);

    PROCEDURE increase_line_qty (pn_line_id IN NUMBER, pn_increase_quantity IN NUMBER, pn_calloff_line_id IN NUMBER
                                 , pd_calloff_old_ssd IN DATE, xn_increased_quantity OUT NUMBER, xc_ret_stat OUT VARCHAR2);

    FUNCTION oola_obj_to_rec_fnc (p_obj IN xxd_ne.xxd_ont_ord_line_obj)
        RETURN oe_order_lines_all%ROWTYPE;
END xxd_ont_order_utils_pkg;
/
