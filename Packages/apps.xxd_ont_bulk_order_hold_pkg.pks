--
-- XXD_ONT_BULK_ORDER_HOLD_PKG  (Package) 
--
--  Dependencies: 
--   OE_HOLD_SOURCES_ALL (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BULK_ORDER_HOLD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORDER_HOLD_PKG
    * Design       : This package will be used to apply/release hold to restrict or control
    *                Bulk order closure by Workflow Background Process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 23-Feb-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE apply_release_hold (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_apply_release IN VARCHAR2
                                  , p_hold_id IN oe_hold_sources_all.hold_id%TYPE, p_release_reason_code IN VARCHAR2, p_release_comment IN VARCHAR2);
END xxd_ont_bulk_order_hold_pkg;
/
