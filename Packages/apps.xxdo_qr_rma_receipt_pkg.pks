--
-- XXDO_QR_RMA_RECEIPT_PKG  (Package) 
--
--  Dependencies: 
--   HZ_CUST_SITE_USES_ALL (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_TRANSACTION_TYPES_ALL (Synonym)
--   ORG_ORGANIZATION_DEFINITIONS (View)
--   RA_CUSTOMERS (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_QR_RMA_RECEIPT_PKG"
AS
    /*
    REM $Header: XXDO_QR_RMA_RECEIPT_PKG.PKS 1.0 17-JUL-2013 $
    REM ===================================================================================================
    REM (c) Copyright Deckers Outdoor Corporation
    REM All Rights Reserved
    REM ===================================================================================================
    REM
    REM Name : XXDO_QR_RMA_RECEIPT_PKG.PKS
    REM
    REM Procedure :
    REM Special Notes : Main Procedure called by Concurrent Manager
    REM
    REM Procedure :
    REM Special Notes :
    REM
    REM CR # :
    REM ===================================================================================================
    REM History: Creation Date :17-JUL-2013, Created by : Venkata Rama Battu, Sunera Technologies.
    REM
    REM Modification History
    REM Person Date Version Comments and changes made
    REM ------------------- ---------- ---------- ------------------------------------
    REM Venkata Rama Battu 17-JUL-2013 1.0 1. Base lined for delivery
    REM Siva R             06-May-2015 1.1    Fixed the bugs reported in CCR#CCR0004847
    REM
    REM ===================================================================================================
    */
    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_mode IN VARCHAR2, pv_dummy1 IN VARCHAR2, pv_rma_header_id IN NUMBER, pv_dummy2 IN VARCHAR2
                    , pn_organization_id IN NUMBER);

    PROCEDURE process_qa_results (pn_rma_id IN NUMBER, pn_org_id IN NUMBER);

    PROCEDURE error_rec_rcv_interface;

    PROCEDURE submit_rtp;

    PROCEDURE success_report;

    PROCEDURE insert_into_rti (p_rma_id    IN     NUMBER,
                               p_org_id    IN     NUMBER,
                               p_rec_cnt      OUT NUMBER);


    FUNCTION get_locator (p_value IN VARCHAR2, p_org_id IN NUMBER)
        RETURN VARCHAR2;

    -- TYPE s_rec IS RECORD (
    -- rma_num VARCHAR2 (50),
    -- rec_org VARCHAR2 (10),
    -- item VARCHAR2 (100),
    -- qty VARCHAR2 (100),
    -- serial_num VARCHAR2 (100),
    -- qr_rec_id VARCHAR2 (100)
    --
    -- -- ,flag VARCHAR2(100)
    -- );

    -- TYPE s_tbl1 IS TABLE OF s_rec
    -- INDEX BY BINARY_INTEGER;

    TYPE cust_info
        IS RECORD
    (
        customer_name          apps.ra_customers.customer_name%TYPE,
        customer_number        apps.ra_customers.customer_number%TYPE,
        customer_id            apps.ra_customers.customer_id%TYPE,
        order_category_code    apps.oe_transaction_types_all.order_category_code%TYPE,
        brand                  apps.oe_order_headers_all.attribute5%TYPE,
        organization_code      apps.org_organization_definitions.organization_code%TYPE,
        cust_acct_site_id      apps.hz_cust_site_uses_all.cust_acct_site_id%TYPE
    );

    TYPE order_items IS RECORD
    (
        line_id         apps.oe_order_lines_all.line_id%TYPE,
        ordered_item    apps.oe_order_lines_all.ordered_item%TYPE,
        item_id         apps.oe_order_lines_all.inventory_item_id%TYPE,
        quantity        apps.oe_order_lines_all.ordered_quantity%TYPE
    );

    TYPE rma_item_list IS TABLE OF order_items
        INDEX BY BINARY_INTEGER;

    TYPE succ_summ_rep IS RECORD
    (
        rma_num        NUMBER,
        sku            VARCHAR2 (200),
        rma_hdr_id     NUMBER,
        rma_line_id    NUMBER,
        qty            NUMBER,
        subinv         VARCHAR2 (100),
        locator        VARCHAR2 (100),
        flag           VARCHAR2 (1),
        locator_id     NUMBER,
        uom_code       VARCHAR2 (20)
    );

    TYPE s_summary_rep IS TABLE OF succ_summ_rep
        INDEX BY BINARY_INTEGER;

    TYPE subinv_rec IS RECORD
    (
        trx_iface_id       NUMBER,
        item_id            NUMBER,
        organization_id    NUMBER,
        subinv_code        VARCHAR2 (100),
        from_loc_id        NUMBER,
        trx_qty            NUMBER,
        trx_uom            VARCHAR2 (50),
        trx_subinv         VARCHAR2 (100),
        to_loc_id          NUMBER,
        src_line_id        NUMBER,
        src_hdr_id         NUMBER,
        flag               VARCHAR2 (1),
        serial_num         VARCHAR2 (50)
    );

    TYPE subinve_tbl IS TABLE OF subinv_rec
        INDEX BY BINARY_INTEGER;

    PROCEDURE insert_serial_num (p_rma_id    IN NUMBER,
                                 p_line_id   IN VARCHAR2,
                                 p_item_id   IN NUMBER -- ,p_status OUT VARCHAR2
                                                      );

    PROCEDURE launch_int_mgr;

    PROCEDURE subinve_transfer;

    PROCEDURE subinve_report;

    PROCEDURE subinve_transfer_error_report;

    FUNCTION get_rma_num (pn_rma_hdr_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_rma_line_num (pn_rma_line_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_loc (pn_loc_id IN NUMBER, pn_org_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_org_code (pn_org_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION GET_COLUMN (pv_code IN VARCHAR2)
        RETURN VARCHAR2;

    --FUNCTION GET_COLUMN_VAL(pv_col_name IN VARCHAR2
    -- ,pn_rma_id IN NUMBER
    -- ,pv_coll_id IN NUMBER
    -- ,pv_occ_id IN NUMBER
    -- ,pn_line_id IN NUMBER
    -- ,pn_item_id IN NUMBER
    -- )
    --RETURN VARCHAR2;
    PROCEDURE debug_tbl (p_rma_id   IN NUMBER,
                         p_desc     IN VARCHAR2,
                         p_comm     IN VARCHAR2);

    PROCEDURE purge_debug_tbl;
END;
/
