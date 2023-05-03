--
-- XXDO_SO_REQ_DATE_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   DO_DEBUG_UTILS (Package)
--   OE_ORDER_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SO_REQ_DATE_UPDATE_PKG"
/*******************************************************************************
* $Header$
* Program Name : XXDO_SO_REQ_DATE_UPDATE_PKG.pkb
* Language     : PL/SQL
* Description  : This package is used for sending notification for credit line change
* History      :
* 01-APR-2015 Created as Initial
* ------------------------------------------------------------------------
* WHO                        WHAT               WHEN
* --------------         ---------------------- ---------------
* BT Technology Team                             01-Apr-2015
* BT Technology Team        1.1 Defect 2740      15-Jul-2015
* BT Technology Team        1.2 for Japan Lead Time CR# 104    23-Jul-2015
*******************************************************************************/
AS
    GV_PACKAGE_NAME    VARCHAR2 (50) := 'XXDO_SO_REQ_DATE_UPDATE_PKG.';
    g_debug_location   NUMBER := do_debug_utils.debug_conc_log;

    --Kept for backward compatability for automated requests

    /*----------------------------------------------------------
    Main entry funtion for legacy call

    This is the main procedure that supports the existinc concurrent request used for the automated processes

    p_run_type   -- Which process to run
    p_inv_org_id -- Inventory Org Id to check
    p_po_number  -- Optional PO number to process
    p_as_of_date -- Limit on number of days to look back (for performance reasons)

    -------------------------------------------------------------*/
    PROCEDURE MAIN (errbuf            OUT VARCHAR2,
                    retcode           OUT VARCHAR2,
                    p_run_type     IN     VARCHAR2,
                    p_inv_org_id   IN     VARCHAR2,
                    p_po_number    IN     VARCHAR2,
                    p_as_of_date   IN     NUMBER);

    --New entry function to support new concurrent request

    /*----------------------------------------------------------
   Main entry funtion for new concurrent request

   This is the process added for the new report / execute mode option for PO XFDate to ISO date update
   --Renamed from Main as there was a conflicting procedure signature

   p_inv_org_id -- Inventory Org Id to check
   p_po_number  -- Optional PO number to process
   p_run_mode   -- Report oe Execute mode (specifically for the PO Promised Date to ISO request date update
   p_as_of_date -- Limit on number of days to look back (for performance reasons)

   -------------------------------------------------------------*/
    PROCEDURE RUN_ISO_REQ_UPDATE (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_inv_org_id IN NUMBER
                                  , p_po_number IN VARCHAR2, p_run_mode IN VARCHAR2, p_as_of_date IN NUMBER); --Lookup'R'='Report', 'E'='Execute'

    PROCEDURE CALL_PROCESS_ORDER (p_org_id IN NUMBER, p_header_rec IN oe_order_pub.header_rec_type:= oe_order_pub.g_miss_header_rec, p_header_price_adj_tbl IN oe_order_pub.header_adj_tbl_type:= oe_order_pub.g_miss_header_adj_tbl, p_line_tbl IN oe_order_pub.line_tbl_type:= oe_order_pub.g_miss_line_tbl, p_line_price_adj_tbl IN oe_order_pub.line_adj_tbl_type:= oe_order_pub.g_miss_line_adj_tbl, x_header_rec OUT oe_order_pub.header_rec_type, x_header_adj_tbl OUT oe_order_pub.header_adj_tbl_type, x_line_tbl OUT oe_order_pub.line_tbl_type, x_line_adj_tbl OUT oe_order_pub.line_adj_tbl_type, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2, p_debug_location IN NUMBER:= do_debug_utils.debug_table
                                  , p_do_commit IN NUMBER:= 1);

    FUNCTION GET_TQ_LIST_PRICE (p_header_id IN NUMBER, p_unit_price IN NUMBER, p_vendor_id IN NUMBER
                                , p_item_id IN NUMBER, p_org_id IN NUMBER)
        RETURN NUMBER;
END XXDO_SO_REQ_DATE_UPDATE_PKG;
/
