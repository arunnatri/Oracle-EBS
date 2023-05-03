--
-- XXDOEC_SALESORDER_STAGING_PKG  (Package) 
--
--  Dependencies: 
--   DO_ORDER_HEADERS (Table)
--   DO_ORDER_LINES (Table)
--   DO_ORDER_PRICE_ADJS (Table)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_SALESORDER_STAGING_PKG"
AS
    PROCEDURE delete_order_detail_from_stage (p_orig_sys_document_ref IN do_om.do_order_headers.orig_sys_document_ref%TYPE, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2);

    PROCEDURE insert_sales_header_to_stage (
        p_orig_sys_document_ref         do_om.do_order_headers.orig_sys_document_ref%TYPE,
        p_order_source_id               do_om.do_order_headers.order_source_id%TYPE,
        p_org_id                        do_om.do_order_headers.org_id%TYPE,
        p_ordered_date                  do_om.do_order_headers.ordered_date%TYPE,
        p_order_type_id                 do_om.do_order_headers.order_type_id%TYPE,
        p_price_list_id                 do_om.do_order_headers.price_list_id%TYPE,
        p_transactional_curr_code       do_om.do_order_headers.transactional_curr_code%TYPE,
        p_salesrep_id                   do_om.do_order_headers.salesrep_id%TYPE,
        p_payment_term_id               do_om.do_order_headers.payment_term_id%TYPE,
        p_demand_class_code             do_om.do_order_headers.demand_class_code%TYPE,
        p_shipping_method_code          do_om.do_order_headers.shipping_method_code%TYPE,
        p_freight_terms_code            do_om.do_order_headers.freight_terms_code%TYPE,
        p_fob_point_code                do_om.do_order_headers.fob_point_code%TYPE,
        p_customer_po_number            do_om.do_order_headers.customer_po_number%TYPE,
        p_sold_to_org_id                do_om.do_order_headers.sold_to_org_id%TYPE,
        p_ship_from_org_id              do_om.do_order_headers.ship_from_org_id%TYPE,
        p_ship_to_org_id                do_om.do_order_headers.ship_to_org_id%TYPE,
        p_invoice_to_org_id             do_om.do_order_headers.invoice_to_org_id%TYPE,
        p_customer_id                   do_om.do_order_headers.customer_id%TYPE,
        p_booked_flag                   do_om.do_order_headers.booked_flag%TYPE,
        p_closed_flag                   do_om.do_order_headers.closed_flag%TYPE,
        p_cancelled_flag                do_om.do_order_headers.cancelled_flag%TYPE,
        p_attribute1                    do_om.do_order_headers.attribute1%TYPE,
        p_attribute2                    do_om.do_order_headers.attribute2%TYPE,
        p_attribute5                    do_om.do_order_headers.attribute5%TYPE,
        p_attribute6                    do_om.do_order_headers.attribute6%TYPE := NULL,
        p_attribute7                    do_om.do_order_headers.attribute7%TYPE := NULL,
        p_attribute9                    do_om.do_order_headers.attribute9%TYPE,
        p_created_by                    do_om.do_order_headers.created_by%TYPE,
        p_last_updated_by               do_om.do_order_headers.last_updated_by%TYPE,
        p_request_date                  do_om.do_order_headers.request_date%TYPE,
        p_operation_code                do_om.do_order_headers.operation_code%TYPE,
        p_order_category                do_om.do_order_headers.order_category%TYPE,
        p_sold_from_org_id              do_om.do_order_headers.sold_from_org_id%TYPE,
        p_shipping_instructions         do_om.do_order_headers.shipping_instructions%TYPE,
        p_packing_instructions          do_om.do_order_headers.packing_instructions%TYPE,
        p_error_flag                    do_om.do_order_headers.error_flag%TYPE,
        p_global_attribute18            do_om.do_order_headers.global_attribute18%TYPE := NULL,
        p_global_attribute19            do_om.do_order_headers.global_attribute19%TYPE := NULL,
        x_return_status             OUT VARCHAR2,
        x_error_text                OUT VARCHAR2);

    PROCEDURE insert_line_to_stage (p_orig_sys_document_ref do_om.do_order_lines.orig_sys_document_ref%TYPE, p_orig_sys_line_ref do_om.do_order_lines.orig_sys_line_ref%TYPE, p_order_source_id do_om.do_order_lines.order_source_id%TYPE, p_line_number do_om.do_order_lines.line_number%TYPE, p_inventory_item_id do_om.do_order_lines.inventory_item_id%TYPE, p_org_id do_om.do_order_lines.org_id%TYPE, p_customer_po_number do_om.do_order_lines.customer_po_number%TYPE, p_pricing_date do_om.do_order_lines.pricing_date%TYPE, p_pricing_quantity do_om.do_order_lines.pricing_quantity%TYPE, p_ordered_quantity do_om.do_order_lines.ordered_quantity%TYPE, p_order_quantity_uom do_om.do_order_lines.order_quantity_uom%TYPE, p_ship_from_org_id do_om.do_order_lines.ship_from_org_id%TYPE, p_ship_to_org_id do_om.do_order_lines.ship_to_org_id%TYPE, p_sold_to_org_id do_om.do_order_lines.sold_to_org_id%TYPE, p_price_list_id do_om.do_order_lines.price_list_id%TYPE, p_unit_list_price do_om.do_order_lines.unit_list_price%TYPE, p_unit_selling_price do_om.do_order_lines.unit_selling_price%TYPE, p_calculate_price_flag do_om.do_order_lines.calculate_price_flag%TYPE, p_payment_term_id do_om.do_order_lines.payment_term_id%TYPE, p_salesrep_id do_om.do_order_lines.salesrep_id%TYPE, p_attribute1 do_om.do_order_lines.attribute1%TYPE, p_attribute2 do_om.do_order_lines.attribute2%TYPE, p_attribute3 do_om.do_order_lines.attribute3%TYPE, p_created_by do_om.do_order_lines.created_by%TYPE, p_last_updated_by do_om.do_order_lines.last_updated_by%TYPE, p_operation_code do_om.do_order_lines.operation_code%TYPE, p_request_date do_om.do_order_lines.request_date%TYPE, p_unit_list_price_per_pqty do_om.do_order_lines.unit_list_price_per_pqty%TYPE, p_unit_selling_price_per_pqty do_om.do_order_lines.unit_selling_price_per_pqty%TYPE, p_tax_code DO_OM.DO_ORDER_LINES.TAX_CODE%TYPE, p_tax_date DO_OM.DO_ORDER_LINES.TAX_DATE%TYPE, p_tax_value DO_OM.DO_ORDER_LINES.TAX_VALUE%TYPE, p_closed_flag do_om.do_order_lines.closed_flag%TYPE, p_error_flag do_om.do_order_lines.error_flag%TYPE, p_line_type_id do_om.do_order_lines.line_type_id%TYPE, p_shipping_instructions do_om.do_order_lines.shipping_instructions%TYPE, p_shipping_method_code do_om.do_order_lines.shipping_method_code%TYPE, p_fluid_recipe_id do_om.do_order_lines.fluid_recipe_id%TYPE, -- ref 2707455 - global_attributes to store localized values
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_global_attribute19 do_om.do_order_lines.global_attribute19%TYPE
                                    , p_global_attribute20 do_om.do_order_lines.global_attribute20%TYPE, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2);

    PROCEDURE insert_price_adj_to_stage (
        p_orig_sys_document_ref          do_om.do_order_price_adjs.orig_sys_document_ref%TYPE,
        p_orig_sys_line_ref              do_om.do_order_price_adjs.orig_sys_line_ref%TYPE,
        p_orig_sys_discount_ref          do_om.do_order_price_adjs.orig_sys_discount_ref%TYPE,
        p_order_source_id                do_om.do_order_price_adjs.order_source_id%TYPE,
        p_created_by                     do_om.do_order_price_adjs.created_by%TYPE,
        p_last_updated_by                do_om.do_order_price_adjs.last_updated_by%TYPE,
        p_automatic_flag                 do_om.do_order_price_adjs.automatic_flag%TYPE,
        p_list_header_id                 do_om.do_order_price_adjs.list_header_id%TYPE,
        p_list_line_id                   do_om.do_order_price_adjs.list_line_id%TYPE,
        p_list_line_type_code            do_om.do_order_price_adjs.list_line_type_code%TYPE,
        p_applied_flag                   do_om.do_order_price_adjs.applied_flag%TYPE,
        p_percent                        do_om.do_order_price_adjs.percent%TYPE,
        p_operation_code                 do_om.do_order_price_adjs.operation_code%TYPE,
        p_operand                        do_om.do_order_price_adjs.operand%TYPE,
        p_arithmetic_operator            do_om.do_order_price_adjs.arithmetic_operator%TYPE,
        p_adjusted_amount                do_om.do_order_price_adjs.adjusted_amount%TYPE,
        p_operand_per_pqty               do_om.do_order_price_adjs.operand_per_pqty%TYPE,
        p_adjusted_amount_per_pqty       do_om.do_order_price_adjs.adjusted_amount_per_pqty%TYPE,
        p_attribute1                     do_om.do_order_price_adjs.attribute1%TYPE,
        p_attribute5                     do_om.do_order_price_adjs.attribute5%TYPE,
        p_attribute2                     do_om.do_order_price_adjs.attribute2%TYPE,
        x_return_status              OUT VARCHAR2,
        x_error_text                 OUT VARCHAR2);
END XXDOEC_SALESORDER_STAGING_PKG;
/
