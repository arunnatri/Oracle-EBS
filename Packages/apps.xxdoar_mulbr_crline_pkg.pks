--
-- XXDOAR_MULBR_CRLINE_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoar_mulbr_crline_pkg
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 25-MAY-2011
    -- File Name               : XXDOAR015.pks
    -- Work Order Num          : Multi Brand Credit line Process
    --                                      Incident INC0089941
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 25-MAY-2011        1.0         Vijaya Reddy         Initial development.
    --
    -------------------------------------------------------------------------------
    ---------------------------
    -- Declare Input Parameters
    ---------------------------
    --pn_org_id             NUMBER;
    --pn_cust_id            NUMBER;
    --pv_requestor          VARCHAR2(50);
    --------------------
    -- GLOBAL VARIABLES
    --------------------
    gv_error_position   VARCHAR2 (3000);

    TYPE order_rec_type IS RECORD
    (
        header_id    apps.oe_order_headers_all.header_id%TYPE,
        line_id      apps.oe_order_lines_all.line_id%TYPE
    );

    TYPE order_tbl_type IS TABLE OF order_rec_type
        INDEX BY BINARY_INTEGER;

    PROCEDURE get_brand_exposure (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id NUMBER
                                  , pn_cust_id NUMBER);

    PROCEDURE get_bexp_cust_crlmt (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pn_credit_limit NUMBER);

    PROCEDURE get_bexp_openrel_ordamt (pv_customer_number      VARCHAR2,
                                       pv_customer_name        VARCHAR2,
                                       pv_brand                VARCHAR2,
                                       pn_open_rel_order_amt   NUMBER,
                                       pn_org_id               NUMBER);

    PROCEDURE get_bexp_salord_hold (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pv_brand VARCHAR2
                                    , pn_sales_order_num NUMBER, pn_sales_order_value NUMBER, pn_org_id NUMBER);

    PROCEDURE get_overdue_brand (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id NUMBER
                                 , pn_cust_id NUMBER);

    PROCEDURE get_overb_cust_crlmt (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pn_credit_limit NUMBER);

    PROCEDURE get_overdue_check_agg (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id IN NUMBER
                                     , pn_cust_id IN NUMBER);

    PROCEDURE get_overca_cust_crlmt (pv_customer_number VARCHAR2, pv_customer_name VARCHAR2, pn_credit_limit NUMBER);
END xxdoar_mulbr_crline_pkg;
/
