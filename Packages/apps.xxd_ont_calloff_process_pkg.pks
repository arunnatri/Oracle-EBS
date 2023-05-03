--
-- XXD_ONT_CALLOFF_PROCESS_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CALLOFF_PROCESS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_PROCESS_PKG
    * Design       : This package will be used for Calloff Orders Processing
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-May-2018  1.0        Viswanathan Pandian     Initial Version
    -- 02-Mar-2020  1.1        Viswanathan Pandian     Updated for CCR0008440
    ******************************************************************************************/
    PROCEDURE init;

    FUNCTION lock_order_line (p_line_id IN oe_order_lines_all.line_id%TYPE)
        RETURN VARCHAR2;

    PROCEDURE insert_data (p_calloff_header_id IN oe_order_headers_all.header_id%TYPE, p_calloff_line_id IN oe_order_lines_all.line_id%TYPE, p_bulk_header_id IN oe_order_headers_all.header_id%TYPE, p_bulk_line_id IN oe_order_lines_all.line_id%TYPE, p_linked_qty IN NUMBER, p_free_atp_cust IN VARCHAR2
                           ,                           -- Added for CCR0008440
                             p_cancel_qty IN NUMBER);

    PROCEDURE process_order (p_header_rec IN oe_order_pub.header_rec_type, p_line_tbl IN oe_order_pub.line_tbl_type, p_action_request_tbl IN oe_order_pub.request_tbl_type
                             , x_line_tbl OUT NOCOPY oe_order_pub.line_tbl_type, x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2);

    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_bulk_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_threads IN NUMBER
                          , p_debug IN VARCHAR2);

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_from_customer_batch_id IN NUMBER, p_to_customer_batch_id IN NUMBER, p_parent_request_id IN NUMBER, p_threads IN NUMBER
                         , p_debug IN VARCHAR2);

    -- Start changes for CCR0008440
    TYPE order_type_record IS RECORD
    (
        order_type_id    oe_order_headers_all.order_type_id%TYPE
    );

    TYPE order_type_table IS TABLE OF order_type_record;

    FUNCTION get_order_type_fnc (
        p_org_id IN oe_order_headers_all.org_id%TYPE)
        RETURN order_type_table
        PIPELINED;
-- End changes for CCR0008440
END xxd_ont_calloff_process_pkg;
/
