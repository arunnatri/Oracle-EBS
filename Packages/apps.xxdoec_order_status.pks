--
-- XXDOEC_ORDER_STATUS  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   FND_USER (Synonym)
--   HZ_CONTACT_POINTS (Synonym)
--   HZ_CUST_ACCOUNTS (Synonym)
--   HZ_CUST_SITE_USES_ALL (Synonym)
--   HZ_LOCATIONS (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   OE_PRICE_ADJUSTMENTS (Synonym)
--   OE_REASONS (Synonym)
--   XXDOEC_OE_ORDER_STATUS_FRT_TAX (View)
--   XXDOEC_ORDER_MANUAL_REFUNDS (Synonym)
--   XXD_COMMON_ITEMS_V (View)
--   STANDARD (Package)
--   XXDOEC_INVENTORY (Table)
--   XXDOEC_ORDER_ATTRIBUTE (Table)
--   XXDOEC_RETURN_LINES_STAGING (Table)
--
/* Formatted on 4/26/2023 4:13:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_ORDER_STATUS"
AS
    g_error                                  BOOLEAN := FALSE;
    c_mindate_prepaid_order_type    CONSTANT DATE
        := TO_DATE ('09-SEP-2013', 'DD-MON-YYYY') ;
    c_prepaid_order_type_id         CONSTANT NUMBER := 12331;
    c_cancel_eligible_flow_status   CONSTANT VARCHAR2 (30) := 'BOOKED';

    TYPE order_header_list IS RECORD
    (
        order_number          oe_order_headers_all.orig_sys_document_ref%TYPE,
        local_id              hz_cust_accounts.attribute17%TYPE,
        ordered_date          oe_order_headers_all.ordered_date%TYPE,
        customer_number       hz_cust_accounts.account_number%TYPE,
        account_name          hz_cust_accounts.account_name%TYPE,
        total_order_amount    oe_order_lines_all.unit_selling_price%TYPE,
        order_status          oe_order_headers_all.flow_status_code%TYPE,
        -- model_number         mtl_system_items_b.segment1%TYPE,                --commented by BT Technology Team on 11/10/2014
        model_number          xxd_common_items_v.style_number%TYPE, --Added    by BT Technology Team on 11/10/2014
        -- color_code           mtl_system_items_b.segment2%TYPE,                --commented by BT Technology Team on 11/10/2014
        color_code            xxd_common_items_v.color_code%TYPE, --Added    by BT Technology Team on 11/10/2014
        -- product_size         mtl_system_items_b.segment3%TYPE,                --commented by BT Technology Team on 11/10/2014
        product_size          xxd_common_items_v.item_size%TYPE, --Added    by BT Technology Team on 11/10/2014
        -- product_name         mtl_system_items_b.description%TYPE,            --commented by BT Technology Team on 11/10/2014
        product_name          xxd_common_items_v.item_description%TYPE, --Added    by BT Technology Team on 11/10/2014
        ordered_quantity      oe_order_lines_all.ordered_quantity%TYPE,
        unit_selling_price    oe_order_lines_all.unit_selling_price%TYPE,
        subtotal              oe_order_lines_all.unit_selling_price%TYPE,
        line_status           oe_order_lines_all.flow_status_code%TYPE
    );

    TYPE order_detail
        IS RECORD
    (
        header_id                  oe_order_lines_all.header_id%TYPE,
        line_grp_id                oe_order_lines_all.attribute18%TYPE,
        line_id                    oe_order_lines_all.line_id%TYPE,
        order_number               oe_order_headers_all.orig_sys_document_ref%TYPE,
        ordered_date               oe_order_headers_all.ordered_date%TYPE,
        total_order_amount         oe_order_lines_all.unit_selling_price%TYPE,
        customer_number            hz_cust_accounts.account_number%TYPE,
        locale_id                  hz_cust_accounts.attribute17%TYPE,
        account_name               hz_cust_accounts.account_name%TYPE,
        email_address              VARCHAR2 (2000), --hz_parties.email_address
        site_id                    hz_cust_accounts.attribute18%TYPE,
        order_status               oe_order_headers_all.flow_status_code%TYPE,
        bill_to_address1           hz_locations.address1%TYPE,
        bill_to_address2           hz_locations.address2%TYPE,
        bill_to_city               hz_locations.city%TYPE,
        bill_to_state              hz_locations.state%TYPE,
        bill_to_postal_code        hz_locations.postal_code%TYPE,
        bill_to_country            hz_locations.country%TYPE,
        carrier                    VARCHAR2 (30),  --wsh_carriers.freight_code
        shipping_method            VARCHAR2 (80),  --fnd_lookup_values.meaning
        tracking_number            VARCHAR2 (2000),
        --wsh_delivery_details.tracking_number
        shipping_date              oe_order_lines_all.actual_shipment_date%TYPE,
        -- model_number         mtl_system_items_b.segment1%TYPE,                --commented by BT Technology Team on 11/10/2014
        model_number               xxd_common_items_v.style_number%TYPE, --Added    by BT Technology Team on 11/10/2014
        -- color_code           mtl_system_items_b.segment2%TYPE,                --commented by BT Technology Team on 11/10/2014
        color_code                 xxd_common_items_v.color_code%TYPE, --Added    by BT Technology Team on 11/10/2014
        -- product_size         mtl_system_items_b.segment3%TYPE,                --commented by BT Technology Team on 11/10/2014
        product_size               xxd_common_items_v.item_size%TYPE, --Added    by BT Technology Team on 11/10/2014
        fluid_recipe_id            oe_order_lines_all.customer_job%TYPE,
        -- product_name         mtl_system_items_b.description%TYPE,            --commented by BT Technology Team on 11/10/2014
        product_name               xxd_common_items_v.item_description%TYPE, --Added    by BT Technology Team on 11/10/2014
        inventory_item_id          oe_order_lines_all.inventory_item_id%TYPE,
        ordered_quantity           oe_order_lines_all.ordered_quantity%TYPE,
        shipped_quantity           oe_order_lines_all.shipped_quantity%TYPE,
        cancelled_quantity         oe_order_lines_all.cancelled_quantity%TYPE,
        unit_selling_price         oe_order_lines_all.unit_selling_price%TYPE,
        subtotal                   oe_order_lines_all.unit_selling_price%TYPE,
        taxamount                  oe_order_lines_all.tax_value%TYPE,
        line_status                oe_order_lines_all.flow_status_code%TYPE,
        currency                   oe_order_headers_all.transactional_curr_code%TYPE,
        returned_quantity          INT,
        discount_amount            oe_order_lines_all.unit_selling_price%TYPE,
        gift_wrap_total            apps.oe_price_adjustments.adjusted_amount%TYPE,
        refund_line_total          apps.xxdoec_order_manual_refunds.refund_unit_amount%TYPE,
        refund_order_total         apps.xxdoec_order_manual_refunds.refund_unit_amount%TYPE,
        shipping_total             NUMBER,
        shipping_discount          NUMBER,
        order_line_status          apps.fnd_lookup_values.meaning%TYPE,
        delivery_status            apps.fnd_lookup_values.meaning%TYPE,
        pg_line_status             apps.fnd_lookup_values.meaning%TYPE,
        org_id                     apps.oe_order_lines_all.org_id%TYPE,
        backorderdate              xxdo.xxdoec_inventory.pre_back_order_date%TYPE,
        reason_code                apps.oe_reasons.reason_code%TYPE,
        meaning                    apps.fnd_lookup_values.meaning%TYPE,
        user_name                  apps.fnd_user.user_name%TYPE,
        cancel_date                apps.oe_reasons.creation_date%TYPE,
        attribute18                VARCHAR2 (150),
        transactional_curr_code    VARCHAR2 (15),
        staged_return_quantity     NUMBER,
        return_processed           VARCHAR2 (3),
        return_type                VARCHAR (2),
        original_dw_order_id       VARCHAR2 (30),
        has_bling_applied          VARCHAR2 (3),
        bling_product_id           VARCHAR2 (50),
        bling_line_amount          NUMBER,
        eligible_to_cancel         NUMBER,
        ship_from_org_id           oe_order_lines_all.ship_from_org_id%TYPE, -- Modified on 16-SEP-2015
        is_closet_order            VARCHAR2 (5),
        is_final_sale_item         VARCHAR2 (5),
        cod_charge_total           NUMBER,
        invoice_number             VARCHAR2 (20),                -- CCR0008713
        tax_rate                   NUMBER,                       -- CCR0008713
        invoice_date               DATE                          -- CCR0008713
    );

    TYPE order_frttax
        IS RECORD
    (
        header_id               oe_order_headers_all.header_id%TYPE,
        freight_charge_total    xxdoec_oe_order_status_frt_tax.freight_charge_total%TYPE,
        tax_total_no_vat        xxdoec_oe_order_status_frt_tax.tax_total_no_vat%TYPE,
        vat_total               xxdoec_oe_order_status_frt_tax.vat_total%TYPE
    );

    TYPE order_address IS RECORD
    (
        site_use_code    hz_cust_site_uses_all.site_use_code%TYPE,
        address1         hz_locations.address1%TYPE,
        address2         hz_locations.address2%TYPE,
        city             hz_locations.city%TYPE,
        state            hz_locations.state%TYPE,
        postal_code      hz_locations.postal_code%TYPE,
        country          hz_locations.country%TYPE,
        NAME             hz_cust_site_uses_all.LOCATION%TYPE,
        phone            hz_contact_points.phone_number%TYPE,
        phone_number     hz_contact_points.phone_number%TYPE,
        line_id          oe_order_lines_all.line_id%TYPE,
        site_use_id      hz_cust_site_uses_all.site_use_id%TYPE
    );

    TYPE order_staging_lines
        IS RECORD
    (
        sku                    xxdo.xxdoec_return_lines_staging.sku%TYPE,
        upc                    xxdo.xxdoec_return_lines_staging.upc%TYPE,
        quantity               xxdo.xxdoec_return_lines_staging.quantity%TYPE,
        line_type              xxdo.xxdoec_return_lines_staging.line_type%TYPE,
        order_id               xxdo.xxdoec_return_lines_staging.order_id%TYPE,
        line_id                xxdo.xxdoec_return_lines_staging.line_id%TYPE,
        exchange_preference    NUMBER,
        return_reason          xxdo.xxdoec_return_lines_staging.return_reason%TYPE,
        ID                     NUMBER
    );

    TYPE order_attribute_detail IS RECORD
    (
        attribute_id       xxdo.xxdoec_order_attribute.attribute_id%TYPE,
        attribute_type     xxdo.xxdoec_order_attribute.attribute_id%TYPE,
        attribute_value    xxdo.xxdoec_order_attribute.attribute_value%TYPE,
        user_name          xxdo.xxdoec_order_attribute.user_name%TYPE,
        order_header_id    xxdo.xxdoec_order_attribute.order_header_id%TYPE,
        line_id            xxdo.xxdoec_order_attribute.line_id%TYPE,
        creation_date      xxdo.xxdoec_order_attribute.creation_date%TYPE
    );

    TYPE t_order_list_cursor IS REF CURSOR
        RETURN order_header_list;

    TYPE t_order_detail_cursor IS REF CURSOR
        RETURN order_detail;

    TYPE t_order_frttax_cursor IS REF CURSOR
        RETURN order_frttax;

    TYPE t_order_address_cursor IS REF CURSOR
        RETURN order_address;

    TYPE t_order_staging_lines_cursor IS REF CURSOR
        RETURN order_staging_lines;

    TYPE t_order_note_detail_cursor IS REF CURSOR
        RETURN order_attribute_detail;

    FUNCTION get_token (the_list    VARCHAR2,
                        the_index   NUMBER,
                        delim       VARCHAR2:= '-')
        RETURN VARCHAR2;

    PROCEDURE get_order_list (p_customer_number   IN     VARCHAR2,
                              o_orders               OUT t_order_list_cursor);

    PROCEDURE get_order_detail (p_order_number IN VARCHAR2, p_invoice_data_flag IN VARCHAR2, -- CCR0008713
                                                                                             p_invoice_data_OUs IN VARCHAR2, -- CCR0008713
                                                                                                                             o_order_detail OUT t_order_detail_cursor, o_order_frttax OUT t_order_frttax_cursor, o_order_address OUT t_order_address_cursor
                                , o_order_staging_lines OUT t_order_staging_lines_cursor, o_order_attribute_detail OUT t_order_note_detail_cursor);

    FUNCTION get_eligible_to_cancel (p_line_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_eligible_to_cancel_reason (p_line_id   IN     NUMBER,
                                            p_reason       OUT VARCHAR2)
        RETURN NUMBER;
/**************************************************************************************
Order status web service call for demandware
Author:  Mike Bacigalupi
Modifications:
                  Oksana Shenouda 07/13/2011
                  o_order_frttax cursor: swap joint on view xxdoec_oe_order_frt_tax_totals to new view xxdoec_oe_order_status_frt_tax

***************************************************************************************/
END xxdoec_order_status;
/
