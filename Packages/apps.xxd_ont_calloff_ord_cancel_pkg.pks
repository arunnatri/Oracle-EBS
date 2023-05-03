--
-- XXD_ONT_CALLOFF_ORD_CANCEL_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CALLOFF_ORD_CANCEL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_ORD_CANCEL_PKG
    * Design       : This package will be used for processing Calloff Orders cancellations
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 03-Dec-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/

    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE
                          , p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_threads IN NUMBER, p_debug IN VARCHAR2);

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_from_customer_batch_id IN NUMBER, p_to_customer_batch_id IN NUMBER, p_parent_request_id IN NUMBER, p_threads IN NUMBER
                         , p_debug IN VARCHAR2);

    PROCEDURE calloff_order_cancel_prc (
        x_errbuf                      OUT NOCOPY VARCHAR2,
        x_retcode                     OUT NOCOPY VARCHAR2,
        p_from_bulk_batch_id       IN            NUMBER,
        p_to_bulk_batch_id         IN            NUMBER,
        p_from_customer_batch_id   IN            NUMBER,
        p_to_customer_batch_id     IN            NUMBER,
        p_parent_request_id        IN            NUMBER,
        p_debug                    IN            VARCHAR2);
END xxd_ont_calloff_ord_cancel_pkg;
/
