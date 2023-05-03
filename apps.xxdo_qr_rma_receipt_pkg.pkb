--
-- XXDO_QR_RMA_RECEIPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_QR_RMA_RECEIPT_PKG"
AS
    /*
      REM $HEADER: XXDO_QR_RMA_RECEIPT_PKG.PKB 1.0 17-JUL-2013 $
      REM ===================================================================================================
      REM             (C) COPYRIGHT DECKERS OUTDOOR CORPORATION
      REM                       ALL RIGHTS RESERVED
      REM ===================================================================================================
      REM
      REM NAME          : XXDO_QR_RMA_RECEIPT_PKG.PKB
      REM
      REM PROCEDURE     :
      REM SPECIAL NOTES : MAIN PROCEDURE CALLED BY CONCURRENT MANAGER
      REM
      REM PROCEDURE     :
      REM SPECIAL NOTES :
      REM
      REM         CR #  :
      REM ===================================================================================================
      REM HISTORY:  CREATION DATE :17-JUL-2013, CREATED BY : VENKATA RAMA BATTU
      REM
      REM MODIFICATION HISTORY
      REM PERSON                  DATE              VERSION              COMMENTS AND CHANGES MADE
      REM -------------------    ----------         ----------           ------------------------------------
      REM VENKATA RAMA BATTU     17-JUL-2013         1.0                 1. BASE LINED FOR DELIVERY
      REM BT Technology Team     19-Feb-2015         1.1                 Updated for BT
      REM Siva R                 12-May-2015         1.2                 Fixed the bugs reported in CCR#CCR0004847
      REM
      REM ===================================================================================================
      */
    gn_user_id              NUMBER := apps.fnd_global.user_id;
    gn_resp_id              NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id         NUMBER := apps.fnd_global.resp_appl_id;
    gn_group_id             NUMBER;
    s_rep                   s_summary_rep;
    s_rep_idx               NUMBER := 1;
    subinv_trx              subinve_tbl;
    subinv_trx_idx          NUMBER := 1;
    gn_failed_validations   NUMBER := 0;
    gn_organization_id      NUMBER;
    gn_mti_count            NUMBER := 0;

    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_mode IN VARCHAR2, pv_dummy1 IN VARCHAR2, pv_rma_header_id IN NUMBER, pv_dummy2 IN VARCHAR2
                    , pn_organization_id IN NUMBER)
    IS
        ln_rec_cnt   NUMBER;
    BEGIN
        SELECT RCV_INTERFACE_GROUPS_S.NEXTVAL INTO gn_group_id FROM DUAL;

        process_qa_results (pn_rma_id   => pv_rma_header_id,
                            pn_org_id   => pn_organization_id);
        insert_into_rti (p_rma_id    => pv_rma_header_id,
                         p_org_id    => pn_organization_id,
                         p_rec_cnt   => ln_rec_cnt);

        IF ln_rec_cnt >= 1
        THEN
            submit_rtp;
            success_report;
            error_rec_rcv_interface;
            COMMIT;
            subinve_transfer;
            launch_int_mgr;
            subinve_report;
            subinve_transfer_error_report;
            purge_debug_tbl;
        ELSE
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '==============================================================================================================');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '***********************NO ELIGIBLE RECORDS FOR THIS REQUEST*********************************************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '==============================================================================================================');
        END IF;

        IF gn_failed_validations > 0
        THEN
            IF gn_organization_id = 108
            THEN
                UPDATE APPS.QA_RESULTS QA
                   SET LINE_ID = NULL, CHARACTER12 = NULL, REQUEST_ID = NULL,
                       CHARACTER100 = 'E'
                 WHERE REQUEST_ID = gn_group_id AND CHARACTER100 IS NULL;
            ELSE
                UPDATE APPS.QA_RESULTS QA
                   SET LINE_ID = NULL, CHARACTER11 = NULL, REQUEST_ID = NULL,
                       CHARACTER100 = 'E'
                 WHERE REQUEST_ID = gn_group_id AND CHARACTER100 IS NULL;
            END IF;

            retcode   := 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'ERROR OCCURED IN MAIN PROCEDURE ERROR MESSAGE-' || SQLERRM);
    END;

    PROCEDURE print_line (p_mode    IN VARCHAR2 DEFAULT 'L',
                          p_input   IN VARCHAR2)
    IS
    BEGIN
        IF p_mode = 'O'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.output, p_input);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, p_input);
        END IF;
    END print_line;

    FUNCTION get_collection_id (p_hdr_id    IN NUMBER,
                                p_line_id   IN NUMBER,
                                p_sku_id    IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_collection   VARCHAR2 (2000);
    BEGIN
        SELECT RTRIM (XMLAGG (XMLELEMENT (e, collection_id || ',')).EXTRACT ('//text()'), ',') collection_id
          INTO lv_collection
          FROM (  SELECT qr.collection_id, qr.rma_header_id, qr.line_id,
                         qr.item_id
                    FROM do_custom.do_qa_results_v qr /* replaced the qr_results table with view do_custom.do_qa_results_v, ccr# CCR#CCR0004847*/
                GROUP BY collection_id, qr.rma_header_id, qr.line_id,
                         qr.item_id) qr
         WHERE     DECODE (p_hdr_id, NULL, 1, qr.rma_header_id) =
                   DECODE (p_hdr_id, NULL, 1, p_hdr_id)
               AND DECODE (p_line_id, NULL, 1, qr.line_id) =
                   DECODE (p_line_id, NULL, 1, p_line_id)
               AND DECODE (p_sku_id, NULL, 1, qr.item_id) =
                   DECODE (p_sku_id, NULL, 1, p_sku_id);

        RETURN lv_collection;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_collection   := NULL;
            RETURN lv_collection;
    END;

    PROCEDURE process_qa_results (pn_rma_id IN NUMBER, pn_org_id IN NUMBER)
    IS
        ln_err_cnt        VARCHAR2 (1);
        lv_err_msg        VARCHAR2 (2000);
        lv_order_number   NUMBER;
        ln_org_id         NUMBER;
        order_info        cust_info;
        rma_items         rma_item_list;
        rma_id_cur        VARCHAR2 (2000);
        lv_where          VARCHAR2 (2000);
        ln_rma_id         NUMBER;
        item_sql          VARCHAR2 (2000);

        TYPE item_cur_rec IS RECORD
        (
            collection_id    NUMBER,
            occurrence       NUMBER,
            line_id          NUMBER,
            item_id          NUMBER,
            qty              NUMBER
        );

        item_cur          item_cur_rec;

        TYPE cur_typ IS REF CURSOR;

        c                 cur_typ;
        j                 cur_typ;
    BEGIN
        lv_where   := NULL;

        IF pn_rma_id IS NOT NULL
        THEN
            lv_where   := ' AND QR.RMA_HEADER_ID   = ' || pn_rma_id;


            BEGIN
                SELECT MAX (oola.ship_from_org_id)
                  INTO gn_organization_id
                  FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
                 WHERE     ooha.header_id = pn_rma_id
                       AND oola.header_id = ooha.header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        IF pn_org_id IS NOT NULL
        THEN
            lv_where             :=
                lv_where || ' ' || 'AND QR.ORGANIZATION_ID =' || pn_org_id;

            gn_organization_id   := pn_org_id;
        END IF;

        lv_where   :=
               lv_where
            || ' '
            || 'AND '
            || get_column ('CUST_NUM')
            || ' IS NOT NULL';
        lv_where   :=
               lv_where
            || ' '
            || 'AND '
            || get_column ('DISP_CODE')
            || ' IS NOT NULL';
        lv_where   :=
               lv_where
            || ' '
            || 'AND '
            || get_column ('LINE_ID')
            || ' IS  NULL';
        rma_id_cur   :=
               'SELECT DISTINCT QR.RMA_HEADER_ID
                       FROM  APPS.QA_RESULTS QR
                       WHERE  NVL (QR.CHARACTER100, ''N'') IN (''N'', ''E'')'
            || lv_where;
        debug_tbl (
            p_rma_id   => ln_rma_id,
            p_desc     => ' Step - 1  Proc-process_qa_results rma_id_cur',
            p_comm     => rma_id_cur);

        OPEN c FOR rma_id_cur;

        LOOP
            FETCH c INTO ln_rma_id;

            EXIT WHEN c%NOTFOUND;
            ln_err_cnt        := apps.fnd_api.g_true;
            lv_err_msg        := NULL;
            order_info        := NULL;
            lv_order_number   := NULL;
            ln_org_id         := NULL;

            /* =========================================================================
                --------------------VALIDATION RMA STATUS----------------------------
              =========================================================================*/
            BEGIN
                SELECT ooh.order_number, gn_organization_id
                  INTO lv_order_number, ln_org_id
                  FROM apps.oe_order_headers_all ooh
                 WHERE     ooh.header_id = ln_rma_id
                       AND ooh.flow_status_code = 'BOOKED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_err_cnt              := apps.fnd_api.g_false;
                    gn_failed_validations   := gn_failed_validations + 1;
                    print_line (
                        'L',
                           'Order number not in booked stage for RMA Number - '
                        || get_rma_num (ln_rma_id)
                        || '  '
                        || 'Error code is:- '
                        || SQLERRM);
                    debug_tbl (
                        p_rma_id   => ln_rma_id,
                        p_desc     =>
                            'Step-2 Proc-process_qa_results RMA Num Validation',
                        p_comm     => get_rma_num (ln_rma_id));
            END;

            IF ln_err_cnt <> apps.fnd_api.g_false
            THEN
                item_sql   :=
                       'SELECT   qr.collection_id,qr.occurrence,dqrv.line_id,dqrv.item_id,SUM (dqrv.QUANTITY)
                          FROM APPS.QA_RESULTS QR,
                               do_custom.do_qa_results_v dqrv
                         WHERE qr.plan_id = dqrv.plan_id
                         AND  qr.collection_id = dqrv.collection_id
                         AND  qr.occurrence = dqrv.occurrence
                         AND qr.rma_header_id = dqrv.rma_header_id
                         AND qr.organization_id = dqrv.organization_id
                         AND NVL (QR.CHARACTER100, ''N'') IN (''N'', ''E'')
                         AND dqrv.customer_number IS NOT NULL
                         AND dqrv.disposition_code IS NOT NULL
                         AND qr.rma_header_id = '
                    || ln_rma_id
                    || ' GROUP BY dqrv.line_id,dqrv.item_id,qr.collection_id,qr.occurrence';
                debug_tbl (
                    p_rma_id   => ln_rma_id,
                    p_desc     => 'Step-3 Proc-process_qa_results item_sql',
                    p_comm     => item_sql);

                OPEN j FOR item_sql;

                LOOP
                    FETCH j INTO item_cur;

                    EXIT WHEN j%NOTFOUND;

                    BEGIN
                          SELECT ool.line_id, ordered_item, inventory_item_id,
                                 ordered_quantity
                            BULK COLLECT INTO rma_items
                            FROM apps.oe_order_lines_all ool
                           WHERE     ool.header_id = ln_rma_id
                                 AND ool.line_id = item_cur.line_id
                                 AND ool.inventory_item_id = item_cur.item_id
                                 AND ool.flow_status_code = 'AWAITING_RETURN'
                        ORDER BY ordered_quantity DESC;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt   := apps.fnd_api.g_false;
                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                            print_line (
                                'L',
                                   'Error occured while getting rma quantity for item :- '
                                || apps.iid_to_sku (item_cur.item_id)
                                || ' RA NUMBER#-LINE# '
                                || get_rma_num (ln_rma_id)
                                || '-'
                                || get_rma_line_num (item_cur.line_id)
                                || ' AND ERROR MSG IS- '
                                || SQLERRM);
                            debug_tbl (
                                p_rma_id   => ln_rma_id,
                                p_desc     =>
                                    'Step-4 Proc-process_qa_results RMA Item qty validation',
                                p_comm     =>
                                       'RMA#-LINE#'
                                    || get_rma_num (ln_rma_id)
                                    || '-'
                                    || get_rma_line_num (item_cur.line_id)
                                    || ' '
                                    || 'SKU#'
                                    || item_cur.item_id);
                    END;


                    /* RMA LINE ID IS UPDATED DIRECTLY,  CCR#CCR0004847  */
                    BEGIN
                        IF ln_err_cnt <> apps.fnd_api.g_false
                        THEN
                            debug_tbl (
                                p_rma_id   => ln_rma_id,
                                p_desc     => 'Step-5 Proc-process_qa_results',
                                p_comm     =>
                                       'Updating qa_results table line_id column '
                                    || 'RMA#-LINE#'
                                    || get_rma_num (ln_rma_id)
                                    || '-'
                                    || get_rma_line_num (item_cur.line_id)
                                    || ' '
                                    || 'SKU#'
                                    || item_cur.item_id);

                            /*  assign_line_id_to_qa (p_items_tbl   => rma_items,
                                                    p_rma_id      => ln_rma_id,
                                                    p_item_id     => item_cur.item_id);     */

                            IF gn_organization_id = 108
                            THEN
                                UPDATE apps.qa_results
                                   SET line_id = item_cur.line_id, item_id = NVL (item_id, item_cur.item_id), character12 = TO_CHAR (item_cur.line_id),
                                       request_id = gn_group_id
                                 WHERE     collection_id =
                                           item_cur.collection_id
                                       AND occurrence = item_cur.occurrence
                                       AND rma_header_id = ln_rma_id;
                            ELSE
                                UPDATE apps.qa_results
                                   SET line_id = item_cur.line_id, item_id = NVL (item_id, item_cur.item_id), character11 = TO_CHAR (item_cur.line_id),
                                       request_id = gn_group_id
                                 WHERE     collection_id =
                                           item_cur.collection_id
                                       AND occurrence = item_cur.occurrence
                                       AND rma_header_id = ln_rma_id;
                            END IF;
                        END IF;
                    END;
                END LOOP;

                CLOSE j;
            ELSE
                gn_failed_validations   := gn_failed_validations + 1;
                print_line (
                    'L',
                       'Error occured while validating  order number- '
                    || lv_order_number
                    || '  AND Error message is- '
                    || lv_err_msg);
                debug_tbl (
                    p_rma_id   => ln_rma_id,
                    p_desc     => 'Step-16 Proc-process_qa_results',
                    p_comm     =>
                        'Failed in updating the line_id column of QA_RESULTS tabke');
            END IF;
        END LOOP;

        CLOSE c;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_tbl (
                p_rma_id   => ln_rma_id,
                p_desc     => 'Step-17 Exception in Process QA Results',
                p_comm     => SQLERRM);

            CLOSE c;

            CLOSE j;
    END;

    PROCEDURE insert_into_rti (p_rma_id    IN     NUMBER,
                               p_org_id    IN     NUMBER,
                               p_rec_cnt      OUT NUMBER)
    IS
        ln_err_cnt         VARCHAR2 (1) := apps.fnd_api.g_true;
        lv_err_msg         VARCHAR2 (2000);
        ln_item_id         NUMBER;
        lv_order_qty_uom   VARCHAR2 (20);
        lv_uom_code        VARCHAR2 (50);
        order_info         cust_info;
        lv_locator         VARCHAR2 (100);
        ln_locator_id      NUMBER;
        lv_subinventory    VARCHAR2 (100);
        ln_rma_num         NUMBER;
        itm                NUMBER;
        qty                NUMBER;
        ln_serial_cnt      NUMBER;
        serial             VARCHAR2 (30);
        lv_sql             VARCHAR2 (2000);
        -- lv_long_loc        VARCHAR2(100);
        -- locator_null       exception;
        rma_id_cur         VARCHAR2 (2000);
        qa_items_cur       VARCHAR2 (2000);
        --serial_cur         VARCHAR2(2000);
        lv_where           VARCHAR2 (2000);
        ln_rma_id          NUMBER;

        TYPE cur_typ IS REF CURSOR;

        c                  cur_typ;
        i                  cur_typ;
        j                  cur_typ;

        TYPE items_record IS RECORD
        (
            organization_id    apps.qa_results.organization_id%TYPE,
            quantity           apps.qa_results.quantity%TYPE,
            item_id            apps.qa_results.item_id%TYPE,
            rma_header_id      apps.qa_results.rma_header_id%TYPE,
            customer_num       apps.qa_results.character1%TYPE,
            line_id            apps.qa_results.line_id%TYPE
        );

        items_rec          items_record;

        TYPE serial_record IS RECORD
        (
            serial             VARCHAR2 (50),
            organization_id    NUMBER,
            serial_status      VARCHAR2 (50)
        );

        serial_rec         serial_record;
    BEGIN
        p_rec_cnt   := 0;
        lv_where    := NULL;

        IF p_rma_id IS NOT NULL
        THEN
            lv_where   :=
                ' AND qr.rma_header_id   = TO_NUMBER(''' || p_rma_id || ''')';
        END IF;

        IF p_org_id IS NOT NULL
        THEN
            lv_where   :=
                   lv_where
                || ' AND qr.organization_id =TO_NUMBER('''
                || p_org_id
                || ''')';
        END IF;

        lv_where    :=
            lv_where || ' AND ' || get_column ('CUST_NUM') || ' IS NOT NULL';
        lv_where    :=
            lv_where || ' AND ' || get_column ('DISP_CODE') || ' IS NOT NULL';
        lv_where    :=
            lv_where || ' AND ' || get_column ('LINE_ID') || ' IS NOT NULL';
        rma_id_cur   :=
               'SELECT DISTINCT QR.RMA_HEADER_ID
                       FROM  APPS.QA_RESULTS QR
                       WHERE  NVL (QR.CHARACTER100, ''N'') IN (''N'', ''E'')'
            || lv_where;
        debug_tbl (p_rma_id   => p_rma_id,
                   p_desc     => 'Step-18 insert_into_rti rma_id_cur sql is',
                   p_comm     => rma_id_cur);

        -- FOR I IN RMA_ID_CUR
        OPEN c FOR rma_id_cur;

        LOOP
            FETCH c INTO ln_rma_id;

            EXIT WHEN c%NOTFOUND;
            order_info   := NULL;

            BEGIN
                SELECT ra.customer_name, ra.customer_number, ra.customer_id,
                       ott.order_category_code, ooh.attribute5, ood.organization_code,
                       hsa.cust_acct_site_id
                  INTO order_info
                  FROM apps.oe_order_headers_all ooh, --Start Changes by BT Technology Team for BT on 19-Feb-2015,  v1.1
                                                      --apps.ra_customers ra,
                                                      apps.xxd_ra_customers_v ra, --End Changes by BT Technology Team for BT on 19-Feb-2015,  v1.1
                                                                                  apps.oe_transaction_types_all ott,
                       apps.org_organization_definitions ood, apps.hz_cust_site_uses_all hsa
                 WHERE     ooh.header_id = ln_rma_id
                       AND ooh.sold_to_org_id = ra.customer_id
                       AND ooh.ship_from_org_id = ood.organization_id
                       AND ooh.order_type_id = ott.transaction_type_id
                       AND hsa.site_use_id = ooh.ship_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_err_cnt              := apps.fnd_api.g_false;
                    gn_failed_validations   := gn_failed_validations + 1;
                    print_line (
                        'L',
                           'procedure insert_into_rti'
                        || '-'
                        || ' error occured while getting customer name and numner for RA#'
                        || get_rma_num (ln_rma_id)
                        || '   error code :-'
                        || SQLERRM);
                    debug_tbl (
                        p_rma_id   => ln_rma_id,
                        p_desc     =>
                            'Step-19 Proc:insert_into_rti rma_id_cur sql is',
                        p_comm     =>
                               ' Error occured while getting customer name and numner for RA#'
                            || get_rma_num (ln_rma_id)
                            || '   ERROR CODE :-'
                            || SQLERRM);
            END;

            IF ln_err_cnt <> apps.fnd_api.g_false
            THEN
                qa_items_cur   :=
                       'SELECT  dqrv.organization_id
                  ,SUM (dqrv.quantity) quantity
                  ,dqrv.item_id
                  ,dqrv.rma_header_id
                  ,dqrv.customer_number
                  ,dqrv.line_id
                  FROM apps.qa_results qr,
                       do_custom.do_qa_results_v dqrv
                  WHERE qr.plan_id = dqrv.plan_id
                  AND  qr.collection_id = dqrv.collection_id
                  AND  qr.occurrence = dqrv.occurrence
                  AND qr.rma_header_id = dqrv.rma_header_id
                  AND qr.organization_id = dqrv.organization_id
                  AND nvl (qr.character100, ''N'') in (''N'', ''E'')
                  AND dqrv.customer_number IS NOT NULL
                  AND dqrv.disposition_code IS NOT NULL
                  AND dqrv.serial_status IS NOT NULL
                  AND dqrv.rma_header_id = '
                    || ln_rma_id
                    || ' GROUP BY  dqrv.organization_id, dqrv.item_id,dqrv.rma_header_id,dqrv.customer_number,dqrv.line_id';

                debug_tbl (
                    p_rma_id   => p_rma_id,
                    p_desc     =>
                        'Step-20 Proc: insert_into_rti qa_items_cur sql is',
                    p_comm     => qa_items_cur);

                OPEN i FOR qa_items_cur;

                LOOP
                    FETCH i INTO items_rec;

                    EXIT WHEN i%NOTFOUND;
                    ln_item_id         := NULL;
                    lv_order_qty_uom   := NULL;
                    lv_uom_code        := NULL;
                    lv_locator         := NULL;
                    ln_locator_id      := NULL;
                    lv_subinventory    := NULL;
                    ln_rma_num         := NULL;
                    lv_sql             := NULL;

                    /*==============================================================================================
                     ******************** FETCHING ITEM_ID,UOM CODES *****************************************
                    =============================================================================================*/
                    BEGIN
                        SELECT ool.inventory_item_id, msib.primary_unit_of_measure, msib.primary_uom_code,
                               NVL (ool.subinventory, 'RETURNS'), ooh.order_number
                          INTO ln_item_id, lv_order_qty_uom, lv_uom_code, lv_subinventory,
                                         ln_rma_num
                          FROM apps.oe_order_lines_all ool, apps.mtl_system_items_b msib, apps.oe_order_headers_all ooh
                         WHERE     ool.header_id = ln_rma_id
                               AND ool.inventory_item_id = items_rec.item_id
                               AND ool.flow_status_code = 'AWAITING_RETURN'
                               AND ool.line_id = items_rec.line_id   --LINE_ID
                               AND ool.inventory_item_id =
                                   msib.inventory_item_id
                               AND ool.ship_from_org_id =
                                   msib.organization_id
                               AND ool.header_id = ooh.header_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_item_id   := NULL;
                            ln_err_cnt   := apps.fnd_api.g_false;
                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                            print_line (
                                'L',
                                   'Procedure insert_into_rti'
                                || '-'
                                || ' item does not exist for this RA# :-'
                                || get_rma_num (ln_rma_id)
                                || ' SKU :'
                                || apps.iid_to_sku (items_rec.item_id)
                                || '   ERROR MESSAGE IS-'
                                || SQLERRM);
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     => 'Step-21 Proc:insert_into_rti',
                                p_comm     =>
                                       ' item does not exist for this RA# :-'
                                    || get_rma_num (ln_rma_id)
                                    || ' SKU :'
                                    || apps.iid_to_sku (items_rec.item_id)
                                    || '   ERROR MESSAGE IS-'
                                    || SQLERRM);
                        WHEN OTHERS
                        THEN
                            ln_item_id   := NULL;
                            ln_err_cnt   := apps.fnd_api.g_false;
                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                            print_line (
                                'L',
                                   'procedure insert_into_rti'
                                || '-'
                                || 'error occured while validating RMA item for RMA# :-'
                                || get_rma_num (ln_rma_id)
                                || ' and SKU-'
                                || apps.iid_to_sku (items_rec.item_id)
                                || ' and line_id - '
                                || items_rec.line_id
                                || ' Collection Id :'
                                || get_collection_id (ln_rma_id,
                                                      items_rec.line_id,
                                                      items_rec.item_id)
                                || '   Error code is :-'
                                || SQLERRM);
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     => 'Step-22 proc: insert_into_rti',
                                p_comm     =>
                                       'error occured while validating RMA item for RMA# :-'
                                    || get_rma_num (ln_rma_id)
                                    || ' and SKU-'
                                    || apps.iid_to_sku (items_rec.item_id)
                                    || ' and line_id - '
                                    || items_rec.line_id
                                    || ' Collection Id :'
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          items_rec.item_id)
                                    || '   Error code is :-'
                                    || SQLERRM);
                    END;

                    /*==============================================================================================
                         ------------------FETCHING LOCAROT CODE OR DISPOSITION CODE------------------
                    =============================================================================================*/
                    BEGIN
                        SELECT TRIM (flv.description)
                          INTO lv_locator
                          FROM apps.fnd_lookup_values flv
                         WHERE     flv.lookup_type = 'XXDO_SERIAL_RETURNS'
                               AND flv.language = USERENV ('LANG')
                               AND flv.meaning = 'DEFAULT';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt   := apps.fnd_api.g_false;
                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                            print_line (
                                'L',
                                   'procedure insert_into_rti'
                                || '-'
                                || 'Error getting default locator code from lookup for RA# '
                                || get_rma_num (ln_rma_id)
                                || ' and SKU-'
                                || apps.iid_to_sku (items_rec.item_id)
                                || ' and line_id - '
                                || items_rec.line_id
                                || ' Collection Id :'
                                || get_collection_id (ln_rma_id,
                                                      items_rec.line_id,
                                                      items_rec.item_id)
                                || '   ERROR CODE IS :-'
                                || SQLERRM);
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     => 'Step-23 proc: insert_into_rti',
                                p_comm     =>
                                       'Error getting default locator code from lookup for RA# '
                                    || get_rma_num (ln_rma_id)
                                    || '-'
                                    || get_rma_line_num (ln_rma_id)
                                    || ' and SKU-'
                                    || apps.iid_to_sku (items_rec.line_id)
                                    || ' and line_id - '
                                    || items_rec.line_id
                                    || ' Collection Id :'
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          items_rec.item_id)
                                    || '   ERROR CODE IS :-'
                                    || SQLERRM);
                    END;

                    debug_tbl (
                        p_rma_id   => p_rma_id,
                        p_desc     =>
                            'Step-24 proc: insert_into_rti lookup default locator :',
                        p_comm     => lv_locator);

                    /* *********************************************************************************
     ----------------------FETCHING LOCATOR IF THE QUANTITY IS 1-----------------------
       ***********************************************************************************/
                    BEGIN
                        lv_sql   :=
                               'SELECT qr.item_id,SUM(qr.quantity)
                       FROM apps.qa_results qr
                       WHERE NVL (QR.CHARACTER100, ''N'') IN (''N'', ''E'')
                         AND QR.RMA_HEADER_ID = '
                            || ln_rma_id
                            || ' AND QR.item_id = '
                            || items_rec.item_id
                            || ' AND '
                            || get_column ('LINE_ID')
                            || ' = '
                            || items_rec.line_id
                            || ' AND '
                            || get_column ('CUST_NUM')
                            || ' IS NOT NULL'
                            || ' AND '
                            || get_column ('DISP_CODE')
                            || ' IS NOT NULL'
                            || ' GROUP BY ITEM_ID';
                        debug_tbl (
                            p_rma_id   => p_rma_id,
                            p_desc     =>
                                'Step-25 proc: insert_into_rti item,sum qty lv_sql :',
                            p_comm     => lv_sql);

                        EXECUTE IMMEDIATE lv_sql
                            INTO itm, qty;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt   := apps.fnd_api.g_false;
                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                            print_line (
                                'L',
                                   'Error Getting Item_id and Sum of qty in INSERT_INTO_RTI Proc- '
                                || SQLERRM
                                || 'For RA# '
                                || get_rma_num (ln_rma_id)
                                || ' Collection id: '
                                || get_collection_id (ln_rma_id,
                                                      items_rec.line_id,
                                                      items_rec.item_id));
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     =>
                                    'Step-26 proc: insert_into_rti :',
                                p_comm     =>
                                       'Error Getting Item_id and Sum of qty in INSERT_INTO_RTI Proc- '
                                    || SQLERRM
                                    || 'For RA# '
                                    || get_rma_num (ln_rma_id)
                                    || ' Collection id: '
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          items_rec.item_id));
                    END;

                    IF qty = 1
                    THEN
                        BEGIN
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     => 'proc: insert_into_rti',
                                p_comm     =>
                                       'Locator for: Line_id'
                                    || items_rec.line_id
                                    || ' '
                                    || 'item_id:'
                                    || items_rec.item_id);
                            lv_sql   :=
                                   ' SELECT TRIM (get_locator (flv.description,qr.organization_id))
                            FROM apps.fnd_lookup_values flv,
                                 apps.qa_results qr
                           WHERE FLV.LOOKUP_TYPE = ''XXDO_SERIAL_RETURNS''
                             AND FLV.LANGUAGE = USERENV (''LANG'')
                             AND FLV.LOOKUP_CODE = '
                                || get_column ('DISP_CODE')
                                || ' AND QR.RMA_HEADER_ID = '
                                || ln_rma_id
                                || ' AND QR.ITEM_ID = '
                                || items_rec.item_id
                                || ' AND '
                                || get_column ('LINE_ID')
                                || ' = '
                                || items_rec.line_id
                                || ' AND '
                                || get_column ('CUST_NUM')
                                || ' IS NOT NULL'
                                || ' AND '
                                || get_column ('CUST_NAME')
                                || ' IS NOT NULL'
                                || ' AND '
                                || get_column ('SERIAL_STATUS')
                                || ' IS NOT NULL';
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     =>
                                    'Step-27 proc: insert_into_rti locator lv_sql :',
                                p_comm     => lv_sql);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_err_cnt   := apps.fnd_api.g_false;
                                gn_failed_validations   :=
                                    gn_failed_validations + 1;
                                print_line (
                                    'L',
                                       'Error while getting Locator From lookup in INSERT_INTO_RTI Procedure-'
                                    || SQLERRM);
                                print_line (
                                    'L',
                                       'RA#'
                                    || get_rma_num (ln_rma_id)
                                    || 'SKU :'
                                    || apps.iid_to_sku (items_rec.item_id)
                                    || 'AND line_id - '
                                    || items_rec.line_id
                                    || ' Collection Id :'
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          items_rec.item_id));
                                debug_tbl (
                                    p_rma_id   => p_rma_id,
                                    p_desc     =>
                                        'Step-28 proc: insert_into_rti :',
                                    p_comm     =>
                                           'Error getting Locator From lookup -'
                                        || SQLERRM);
                        END;
                    END IF;

                    /* *********************************************************************************
                        ----------------------FETCHING INVENTORY LOCATOR ID-----------------------
                      ***********************************************************************************/
                    BEGIN
                        SELECT mil.inventory_location_id
                          INTO ln_locator_id
                          FROM apps.mtl_item_locations mil
                         WHERE        mil.segment1
                                   || '.'
                                   || mil.segment2
                                   || '.'
                                   || mil.segment3
                                   || '.'
                                   || mil.segment4
                                   || '.'
                                   || mil.segment5 =
                                   NVL (lv_locator, 1)
                               AND mil.organization_id =
                                   items_rec.organization_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt              := apps.fnd_api.g_false;
                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                            ln_locator_id           := NULL;
                            print_line (
                                'L',
                                   'Procedure insert_into_rti'
                                || '-'
                                || 'SQL ERRM-'
                                || SQLERRM
                                || '  '
                                || 'Error occure while getting locator id for locator:- '
                                || lv_locator
                                || ' for RA#'
                                || get_rma_num (ln_rma_id)
                                || 'and LINE_ID-'
                                || items_rec.line_id
                                || 'Organization_id -'
                                || items_rec.organization_id
                                || 'Collection Id :'
                                || get_collection_id (ln_rma_id,
                                                      items_rec.line_id,
                                                      NULL));
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     =>
                                    'Step-29 proc: insert_into_rti :',
                                p_comm     =>
                                       'Error occure while getting locator id for locator:-'
                                    || lv_locator
                                    || ' for RA#'
                                    || get_rma_num (ln_rma_id)
                                    || 'and LINE_ID-'
                                    || items_rec.line_id
                                    || 'Collection Id :'
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          NULL));
                    END;

                    IF ln_err_cnt = apps.fnd_api.g_true
                    THEN
                        lv_sql   :=
                               'SELECT COUNT('
                            || get_column ('SERIAL_NUM')
                            || ')'
                            || ' FROM apps.qa_results WHERE item_id = '
                            || items_rec.item_id
                            || ' AND organization_id = '
                            || items_rec.organization_id
                            || ' AND '
                            || get_column ('LINE_ID')
                            || ' = '
                            || items_rec.line_id
                            || ' AND rma_header_id = '
                            || ln_rma_id
                            || ' AND NVL (CHARACTER100, ''N'') IN (''N'', ''E'')';
                        debug_tbl (
                            p_rma_id   => p_rma_id,
                            p_desc     =>
                                'Step-30 proc: insert_into_rti serial_num cnt sql:',
                            p_comm     => lv_sql);

                        EXECUTE IMMEDIATE lv_sql
                            INTO ln_serial_cnt;

                        IF (apps.xxdo_iid_to_serial (items_rec.item_id, items_rec.organization_id) = 'Y' AND ln_serial_cnt <> items_rec.quantity)
                        THEN
                            lv_sql   :=
                                   'SELECT '
                                || get_column ('SERIAL_NUM')
                                || ' "serial" , '
                                || ' qr.organization_id ,'
                                || get_column ('SERIAL_STATUS')
                                || ' "status_code"'
                                || '  FROM apps.qa_results QR
                                               WHERE qr.rma_header_id = '
                                || ln_rma_id
                                || ' AND '
                                || get_column ('LINE_ID')
                                || ' = '
                                || items_rec.line_id
                                || ' AND qr.item_id = '
                                || items_rec.item_id
                                || ' AND NVL(QR.CHARACTER100,''N'') <> ''Y'' ';
                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     =>
                                    'Step-31 proc: insert_into_rti serial sql',
                                p_comm     => lv_sql);

                            OPEN j FOR lv_sql;

                            LOOP
                                FETCH j INTO serial_rec;

                                EXIT WHEN j%NOTFOUND;

                                IF (serial_rec.serial IS NULL)
                                THEN
                                    serial   := 'FALSE';
                                END IF;
                            END LOOP;

                            CLOSE j;

                            IF NVL (serial, 'N') = 'FALSE'
                            THEN
                                print_line (
                                    'L',
                                       'RA#'
                                    || get_rma_num (ln_rma_id)
                                    || ' SKU#'
                                    || ' - '
                                    || apps.iid_to_sku (items_rec.item_id)
                                    || ' is Serial enabled.'
                                    || '   Please enter serial numbers for this item.'
                                    || 'Collection Id :'
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          items_rec.item_id));
                                debug_tbl (
                                    p_rma_id   => ln_rma_id,
                                    p_desc     =>
                                        'Step-32 proc: insert_into_rti :',
                                    p_comm     =>
                                           'RA#'
                                        || get_rma_num (ln_rma_id)
                                        || ' SKU#'
                                        || ' - '
                                        || apps.iid_to_sku (
                                               items_rec.item_id)
                                        || ' is Serial enabled.'
                                        || '   Please enter serial numbers for this item.'
                                        || 'Collection Id :'
                                        || get_collection_id (
                                               ln_rma_id,
                                               items_rec.line_id,
                                               items_rec.item_id));
                            ELSE
                                print_line (
                                    'L',
                                       'RA#'
                                    || get_rma_num (ln_rma_id)
                                    || ' SKU#'
                                    || ' - '
                                    || apps.iid_to_sku (items_rec.item_id)
                                    || ' is Serial enabled.'
                                    || '   Serial Item can not have quantity of more than 1.'
                                    || ' - Collection Id - '
                                    || get_collection_id (ln_rma_id,
                                                          items_rec.line_id,
                                                          items_rec.item_id));
                                debug_tbl (
                                    p_rma_id   => ln_rma_id,
                                    p_desc     =>
                                        'Step-33 proc: insert_into_rti :',
                                    p_comm     =>
                                           'RA#'
                                        || get_rma_num (ln_rma_id)
                                        || ' SKU#'
                                        || ' - '
                                        || apps.iid_to_sku (
                                               items_rec.item_id)
                                        || ' is Serial enabled.'
                                        || '   Serial Item can not have quantity of more than 1.'
                                        || ' - Collection Id - '
                                        || get_collection_id (
                                               ln_rma_id,
                                               items_rec.line_id,
                                               items_rec.item_id));
                            END IF;

                            gn_failed_validations   :=
                                gn_failed_validations + 1;
                        ELSE
                            INSERT INTO apps.rcv_headers_interface (
                                            header_interface_id,
                                            GROUP_ID,
                                            processing_status_code,
                                            receipt_source_code,
                                            transaction_type,
                                            last_update_date,
                                            last_updated_by,
                                            creation_date,
                                            last_update_login,
                                            customer_id,
                                            expected_receipt_date,
                                            validation_flag)
                                SELECT apps.rcv_headers_interface_s.NEXTVAL, gn_group_id, 'PENDING' -- processing_status_code
                                                                                                   ,
                                       'CUSTOMER'       -- receipt_source_code
                                                 , 'NEW'   -- transaction_type
                                                        , SYSDATE -- Last_update_date
                                                                 ,
                                       gn_user_id           -- last_updated_by
                                                 , SYSDATE    -- creation_date
                                                          , -1 -- last_update_login
                                                              ,
                                       order_info.customer_id   -- customer_id
                                                             , SYSDATE -- expected_receipt_date
                                                                      , 'Y' -- validation_flag
                                  FROM DUAL;

                            INSERT INTO apps.rcv_transactions_interface (
                                            interface_transaction_id,
                                            GROUP_ID,
                                            header_interface_id,
                                            last_update_date,
                                            last_updated_by,
                                            creation_date,
                                            created_by,
                                            transaction_type,
                                            transaction_date,
                                            processing_status_code,
                                            processing_mode_code,
                                            transaction_status_code,
                                            quantity,
                                            unit_of_measure,
                                            interface_source_code,
                                            item_id,
                                            uom_code,
                                            employee_id,
                                            auto_transact_code,
                                            primary_quantity,
                                            receipt_source_code,
                                            to_organization_id,
                                            source_document_code,
                                            destination_type_code,
                                            locator_id,
                                            --  DELIVER_TO_LOCATION_ID,
                                            subinventory,
                                            expected_receipt_date,
                                            oe_order_header_id,
                                            oe_order_line_id,
                                            customer_id,
                                            customer_site_id,
                                            validation_flag)
                                 VALUES (apps.rcv_transactions_interface_s.NEXTVAL, -- interface_transaction_id
                                                                                    gn_group_id, -- group_id
                                                                                                 apps.rcv_headers_interface_s.CURRVAL, -- header_interface_id
                                                                                                                                       SYSDATE, -- last_update_date
                                                                                                                                                gn_user_id, -- last_updated_by
                                                                                                                                                            SYSDATE, -- creation_date
                                                                                                                                                                     gn_user_id, -- created_by
                                                                                                                                                                                 'RECEIVE', -- transaction_type
                                                                                                                                                                                            SYSDATE, -- transaction_date
                                                                                                                                                                                                     'PENDING', -- processing_status_code
                                                                                                                                                                                                                'BATCH', -- processing_mode_code
                                                                                                                                                                                                                         'PENDING', -- transaction_mode_code
                                                                                                                                                                                                                                    items_rec.quantity, -- quantity
                                                                                                                                                                                                                                                        lv_order_qty_uom, -- unit_of_measure
                                                                                                                                                                                                                                                                          'RCV', -- interface_source_code
                                                                                                                                                                                                                                                                                 items_rec.item_id, -- item_id
                                                                                                                                                                                                                                                                                                    lv_uom_code, -- uom_code
                                                                                                                                                                                                                                                                                                                 gn_user_id, -- employee_id
                                                                                                                                                                                                                                                                                                                             'DELIVER', -- auto_transact_code
                                                                                                                                                                                                                                                                                                                                        items_rec.quantity, -- primary_quantity
                                                                                                                                                                                                                                                                                                                                                            'CUSTOMER', -- receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                        items_rec.organization_id, -- to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                   'RMA', -- source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                          'INVENTORY', -- destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                       ln_locator_id, --43401--deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                      lv_subinventory, -- subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                       SYSDATE, -- expected_receipt_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                ln_rma_id, -- oe_order_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                           items_rec.line_id, -- oe_order_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              order_info.customer_id
                                         ,                      -- customer_id
                                           order_info.cust_acct_site_id, -- customer_site_id
                                                                         'Y' --validation_flag
                                                                            );

                            /*========================================================================================
                              *********** VALIDATION SERIAL NUMBER FOR SKU AND INSERT INTO SERIAL INTERFACE **********
                              ========================================================================================*/
                            insert_serial_num (
                                p_rma_id    => ln_rma_id,
                                p_line_id   => items_rec.line_id,
                                p_item_id   => items_rec.item_id --   ,P_STATUS   => x_ret_sts
                                                                );
                            lv_sql                          :=
                                   'UPDATE APPS.QA_RESULTS QA SET CHARACTER100 = ''P'''
                                || ' WHERE line_id  = '
                                || items_rec.line_id
                                || ' AND request_id = '
                                || gn_group_id;

                            debug_tbl (
                                p_rma_id   => p_rma_id,
                                p_desc     =>
                                    'Step-34 proc: insert_into_rti Update sql',
                                p_comm     => lv_sql);

                            EXECUTE IMMEDIATE lv_sql;

                            s_rep (s_rep_idx).rma_num       := ln_rma_num;
                            s_rep (s_rep_idx).sku           :=
                                apps.iid_to_sku (items_rec.item_id);
                            s_rep (s_rep_idx).rma_hdr_id    := ln_rma_id;
                            s_rep (s_rep_idx).rma_line_id   :=
                                items_rec.line_id;
                            s_rep (s_rep_idx).qty           :=
                                items_rec.quantity;
                            s_rep (s_rep_idx).subinv        :=
                                lv_subinventory;
                            s_rep (s_rep_idx).locator       := lv_locator;
                            s_rep (s_rep_idx).flag          := 'I';
                            s_rep (s_rep_idx).locator_id    := ln_locator_id;
                            s_rep (s_rep_idx).uom_code      := lv_uom_code;
                            s_rep_idx                       := s_rep_idx + 1;
                            p_rec_cnt                       := 1;
                        END IF;
                    END IF;
                END LOOP;

                CLOSE i;
            END IF;
        END LOOP;

        CLOSE c;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                'Error occured in insert into rti package -' || SQLERRM);
            debug_tbl (
                p_rma_id   => p_rma_id,
                p_desc     =>
                    'Step-35 proc: insert_into_rti main exception block',
                p_comm     => SQLERRM);
    END;

    PROCEDURE insert_serial_num (p_rma_id    IN NUMBER,
                                 p_line_id   IN VARCHAR2,
                                 p_item_id   IN NUMBER --              ,P_STATUS   OUT VARCHAR2
                                                      )
    IS
        ln_serial_cnt   NUMBER;
        sn_rec_tp       apps.xxdo_serialization.sn_rec;
        x_ret_stat      VARCHAR2 (30);
        x_error_text    VARCHAR2 (100);
        lv_sql          VARCHAR2 (2000);

        TYPE serial_record IS RECORD
        (
            serial             VARCHAR2 (50),
            organization_id    NUMBER,
            disp_code          VARCHAR2 (50)
        );

        serial_rec      serial_record;

        TYPE cur_typ IS REF CURSOR;

        c               cur_typ;
    BEGIN
        ln_serial_cnt   := 0;

        BEGIN
            lv_sql   :=
                   'SELECT COUNT('
                || get_column ('SERIAL_NUM')
                || ')'
                || ' FROM apps.qa_results qa1 '
                || ' where qa1.rma_header_id  = '
                || p_rma_id
                || ' AND '
                || get_column ('LINE_ID')
                || ' = '
                || p_line_id
                || ' '
                || ' AND qa1.item_id          =  '
                || p_item_id
                || ' '
                || ' AND NVL(qa1.character100,''N'') <> ''Y'' ';

            debug_tbl (
                p_rma_id   => p_rma_id,
                p_desc     => 'Step-36 proc: insert_serial_num serial cnt sql',
                p_comm     => lv_sql);

            EXECUTE IMMEDIATE lv_sql
                INTO ln_serial_cnt;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_serial_cnt   := 0;
        END;

        IF ln_serial_cnt <> 0
        THEN
            lv_sql   :=
                   'SELECT '
                || get_column ('SERIAL_NUM')
                || ' "serial" ,'
                || ' qr.organization_id , '
                || get_column ('DISP_CODE')
                || ' "disp_code" '
                || ' FROM apps.qa_results qr '
                || ' WHERE QR.RMA_HEADER_ID  = '
                || p_rma_id
                || ' AND '
                || get_column ('LINE_ID')
                || ' = '
                || p_line_id
                || ' AND qr.item_id  ='
                || p_item_id
                || ' AND '
                || get_column ('SERIAL_NUM')
                || ' IS NOT NULL '
                || ' AND NVL(qr.character100,''N'') <> ''Y'' ';
            debug_tbl (
                p_rma_id   => p_rma_id,
                p_desc     =>
                    'Step-37 proc: insert_serial_num serial cursor sql',
                p_comm     => lv_sql);

            OPEN c FOR lv_sql;                  --FOR SERIAL_REC IN SERIAL_CUR

            LOOP
                FETCH c INTO serial_rec;

                EXIT WHEN c%NOTFOUND;
                sn_rec_tp.serial_number           := TO_CHAR (serial_rec.serial);
                sn_rec_tp.lpn_id                  := NULL;
                sn_rec_tp.inventory_item_id       := TO_NUMBER (p_item_id);
                sn_rec_tp.organization_id         :=
                    TO_NUMBER (serial_rec.organization_id);
                --SN_REC_TP.STATUS_ID             := 1;
                sn_rec_tp.source_code             := 'RMA_RETURN';
                sn_rec_tp.source_code_reference   := TO_CHAR (p_line_id);

                BEGIN
                    SELECT TO_NUMBER (NVL (tag, 9))
                      INTO sn_rec_tp.status_id
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'XXDO_SERIAL_RETURNS'
                           AND enabled_flag = 'Y'
                           AND language = USERENV ('LANG')
                           AND lookup_code = serial_rec.disp_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        sn_rec_tp.status_id   := 9;
                END;

                apps.xxdo_serialization.update_serial_temp (sn_rec_tp, 0, x_ret_stat
                                                            , x_error_text);

                IF x_ret_stat <> 'S'
                THEN
                    print_line ('L', ' ');
                    print_line (
                        'L',
                        'Error occured while insert the Serial number For ');
                    print_line (
                        'L',
                           ' Serial Number: '
                        || sn_rec_tp.serial_number
                        || ' SKU  :'
                        || apps.iid_to_sku (sn_rec_tp.inventory_item_id));
                    print_line (
                        'L',
                           'Line Id : '
                        || sn_rec_tp.source_code_reference
                        || ' Error Message: '
                        || x_error_text);

                    print_line ('O', ' ');
                    print_line (
                        'O',
                        'Error occured while insert the Serial number For ');
                    print_line (
                        'O',
                           ' Serial Number: '
                        || sn_rec_tp.serial_number
                        || ' SKU  :'
                        || apps.iid_to_sku (sn_rec_tp.inventory_item_id));
                    print_line (
                        'O',
                           'Line Id : '
                        || sn_rec_tp.source_code_reference
                        || ' Error Message: '
                        || x_error_text);

                    debug_tbl (
                        p_rma_id   => p_rma_id,
                        p_desc     =>
                            'Step-38 proc: insert_serial_num serial cursor sql',
                        p_comm     =>
                               'Error occured while insert the Serial number'
                            || 'Serial Number:'
                            || sn_rec_tp.serial_number
                            || ' SKU :'
                            || apps.iid_to_sku (sn_rec_tp.inventory_item_id));
                END IF;
            -- P_STATUS:=X_RET_STAT;
            END LOOP;

            COMMIT;

            CLOSE c;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            CLOSE c;

            print_line (
                'L',
                   'Exception occured while inserting into serial numbers interface table-'
                || SQLERRM);
            debug_tbl (
                p_rma_id   => p_rma_id,
                p_desc     =>
                    'Step-39 proc: insert_serial_num serial cursor sql',
                p_comm     =>
                       'Exception occured while inserting into serial numbers interface table-'
                    || SQLERRM);
    END;

    PROCEDURE submit_rtp
    IS
        ln_request_id      NUMBER;
        ln_child_request   BOOLEAN;
        lv_phasecode       VARCHAR2 (200);
        lv_statuscode      VARCHAR2 (200);
        lv_devphase        VARCHAR2 (200);
        lv_devstatus       VARCHAR2 (200);
        lv_returnmsg       VARCHAR2 (200);
    BEGIN
        apps.fnd_global.apps_initialize (gn_user_id,
                                         gn_resp_id,
                                         gn_resp_appl_id);
        ln_request_id   :=
            apps.fnd_request.submit_request ('PO', 'RVCTP', NULL,
                                             SYSDATE, FALSE, 'BATCH',
                                             gn_group_id);
        COMMIT;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '*** RECEIVING TRANSACTION PROCESSOR REQUEST ID ***'
            || ln_request_id);

        IF ln_request_id <= 0
        THEN
            --PV_RETCODE := 1;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*** RECEIVING TRANSACTION PROCESSOR RUNNING EXCEPTION ***');
            gn_failed_validations   := gn_failed_validations + 1;
        ELSIF ln_request_id > 0
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*** RECEIVING TRANSACTION PROCESSOR REQUEST SUBMIT SUCCESSFUL ***');

            LOOP
                ln_child_request   :=
                    apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                          8, -- WAIT 10 SECONDS BETWEEN DB CHECKS
                                                          0,
                                                          lv_phasecode,
                                                          lv_statuscode,
                                                          lv_devphase,
                                                          lv_devstatus,
                                                          lv_returnmsg);
                EXIT WHEN UPPER (lv_phasecode) = 'COMPLETED';
            -- OR UPPER (LV_STATUSCODE) IN
            --                             ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Error occured in submit_rtp procedure error code-'
                || SQLERRM);
            debug_tbl (
                p_rma_id   => NULL,
                p_desc     => 'Stpe-40 proc: submit_rtp',
                p_comm     =>
                       'Error occured in submit_rtp procedure error code-'
                    || SQLERRM);
    END;

    PROCEDURE error_rec_rcv_interface
    IS
        CURSOR err_rec_cur IS
            SELECT TO_CHAR (ooh.order_number) order_num, apps.iid_to_sku (rti.item_id) sku, TO_CHAR (ool.line_number) line_number,
                   TO_CHAR (rti.quantity) qty, poe.column_name, error_message,
                   table_name     -- ,TO_CHAR(MSI.FM_SERIAL_NUMBER) SERIAL_NUM
                             , rhi.header_interface_id, rti.interface_transaction_id,
                   rti.oe_order_line_id line_id, rti.processing_status_code status
              FROM apps.rcv_transactions_interface rti, apps.rcv_headers_interface rhi, apps.po_interface_errors poe,
                   apps.mtl_serial_numbers_interface msi, apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     rhi.GROUP_ID = gn_group_id
                   AND rhi.header_interface_id = rti.header_interface_id
                   AND rti.interface_transaction_id = poe.interface_line_id
                   AND rti.interface_transaction_id =
                       msi.product_transaction_id(+)
                   AND rti.oe_order_header_id = ooh.header_id
                   AND ool.header_id = ooh.header_id
                   AND ool.line_id = rti.oe_order_line_id;

        ln_err_cnt   NUMBER := 0;
        lv_sql       VARCHAR2 (1000);
    BEGIN
        print_line ('L', '        ');
        print_line (
            'L',
            '==============================================================================================');
        print_line (
            'L',
            '*****************************INTERFACE ERROR REPORT******************************************');
        print_line (
            'L',
            '==============================================================================================');
        print_line ('L', '        ');
        print_line (
            'L',
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 80, '-')
            || '|');
        print_line (
            'L',
               '|'
            || RPAD ('ORDER NUMBER', 15, ' ')
            || '|'
            || RPAD ('SKU', 15, ' ')
            || '|'
            || RPAD ('QTY', 15, ' ')
            || '|'
            || RPAD ('LINE NUMBER', 15, ' ')
            || '|'
            --   || RPAD ('SERIAL NUMBER', 20, ' ')
            --   || '|'
            || RPAD ('COLUMN NAME', 30, ' ')
            || '|'
            || RPAD ('TABLE NAME', 80, ' ')
            || '|'
            || RPAD ('ERROR MESSAGE', 50, ' ')
            || '|');
        print_line (
            'L',
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 80, '-')
            || '|');

        FOR i IN err_rec_cur
        LOOP
            IF i.status = 'ERROR'
            THEN
                IF gn_organization_id = 108
                THEN
                    lv_sql   :=
                           'UPDATE APPS.QA_RESULTS QA SET LINE_ID = NULL, CHARACTER12 = NULL, REQUEST_ID = NULL, CHARACTER100 = ''E'''
                        || ' WHERE REQUEST_ID = '
                        || gn_group_id
                        || ' AND line_id = '
                        || i.line_id;
                ELSE
                    lv_sql   :=
                           'UPDATE APPS.QA_RESULTS QA SET LINE_ID = NULL, CHARACTER11 = NULL, REQUEST_ID = NULL, CHARACTER100 = ''E'''
                        || ' WHERE REQUEST_ID = '
                        || gn_group_id
                        || ' AND line_id = '
                        || i.line_id;
                END IF;

                EXECUTE IMMEDIATE lv_sql;
            END IF;



            print_line (
                'L',
                   '|'
                || RPAD (NVL (NVL (i.order_num, ' '), ' '), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.sku, ' '), ' '), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.qty, ' '), ' '), 15, ' ')
                || '|'
                || RPAD (NVL (NVL (i.line_number, ' '), ' '), 15, ' ')
                || '|'
                -- ||RPAD (NVL (NVL(I.SERIAL_NUM,' '), ' '),
                --           20,
                --           ' '
                --          )
                --    || '|'
                || RPAD (NVL (NVL (i.column_name, ' '), ' '), 30, ' ')
                || '|'
                || RPAD (NVL (i.table_name, ' '), 30, ' ')
                || '|'
                || RPAD (NVL (NVL (i.error_message, ' '), ' '), 80, ' ')
                || '|');
            print_line (
                'L',
                   '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                || RPAD ('-', 15, '-')
                || '|'
                --     || RPAD ('-', 20, '-')
                --     || '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 80, '-')
                || '|');
            ln_err_cnt   := ln_err_cnt + 1;
            print_line ('O', ' ');
            print_line ('O', ' ');
            print_line ('O', ' ');

            DELETE FROM
                apps.po_interface_errors pie
                  WHERE pie.interface_transaction_id =
                        i.interface_transaction_id;


            DELETE FROM
                apps.rcv_transactions_interface rti
                  WHERE rti.interface_transaction_id =
                        i.interface_transaction_id;
        END LOOP;



        IF ln_err_cnt > 0
        THEN
            print_line ('O', '        ');
            print_line (
                'O',
                '===================================================================================================================================================');
            print_line (
                'O',
                '*****************************ERROR OCCURED WHILE CREATING RECEIPT PLEASE CHECK LOG FILE FOR ERROR AND CONTACT TO IT DEPARTMENT ***************');
            print_line (
                'O',
                '===================================================================================================================================================');
            print_line ('O', '        ');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L',
                        'Exception occured in error report:-' || SQLERRM);
            debug_tbl (
                p_rma_id   => NULL,
                p_desc     => 'Step-41 proc: error_rec_rcv_interface  ',
                p_comm     => SQLERRM);
    END;

    PROCEDURE success_report
    IS
        ln_tbl_inx   NUMBER;
        ln_err_cnt   NUMBER;
        lv_rec_num   VARCHAR2 (100);
        lv_sql       VARCHAR2 (1000);
    BEGIN
        /*==============================================================================================================================================
                ******************************* SUCCESS RECORDS REPORT*****************************************************************
          =============================================================================================================================================*/
        print_line ('O', ' ');
        print_line ('O', ' ');
        print_line (
            'O',
            '===================================================================================');
        print_line (
            'O',
            '***********************RMA RECEIVING SUMMARY REPORT*************************');
        print_line (
            'O',
            '===================================================================================');
        print_line (
            'O',
            '===================================================================================');
        print_line (
            'O',
               '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 22, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 5, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|' --                                               || RPAD ('-', 30, '-')
                  --                                               || '|'
                  );
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               '|'
            || RPAD ('RMA NUMBER', 20, ' ')
            || '|'
            || RPAD ('LINE NUMBER', 12, ' ')
            || '|'
            || RPAD ('SKU', 25, ' ')
            || '|'
            || RPAD ('QUANTITY', 5, ' ')
            || '|'
            || RPAD ('SUBINVENTORY', 15, ' ')
            || '|'
            || RPAD ('LOCATOR', 15, ' ')
            || '|'
            || RPAD ('RECEIPT NUMBER', 20, ' ')
            || '|' --                                               || RPAD ('SERIAL NUMBER', 30, ' ')
                  --                                               || '|'
                  );
        print_line (
            'O',
               '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 5, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|' --                                               || RPAD ('-', 30, '-')
                  --                                               || '|'
                  );
        --FOR K IN S_TBL.FIRST..S_TBL.LAST
        ln_tbl_inx   := s_rep.FIRST;

        WHILE (ln_tbl_inx IS NOT NULL)
        LOOP
            ln_err_cnt   := 0;
            lv_rec_num   := NULL;

            --APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'SUCCESS STEP:-1');
            BEGIN
                SELECT COUNT (1)
                  INTO ln_err_cnt
                  FROM apps.rcv_transactions_interface rti, apps.rcv_headers_interface rhi, apps.po_interface_errors poe
                 WHERE     rhi.GROUP_ID = gn_group_id
                       AND rhi.header_interface_id = rti.header_interface_id
                       AND rti.interface_transaction_id =
                           poe.interface_line_id
                       AND rti.oe_order_header_id =
                           s_rep (ln_tbl_inx).rma_hdr_id
                       AND rti.oe_order_line_id =
                           s_rep (ln_tbl_inx).rma_line_id
                       AND rti.item_id =
                           apps.sku_to_iid (s_rep (ln_tbl_inx).sku)
                       AND rti.processing_status_code = 'ERROR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_err_cnt   := 1;
            END;

            --FETCHING RECEIPT NUMBER FOR PROCESSED RECORD
            BEGIN
                SELECT rsh.receipt_num
                  INTO lv_rec_num
                  FROM apps.rcv_transactions rt, apps.rcv_shipment_headers rsh
                 WHERE     rt.oe_order_header_id =
                           s_rep (ln_tbl_inx).rma_hdr_id
                       AND rt.oe_order_line_id =
                           s_rep (ln_tbl_inx).rma_line_id
                       AND rt.shipment_header_id = rsh.shipment_header_id
                       AND rt.transaction_type = 'DELIVER';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_rec_num   := NULL;
            END;

            IF ln_err_cnt = 0
            THEN
                lv_sql                    :=
                       'UPDATE APPS.QA_RESULTS QA SET CHARACTER100 = ''R'''
                    || ' WHERE REQUEST_ID = '
                    || gn_group_id;

                debug_tbl (
                    p_rma_id   => NULL,
                    p_desc     =>
                        'Step-50 proc: RTP IS SUCCESSFUL FOR ALL RECORDS',
                    p_comm     => lv_sql);

                EXECUTE IMMEDIATE lv_sql;



                print_line (
                    'O',
                       '|'
                    || RPAD (
                           NVL (
                               NVL (TO_CHAR (s_rep (ln_tbl_inx).rma_num),
                                    ' '),
                               ' '),
                           20,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_rma_line_num (
                                           s_rep (ln_tbl_inx).rma_line_id)),
                                   ' '),
                               ' '),
                           12,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (NVL (TO_CHAR (s_rep (ln_tbl_inx).sku), ' '),
                                ' '),
                           25,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (NVL (TO_CHAR (s_rep (ln_tbl_inx).qty), ' '),
                                ' '),
                           5,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (TO_CHAR (s_rep (ln_tbl_inx).subinv), ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (TO_CHAR (s_rep (ln_tbl_inx).locator),
                                    ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (NVL (NVL (lv_rec_num, ' '), ' '), 20, ' ')
                    || '|');
                print_line (
                    'O',
                       '|'
                    || RPAD ('-', 20, '-')
                    || '|'
                    || RPAD ('-', 12, '-')
                    || '|'
                    || RPAD ('-', 25, '-')
                    || '|'
                    || RPAD ('-', 5, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 20, '-')
                    || '|');
                s_rep (ln_tbl_inx).flag   := 'S';
            END IF;

            ln_tbl_inx   := s_rep.NEXT (ln_tbl_inx);
        END LOOP;

        print_line ('O', ' ');
        print_line ('O', ' ');
        print_line ('O', ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'EXCEPTION OCCURED WHILE DISPLYING SUCCESS RECORDS   '
                || SQLERRM);
    END;

    FUNCTION get_locator (p_value IN VARCHAR2, p_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_org_code   VARCHAR2 (200);
        ln_tbl_cnt    NUMBER;
        lv_locator    VARCHAR2 (200);
        ln_ctr        NUMBER;

        TYPE locator_info IS RECORD
        (
            org_code        VARCHAR2 (200),
            locator_code    VARCHAR2 (200)
        );

        TYPE locator_tbl_type IS TABLE OF locator_info
            INDEX BY BINARY_INTEGER;

        locator_tbl   locator_tbl_type;

        CURSOR c IS
                SELECT REGEXP_SUBSTR (p_value, '[^,]+', 1,
                                      LEVEL) org_loc
                  FROM DUAL
            CONNECT BY REGEXP_SUBSTR (p_value, '[^,]+', 1,
                                      LEVEL)
                           IS NOT NULL;
    BEGIN
        FOR i IN c
        LOOP
            ln_ctr   := locator_tbl.COUNT + 1;
            locator_tbl (ln_ctr).org_code   :=
                SUBSTR (i.org_loc, 1, INSTR (i.org_loc, '-', 1) - 1);
            locator_tbl (ln_ctr).locator_code   :=
                SUBSTR (i.org_loc, INSTR (i.org_loc, '-', 1) + 1);
        END LOOP;

        BEGIN
            SELECT ood.organization_code
              INTO ln_org_code
              FROM apps.org_organization_definitions ood
             WHERE ood.organization_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_code   := NULL;
        END;

        IF ln_org_code IS NOT NULL
        THEN
            ln_tbl_cnt   := locator_tbl.FIRST;

            WHILE (ln_tbl_cnt IS NOT NULL)
            LOOP
                IF TRIM (locator_tbl (ln_tbl_cnt).org_code) =
                   TRIM (ln_org_code)
                THEN
                    lv_locator   := locator_tbl (ln_tbl_cnt).locator_code;
                END IF;

                ln_tbl_cnt   := locator_tbl.NEXT (ln_tbl_cnt);
            END LOOP;
        END IF;

        RETURN lv_locator;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_locator;

    PROCEDURE subinve_transfer
    IS
        ln_tbl_inx      NUMBER;
        ln_err_cnt      VARCHAR2 (10) := apps.fnd_api.g_true;
        lv_err_msg      VARCHAR2 (4000);
        lv_locator      VARCHAR2 (50);
        ln_locator_id   NUMBER;
        lv_sql          VARCHAR2 (2000);

        TYPE subinv_record IS RECORD
        (
            rma_hdr_id         NUMBER,
            organization_id    NUMBER,
            quantity           NUMBER,
            line_id            NUMBER,
            item_id            NUMBER,
            disp_code          VARCHAR2 (50),
            serial_num         VARCHAR2 (50)
        );

        subinv_rec      subinv_record;

        TYPE cur_typ IS REF CURSOR;

        c               cur_typ;
    BEGIN
        ln_tbl_inx   := s_rep.FIRST;

        WHILE (ln_tbl_inx IS NOT NULL)
        LOOP
            IF s_rep (ln_tbl_inx).flag = 'S'
            THEN
                lv_sql   :=
                       'SELECT qr.rma_header_id,
                       qr.organization_id,
                       qr.quantity,
                       qr.line_id,
                       qr.item_id , '
                    || get_column ('DISP_CODE')
                    || ', '
                    || get_column ('SERIAL_NUM')
                    || ' FROM apps.qa_results qr
                      WHERE qr.rma_header_id =  '
                    || s_rep (ln_tbl_inx).rma_hdr_id
                    || ' AND qr.line_id '
                    || '= '
                    || s_rep (ln_tbl_inx).rma_line_id
                    || ' AND  qr.item_id = '
                    || apps.sku_to_iid (s_rep (ln_tbl_inx).sku);
                --  FOR i IN sub_inv_cur (s_rep (ln_tbl_inx).rma_hdr_id,
                --                        s_rep (ln_tbl_inx).rma_line_id,
                --                        apps.sku_to_iid (s_rep (ln_tbl_inx).sku)
                --                       )
                debug_tbl (
                    p_rma_id   => s_rep (ln_tbl_inx).rma_hdr_id,
                    p_desc     => 'Step-42 proc: subinve transfer sql-',
                    p_comm     => lv_sql);

                OPEN c FOR lv_sql;

                LOOP
                    FETCH c INTO subinv_rec;

                    EXIT WHEN c%NOTFOUND;
                    debug_tbl (
                        p_rma_id   => s_rep (ln_tbl_inx).rma_hdr_id,
                        p_desc     =>
                            'Step-42a proc: subinve transfer sql-records found for processing sub-inventory transfers',
                        p_comm     => lv_sql);

                    /*==============================================================================================
                       ------------------FETCHING LOCATOR CODE OR DISPOSITION CODE------------------
                      =============================================================================================*/

                    BEGIN
                        SELECT NVL (TRIM (get_locator (flv.description, subinv_rec.organization_id)), 'RTN....1')
                          INTO lv_locator
                          FROM apps.fnd_lookup_values flv
                         WHERE     flv.lookup_type = 'XXDO_SERIAL_RETURNS'
                               AND flv.language = USERENV ('LANG')
                               AND flv.lookup_code = subinv_rec.disp_code;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt   := apps.fnd_api.g_false;
                            print_line (
                                'L',
                                   'Error occured while getting locator code from lookup for line_id-'
                                || subinv_rec.line_id
                                || ' AND RA#-'
                                || get_rma_num (subinv_rec.rma_hdr_id)
                                || ' Collection Id :'
                                || get_collection_id (subinv_rec.rma_hdr_id,
                                                      subinv_rec.line_id,
                                                      NULL));
                            debug_tbl (
                                p_rma_id   => subinv_rec.rma_hdr_id,
                                p_desc     =>
                                    'Step-43 proc: subinve transafer get locator-',
                                p_comm     =>
                                       'Error occured while getting locator code from lookup for line_id-'
                                    || subinv_rec.line_id
                                    || ' AND RA#-'
                                    || get_rma_num (subinv_rec.rma_hdr_id)
                                    || ' Collection Id :'
                                    || get_collection_id (
                                           subinv_rec.rma_hdr_id,
                                           subinv_rec.line_id,
                                           NULL));
                    END;

                    /* *********************************************************************************
                        ----------------------FETCHING INVENTORY LOCATOR ID-----------------------
                     ***********************************************************************************/

                    BEGIN
                        SELECT mil.inventory_location_id
                          INTO ln_locator_id
                          FROM apps.mtl_item_locations mil
                         WHERE        mil.segment1
                                   || '.'
                                   || mil.segment2
                                   || '.'
                                   || mil.segment3
                                   || '.'
                                   || mil.segment4
                                   || '.'
                                   || mil.segment5 =
                                   lv_locator
                               AND mil.organization_id =
                                   subinv_rec.organization_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_cnt      := apps.fnd_api.g_false;
                            ln_locator_id   := NULL;
                            print_line (
                                'L',
                                   'Error occure while getting locator id for locator:-'
                                || lv_locator
                                || 'AND LINE_ID ID-'
                                || subinv_rec.line_id
                                || '  AND RA#-'
                                || get_rma_num (subinv_rec.rma_hdr_id)
                                || ' Collection Id:'
                                || get_collection_id (subinv_rec.rma_hdr_id,
                                                      subinv_rec.line_id,
                                                      NULL)
                                || 'Error Message-'
                                || SQLERRM);
                            debug_tbl (
                                p_rma_id   => subinv_rec.rma_hdr_id,
                                p_desc     =>
                                    'Step-44 proc: subinve transfer locator id ',
                                p_comm     =>
                                       'Error occure while getting locator id for locator:-'
                                    || lv_locator
                                    || 'AND LINE_ID ID-'
                                    || subinv_rec.line_id
                                    || '  AND RA#-'
                                    || get_rma_num (subinv_rec.rma_hdr_id)
                                    || ' Collection Id:'
                                    || get_collection_id (
                                           subinv_rec.rma_hdr_id,
                                           subinv_rec.line_id,
                                           NULL)
                                    || 'Error Message-'
                                    || SQLERRM);
                    END;

                    IF     ln_err_cnt <> apps.fnd_api.g_false
                       AND NVL (s_rep (ln_tbl_inx).locator_id, 0) <>
                           NVL (ln_locator_id, 0)
                    THEN
                        INSERT INTO apps.mtl_transactions_interface (
                                        transaction_header_id,
                                        transaction_interface_id,
                                        transaction_mode,
                                        lock_flag,
                                        inventory_item_id,
                                        organization_id,
                                        subinventory_code,
                                        locator_id,
                                        transaction_quantity,
                                        transaction_uom,
                                        transaction_type_id,
                                        transaction_date,
                                        transaction_reference,
                                        transfer_subinventory,
                                        transfer_locator,
                                        process_flag,
                                        source_code,
                                        source_line_id,
                                        source_header_id,
                                        last_update_date,
                                        last_updated_by,
                                        creation_date,
                                        created_by)
                             --REASON_ID)
                             VALUES (gn_group_id,    -- transaction_header_id,
                                                  apps.mtl_material_transactions_s.NEXTVAL, -- transaction_interface_id,
                                                                                            3, -- transaction_mode,
                                                                                               2, -- lock_flag,
                                                                                                  subinv_rec.item_id, -- inventory_item_id,
                                                                                                                      subinv_rec.organization_id, -- v_frm_org,
                                                                                                                                                  s_rep (ln_tbl_inx).subinv, -- V_sub_inv_code,
                                                                                                                                                                             s_rep (ln_tbl_inx).locator_id, -- subinventory_code,
                                                                                                                                                                                                            subinv_rec.quantity, -- v_transaction_quantity,
                                                                                                                                                                                                                                 s_rep (ln_tbl_inx).uom_code, -- ransaction_uom,
                                                                                                                                                                                                                                                              2, -- transaction_type_id,
                                                                                                                                                                                                                                                                 SYSDATE, -- Transaction_date
                                                                                                                                                                                                                                                                          'QA MODULE RMA LOCATOR TRANSFER', s_rep (ln_tbl_inx).subinv, -- transfer_subinventory,
                                                                                                                                                                                                                                                                                                                                       ln_locator_id, -- transfer_locator,
                                                                                                                                                                                                                                                                                                                                                      1, -- process_flag,
                                                                                                                                                                                                                                                                                                                                                         'INTERFACE', -- source_code,
                                                                                                                                                                                                                                                                                                                                                                      s_rep (ln_tbl_inx).rma_hdr_id, -- source_line_id,
                                                                                                                                                                                                                                                                                                                                                                                                     s_rep (ln_tbl_inx).rma_line_id, -- source_header_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                     SYSDATE, -- last_update_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                              gn_user_id
                                     ,                     -- last_updated_by,
                                       SYSDATE,              -- creation_date,
                                                gn_user_id -- 7                                        --REASON_ID
                                                          );

                        BEGIN
                            SELECT apps.mtl_material_transactions_s.CURRVAL
                              INTO subinv_trx (subinv_trx_idx).trx_iface_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                subinv_trx (subinv_trx_idx).trx_iface_id   :=
                                    NULL;
                        END;

                        subinv_trx (subinv_trx_idx).item_id   :=
                            subinv_rec.item_id;
                        subinv_trx (subinv_trx_idx).organization_id   :=
                            subinv_rec.organization_id;
                        subinv_trx (subinv_trx_idx).subinv_code   :=
                            s_rep (ln_tbl_inx).subinv;
                        subinv_trx (subinv_trx_idx).from_loc_id   :=
                            s_rep (ln_tbl_inx).locator_id;
                        subinv_trx (subinv_trx_idx).trx_qty   :=
                            subinv_rec.quantity;
                        --S_REP (LN_TBL_INX).QTY;
                        subinv_trx (subinv_trx_idx).trx_uom   :=
                            s_rep (ln_tbl_inx).uom_code;
                        subinv_trx (subinv_trx_idx).trx_subinv   :=
                            s_rep (ln_tbl_inx).subinv;
                        subinv_trx (subinv_trx_idx).to_loc_id   :=
                            ln_locator_id;
                        subinv_trx (subinv_trx_idx).src_line_id   :=
                            s_rep (ln_tbl_inx).rma_line_id;
                        subinv_trx (subinv_trx_idx).src_hdr_id   :=
                            s_rep (ln_tbl_inx).rma_hdr_id;
                        subinv_trx (subinv_trx_idx).flag   := 'I';
                        subinv_trx (subinv_trx_idx).serial_num   :=
                            subinv_rec.serial_num;
                        subinv_trx_idx                     :=
                            subinv_trx_idx + 1;

                        gn_mti_count                       :=
                            gn_mti_count + 1;
                    END IF;
                END LOOP;

                CLOSE c;
            END IF;

            ln_tbl_inx   := s_rep.NEXT (ln_tbl_inx);
        END LOOP;

        debug_tbl (
            p_rma_id   => NULL,
            p_desc     =>
                   'Step-45 proc: subinve transfer sql-Inserted '
                || gn_mti_count
                || ' record(s) into apps.mtl_transactions_interface',
            p_comm     => NULL);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Error occured in subinventory transfer procedure error message -'
                || SQLERRM);

            CLOSE c;
    END;

    PROCEDURE subinve_report
    IS
        ln_cnt       NUMBER;
        ln_tbl_inx   NUMBER;
    BEGIN
        print_line (
            'O',
            '=======================================================================================');
        print_line (
            'O',
            '*************SUBINVENTORY TRANSFER SUCCESS REPORT ON DEFECT CODE********************');
        print_line (
            'O',
            '=======================================================================================');
        print_line (
            'O',
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 17, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|');
        print_line (
            'O',
               '|'
            || RPAD ('RMA NUMBER', 15, ' ')
            || '|'
            || RPAD ('LINE NUMBER', 12, ' ')
            || '|'
            || RPAD ('SKU', 25, ' ')
            || '|'
            || RPAD ('QUANTITY', 10, ' ')
            || '|'
            || RPAD ('ORGANIZATION', 15, ' ')
            || '|'
            || RPAD ('FROM SUBINVENTORY', 17, ' ')
            || '|'
            || RPAD ('FROM LOCATOR', 15, ' ')
            || '|'
            || RPAD ('TO SUBINVENTORY', 15, ' ')
            || '|'
            || RPAD ('TO LOCATOR', 15, ' ')
            || '|'
            || RPAD ('SERIAL NUMBER', 20, ' ')
            || '|');
        print_line (
            'O',
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 17, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|');
        ln_tbl_inx   := subinv_trx.FIRST;

        WHILE (ln_tbl_inx IS NOT NULL)
        LOOP
            ln_cnt       := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_cnt
                  FROM apps.mtl_transactions_interface mti
                 WHERE     mti.transaction_interface_id =
                           subinv_trx (ln_tbl_inx).trx_iface_id
                       AND mti.transaction_header_id = gn_group_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cnt   := 0;
            END;

            IF ln_cnt = 0
            THEN
                print_line (
                    'O',
                       '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_rma_num (
                                           subinv_trx (ln_tbl_inx).src_hdr_id)),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_rma_line_num (
                                           subinv_trx (ln_tbl_inx).src_line_id)),
                                   ' '),
                               ' '),
                           12,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       apps.iid_to_sku (
                                           subinv_trx (ln_tbl_inx).item_id)),
                                   ' '),
                               ' '),
                           25,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (subinv_trx (ln_tbl_inx).trx_qty),
                                   ' '),
                               ' '),
                           10,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_org_code (
                                           subinv_trx (ln_tbl_inx).organization_id)),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).subinv_code),
                                   ' '),
                               ' '),
                           17,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_loc (
                                           subinv_trx (ln_tbl_inx).from_loc_id,
                                           subinv_trx (ln_tbl_inx).organization_id)),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).subinv_code),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_loc (
                                           subinv_trx (ln_tbl_inx).to_loc_id,
                                           subinv_trx (ln_tbl_inx).organization_id)),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).serial_num),
                                   ' '),
                               ' '),
                           20,
                           ' ')
                    || '|');
                print_line (
                    'O',
                       '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 12, '-')
                    || '|'
                    || RPAD ('-', 25, '-')
                    || '|'
                    || RPAD ('-', 10, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 17, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 20, '-')
                    || '|');
            ELSE
                subinv_trx (ln_tbl_inx).flag   := 'E';
            END IF;

            ln_tbl_inx   := subinv_trx.NEXT (ln_tbl_inx);
        END LOOP;

        print_line ('O', ' ');
        print_line ('O', ' ');
        print_line ('O', ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Exception occured in subinventory transfer report procedure error message -'
                || SQLERRM);
    END;

    FUNCTION get_rma_num (pn_rma_hdr_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_rma_num   NUMBER;
    BEGIN
        SELECT order_number
          INTO ln_rma_num
          FROM apps.oe_order_headers_all ooh
         WHERE ooh.header_id = pn_rma_hdr_id;

        RETURN ln_rma_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_rma_num   := NULL;
            RETURN ln_rma_num;
    END;


    /** Added below function for CCR#CCR0004847, By Siva R**/
    FUNCTION get_rma_line_num (pn_rma_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_rma_line_num   NUMBER;
    BEGIN
        SELECT line_number
          INTO ln_rma_line_num
          FROM apps.oe_order_lines_all ool
         WHERE ool.line_id = pn_rma_line_id;

        RETURN ln_rma_line_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_rma_line_num   := NULL;
            RETURN ln_rma_line_num;
    END;


    FUNCTION get_loc (pn_loc_id IN NUMBER, pn_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_loc   VARCHAR2 (100);
    BEGIN
        SELECT mil.segment1 || '.' || segment2 || '.' || segment3 || '.' || segment4 || '.' || segment5
          INTO lv_loc
          FROM apps.mtl_item_locations mil
         WHERE     mil.inventory_location_id = pn_loc_id
               AND mil.organization_id = pn_org_id;

        RETURN lv_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_loc   := NULL;
            RETURN lv_loc;
    END;

    FUNCTION get_org_code (pn_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_org   VARCHAR2 (100);
    BEGIN
        SELECT organization_code
          INTO lv_org
          FROM apps.org_organization_definitions ood
         WHERE ood.organization_id = pn_org_id;

        RETURN lv_org;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_org   := NULL;
            RETURN lv_org;
    END;

    FUNCTION get_column (pv_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_character   VARCHAR2 (100);
    BEGIN
        IF gn_organization_id = 108
        THEN          /* PASS THE CHARACTERS USING BELOW LOGIC FOR US2 ORG **/
            IF pv_code = 'CUST_NAME'
            THEN
                lv_character   := 'CHARACTER2';
            ELSIF pv_code = 'CUST_NUM'
            THEN
                lv_character   := 'CHARACTER1';
            ELSIF pv_code = 'DISP_CODE'
            THEN
                lv_character   := 'CHARACTER7';
            ELSIF pv_code = 'LINE_ID'
            THEN
                lv_character   := 'CHARACTER12';
            ELSIF pv_code = 'SERIAL_NUM'
            THEN
                lv_character   := 'CHARACTER3';
            ELSIF pv_code = 'SERIAL_STATUS'
            THEN
                lv_character   := 'CHARACTER6';
            END IF;
        ELSE
              SELECT flv.meaning
                INTO lv_character
                FROM apps.fnd_lookup_values flv
               WHERE     flv.lookup_type = 'XXDO_QUALITY_PLAN_MAPPINGS'
                     AND flv.language = USERENV ('LANG')
                     AND NVL (flv.enabled_flag, 'N') = 'Y'
                     AND flv.lookup_code = pv_code
            GROUP BY flv.meaning;
        END IF;

        RETURN lv_character;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_character   := NULL;
            RETURN lv_character;
    END;


    PROCEDURE launch_int_mgr
    IS
        l_return_status   VARCHAR2 (10);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (2000);
        l_trans_count     NUMBER;
        ln_int_retcode    NUMBER;
        lv_sql            VARCHAR2 (2000);
    BEGIN
        IF gn_mti_count > 0
        THEN
            ln_int_retcode   :=
                apps.inv_txn_manager_pub.process_transactions (
                    p_api_version     => 1.0,
                    p_init_msg_list   => apps.fnd_api.g_true,
                    x_return_status   => l_return_status,
                    x_msg_count       => l_msg_count,
                    x_msg_data        => l_msg_data,
                    x_trans_count     => l_trans_count,
                    p_header_id       => gn_group_id);
            print_line (
                'L',
                   'Return status of inventory transaction interface manager is:-#'
                || ln_int_retcode);
        ELSE
            l_return_status   := 'S';
            print_line (
                'L',
                'NO ELIGIBLE RECORDS FOUND FOR SUB-INVENTORY TRANSFERS');
            print_line (
                'O',
                'NO ELIGIBLE RECORDS FOUND FOR SUB-INVENTORY TRANSFERS');
        END IF;

        IF l_return_status = 'E'
        THEN
            lv_sql   :=
                   'UPDATE APPS.QA_RESULTS QA SET CHARACTER100 = ''E'''
                || ' WHERE REQUEST_ID  = '
                || gn_group_id
                || ' AND CHARACTER100 NOT IN ( ''R'', ''Y'')';
        ELSE
            lv_sql   :=
                   'UPDATE APPS.QA_RESULTS QA SET CHARACTER100 = ''Y'''
                || ' WHERE REQUEST_ID  = '
                || gn_group_id
                || ' AND CHARACTER100 = ''R''';
        END IF;


        EXECUTE IMMEDIATE lv_sql;


        debug_tbl (
            p_rma_id   => NULL,
            p_desc     =>
                   'Step-46 proc: launch_int_mgr-Quality results table is marked with a flag of  : '
                || l_return_status
                || ' for request ID/Transaction Header ID : '
                || gn_group_id,
            p_comm     => lv_sql);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Error occured while submitting inventory transaction manager error msg -'
                || SQLERRM);
    END;                                                      --LAUNCH_INT_MGR

    PROCEDURE subinve_transfer_error_report
    IS
        lv_error_code   VARCHAR2 (50);
        lv_error_msg    VARCHAR2 (100);
        ln_tbl_inx      NUMBER;
    BEGIN
        print_line (
            'L',
            '=======================================================================================');
        print_line (
            'L',
            '*************SUBINVENTORY TRANSFER ERROR REPORT ON DEFECT CODE********************');
        print_line (
            'L',
            '=======================================================================================');
        print_line (
            'L',
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 5, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 100, '-')
            || '|');
        print_line (
            'L',
               '|'
            || RPAD ('RMA NUMBER', 15, ' ')
            || '|'
            || RPAD ('LINE NUMBER', 12, ' ')
            || '|'
            || RPAD ('SKU', 25, ' ')
            || '|'
            || RPAD ('QUANTITY', 5, ' ')
            || '|'
            || RPAD ('FROM SUBINVENTORY', 15, ' ')
            || '|'
            || RPAD ('FROM LOCATOR', 15, ' ')
            || '|'
            || RPAD ('TO SUBINVENTORY', 15, ' ')
            || '|'
            || RPAD ('TO LOCATOR', 15, ' ')
            || '|'
            || RPAD ('SERIAL NUMBER', 20, ' ')
            || '|'
            || RPAD ('ERROR CODE', 30, ' ')
            || '|'
            || RPAD ('ERROR EXPLANATION', 100, ' ')
            || '|');
        print_line (
            'L',
               '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 12, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 5, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 100, '-')
            || '|');
        ln_tbl_inx   := subinv_trx.FIRST;

        WHILE (ln_tbl_inx IS NOT NULL)
        LOOP
            IF subinv_trx (ln_tbl_inx).flag = 'E'
            THEN
                lv_error_code   := NULL;
                lv_error_msg    := NULL;

                BEGIN
                    SELECT SUBSTR (mti.ERROR_CODE, 1, 30), SUBSTR (mti.error_explanation, 1, 100)
                      INTO lv_error_code, lv_error_msg
                      FROM apps.mtl_transactions_interface mti
                     WHERE     mti.transaction_interface_id =
                               subinv_trx (ln_tbl_inx).trx_iface_id
                           AND mti.transaction_header_id = gn_group_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                print_line (
                    'L',
                       '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_rma_num (
                                           subinv_trx (ln_tbl_inx).src_hdr_id)),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       get_rma_line_num (
                                           subinv_trx (ln_tbl_inx).src_line_id)),
                                   ' '),
                               ' '),
                           12,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       apps.iid_to_sku (
                                           subinv_trx (ln_tbl_inx).item_id)),
                                   ' '),
                               ' '),
                           25,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).organization_id),
                                   ' '),
                               ' '),
                           5,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).subinv_code),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).from_loc_id),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (subinv_trx (ln_tbl_inx).trx_qty),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).to_loc_id),
                                   ' '),
                               ' '),
                           15,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               NVL (
                                   TO_CHAR (
                                       subinv_trx (ln_tbl_inx).serial_num),
                                   ' '),
                               ' '),
                           20,
                           ' ')
                    || '|'
                    || RPAD (NVL (NVL (TO_CHAR (lv_error_code), ' '), ' '),
                             30,
                             ' ')
                    || '|'
                    || RPAD (NVL (NVL (TO_CHAR (lv_error_msg), ' '), ' '),
                             100,
                             ' ')
                    || '|');
                print_line (
                    'L',
                       '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 12, '-')
                    || '|'
                    || RPAD ('-', 25, '-')
                    || '|'
                    || RPAD ('-', 5, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 15, '-')
                    || '|'
                    || RPAD ('-', 20, '-')
                    || '|'
                    || RPAD ('-', 30, '-')
                    || '|'
                    || RPAD ('-', 100, '-')
                    || '|');
            END IF;

            ln_tbl_inx   := subinv_trx.NEXT (ln_tbl_inx);
        END LOOP;

        print_line ('L', ' ');
        print_line ('L', ' ');
        print_line ('L', ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Exception occured in subinventory transfer error report procedure error message -'
                || SQLERRM);
    END;

    PROCEDURE debug_tbl (p_rma_id   IN NUMBER,
                         p_desc     IN VARCHAR2,
                         p_comm     IN VARCHAR2)
    IS
    BEGIN
        INSERT INTO apps.qa_debug (sno, request_id, rma_hdr_id,
                                   description, comments, creation_date,
                                   created_by)
             VALUES (apps.qa_debug_seq.NEXTVAL, gn_group_id, p_rma_id,
                     p_desc, p_comm, SYSDATE,
                     gn_user_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                'Error while insert into debug procedure- ' || SQLERRM);
            debug_tbl (p_rma_id   => NULL,
                       p_desc     => 'Step-45 proc: debug tble',
                       p_comm     => SQLERRM);
    END;

    PROCEDURE purge_debug_tbl
    IS
    BEGIN
        DELETE FROM apps.qa_debug
              WHERE TRUNC (creation_date) <= TRUNC (SYSDATE - 30);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L',
                        'exception in purge debug procedure- ' || SQLERRM);
            debug_tbl (p_rma_id   => NULL,
                       p_desc     => 'Step-46 proc: purge debug tble',
                       p_comm     => SQLERRM);
    END;
END;
/
