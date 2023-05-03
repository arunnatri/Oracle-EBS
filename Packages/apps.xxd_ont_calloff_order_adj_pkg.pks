--
-- XXD_ONT_CALLOFF_ORDER_ADJ_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CALLOFF_ORDER_ADJ_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_ORDER_ADJ_PKG
    * Design       : This package will be used for processing Calloff Orders changes after
    *                linking with Bulk Orders
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 21-Nov-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/

    PROCEDURE calloff_order_line_change_prc (
        x_errbuf                OUT NOCOPY VARCHAR2,
        x_retcode               OUT NOCOPY VARCHAR2,
        p_org_id             IN            oe_order_headers_all.org_id%TYPE,
        p_line_change_type   IN            VARCHAR2);
END xxd_ont_calloff_order_adj_pkg;
/
