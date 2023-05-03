--
-- XXDOOM_BULK_PICK_ORDERS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOM_BULK_PICK_ORDERS_PKG"
AS
    /*
      REM $Header: XXDOOM_BULK_PICK_ORDERS_PKG.PKB 1.0 16-Aug-2012 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM ===================================================================================================
      REM
      REM Name          : XXDOOM_BULK_PICK_ORDERS_PKG.PKB
      REM
      REM Procedure     :
      REM Special Notes : Main Procedure called by Concurrent Manager
      REM
      REM Procedure     :
      REM Special Notes :
      REM
      REM         CR #  :
      REM ===================================================================================================
      REM History:  Creation Date :16-Aug-2012, Created by : Venkata Rama Battu, Sunera Technologies.
      REM
      REM Modification History
      REM Person                  Date              Version              Comments and changes made
      REM -------------------    ----------         ----------           ------------------------------------
      REM Venkata Rama Battu     16-Aug-2012         1.0                 1. Base lined for delivery
      REM
      REM ===================================================================================================
      */
    TYPE order_type IS RECORD
    (
        ln_header_id         NUMBER,
        ln_line_id           NUMBER,
        lv_ship_prio_code    VARCHAR2 (30),
        lv_ship_to_org_id    NUMBER
    );

    TYPE err_order_type IS RECORD
    (
        header_id      NUMBER,
        line_id        NUMBER,
        status_code    VARCHAR2 (1),
        status_msg     VARCHAR2 (2000)
    );

    TYPE order_tbl1 IS TABLE OF order_type
        INDEX BY BINARY_INTEGER;

    TYPE err_tbl1 IS TABLE OF err_order_type
        INDEX BY BINARY_INTEGER;

    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_cust_accout_id IN NUMBER, pv_from_date IN VARCHAR2, pv_to_date IN VARCHAR2, pv_organization_id IN NUMBER
                    , pv_cust_po IN VARCHAR2);

    PROCEDURE update_ship_priority;

    PROCEDURE INSERT_STG;

    PROCEDURE PROCESS_BP_ORDERS;

    PROCEDURE email_bptype;

    PROCEDURE SPLIT_DELIVERY_LINE (pn_header_id IN NUMBER, pn_line_id IN NUMBER, pn_item_id IN NUMBER, pn_bulk_qty IN NUMBER, pn_flow_qty IN NUMBER, pn_from_detail_id IN NUMBER
                                   , pn_new_detail_id OUT NUMBER, pv_status OUT VARCHAR2, pv_err_msg OUT VARCHAR2);

    FUNCTION QTY_RESERVED (pn_header_id IN NUMBER, pn_line_id IN NUMBER, pv_order_qty_uom IN VARCHAR2
                           , pn_inv_item_id IN NUMBER)
        RETURN NUMBER;
END XXDOOM_BULK_PICK_ORDERS_PKG;
/
