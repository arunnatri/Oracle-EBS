--
-- XXDOOM_MUSICAL_ORDERS_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   WMS_LICENSE_PLATE_NUMBERS (Synonym)
--   WSH_DELIVERY_DETAILS (Synonym)
--   STANDARD (Package)
--   MUSICAL_ORDER (Type)
--
/* Formatted on 4/26/2023 4:14:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOM_MUSICAL_ORDERS_PKG"
AS
    /*
      REM $Header: XXDOOM_MUSICAL_ORDERS_PKG.PKB 1.1 01-Dec-2012 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM ===================================================================================================
      REM
      REM Name          : XXDOOM_MUSICAL_ORDERS_PKG.PKB
      REM
      REM Procedure     :
      REM Special Notes : Main Procedure called by Concurrent Manager
      REM
      REM Procedure     :
      REM Special Notes :
      REM
      REM         CR #  :
      REM ===================================================================================================
      REM History:  Creation Date :01-Dec-2012, Created by : Venkata Rama Battu, Sunera Technologies.
      REM
      REM Modification History
      REM Person                  Date              Version              Comments and changes made
      REM -------------------    ----------         ----------           ------------------------------------
      REM Venkata Rama Battu     01-Dec-2012         1.0                 1. Base lined for delivery
      REM Venkata Rama Battu     07-APR-2013         1.1                 1. updated the code at int_cur Cursor to fix if SO has multiple lines for same item
      REM ===================================================================================================
      */

    TYPE order_table IS TABLE OF apps.oe_order_headers_all.order_number%TYPE
        INDEX BY BINARY_INTEGER;

    TYPE items_tbl IS TABLE OF VARCHAR2 (2000)
        INDEX BY BINARY_INTEGER;

    TYPE lpn_num_tbl
        IS TABLE OF apps.wms_license_plate_numbers.license_plate_number%TYPE
        INDEX BY BINARY_INTEGER;

    TYPE items_qty_rec IS RECORD
    (
        Item    VARCHAR2 (100),
        qty     NUMBER
    );

    TYPE int_rec
        IS RECORD
    (
        ordered_qty_uom      apps.oe_order_lines_all.order_quantity_uom%TYPE,
        source_line_id       apps.wsh_delivery_Details.source_line_id%TYPE,
        source_header_id     apps.wsh_delivery_details.source_header_id%TYPE,
        locator_id           apps.wsh_delivery_Details.locator_id%TYPE,
        inventory_item_id    apps.wsh_delivery_details.inventory_item_id%TYPE,
        organization_id      apps.wsh_delivery_details.organization_id%TYPE,
        subinventory         apps.wsh_delivery_details.subinventory%TYPE,
        lpn_id               apps.wsh_delivery_details.lpn_id%TYPE,
        lpn_number           apps.wsh_delivery_details.container_name%TYPE,
        ordered_item         apps.oe_order_lines_all.ordered_item%TYPE,
        quantity             apps.wsh_delivery_details.requested_quantity%TYPE,
        split_qty            apps.wsh_delivery_details.requested_quantity%TYPE
    );

    TYPE int_table IS TABLE OF int_rec
        INDEX BY BINARY_INTEGER;

    TYPE items_qty_tbl IS TABLE OF items_qty_rec
        INDEX BY BINARY_INTEGER;

    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pn_order_num IN NUMBER, pn_org_id IN NUMBER, pv_list_items IN VARCHAR2, pn_total_qty IN NUMBER
                    , pv_start_lpn IN VARCHAR2);

    PROCEDURE validate_so;

    PROCEDURE insert_intface;

    FUNCTION g_convert (pv_list IN VARCHAR2)
        RETURN XXDO.MUSICAL_ORDER;

    PROCEDURE CREATE_LPN (pv_lpn_number IN VARCHAR2, pv_sub_inv IN VARCHAR2, pn_loc_id IN NUMBER, pv_org_id IN NUMBER, pv_status OUT VARCHAR2, pn_lpn_id OUT NUMBER
                          , pv_err_msg OUT VARCHAR2);

    PROCEDURE launch_int_mgr;

    PROCEDURE err_report_intface;

    PROCEDURE display_report;

    PROCEDURE update_pattern;
END;
/
