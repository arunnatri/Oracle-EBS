--
-- XXD_OE_SALESREP_ASSN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OE_SALESREP_ASSN_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Tech Team
    -- Creation Date           : 27-NOV-2014
    -- Program Name            : XXD_OE_SALESREP_ASSN_PKG.pks
    -- Description             : Called from Attributing Defaulting to assign sales rep for orders
    -- Language                : PL/SQL
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 27-NOV-2014        1.0         BT Tech Team   Initial development.
    -- 29-NOV-2016        1.1         Mithun Mathew   Addition of Style and Color to salesrep matrix (CCR0005785).

    PROCEDURE ASSIGN_SALESREP (p_retcode                OUT NUMBER,
                               p_errbuff                OUT VARCHAR2,
                               p_order_number        IN     NUMBER,
                               p_request_date_low    IN     VARCHAR2,
                               p_request_date_high   IN     VARCHAR2);

    FUNCTION RET_HSALESREP (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION RET_LSALESREP (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE ASSIGN_SALESREP_HEADER (p_header_id IN NUMBER, p_org_id IN NUMBER, p_salesrep_id IN NUMBER);

    PROCEDURE APPLY_HOLD (pv_header_id IN NUMBER, pv_org_id IN NUMBER);

    PROCEDURE UPDATE_SALESREP (p_level IN VARCHAR2, p_header_id IN NUMBER, p_line_id IN NUMBER
                               , p_salesrep IN VARCHAR2);

    FUNCTION get_sales_rep (p_org_id IN NUMBER, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER, p_brand IN VARCHAR2, p_division IN VARCHAR2, p_department IN VARCHAR2, p_class IN VARCHAR2, p_sub_class IN VARCHAR2, p_style_number IN VARCHAR2 --CCR0005785
                            , p_color_code IN VARCHAR2            --CCR0005785
                                                      )
        RETURN NUMBER;
END XXD_OE_SALESREP_ASSN_PKG;
/
