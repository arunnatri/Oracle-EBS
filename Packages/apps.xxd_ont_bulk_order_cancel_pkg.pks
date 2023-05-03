--
-- XXD_ONT_BULK_ORDER_CANCEL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BULK_ORDER_CANCEL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORDER_CANCEL_PKG
    * Design       : This package will be used for Bulk Order Cancellation
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-May-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE cancel_prc (x_errbuf                      OUT NOCOPY VARCHAR2,
                          x_retcode                     OUT NOCOPY VARCHAR2,
                          p_from_bulk_batch_id       IN            NUMBER,
                          p_to_bulk_batch_id         IN            NUMBER,
                          p_from_customer_batch_id   IN            NUMBER,
                          p_to_customer_batch_id     IN            NUMBER,
                          p_parent_request_id        IN            NUMBER,
                          p_debug                    IN            VARCHAR2);
END xxd_ont_bulk_order_cancel_pkg;
/
