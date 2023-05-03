--
-- XXD_ONT_MULTI_ORDER_UPLOAD_PKG  (Package) 
--
--  Dependencies: 
--   FND_APPLICATION (Synonym)
--   FND_GLOBAL (Package)
--   FND_USER (Synonym)
--   HZ_CUST_ACCOUNTS (Synonym)
--   HZ_CUST_SITE_USES_ALL (Synonym)
--   MTL_CUSTOMER_ITEMS (Synonym)
--   MTL_PARAMETERS (Synonym)
--   MTL_SECONDARY_INVENTORIES (Synonym)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_AGREEMENTS_TL (Synonym)
--   OE_BLANKET_HEADERS_ALL (Synonym)
--   OE_HEADERS_IFACE_ALL (Synonym)
--   OE_LINES_IFACE_ALL (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   OE_ORDER_SOURCES (Synonym)
--   OE_TRANSACTION_TYPES_TL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_MULTI_ORDER_UPLOAD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_MULTI_ORDER_UPLOAD_PKG
    * Design       : This package is used for Multi Sales Order WebADI upload
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 16-May-2017  1.0        Viswanathan Pandian     Initial Version
    -- 11-Dec-2017  1.1        Viswanathan Pandian     Modified for CCR0006653
    -- 11-Jan-2019  1.2        Viswanathan Pandian     Modified for CCR0007557
    -- 07-Apr-2019  1.3        Viswanathan Pandian     Modified for CCR0007844
    -- 14-Mar-2022  1.4        Viswanathan Pandian     Modified for CCR0009886
    ******************************************************************************************/
    gn_org_id            oe_order_headers_all.org_id%TYPE DEFAULT fnd_global.org_id;
    gn_user_id           fnd_user.user_id%TYPE DEFAULT fnd_global.user_id;
    gn_order_source_id   oe_order_sources.order_source_id%TYPE;
    gn_application_id    fnd_application.application_id%TYPE;

    PROCEDURE validate_prc (
        p_header_request_date     oe_order_headers_all.request_date%TYPE,
        -- Start changes for CCR0007557
        -- p_price_list               qp_list_headers_v.name%TYPE,
        p_return_reason_code      oe_headers_iface_all.return_reason_code%TYPE,
        -- End changes for CCR0007557
        p_warehouse               mtl_parameters.organization_code%TYPE,
        p_subinventory            mtl_secondary_inventories.secondary_inventory_name%TYPE,
        p_header_cancel_date      oe_order_headers_all.request_date%TYPE,
        p_order_type              oe_transaction_types_tl.name%TYPE,
        p_book_order              VARCHAR2,
        p_brand                   oe_order_headers_all.attribute5%TYPE,
        p_customer_number         hz_cust_accounts.account_number%TYPE,
        p_ship_to_location        hz_cust_site_uses_all.location%TYPE,
        p_bill_to_location        hz_cust_site_uses_all.location%TYPE,
        p_deliver_to_location     hz_cust_site_uses_all.location%TYPE,
        p_cust_po_number          oe_order_headers_all.cust_po_number%TYPE,
        p_packing_instructions    oe_order_headers_all.packing_instructions%TYPE, -- Added for CCR0007844
        p_shipping_instructions   oe_order_headers_all.shipping_instructions%TYPE,
        p_comments1               oe_order_headers_all.attribute6%TYPE,
        p_comments2               oe_order_headers_all.attribute7%TYPE,
        p_pricing_agreement       oe_agreements_tl.name%TYPE,
        p_sales_agreement         oe_blanket_headers_all.order_number%TYPE,
        p_customer_item           mtl_customer_items.customer_item_number%TYPE,
        p_inventory_item          mtl_system_items_b.segment1%TYPE,
        p_ordered_qty             oe_order_lines_all.ordered_quantity%TYPE,
        p_line_request_date       oe_order_lines_all.request_date%TYPE,
        p_line_cancel_date        oe_order_lines_all.request_date%TYPE,
        p_unit_selling_price      oe_order_lines_all.unit_selling_price%TYPE,
        -- Start changes for CCR0007844
        p_additional_column1      VARCHAR2,
        p_additional_column2      VARCHAR2,
        p_additional_column3      VARCHAR2,
        p_additional_column4      VARCHAR2,
        p_additional_column5      VARCHAR2,
        p_additional_column6      VARCHAR2,
        p_additional_column7      VARCHAR2,
        p_additional_column8      VARCHAR2,
        p_additional_column9      VARCHAR2,
        p_additional_column10     VARCHAR2);     -- End changes for CCR0007844

    PROCEDURE import_data_prc;

    -- Start changes for CCR0006653
    PROCEDURE pre_validation_prc (p_errbuf IN OUT VARCHAR2, p_retcode IN OUT VARCHAR2, p_orig_sys_document_ref IN oe_lines_iface_all.orig_sys_document_ref%TYPE
                                  , p_user_id IN fnd_user.user_id%TYPE); -- Added for CCR0009886
-- End changes for CCR0006653
END xxd_ont_multi_order_upload_pkg;
/
