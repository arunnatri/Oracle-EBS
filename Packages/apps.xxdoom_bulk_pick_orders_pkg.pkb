--
-- XXDOOM_BULK_PICK_ORDERS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM_BULK_PICK_ORDERS_PKG"
AS
    /*
      REM $Header: XXDOOM_BULK_PICK_ORDERS_PKG.PKS 1.0 18-Oct-2012 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM ===================================================================================================
      REM
      REM Name          : XXDOOM_BULK_PICK_ORDERS_PKG.PKS
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
      REM Venkata Rama Battu     18-OCT-2012         1.0                 1. Base lined for delivery
      REM
      REM ===================================================================================================
      */
    gn_rtn_val           NUMBER := 0;
    gn_org_id            NUMBER;                               --:=732; --152;
    gn_cust_account_id   NUMBER;
    gv_from_date         VARCHAR2 (30);
    gv_to_date           VARCHAR2 (30);
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_updated_by        NUMBER := apps.fnd_global.user_id;
    gn_request_id        NUMBER := apps.fnd_global.conc_request_id;
    gv_shipment_type     apps.oe_order_lines_all.shipment_priority_code%TYPE
                             := 'PB26';                       --PB26=Bulk Pick
    gv_bulk_sub_inv      VARCHAR2 (10);
    gv_flow_sub_inv      VARCHAR2 (10);
    gn_user_id           NUMBER := apps.fnd_profile.VALUE ('USER_ID');
    gn_resp_id           NUMBER := apps.fnd_profile.VALUE ('RESP_ID');
    gn_appl_id           NUMBER := apps.fnd_profile.VALUE ('RESP_APPL_ID');
    gv_cust_po           VARCHAR2 (2000);
    gn_pri_ship_loc      NUMBER;

    --gn_ship_loc                NUMBER;
    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_cust_accout_id IN NUMBER, pv_from_date IN VARCHAR2, pv_to_date IN VARCHAR2, pv_organization_id IN NUMBER
                    , pv_cust_po IN VARCHAR2)
    IS
    BEGIN
        gn_cust_account_id   := pv_cust_accout_id;
        gv_from_date         := pv_from_date;
        gv_to_date           := pv_to_date;
        gn_org_id            := pv_organization_id;
        gv_cust_po           := UPPER (pv_cust_po);

        update_ship_priority;
        insert_stg;
        process_bp_orders;
        email_bptype;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured in the main Procedure and error code is -'
                || SQLERRM);
    END;                                                               -- main


    PROCEDURE update_ship_priority
    IS
        CURSOR order_cur IS
            SELECT ooh.header_id, ool.line_id, ool.SHIPMENT_PRIORITY_CODE,
                   ool.ship_to_org_id
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     TRUNC (ool.request_date) >=
                       TRUNC (
                           TO_DATE (gv_from_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND TRUNC (ool.request_date) <=
                       TRUNC (TO_DATE (gv_to_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND ooh.header_id = ool.header_id
                   AND ool.sold_to_org_id = gn_cust_account_id
                   AND ool.SHIP_FROM_ORG_ID = gn_org_id
                   AND UPPER (ooh.CUST_PO_NUMBER) IN
                           (    SELECT REGEXP_SUBSTR (gv_cust_po, '[^,]+', 1
                                                      , LEVEL)
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR (gv_cust_po, '[^,]+', 1,
                                                      LEVEL)
                                           IS NOT NULL)
                   -- AND  ooh.SHIPMENT_PRIORITY_CODE   <> 'PB26'
                   AND 1 = qty_reserved (ool.header_id, ool.line_id, ool.order_quantity_uom
                                         , ool.inventory_item_id)
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_Details wdd
                             WHERE     wdd.source_header_id = ooh.header_id
                                   AND wdd.source_line_id = ool.line_id
                                   AND wdd.released_status IN ('R', 'B')
                                   AND NVL (wdd.attribute1, 'N') = 'N');


        order_tbl                        order_tbl1;

        err_tbl                          err_tbl1;

        lv_ship_code                     VARCHAR2 (30);
        lv_old_ship_code                 VARCHAR2 (30);
        ln_resp_id                       NUMBER;
        ln_application_id                NUMBER;
        --    Variable Declerations for ORDER Lines Decklerations
        ln_api_version_number            NUMBER := 1;
        lv_return_status                 VARCHAR2 (2000);
        ln_msg_count                     NUMBER;
        lv_msg_data                      VARCHAR2 (2000);
        -- IN Variables --
        header_rec_rectype               apps.oe_order_pub.header_rec_type;
        line_tbl_tabtype                 apps.oe_order_pub.line_tbl_type;
        action_request_tabtype           apps.oe_order_pub.request_tbl_type;
        line_adj_tabtype                 apps.oe_order_pub.line_adj_tbl_type;
        -- OUT Variables--
        header_rec_out_rectype           apps.oe_order_pub.header_rec_type;
        header_val_rec_out_rectype       apps.oe_order_pub.header_val_rec_type;
        header_adj_tbl_out_tabtype       apps.oe_order_pub.header_adj_tbl_type;
        header_adj_val_out_tabtype       apps.oe_order_pub.header_adj_val_tbl_type;
        header_price_att_out_tabtype     apps.oe_order_pub.header_price_att_tbl_type;
        header_adj_att_out_tabtype       apps.oe_order_pub.header_adj_att_tbl_type;
        header_adj_assoc_out_tabtype     apps.oe_order_pub.header_adj_assoc_tbl_type;
        header_scredit_tbl_tabtype       apps.oe_order_pub.header_scredit_tbl_type;
        header_scredit_val_tabtype       apps.oe_order_pub.header_scredit_val_tbl_type;
        line_tbl_out_tabtype             apps.oe_order_pub.line_tbl_type;
        line_val_tbl_out_tabtype         apps.oe_order_pub.line_val_tbl_type;
        line_adj_tbl_out_tabtype         apps.oe_order_pub.line_adj_tbl_type;
        line_adj_val_tbl_out_tabtype     apps.oe_order_pub.line_adj_val_tbl_type;
        line_price_att_tbl_tabtype       apps.oe_order_pub.line_price_att_tbl_type;
        line_adj_att_tbl_out_tabtype     apps.oe_order_pub.line_adj_att_tbl_type;
        line_adj_assoc_tbl_tabtype       apps.oe_order_pub.line_adj_assoc_tbl_type;
        line_scredit_tbl_out_tabtype     apps.oe_order_pub.line_scredit_tbl_type;
        line_scredit_val_tbl_tabtype     apps.oe_order_pub.line_scredit_val_tbl_type;
        lot_serial_tbl_out_tabtype       apps.oe_order_pub.lot_serial_tbl_type;
        lot_serial_val_tbl_out_tabtype   apps.oe_order_pub.lot_serial_val_tbl_type;
        action_request_tbl_tabtype       apps.oe_order_pub.request_tbl_type;
        v_msg_data                       VARCHAR2 (2000);
        lv_err_msg                       VARCHAR2 (2000);
        ln_err_cnt                       NUMBER := 0;
    BEGIN
        err_tbl.DELETE;

        order_tbl.DELETE;
        gn_pri_ship_loc    := 0;

        BEGIN
            SELECT flv.lookup_code
              INTO lv_ship_code
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'SHIPMENT_PRIORITY'
                   AND flv.meaning = 'Bulk Pick'
                   AND flv.LANGUAGE = USERENV ('LANG');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_ship_code   := 'PB26';
            WHEN OTHERS
            THEN
                lv_ship_code   := 'PB26';
        END;

        BEGIN
            SELECT DISTINCT hcsu.site_use_id
              INTO gn_pri_ship_loc
              FROM apps.hz_cust_accounts hca, apps.hz_cust_acct_sites_all hcas, apps.hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = gn_cust_account_id   --2020--3403
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND hcsu.primary_flag = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                gn_pri_ship_loc   := 0;
            WHEN OTHERS
            THEN
                gn_pri_ship_loc   := 0;
        END;

        BEGIN
            SELECT frt.application_id, frt.responsibility_id
              INTO ln_application_id, ln_resp_id
              FROM applsys.fnd_responsibility_tl frt
             WHERE     frt.responsibility_name =
                       'Deckers Order Management Super User - US'
                   AND frt.language = USERENV ('LANG');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_application_id   := 0;
                ln_resp_id          := 0;
            WHEN OTHERS
            THEN
                ln_application_id   := 0;
                ln_resp_id          := 0;
        END;

        apps.FND_GLOBAL.APPS_INITIALIZE (gn_user_id,
                                         ln_resp_id,
                                         ln_application_id);


        lv_old_ship_code   := NULL;

        OPEN order_cur;

        FETCH order_cur BULK COLLECT INTO order_tbl;

        CLOSE order_cur;

        --IF lt_item_glo.COUNT > 0 THEN
        FOR i IN 1 .. order_tbl.COUNT
        LOOP
            IF i = 1 AND gn_pri_ship_loc = 0
            THEN
                gn_pri_ship_loc   := order_tbl (i).lv_ship_to_org_id;
            END IF;

            lv_old_ship_code                               := order_tbl (i).lv_ship_prio_code;
            --Line Record --
            line_tbl_tabtype (1)                           := apps.oe_order_pub.g_miss_line_rec;
            line_tbl_tabtype (1).operation                 := apps.OE_GLOBALS.G_OPR_UPDATE;
            line_tbl_tabtype (1).SHIPMENT_PRIORITY_CODE    := lv_ship_code; --Updating SHIPMENT_PRIORITY_CODE to Bulk Pick
            line_tbl_tabtype (1).intermed_ship_to_org_id   := gn_pri_ship_loc; --Updating Intermediate ship to org id
            line_tbl_tabtype (1).header_id                 :=
                order_tbl (i).ln_header_id;         --Existing order header id
            line_tbl_tabtype (1).line_id                   :=
                order_tbl (i).ln_line_id;             --Existing order line id
            line_tbl_tabtype (1).last_updated_by           := gn_user_id;
            line_tbl_tabtype (1).last_update_date          := SYSDATE;
            action_request_tbl_tabtype (1)                 :=
                apps.oe_order_pub.g_miss_request_rec;
            -- Calling the API to update the lines of an existing Order --
            apps.OE_ORDER_PUB.PROCESS_ORDER (
                p_api_version_number       => ln_api_version_number,
                p_header_rec               => header_rec_rectype,
                p_line_tbl                 => line_tbl_tabtype,
                p_action_request_tbl       => action_request_tabtype,
                p_line_adj_tbl             => line_adj_tabtype-- OUT variables
                                                              ,
                x_header_rec               => header_rec_out_rectype,
                x_header_val_rec           => header_val_rec_out_rectype,
                x_header_adj_tbl           => header_adj_tbl_out_tabtype,
                x_header_adj_val_tbl       => header_adj_val_out_tabtype,
                x_header_price_att_tbl     => header_price_att_out_tabtype,
                x_header_adj_att_tbl       => header_adj_att_out_tabtype,
                x_header_adj_assoc_tbl     => header_adj_assoc_out_tabtype,
                x_header_scredit_tbl       => header_scredit_tbl_tabtype,
                x_header_scredit_val_tbl   => header_scredit_val_tabtype,
                x_line_tbl                 => line_tbl_out_tabtype,
                x_line_val_tbl             => line_val_tbl_out_tabtype,
                x_line_adj_tbl             => line_adj_tbl_out_tabtype,
                x_line_adj_val_tbl         => line_adj_val_tbl_out_tabtype,
                x_line_price_att_tbl       => line_price_att_tbl_tabtype,
                x_line_adj_att_tbl         => line_adj_att_tbl_out_tabtype,
                x_line_adj_assoc_tbl       => line_adj_assoc_tbl_tabtype,
                x_line_scredit_tbl         => line_scredit_tbl_out_tabtype,
                x_line_scredit_val_tbl     => line_scredit_val_tbl_tabtype,
                x_lot_serial_tbl           => lot_serial_tbl_out_tabtype,
                x_lot_serial_val_tbl       => lot_serial_val_tbl_out_tabtype,
                x_action_request_tbl       => action_request_tbl_tabtype,
                x_return_status            => lv_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lv_msg_data);

            IF lv_return_status = apps.fnd_api.g_ret_sts_success
            THEN
                UPDATE apps.wsh_delivery_details wdd
                   SET wdd.attribute4 = lv_old_ship_code, wdd.last_updated_by = gn_updated_by, wdd.LAST_UPDATE_DATE = SYSDATE
                 WHERE     wdd.source_line_id = order_tbl (i).ln_line_id
                       AND wdd.source_header_id = order_tbl (i).ln_header_id;

                COMMIT;
            ELSE
                lv_err_msg                         := NULL;
                ROLLBACK;

                FOR i IN 1 .. ln_msg_count
                LOOP
                    v_msg_data   :=
                        apps.oe_msg_pub.GET (p_msg_index   => i,
                                             p_encoded     => 'F');
                    -- apps.fnd_file.put_line(apps.fnd_file.OUTPUT,i||' '|| lv_msg_data);
                    lv_err_msg   := lv_err_msg || ' ' || v_msg_data;
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'error message ' || v_msg_data);
                END LOOP;

                ln_err_cnt                         := ln_err_cnt + 1;
                err_tbl (ln_err_cnt).header_id     :=
                    order_tbl (i).ln_header_id;
                err_tbl (ln_err_cnt).line_id       := order_tbl (i).ln_line_id;
                err_tbl (ln_err_cnt).status_code   := 'E';
                err_tbl (ln_err_cnt).status_msg    := lv_err_msg;
            END IF;
        END LOOP;

        -- Displaying the error messages in LOG File
        BEGIN
            FOR j IN 1 .. err_tbl.COUNT
            LOOP
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       err_tbl (j).header_id
                    || '---'
                    || err_tbl (j).line_id
                    || '----'
                    || err_tbl (j).status_msg);
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error Occured while displaying the error reocrds in updating bulk pick'
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error Occured while updating the eligible customers into Bulk Pick'
                || 'Erro message is:-'
                || SQLERRM);
    END;                                                --update_ship_priority

    PROCEDURE INSERT_STG
    IS
        CURSOR insert_so_lines IS
            SELECT 'BULKPICK', ool.HEADER_ID, ool.LINE_ID,
                   ool.INVENTORY_ITEM_ID, ool.SHIP_FROM_ORG_ID, ool.ORDERED_ITEM,
                   ool.LINE_NUMBER, ool.ORDERED_QUANTITY, ool.ORG_ID,
                   ool.REQUEST_DATE, ool.PROMISE_DATE, ool.SCHEDULE_SHIP_DATE,
                   ool.ORDER_QUANTITY_UOM, ool.SHIPMENT_PRIORITY_CODE, ool.FLOW_STATUS_CODE,
                   SYSDATE, gn_updated_by, SYSDATE,
                   gn_created_by, gn_request_id, NULL,
                   NULL, ool.sold_to_org_id         -- Customer sold to org_id
                                           , NULL,
                   NULL, 'N', NULL
              FROM apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
             WHERE     ooh.header_id = ool.header_id
                   AND ool.shipment_priority_code = gv_shipment_type
                   AND TRUNC (ool.request_date) >=
                       TRUNC (
                           TO_DATE (gv_from_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND TRUNC (ool.request_date) <=
                       TRUNC (TO_DATE (gv_to_date, 'RRRR/MM/DD HH24:MI:SS'))
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND 1 = qty_reserved (ool.header_id, ool.line_id, ool.order_quantity_uom
                                         , ool.inventory_item_id)
                   AND UPPER (ooh.CUST_PO_NUMBER) IN
                           (    SELECT REGEXP_SUBSTR (gv_cust_po, '[^,]+', 1
                                                      , LEVEL)
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR (gv_cust_po, '[^,]+', 1,
                                                      LEVEL)
                                           IS NOT NULL)
                   AND ool.ship_from_org_id = gn_org_id
                   AND ool.sold_to_org_id = gn_cust_account_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ool.header_id
                                   AND wdd.source_line_id = ool.line_id
                                   AND wdd.released_status IN ('R', 'B')
                                   AND NVL (wdd.attribute1, 'N') = 'N');

        ln_err_cnt     PLS_INTEGER;
        ln_cnt         NUMBER := 0;
        dml_errors     EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);

        TYPE lines_tbl IS TABLE OF xxdo.xxdooe_lines_stg%ROWTYPE;

        so_lines_tbl   lines_tbl;
    BEGIN
        DELETE FROM xxdo.xxdooe_lines_stg
              WHERE source_code = 'BULKPICK';

        COMMIT;

        OPEN insert_so_lines;

        FETCH insert_so_lines BULK COLLECT INTO so_lines_tbl;

        CLOSE insert_so_lines;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '===================================================================================================');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'No of Records Feteched For this iteration is:---'
            || so_lines_tbl.COUNT);

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

    PROCEDURE Process_bp_orders
    IS
        CURSOR BP_CUR    -- Cursor to fetch the distinct item id's by customer
                      IS
              SELECT ool.ordered_item, ool.inventory_item_id, ool.attribute3 -- sold_to_org_id
                FROM xxdo.xxdooe_lines_stg ool
               WHERE     ool.shipment_priority_code = gv_shipment_type
                     AND ool.flow_status_code = 'AWAITING_SHIPPING'
                     AND ool.ship_from_org_id = gn_org_id
                     AND ool.source_code = 'BULKPICK'
            GROUP BY ool.ordered_item, ool.inventory_item_id, ool.attribute3;

        CURSOR GET_LINES_CUR (cp_item_id NUMBER -- cursor to fetch all similar items for single customer
                                               , cp_cust_id NUMBER)
        IS
              SELECT ool.header_id, ool.ordered_item, ool.ordered_quantity,
                     ool.inventory_item_id, ool.line_id, ool.ship_from_org_id,
                     ool.attribute3
                FROM xxdo.xxdooe_lines_stg ool
               WHERE     ool.shipment_priority_code = gv_shipment_type
                     AND ool.flow_status_code = 'AWAITING_SHIPPING'
                     AND ool.inventory_item_id = cp_item_id
                     AND ool.attribute3 = cp_cust_id
                     AND ool.ship_from_org_id = gn_org_id
                     AND ool.source_code = 'BULKPICK'
            ORDER BY ool.ordered_quantity ASC;

        ln_conversion_rate   NUMBER;
        ln_err_cnt           NUMBER;
        ln_mod_value         NUMBER;
        ln_ordered_qty       NUMBER;
        ln_temp              NUMBER;
        ln_bulk              NUMBER;
        ln_flow              NUMBER;
        ln_new_detail_id     NUMBER;
        lv_err_msg           VARCHAR2 (2000);
        lv_status            VARCHAR2 (1);
        lv_api_err_msg       VARCHAR2 (2000);
        ln_from_detail_id    NUMBER;
    BEGIN
        FOR i IN BP_CUR
        LOOP
            ln_conversion_rate   := 0;
            ln_err_cnt           := 0;
            ln_mod_value         := 0;
            ln_ordered_qty       := 0;
            ln_temp              := 0;
            lv_err_msg           := NULL;

            /*==========================================================================================
                Getting Case pick quantity or conversion rate for items

              ==========================================================================================*/

            BEGIN
                SELECT mou.conversion_rate
                  INTO ln_conversion_rate
                  FROM apps.mtl_uom_conversions mou
                 WHERE mou.inventory_item_id = i.inventory_item_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'UOM conversion rate not defined';
                WHEN TOO_MANY_ROWS
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'More than one UOM conversion Defined';
                WHEN OTHERS
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'Error Occured wile getting case pick quantity';
            END;

            /*==========================================================================================
                fetch sun-inventory details for which sun-inv has bulk quantity and loose quantity

              ==========================================================================================*/
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
                  INTO gv_bulk_sub_inv, gv_flow_sub_inv
                  FROM apps.fnd_lookup_values flv, apps.org_organization_definitions ood
                 WHERE     flv.lookup_type = 'XXDO_BULK_PICK'
                       AND flv.LANGUAGE = USERENV ('LANG')
                       AND flv.lookup_code = ood.organization_code
                       AND ood.organization_id = gn_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'Bulk And Flow Subinventories are not defined';
                WHEN TOO_MANY_ROWS
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'Multiple times sub inventories are defined ';
                WHEN OTHERS
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'Error occured wile getting subinventories in lookup table';
            END;

            /*================================================================================================
                     Fetching SUM of quantity for multiple SO's of single customer
                     Ex:-item 5815-CHE-10 has exist in 4 SO's for NORDSTORM customer we need to sum it
              ================================================================================================*/
            BEGIN
                SELECT SUM (ordered_quantity)
                  INTO ln_ordered_qty
                  FROM xxdo.xxdooe_lines_stg ool
                 WHERE     ool.shipment_priority_code = gv_shipment_type
                       AND ool.flow_status_code = 'AWAITING_SHIPPING'
                       AND ool.inventory_item_id = i.inventory_item_id
                       AND ool.ship_from_org_id = gn_org_id
                       AND ool.attribute3 = i.attribute3
                       AND ool.source_code = 'BULKPICK';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'No such orders found for the item';
                WHEN OTHERS
                THEN
                    ln_err_cnt   := ln_err_cnt + 1;
                    lv_err_msg   :=
                           lv_err_msg
                        || '  '
                        || 'Error Occured wile getting sum of item qty';
            END;

            -- apps.fnd_file.put_line(apps.fnd_file.log,'Step-1');
            IF     ln_conversion_rate > 0
               AND ln_ordered_qty >= ln_conversion_rate
               AND ln_err_cnt <= 0
            THEN
                --   apps.fnd_file.put_line(apps.fnd_file.log,'Step-2');
                ln_mod_value   := MOD (ln_ordered_qty, ln_conversion_rate);
                ln_temp        := ln_mod_value;

                FOR j IN GET_LINES_CUR (i.inventory_item_id, i.attribute3)
                LOOP
                    ln_bulk             := 0;
                    ln_flow             := 0;
                    ln_from_detail_id   := 0;
                    ln_new_detail_id    := 0;
                    lv_status           := NULL;
                    lv_api_err_msg      := NULL;

                    --    apps.fnd_file.put_line(apps.fnd_file.log,'Step-3');
                    IF j.ordered_quantity <= ln_temp
                    THEN
                        ln_flow   := j.ordered_quantity;
                        ln_temp   := ln_temp - j.ordered_quantity;

                        IF ln_temp < 0
                        THEN
                            ln_temp   := 0;
                        END IF;

                        UPDATE apps.wsh_delivery_details wdd
                           SET wdd.attribute2 = gv_flow_sub_inv, wdd.attribute1 = 'Y', wdd.last_updated_by = gn_updated_by,
                               wdd.LAST_UPDATE_DATE = SYSDATE
                         WHERE     wdd.source_header_id = j.header_id
                               AND wdd.source_line_id = j.line_id;

                        UPDATE xxdo.xxdooe_lines_stg lstg
                           SET lstg.attribute1 = gv_flow_sub_inv, lstg.status_code = 'S'
                         WHERE     lstg.header_id = j.header_id
                               AND lstg.line_id = j.line_id
                               AND lstg.source_code = 'BULKPICK';
                    ELSE                   -- IF j.ordered_quantity <= ln_temp
                        ln_bulk   := (j.ordered_quantity - ln_temp);
                        ln_flow   := ln_temp;
                        ln_temp   := ln_temp - j.ordered_quantity;

                        --    apps.fnd_file.put_line(apps.fnd_file.log,'Step-4');
                        IF ln_temp < 0
                        THEN
                            ln_temp   := 0;
                        END IF;

                        --    apps.fnd_file.put_line(apps.fnd_file.log,'Step-5');

                        IF ln_flow <> 0
                        THEN
                            BEGIN
                                SELECT wdd.delivery_detail_id
                                  INTO ln_from_detail_id
                                  FROM apps.wsh_delivery_details wdd
                                 WHERE     wdd.source_header_id = j.header_id
                                       AND wdd.source_line_id = j.line_id
                                       AND wdd.inventory_item_id =
                                           j.inventory_item_id
                                       AND wdd.split_from_delivery_detail_id
                                               IS NULL;
                            EXCEPTION
                                WHEN TOO_MANY_ROWS
                                THEN
                                    lv_err_msg   :=
                                        'More than one delivery detail ids exist for  line id  ';
                                    ln_err_cnt   := 1;
                                WHEN OTHERS
                                THEN
                                    lv_err_msg   :=
                                        'Error occured while getting delivery id';
                                    ln_err_cnt   := 1;
                            END;

                            IF ln_err_cnt = 0
                            THEN
                                SPLIT_DELIVERY_LINE (
                                    pn_header_id        => j.header_id,
                                    pn_line_id          => j.line_id,
                                    pn_item_id          => j.inventory_item_id,
                                    pn_bulk_qty         => ln_bulk,
                                    pn_flow_qty         => ln_flow,
                                    pn_from_detail_id   => ln_from_detail_id,
                                    pn_new_detail_id    => ln_new_detail_id,
                                    pv_status           => lv_status,
                                    pv_err_msg          => lv_api_err_msg);

                                --        apps.fnd_file.put_line(apps.fnd_file.log,'Step-7');
                                IF lv_status = 'S'
                                THEN
                                    UPDATE xxdo.xxdooe_lines_stg lstg
                                       SET lstg.ordered_quantity = ln_bulk, lstg.attribute1 = gv_bulk_sub_inv, lstg.status_code = 'S'
                                     WHERE     lstg.header_id = j.header_id
                                           AND lstg.line_id = j.line_id
                                           AND lstg.source_code = 'BULKPICK';

                                    /*=============================================================================================================
                                        If delivery line split is success then inesert that line into stageing table
                                      =============================================================================================================*/
                                    BEGIN
                                        INSERT INTO xxdo.xxdooe_lines_stg
                                            (SELECT 'BULKPICK', HEADER_ID, LINE_ID,
                                                    INVENTORY_ITEM_ID, SHIP_FROM_ORG_ID, ORDERED_ITEM,
                                                    LINE_NUMBER, ln_flow, ORG_ID,
                                                    REQUEST_DATE, PROMISE_DATE, SCHEDULE_SHIP_DATE,
                                                    ORDER_QUANTITY_UOM, SHIPMENT_PRIORITY_CODE, FLOW_STATUS_CODE,
                                                    SYSDATE, gn_updated_by, SYSDATE,
                                                    gn_created_by, gn_request_id, gv_flow_sub_inv,
                                                    NULL, ool.sold_to_org_id, ln_new_detail_id,
                                                    NULL, 'S', NULL
                                               FROM apps.oe_order_lines_all ool
                                              WHERE     ool.header_id =
                                                        j.header_id
                                                    AND ool.line_id =
                                                        j.line_id);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            apps.fnd_file.put_line (
                                                apps.fnd_file.LOG,
                                                'Error occured while inserting the splitted line');
                                    END;

                                    UPDATE apps.wsh_delivery_details wdd
                                       SET wdd.attribute2 = gv_bulk_sub_inv, wdd.attribute1 = 'Y'
                                     WHERE wdd.delivery_detail_id =
                                           ln_from_detail_id;

                                    --    apps.fnd_file.put_line(apps.fnd_file.log,'Step-9');
                                    UPDATE apps.wsh_delivery_details wdd
                                       SET wdd.attribute2 = gv_flow_sub_inv, wdd.attribute1 = 'Y'
                                     WHERE wdd.delivery_detail_id =
                                           ln_new_detail_id;
                                -- COMMIT;
                                ELSE
                                    --    apps.fnd_file.put_line(apps.fnd_file.log,'Step-11');
                                    --    apps.fnd_file.put_line(apps.fnd_file.log,'Step-12'||lv_api_err_msg);
                                    ROLLBACK;

                                    UPDATE xxdo.xxdooe_lines_stg lstg
                                       SET lstg.status_code = 'E', lstg.status_msg = 'Error occured while spliting the line_id   ' || j.line_id || '   -API error is-   ' || lv_api_err_msg
                                     WHERE     lstg.inventory_item_id =
                                               j.inventory_item_id
                                           AND lstg.attribute3 = j.attribute3
                                           AND lstg.line_id = j.line_id;

                                    --   AND  lstg.shipment_priority_code  = gv_shipment_type2;
                                    EXIT;
                                END IF;            -- end of api return status
                            ELSE                               --if ln_err_cnt
                                UPDATE xxdo.xxdooe_lines_stg lstg
                                   SET lstg.status_code = 'E', lstg.status_msg = lv_err_msg
                                 WHERE     lstg.header_id = j.header_id
                                       AND lstg.line_id = j.line_id
                                       AND lstg.source_code = 'BULKPICK';
                            END IF;                 -- end of  if ln_err_cnt=0
                        -- END IF;
                        ELSE
                            UPDATE apps.wsh_delivery_details wdd
                               SET wdd.attribute2 = gv_bulk_sub_inv, wdd.attribute1 = 'Y', wdd.last_updated_by = gn_updated_by,
                                   wdd.LAST_UPDATE_DATE = SYSDATE
                             WHERE     wdd.source_header_id = j.header_id
                                   AND wdd.source_line_id = j.line_id;

                            UPDATE xxdo.xxdooe_lines_stg lstg
                               SET lstg.attribute1 = gv_bulk_sub_inv, lstg.status_code = 'S'
                             WHERE     lstg.header_id = j.header_id
                                   AND lstg.line_id = j.line_id;
                        END IF;                     -- end of  IF ln_flow <> 0
                    END IF;         -- end of IF j.ordered_quantity <= ln_temp
                END LOOP;

                COMMIT;
            ELSIF     ln_conversion_rate > 0
                  AND ln_ordered_qty < ln_conversion_rate  --AND ln_err_cnt<=0
            THEN
                FOR j IN GET_LINES_CUR (i.inventory_item_id, i.attribute3)
                LOOP
                    ln_bulk   := 0;
                    ln_flow   := 0;

                    UPDATE apps.wsh_delivery_details wdd
                       SET wdd.attribute2 = gv_flow_sub_inv, wdd.attribute1 = 'Y', wdd.last_updated_by = gn_updated_by,
                           wdd.LAST_UPDATE_DATE = SYSDATE
                     WHERE     wdd.source_header_id = j.header_id
                           AND wdd.source_line_id = j.line_id;

                    UPDATE xxdo.xxdooe_lines_stg lstg
                       SET lstg.attribute1 = gv_flow_sub_inv, lstg.status_code = 'S'
                     WHERE     lstg.header_id = j.header_id
                           AND lstg.line_id = j.line_id;

                    COMMIT;
                END LOOP;
            --    END IF;

            ELSE
                UPDATE xxdo.xxdooe_lines_stg lstg
                   SET lstg.status_code = 'E', lstg.status_msg = lv_err_msg
                 WHERE     lstg.flow_status_code = 'AWAITING_SHIPPING'
                       AND lstg.ship_from_org_id = gn_org_id
                       AND lstg.inventory_item_id = i.inventory_item_id
                       AND lstg.attribute3 = i.attribute3;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured in the pocedure Process_bp_type2 and error code is -'
                || SQLERRM);
    END;


    PROCEDURE SPLIT_DELIVERY_LINE (pn_header_id IN NUMBER, pn_line_id IN NUMBER, pn_item_id IN NUMBER, pn_bulk_qty IN NUMBER, pn_flow_qty IN NUMBER, pn_from_detail_id IN NUMBER
                                   , pn_new_detail_id OUT NUMBER, pv_status OUT VARCHAR2, pv_err_msg OUT VARCHAR2)
    IS
        lv_api_version        NUMBER := 1.0;
        lv_init_msg_list      VARCHAR2 (30) := apps.FND_API.G_FALSE;
        lv_commit             VARCHAR2 (30) := apps.FND_API.G_FALSE;
        lv_validation_level   NUMBER := apps.FND_API.G_VALID_LEVEL_FULL;
        lx_return_status      VARCHAR2 (100);
        lx_msg_count          NUMBER;
        lx_msg_data           VARCHAR2 (2000);
        -- ln_from_detail_id     NUMBER;
        lx_new_detail_id      NUMBER;
        lx_split_quantity     NUMBER := pn_flow_qty;
        lx_split_quantity2    NUMBER;
        fail_api              EXCEPTION;
        lx_msg_details        VARCHAR2 (3000);
        lx_msg_summary        VARCHAR2 (3000);
    BEGIN
        lx_return_status   := apps.WSH_UTIL_CORE.G_RET_STS_SUCCESS;
        apps.FND_GLOBAL.APPS_INITIALIZE (user_id        => gn_user_id,
                                         resp_id        => gn_resp_id,
                                         resp_appl_id   => gn_appl_id);

        apps.WSH_DELIVERY_DETAILS_PUB.split_line (
            -- Standard parameters
            p_api_version        => lv_api_version,
            p_init_msg_list      => lv_init_msg_list,
            p_commit             => lv_commit,
            p_validation_level   => lv_validation_level,
            x_return_status      => lx_return_status,
            x_msg_count          => lx_msg_count,
            x_msg_data           => lx_msg_data-- program specific parameters
                                               ,
            p_from_detail_id     => pn_from_detail_id,
            x_new_detail_id      => lx_new_detail_id,
            x_split_quantity     => lx_split_quantity,
            x_split_quantity2    => lx_split_quantity2     /* added for OPM */
                                                      );

        IF (lx_return_status = apps.WSH_UTIL_CORE.G_RET_STS_SUCCESS)
        THEN
            pv_status          := 'S';
            pn_new_detail_id   := lx_new_detail_id;
        ELSE
            apps.WSH_UTIL_CORE.get_messages ('Y', lx_msg_summary, lx_msg_details
                                             , lx_msg_count);

            IF lx_msg_count > 1
            THEN
                lx_msg_data   := lx_msg_summary || lx_msg_details;
            ELSE
                lx_msg_data   := lx_msg_summary;
            END IF;

            pv_status    := 'E';
            pv_err_msg   := lx_msg_data;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error occured in Split_so_line Procedure and error message is-'
                || SQLERRM);
    END;                                                 --split_delivery_line

    PROCEDURE email_bptype
    IS
        CURSOR bptype1_cur IS
            SELECT ool.header_id, ool.ordered_item, ool.ordered_quantity,
                   ool.line_number, ool.inventory_item_id, ool.line_id,
                   ool.ship_from_org_id, ool.flow_status_code, DECODE (ool.shipment_priority_code, 'PB26', 'Bulk Pick', ool.shipment_priority_code) priority_code
              FROM xxdo.xxdooe_lines_stg ool
             WHERE     ool.shipment_priority_code = gv_shipment_type
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.ship_from_org_id = gn_org_id
                   AND ool.status_code = 'S'
                   AND ool.source_code = 'BULKPICK';

        /*    CURSOR bptype2_cur
               IS
               SELECT  ool.header_id
                    ,ool.ordered_item
                    ,ool.ordered_quantity
                    ,ool.line_number
                    ,ool.inventory_item_id
                    ,ool.line_id
                    ,ool.ship_from_org_id
                    ,ool.flow_status_code
                    ,DECODE(ool.shipment_priority_code,'PB27','Bulk Pick Type-1'
                                                      ,'PB28','Bulk Pick Type-2'
                                                      ,NULL
                            ) priority_code
              FROM  xxdo.xxdooe_lines_stg ool
              WHERE ool.shipment_priority_code   =  gv_shipment_type2
               AND  ool.flow_status_code         =  'AWAITING_SHIPPING'
               AND  ool.ship_from_org_id         =  gn_org_id
               AND  ool.status_code              <> 'E'
               AND  ool.source_code              = 'BULKPICK';
        */

        CURSOR err_cur IS
            SELECT ool.header_id, ool.ordered_item, ool.ordered_quantity,
                   ool.line_number, ool.inventory_item_id, ool.line_id,
                   ool.ship_from_org_id, ool.flow_status_code, DECODE (ool.shipment_priority_code, 'PB26', 'Bulk Pick', ool.shipment_priority_code) priority_code,
                   ool.status_msg
              FROM xxdo.xxdooe_lines_stg ool
             WHERE ool.status_code = 'E' AND ool.source_code = 'BULKPICK';

        lv_user_name        VARCHAR2 (50) := apps.fnd_profile.VALUE ('USERNAME');
        lv_email            VARCHAR2 (50) := NULL;
        v_mail_recips       apps.do_mail_utils.tbl_recips;
        lv_org_code         VARCHAR2 (5);
        ln_order_number     NUMBER;
        lv_customer_name    VARCHAR2 (25);
        ln_bp1_count        NUMBER := 0;
        ln_bp2_count        NUMBER := 0;
        lv_cust_po_number   VARCHAR2 (50);
    BEGIN
        BEGIN                                          -- Getting the email id
            SELECT fu.email_address
              INTO lv_email
              FROM apps.fnd_user fu
             WHERE fu.user_name = lv_user_name;

            IF lv_email IS NOT NULL
            THEN
                v_mail_recips (v_mail_recips.COUNT + 1)   := lv_email;
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'venkatarama.battu@deckers.com';
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'shaik.basha@deckers.com';
            ELSE
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'venkatarama.battu@deckers.com';
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'shaik.basha@deckers.com';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'venkatarama.battu@deckers.com';
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'shaik.basha@deckers.com';
            WHEN TOO_MANY_ROWS
            THEN
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'venkatarama.battu@deckers.com';
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'shaik.basha@deckers.com';
            WHEN OTHERS
            THEN
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'venkatarama.battu@deckers.com';
                v_mail_recips (v_mail_recips.COUNT + 1)   :=
                    'shaik.basha@deckers.com';
        END;

        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_mail_recips, 'Bulk Pick Eligible Orders'
                                             , gn_rtn_val);
        apps.do_mail_utils.send_mail_line ('', gn_rtn_val);
        apps.do_mail_utils.send_mail_line (
            'Request Submitted by:-' || lv_user_name,
            gn_rtn_val);
        --  apps.do_mail_utils.send_mail_line('From Date:-'||gv_from_date,gn_rtn_val);
        --  apps.do_mail_utils.send_mail_line('From Date:-'||gv_to_date,gn_rtn_val);
        apps.do_mail_utils.send_mail_line (' ' || ' ', gn_rtn_val);
        apps.do_mail_utils.send_mail_line (
            '## This is an Email alert automatically generated when "Bulkpick  Eligible orders " is Program  submitted ##',
            gn_rtn_val);
        apps.do_mail_utils.send_mail_line (' ' || ' ', gn_rtn_val);
        apps.do_mail_utils.send_mail_line (
               '|'
            || RPAD ('-', 18, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 8, '-')
            || '|'
            || RPAD ('-', 8, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'--   || RPAD ('-', 25, '-')
                  --    || '|'
                  ,
            gn_rtn_val);
        apps.do_mail_utils.send_mail_line (
               '|'
            || RPAD ('Order Number', 18, ' ')
            || '|'
            || RPAD ('Customer Name', 30, ' ')
            || '|'
            || RPAD ('Customer PO Number', 20, ' ')
            || '|'
            || RPAD ('Line item', 20, ' ')
            || '|'
            || RPAD ('Line Number ', 8, ' ')
            || '|'
            || RPAD ('Line Qty', 8, ' ')
            || '|'
            || RPAD ('Line Status', 20, ' ')
            || '|'
            || RPAD ('Shipment Priority', 20, ' ')
            || '|'--  || RPAD ('Status', 25, ' ')
                  --   || '|'
                  ,
            gn_rtn_val);

        apps.do_mail_utils.send_mail_line (
               '|'
            || RPAD ('-', 18, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 8, '-')
            || '|'
            || RPAD ('-', 8, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'--  || RPAD ('-', 25, '-')
                  --  || '|'
                  ,
            gn_rtn_val);



        FOR i IN bptype1_cur
        LOOP
            ln_order_number     := 0;
            lv_org_code         := NULL;
            ln_bp1_count        := ln_bp1_count + 1;
            lv_cust_po_number   := NULL;

            BEGIN
                SELECT order_number
                  INTO ln_order_number
                  FROM apps.oe_order_headers_all ooh
                 WHERE ooh.header_id = i.header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        ' Order number not found for the header_id :- ' || i.header_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the order number for the header_id:-'
                        || i.header_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            BEGIN
                SELECT organization_code
                  INTO lv_org_code
                  FROM apps.org_organization_definitions ood
                 WHERE ood.organization_id = i.ship_from_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           ' organization_code not found for the organization_id  :- '
                        || i.ship_from_org_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the organization_code for the organization_id:-'
                        || i.ship_from_org_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            BEGIN
                SELECT hp.party_name
                  INTO lv_customer_name
                  FROM apps.hz_parties hp, apps.hz_cust_accounts hca, apps.oe_order_headers_all ooh
                 WHERE     hp.party_id = hca.party_id
                       AND hca.cust_account_id = ooh.sold_to_org_id
                       AND ooh.header_id = i.header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        ' Customer not found for the header_id  :- ' || i.header_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the customer name for the header_id :-'
                        || i.header_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            BEGIN
                SELECT ooh.cust_po_number
                  INTO lv_cust_po_number
                  FROM apps.oe_order_headers_all ooh
                 WHERE ooh.header_id = i.header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        ' Customer PO Not found :- ' || i.header_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the Customer PO Number for the header_id:-'
                        || i.header_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            apps.do_mail_utils.send_mail_line (
                   '|'
                || RPAD (NVL (NVL (ln_order_number, 0), 0), 18, ' ')
                || '|'
                || RPAD (NVL (lv_customer_name, ' '), 30, ' ')
                || '|'
                || RPAD (NVL (lv_cust_po_number, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (i.ordered_item, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (i.line_number, 0), 8, ' ')
                || '|'
                || RPAD (NVL (i.ordered_quantity, 0), 8, ' ')
                || '|'
                || RPAD (NVL (i.flow_status_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (i.priority_code, ' '), 20, ' ')
                || '|'--  || RPAD (NVL ('Success', ' '),
                      --           25,
                      --           ' '
                      --            )
                      --   || '|'
                      ,
                gn_rtn_val);

            apps.do_mail_utils.send_mail_line (
                   '|'
                || RPAD ('-', 18, '-')
                || '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'
                || RPAD ('-', 8, '-')
                || '|'
                || RPAD ('-', 8, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'--   || RPAD ('-', 25, '-')
                      --   || '|'
                      ,
                gn_rtn_val);
        END LOOP;

        IF ln_bp1_count = 0
        THEN
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
                '#### No Eligible Bulk Pick  orders for this request ####',
                gn_rtn_val);
            apps.DO_MAIL_UTILS.SEND_MAIL_LINE (' ' || ' ', gn_rtn_val);
        END IF;

        apps.DO_MAIL_UTILS.SEND_MAIL_LINE ('  ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE ('  ', gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_LINE (
            '*************************END Of Bulkpick********************************',
            gn_rtn_val);
        apps.DO_MAIL_UTILS.SEND_MAIL_CLOSE (gn_rtn_val);

        /*   ====================================================================================================================
                    ************************* Printing the error reocrds in LOG file ************************************
            ====================================================================================================================*/
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '--------------------- Error Records ------------------------------------');

        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('-', 18, '-')
            || '|'
            || RPAD ('-', 40, '-')
            || '|'
            --  || RPAD ('-', 40, '-')
            --  || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 250, '-')
            || '|'--     ,gn_rtn_val
                  );
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('Order Number', 18, ' ')
            || '|'
            || RPAD ('Customer Name', 40, ' ')
            || '|'
            || RPAD ('Line item', 25, ' ')
            || '|'
            || RPAD ('Line Number ', 12, ' ')
            || '|'
            || RPAD ('Line Qty', 12, ' ')
            || '|'
            || RPAD ('Line Status', 20, ' ')
            || '|'
            || RPAD ('Shipment Priority', 20, ' ')
            || '|'
            || RPAD ('Error Message', 250, ' ')
            || '|'--     ,gn_rtn_val
                  );

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '|'
            || RPAD ('-', 18, '-')
            || '|'
            || RPAD ('-', 40, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 250, '-')
            || '|'--    ,gn_rtn_val
                  );

        FOR k IN err_cur
        LOOP
            ln_order_number   := 0;
            lv_org_code       := NULL;
            ln_bp2_count      := ln_bp2_count + 1;

            BEGIN
                SELECT order_number
                  INTO ln_order_number
                  FROM apps.oe_order_headers_all ooh
                 WHERE ooh.header_id = k.header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        ' Order number not found for the header_id :- ' || k.header_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the order number for the header_id:-'
                        || k.header_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            BEGIN
                SELECT organization_code
                  INTO lv_org_code
                  FROM apps.org_organization_definitions ood
                 WHERE ood.organization_id = k.ship_from_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           ' organization_code not found for the organization_id  :- '
                        || k.ship_from_org_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the organization_code for the organization_id:-'
                        || k.ship_from_org_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            BEGIN
                SELECT hp.party_name
                  INTO lv_customer_name
                  FROM apps.hz_parties hp, apps.hz_cust_accounts hca, apps.oe_order_headers_all ooh
                 WHERE     hp.party_id = hca.party_id
                       AND hca.cust_account_id = ooh.sold_to_org_id
                       AND ooh.header_id = k.header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        ' Customer not found for the header_id  :- ' || k.header_id);
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error occured while getting the customer name for the header_id :-'
                        || k.header_id
                        || 'AND error code is '
                        || SQLERRM);
            END;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD (NVL (NVL (ln_order_number, 0), 0), 18, ' ')
                || '|'
                || RPAD (NVL (lv_customer_name, ' '), 40, ' ')
                || '|'
                || RPAD (NVL (k.ordered_item, ' '), 25, ' ')
                || '|'
                || RPAD (NVL (k.line_number, 0), 12, ' ')
                || '|'
                || RPAD (NVL (k.ordered_quantity, 0), 12, ' ')
                || '|'
                || RPAD (NVL (k.flow_status_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (k.priority_code, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (k.status_msg, ' '), 250, ' ')
                || '|'--    ,gn_rtn_val
                      );

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD ('-', 18, '-')
                || '|'
                || RPAD ('-', 40, '-')
                || '|'
                || RPAD ('-', 25, '-')
                || '|'
                || RPAD ('-', 12, '-')
                || '|'
                || RPAD ('-', 12, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'
                || RPAD ('-', 20, '-')
                || '|'
                || RPAD ('-', 250, '-')
                || '|'--    ,gn_rtn_val
                      );
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Internal error occured in ' || SQLERRM);
    END;



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
END;                                             --XXDOOM_BULK_PICK_ORDERS_PKG 
/
