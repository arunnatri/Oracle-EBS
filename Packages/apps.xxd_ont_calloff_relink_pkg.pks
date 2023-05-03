--
-- XXD_ONT_CALLOFF_RELINK_PKG  (Package) 
--
--  Dependencies: 
--   HR_OPERATING_UNITS (View)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CALLOFF_RELINK_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_RELINK_PKG
    * Design       : This package will be used to make a calloff order eligible for
    *                reconsumption by applying a line level hold and reseting the status
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 15-Mar-2018  1.0        Viswanathan Pandian     Initial Version
    -- 02-Mar-2020  1.1        Viswanathan Pandian     Redesigned for CCR0008440
    *****************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    PROCEDURE master_prc (
        x_errbuf                 OUT NOCOPY VARCHAR2,
        x_retcode                OUT NOCOPY VARCHAR2,
        p_org_id                            hr_operating_units.organization_id%TYPE,
        p_cust_account_id     IN            oe_order_headers_all.sold_to_org_id%TYPE,
        p_cust_po_number      IN            oe_order_headers_all.cust_po_number%TYPE,
        p_order_number        IN            oe_order_headers_all.order_number%TYPE,
        p_order_type_id       IN            oe_order_headers_all.order_type_id%TYPE,
        p_request_date_from   IN            VARCHAR2,
        p_request_date_to     IN            VARCHAR2,
        p_threads             IN            NUMBER,
        p_purge_days          IN            NUMBER,
        p_debug_enable        IN            VARCHAR2);

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_parent_request_id IN NUMBER
                         , p_from_batch_id IN NUMBER, p_to_batch_id IN NUMBER, p_debug_enable IN VARCHAR2);
END xxd_ont_calloff_relink_pkg;
/
