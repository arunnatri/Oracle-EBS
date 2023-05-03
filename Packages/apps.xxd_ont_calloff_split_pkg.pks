--
-- XXD_ONT_CALLOFF_SPLIT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CALLOFF_SPLIT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_SPLIT_PKG
    * Design       : This package will be used for Calloff Order Split and Cancellation when
    *                there is no bulk to consume
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 25-Mar-2020  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE split_cancel_prc (
        x_errbuf                      OUT NOCOPY VARCHAR2,
        x_retcode                     OUT NOCOPY VARCHAR2,
        p_from_calloff_batch_id    IN            NUMBER,
        p_to_calloff_batch_id      IN            NUMBER,
        p_from_customer_batch_id   IN            NUMBER,
        p_to_customer_batch_id     IN            NUMBER,
        p_parent_request_id        IN            NUMBER,
        p_debug                    IN            VARCHAR2);
END xxd_ont_calloff_split_pkg;
/
