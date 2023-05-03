--
-- XXD_OM_ORDER_UPLOAD_X_PK1  (Package) 
--
--  Dependencies: 
--   FND_USER (Synonym)
--   OE_HEADERS_IFACE_ALL (Synonym)
--   OE_LINES_IFACE_ALL (Synonym)
--   OE_ORDER_SOURCES (Synonym)
--   OE_ORDER_TYPES_V (View)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_ORDER_UPLOAD_X_PK1"
AS
    /******************************************************************************************
    -- Modification History:
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 25-Feb-2015  1.0        BT Technology Team      Created for Order Upload WebADI
    ******************************************************************************************/
    --Global Variables
    --Public Subprograms
    /****************************************************************************************
    * Procedure    : ORDER_UPLOAD_PRC
    * Design       : This procedure inserts records into OE interface tables
    * Notes        : GT will hold the header sequence value for both interface tables
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 25-Feb-2015  1.0        BT Technology Team      Initial Version
    ****************************************************************************************/
    PROCEDURE order_upload_prc (
        p_order_source_id         IN oe_order_sources.order_source_id%TYPE,
        p_order_type              IN oe_order_types_v.name%TYPE,
        p_orig_sys_document_ref   IN oe_headers_iface_all.orig_sys_document_ref%TYPE,
        p_user_id                 IN fnd_user.user_id%TYPE,
        --      p_creation_date           IN oe_headers_iface_all.creation_date%TYPE, --Commented parameter
        p_request_date            IN oe_headers_iface_all.request_date%TYPE,
        p_operation_code          IN oe_headers_iface_all.operation_code%TYPE,
        p_booked_flag             IN oe_headers_iface_all.booked_flag%TYPE,
        p_customer_number         IN oe_headers_iface_all.customer_number%TYPE,
        p_customer_po_number      IN oe_headers_iface_all.customer_po_number%TYPE,
        p_price_list              IN oe_headers_iface_all.price_list%TYPE,
        p_ship_from_org           IN oe_headers_iface_all.ship_from_org%TYPE,
        p_ship_to_org             IN oe_headers_iface_all.ship_to_org%TYPE,
        p_invoice_to_org          IN oe_headers_iface_all.invoice_to_org%TYPE,
        p_cancel_date             IN DATE,
        p_brand                   IN oe_headers_iface_all.attribute5%TYPE,
        --      p_orig_sys_line_ref       IN oe_lines_iface_all.orig_sys_line_ref%TYPE, --Commented parameter
        p_inventory_item          IN oe_lines_iface_all.inventory_item%TYPE,
        p_ordered_quantity        IN oe_lines_iface_all.ordered_quantity%TYPE,
        p_line_request_date       IN oe_lines_iface_all.request_date%TYPE,
        p_unit_selling_price      IN oe_lines_iface_all.unit_selling_price%TYPE,
        p_subinventory            IN oe_lines_iface_all.subinventory%TYPE,
        --------------------------------------------------------------------
        -- Added By Sivakumar Boothathan For Adding Pricing Agreement,
        -- Shipping Instructions and Comments1 and 2
        --------------------------------------------------------------------
        p_ship_instructions       IN oe_headers_iface_all.shipping_instructions%TYPE,
        p_comments1               IN oe_headers_iface_all.attribute6%TYPE,
        p_comments2               IN oe_headers_iface_all.attribute7%TYPE,
        p_pricing_agreement       IN oe_headers_iface_all.agreement%TYPE,
        -------------------------------------------------------------
        -- End of chnage By Sivakuar Boothathan for adding more
        -- Input Parameters
        ---------------------------------------------------------------
        -------------------------------------------------------------------
        -- Added By Sivakumar Boothathan: 12/28 To add A. Sales Agreement Number
        -- to the Parameter when populated the sales agreement ID will be used
        --to release the order from that agreement.
        -------------------------------------------------------------------
        p_sa_number               IN oe_headers_iface_all.blanket_number%TYPE);

    -----------------------------------------
    -- End of changes By Sivakumar Boothathan
    -----------------------------------------

    /****************************************************************************************
    * Procedure    : RUN_ORDER_IMPORT_PRC
    * Design       : This procedure submits "Order Import" program
    * Notes        : This is called in WebADI import
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 25-Feb-2015  1.0        BT Technology Team      Initial Version
    ****************************************************************************************/
    PROCEDURE run_order_import_prc;
END xxd_om_order_upload_x_pk1;
/
