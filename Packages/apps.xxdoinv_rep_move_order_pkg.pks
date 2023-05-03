--
-- XXDOINV_REP_MOVE_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV_REP_MOVE_ORDER_PKG"
AS
    /*
      REM $Header: XXDOINV_REP_MOVE_ORDER_PKG.PKS 1.0 23-Aug-2012 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM ===================================================================================================
      REM
      REM Name          : XXDOINV_REP_MOVE_ORDER_PKG.PKS
      REM
      REM Procedure     :
      REM Special Notes : Main Procedure called by Concurrent Manager
      REM
      REM Procedure     :
      REM Special Notes :
      REM
      REM         CR #  :
      REM ===================================================================================================
      REM History:  Creation Date :23-Aug-2012, Created by : Venkata Rama Battu, Sunera Technologies.
      REM
      REM Modification History
      REM Person                  Date              Version              Comments and changes made
      REM -------------------    ----------         ----------           ------------------------------------
      REM Venkata Rama Battu     23-Aug-2012         1.0                 1. Base lined for delivery
      REM Venkata Rama Battu     08-Aug-2012         1.1                 1. Updated the processing logic while inserting data  into stg table
      REM Venkata Rama Battu     19-Mar-2013         1.2                 1. Added organization Parameter for all DC's.
      REM Venkata Rama Battu     15-OCT-2013         1.3                 1. Added procedure Process_dc3_orders for DC3 Organization Gender Split Logic
      REM Venkata Rama Battu     10-JUN-2014         1.4                 Removed procedure Process_dc3_orders and changes in email output format
      REM ===================================================================================================
      */

    TYPE Order_Header_Rec_Type IS RECORD
    (
        ordered_item          VARCHAR2 (2000),
        inventory_item_id     NUMBER,
        ship_from_org_id      NUMBER,
        ORDER_QUANTITY_UOM    VARCHAR2 (10)
    );

    TYPE Order_header_Tbl_type IS TABLE OF Order_Header_Rec_Type
        INDEX BY BINARY_INTEGER;

    TYPE Order_Rec_Type IS RECORD
    (
        header_id             NUMBER,
        line_id               NUMBER,
        line_number           NUMBER,
        ordered_item          VARCHAR2 (2000),
        inventory_item_id     NUMBER,
        ordered_quantity      NUMBER,
        ship_from_org_id      NUMBER,
        order_quantity_uom    VARCHAR2 (10)
    );

    TYPE Order_Tbl_Type IS TABLE OF Order_Rec_Type
        INDEX BY BINARY_INTEGER;

    TYPE Order_Rec_Type1 IS RECORD
    (
        header_id             NUMBER,
        line_id               NUMBER,
        line_number           NUMBER,
        ordered_item          VARCHAR2 (2000),
        inventory_item_id     NUMBER,
        ordered_quantity      NUMBER,
        ship_from_org_id      NUMBER,
        order_quantity_uom    VARCHAR2 (10),
        mod_qty               NUMBER,
        flag                  VARCHAR2 (1)
    );

    TYPE Order_Tbl_Type1 IS TABLE OF Order_Rec_Type1
        INDEX BY BINARY_INTEGER;

    --TYPE item_info IS TABLE OF xxdo.xxdoe_lines_stg.inventory_item_id%TYPE;
    TYPE build_detail_Rec_Type IS RECORD
    (
        header_id             NUMBER,
        line_id               NUMBER,
        line_number           NUMBER,
        ordered_item          VARCHAR2 (2000),
        inventory_item_id     NUMBER,
        ordered_quantity      NUMBER,
        ship_from_org_id      NUMBER,
        order_quantity_uom    VARCHAR2 (10),
        required_qty          NUMBER,
        from_sub_inv          VARCHAR2 (50),
        to_sub_inv            VARCHAR2 (20),
        pair_pick_qty         NUMBER,
        case_pick_qty         NUMBER,
        qa_subinv_onhand      NUMBER,
        rcv_subinv_onhand     NUMBER,
        rtn_subinv_onhand     NUMBER,
        building_code         VARCHAR2 (50)
    );

    TYPE build_detail_table IS TABLE OF build_detail_Rec_Type
        INDEX BY BINARY_INTEGER;

    PROCEDURE MAIN_PROC (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_from_date IN VARCHAR2, p_to_date IN VARCHAR2, p_inv_org_id IN NUMBER, p_building IN VARCHAR2
                         , p_brand IN VARCHAR2);

    --  PROCEDURE  PROCESS_MOVE_ORDER ;
    PROCEDURE INSERT_ROWS;

    PROCEDURE print_report;

    --  PROCEDURE  CREATE_MOVE_ORDER  ( p_org_id    IN   NUMBER
    --                                 ,p_from_sub  IN   VARCHAR2
    --                                 ,p_to_sub    IN   VARCHAR2
    --                                 ,p_item_id   IN   NUMBER
    --                                 ,p_item_num  IN   VARCHAR2
    --                                 ,p_qty       IN   NUMBER
    --                                 ,p_uom_code  IN   VARCHAR2
    --                                 ,p_org_code  IN   VARCHAR2
    --                                 ,p_orders_tbl IN Order_Tbl_Type
    --                                );
    FUNCTION ATR_QTY (pn_item_id       IN NUMBER,
                      pn_org_id        IN NUMBER,
                      pv_subinv_code   IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION ATT_QTY (pn_item_id       IN NUMBER,
                      pn_org_id        IN NUMBER,
                      pv_subinv_code   IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION QTY_RESERVED (pn_header_id IN NUMBER, pn_line_id IN NUMBER, pv_order_qty_uom IN VARCHAR2
                           , pn_inv_item_id IN NUMBER)
        RETURN NUMBER;

    --  PROCEDURE UPDATE_PROCESSED_RECORDS(
    --                                   p_order_detail_tbl IN Order_Tbl_Type
    --                                  );



    PROCEDURE UPDATE_STG_TBL (p_item_id IN NUMBER, p_status_code IN VARCHAR2);

    PROCEDURE CREATE_MOVE_ORDER (p_org_id IN NUMBER, p_from_sub IN VARCHAR2, p_to_sub IN VARCHAR2, p_item_id IN NUMBER, p_item_num IN VARCHAR2, p_qty IN NUMBER, p_uom_code IN VARCHAR2, p_org_code IN VARCHAR2, p_orders_tbl IN Order_Tbl_Type1
                                 , p_move_tbl IN build_detail_table);

    PROCEDURE Process_orders;

    PROCEDURE UPDATE_STG_TBL (p_update_tbl    IN Order_Tbl_Type1,
                              p_status_code   IN VARCHAR2);

    PROCEDURE UPDATE_PROCESSED_RECORDS (p_order_detail_tbl IN Order_Tbl_Type1, p_sku_tbl IN build_detail_table);

    FUNCTION IID_TO_BRAND (pn_item_id   IN NUMBER,
                           pn_org_id    IN NUMBER DEFAULT 7)
        RETURN VARCHAR2;

    PROCEDURE email_error_report;
END XXDOINV_REP_MOVE_ORDER_PKG;
/
