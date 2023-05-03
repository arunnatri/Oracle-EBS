--
-- XXDOEC_ORDER_RECONCILE_STATUS  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   HZ_CUST_ACCOUNTS (Synonym)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_ORDER_RECONCILE_STATUS"
AS
    g_error   BOOLEAN := FALSE;

    TYPE order_detail IS RECORD
    (
        header_id             oe_order_lines_all.header_id%TYPE,
        line_grp_id           oe_order_lines_all.attribute18%TYPE,
        line_id               oe_order_lines_all.line_id%TYPE,
        order_number          oe_order_headers_all.orig_sys_document_ref%TYPE,
        ordered_date          oe_order_headers_all.ordered_date%TYPE,
        total_order_amount    oe_order_lines_all.unit_selling_price%TYPE,
        customer_number       hz_cust_accounts.account_number%TYPE,
        account_name          hz_cust_accounts.account_name%TYPE,
        email_address         VARCHAR2 (2000),      --hz_parties.email_address
        order_status          oe_order_headers_all.flow_status_code%TYPE,
        shipping_date         oe_order_lines_all.actual_shipment_date%TYPE,
        model_number          mtl_system_items_b.segment1%TYPE,
        color_code            mtl_system_items_b.segment2%TYPE,
        product_size          mtl_system_items_b.segment3%TYPE,
        product_name          mtl_system_items_b.description%TYPE,
        inventory_item_id     oe_order_lines_all.inventory_item_id%TYPE,
        ordered_quantity      oe_order_lines_all.ordered_quantity%TYPE,
        unit_selling_price    oe_order_lines_all.unit_selling_price%TYPE,
        subtotal              oe_order_lines_all.unit_selling_price%TYPE,
        line_status           oe_order_lines_all.flow_status_code%TYPE,
        open_flag             oe_order_lines_all.open_flag%TYPE,
        cancelled_flag        oe_order_lines_all.cancelled_flag%TYPE,
        booked_flag           oe_order_lines_all.booked_flag%TYPE,
        return_quantity       oe_order_lines_all.ordered_quantity%TYPE,
        exchange_quantity     oe_order_lines_all.ordered_quantity%TYPE,
        cancel_reason         fnd_lookup_values.meaning%TYPE
    );

    TYPE t_order_detail_cursor IS REF CURSOR
        RETURN order_detail;

    PROCEDURE get_order_detail (
        p_order_number   IN     VARCHAR2,
        o_order_detail      OUT t_order_detail_cursor);
/**************************************************************************************
Order reconcilation status web service call for commission junction reconciliation
Author:  Aram Malinich
***************************************************************************************/
END XXDOEC_ORDER_RECONCILE_STATUS;
/
