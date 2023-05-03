--
-- XXDOEC_SALESORDER_STAGING_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_SALESORDER_STAGING_PKG"
AS
    PROCEDURE delete_order_detail_from_stage (p_orig_sys_document_ref IN do_om.do_order_headers.orig_sys_document_ref%TYPE, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2)
    IS
    BEGIN
        x_return_status   := 'S';

        DELETE do_om.do_order_headers
         WHERE orig_sys_document_ref = p_orig_sys_document_ref;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := fnd_api.g_ret_sts_unexp_error;
            x_error_text      :=
                   'Attempt to delete '
                || p_orig_sys_document_ref
                || ' from order staging tables failed with Error: '
                || SQLERRM;
    END;

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
        x_error_text                OUT VARCHAR2)
    IS
        CURSOR c_order_exists (
            c_orig_sys_document_ref   IN do_om.do_order_headers.orig_sys_document_ref%TYPE)
        IS
            SELECT orig_sys_document_ref
              FROM do_om.do_order_headers
             WHERE orig_sys_document_ref = c_orig_sys_document_ref;

        l_return_status           VARCHAR2 (5) := 'S';
        l_error_text              VARCHAR2 (4000) := NULL;
        l_exists                  BOOLEAN := FALSE;
        --Does the order already exist. Assume it does not
        l_ok                      NUMBER := 0;
        l_orig_sys_document_ref   do_om.do_order_headers.orig_sys_document_ref%TYPE;
    BEGIN
        x_return_status   := 'S';

        --See if this order already exists
        IF p_orig_sys_document_ref IS NOT NULL
        THEN
            OPEN c_order_exists (p_orig_sys_document_ref);

            FETCH c_order_exists INTO l_orig_sys_document_ref;

            IF c_order_exists%NOTFOUND
            THEN
                l_exists   := FALSE;

                CLOSE c_order_exists;
            ELSE
                l_exists   := TRUE;

                CLOSE c_order_exists;
            END IF;
        END IF;

        --If the order exists delete it
        IF l_exists = TRUE
        THEN
            delete_order_detail_from_stage (
                p_orig_sys_document_ref   => p_orig_sys_document_ref,
                x_return_status           => l_return_status,
                x_error_text              => l_error_text);

            IF l_return_status = 'S'
            THEN
                l_ok   := 1;
            ELSE
                x_return_status   := l_return_status;
                x_error_text      := l_error_text;
                l_ok              := 0;
            END IF;
        ELSE
            l_ok   := 1;
        END IF;

        IF l_ok = 1
        THEN                     --The order does not exist it is ok to insert
            INSERT INTO do_om.do_order_headers (orig_sys_document_ref,
                                                order_source_id,
                                                org_id,
                                                ordered_date,
                                                order_type_id,
                                                price_list_id,
                                                transactional_curr_code,
                                                salesrep_id,
                                                payment_term_id,
                                                demand_class_code,
                                                shipping_method_code,
                                                freight_terms_code,
                                                fob_point_code,
                                                customer_po_number,
                                                sold_to_org_id,
                                                ship_from_org_id,
                                                ship_to_org_id,
                                                invoice_to_org_id,
                                                customer_id,
                                                booked_flag,
                                                closed_flag,
                                                cancelled_flag,
                                                attribute1,
                                                attribute2,
                                                attribute5,
                                                attribute6,
                                                attribute7,
                                                attribute9,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date,
                                                request_date,
                                                operation_code,
                                                order_category,
                                                sold_from_org_id,
                                                shipping_instructions,
                                                packing_instructions,
                                                error_flag,
                                                global_attribute18,
                                                global_attribute19)
                 VALUES (p_orig_sys_document_ref, p_order_source_id, p_org_id, p_ordered_date, p_order_type_id, p_price_list_id, p_transactional_curr_code, p_salesrep_id, p_payment_term_id, p_demand_class_code, p_shipping_method_code, p_freight_terms_code, p_fob_point_code, p_customer_po_number, p_sold_to_org_id, p_ship_from_org_id, p_ship_to_org_id, p_invoice_to_org_id, p_customer_id, p_booked_flag, p_closed_flag, p_cancelled_flag, p_attribute1, p_attribute2, p_attribute5, p_attribute6, p_attribute7, p_attribute9, p_created_by, SYSDATE, p_last_updated_by, SYSDATE, p_request_date, p_operation_code, p_order_category, p_sold_from_org_id, p_shipping_instructions, p_packing_instructions, p_error_flag
                         , p_global_attribute18, p_global_attribute19);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := fnd_api.g_ret_sts_unexp_error;
            x_error_text      :=
                   'Insert into do_om.do_order_headers table failed with Error: '
                || SQLERRM;
    END insert_sales_header_to_stage;

    PROCEDURE insert_line_to_stage (p_orig_sys_document_ref do_om.do_order_lines.orig_sys_document_ref%TYPE, p_orig_sys_line_ref do_om.do_order_lines.orig_sys_line_ref%TYPE, p_order_source_id do_om.do_order_lines.order_source_id%TYPE, p_line_number do_om.do_order_lines.line_number%TYPE, p_inventory_item_id do_om.do_order_lines.inventory_item_id%TYPE, p_org_id do_om.do_order_lines.org_id%TYPE, p_customer_po_number do_om.do_order_lines.customer_po_number%TYPE, p_pricing_date do_om.do_order_lines.pricing_date%TYPE, p_pricing_quantity do_om.do_order_lines.pricing_quantity%TYPE, p_ordered_quantity do_om.do_order_lines.ordered_quantity%TYPE, p_order_quantity_uom do_om.do_order_lines.order_quantity_uom%TYPE, p_ship_from_org_id do_om.do_order_lines.ship_from_org_id%TYPE, p_ship_to_org_id do_om.do_order_lines.ship_to_org_id%TYPE, p_sold_to_org_id do_om.do_order_lines.sold_to_org_id%TYPE, p_price_list_id do_om.do_order_lines.price_list_id%TYPE, p_unit_list_price do_om.do_order_lines.unit_list_price%TYPE, p_unit_selling_price do_om.do_order_lines.unit_selling_price%TYPE, p_calculate_price_flag do_om.do_order_lines.calculate_price_flag%TYPE, p_payment_term_id do_om.do_order_lines.payment_term_id%TYPE, p_salesrep_id do_om.do_order_lines.salesrep_id%TYPE, p_attribute1 do_om.do_order_lines.attribute1%TYPE, p_attribute2 do_om.do_order_lines.attribute2%TYPE, p_attribute3 do_om.do_order_lines.attribute3%TYPE, p_created_by do_om.do_order_lines.created_by%TYPE, p_last_updated_by do_om.do_order_lines.last_updated_by%TYPE, p_operation_code do_om.do_order_lines.operation_code%TYPE, p_request_date do_om.do_order_lines.request_date%TYPE, p_unit_list_price_per_pqty do_om.do_order_lines.unit_list_price_per_pqty%TYPE, p_unit_selling_price_per_pqty do_om.do_order_lines.unit_selling_price_per_pqty%TYPE, p_tax_code do_om.do_order_lines.tax_code%TYPE, p_tax_date do_om.do_order_lines.tax_date%TYPE, p_tax_value do_om.do_order_lines.tax_value%TYPE, p_closed_flag do_om.do_order_lines.closed_flag%TYPE, p_error_flag do_om.do_order_lines.error_flag%TYPE, p_line_type_id do_om.do_order_lines.line_type_id%TYPE, p_shipping_instructions do_om.do_order_lines.shipping_instructions%TYPE, p_shipping_method_code do_om.do_order_lines.shipping_method_code%TYPE, p_fluid_recipe_id do_om.do_order_lines.fluid_recipe_id%TYPE, -- ref 2707455 - global_attributes to store localized values
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_global_attribute19 do_om.do_order_lines.global_attribute19%TYPE
                                    , p_global_attribute20 do_om.do_order_lines.global_attribute20%TYPE, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2)
    IS
    BEGIN
        x_return_status   := 'S';

        INSERT INTO do_om.do_order_lines (orig_sys_document_ref,
                                          orig_sys_line_ref,
                                          order_source_id,
                                          line_number,
                                          inventory_item_id,
                                          line_type_id,
                                          org_id,
                                          customer_po_number,
                                          pricing_date,
                                          pricing_quantity,
                                          ordered_quantity,
                                          order_quantity_uom,
                                          ship_from_org_id,
                                          ship_to_org_id,
                                          shipping_instructions,
                                          sold_to_org_id,
                                          price_list_id,
                                          unit_list_price,
                                          unit_selling_price,
                                          calculate_price_flag,
                                          payment_term_id,
                                          salesrep_id,
                                          attribute1,
                                          attribute2,
                                          attribute3,
                                          created_by,
                                          creation_date,
                                          last_updated_by,
                                          last_update_date,
                                          operation_code,
                                          request_date,
                                          unit_list_price_per_pqty,
                                          unit_selling_price_per_pqty,
                                          tax_code,
                                          tax_date,
                                          tax_value,
                                          closed_flag,
                                          error_flag,
                                          shipping_method_code,
                                          fluid_recipe_id,
                                          -- ref 2707455 - global_attributes to store localized values
                                          global_attribute19,
                                          global_attribute20)
                 VALUES (p_orig_sys_document_ref,
                         p_orig_sys_line_ref,
                         p_order_source_id,
                         p_line_number,
                         p_inventory_item_id,
                         p_line_type_id,
                         p_org_id,
                         p_customer_po_number,
                         p_pricing_date,
                         p_pricing_quantity,
                         p_ordered_quantity,
                         p_order_quantity_uom,
                         p_ship_from_org_id,
                         p_ship_to_org_id,
                         p_shipping_instructions,
                         p_sold_to_org_id,
                         p_price_list_id,
                         p_unit_list_price,
                         p_unit_selling_price,
                         p_calculate_price_flag,
                         p_payment_term_id,
                         p_salesrep_id,
                         p_attribute1,
                         p_attribute2,
                         p_attribute3,
                         p_created_by,
                         SYSDATE,
                         p_last_updated_by,
                         SYSDATE,
                         p_operation_code,
                         p_request_date,
                         p_unit_list_price_per_pqty,
                         p_unit_selling_price_per_pqty,
                         p_tax_code,
                         p_tax_date,
                         p_tax_value,
                         p_closed_flag,
                         p_error_flag,
                         p_shipping_method_code,
                         -- ref 2707455 - global_attributes to store localized values
                         p_fluid_recipe_id,
                         p_global_attribute19,
                         p_global_attribute20);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := fnd_api.g_ret_sts_unexp_error;
            x_error_text      :=
                   'Insert into do_om.do_order_lines table failed with Error: '
                || SQLERRM;
    END insert_line_to_stage;

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
        p_percent                        do_om.do_order_price_adjs.PERCENT%TYPE,
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
        x_error_text                 OUT VARCHAR2)
    IS
    BEGIN
        x_return_status   := 'S';

        INSERT INTO do_om.do_order_price_adjs (orig_sys_document_ref, orig_sys_line_ref, orig_sys_discount_ref, order_source_id, created_by, creation_date, last_updated_by, last_update_date, automatic_flag, list_header_id, list_line_id, list_line_type_code, applied_flag, PERCENT, operation_code, operand, arithmetic_operator, adjusted_amount, operand_per_pqty, adjusted_amount_per_pqty, attribute1
                                               , attribute5, attribute2)
             VALUES (p_orig_sys_document_ref, p_orig_sys_line_ref, p_orig_sys_discount_ref, p_order_source_id, p_created_by, SYSDATE, p_last_updated_by, SYSDATE, p_automatic_flag, p_list_header_id, p_list_line_id, p_list_line_type_code, p_applied_flag, p_percent, p_operation_code, p_operand, p_arithmetic_operator, p_adjusted_amount, p_operand_per_pqty, p_adjusted_amount_per_pqty, p_attribute1
                     , p_attribute5, p_attribute2);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := fnd_api.g_ret_sts_unexp_error;
            x_error_text      :=
                   'Price adj insert into do_om.do_order_price_adjs table failed with Error: '
                || SQLERRM;
    END insert_price_adj_to_stage;
END xxdoec_salesorder_staging_pkg;
/
