--
-- XXDOOM_MUSICAL_ORDERS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM_MUSICAL_ORDERS_PKG"
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
      REM
      REM ===================================================================================================
      */
    gn_order_num          NUMBER;
    gv_list_items         VARCHAR2 (2000);
    gn_total_qty          NUMBER;
    gn_created_by         NUMBER := apps.fnd_global.user_id;
    gn_request_id         NUMBER := apps.fnd_global.conc_request_id;
    g_items_tbl           XXDO.musical_order;
    g_items_qty_tbl       items_qty_tbl;
    gn_err_cnt            NUMBER := 0;
    gv_err_msg            VARCHAR2 (2000) := NULL;
    gn_tot_pairs          NUMBER;
    gv_start_lpn          VARCHAR2 (100);
    gv_next_lpn           VARCHAR2 (100);
    gn_resp_id            NUMBER := apps.fnd_profile.VALUE ('RESP_ID');
    gn_appl_id            NUMBER := apps.fnd_profile.VALUE ('RESP_APPL_ID');
    gn_lpn_tbl            lpn_num_tbl;
    g_int_table           int_table;
    gn_locator_id         NUMBER;
    gn_org_id             NUMBER;
    gn_lpn_id             NUMBER;
    gn_ship_from_org_id   NUMBER;
    gn_list_qty           NUMBER;
    gn_order_tot_qty      NUMBER;
    gn_int_retcode        NUMBER;

    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pn_order_num IN NUMBER, pn_org_id IN NUMBER, pv_list_items IN VARCHAR2, pn_total_qty IN NUMBER
                    , pv_start_lpn IN VARCHAR2)
    IS
    BEGIN
        gn_order_num          := pn_order_num;
        gv_list_items         := pv_list_items;
        gn_total_qty          := pn_total_qty;
        gv_start_lpn          := pv_start_lpn;
        gv_next_lpn           := pv_start_lpn;
        gn_ship_from_org_id   := pn_org_id;

        validate_so;
        insert_intface;
        launch_int_mgr;
        err_report_intface;
        update_pattern;

        IF gn_int_retcode = 0
        THEN
            display_report;
        END IF;

        IF gn_err_cnt > 0
        THEN
            retcode   := 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Error Occured in Main Procedure');
    END;

    PROCEDURE validate_so
    IS
        ln_err_cnt           NUMBER := 0;
        lv_err_msg           VARCHAR2 (2000);
        ln_order_cnt         NUMBER := 0;
        ln_item_cnt          NUMBER := 0;
        ln_tot_item_cnt      NUMBER := 0;
        ln_list_item_qty     NUMBER := 0;
        ln_lpn_cnt           NUMBER := 0;
        lv_single_lpn        VARCHAR2 (100);
        ln_single_lpn_id     NUMBER;
        ln_locator_id        NUMBER;
        ln_organization_id   NUMBER;
        ln_lpn_id            NUMBER;
        ln_int_cnt           NUMBER := 0;
        ln_mul_lpn_cnt       NUMBER := 0;
        ln_mod_value         NUMBER := 0;
        ln_lpn_num_val       NUMBER := NULL;


        CURSOR int_cur (cp_item VARCHAR2)
        IS
              SELECT DISTINCT oola.ORDER_QUANTITY_UOM, MAX (wdd2.SOURCE_LINE_ID) SOURCE_LINE_ID --Updated by Battu on 07-Mar-2013 to fix SO has multiple lines of same item musical orders not able to split
                                                                                               , wdd2.SOURCE_HEADER_ID,
                              wdd2.LOCATOR_ID, wdd2.INVENTORY_ITEM_ID, wdd2.ORGANIZATION_ID,
                              wdd.SUBINVENTORY, wdd.LPN_ID, wdd.container_name lpn,
                              oola.ordered_item, SUM (wdd2.REQUESTED_QUANTITY) LPN_QTY
                FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                     apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                     apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
               WHERE     wdd.container_name = wlpn.license_plate_number
                     AND wdd.source_code = 'WSH'
                     AND wdd.container_flag = 'Y'
                     AND wda2.parent_delivery_detail_id =
                         wdd.delivery_detail_id
                     AND wnd2.delivery_id = wda2.delivery_id
                     AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                     AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                     AND wcsm2.enabled_flag(+) = 'Y'
                     AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                     AND oola.line_id = wdd2.source_line_id
                     AND ooha.header_id = oola.header_id
                     AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                     AND wdd.LPN_ID = ln_single_lpn_id
                     AND oola.ordered_item = cp_item
            GROUP BY oola.ORDER_QUANTITY_UOM-- ,wdd2.SOURCE_LINE_ID   --Commented by Battu on 07-Mar-2013 to fix SO has multiple lines of same item musical orders not able to split
                                            , wdd2.SOURCE_HEADER_ID, wdd2.LOCATOR_ID,
                     wdd2.INVENTORY_ITEM_ID, wdd2.ORGANIZATION_ID, wdd.LPN_ID,
                     wdd.container_name, oola.ordered_item, wdd.SUBINVENTORY;
    BEGIN
        gn_err_cnt    := 0;
        gv_err_msg    := NULL;

        g_items_tbl   := g_convert (gv_list_items);

        BEGIN
            FOR i IN g_items_tbl.FIRST .. g_items_tbl.LAST
            LOOP
                g_items_qty_tbl (i).item   :=
                    TRIM (
                        UPPER (
                            TO_CHAR (
                                (TRIM (SUBSTR (g_items_tbl (i), 1, INSTR (g_items_tbl (i), '=') - 1))))));
                g_items_qty_tbl (i).qty   :=
                    TRIM (
                        SUBSTR (g_items_tbl (i),
                                INSTR (g_items_tbl (i), '=', 1) + 1));
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_err_cnt   := ln_err_cnt + 1;
                lv_err_msg   :=
                       lv_err_msg
                    || ' '
                    || 'Error occured while segregating item and quantity';
        END;


        /*===============================================================================================================
             **********************Validating LPN Number Have Onle Numeric values***************************
          =============================================================================================================*/
        BEGIN
            ln_lpn_num_val   :=
                LENGTH (
                    TRIM (TRANSLATE (gv_start_lpn, ' +-.0123456789', ' ')));

            IF ln_lpn_num_val IS NOT NULL
            THEN
                ln_err_cnt   := ln_err_cnt + 1;
                lv_err_msg   :=
                       lv_err_msg
                    || ' '
                    || 'LPN Number Should not contain Characters';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_err_cnt   := ln_err_cnt + 1;
                lv_err_msg   :=
                       lv_err_msg
                    || ' '
                    || 'Error Occured while validating LPN Number has Characters';
        END;


        /*==================================================================================================================
               ---------------------------validating SO is EXIST or NOT ---------------------------------------------
         =================================================================================================================*/

        BEGIN
            SELECT COUNT (1)
              INTO ln_order_cnt
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.order_number = gn_order_num
                   AND ooh.header_id = ool.header_id
                   AND ool.ship_from_org_id = gn_ship_from_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_order_cnt   := 0;
                lv_err_msg     :=
                       lv_err_msg
                    || ' '
                    || 'error occured while validating order Number';
        END;

        IF ln_order_cnt <> 0
        THEN
            ln_err_cnt   := 0;
        ELSE
            ln_err_cnt   := ln_err_cnt + 1;
            lv_err_msg   :=
                   lv_err_msg
                || ' '
                || 'Order Number not exist in the provided shipping organization ';
        END IF;


        /*=================================================================================================================
                         ***********Validating Entered Item Quantity Can not be zero***************
           ================================================================================================================*/
        IF ln_err_cnt = 0
        THEN
            FOR i IN g_items_qty_tbl.FIRST .. g_items_qty_tbl.LAST
            LOOP
                IF TO_NUMBER (g_items_qty_tbl (i).qty) = 0
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'Item#'
                        || g_items_qty_tbl (i).item
                        || 'Quantity can not be ZERO';
                END IF;
            END LOOP;
        END IF;

        /* =============================================================================================================
            -----------------Validating Items exist in Sales order or not -----------------------------------
          ===========================================================================================================*/
        IF ln_err_cnt = 0
        THEN
            -- ln_item_loop_cnt:=g_items_qty_tbl.LAST;
            FOR i IN g_items_qty_tbl.FIRST .. g_items_qty_tbl.LAST
            LOOP
                ln_item_cnt   := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_item_cnt
                      FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
                     WHERE     ooh.header_id = ool.header_id
                           AND ool.ordered_item =
                               UPPER (g_items_qty_tbl (i).item)
                           AND ooh.order_number = gn_order_num;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_item_cnt   := 0;
                END;

                IF ln_item_cnt = 0
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || ' '
                        || 'Item:-'
                        || g_items_qty_tbl (i).item
                        || ' '
                        || 'Item Does not exist in Order Number';
                ELSE
                    ln_tot_item_cnt   := ln_tot_item_cnt + ln_item_cnt;
                    ln_list_item_qty   :=
                        ln_list_item_qty + g_items_qty_tbl (i).qty;
                END IF;
            END LOOP;
        END IF;


        /*==========================================================================================================
            ---------Validating items total quantity and pakcing item quantity are equal or not ----------------
          ==========================================================================================================*/
        BEGIN
            gn_list_qty    := ln_list_item_qty;
            ln_mod_value   := MOD (gn_total_qty, ln_list_item_qty);

            IF ln_mod_value = 0
            THEN
                gn_tot_pairs   := FLOOR (gn_total_qty / ln_list_item_qty);
            ELSE
                ln_err_cnt   := ln_err_cnt + 1;
                lv_err_msg   :=
                       lv_err_msg
                    || ' '
                    || 'items quantity and total quantity are not mathced please check the total quantity';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_err_cnt   := ln_err_cnt + 1;
                lv_err_msg   :=
                       lv_err_msg
                    || ' '
                    || 'Error occured while calculating total pairs';
        END;

        /*===========================================================================================================
            --------------Validating No of LPN hava the sales order ----------------------------------------
          ==========================================================================================================*/
        gn_err_cnt    := gn_err_cnt + ln_err_cnt; --Assingn the error cnt to global vairable
        gv_err_msg    := gv_err_msg || ' ' || lv_err_msg;

        BEGIN
            ln_lpn_cnt   := 0;

            SELECT COUNT (DISTINCT wdd.container_name)
              INTO ln_lpn_cnt
              FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                   apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                   apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     wdd.container_name = wlpn.license_plate_number
                   AND wdd.source_code = 'WSH'
                   AND wdd.container_flag = 'Y'
                   AND wda2.parent_delivery_detail_id =
                       wdd.delivery_detail_id
                   AND wnd2.delivery_id = wda2.delivery_id
                   AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                   AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                   AND wcsm2.enabled_flag(+) = 'Y'
                   AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                   AND oola.line_id = wdd2.source_line_id
                   AND ooha.header_id = oola.header_id
                   AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                   AND ooha.order_number = gn_order_num
                   AND wdd2.SUBINVENTORY = 'STAGE';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_lpn_cnt   := 0;
                ln_err_cnt   := ln_err_cnt + 1;
                lv_err_msg   :=
                       lv_err_msg
                    || ' '
                    || 'Error Occured while getting the LPN Count-'
                    || SQLERRM;
        END;

        gn_err_cnt    := gn_err_cnt + ln_err_cnt; --Assingn the error cnt to global vairable
        gv_err_msg    := gv_err_msg || ' ' || lv_err_msg;

        IF ln_lpn_cnt = 1 AND ln_err_cnt = 0
        THEN
            /*==============================================================================================================
                 ---------------------SO# has single LPN Number then fetch the LPN NUMBER --------------------------
              ==============================================================================================================*/
            BEGIN
                SELECT DISTINCT wdd.container_name, wdd.LPN_ID, wdd.locator_id,
                                wdd.organization_id
                  INTO lv_single_lpn, ln_single_lpn_id, ln_locator_id, ln_organization_id
                  FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                       apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                       apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                 WHERE     wdd.container_name = wlpn.license_plate_number
                       AND wdd.source_code = 'WSH'
                       AND wdd.container_flag = 'Y'
                       AND wda2.parent_delivery_detail_id =
                           wdd.delivery_detail_id
                       AND wnd2.delivery_id = wda2.delivery_id
                       AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                       AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                       AND wcsm2.enabled_flag(+) = 'Y'
                       AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                       AND oola.line_id = wdd2.source_line_id
                       AND ooha.header_id = oola.header_id
                       AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                       AND ooha.order_number = gn_order_num
                       AND wdd2.SUBINVENTORY = 'STAGE';
            EXCEPTION
                WHEN OTHERS
                THEN
                    -- ln_lpn_cnt:=0;
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || ' '
                        || 'Error Occured while getting the LPN Number,LPN_ID,Locator_id,organization_id-'
                        || SQLERRM;
            END;

            IF ln_err_cnt = 0
            THEN
                gn_locator_id   := ln_locator_id;
                gn_org_id       := ln_organization_id;
                gn_lpn_id       := ln_single_lpn_id;


                UPDATE apps.wsh_Delivery_details wdd
                   SET attribute4   = lv_single_lpn
                 WHERE wdd.delivery_detail_id IN
                           (SELECT DISTINCT wdd2.DELIVERY_DETAIL_ID
                              FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                                   apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                                   apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                             WHERE     wdd.container_name =
                                       wlpn.license_plate_number
                                   AND wdd.source_code = 'WSH'
                                   AND wdd.container_flag = 'Y'
                                   AND wda2.parent_delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND wnd2.delivery_id = wda2.delivery_id
                                   AND wdd2.delivery_detail_id =
                                       wda2.delivery_detail_id
                                   AND wcsm2.ship_method_code(+) =
                                       wdd2.ship_method_code
                                   AND wcsm2.enabled_flag(+) = 'Y'
                                   AND wcsm2.organization_id(+) =
                                       wdd2.organization_id -- in (7, wdd2.organization_id)
                                   AND oola.line_id = wdd2.source_line_id
                                   AND ooha.header_id = oola.header_id
                                   AND oola.FLOW_STATUS_CODE =
                                       'AWAITING_SHIPPING'
                                   AND ooha.order_number = gn_order_num
                                   AND wdd2.SUBINVENTORY = 'STAGE');


                COMMIT;


                FOR i IN g_items_qty_tbl.FIRST .. g_items_qty_tbl.LAST
                LOOP
                    BEGIN
                        FOR j IN int_cur (g_items_qty_tbl (i).Item)
                        LOOP
                            g_int_table (ln_int_cnt).ordered_qty_uom   :=
                                j.ORDER_QUANTITY_UOM;
                            g_int_table (ln_int_cnt).source_line_id   :=
                                j.SOURCE_LINE_ID;
                            g_int_table (ln_int_cnt).source_header_id   :=
                                j.SOURCE_HEADER_ID;
                            g_int_table (ln_int_cnt).locator_id   :=
                                j.LOCATOR_ID;
                            g_int_table (ln_int_cnt).inventory_item_id   :=
                                j.INVENTORY_ITEM_ID;
                            g_int_table (ln_int_cnt).organization_id   :=
                                j.ORGANIZATION_ID;
                            g_int_table (ln_int_cnt).subinventory   :=
                                j.SUBINVENTORY;
                            g_int_table (ln_int_cnt).lpn_id       := j.LPN_ID;
                            g_int_table (ln_int_cnt).lpn_number   := j.lpn;
                            g_int_table (ln_int_cnt).ordered_item   :=
                                j.ordered_item;
                            g_int_table (ln_int_cnt).quantity     :=
                                j.lpn_qty;
                            g_int_table (ln_int_cnt).split_qty    :=
                                g_items_qty_tbl (i).qty;
                        /*  apps.fnd_file.put_line(apps.fnd_file.LOG,
                                                               g_int_table(ln_int_cnt).ordered_qty_uom   ||'-'||
                                                               g_int_table(ln_int_cnt).source_line_id    ||'-'||
                                                               g_int_table(ln_int_cnt).source_header_id  ||'-'||
                                                               g_int_table(ln_int_cnt).locator_id        ||'-'||
                                                               g_int_table(ln_int_cnt).inventory_item_id ||'-'||
                                                               g_int_table(ln_int_cnt).organization_id   ||'-'||
                                                               g_int_table(ln_int_cnt).subinventory      ||'-'||
                                                               g_int_table(ln_int_cnt).lpn_id            ||'-'||
                                                               g_int_table(ln_int_cnt).lpn_number        ||'-'||
                                                               g_int_table(ln_int_cnt).ordered_item      ||'-'||
                                                               g_int_table(ln_int_cnt).quantity          ||'-'||
                                                               g_int_table(ln_int_cnt).split_qty
                                              ); */
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt   := ln_err_cnt + 1;
                            lv_err_msg   :=
                                   lv_err_msg
                                || ' '
                                || 'Error Occured while assigning line details to table type-'
                                || SQLERRM;
                    END;

                    ln_int_cnt   := ln_int_cnt + 1;
                END LOOP;
            END IF;                                       -- IF ln_err_cnt = 0

            --ELSE
            gn_err_cnt   := ln_err_cnt;
            gv_err_msg   := lv_err_msg;
        ELSE                               -- IF LPN COUNT is Greater than one
            BEGIN
                SELECT COUNT (DISTINCT wdd.container_name)
                  INTO ln_mul_lpn_cnt
                  FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                       apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                       apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                 WHERE     wdd.container_name = wlpn.license_plate_number
                       AND wdd.source_code = 'WSH'
                       AND wdd.container_flag = 'Y'
                       AND wda2.parent_delivery_detail_id =
                           wdd.delivery_detail_id
                       AND wnd2.delivery_id = wda2.delivery_id
                       AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                       AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                       AND wcsm2.enabled_flag(+) = 'Y'
                       AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                       AND oola.line_id = wdd2.source_line_id
                       AND ooha.header_id = oola.header_id
                       AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                       AND ooha.order_number = gn_order_num
                       AND wdd2.SUBINVENTORY = 'STAGE'
                       AND wdd.CONTAINER_NAME = wdd2.ATTRIBUTE4;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_mul_lpn_cnt   := 0;
                    ln_err_cnt       := ln_err_cnt + 1;
                    lv_err_msg       :=
                           lv_err_msg
                        || ' '
                        || 'Error Occured while getting the partially processed order LPN Count-'
                        || SQLERRM;
            END;

            IF ln_mul_lpn_cnt = 1
            THEN
                BEGIN
                    SELECT DISTINCT wdd.container_name, wdd.LPN_ID, wdd.locator_id,
                                    wdd.organization_id
                      INTO lv_single_lpn, ln_single_lpn_id, ln_locator_id, ln_organization_id
                      FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                           apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                           apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                     WHERE     wdd.container_name = wlpn.license_plate_number
                           AND wdd.source_code = 'WSH'
                           AND wdd.container_flag = 'Y'
                           AND wda2.parent_delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wnd2.delivery_id = wda2.delivery_id
                           AND wdd2.delivery_detail_id =
                               wda2.delivery_detail_id
                           AND wcsm2.ship_method_code(+) =
                               wdd2.ship_method_code
                           AND wcsm2.enabled_flag(+) = 'Y'
                           AND wcsm2.organization_id(+) =
                               wdd2.organization_id -- in (7, wdd2.organization_id)
                           AND oola.line_id = wdd2.source_line_id
                           AND ooha.header_id = oola.header_id
                           AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                           AND ooha.order_number = gn_order_num
                           AND wdd2.SUBINVENTORY = 'STAGE'
                           AND wdd.CONTAINER_NAME = wdd2.ATTRIBUTE4;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        -- ln_lpn_cnt:=0;
                        ln_err_cnt   := ln_err_cnt + 1;
                        lv_err_msg   :=
                               lv_err_msg
                            || ' '
                            || 'Error Occured while getting Partially process  LPN Number,LPN_ID,Locator_id,organization_id-'
                            || SQLERRM;
                END;

                IF ln_err_cnt = 0
                THEN
                    gn_locator_id   := ln_locator_id;
                    gn_org_id       := ln_organization_id;
                    gn_lpn_id       := ln_single_lpn_id;

                    FOR i IN g_items_qty_tbl.FIRST .. g_items_qty_tbl.LAST
                    LOOP
                        BEGIN
                            FOR j IN int_cur (g_items_qty_tbl (i).Item)
                            LOOP
                                g_int_table (ln_int_cnt).ordered_qty_uom   :=
                                    j.ORDER_QUANTITY_UOM;
                                g_int_table (ln_int_cnt).source_line_id   :=
                                    j.SOURCE_LINE_ID;
                                g_int_table (ln_int_cnt).source_header_id   :=
                                    j.SOURCE_HEADER_ID;
                                g_int_table (ln_int_cnt).locator_id   :=
                                    j.LOCATOR_ID;
                                g_int_table (ln_int_cnt).inventory_item_id   :=
                                    j.INVENTORY_ITEM_ID;
                                g_int_table (ln_int_cnt).organization_id   :=
                                    j.ORGANIZATION_ID;
                                g_int_table (ln_int_cnt).subinventory   :=
                                    j.SUBINVENTORY;
                                g_int_table (ln_int_cnt).lpn_id   := j.LPN_ID;
                                g_int_table (ln_int_cnt).lpn_number   :=
                                    j.lpn;
                                g_int_table (ln_int_cnt).ordered_item   :=
                                    j.ordered_item;
                                g_int_table (ln_int_cnt).quantity   :=
                                    j.lpn_qty;
                                g_int_table (ln_int_cnt).split_qty   :=
                                    g_items_qty_tbl (i).qty;
                            /* apps.fnd_file.put_line(apps.fnd_file.LOG,
                                                                  g_int_table(ln_int_cnt).ordered_qty_uom   ||'-'||
                                                                  g_int_table(ln_int_cnt).source_line_id    ||'-'||
                                                                  g_int_table(ln_int_cnt).source_header_id  ||'-'||
                                                                  g_int_table(ln_int_cnt).locator_id        ||'-'||
                                                                  g_int_table(ln_int_cnt).inventory_item_id ||'-'||
                                                                  g_int_table(ln_int_cnt).organization_id   ||'-'||
                                                                  g_int_table(ln_int_cnt).subinventory      ||'-'||
                                                                  g_int_table(ln_int_cnt).lpn_id            ||'-'||
                                                                  g_int_table(ln_int_cnt).lpn_number        ||'-'||
                                                                  g_int_table(ln_int_cnt).ordered_item      ||'-'||
                                                                  g_int_table(ln_int_cnt).quantity          ||'-'||
                                                                  g_int_table(ln_int_cnt).split_qty
                                                 );  */
                            END LOOP;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_err_cnt   := ln_err_cnt + 1;
                                lv_err_msg   :=
                                       lv_err_msg
                                    || ' '
                                    || 'Error Occured while assigning line details to table type-'
                                    || SQLERRM;
                        END;

                        ln_int_cnt   := ln_int_cnt + 1;
                    END LOOP;
                END IF;
            ELSE
                gn_err_cnt   := gn_err_cnt + ln_err_cnt + 1;
                gv_err_msg   :=
                       gv_err_msg
                    || ' '
                    || lv_err_msg
                    || ' '
                    || 'SO has multiple LPNs';
            END IF;
        END IF;                                            -- IF ln_lpn_cnt =1

        gn_err_cnt    := gn_err_cnt + ln_err_cnt;
        gv_err_msg    := gv_err_msg || ' ' || lv_err_msg;
    EXCEPTION
        WHEN OTHERS
        THEN
            gn_err_cnt   := gn_err_cnt + 1;
            gv_err_msg   :=
                gv_err_msg || ' ' || 'Error occured in validation Procedure';
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error Occured in validation Procedure' || ' ' || SQLERRM);
    END;                                                        -- validate_so

    PROCEDURE insert_intface
    IS
        ld_trx_date        DATE := SYSDATE;
        lv_source_code     VARCHAR2 (30) := 'Musical Split';
        ln_process_flag    NUMBER := 1;
        ln_trx_mode        NUMBER := 2;
        ln_lock_flag       NUMBER := 2;
        ln_trx_type        NUMBER := 89;
        ln_trx_header_id   NUMBER := gn_request_id;
        lv_status          VARCHAR2 (3);
        lv_lpn_err         VARCHAR2 (200);
        ln_lpn_tbl_cnt     NUMBER := 0;
        ln_loc_type_id     NUMBER := 0;
        ln_items_tot_qty   NUMBER := 0;
    BEGIN
        /*==================================================================================================================================
            ----------validating item ordered quantity should be greate or equal to sum of split quantity ---------------
         ==================================================================================================================================*/
        BEGIN
            FOR i IN g_int_table.FIRST .. g_int_table.LAST
            LOOP
                IF (g_int_table (i).split_qty * gn_tot_pairs) >
                   g_int_table (i).quantity
                THEN
                    gn_err_cnt   := gn_err_cnt + 1;
                    gv_err_msg   :=
                           gv_err_msg
                        || ' '
                        || 'Item#'
                        || g_int_table (i).ordered_item
                        || ' '
                        || 'Quantity is less than the total split quantity';
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_err_cnt   := gn_err_cnt + 1;
                gv_err_msg   :=
                       gv_err_msg
                    || ' '
                    || 'Error validating total quantity and split quantity -Pleae check any quantity can not be zero';
        END;


        /*=============================================================================
           *****Calculating SO# Total quantity before processing********************
          ============================================================================*/
        BEGIN
            FOR i IN g_int_table.FIRST .. g_int_table.LAST
            LOOP
                gn_order_tot_qty   :=
                    gn_order_tot_qty + g_int_table (i).quantity;
            END LOOP;
        /* IF ln_items_tot_qty <> gn_total_qty
            THEN
                gn_err_cnt:=gn_err_cnt+1;
                gv_err_msg:= gv_err_msg||' '||'Items total Quantity is not equal to provided total quantity';
            END IF;  */
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_err_cnt   := gn_err_cnt + 1;
                gv_err_msg   :=
                       gv_err_msg
                    || ' '
                    || 'Error Calculating total quantity of SO#';
        END;

        COMMIT;

        /*==============================================================================================================
            --------------------Validating locator is stage line locator or not-----------------------------------------
          ============================================================================================================*/
        BEGIN
            SELECT mil.inventory_location_type
              INTO ln_loc_type_id
              FROM apps.mtl_item_locations mil
             WHERE     mil.inventory_location_id = gn_locator_id
                   AND mil.organization_id = gn_org_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_loc_type_id   := 0;
            WHEN OTHERS
            THEN
                ln_loc_type_id   := 0;
        END;

        IF ln_loc_type_id NOT IN (2, 3)
        THEN
            gn_err_cnt   := gn_err_cnt + 1;
            gv_err_msg   :=
                gv_err_msg || ' ' || 'Locator is not the Stage Lane Locator';
        END IF;

        /*=======================================================================================================================
                   ------------------------- Creating the LPN --------------------------------------------------------
            ======================================================================================================================*/

        IF gn_err_cnt = 0
        THEN
            BEGIN
                FOR i IN 1 .. gn_tot_pairs
                LOOP
                    CREATE_LPN (pv_lpn_number => gv_next_lpn, pv_sub_inv => 'STAGE', pn_loc_id => gn_locator_id, pv_org_id => gn_org_id, pv_status => lv_status, pn_lpn_id => gn_lpn_id
                                , pv_err_msg => lv_lpn_err);

                    IF lv_status = 'S'
                    THEN
                        gn_lpn_tbl (ln_lpn_tbl_cnt)   := gn_lpn_id;
                        ln_lpn_tbl_cnt                := ln_lpn_tbl_cnt + 1;
                    ELSE
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   := gv_err_msg || '  ' || lv_lpn_err;
                    END IF;

                    gv_next_lpn   :=
                        TO_CHAR (
                            LPAD (gv_next_lpn + 1, LENGTH (gv_start_lpn), 0));
                END LOOP;

                IF gn_tot_pairs <> gn_lpn_tbl.COUNT
                THEN
                    ROLLBACK;
                ELSE
                    COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Error occured in Create LPN Procedure');
            END;
        END IF;


        IF gn_err_cnt = 0
        THEN
            FOR i IN gn_lpn_tbl.FIRST .. gn_lpn_tbl.LAST
            LOOP
                FOR j IN g_int_table.FIRST .. g_int_table.LAST
                LOOP
                    INSERT INTO apps.mtl_transactions_interface (
                                    transaction_header_id,
                                    transaction_uom,
                                    transaction_date,
                                    source_code,
                                    source_line_id,
                                    source_header_id,
                                    process_flag,
                                    transaction_mode,
                                    lock_flag,
                                    locator_id,
                                    last_update_date,
                                    last_updated_by,
                                    creation_date,
                                    created_by,
                                    inventory_item_id,
                                    subinventory_code,
                                    organization_id,
                                    transaction_quantity,
                                    --primary_quantity ,
                                    transaction_type_id,
                                    lpn_id,
                                    TRANSFER_LPN_ID)
                             VALUES (ln_trx_header_id,
                                     g_int_table (j).ordered_qty_uom, -- transaction uom
                                     ld_trx_date,          -- transaction date
                                     lv_source_code,            -- source code
                                     g_int_table (j).source_line_id, -- source line id
                                     g_int_table (j).source_header_id, -- source header id
                                     ln_process_flag,          -- process flag
                                     ln_trx_mode,          -- transaction mode
                                     ln_lock_flag,                -- lock flag
                                     g_int_table (j).locator_id, -- locator id
                                     ld_trx_date,          -- last update date
                                     gn_created_by,         -- last updated by
                                     ld_trx_date,             -- creation date
                                     gn_created_by,              -- created by
                                     g_int_table (j).inventory_item_id, -- inventory item id
                                     g_int_table (j).subinventory, -- From subinventory code
                                     g_int_table (j).organization_id, -- organization id
                                     g_int_table (j).split_qty, -- transaction quantity
                                     ln_trx_type,       -- transaction type id
                                     g_int_table (j).lpn_id,       -- From_lpn
                                     gn_lpn_tbl (i)                  -- To_lpn
                                                   );
                /*apps.fnd_file.put_line(apps.fnd_file.LOG,g_int_table(j).ordered_qty_uom||'-'||ld_trx_date||'-'||'Container Split'||'-'||g_int_table(j).source_line_id||'-'||
                                       g_int_table(j).source_header_id||'-'||ln_process_flag||'-'||ln_trx_mode||'-'||ln_lock_flag||'-'||g_int_table(j).locator_id||'-'||
                                       ld_trx_date||'-'||gn_created_by||'-'||ld_trx_date||'-'||gn_created_by||'-'||g_int_table(j).inventory_item_id||'-'||g_int_table(j).subinventory
                                       ||'-'||g_int_table(j).organization_id||'-'||g_int_table(j).split_qty||'-'||ln_trx_type||'-'||g_int_table(j).lpn_id||'-'|| gn_lpn_tbl(i)); */
                END LOOP;
            END LOOP;

            COMMIT;
        END IF;

        /*======================================================================================================
                **************Displaying Error Count and Error Message In Log File******************************
          =====================================================================================================*/
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '**************Displaying Error Count and Error Message ******************** ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '|' || RPAD ('-', 25, '-') || '|' || RPAD ('-', 200, '-') || '|');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('No Of Validation Errors', 25, ' ')
            || '|'
            || RPAD ('Error Message', 200, ' ')
            || '|');

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '|' || RPAD ('-', 25, '-') || '|' || RPAD ('-', 200, '-') || '|');

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD (NVL (NVL (gn_err_cnt, 0), 0), 25, ' ')
            || '|'
            || RPAD (NVL (gv_err_msg, ' '), 200, ' ')
            || '|');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '|' || RPAD ('-', 25, '-') || '|' || RPAD ('-', 200, '-') || '|');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured while inserting records into mtl_transactions_interface table'
                || SQLERRM);
    END;                                                     -- insert_intface


    FUNCTION g_convert (pv_list IN VARCHAR2)
        RETURN XXDO.MUSICAL_ORDER
    AS
        lv_string        VARCHAR2 (32767) := pv_list || ',';
        ln_comma_index   PLS_INTEGER;
        ln_index         PLS_INTEGER := 1;
        l_tab            XXDO.MUSICAL_ORDER := XXDO.MUSICAL_ORDER ();
    BEGIN
        LOOP
            ln_comma_index        := INSTR (lv_string, ',', ln_index);
            EXIT WHEN ln_comma_index = 0;
            l_tab.EXTEND;
            l_tab (l_tab.COUNT)   :=
                SUBSTR (lv_string, ln_index, ln_comma_index - ln_index);
            ln_index              := ln_comma_index + 1;
        END LOOP;

        RETURN l_tab;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error occured while converting the comma seperated to table type');
            RETURN NULL;
    END g_convert;

    PROCEDURE CREATE_LPN (pv_lpn_number IN VARCHAR2, pv_sub_inv IN VARCHAR2, pn_loc_id IN NUMBER, pv_org_id IN NUMBER, pv_status OUT VARCHAR2, pn_lpn_id OUT NUMBER
                          , pv_err_msg OUT VARCHAR2)
    IS
        ln_api_version       NUMBER := 1.0;
        lv_return_status     VARCHAR2 (10);
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_lpn_id            NUMBER := 0;
        ln_organization_id   NUMBER := pv_org_id;
        ln_inv_item_id       NUMBER;
        lv_sub_inventory     VARCHAR2 (100) := pv_sub_inv;
        ln_inv_locator_id    NUMBER := pn_loc_id;      -- sanuk --303654 test;
        ln_serial_number     NUMBER := NULL;
        ln_lot_number        NUMBER;
        xn_lpn_id            NUMBER;
        v_msg_data           VARCHAR2 (2000);
        lv_err_msg           VARCHAR2 (2000);
        lv_source            NUMBER := 11;                            --PICKED
    BEGIN
        /* ===========================================================================================
                  Validating LPN Number exist or not in WMS License Plate Number table
           ==========================================================================================*/

        BEGIN
            SELECT wlp.lpn_id
              INTO lv_lpn_id
              FROM apps.wms_license_plate_numbers wlp
             WHERE     wlp.license_plate_number = pv_lpn_number
                   AND wlp.organization_id = ln_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_lpn_id   := 0;
        END;

        IF lv_lpn_id = 0
        THEN
            apps.FND_GLOBAL.APPS_INITIALIZE (gn_created_by,
                                             gn_resp_id,
                                             gn_appl_id);
            apps.wms_container_pub.Create_LPN (p_api_version => ln_api_version, x_return_status => lv_return_status, x_msg_count => ln_msg_count, x_msg_data => lv_msg_data, p_lpn => pv_lpn_number, p_organization_id => ln_organization_id, p_container_item_id => ln_inv_item_id, --v_inventory_item_id,
                                                                                                                                                                                                                                                                                     p_subinventory => lv_sub_inventory, p_source => lv_source, p_locator_id => ln_inv_locator_id, p_serial_number => ln_serial_number, p_lot_number => ln_lot_number
                                               , x_lpn_id => xn_lpn_id);

            IF lv_return_status = apps.fnd_api.g_ret_sts_success
            THEN
                pv_status   := 'S';
                pn_lpn_id   := xn_lpn_id;
            ELSE
                ROLLBACK;
                apps.fnd_msg_pub.count_and_get (p_count     => ln_msg_count,
                                                p_data      => lv_msg_data,
                                                p_encoded   => 'F');

                IF (ln_msg_count = 1)
                THEN
                    pv_err_msg   := lv_msg_data;
                ELSIF (ln_msg_count > 1)
                THEN
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lv_msg_data   := apps.fnd_msg_pub.get (i, 'F');
                    END LOOP;

                    pv_err_msg   := lv_msg_data;
                END IF;
            END IF;
        ELSE
            -- apps.fnd_file.put_line(apps.fnd_file.LOG,'LPN#:'||pv_lpn_number|| ' -Already exist');
            pv_err_msg   :=
                'LPN Number:-' || pv_lpn_number || '   Already exist';
        END IF;                                           -- end of lv_lpn_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured while create_lpn Procedure and error message is-'
                || SQLERRM);
    END;                                           --end of create API package

    PROCEDURE launch_int_mgr
    IS
        l_return_status           VARCHAR2 (10);
        l_msg_count               NUMBER;
        l_msg_data                VARCHAR2 (2000);
        l_trans_count             NUMBER;
        l_transaction_header_id   NUMBER := gn_request_id;
    BEGIN
        gn_int_retcode   :=
            apps.INV_TXN_MANAGER_PUB.process_transactions (
                p_api_version     => 1.0,
                p_init_msg_list   => apps.fnd_api.g_true,
                x_return_status   => l_return_status,
                x_msg_count       => l_msg_count,
                x_msg_data        => l_msg_data,
                x_trans_count     => l_trans_count,
                p_header_id       => l_transaction_header_id);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Return status is:-#' || gn_int_retcode);
    END;                                                      --launch_int_mgr

    /*========================================================================================================================================
       *******************************Procedure to disply error records In Interface table***********************************
       ====================================================================================================================================*/


    PROCEDURE err_report_intface
    IS
        CURSOR err_cur IS
            SELECT mti.source_line_id, mti.source_header_id, mti.INVENTORY_ITEM_ID,
                   mti.organization_id, mti.subinventory_code, mti.locator_id,
                   mti.TRANSACTION_QUANTITY, mti.LPN_ID, mti.TRANSFER_LPN_ID,
                   mti.ERROR_CODE, mti.ERROR_EXPLANATION
              FROM apps.mtl_transactions_interface mti
             WHERE     mti.TRANSACTION_HEADER_ID = gn_request_id
                   AND mti.PROCESS_FLAG = 3;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 240, '-')
            || '|'
            || RPAD ('-', 240, '-')
            || '|'--     ,gn_rtn_val
                  );
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('Source Header Id', 15, ' ')
            || '|'
            || RPAD ('Source Line Id', 15, ' ')
            || '|'
            || RPAD ('Inventory Item Id', 15, ' ')
            || '|'
            || RPAD ('Organization_id', 12, ' ')
            || '|'
            || RPAD ('Subinventory', 12, ' ')
            || '|'
            || RPAD ('Locator Id', 10, ' ')
            || '|'
            || RPAD ('Transaction Qty', 20, ' ')
            || '|'
            || RPAD ('LPN Id', 15, ' ')
            || '|'
            || RPAD ('Transafer LPN Id', 15, ' ')
            || '|'
            || RPAD ('Error Code', 240, ' ')
            || '|'
            || RPAD ('Error Explanation ', 240, ' ')
            || '|'--     ,gn_rtn_val
                  );

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 240, '-')
            || '|'
            || RPAD ('-', 240, '-')
            || '|'--     ,gn_rtn_val
                  );

        FOR i IN err_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD (NVL (NVL (i.source_header_id, 0), 0), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.source_line_id, 0), 0), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.inventory_item_id, 0), 0), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.organization_id, 0), 0), 12, ' ')
                || '|'
                || RPAD (NVL (i.subinventory_code, ' '), 12, ' ')
                || '|'
                || RPAD (NVL (NVL (i.locator_id, 0), 0), 10, ' ')
                || '|'
                || RPAD (NVL (NVL (i.Transaction_quantity, 0), 0), 20, ' ')
                || '|'
                || RPAD (NVL (NVL (i.lpn_id, 0), 0), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.transfer_lpn_id, 0), 0), 15, ' ')
                || '|'
                || RPAD (NVL (i.ERROR_CODE, ' '), 240, ' ')
                || '|'
                || RPAD (NVL (i.error_explanation, ' '), 240, ' ')
                || '|'--    ,gn_rtn_val
                      );
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 12, '-')
                || '|'
                || RPAD ('-', 12, '-')
                || '|'
                || RPAD ('-', 10, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 240, '-')
                || '|'
                || RPAD ('-', 240, '-')
                || '|'--     ,gn_rtn_val
                      );
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error occured in interface error report disply procedure');
    END;

    PROCEDURE display_report
    IS
        lv_items_list      VARCHAR2 (4000);
        lv_qty_list        VARCHAR2 (4000);
        lv_process_items   VARCHAR2 (4000);
        lv_process_qty     VARCHAR2 (4000);
        ln_order_tot_qty   NUMBER;


        CURSOR pattern_cur IS
              SELECT DISTINCT SUBSTR (wdd2.attribute5,
                                      1,
                                        INSTR (wdd2.attribute5, '-', 1,
                                               1)
                                      - 1) Pattern,
                              SUBSTR (wdd2.attribute5,
                                        INSTR (wdd2.attribute5, '-', 1,
                                               1)
                                      + 1,
                                        INSTR (wdd2.attribute5, '-', 1,
                                               2)
                                      - (  INSTR (wdd2.attribute5, '-', 1,
                                                  1)
                                         + 1)) Total_Qty,
                              SUBSTR (wdd2.attribute5,
                                        INSTR (wdd2.attribute5, '-', 1,
                                               2)
                                      + 1,
                                        INSTR (wdd2.attribute5, '-', 1,
                                               3)
                                      - INSTR (wdd2.attribute5, '-', 1,
                                               2)
                                      - 1) Cases,
                              SUBSTR (wdd2.attribute5,
                                        INSTR (wdd2.attribute5, '-', -1,
                                               1)
                                      + 1) Qty_for_Case
                FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                     apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                     apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
               WHERE     wdd.container_name = wlpn.license_plate_number
                     AND wdd.source_code = 'WSH'
                     AND wdd.container_flag = 'Y'
                     AND wda2.parent_delivery_detail_id =
                         wdd.delivery_detail_id
                     AND wnd2.delivery_id = wda2.delivery_id
                     AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                     AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                     AND wcsm2.enabled_flag(+) = 'Y'
                     AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                     AND oola.line_id = wdd2.source_line_id
                     AND ooha.header_id = oola.header_id
                     AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                     AND ooha.order_number = gn_order_num
                     AND wdd2.SUBINVENTORY = 'STAGE'
                     AND wdd.CONTAINER_NAME <> wdd2.ATTRIBUTE4
            ORDER BY pattern DESC;

        CURSOR item_cur (cp_pattern VARCHAR2)
        IS
              SELECT DISTINCT oola.ordered_item, SUM (wdd2.REQUESTED_QUANTITY) LPN_QTY
                FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                     apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                     apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
               WHERE     wdd.container_name = wlpn.license_plate_number
                     AND wdd.source_code = 'WSH'
                     AND wdd.container_flag = 'Y'
                     AND wda2.parent_delivery_detail_id =
                         wdd.delivery_detail_id
                     AND wnd2.delivery_id = wda2.delivery_id
                     AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                     AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                     AND wcsm2.enabled_flag(+) = 'Y'
                     AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                     AND oola.line_id = wdd2.source_line_id
                     AND ooha.header_id = oola.header_id
                     AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                     AND ooha.order_number = gn_order_num
                     AND SUBSTR (wdd2.attribute5,
                                 1,
                                 (  INSTR (wdd2.attribute5, '-', 1,
                                           1)
                                  - 1)) = cp_pattern
                     AND wdd2.SUBINVENTORY = 'STAGE'
                     AND wdd.CONTAINER_NAME <> wdd2.ATTRIBUTE4
            GROUP BY oola.ordered_item, wdd.container_name;


        CURSOR avail_qty_cur IS
              SELECT DISTINCT oola.ordered_item, SUM (wdd2.REQUESTED_QUANTITY) LPN_QTY
                FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                     apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                     apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
               WHERE     wdd.container_name = wlpn.license_plate_number
                     AND wdd.source_code = 'WSH'
                     AND wdd.container_flag = 'Y'
                     AND wda2.parent_delivery_detail_id =
                         wdd.delivery_detail_id
                     AND wnd2.delivery_id = wda2.delivery_id
                     AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                     AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                     AND wcsm2.enabled_flag(+) = 'Y'
                     AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                     AND oola.line_id = wdd2.source_line_id
                     AND ooha.header_id = oola.header_id
                     AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                     AND ooha.order_number = gn_order_num
                     AND wdd2.SUBINVENTORY = 'STAGE'
                     AND wdd.CONTAINER_NAME = wdd2.ATTRIBUTE4
            GROUP BY oola.ordered_item;
    BEGIN
        ln_order_tot_qty   := 0;

        /*=================================================================================================================================
                        ------------------Processing for SO# Available quantity ------------------------------------
           ================================================================================================================================*/

        lv_items_list      :=
               lv_items_list
            || '|'
            || RPAD (NVL ('Total Avail Qty', ' '), 15, ' ');

        FOR i IN avail_qty_cur
        LOOP
            lv_items_list      :=
                   lv_items_list
                || '|'
                || RPAD (NVL (i.ordered_item, ' '), 15, ' ');
            ln_order_tot_qty   := ln_order_tot_qty + i.lpn_qty;
        END LOOP;

        lv_qty_list        :=
            lv_qty_list || '|' || RPAD (NVL (ln_order_tot_qty, 0), 15, ' ');

        FOR i IN avail_qty_cur
        LOOP
            lv_qty_list   :=
                lv_qty_list || '|' || RPAD (NVL (i.lpn_qty, 0), 15, ' ');
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
            '*******************************************************************************************************');
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               '====================Report For Processed Patterns and left over quantity of SO#'
            || gn_order_num
            || '========================');
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
            '*******************************************************************************************************');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');


        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               '====================Available Quanttiy to Split the SO#'
            || gn_order_num
            || ' ========================');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                RPAD ('-', LENGTH (lv_items_list), '-'));
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, lv_items_list || '|');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                RPAD ('-', LENGTH (lv_items_list), '-'));
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, lv_qty_list || '|');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                RPAD ('-', LENGTH (lv_items_list), '-'));
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                '                          ');

        /*======================================================================================================================
                  ***********************Displaying Processed Patters*************************************
          =====================================================================================================================*/
        FOR i IN pattern_cur
        LOOP
            lv_process_items   := NULL;
            lv_process_qty     := NULL;

            lv_process_items   :=
                   lv_process_items
                || '|'
                || RPAD (NVL ('Total Quantity', ' '), 15, ' ')
                || '|'
                || RPAD (NVL ('Cases', ' '), 15, ' ')
                || '|'
                || RPAD (NVL ('Pairs For Case', ' '), 15, ' ');

            FOR j IN item_cur (i.Pattern)
            LOOP
                lv_process_items   :=
                       lv_process_items
                    || '|'
                    || RPAD (NVL (j.ordered_item, ' '), 15, ' ');
            END LOOP;

            lv_process_qty     :=
                   lv_process_qty
                || '|'
                || RPAD (NVL (i.Total_Qty, 0), 15, ' ')
                || '|'
                || RPAD (NVL (i.Cases, 0), 15, ' ')
                || '|'
                || RPAD (NVL (i.Qty_for_Case, 0), 15, ' ');

            FOR k IN item_cur (i.Pattern)
            LOOP
                lv_process_qty   :=
                       lv_process_qty
                    || '|'
                    || RPAD (NVL (k.LPN_QTY, 0), 15, ' ');
            END LOOP;

            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                   '====================Pattern:-'
                || i.Pattern
                || ' ========================');
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                    '                          ');
            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                RPAD ('-', LENGTH (lv_process_items), '-'));
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                    lv_process_items || '|');
            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                RPAD ('-', LENGTH (lv_process_items), '-'));
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                    lv_process_qty || '|');
            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                RPAD ('-', LENGTH (lv_process_items), '-'));
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                    '                          ');
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                    '                          ');
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error occured in disply report Procedure' || SQLERRM);
    END;

    PROCEDURE update_pattern
    IS
        ln_lines_cnt        NUMBER := 0;
        lv_init_pattern     VARCHAR2 (10) := 'A';
        ln_max_pattern      NUMBER;
        lv_update_pattern   VARCHAR2 (2000);

        CURSOR update_cur IS
            SELECT wdd2.DELIVERY_DETAIL_ID
              FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                   apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                   apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     wdd.container_name = wlpn.license_plate_number
                   AND wdd.source_code = 'WSH'
                   AND wdd.container_flag = 'Y'
                   AND wda2.parent_delivery_detail_id =
                       wdd.delivery_detail_id
                   AND wnd2.delivery_id = wda2.delivery_id
                   AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                   AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                   AND wcsm2.enabled_flag(+) = 'Y'
                   AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                   AND oola.line_id = wdd2.source_line_id
                   AND ooha.header_id = oola.header_id
                   AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                   AND ooha.order_number = gn_order_num
                   AND wdd2.SUBINVENTORY = 'STAGE'
                   AND wdd.CONTAINER_NAME <> wdd2.ATTRIBUTE4
                   AND wdd2.ATTRIBUTE5 IS NULL;
    BEGIN
        BEGIN
            SELECT COUNT (DISTINCT (wdd.container_name))
              INTO ln_lines_cnt
              FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                   apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                   apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     wdd.container_name = wlpn.license_plate_number
                   AND wdd.source_code = 'WSH'
                   AND wdd.container_flag = 'Y'
                   AND wda2.parent_delivery_detail_id =
                       wdd.delivery_detail_id
                   AND wnd2.delivery_id = wda2.delivery_id
                   AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                   AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                   AND wcsm2.enabled_flag(+) = 'Y'
                   AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                   AND oola.line_id = wdd2.source_line_id
                   AND ooha.header_id = oola.header_id
                   AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                   AND ooha.order_number = gn_order_num
                   AND wdd2.SUBINVENTORY = 'STAGE'
                   AND wdd.CONTAINER_NAME <> wdd2.ATTRIBUTE4
                   AND wdd2.ATTRIBUTE5 IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_lines_cnt   := 0;
                apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    ' Error occured while getting count of processed Records');
        END;

        --apps.fnd_file.put_line(apps.fnd_file.LOG,' Lines Cnt is-'||ln_lines_cnt);
        BEGIN
            SELECT NVL (MAX (ASCII (wdd2.attribute5)), 0)
              INTO ln_max_pattern
              FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                   apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                   apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     wdd.container_name = wlpn.license_plate_number
                   AND wdd.source_code = 'WSH'
                   AND wdd.container_flag = 'Y'
                   AND wda2.parent_delivery_detail_id =
                       wdd.delivery_detail_id
                   AND wnd2.delivery_id = wda2.delivery_id
                   AND wdd2.delivery_detail_id = wda2.delivery_detail_id
                   AND wcsm2.ship_method_code(+) = wdd2.ship_method_code
                   AND wcsm2.enabled_flag(+) = 'Y'
                   AND wcsm2.organization_id(+) = wdd2.organization_id -- in (7, wdd2.organization_id)
                   AND oola.line_id = wdd2.source_line_id
                   AND ooha.header_id = oola.header_id
                   AND oola.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                   AND ooha.order_number = gn_order_num
                   AND wdd2.SUBINVENTORY = 'STAGE'
                   AND wdd.CONTAINER_NAME <> wdd2.ATTRIBUTE4;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_max_pattern   := 1;
                apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    ' Error occured while fetching maximum pattern');
        END;

        -- apps.fnd_file.put_line(apps.fnd_file.LOG,' max pattern -'||ln_max_pattern);
        IF ln_lines_cnt <> 0
        THEN
            IF ln_max_pattern = 0
            THEN
                lv_update_pattern   := lv_init_pattern;
            --apps.fnd_file.put_line(apps.fnd_file.LOG,' initial pattern :='||lv_update_pattern);
            ELSIF ln_max_pattern >= 65
            THEN
                lv_update_pattern   := CHR (ln_max_pattern + 1);
            -- apps.fnd_file.put_line(apps.fnd_file.LOG,' max pattern -'||lv_update_pattern);
            END IF;

            lv_update_pattern   :=
                   lv_update_pattern
                || '-'
                || gn_total_qty
                || '-'
                || gn_tot_pairs
                || '-'
                || gn_list_qty;

            FOR i IN update_cur
            LOOP
                UPDATE apps.wsh_delivery_details wdd
                   SET attribute5   = lv_update_pattern
                 WHERE wdd.delivery_detail_id = i.delivery_detail_id;
            --  apps.fnd_file.put_line(apps.fnd_file.LOG,'delivery-'||lv_update_pattern);
            END LOOP;
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'No Eligible records for this iteration to update the pattern');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured in procedure update_pattern procedure:-'
                || SQLERRM);
    END;
END;
/
