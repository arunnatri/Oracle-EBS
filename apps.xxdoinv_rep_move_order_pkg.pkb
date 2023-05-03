--
-- XXDOINV_REP_MOVE_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV_REP_MOVE_ORDER_PKG"
AS
    /*
      REM $Header: XXDOINV_REP_MOVE_ORDER_PKG.PKB 1.0 23-Aug-2012 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM ===================================================================================================
      REM
      REM Name          : XXDOINV_REP_MOVE_ORDER_PKG.PKB
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
      REM Siva Ratnam            19-Sep-2014         1.5                 Added changes for DC3.4 expansion, move order lines will be updated with building code.
      REM BT Technology Team     05-Jan-2015         1.1                 Updated for BT
      REM ===================================================================================================
      */
    gn_rtn_val           NUMBER := 0;
    gn_err_cnt           NUMBER := 0;
    gv_err_msg           VARCHAR2 (2000);
    gn_organization_id   NUMBER;
    gv_from_date         VARCHAR2 (30);
    gv_to_date           VARCHAR2 (30);
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_updated_by        NUMBER := apps.fnd_global.user_id;
    gn_request_id        NUMBER := apps.fnd_global.conc_request_id;
    gv_brand             VARCHAR2 (20);
    gv_building          VARCHAR2 (20);
    gv_org_code          VARCHAR2 (20);
    gv_instance          VARCHAR2 (50);

    PROCEDURE UPDATE_MOD_QTY (pn_header_id          IN NUMBER,
                              pn_line_id            IN NUMBER,
                              pn_item_id            IN NUMBER,
                              pn_ship_from_org_id   IN NUMBER,
                              pn_mod_qty            IN NUMBER);

    FUNCTION hdr_id_to_order (pn_header_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION QTY_RESERVED (pn_header_id IN NUMBER, pn_line_id IN NUMBER, pv_order_qty_uom IN VARCHAR2
                           , pn_inv_item_id IN NUMBER)
        RETURN NUMBER
    IS
        l_open_quantity        NUMBER := 0;
        l_reserved_quantity    NUMBER := 0;
        l_mtl_sales_order_id   NUMBER;
        l_return_status        VARCHAR2 (1);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (240);
        l_rsv_rec              apps.inv_reservation_global.mtl_reservation_rec_type;
        l_rsv_tbl              apps.inv_reservation_global.mtl_reservation_tbl_type;
        l_count                NUMBER;
        l_x_error_code         NUMBER;
        l_lock_records         VARCHAR2 (1);
        l_sort_by_req_date     NUMBER;
        l_converted_qty        NUMBER;
        l_inventory_item_id    NUMBER := pn_inv_item_id;
        l_order_quantity_uom   VARCHAR2 (30) := pv_order_qty_uom;
        P_HEADER_ID            NUMBER := pn_header_id;
        P_LINE_ID              NUMBER := pn_line_id;
    BEGIN
        l_mtl_sales_order_id                :=
            apps.OE_HEADER_UTIL.Get_Mtl_Sales_Order_Id (
                p_header_id => p_header_id);

        l_rsv_rec.demand_source_header_id   := l_mtl_sales_order_id;
        l_rsv_rec.demand_source_line_id     := p_line_id;
        l_rsv_rec.organization_id           := NULL;

        apps.INV_RESERVATION_PUB.QUERY_RESERVATION_OM_HDR_LINE (
            p_api_version_number          => 1.0,
            p_init_msg_lst                => apps.fnd_api.g_true,
            x_return_status               => l_return_status,
            x_msg_count                   => l_msg_count,
            x_msg_data                    => l_msg_data,
            p_query_input                 => l_rsv_rec,
            x_mtl_reservation_tbl         => l_rsv_tbl,
            x_mtl_reservation_tbl_count   => l_count,
            x_error_code                  => l_x_error_code,
            p_lock_records                => l_lock_records,
            p_sort_by_req_date            => l_sort_by_req_date);

        /* BEGIN

              SELECT ool.order_quantity_uom, ool.inventory_item_id
              INTO   l_order_quantity_uom, l_inventory_item_id
              FROM   apps.oe_order_lines_all ool
               WHERE  line_id = p_line_id;

         EXCEPTION
          WHEN OTHERS THEN

           l_order_quantity_uom := NULL;
         END; */

        FOR I IN 1 .. l_rsv_tbl.COUNT
        LOOP
            l_rsv_rec   := l_rsv_tbl (I);

            IF NVL (l_order_quantity_uom, l_rsv_rec.reservation_uom_code) <>
               l_rsv_rec.reservation_uom_code
            THEN
                l_converted_qty   :=
                    apps.Oe_Order_Misc_Util.convert_uom (
                        l_inventory_item_id,
                        l_rsv_rec.reservation_uom_code,
                        l_order_quantity_uom,
                        l_rsv_rec.reservation_quantity);

                l_reserved_quantity   :=
                    l_reserved_quantity + l_converted_qty;
            ELSE
                l_reserved_quantity   :=
                    l_reserved_quantity + l_rsv_rec.reservation_quantity;
            END IF;
        END LOOP;

        IF l_reserved_quantity = 0
        THEN
            RETURN 0;
        ELSE
            RETURN 1;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
    END;

    PROCEDURE INSERT_ROWS
    IS
        CURSOR insert_so_lines IS
            SELECT 'REPLENISH',
                   ool.header_id,
                   ool.line_id,
                   ool.inventory_item_id,
                   ool.ship_from_org_id,
                   ool.ordered_item,
                   ool.line_number,
                   ool.ordered_quantity,
                   ool.org_id,
                   ool.request_date,
                   ool.promise_date,
                   ool.schedule_ship_date,
                   ool.order_quantity_uom,
                   ool.shipment_priority_code,
                   ool.flow_status_code,
                   SYSDATE,
                   gn_updated_by,
                   SYSDATE sysdate1,
                   gn_created_by,
                   gn_request_id,
                   --Start changes by BT Technology Team for BT on 17-Nov-2014,  v1.1
                   /*apps.xxdo_gender_split.iid_to_building (
                      ool.inventory_item_id,
                      ool.ship_from_org_id)
                      building,*/
                   (SELECT organization_code
                      FROM apps.mtl_parameters
                     WHERE organization_id = ool.ship_from_org_id) building,
                   --End changes by BT Technology Team for BT on 17-Nov-2014,  v1.1
                   NULL null1,
                   NULL null2,
                   NULL null3,
                   NULL null4,
                   'N',
                   NULL null5
              FROM apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
             WHERE     ool.header_id = ooh.header_id
                   AND TRUNC (ool.request_date) >=
                       TRUNC (
                           TO_DATE (gv_from_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND TRUNC (ool.request_date) <=
                       TRUNC (TO_DATE (gv_to_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.ship_from_org_id = gn_organization_id         --DC3
                   AND 1 = qty_reserved (ool.header_id, ool.line_id, ool.order_quantity_uom
                                         , ool.inventory_item_id) --added by venkatarama.battu on 08-Aug-2012
                   AND DECODE (
                           gv_brand,
                           NULL, '1',
                           NVL (
                               ooh.attribute5,
                               IID_TO_BRAND (ool.inventory_item_id,
                                             ool.ship_from_org_id))) =
                       DECODE (gv_brand, NULL, '1', gv_brand)
                   --Start changes by BT Technology Team for BT on 17-Nov-2014,  v1.1
                   /*AND DECODE (
                          gv_building,
                          NULL, '1',
                          apps.xxdo_gender_split.iid_to_building (
                             ool.inventory_item_id,
                             ool.ship_from_org_id)) =
                          DECODE (gv_building, NULL, '1', gv_building)*/
                   --End changes by BT Technology Team for BT on 17-Nov-2014,  v1.1
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details wdd
                             WHERE     wdd.source_line_id = ool.line_id
                                   AND wdd.source_code = 'OE'
                                   AND NVL (wdd.ATTRIBUTE3, 'N') <> 'Y'
                                   AND wdd.released_status = 'R' --added by venkatarama.battu on 08-Aug-2012
                                                                )
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdooe_lines_stg ols
                             WHERE     ols.header_id = ool.header_id
                                   AND ols.line_id = ool.line_id
                                   AND ols.source_code = 'REPLENISH');

        ln_err_cnt     PLS_INTEGER;
        ln_cnt         NUMBER := 0;
        dml_errors     EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);

        TYPE lines_tbl IS TABLE OF xxdo.xxdooe_lines_stg%ROWTYPE;

        so_lines_tbl   lines_tbl;
    BEGIN
        --                FOR rec1 IN insert_so_lines
        --                LOOP
        --                    dbms_output.put_line( 'CVC...STG table DATA...'||rec1.line_id);
        --                    null;
        --                END LOOP;

        DELETE FROM
            xxdo.xxdooe_lines_stg
              WHERE     source_code = 'REPLENISH'
                    AND status_code IN ('S', 'P', 'N');

        DELETE FROM
            xxdo.xxdooe_lines_stg lstg
              WHERE     lstg.source_code = 'REPLENISH'
                    AND lstg.STATUS_CODE = 'E'
                    AND TRUNC (lstg.creation_date) <= TRUNC (SYSDATE - 30);

        COMMIT;

        --    dbms_output.put_line( 'CVC...Before inserting into STG table...');



        OPEN insert_so_lines;

        FETCH insert_so_lines BULK COLLECT INTO so_lines_tbl;

        CLOSE insert_so_lines;

        --dbms_output.put_line( 'CVC...STG table data...'||so_lines_tbl.header_id);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '===================================================================================================');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'No of Records Feteched For this iteration is:---'
            || so_lines_tbl.COUNT);

        --    dbms_output.put_line( 'CVC...After inserting into STG table...'||so_lines_tbl.COUNT);
        FORALL i IN 1 .. so_lines_tbl.COUNT SAVE EXCEPTIONS
            INSERT INTO xxdo.xxdooe_lines_stg
                 VALUES so_lines_tbl (i);

        COMMIT;
    EXCEPTION
        WHEN dml_errors
        THEN
            ln_err_cnt   := SQL%BULK_EXCEPTIONS.COUNT;
            ln_cnt       := ln_cnt + ln_err_cnt;

            FOR i IN 1 .. ln_err_cnt
            LOOP
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error Occured during the insertion'
                    || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX
                    || '  '
                    || 'Oracle error is '
                    || SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
            END LOOP;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'No of error records while inserting are:--' || ln_cnt);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '===================================================================================================');
    END;

    PROCEDURE UPDATE_STG_TBL (p_item_id IN NUMBER, p_status_code IN VARCHAR2)
    IS
        CURSOR stg_tbl_update IS
            SELECT ool.header_id, ool.line_id, ool.ordered_item,
                   ool.inventory_item_id, ool.ship_from_org_id, ool.ORDER_QUANTITY_UOM
              FROM xxdo.xxdooe_lines_stg ool
             WHERE     TRUNC (ool.request_date) >=
                       TRUNC (
                           TO_DATE (gv_from_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND TRUNC (ool.request_date) <=
                       TRUNC (TO_DATE (gv_to_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.ship_from_org_id = gn_organization_id
                   AND ool.source_code = 'REPLENISH'
                   AND ool.status_code IN ('N', 'E')
                   AND ool.inventory_item_id = p_item_id;
    BEGIN
        FOR i IN stg_tbl_update
        LOOP
            UPDATE xxdo.xxdooe_lines_stg ols
               SET ols.status_code = NVL (p_status_code, 'E'), ols.status_msg = gv_err_msg, ols.last_update_date = SYSDATE,
                   ols.last_updated_by = gn_updated_by
             WHERE ols.header_id = i.header_id AND ols.line_id = i.line_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'error occured while updating the staging table'
                || '  '
                || 'ERROR: '
                || SQLERRM);
    END;

    PROCEDURE print_report
    IS
        CURSOR err_cur IS
              SELECT ols.ordered_item,
                     ols.inventory_item_id,
                     (SELECT ood.organization_code
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = ols.ship_from_org_id)
                         organization_code,
                     ols.order_quantity_uom,
                     ols.status_code,
                     ols.status_msg
                FROM xxdo.xxdooe_lines_stg ols
               WHERE ols.status_code = 'E' AND ols.request_id = gn_request_id
            GROUP BY ols.ordered_item, ols.inventory_item_id, ols.ship_from_org_id,
                     ols.order_quantity_uom, ols.status_code, ols.status_msg;

        CURSOR Process_cur IS
              SELECT ols.ordered_item,
                     ols.inventory_item_id,
                     (SELECT ood.organization_code
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = ols.ship_from_org_id)
                         organization_code,
                     ols.order_quantity_uom,
                     ols.status_code,
                     ols.status_msg
                FROM xxdo.xxdooe_lines_stg ols
               WHERE ols.status_code = 'P' AND ols.request_id = gn_request_id
            GROUP BY ols.ordered_item, ols.inventory_item_id, ols.ship_from_org_id,
                     ols.order_quantity_uom, ols.status_code, ols.status_msg;

        CURSOR success_cur IS
              SELECT ols.ordered_item,
                     ols.inventory_item_id,
                     (SELECT ood.organization_code
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = ols.ship_from_org_id)
                         organization_code,
                     ols.order_quantity_uom,
                     ols.status_code,
                     ols.status_msg
                FROM xxdo.xxdooe_lines_stg ols
               WHERE ols.status_code = 'S' AND ols.request_id = gn_request_id
            GROUP BY ols.ordered_item, ols.inventory_item_id, ols.ship_from_org_id,
                     ols.order_quantity_uom, ols.status_code, ols.status_msg;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, 'Print Error Records');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD (' ', 60, ' ')
            || ' '
            || RPAD (
                   'Replenishment Move Orders Based on Sales Order Demand - Deckers Report',
                   60,
                   ' ')
            || ' '
            || RPAD (' ', 60, ' '));
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, RPAD ('-', 80, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
            'Replenishment Move Orders Based on Sales Order Demand - Deckers Report - Errored Rows');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, RPAD ('-', 80, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   );
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('Ordered_item', 20, ' ')
            || '|'
            || RPAD ('Inventory_item_id', 20, ' ')
            || '|'
            || RPAD ('Organization Code', 20, ' ')
            || '|'
            || RPAD ('Order_quantity_uom ', 19, ' ')
            || '|'
            || RPAD ('Status', 7, ' ')
            || '|'
            || RPAD ('Error Message', 200, ' ')                     --  || '|'
                                               );
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   );

        FOR error_rec IN err_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                   RPAD (NVL (NVL (error_rec.ordered_item, ' '), ' '),
                         20,
                         ' ')
                || '|'
                || RPAD (NVL (error_rec.inventory_item_id, 0), 20, ' ')
                || '|'
                || RPAD (NVL (error_rec.organization_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (error_rec.order_quantity_uom, ' '), 19, ' ')
                || '|'
                || RPAD (NVL (error_rec.status_code, ' '), 7, ' ')
                || '|'
                || RPAD (NVL (error_rec.status_msg, ' '), 200, ' ') --        || '|'
                                                                   );

            apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');

        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                'Print Processed Records');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD (' ', 70, ' ')
            || ' '
            || RPAD (
                   'Replenishment Move Orders Based on Sales Order Demand - Deckers Report',
                   70,
                   ' ')
            || ' '
            || RPAD (' ', 70, ' '));
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, RPAD ('-', 100, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
            'Replenishment Move Orders Based on Sales Order Demand - Deckers Report - Processed Rows');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, RPAD ('-', 100, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   );
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('Ordered_item', 20, ' ')
            || '|'
            || RPAD ('Inventory_item_id', 20, ' ')
            || '|'
            || RPAD ('Organization Code', 20, ' ')
            || '|'
            || RPAD ('Order_quantity_uom ', 19, ' ')
            || '|'
            || RPAD ('Status', 7, ' ')
            || '|'
            || RPAD ('Error Message', 200, ' ')                     --  || '|'
                                               );
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   );

        FOR Process_rec IN Process_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                   RPAD (NVL (NVL (Process_rec.ordered_item, ' '), ' '),
                         20,
                         ' ')
                || '|'
                || RPAD (NVL (Process_rec.inventory_item_id, 0), 20, ' ')
                || '|'
                || RPAD (NVL (Process_rec.organization_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (Process_rec.order_quantity_uom, ' '), 19, ' ')
                || '|'
                || RPAD (NVL (Process_rec.status_code, ' '), 7, ' ')
                || '|'
                || RPAD (NVL (Process_rec.status_msg, ' '), 200, ' ') --        || '|'
                                                                     );


            apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                'Print Success Records');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD (' ', 70, ' ')
            || ' '
            || RPAD (
                   'Replenishment Move Orders Based on Sales Order Demand - Deckers Report',
                   70,
                   ' ')
            || ' '
            || RPAD (' ', 70, ' '));
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, RPAD ('-', 100, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
            'Replenishment Move Orders Based on Sales Order Demand - Deckers Report - Success Rows');
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, RPAD ('-', 100, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   );
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('Ordered_item', 20, ' ')
            || '|'
            || RPAD ('Inventory_item_id', 20, ' ')
            || '|'
            || RPAD ('Organization Code', 20, ' ')
            || '|'
            || RPAD ('Order_quantity_uom ', 19, ' ')
            || '|'
            || RPAD ('Status', 7, ' ')
            || '|'
            || RPAD ('Error Message', 200, ' ')                     --  || '|'
                                               );
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   );

        FOR success_rec IN success_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.OUTPUT,
                   RPAD (NVL (NVL (success_rec.ordered_item, ' '), ' '),
                         20,
                         ' ')
                || '|'
                || RPAD (NVL (success_rec.inventory_item_id, 0), 20, ' ')
                || '|'
                || RPAD (NVL (success_rec.organization_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (success_rec.order_quantity_uom, ' '), 19, ' ')
                || '|'
                || RPAD (NVL (success_rec.status_code, ' '), 7, ' ')
                || '|'
                || RPAD (NVL (success_rec.status_msg, ' '), 200, ' ') --        || '|'
                                                                     );

            apps.fnd_file.put_line (apps.fnd_file.OUTPUT, ' ');
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in :- Error Report Printing - > ' || SQLERRM);
    END;

    PROCEDURE Process_orders
    IS
        CURSOR building_cur IS
            SELECT DISTINCT stg.attribute1 building
              FROM xxdo.xxdooe_lines_stg stg
             WHERE     stg.source_code = 'REPLENISH'
                   AND TRUNC (stg.request_date) >=
                       TRUNC (
                           TO_DATE (gv_from_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND TRUNC (stg.request_date) <=
                       TRUNC (TO_DATE (gv_to_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND stg.flow_status_code = 'AWAITING_SHIPPING'
                   AND stg.ship_from_org_id = gn_organization_id
                   AND stg.source_code = 'REPLENISH'
                   AND stg.status_code IN ('N', 'E');

        --AND stg.inventory_item_id        = 311047;
        CURSOR rep_item_cur (cp_building VARCHAR2)
        IS
            SELECT DISTINCT ool.ordered_item, ool.inventory_item_id, ool.ship_from_org_id,
                            ool.order_quantity_uom
              FROM xxdo.xxdooe_lines_stg ool
             WHERE     TRUNC (ool.request_date) >=
                       TRUNC (
                           TO_DATE (gv_from_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND TRUNC (ool.request_date) <=
                       TRUNC (TO_DATE (gv_to_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.ship_from_org_id = gn_organization_id
                   AND ool.source_code = 'REPLENISH'
                   AND ool.status_code IN ('N', 'E')
                   AND ool.attribute1 = cp_building;

        --AND ool.inventory_item_id        = 311047;

        -- Variable Declerations

        lv_onhand_quantity     NUMBER;
        lv_qa_onhand           NUMBER;
        lv_src_onhand          NUMBER;
        lv_return_onhand       NUMBER;
        lv_receiving_onhand    NUMBER;
        ln_max_minmax_qty      NUMBER;
        ln_req_quantity        NUMBER;
        ln_locator_cnt         NUMBER;
        ln_process_COUNT       NUMBER := 0;
        ln_suff_qty            NUMBER := 0;
        ln_COUNT               NUMBER := 0;
        ln_conversion_rate     NUMBER;
        ln_qty_required        NUMBER;
        ln_quantity            NUMBER;
        ln_round_qty           NUMBER;
        ln_index               NUMBER;
        bild_ind               NUMBER;
        lv_org_code            VARCHAR2 (10);
        lv_mail_recp           VARCHAR2 (100);
        lv_user_name           VARCHAR2 (50)
                                   := apps.fnd_profile.VALUE ('USERNAME');
        lv_source_sub_inv      VARCHAR2 (10);
        lv_dest_sub_inv        VARCHAR2 (10);
        lv_email               VARCHAR2 (50) := NULL;
        order_detail_tbl       Order_Tbl_Type1;
        order_detail_tbl_cnt   NUMBER;
        build_detail_tbl       build_detail_table;
        v_mail_recips          apps.do_mail_utils.tbl_recips;
        l_header_tbl           Order_header_Tbl_type;
        l_order_lines_tbl      Order_Tbl_Type;
        ln_build_id            NUMBER;
    --        item_tbl                       item_info;
    --        item_cnt                       NUMBER:=1;
    BEGIN
        BEGIN                                          -- Getting the email id
            SELECT fu.email_address
              INTO lv_email
              FROM apps.fnd_user fu
             WHERE fu.user_name = lv_user_name;

            IF lv_email IS NOT NULL
            THEN
                v_mail_recips (v_mail_recips.COUNT + 1)   := lv_email;
            ELSE
                V_MAIL_RECIPS (V_MAIL_RECIPS.COUNT + 1)   :=
                    'jmiranda@deckers.com';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_MAIL_RECIPS (V_MAIL_RECIPS.COUNT + 1)   :=
                    'jmiranda@deckers.com';
            WHEN TOO_MANY_ROWS
            THEN
                V_MAIL_RECIPS (V_MAIL_RECIPS.COUNT + 1)   :=
                    'jmiranda@deckers.com';
            WHEN OTHERS
            THEN
                V_MAIL_RECIPS (V_MAIL_RECIPS.COUNT + 1)   :=
                    'jmiranda@deckers.com';
        END;

        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_mail_recips, 'Replenishment Move Orders From :' || gv_from_date || ' AND  To : ' || gv_to_date
                                             , gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('', gn_rtn_val);
        apps.do_mail_utils.send_mail_line (
            'Request Submitted by:-' || lv_user_name,
            gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('From Date:-' || gv_from_date,
                                           gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('To Date:-' || gv_to_date,
                                           gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('Organization:-' || gv_org_code,
                                           gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('Building:-' || gv_building,
                                           gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('Brand:-' || gv_brand, gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('Instance:-' || gv_instance,
                                           gn_rtn_val);
        apps.do_mail_utils.send_mail_line (' ' || ' ', gn_rtn_val);
        apps.do_mail_utils.send_mail_line (
            '## This is an Email alert automatically generated when "Replenishment Move Order creation based on Sales order demand" is submitted ##',
            gn_rtn_val);
        apps.do_mail_utils.send_mail_line (' ' || ' ', gn_rtn_val);

        FOR k IN building_cur
        LOOP
            build_detail_tbl.DELETE;
            bild_ind               := 1;
            order_detail_tbl.DELETE;
            order_detail_tbl_cnt   := NULL;
            ln_index               := 1;

            --item_tbl.DELETE;
            --item_cnt    :=1;
            BEGIN
                SELECT ood.organization_id
                  INTO ln_build_id
                  FROM apps.org_organization_definitions ood
                 WHERE ood.organization_code = k.building;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Building id not found');
                WHEN TOO_MANY_ROWS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'More than one organization id exist');
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Unexpected error occured getting the Building id');
            END;

            l_header_tbl.DELETE;

            OPEN rep_item_cur (k.building);

            FETCH rep_item_cur BULK COLLECT INTO l_header_tbl;

            CLOSE rep_item_cur;

            --IF lt_item_glo.COUNT > 0 THEN
            FOR j IN 1 .. l_header_tbl.COUNT
            LOOP
                lv_org_code           := NULL;
                lv_source_sub_inv     := NULL;
                lv_dest_sub_inv       := NULL;
                lv_onhand_quantity    := 0;
                lv_src_onhand         := 0;
                lv_qa_onhand          := 0;
                lv_return_onhand      := 0;
                lv_receiving_onhand   := 0;
                ln_locator_cnt        := 0;
                ln_max_minmax_qty     := 0;
                ln_conversion_rate    := 0;
                ln_count              := ln_count + 1;
                ln_req_quantity       := 0;
                ln_quantity           := 0;
                ln_round_qty          := 0;
                gn_err_cnt            := 0;
                gv_err_msg            := NULL;
                l_order_lines_tbl.DELETE;

                BEGIN
                    SELECT organization_code
                      INTO lv_org_code
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id =
                           l_header_tbl (j).ship_from_org_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'Organizaton code not found');
                    WHEN TOO_MANY_ROWS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'More than one organization code exist');
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Unexpected error occured getting the organization code');
                END;

                BEGIN -- Fetching the Source sub_inv and Destinatin sub_inv from the ship_from_org_id
                    SELECT TRIM (SUBSTR (description,
                                         1,
                                         (  INSTR (description, ',', 1,
                                                   1)
                                          - 1))),
                           TRIM (SUBSTR (description,
                                         (  INSTR (description, ',', 1,
                                                   1)
                                          + 1)))
                      INTO lv_source_sub_inv, lv_dest_sub_inv
                      FROM apps.fnd_lookup_values flv, apps.org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXDO_REPLEN_SUBINV'
                           AND flv.LANGUAGE = USERENV ('LANG')
                           AND flv.lookup_code = ood.organization_code
                           AND ood.organization_code = k.building;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'Source and Destination suninventories not defined in the lookup';
                    WHEN TOO_MANY_ROWS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'More than one source and destination suninventories are defined in the lookup table';
                    WHEN OTHERS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'Error occured wile getting subinventories in lookup table';
                END;

                BEGIN --checking the onhand quantity in mtl_onhand_quantities table for the suvinventory
                    lv_onhand_quantity   :=
                        ATR_QTY (l_header_tbl (j).inventory_item_id,
                                 l_header_tbl (j).ship_from_org_id,
                                 lv_dest_sub_inv);
                    lv_src_onhand   :=
                        ATR_QTY (l_header_tbl (j).inventory_item_id,
                                 l_header_tbl (j).ship_from_org_id,
                                 lv_source_sub_inv);
                    lv_qa_onhand   :=
                        ATT_QTY (l_header_tbl (j).inventory_item_id,
                                 l_header_tbl (j).ship_from_org_id,
                                 'QA');
                    lv_return_onhand   :=
                        ATT_QTY (l_header_tbl (j).inventory_item_id,
                                 l_header_tbl (j).ship_from_org_id,
                                 'RETURNS');
                    lv_receiving_onhand   :=
                        ATT_QTY (l_header_tbl (j).inventory_item_id,
                                 l_header_tbl (j).ship_from_org_id,
                                 'RECEIVING');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'Error occured wile getting Available to reserve quantity';
                END;

                BEGIN -- Fetching the Convertin rate for the item  or case pick quantity
                    SELECT mou.conversion_rate
                      INTO ln_conversion_rate
                      FROM apps.mtl_uom_conversions mou
                     WHERE mou.inventory_item_id =
                           l_header_tbl (j).inventory_item_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'UOM conversion rate not defined';
                    WHEN TOO_MANY_ROWS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'More than one UOM conversion Defined';
                    WHEN OTHERS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'Error Occured wile getting case pick quantity';
                END;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_locator_cnt
                      FROM apps.mtl_secondary_locators msl, apps.mtl_item_locations mil
                     WHERE     msl.inventory_item_id =
                               l_header_tbl (j).inventory_item_id -- 1179409 --1184432
                           AND msl.organization_id =
                               l_header_tbl (j).ship_from_org_id -- gn_organization_id
                           AND msl.secondary_locator =
                               mil.inventory_location_id
                           AND msl.subinventory_code = lv_dest_sub_inv;
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'More than one Locator exist';
                    WHEN OTHERS
                    THEN
                        gn_err_cnt   := gn_err_cnt + 1;
                        gv_err_msg   :=
                               gv_err_msg
                            || '  '
                            || 'Error wile validating more than one locarot for the item';
                END;

                IF ln_locator_cnt > 1
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
                    apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
                    apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                           RPAD ('Move Order Num', 20, ' ')
                        || ' '
                        || RPAD ('Move Order Satus', 18, ' ')
                        || ' '
                        || RPAD ('Item Number', 17, ' ')
                        || ' '
                        || RPAD ('Organization Code', 19, ' ')
                        || ' '
                        || RPAD ('From Subinventory', 19, ' ')
                        || ' '
                        || RPAD ('To Subinventory', 19, ' ')
                        || ' '
                        || RPAD ('Quantity Ordered', 20, ' ')
                        || ' '
                        || RPAD ('STATUS', 15, ' '),
                        gn_rtn_val);
                    apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                           RPAD ('==============', 20, ' ')
                        || ' '
                        || RPAD ('===============', 18, ' ')
                        || ' '
                        || RPAD ('===========', 17, ' ')
                        || ' '
                        || RPAD ('=================', 19, ' ')
                        || ' '
                        || RPAD ('================', 19, ' ')
                        || ' '
                        || RPAD ('===============', 19, ' ')
                        || ' '
                        || RPAD ('================', 20, ' ')
                        || ' '
                        || RPAD ('======', 30, ' '),
                        gn_rtn_val);
                    apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                           RPAD ('########', 20, ' ')
                        || ' '
                        || RPAD ('####', 18, ' ')
                        || ' '
                        || RPAD (l_header_tbl (j).ordered_item, 17, ' ')
                        || ' '
                        || RPAD (lv_org_code, 19, ' ')
                        || ' '
                        || RPAD (lv_source_sub_inv, 19, ' ')
                        || ' '
                        || RPAD (lv_dest_sub_inv, 19, ' ')
                        || ' '
                        || RPAD ('###', 20, ' ')
                        || ' '
                        || RPAD ('Multiple Locators Exist', 70, ' '),
                        gn_rtn_val);
                    apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
                    gv_err_msg         :=
                           gv_err_msg
                        || ' '
                        || 'More than one Locators defined for the item';

                    UPDATE_STG_TBL (
                        p_item_id       => l_header_tbl (j).inventory_item_id,
                        p_status_code   => 'E');  --updating the staging table
                    ln_process_COUNT   := ln_process_COUNT + 1;
                ELSE
                    BEGIN
                        DBMS_OUTPUT.put_line (
                               'CVC...item locator counts value is NOT GREATER THAN ONE:'
                            || ln_locator_cnt);

                        SELECT misi.max_minmax_quantity
                          INTO ln_max_minmax_qty
                          FROM apps.mtl_item_sub_inventories_all_v misi, apps.mfg_lookups ml
                         WHERE     misi.inventory_item_id =
                                   l_header_tbl (j).inventory_item_id
                               AND misi.organization_id =
                                   l_header_tbl (j).ship_from_org_id
                               AND misi.secondary_inventory = lv_dest_sub_inv
                               AND ml.lookup_type = 'MTL_MATERIAL_PLANNING'
                               AND misi.inventory_planning_code = lookup_code
                               AND UPPER (ml.meaning) =
                                   UPPER ('Min-max planning');
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            gn_err_cnt          := gn_err_cnt + 1;
                            gv_err_msg          :=
                                   gv_err_msg
                                || '  '
                                || 'MIN_MAX plan not enabled for the item or maximum_locator capaciry not defined';
                            ln_max_minmax_qty   := 0;
                        WHEN TOO_MANY_ROWS
                        THEN
                            gn_err_cnt          := gn_err_cnt + 1;
                            gv_err_msg          :=
                                   gv_err_msg
                                || '  '
                                || 'More than  one locator exist for the item';
                            ln_max_minmax_qty   := 0;
                        WHEN OTHERS
                        THEN
                            gn_err_cnt          := gn_err_cnt + 1;
                            gv_err_msg          :=
                                   gv_err_msg
                                || '  '
                                || 'Error wile getting max locator capacity of an item';
                            ln_max_minmax_qty   := 0;
                    END;

                    IF gn_err_cnt > 0
                    THEN
                        UPDATE_STG_TBL (
                            p_item_id       => l_header_tbl (j).inventory_item_id,
                            p_status_code   => 'E');
                    ELSE
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            '=============================================================================================================================================');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Processing the item'
                            || '****'
                            || l_header_tbl (j).ordered_item
                            || '  '
                            || 'AND ship_from_org_id: '
                            || l_header_tbl (j).ship_from_org_id);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            '---------------------------------------------------------------------------------------------------------------------------------------------');

                        BEGIN
                            SELECT ool.header_id, ool.line_id, ool.line_number,
                                   ool.ordered_item, ool.inventory_item_id, ool.ordered_quantity,
                                   ool.ship_from_org_id, ool.order_quantity_uom
                              BULK COLLECT INTO l_order_lines_tbl
                              FROM xxdo.xxdooe_lines_stg ool
                             WHERE     TRUNC (ool.request_date) >=
                                       TRUNC (
                                           TO_DATE (gv_from_date,
                                                    'RRRR/MM/DD HH24:MI:SS'))
                                   AND TRUNC (ool.request_date) <=
                                       TRUNC (
                                           TO_DATE (gv_to_date,
                                                    'RRRR/MM/DD HH24:MI:SS'))
                                   AND ool.flow_status_code =
                                       'AWAITING_SHIPPING'
                                   AND ool.ship_from_org_id =
                                       l_header_tbl (j).ship_from_org_id
                                   AND ool.inventory_item_id =
                                       l_header_tbl (j).inventory_item_id
                                   AND ool.source_code = 'REPLENISH'
                                   AND ool.status_code IN ('N', 'E')
                                   AND ool.attribute1 = k.building;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                apps.fnd_file.put_line (
                                    apps.fnd_file.LOG,
                                       ' Error occured while processing the item it'
                                    || l_header_tbl (j).inventory_item_id);
                        END;

                        FOR i IN 1 .. l_order_lines_tbl.COUNT
                        LOOP
                            IF l_order_lines_tbl (i).ordered_quantity >=
                               ln_conversion_rate
                            THEN
                                ln_req_quantity   :=
                                      ln_req_quantity
                                    + MOD (
                                          l_order_lines_tbl (i).ordered_quantity,
                                          ln_conversion_rate);

                                IF MOD (
                                       l_order_lines_tbl (i).ordered_quantity,
                                       ln_conversion_rate) >
                                   0
                                THEN
                                    order_detail_tbl (ln_index).header_id   :=
                                        l_order_lines_tbl (i).header_id;
                                    order_detail_tbl (ln_index).line_id   :=
                                        l_order_lines_tbl (i).line_id;
                                    order_detail_tbl (ln_index).line_number   :=
                                        l_order_lines_tbl (i).line_number;
                                    order_detail_tbl (ln_index).ordered_item   :=
                                        l_order_lines_tbl (i).ordered_item;
                                    order_detail_tbl (ln_index).inventory_item_id   :=
                                        l_order_lines_tbl (i).inventory_item_id;
                                    order_detail_tbl (ln_index).ordered_quantity   :=
                                        l_order_lines_tbl (i).ordered_quantity;
                                    order_detail_tbl (ln_index).ship_from_org_id   :=
                                        l_order_lines_tbl (i).ship_from_org_id;
                                    order_detail_tbl (ln_index).order_quantity_uom   :=
                                        l_order_lines_tbl (i).order_quantity_uom;
                                    order_detail_tbl (ln_index).mod_qty   :=
                                        MOD (
                                            l_order_lines_tbl (i).ordered_quantity,
                                            ln_conversion_rate);
                                    order_detail_tbl (ln_index).flag   := 'Y';
                                    ln_index                           :=
                                        ln_index + 1;
                                    UPDATE_MOD_QTY (
                                        pn_header_id   =>
                                            l_order_lines_tbl (i).header_id,
                                        pn_line_id   =>
                                            l_order_lines_tbl (i).line_id,
                                        pn_item_id   =>
                                            l_order_lines_tbl (i).inventory_item_id,
                                        pn_ship_from_org_id   =>
                                            l_order_lines_tbl (i).ship_from_org_id,
                                        pn_mod_qty   =>
                                            MOD (
                                                l_order_lines_tbl (i).ordered_quantity,
                                                ln_conversion_rate));
                                ELSIF MOD (
                                          l_order_lines_tbl (i).ordered_quantity,
                                          ln_conversion_rate) =
                                      0
                                THEN
                                    UPDATE xxdo.xxdooe_lines_stg stg
                                       SET stg.status_code = 'P', stg.status_msg = 'Ordered Quantity is matched to case pick Quantity', stg.attribute2 = 0
                                     WHERE     stg.header_id =
                                               l_order_lines_tbl (i).header_id
                                           AND stg.line_id =
                                               l_order_lines_tbl (i).line_id;
                                END IF;
                            ELSIF l_order_lines_tbl (i).ordered_quantity <
                                  ln_conversion_rate
                            THEN
                                ln_req_quantity                    :=
                                      ln_req_quantity
                                    + l_order_lines_tbl (i).ordered_quantity;
                                order_detail_tbl (ln_index).header_id   :=
                                    l_order_lines_tbl (i).header_id;
                                order_detail_tbl (ln_index).line_id   :=
                                    l_order_lines_tbl (i).line_id;
                                order_detail_tbl (ln_index).line_number   :=
                                    l_order_lines_tbl (i).line_number;
                                order_detail_tbl (ln_index).ordered_item   :=
                                    l_order_lines_tbl (i).ordered_item;
                                order_detail_tbl (ln_index).inventory_item_id   :=
                                    l_order_lines_tbl (i).inventory_item_id;
                                order_detail_tbl (ln_index).ordered_quantity   :=
                                    l_order_lines_tbl (i).ordered_quantity;
                                order_detail_tbl (ln_index).ship_from_org_id   :=
                                    l_order_lines_tbl (i).ship_from_org_id;
                                order_detail_tbl (ln_index).order_quantity_uom   :=
                                    l_order_lines_tbl (i).order_quantity_uom;
                                order_detail_tbl (ln_index).mod_qty   :=
                                    l_order_lines_tbl (i).ordered_quantity;
                                order_detail_tbl (ln_index).flag   := 'Y';
                                ln_index                           :=
                                    ln_index + 1;
                                UPDATE_MOD_QTY (
                                    pn_header_id   =>
                                        l_order_lines_tbl (i).header_id,
                                    pn_line_id   =>
                                        l_order_lines_tbl (i).line_id,
                                    pn_item_id   =>
                                        l_order_lines_tbl (i).inventory_item_id,
                                    pn_ship_from_org_id   =>
                                        l_order_lines_tbl (i).ship_from_org_id,
                                    pn_mod_qty   =>
                                        MOD (
                                            l_order_lines_tbl (i).ordered_quantity,
                                            ln_conversion_rate));
                            END IF;
                        END LOOP;

                        IF lv_onhand_quantity >= ln_req_quantity
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                '                Item has sufficent onhand quantity for the current demand  ');
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                ' ==========================================================================================================================================');
                            gv_err_msg   :=
                                   gv_err_msg
                                || ' '
                                || 'Items has Sufficent onhand quantity for the current demand ';
                            UPDATE_STG_TBL (
                                p_item_id       =>
                                    l_header_tbl (j).inventory_item_id,
                                p_status_code   => 'P');
                        ELSE
                            IF     ln_req_quantity > lv_onhand_quantity
                               AND ln_max_minmax_qty > 0
                               AND ln_req_quantity <= ln_max_minmax_qty
                            THEN
                                ln_quantity                           :=
                                    (ln_max_minmax_qty - lv_onhand_quantity);

                                ln_round_qty                          :=
                                      ln_quantity
                                    + (ln_conversion_rate - MOD (ln_quantity, ln_conversion_rate));
                                build_detail_tbl (bild_ind).header_id   :=
                                    NULL;
                                build_detail_tbl (bild_ind).line_id   := NULL;
                                build_detail_tbl (bild_ind).line_number   :=
                                    bild_ind;
                                build_detail_tbl (bild_ind).ordered_item   :=
                                    l_header_tbl (j).ordered_item;
                                build_detail_tbl (bild_ind).inventory_item_id   :=
                                    l_header_tbl (j).inventory_item_id;
                                build_detail_tbl (bild_ind).ordered_quantity   :=
                                    ln_round_qty;
                                build_detail_tbl (bild_ind).ship_from_org_id   :=
                                    l_header_tbl (j).ship_from_org_id;
                                build_detail_tbl (bild_ind).order_quantity_uom   :=
                                    l_header_tbl (j).order_quantity_uom;
                                build_detail_tbl (bild_ind).required_qty   :=
                                    ln_req_quantity;
                                build_detail_tbl (bild_ind).from_sub_inv   :=
                                    lv_source_sub_inv;
                                build_detail_tbl (bild_ind).to_sub_inv   :=
                                    lv_dest_sub_inv;
                                build_detail_tbl (bild_ind).pair_pick_qty   :=
                                    lv_onhand_quantity;
                                build_detail_tbl (bild_ind).case_pick_qty   :=
                                    lv_src_onhand;
                                build_detail_tbl (bild_ind).qa_subinv_onhand   :=
                                    lv_qa_onhand;
                                build_detail_tbl (bild_ind).rcv_subinv_onhand   :=
                                    lv_receiving_onhand;
                                build_detail_tbl (bild_ind).rtn_subinv_onhand   :=
                                    lv_return_onhand;
                                build_detail_tbl (bild_ind).building_code   :=
                                    k.building;
                                bild_ind                              :=
                                    bild_ind + 1;

                                ln_process_COUNT                      :=
                                    ln_process_COUNT + 1;
                            ELSIF     ln_req_quantity > lv_onhand_quantity
                                  AND ln_max_minmax_qty > 0
                                  AND ln_req_quantity > ln_max_minmax_qty
                            THEN
                                ln_quantity                           :=
                                    (ln_req_quantity - lv_onhand_quantity);
                                ln_round_qty                          :=
                                      ln_quantity
                                    + (ln_conversion_rate - MOD (ln_quantity, ln_conversion_rate));
                                build_detail_tbl (bild_ind).header_id   :=
                                    NULL;
                                build_detail_tbl (bild_ind).line_id   := NULL;
                                build_detail_tbl (bild_ind).line_number   :=
                                    bild_ind;
                                build_detail_tbl (bild_ind).ordered_item   :=
                                    l_header_tbl (j).ordered_item;
                                build_detail_tbl (bild_ind).inventory_item_id   :=
                                    l_header_tbl (j).inventory_item_id;
                                build_detail_tbl (bild_ind).ordered_quantity   :=
                                    ln_round_qty;
                                build_detail_tbl (bild_ind).ship_from_org_id   :=
                                    l_header_tbl (j).ship_from_org_id;
                                build_detail_tbl (bild_ind).order_quantity_uom   :=
                                    l_header_tbl (j).order_quantity_uom;
                                build_detail_tbl (bild_ind).required_qty   :=
                                    ln_req_quantity;
                                build_detail_tbl (bild_ind).from_sub_inv   :=
                                    lv_source_sub_inv;
                                build_detail_tbl (bild_ind).to_sub_inv   :=
                                    lv_dest_sub_inv;
                                build_detail_tbl (bild_ind).pair_pick_qty   :=
                                    lv_onhand_quantity;
                                build_detail_tbl (bild_ind).case_pick_qty   :=
                                    lv_src_onhand;
                                build_detail_tbl (bild_ind).qa_subinv_onhand   :=
                                    lv_qa_onhand;
                                build_detail_tbl (bild_ind).rcv_subinv_onhand   :=
                                    lv_receiving_onhand;
                                build_detail_tbl (bild_ind).rtn_subinv_onhand   :=
                                    lv_return_onhand;

                                bild_ind                              :=
                                    bild_ind + 1;

                                ln_process_COUNT                      :=
                                    ln_process_COUNT + 1;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            IF build_detail_tbl.COUNT > 0
            THEN
                CREATE_MOVE_ORDER (p_org_id => gn_organization_id --ln_build_id  --l_header_tbl(j).ship_from_org_id
                                                                 , p_from_sub => lv_source_sub_inv, p_to_sub => lv_dest_sub_inv, p_item_id => NULL --l_header_tbl(j).inventory_item_id
                                                                                                                                                  , p_item_num => NULL --l_header_tbl(j).ordered_item
                                                                                                                                                                      , p_qty => ln_round_qty, p_uom_code => NULL --l_header_tbl(j).order_quantity_uom
                                                                                                                                                                                                                 , p_org_code => lv_org_code, p_orders_tbl => order_detail_tbl
                                   , p_move_tbl => build_detail_tbl);
            END IF;
        END LOOP;

        --    apps.fnd_file.put_line(apps.fnd_file.LOG,'step-11');
        IF ln_COUNT = 0 OR ln_process_COUNT = 0
        THEN
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                '#### No Eligible Items to Create the Move orders  for this Requested ####',
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '=============================================================================================================');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '***********************:Replenishment Move Orders Based on Sales Order Demand :******************************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '============================================================================================================');
            apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
            apps.fnd_file.put_line (apps.fnd_file.LOG, ' ');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Request Sbumitted By :-' || lv_user_name);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'From Date:-  ' || gv_from_date);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'To Date:-  ' || gv_to_date);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Organization:-' || gv_org_code);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Building:-' || gv_building);
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'Brand:-' || gv_brand);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'No Eligibel Sales Order Lines for this Requested');
        END IF;

        apps.DO_MAIL_UTILS.SEND_MAIL_LINE ('  ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE ('  ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
            '*************************END Of Move Orders********************************',
            gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE ('  ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE ('  ', gn_rtn_val);
        --Calling email error report procedure
        email_error_report;
        apps.DO_MAIL_UTILS.SEND_MAIL_CLOSE (gn_rtn_val);
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Internal error occured in process move order DC3 Proceudre'
                || SQLERRM);
    END;                                              --Process Move Order DC3

    PROCEDURE CREATE_MOVE_ORDER (p_org_id IN NUMBER, p_from_sub IN VARCHAR2, p_to_sub IN VARCHAR2, p_item_id IN NUMBER, p_item_num IN VARCHAR2, p_qty IN NUMBER, p_uom_code IN VARCHAR2, p_org_code IN VARCHAR2, p_orders_tbl IN Order_Tbl_Type1
                                 , p_move_tbl IN build_detail_table)
    IS
        -- Common Declarations
        ln_api_version           NUMBER := 1.0;
        lv_init_msg_list         VARCHAR2 (2) := apps.FND_API.G_TRUE;
        lv_return_values         VARCHAR2 (2) := apps.FND_API.G_FALSE;
        lv_commit                VARCHAR2 (2) := apps.FND_API.G_FALSE;

        -- WHO columns
        ln_user_id               NUMBER := apps.fnd_profile.VALUE ('USER_ID');
        ln_resp_id               NUMBER := apps.fnd_profile.VALUE ('RESP_ID');
        ln_application_id        NUMBER := apps.fnd_profile.VALUE ('RESP_APPL_ID');
        ln_login_id              NUMBER := apps.fnd_profile.VALUE ('login_id');

        -- API specific declarations
        l_trohdr_rec             apps.INV_MOVE_ORDER_PUB.TROHDR_REC_TYPE;
        l_trohdr_val_rec         apps.INV_MOVE_ORDER_PUB.TROHDR_VAL_REC_TYPE;
        x_trohdr_rec             apps.INV_MOVE_ORDER_PUB.TROHDR_REC_TYPE;
        x_trohdr_val_rec         apps.INV_MOVE_ORDER_PUB.TROHDR_VAL_REC_TYPE;
        l_validation_flag        VARCHAR2 (2)
                                     := apps.INV_MOVE_ORDER_PUB.G_VALIDATION_YES;
        x_return_status          VARCHAR2 (2);
        x_msg_COUNT              NUMBER := 0;
        x_msg_data               VARCHAR2 (2500);
        -- gn_rtn_val                      NUMBER:=0;

        -- API Lines table specific declarations
        l_trolin_tbl             apps.INV_MOVE_ORDER_PUB.TROLIN_TBL_TYPE;
        l_trolin_val_tbl         apps.INV_MOVE_ORDER_PUB.TROLIN_VAL_TBL_TYPE;
        x_trolin_tbl             apps.INV_MOVE_ORDER_PUB.TROLIN_TBL_TYPE;
        x_trolin_val_tbl         apps.INV_MOVE_ORDER_PUB.TROLIN_VAL_TBL_TYPE;
        --l_validation_flag           VARCHAR2(2) := INV_MOVE_ORDER_PUB.G_VALIDATION_YES;
        x_msg_index_out          NUMBER;
        l_error_message          VARCHAR2 (2000) := NULL;
        l_row_cnt                NUMBER := 1;
        ln_transaction_type_id   NUMBER := 64;
        ln_move_order_type       NUMBER := 2;
        lv_move_order_num        NUMBER := 0;

        lv_uom_code              VARCHAR2 (10);
        lv_move_order_sts        VARCHAR2 (25);
    BEGIN
        APPS.FND_GLOBAL.APPS_INITIALIZE (ln_user_id,
                                         ln_resp_id,
                                         ln_application_id);

        BEGIN
            SELECT TO_NUMBER (TO_CHAR (SYSDATE, 'YYYYMM') || xxdo.xxdorep_move_order.NEXTVAL)
              INTO lv_move_order_num
              FROM DUAL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Unable to get the sequence');
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Internal error occured while getting sequence number'
                    || 'ERROR: '
                    || SQLERRM);
        END;

        -- header initialization++
        l_trohdr_rec.date_required            := SYSDATE;
        l_trohdr_rec.organization_id          := p_org_id;
        l_trohdr_rec.from_subinventory_code   := p_from_sub;
        l_trohdr_rec.to_subinventory_code     := p_to_sub;
        l_trohdr_rec.status_date              := SYSDATE;
        l_trohdr_rec.request_number           := lv_move_order_num;
        l_trohdr_rec.header_status            :=
            apps.INV_Globals.G_TO_STATUS_PREAPPROVED;
        l_trohdr_rec.transaction_type_id      := ln_transaction_type_id; --INV_GLOBALS.G_TYPE_TRANSFER_ORDER_SUBXFR; -- INV_GLOBALS.G_TYPE_TRANSFER_ORDER_STGXFR; --;
        l_trohdr_rec.move_order_type          := ln_move_order_type; --INV_GLOBALS.G_MOVE_ORDER_REQUISITION; -- G_MOVE_ORDER_PICK_WAVE;
        l_trohdr_rec.db_flag                  := apps.FND_API.G_TRUE;
        l_trohdr_rec.operation                :=
            apps.INV_GLOBALS.G_OPR_CREATE;

        -- Who columns
        l_trohdr_rec.created_by               := ln_user_id;
        l_trohdr_rec.creation_date            := SYSDATE;
        l_trohdr_rec.last_updated_by          := ln_user_id;
        l_trohdr_rec.last_update_date         := SYSDATE;
        l_trohdr_rec.last_update_login        := apps.FND_GLOBAL.login_id;

        FOR k IN 1 .. p_move_tbl.COUNT
        LOOP
            -- lines initalization
            l_trolin_tbl (k).header_id                := NULL;
            l_trolin_tbl (k).date_required            := SYSDATE;
            l_trolin_tbl (k).organization_id          :=
                p_move_tbl (k).ship_from_org_id;
            l_trolin_tbl (k).inventory_item_id        :=
                p_move_tbl (k).inventory_item_id;
            l_trolin_tbl (k).from_subinventory_code   := p_from_sub;
            l_trolin_tbl (k).to_subinventory_code     := p_to_sub;
            l_trolin_tbl (k).quantity                 :=
                p_move_tbl (k).ordered_quantity;
            l_trolin_tbl (k).status_date              := SYSDATE;
            l_trolin_tbl (k).uom_code                 :=
                p_move_tbl (k).order_quantity_uom;
            l_trolin_tbl (k).line_number              := k;
            l_trolin_tbl (k).line_status              :=
                apps.INV_Globals.G_TO_STATUS_PREAPPROVED;
            l_trolin_tbl (k).db_flag                  := apps.FND_API.G_TRUE;
            l_trolin_tbl (k).operation                :=
                apps.INV_GLOBALS.G_OPR_CREATE;
            -- Who columns
            l_trolin_tbl (k).created_by               := ln_user_id;
            l_trolin_tbl (k).creation_date            := SYSDATE;
            l_trolin_tbl (k).last_updated_by          := ln_user_id;
            l_trolin_tbl (k).last_update_date         := SYSDATE;
            l_trolin_tbl (k).last_update_login        :=
                apps.FND_GLOBAL.login_id;

            --Set the move order lines DFF(attribute7) with the building code for DC3 org move order lines, as part of DC3.4 Expansion Project

            --Start changes by BT Technology Team for BT on 17-Nov-2014,  v1.1
            --IF     gn_organization_id = 152
            --   AND p_move_tbl (k).building_code <> 'DC3'
            --THEN
            --End changes by BT Technology Team for BT on 17-Nov-2014,  v1.1
            l_trolin_tbl (k).attribute7               :=
                p_move_tbl (k).building_code;
        --END IF;--Commented by BT Technology Team for BT on 17-Nov-2014,  v1.1
        END LOOP;

        -- call API to create move order header

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Calling INV_MOVE_ORDER_PUB.Create_Move_Order_Header API');

        apps.INV_MOVE_ORDER_PUB.Process_Move_Order (
            P_API_VERSION_NUMBER   => ln_api_version,
            P_INIT_MSG_LIST        => lv_init_msg_list,
            P_RETURN_VALUES        => lv_return_values,
            P_COMMIT               => lv_commit,
            X_RETURN_STATUS        => x_return_status,
            X_MSG_COUNT            => x_msg_COUNT,
            X_MSG_DATA             => x_msg_data,
            P_TROHDR_REC           => l_trohdr_rec,
            P_TROHDR_VAL_REC       => l_trohdr_val_rec,
            P_TROLIN_TBL           => l_trolin_tbl,
            P_TROLIN_VAL_TBL       => l_trolin_val_tbl,
            X_TROHDR_REC           => x_trohdr_rec,
            X_TROHDR_VAL_REC       => x_trohdr_val_rec,
            X_TROLIN_TBL           => x_trolin_tbl,
            X_TROLIN_VAL_TBL       => x_trolin_val_tbl);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Return Status-' || x_return_status);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'error message-' || x_msg_data);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'error message count-' || x_msg_COUNT);

        IF x_return_status = apps.fnd_api.g_ret_sts_success
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Replenish Move Order Creation is Success and Move Order Number is  :'
                || '==='
                || x_trohdr_rec.request_number
                || '==='
                || x_trohdr_rec.header_status);
            apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');

            BEGIN
                SELECT ml.MEANING
                  INTO lv_move_order_sts
                  FROM apps.MFG_LOOKUPS ml
                 WHERE     ml.LOOKUP_TYPE = 'MTL_TXN_REQUEST_STATUS'
                       AND ml.LOOKUP_CODE = x_trohdr_rec.header_status;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Unable to get the move order status');
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Internal error occured while getting move order status');
            END;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '=================================================================================================================================');
            apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
            apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('Move Order Num', 20, ' ')
                || ' '
                || RPAD ('Move Order Satus', 18, ' ')
                || ' '
                || RPAD ('Organization Code', 19, ' ')
                || ' '
                || RPAD ('STATUS', 15, ' '),
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('==============', 20, ' ')
                || ' '
                || RPAD ('================', 18, ' ')
                || ' '
                || RPAD ('=================', 19, ' ')
                || ' '
                || RPAD ('=======', 15, ' '),
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD (x_trohdr_rec.request_number, 20, ' ')
                || ' '
                || RPAD (lv_move_order_sts, 18, ' ')
                || ' '
                || RPAD (p_org_code, 19, ' ')
                || ' '
                || RPAD ('Success', 15, ' '),
                gn_rtn_val);

            UPDATE_PROCESSED_RECORDS (p_order_detail_tbl   => p_orders_tbl,
                                      p_sku_tbl            => p_move_tbl);

            COMMIT;

            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ', gn_rtn_val);
        ELSE
            BEGIN
                IF (apps.fnd_msg_pub.COUNT_msg > 1)
                THEN
                    FOR k IN 1 .. apps.fnd_msg_pub.COUNT_msg
                    LOOP
                        apps.fnd_msg_pub.get (
                            p_msg_index       => k,
                            p_encoded         => 'F',
                            p_data            => x_msg_data,
                            p_msg_index_out   => x_msg_index_out);

                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'x_msg_data:= ' || x_msg_data);

                        IF x_msg_data IS NOT NULL
                        THEN
                            l_error_message   :=
                                l_error_message || '-' || x_msg_data;
                        END IF;
                    END LOOP;

                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Error Occured Wile Creating the move order ');
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Error Message is   :-' || l_error_message);
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        '=============================================================================================');
                    apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
                    apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');

                    gv_err_msg   := gv_err_msg || l_error_message;
                    UPDATE_STG_TBL (p_update_tbl    => p_orders_tbl,
                                    p_status_code   => 'E');
                ELSE
                    --Only one error
                    apps.fnd_msg_pub.get (
                        p_msg_index       => 1,
                        p_encoded         => 'F',
                        p_data            => x_msg_data,
                        p_msg_index_out   => x_msg_index_out);
                    l_error_message   := l_error_message || x_msg_data;
                    gv_err_msg        := gv_err_msg || l_error_message;
                    UPDATE_STG_TBL (p_update_tbl    => p_orders_tbl,
                                    p_status_code   => 'E');
                END IF;

                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Error Occured Wile Creating the move order ');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error Message is   :-'
                    || l_error_message
                    || 'gv_err msg-'
                    || gv_err_msg);
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    '==================================================================================================================');
                apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
                apps.fnd_file.put_line (apps.fnd_file.LOG, '    ');
            --   ROLLBACK;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_error_message   := SQLERRM;
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error encountered by the API is :'
                        || l_error_message
                        || '  '
                        || 'ERROR: '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_error_message   := SQLERRM;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error encountered by the API is :'
                || l_error_message
                || '  '
                || 'ERROR: '
                || SQLERRM);
    END;

    PROCEDURE UPDATE_STG_TBL (p_update_tbl    IN Order_Tbl_Type1,
                              p_status_code   IN VARCHAR2)
    IS
    BEGIN
        FOR i IN p_update_tbl.FIRST .. p_update_tbl.LAST
        LOOP
            IF p_update_tbl (i).flag = 'Y'
            THEN
                UPDATE xxdo.xxdooe_lines_stg ols
                   SET ols.status_code = NVL (p_status_code, 'E'), ols.status_msg = gv_err_msg, ols.last_update_date = SYSDATE,
                       ols.last_updated_by = gn_updated_by
                 WHERE     ols.header_id = p_update_tbl (i).header_id
                       AND ols.line_id = p_update_tbl (i).line_id;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'error occured while updating the staging table'
                || '  '
                || 'ERROR: '
                || SQLERRM);
    END;

    PROCEDURE UPDATE_PROCESSED_RECORDS (p_order_detail_tbl IN Order_Tbl_Type1, p_sku_tbl IN build_detail_table)
    IS
        -- gn_rtn_val NUMBER:=0;
        --     PRAGMA AUTONOMOUS_TRANSACTION;
        CURSOR orders_cur (cp_item_id NUMBER, cp_org_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxdooe_lines_stg stg
             WHERE     stg.inventory_item_id = TRIM (cp_item_id)
                   AND stg.ship_from_org_id = TRIM (cp_org_id)
                   AND stg.source_code = 'REPLENISH'
                   AND NVL (stg.ATTRIBUTE2, 0) <> 0
                   AND stg.STATUS_CODE <> 'P';
    --  ln_cnt number;
    BEGIN
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);

        FOR k IN p_sku_tbl.FIRST .. p_sku_tbl.LAST
        LOOP
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('  ', 20)
                || ' '
                || RPAD ('SKU', 30, ' ')
                || ' '
                || RPAD ('From Subinventory', 18, ' ')
                || ' '
                || RPAD ('To Subinventory', 19, ' ')
                || ' '
                || RPAD ('Ordered Quantity', 18, ' ')
                || ' '
                || RPAD ('Required Qty', 12, ' ')
                || ' '
                || RPAD ('Pair Pick Qty', 13, ' ')
                || ' '
                || RPAD ('Case Pick Qty', 13, ' ')
                || ' '
                || RPAD ('QA Sub inv Qty', 14, ' ')
                || ' '
                || RPAD ('Return Sub inv Qty', 18, ' ')
                || ' '
                || RPAD ('Receiving Sub inv Qty', 21, ' '),
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('  ', 20)
                || ' '
                || RPAD (':::::::::::::::::::', 30, ' ')
                || ' '
                || RPAD ('::::::::::::::::::', 18, ' ')
                || ' '
                || RPAD ('::::::::::::::::::', 19, ' ')
                || ' '
                || RPAD ('::::::::::::::::::', 18, ' ')
                || ' '
                || RPAD (':::::::::::::', 12, ' ')
                || ' '
                || RPAD ('::::::::::::', 13, ' ')
                || ' '
                || RPAD ('::::::::::::', 13, ' ')
                || ' '
                || RPAD (':::::::::::::', 14, ' ')
                || ' '
                || RPAD (':::::::::::::::::', 18, ' ')
                || ' '
                || RPAD ('::::::::::::::::::::', 21, ' ')
                || ' ',
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('  ', 20)
                || ' '
                || RPAD (apps.IID_TO_SKU (p_sku_tbl (k).inventory_item_id),
                         30,
                         ' ')
                || ' '
                || RPAD (p_sku_tbl (k).from_sub_inv, 18, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).to_sub_inv, 19, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).ordered_quantity, 18, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).required_qty, 12, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).pair_pick_qty, 13, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).case_pick_qty, 13, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).qa_subinv_onhand, 14, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).rtn_subinv_onhand, 18, ' ')
                || ' '
                || RPAD (p_sku_tbl (k).rcv_subinv_onhand, 21, ' '),
                gn_rtn_val);
            -- apps.DO_MAIL_UTILS.SEND_MAIL_LINE(' '||' ',gn_rtn_val );

            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('  ', 20)
                || ' '
                || RPAD ('Order Number', 20, ' ')
                || ' '
                || RPAD ('Line Num', 18, ' ')
                || ' '
                || RPAD ('Ordered Quantity', 19, ' ')
                || ' '
                || RPAD ('Considered Quantity', 19, ' '),
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD ('  ', 20)
                || ' '
                || RPAD ('- - - - - - - - -', 20, ' ')
                || ' '
                || RPAD ('- - - - - - - - -', 18, ' ')
                || ' '
                || RPAD ('- - - - - - - - -', 19, ' ')
                || ' '
                || RPAD ('- - - - - - - - -', 19, ' '),
                gn_rtn_val);

            FOR j
                IN orders_cur (p_sku_tbl (k).inventory_item_id,
                               p_sku_tbl (k).ship_from_org_id)
            LOOP
                apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                       RPAD ('  ', 20)
                    || ' '
                    || RPAD (hdr_id_to_order (j.header_id), 20)
                    || ' '
                    || RPAD (j.line_number, 18)
                    || ' '
                    || RPAD (j.ordered_quantity, 19)
                    || ' '
                    || RPAD (j.attribute2, 18) --attribute2 is calculated quantity of each line
                                              ,
                    gn_rtn_val);

                UPDATE apps.wsh_delivery_details wdd
                   SET wdd.attribute3   = 'Y'
                 WHERE     wdd.source_header_id = j.header_id
                       AND wdd.source_line_id = j.line_id;

                UPDATE xxdo.xxdooe_lines_stg stg
                   SET stg.STATUS_CODE = 'S', stg.STATUS_MSG = 'Success'
                 WHERE     stg.header_id = j.header_id
                       AND stg.line_id = j.line_id
                       AND stg.source_code = 'REPLENISH';
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Internal error occured while updating the processed records  '
                || 'ERROR: '
                || SQLERRM);
    END;

    FUNCTION IID_TO_BRAND (pn_item_id   IN NUMBER,
                           pn_org_id    IN NUMBER DEFAULT 7)
        RETURN VARCHAR2
    IS
        lv_brand   VARCHAR2 (100);
    BEGIN
        SELECT mc.segment1
          INTO lv_brand
          FROM apps.mtl_system_items_b msib, apps.mtl_categories mc, apps.mtl_item_categories mic,
               apps.FND_ID_FLEX_STRUCTURES_VL fls
         WHERE     msib.INVENTORY_ITEM_ID = mic.INVENTORY_ITEM_ID
               AND msib.ORGANIZATION_ID = mic.ORGANIZATION_ID
               AND mic.CATEGORY_ID = mc.CATEGORY_ID
               AND mc.STRUCTURE_ID = fls.ID_FLEX_NUM
               AND fls.ID_FLEX_STRUCTURE_NAME = 'Item Categories'
               AND msib.organization_id = pn_org_id
               AND msib.INVENTORY_ITEM_ID = pn_item_id;

        RETURN lv_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_brand   := NULL;
            RETURN lv_brand;
    END;

    FUNCTION hdr_id_to_order (pn_header_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_order_number   apps.oe_order_headers_all.order_number%TYPE;
    BEGIN
        SELECT ooh.order_number
          INTO ln_order_number
          FROM apps.oe_order_headers_all ooh
         WHERE ooh.header_id = pn_header_id;

        RETURN ln_order_number;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN ln_order_number;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN ln_order_number;
        WHEN OTHERS
        THEN
            RETURN ln_order_number;
    END;

    PROCEDURE UPDATE_MOD_QTY (pn_header_id          IN NUMBER,
                              pn_line_id            IN NUMBER,
                              pn_item_id            IN NUMBER,
                              pn_ship_from_org_id   IN NUMBER,
                              pn_mod_qty            IN NUMBER)
    IS
    BEGIN
        UPDATE xxdo.xxdooe_lines_stg stg
           SET stg.attribute2   = pn_mod_qty
         WHERE     stg.header_id = pn_header_id
               AND stg.line_id = pn_line_id
               AND stg.INVENTORY_ITEM_ID = pn_item_id
               AND stg.SHIP_FROM_ORG_ID = pn_ship_from_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured in update_mod_qty for - header_id,line_id,item_id-'
                || pn_header_id
                || ','
                || pn_line_id
                || ','
                || pn_item_id
                || ' -  error msg-'
                || SQLERRM);
    END;

    FUNCTION ATR_QTY (pn_item_id       IN NUMBER,
                      pn_org_id        IN NUMBER,
                      pv_subinv_code   IN VARCHAR2)
        RETURN NUMBER
    IS
        x_return_status          VARCHAR2 (50);
        x_msg_COUNT              VARCHAR2 (50);
        x_msg_data               VARCHAR2 (50);
        ln_item_id               NUMBER;
        ln_organization_id       NUMBER;
        lv_subinventory_code     VARCHAR2 (20);
        ln_qty_on_hand           NUMBER;
        ln_res_qty_on_hand       NUMBER;
        ln_avail_to_tnsct        NUMBER;
        ln_avail_to_reserve      NUMBER;
        ln_qty_reserved          NUMBER;
        ln_qty_suggested         NUMBER;
        lb_lot_control_code      BOOLEAN;
        lb_serial_control_code   BOOLEAN;
        ln_user_id               NUMBER := apps.fnd_profile.VALUE ('USER_ID');
        ln_resp_id               NUMBER := apps.fnd_profile.VALUE ('RESP_ID');
        ln_application_id        NUMBER
            := apps.fnd_profile.VALUE ('RESP_APPL_ID'); -- Set the org context
        ln_login_id              NUMBER
                                     := apps.fnd_profile.VALUE ('LOGIN_ID');
    BEGIN
        apps.FND_GLOBAL.apps_initialize (user_id        => ln_user_id,
                                         resp_id        => ln_resp_id,
                                         resp_appl_id   => ln_application_id); --,security_group_id => 0);
        apps.inv_quantity_tree_grp.clear_quantity_cache; -- Clear Quantity cache
        -- Set the variable values
        ln_item_id               := pn_item_id;
        ln_organization_id       := pn_org_id;
        lv_subinventory_code     := pv_subinv_code;
        lb_lot_control_code      := FALSE;

        --Only When Lot number is passed  TRUE else FALSE
        lb_serial_control_code   := FALSE;

        -- Call API
        -- apps.fnd_file.put_line(apps.fnd_file.LOG,'Getting the available to ');
        DBMS_OUTPUT.put_line (
               'CVC......Before calling API.. '
            || ln_item_id
            || ln_organization_id
            || lv_subinventory_code);
        apps.inv_quantity_tree_pub.query_quantities (
            p_api_version_number    => 1.0,
            p_init_msg_lst          => NULL,
            x_return_status         => x_return_status,
            x_msg_COUNT             => x_msg_COUNT,
            x_msg_data              => x_msg_data,
            p_organization_id       => ln_organization_id,
            p_inventory_item_id     => ln_item_id,
            p_tree_mode             =>
                apps.inv_quantity_tree_pub.g_transaction_mode,
            p_is_revision_control   => FALSE,
            p_is_lot_control        => lb_lot_control_code,
            p_is_serial_control     => lb_serial_control_code,
            p_revision              => NULL,
            p_lot_number            => NULL,
            p_lot_expiration_date   => SYSDATE,
            p_subinventory_code     => lv_subinventory_code,
            p_locator_id            => NULL --,p_cost_group_id          => NULL
                                           --,p_onhand_source          => NULL
            ,
            x_qoh                   => ln_qty_on_hand,
            x_rqoh                  => ln_res_qty_on_hand,
            x_qr                    => ln_qty_reserved,
            x_qs                    => ln_qty_suggested,
            x_att                   => ln_avail_to_tnsct,
            x_atr                   => ln_avail_to_reserve);
        DBMS_OUTPUT.put_line (
               'CVC......After calling API.. '
            || ln_item_id
            || ln_organization_id
            || lv_subinventory_code
            || ln_qty_on_hand);
        DBMS_OUTPUT.put_line (
               'CVC......x_return_status :.. '
            || x_return_status
            || '+'
            || ln_avail_to_reserve);

        IF (x_return_status = 'S')
        THEN
            -- apps.fnd_file.put_line(apps.fnd_file.LOG,'Available to reser qty is:-'||ln_avail_to_reserve);
            RETURN (ln_avail_to_reserve);
        ELSE
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'error getting the available to reserve quantity');
            ln_avail_to_reserve   := 0;
            RETURN (ln_avail_to_reserve);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Internal error getting the available to reserve quantity   '
                || 'ERROR: '
                || SQLERRM);
    END;

    FUNCTION ATT_QTY (pn_item_id       IN NUMBER,
                      pn_org_id        IN NUMBER,
                      pv_subinv_code   IN VARCHAR2)
        RETURN NUMBER
    IS
        x_return_status          VARCHAR2 (50);
        x_msg_COUNT              VARCHAR2 (50);
        x_msg_data               VARCHAR2 (50);
        ln_item_id               NUMBER;
        ln_organization_id       NUMBER;
        lv_subinventory_code     VARCHAR2 (20);
        ln_qty_on_hand           NUMBER;
        ln_res_qty_on_hand       NUMBER;
        ln_avail_to_tnsct        NUMBER;
        ln_avail_to_reserve      NUMBER;
        ln_qty_reserved          NUMBER;
        ln_qty_suggested         NUMBER;
        lb_lot_control_code      BOOLEAN;
        lb_serial_control_code   BOOLEAN;
        ln_user_id               NUMBER := apps.fnd_profile.VALUE ('USER_ID');
        ln_resp_id               NUMBER := apps.fnd_profile.VALUE ('RESP_ID');
        ln_application_id        NUMBER
            := apps.fnd_profile.VALUE ('RESP_APPL_ID'); -- Set the org context
        ln_login_id              NUMBER
                                     := apps.fnd_profile.VALUE ('LOGIN_ID');
    BEGIN
        apps.FND_GLOBAL.apps_initialize (user_id        => ln_user_id,
                                         resp_id        => ln_resp_id,
                                         resp_appl_id   => ln_application_id); --,security_group_id => 0);
        apps.inv_quantity_tree_grp.clear_quantity_cache; -- Clear Quantity cache
        -- Set the variable values
        ln_item_id               := pn_item_id;
        ln_organization_id       := pn_org_id;
        lv_subinventory_code     := pv_subinv_code;
        lb_lot_control_code      := FALSE;

        --Only When Lot number is passed  TRUE else FALSE
        lb_serial_control_code   := FALSE;

        apps.inv_quantity_tree_pub.query_quantities (
            p_api_version_number    => 1.0,
            p_init_msg_lst          => NULL,
            x_return_status         => x_return_status,
            x_msg_COUNT             => x_msg_COUNT,
            x_msg_data              => x_msg_data,
            p_organization_id       => ln_organization_id,
            p_inventory_item_id     => ln_item_id,
            p_tree_mode             =>
                apps.inv_quantity_tree_pub.g_transaction_mode,
            p_is_revision_control   => FALSE,
            p_is_lot_control        => lb_lot_control_code,
            p_is_serial_control     => lb_serial_control_code,
            p_revision              => NULL,
            p_lot_number            => NULL,
            p_lot_expiration_date   => SYSDATE,
            p_subinventory_code     => lv_subinventory_code,
            p_locator_id            => NULL --,p_cost_group_id          => NULL
                                           --,p_onhand_source          => NULL
            ,
            x_qoh                   => ln_qty_on_hand,
            x_rqoh                  => ln_res_qty_on_hand,
            x_qr                    => ln_qty_reserved,
            x_qs                    => ln_qty_suggested,
            x_att                   => ln_avail_to_tnsct,
            x_atr                   => ln_avail_to_reserve);

        IF (x_return_status = 'S')
        THEN
            RETURN (ln_avail_to_tnsct);
        ELSE
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'error getting the available to reserve quantity');
            ln_avail_to_tnsct   := 0;
            RETURN (ln_avail_to_tnsct);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Internal error getting the available to reserve quantity   '
                || 'ERROR: '
                || SQLERRM);
    END;

    PROCEDURE email_error_report
    IS
        CURSOR err_cur IS
              SELECT ols.ordered_item,
                     ols.inventory_item_id,
                     (SELECT ood.organization_code
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = ols.ship_from_org_id)
                         organization_code,
                     ols.order_quantity_uom,
                     ols.status_code,
                     ols.status_msg
                FROM xxdo.xxdooe_lines_stg ols
               WHERE ols.status_code = 'E' AND ols.request_id = gn_request_id
            GROUP BY ols.ordered_item, ols.inventory_item_id, ols.ship_from_org_id,
                     ols.order_quantity_uom, ols.status_code, ols.status_msg;
    BEGIN
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (RPAD ('-', 80, '-'), gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
            'Replenishment Move Orders Based on Sales Order Demand - Deckers Report - Errored Rows',
            gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (RPAD ('-', 80, '-'), gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   ,
            gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
               RPAD ('Ordered_item', 20, ' ')
            || '|'
            || RPAD ('Inventory_item_id', 20, ' ')
            || '|'
            || RPAD ('Organization Code', 20, ' ')
            || '|'
            || RPAD ('Order_quantity_uom ', 19, ' ')
            || '|'
            || RPAD ('Status', 7, ' ')
            || '|'
            || RPAD ('Error Message', 200, ' ')                     --  || '|'
                                               ,
            gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
               RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 19, '-')
            || '|'
            || RPAD ('-', 7, '-')
            || '|'
            || RPAD ('-', 200, '-')                                --   || '|'
                                   ,
            gn_rtn_val);

        FOR error_rec IN err_cur
        LOOP
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD (NVL (NVL (error_rec.ordered_item, ' '), ' '),
                         20,
                         ' ')
                || '|'
                || RPAD (NVL (error_rec.inventory_item_id, 0), 20, ' ')
                || '|'
                || RPAD (NVL (error_rec.organization_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (error_rec.order_quantity_uom, ' '), 19, ' ')
                || '|'
                || RPAD (NVL (error_rec.status_code, ' '), 7, ' ')
                || '|'
                || RPAD (NVL (error_rec.status_msg, ' '), 200, ' ') --        || '|'
                                                                   ,
                gn_rtn_val);

            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ', gn_rtn_val);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in :- Email error Report Procedure - > ' || SQLERRM);
    END;

    PROCEDURE MAIN_PROC (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_from_date IN VARCHAR2, p_to_date IN VARCHAR2, p_inv_org_id IN NUMBER, p_building IN VARCHAR2
                         , p_brand IN VARCHAR2)
    IS
        lv_org_code   VARCHAR2 (10);
    BEGIN
        gv_from_date         := p_from_date;
        gv_to_date           := p_to_date;
        gn_organization_id   := p_inv_org_id;
        gv_brand             := p_brand;
        gv_building          := p_building;

        BEGIN
            SELECT fpg.applications_system_name
              INTO gv_instance
              FROM apps.fnd_product_groups fpg;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                gv_instance   := NULL;
            WHEN OTHERS
            THEN
                gv_instance   := NULL;
        END;

        BEGIN
            SELECT ood.organization_code
              INTO lv_org_code
              FROM apps.org_organization_definitions ood
             WHERE ood.organization_id = p_inv_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_org_code   := NULL;
        END;

        gv_org_code          := lv_org_code;

        insert_rows;
        Process_orders;
        print_report;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error occured in main Procedure-' || SQLERRM);
    END;                                                                --Main
END;                                              --XXDOINV_REP_MOVE_ORDER_PKG
/
