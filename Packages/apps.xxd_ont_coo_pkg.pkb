--
-- XXD_ONT_COO_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_COO_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_ONT_COO_PKG
     * Design       : This package will be used to update Country of Origin for SO Shipped Lines
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 11-SEP-2020  1.0        Deckers                 Initial Version
     ******************************************************************************************/

    gv_package_name   CONSTANT VARCHAR (30) := 'XXD_ONT_COO_PKG';
    gv_time_stamp              VARCHAR2 (40)
                                   := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
    gv_file_time_stamp         VARCHAR2 (40)
                                   := TO_CHAR (SYSDATE, 'MMDDYY_HH24MISS');
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_conc_request_id         NUMBER := fnd_global.conc_request_id;


    --Write messages into LOG file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_log (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_LOG';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, lv_msg);
        END IF;
    --fnd_file.put_line (fnd_file.LOG, msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    ----
    ----
    --Write messages into output file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_out (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_OUT';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.output, lv_msg);
        END IF;
    --fnd_file.put_line (fnd_file.output, msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print output:' || SQLERRM);
    END print_out;

    FUNCTION get_trxn_id_fnc (pn_transaction_id IN NUMBER)
        RETURN BOOLEAN
    IS
        lv_attr1   NUMBER;
    BEGIN
        SELECT ffvl.attribute1
          INTO lv_attr1
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvs.flex_value_set_name = 'XXD_INV_COO_TRX_TYPES_VS'
               AND NVL (ffvl.attribute2, 'N') = 'Y'
               AND ffvl.attribute1 = pn_transaction_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    PROCEDURE COO_PRC (pv_errbuf              OUT VARCHAR2,
                       pv_retcode             OUT VARCHAR2,
                       pn_org_id           IN     NUMBER,
                       pn_order_num        IN     NUMBER,
                       pn_order_line_num   IN     NUMBER,
                       pn_inv_item_id      IN     NUMBER,
                       pv_ship_from_date   IN     VARCHAR2,
                       pv_ship_to_date     IN     VARCHAR2)
    IS
        CURSOR shipped_lines_cur IS
              SELECT oola.header_id, oola.line_number || '.' || oola.shipment_number line_ship_number, oola.line_number,
                     oola.line_id, oola.ordered_quantity ordered_quantity, oola.flow_status_code,
                     oola.org_id, wdd.delivery_detail_id, oola.ordered_item,
                     oola.ordered_item_id, oola.ship_from_org_id, oola.inventory_item_id
                FROM oe_order_lines_all oola, oe_order_headers_all ooha, wsh_delivery_details wdd
               WHERE     1 = 1
                     AND oola.header_id = ooha.header_id
                     AND NVL (oola.cancelled_flag, 'Y') = 'N'
                     AND oola.flow_status_code = 'CLOSED'
                     --AND oola.open_flag = 'Y'
                     --AND wdd.source_code = 'OE'
                     AND wdd.source_line_id = oola.line_id
                     AND wdd.source_header_id = oola.header_id
                     --AND wdd.org_id = oola.org_id
                     AND wdd.released_status = 'C'
                     AND wdd.attribute6 IS NULL
                     AND ooha.org_id = NVL (pn_org_id, ooha.org_id)
                     AND ooha.header_id = NVL (pn_order_num, ooha.header_id)
                     AND oola.line_id = NVL (pn_order_line_num, oola.line_id)
                     AND oola.ordered_item_id =
                         NVL (pn_inv_item_id, oola.ordered_item_id)
                     AND TRUNC (oola.actual_shipment_date) BETWEEN NVL (
                                                                       fnd_date.canonical_to_date (
                                                                           pv_ship_from_date),
                                                                       oola.actual_shipment_date)
                                                               AND NVL (
                                                                       fnd_date.canonical_to_date (
                                                                           pv_ship_to_date),
                                                                       oola.actual_shipment_date)
            ORDER BY org_id, Delivery_detail_id;

        TYPE xxd_mmt_rec
            IS RECORD
        (
            trx_id               mtl_material_transactions.transaction_id%TYPE,
            inventory_item_id    mtl_material_transactions.inventory_item_id%TYPE,
            ship_from_org_id     mtl_material_transactions.organization_id%TYPE,
            trx_type_id          mtl_material_transactions.transaction_type_id%TYPE
        );

        TYPE xxd_mmt_rec_new_tab IS TABLE OF xxd_mmt_rec;

        xxd_mmt_rec_tab          xxd_mmt_rec_new_tab := xxd_mmt_rec_new_tab ();

        ln_transaction_type_id   mtl_material_transactions.transaction_type_id%TYPE;
        ln_transaction_id        mtl_material_transactions.transaction_id%TYPE;
        lb_return_value          BOOLEAN := TRUE;
        ln_source_header_id      NUMBER;
        ln_source_line_id        NUMBER;
        ln_inv_item_id           NUMBER;
        ln_ref_line_id           NUMBER;
        ln_ref_header_id         NUMBER;
        ln_ship_org_id           NUMBER;
        ln_final_trx_type_id     NUMBER;
        ln_final_trx_id          NUMBER;
        lb_trxn_value            BOOLEAN;
        ln_trx_organization_id   NUMBER;
        lv_invalid_flag          VARCHAR2 (1);
        ln_trx_source_id         NUMBER;
        --ln_vendor_site_id        NUMBER;
        ln_trx_source_line_d     NUMBER;
        lv_vendor_site_id        VARCHAR2 (100);
        ln_count                 NUMBER;
        ln_coll_cnt              NUMBER;
        l_index                  PLS_INTEGER;
        ln_init_count            NUMBER;
    BEGIN
        print_log (
               ' Start of the Program : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        xxd_mmt_rec_tab.EXTEND;

        FOR line IN shipped_lines_cur
        LOOP
            ln_transaction_type_id                  := NULL;
            ln_transaction_id                       := NULL;
            ln_final_trx_type_id                    := NULL;
            ln_final_trx_id                         := NULL;
            lv_invalid_flag                         := 'N';
            ln_count                                := 0;
            lb_return_value                         := TRUE;

            print_log (' Cursor entry ');

            BEGIN
                SELECT transaction_type_id, transaction_id
                  INTO ln_transaction_type_id, ln_transaction_id
                  FROM (  SELECT *
                            FROM mtl_material_transactions mmt
                           WHERE     mmt.inventory_item_id =
                                     line.inventory_item_id
                                 AND mmt.organization_id =
                                     line.ship_from_org_id
                                 AND EXISTS
                                         (SELECT 1
                                            FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                           WHERE     ffvs.flex_value_set_id =
                                                     ffvl.flex_value_set_id
                                                 AND ffvl.enabled_flag = 'Y'
                                                 AND SYSDATE BETWEEN NVL (
                                                                         ffvl.start_date_active,
                                                                         SYSDATE)
                                                                 AND NVL (
                                                                         ffvl.end_date_active,
                                                                         SYSDATE)
                                                 AND ffvs.flex_value_set_name =
                                                     'XXD_INV_COO_TRX_TYPES_VS'
                                                 AND ffvl.attribute1 =
                                                     mmt.transaction_type_id)
                        ORDER BY creation_date DESC)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_transaction_type_id   := NULL;
                    ln_transaction_id        := NULL;
                    print_log (
                           ' Initial Fetch is NULL with msg -  '
                        || SUBSTR (SQLERRM, 1, 200));
            END;

            --         IF xxd_mmt_rec_tab.COUNT > 0
            --         THEN
            --            xxd_mmt_rec_tab.delete;
            --         END IF;



            xxd_mmt_rec_tab (1).trx_id              := ln_transaction_id;
            xxd_mmt_rec_tab (1).inventory_item_id   := line.inventory_item_id;
            xxd_mmt_rec_tab (1).trx_type_id         := ln_transaction_type_id;
            xxd_mmt_rec_tab (1).ship_from_org_id    := line.ship_from_org_id;

            print_log ('Start of Coll Count is - ' || xxd_mmt_rec_tab.FIRST);

            print_log (
                   ' Transaction Type id is - '
                || ln_transaction_type_id
                || ' - Transaction ID is - '
                || ln_transaction_id
                || ' With Ordered Item - '
                || line.ordered_item
                || ' and Organization ID - '
                || line.ship_from_org_id);

            --         l_index := xxd_mmt_rec_tab.FIRST;

            WHILE lb_return_value
            LOOP
                ln_count               := ln_count + 1;
                ln_final_trx_type_id   := ln_transaction_type_id;
                ln_final_trx_id        := ln_transaction_id;
                lb_trxn_value          :=
                    get_trxn_id_fnc (ln_final_trx_type_id);

                print_log (' Iteration Count - ' || ln_count);
                print_log (
                    ' Transaction Type ID - ' || ln_transaction_type_id);
                print_log (' ln_final_trx_id - ' || ln_final_trx_id);

                IF ln_transaction_type_id IN (18, 71)
                THEN
                    ln_final_trx_type_id   := ln_transaction_type_id;
                    ln_final_trx_id        := ln_transaction_id;
                    print_log (
                           ' Transaction Type ID - '
                        || ln_final_trx_type_id
                        || ' - and transaction ID - '
                        || ln_final_trx_id);

                    lb_return_value        := FALSE;
                    lv_invalid_flag        := 'N';
                ELSIF ln_transaction_type_id <> 18 AND lb_trxn_value = FALSE
                THEN
                    ln_final_trx_type_id   := ln_transaction_type_id;
                    ln_final_trx_id        := ln_transaction_id;

                    lv_invalid_flag        := 'Y';
                    lb_return_value        := FALSE;

                    print_log (
                           ' Transaction Type ID - '
                        || ln_final_trx_type_id
                        || ' - and transaction ID - '
                        || ln_final_trx_id
                        || ' - and Flag is - '
                        || lv_invalid_flag);
                ELSIF ln_transaction_type_id <> 18 AND lb_trxn_value = TRUE
                THEN
                    -- Check whether the Transaction is RMA Receipt

                    IF ln_transaction_type_id = 15
                    THEN
                        ln_source_line_id   := NULL;
                        ln_inv_item_id      := NULL;

                        BEGIN
                            SELECT trx_source_line_id, inventory_item_id
                              INTO ln_source_line_id, ln_inv_item_id
                              FROM mtl_material_transactions
                             WHERE transaction_id = ln_transaction_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_source_line_id   := NULL;
                                ln_inv_item_id      := NULL;
                                print_log (
                                       ' Exceptin Msg for ln_source_line_id is null -  '
                                    || SUBSTR (SQLERRM, 1, 200));
                        END;

                        print_log (
                               ' Transaction Type ID - '
                            || ln_transaction_type_id
                            || ' - trx_source_line_id - '
                            || ln_source_line_id
                            || ' - ln_inv_item_id - '
                            || ln_inv_item_id);

                        -- using source line id, get the original order from the SO

                        IF ln_source_line_id IS NOT NULL
                        THEN
                            ln_ref_line_id           := NULL;
                            ln_ref_header_id         := NULL;

                            BEGIN
                                SELECT reference_line_id, reference_header_id
                                  INTO ln_ref_line_id, ln_ref_header_id
                                  FROM oe_order_lines_all
                                 WHERE line_id = ln_source_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_ref_line_id     := NULL;
                                    ln_ref_header_id   := NULL;
                                    print_log (
                                           ' Exceptin Msg for ln_ref_line_id is null -  '
                                        || SUBSTR (SQLERRM, 1, 200));
                            END;

                            print_log (
                                   ' Transaction Type ID - '
                                || ln_transaction_type_id
                                || ' - reference_line_id - '
                                || ln_ref_line_id
                                || ' - reference_header_id - '
                                || ln_ref_header_id);

                            -- Using the Refence header id which is Actual Order, get the Inv. and org. details

                            BEGIN
                                SELECT ship_from_org_id
                                  INTO ln_ship_org_id
                                  FROM oe_order_lines_all
                                 WHERE     header_id = ln_ref_header_id
                                       AND line_id = ln_ref_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_ship_org_id   := NULL;
                                    print_log (
                                           ' Exception Msg for ln_ship_org_id is null -  '
                                        || SUBSTR (SQLERRM, 1, 200));
                            END;

                            print_log (
                                   ' Transaction Type ID - '
                                || ln_transaction_type_id
                                || ' - ship_from_org_id - '
                                || ln_ship_org_id);

                            -- Now again find the latest transaction type id with the above org details

                            ln_transaction_type_id   := NULL;
                            ln_transaction_id        := NULL;

                            BEGIN
                                SELECT transaction_type_id, transaction_id
                                  INTO ln_transaction_type_id, ln_transaction_id
                                  FROM (  SELECT *
                                            FROM mtl_material_transactions mmt
                                           WHERE     mmt.inventory_item_id =
                                                     line.inventory_item_id
                                                 AND mmt.organization_id =
                                                     line.ship_from_org_id
                                                 AND EXISTS
                                                         (SELECT 1
                                                            FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                                           WHERE     ffvs.flex_value_set_id =
                                                                     ffvl.flex_value_set_id
                                                                 AND ffvl.enabled_flag =
                                                                     'Y'
                                                                 AND SYSDATE BETWEEN NVL (
                                                                                         ffvl.start_date_active,
                                                                                         SYSDATE)
                                                                                 AND NVL (
                                                                                         ffvl.end_date_active,
                                                                                         SYSDATE)
                                                                 AND ffvs.flex_value_set_name =
                                                                     'XXD_INV_COO_TRX_TYPES_VS'
                                                                 AND ffvl.attribute1 =
                                                                     mmt.transaction_type_id)
                                        ORDER BY creation_date DESC)
                                 WHERE ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_transaction_type_id   := NULL;
                                    ln_transaction_id        := NULL;
                                    print_log (
                                           ' Exception Msg for ln_ship_org_id as is Not null but derived Trxn ID is NULL for 15 -  '
                                        || SUBSTR (SQLERRM, 1, 200));
                            END;


                            -- Now loop through Collection

                            print_log (
                                   'Start of Coll Count for i is - '
                                || xxd_mmt_rec_tab.FIRST);

                            FOR i IN xxd_mmt_rec_tab.FIRST ..
                                     xxd_mmt_rec_tab.LAST
                            LOOP
                                ln_coll_cnt   := 0;

                                Print_log (
                                       'Entered into Coll Loop for ln_transaction_type_id - '
                                    || ln_transaction_type_id
                                    || ' and index i is - '
                                    || i);

                                xxd_mmt_rec_tab.EXTEND;

                                IF     xxd_mmt_rec_tab (i).trx_id =
                                       ln_transaction_id
                                   AND xxd_mmt_rec_tab (i).inventory_item_id =
                                       line.inventory_item_id
                                   AND xxd_mmt_rec_tab (i).trx_type_id =
                                       ln_transaction_type_id
                                   AND xxd_mmt_rec_tab (i).ship_from_org_id =
                                       line.ship_from_org_id
                                THEN
                                    lv_invalid_flag   := 'Y';
                                    lb_return_value   := FALSE;

                                    print_log (
                                        'Collection value is same as the retrieved value, So Exit the loop');
                                    print_log (
                                           ' Matching Transaction Type ID - '
                                        || ln_transaction_type_id
                                        || ' Inv Item ID - '
                                        || line.inventory_item_id
                                        || ' - organization_id - '
                                        || line.ship_from_org_id
                                        || ' - ln_transaction_id - '
                                        || ln_transaction_id);
                                ELSE
                                    ln_coll_cnt   := ln_coll_cnt + 1;

                                    print_log (
                                           'Entered into Else Coll Loop i for ln_coll_cnt - '
                                        || ln_coll_cnt);

                                    IF ln_coll_cnt = xxd_mmt_rec_tab.LAST
                                    THEN
                                        print_log (
                                            'Insert Records in to Coll I when record count matched ');

                                        xxd_mmt_rec_tab (ln_coll_cnt + 1).trx_id   :=
                                            ln_transaction_id;
                                        xxd_mmt_rec_tab (ln_coll_cnt + 1).inventory_item_id   :=
                                            line.inventory_item_id;
                                        xxd_mmt_rec_tab (ln_coll_cnt + 1).trx_type_id   :=
                                            ln_transaction_type_id;
                                        xxd_mmt_rec_tab (ln_coll_cnt + 1).ship_from_org_id   :=
                                            line.ship_from_org_id;
                                    END IF;
                                END IF;
                            END LOOP;

                            print_log (
                                   ' Transaction Type ID - '
                                || ln_transaction_type_id
                                || ' - ln_transaction_id - '
                                || ln_transaction_id);
                        ELSE
                            lv_invalid_flag   := 'Y';
                            lb_return_value   := FALSE;
                            print_log (
                                ' Exception Msg as ln_source_line_id is NOt found for RMA Receipt Trxn');
                        END IF;
                    ELSIF     ln_transaction_type_id <> 18
                          AND lb_trxn_value = TRUE
                    THEN
                        ln_trx_organization_id   := NULL;
                        ln_inv_item_id           := NULL;

                        IF ln_transaction_type_id = 61
                        THEN
                            BEGIN
                                SELECT transfer_organization_id, inventory_item_id
                                  INTO ln_trx_organization_id, ln_inv_item_id
                                  FROM mtl_material_transactions
                                 WHERE transaction_id = ln_transaction_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_trx_organization_id   := NULL;
                                    ln_inv_item_id           := NULL;
                                    print_log (
                                           ' Exceptin Msg for ln_trx_organization_id is null -  '
                                        || SUBSTR (SQLERRM, 1, 200));
                            END;

                            print_log (
                                   ' Transaction Type ID - '
                                || ln_transaction_type_id
                                || ' - ln_trx_organization_id - '
                                || ln_trx_organization_id
                                || ' - ln_inv_item_id - '
                                || ln_inv_item_id);

                            IF ln_trx_organization_id IS NOT NULL
                            THEN
                                ln_transaction_type_id   := NULL;
                                ln_transaction_id        := NULL;

                                BEGIN
                                    SELECT transaction_type_id, transaction_id
                                      INTO ln_transaction_type_id, ln_transaction_id
                                      FROM (  SELECT *
                                                FROM mtl_material_transactions mmt
                                               WHERE     mmt.inventory_item_id =
                                                         line.inventory_item_id
                                                     AND mmt.organization_id =
                                                         ln_trx_organization_id
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                                               WHERE     ffvs.flex_value_set_id =
                                                                         ffvl.flex_value_set_id
                                                                     AND ffvl.enabled_flag =
                                                                         'Y'
                                                                     AND SYSDATE BETWEEN NVL (
                                                                                             ffvl.start_date_active,
                                                                                             SYSDATE)
                                                                                     AND NVL (
                                                                                             ffvl.end_date_active,
                                                                                             SYSDATE)
                                                                     AND ffvs.flex_value_set_name =
                                                                         'XXD_INV_COO_TRX_TYPES_VS'
                                                                     AND ffvl.attribute1 =
                                                                         mmt.transaction_type_id)
                                            ORDER BY creation_date DESC)
                                     WHERE ROWNUM = 1;

                                    print_log (
                                           ' Transaction Type ID - '
                                        || ln_transaction_type_id
                                        || ' - ln_trx_organization_id - '
                                        || ln_trx_organization_id
                                        || ' - ln_transaction_id - '
                                        || ln_transaction_id
                                        || ' ln_trx_organization_id as NOT NULL ');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_transaction_type_id   := NULL;
                                        ln_transaction_id        := NULL;
                                        print_log (
                                               ' Exception Msg for ln_trx_organization_id as is Not null but derived Trxn ID is NULL for 61 -  '
                                            || SUBSTR (SQLERRM, 1, 200));
                                END;


                                print_log (
                                       'Matching Transaction Type ID - '
                                    || ln_transaction_type_id
                                    || ' with Transaction ID - '
                                    || ln_transaction_id);


                                -- Now loop through Collection

                                print_log (
                                       'Start of Coll Count for j is - '
                                    || xxd_mmt_rec_tab.FIRST);

                                FOR j IN xxd_mmt_rec_tab.FIRST ..
                                         xxd_mmt_rec_tab.LAST
                                LOOP
                                    ln_coll_cnt   := 0;

                                    print_log (
                                           'Entered into Coll Loop for ln_transaction_type_id j - '
                                        || ln_transaction_type_id);

                                    xxd_mmt_rec_tab.EXTEND;

                                    IF     xxd_mmt_rec_tab (j).trx_id =
                                           ln_transaction_id
                                       AND xxd_mmt_rec_tab (j).inventory_item_id =
                                           line.inventory_item_id
                                       AND xxd_mmt_rec_tab (j).trx_type_id =
                                           ln_transaction_type_id
                                       AND xxd_mmt_rec_tab (j).ship_from_org_id =
                                           line.ship_from_org_id
                                    THEN
                                        print_log (
                                            'Collection value is same as the retrieved value, So Exit the loop');
                                        print_log (
                                               ' Matching Transaction Type ID - '
                                            || ln_transaction_type_id
                                            || ' Inv Item ID - '
                                            || line.inventory_item_id
                                            || ' - organization_id - '
                                            || line.ship_from_org_id
                                            || ' - ln_transaction_id - '
                                            || ln_transaction_id
                                            || ' ln_transaction_id ');
                                        lv_invalid_flag   := 'Y';
                                        lb_return_value   := FALSE;
                                    ELSE
                                        ln_coll_cnt   := ln_coll_cnt + 1;

                                        IF ln_coll_cnt = xxd_mmt_rec_tab.LAST
                                        THEN
                                            xxd_mmt_rec_tab (ln_coll_cnt + 1).trx_id   :=
                                                ln_transaction_id;
                                            xxd_mmt_rec_tab (ln_coll_cnt + 1).inventory_item_id   :=
                                                line.inventory_item_id;
                                            xxd_mmt_rec_tab (ln_coll_cnt + 1).trx_type_id   :=
                                                ln_transaction_type_id;
                                            xxd_mmt_rec_tab (ln_coll_cnt + 1).ship_from_org_id   :=
                                                line.ship_from_org_id;

                                            print_log (
                                                'Records are not matched to values in Collection, So inserting record');

                                            print_log (
                                                   '  Transaction Type ID - '
                                                || ln_transaction_type_id
                                                || ' Inv Item ID - '
                                                || line.inventory_item_id
                                                || ' - organization_id - '
                                                || line.ship_from_org_id
                                                || ' - ln_transaction_id - '
                                                || ln_transaction_id
                                                || ' ln_transaction_id ');
                                        END IF;
                                    END IF;
                                END LOOP;
                            ELSE
                                lv_invalid_flag   := 'Y';
                                lb_return_value   := FALSE;
                                print_log (
                                    ' Exception Msg as ln_source_line_id is Not found for DC to DC Transfer Trxn');
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            -- Once out of loop final trx id and trx type id will have values

            -- With the fecthed po based transactions and derive the Supplier and Site details

            ln_trx_source_id                        := NULL;
            lv_vendor_site_id                       := NULL;
            ln_trx_source_line_d                    := NULL;

            IF lv_invalid_flag = 'Y'
            THEN
                lv_vendor_site_id   := 'UNIDENTIFIED';
            END IF;

            print_log ('Final Flag is - ' || lv_invalid_flag);

            IF ln_final_trx_type_id IN (18, 71)
            THEN
                IF ln_final_trx_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT transaction_source_id
                          INTO ln_trx_source_id
                          FROM mtl_material_transactions
                         WHERE transaction_id = ln_final_trx_id;

                        print_log (
                               ' Final ln_trx_source_id is - '
                            || ln_trx_source_id
                            || ' -  for ln_final_trx_id - '
                            || ln_final_trx_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_trx_source_id   := NULL;
                            print_log (
                                   ' Exception Msg as ln_trx_source_id is Not found for ln_final_trx_id - '
                                || SQLERRM);
                    END;

                    IF ln_trx_source_id IS NOT NULL
                    THEN
                        BEGIN
                            SELECT vendor_site_id
                              INTO lv_vendor_site_id
                              FROM po_headers_all
                             WHERE     po_header_id = ln_trx_source_id
                                   AND attribute_category =
                                       'PO Data Elements';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_vendor_site_id   := NULL;
                                print_log (
                                       ' Exception Msg as ln_vendor_site_id is Not found for ln_trx_source_id - '
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;

                print_log (' Final Vendor Site ID - ' || lv_vendor_site_id);
            END IF;

            -- Now update the delivery

            UPDATE wsh_delivery_details
               SET attribute6   = lv_vendor_site_id
             WHERE delivery_detail_id = line.delivery_detail_id;

            COMMIT;
        END LOOP;
    END COO_PRC;
END XXD_ONT_COO_PKG;
/
