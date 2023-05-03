--
-- XXD_ONT_BULK_CALLOFF_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BULK_CALLOFF_ORDER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_CALLOFF_ORDER_PKG
    * Design       : This package will be used for processing Calloff Orders
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 21-Nov-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE init;

    FUNCTION lock_order_line (p_line_id IN oe_order_lines_all.line_id%TYPE)
        RETURN VARCHAR2;

    PROCEDURE insert_data (
        p_calloff_header_rec   IN oe_order_pub.header_rec_type,
        p_calloff_line_rec     IN oe_order_pub.line_rec_type,
        p_bulk_header_id          oe_order_headers_all.header_id%TYPE,
        p_bulk_line_id            oe_order_lines_all.line_id%TYPE,
        p_link_type               VARCHAR2,
        p_linked_qty              NUMBER,
        p_free_atp_qty            NUMBER,
        p_status                  VARCHAR2,
        p_error_msg               VARCHAR2);

    PROCEDURE process_order (p_header_rec IN oe_order_pub.header_rec_type, p_line_tbl IN oe_order_pub.line_tbl_type, p_action_request_tbl IN oe_order_pub.request_tbl_type
                             , x_line_tbl OUT NOCOPY oe_order_pub.line_tbl_type, x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2);

    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE
                          , p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_consumption IN oe_order_lines_all.global_attribute19%TYPE, p_threads IN NUMBER);

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_consumption IN oe_order_lines_all.global_attribute19%TYPE, p_threads IN NUMBER
                         , p_run_id IN NUMBER);
END xxd_ont_bulk_calloff_order_pkg;
/
