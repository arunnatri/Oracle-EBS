--
-- XXD_ONT_BULK_ORDER_FORM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_ORDER_FORM_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORDER_FORM_PKG
    * Design       : This package will be used in Bulk Order Transfer Form
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 21-Jan-2018  1.0        Arun Murthy             Initial Version
    -- 28-Nov-2018  1.1        Viswanathan Pandian     Heavily redesigned for CCR0007531
    ******************************************************************************************/
    gn_org_id              NUMBER := fnd_global.org_id;
    gn_user_id             NUMBER;
    gn_login_id            NUMBER;
    gn_application_id      NUMBER;
    gn_responsibility_id   NUMBER;
    gv_change_reason       VARCHAR2 (100) := 'BLK_FORM_TRANSFER';
    gv_change_comments     VARCHAR2 (1000) := 'Bulk Order Transfer by Form';

    PROCEDURE xxd_initialize_proc (pn_org_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER
                                   , pn_resp_appl_id NUMBER)
    AS
    BEGIN
        gn_user_id             := pn_user_id;
        gn_responsibility_id   := pn_resp_id;
        gn_application_id      := pn_resp_appl_id;
        gn_org_id              := pn_org_id;

        fnd_global.apps_initialize (user_id        => pn_user_id,
                                    resp_id        => pn_resp_id,
                                    resp_appl_id   => pn_resp_appl_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', pn_org_id);
        oe_msg_pub.initialize;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END xxd_initialize_proc;

    FUNCTION lock_order (p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_order IS
                SELECT ooha.header_id, oola.line_id
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola
                 WHERE     ooha.header_id = oola.header_id
                       AND oola.open_flag = 'Y'
                       AND ooha.header_id = p_header_id
            FOR UPDATE NOWAIT;

        lc_lock_status   VARCHAR2 (1) := 'N';
        l_order_rec      get_order%ROWTYPE;
    BEGIN
        BEGIN
            OPEN get_order;

            FETCH get_order INTO l_order_rec;

            CLOSE get_order;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_lock_status   := 'Y';
        END;

        RETURN lc_lock_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'Y';
    END lock_order;

    PROCEDURE proc_update_error (p_header_id IN oe_order_headers_all.header_id%TYPE DEFAULT NULL, p_error_msg VARCHAR2)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxd_ont_bulk_order_lines_gt
           SET error_message = p_error_msg, process_flag = 'E'
         WHERE     select_flag = 1
               AND requested_qty IS NOT NULL
               AND process_flag = 'N'
               AND ((p_header_id IS NOT NULL AND header_id = p_header_id) OR (p_header_id IS NULL AND 1 = 1));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END proc_update_error;

    PROCEDURE proc_reset_orders
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxd_ont_bulk_order_lines_gt xobl
           SET (select_flag, requested_qty, ordered_quantity,
                cancelled_quantity, consumed_qty, cum_transferred_qty)   =
                   (SELECT 2, NULL, ordered_quantity,
                           NVL (get_cum_transferred_qty (oola.header_id, oola.line_id, 'OTHER'), 0) cancelled_quantity, NVL (get_cum_transferred_qty (oola.header_id, oola.line_id, 'BLK_ADJ_PGM'), 0) consumed_qty, NVL (get_cum_transferred_qty (oola.header_id, oola.line_id, gv_change_reason), 0) cum_transferred_qty
                      FROM oe_order_lines_all oola
                     WHERE 1 = 1 AND oola.line_id = xobl.line_id)
         WHERE 1 = 1 AND select_flag = 1;

        DELETE FROM xxdo.xxd_ont_bulk_order_lines_gt
              WHERE 1 = 1 AND ordered_quantity = 0;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END proc_reset_orders;

    FUNCTION get_cum_transferred_qty (pn_header_id     NUMBER,
                                      pn_line_id       NUMBER,
                                      pv_reason_code   VARCHAR2)
        RETURN NUMBER
    IS
        ln_qty   NUMBER := 0;
    BEGIN
        IF pv_reason_code = gv_change_reason
        THEN
            SELECT SUM (NVL (latest_cancelled_quantity, 0))
              INTO ln_qty
              FROM oe_order_lines_history olh, oe_reasons oer
             WHERE     1 = 1
                   AND olh.header_id = pn_header_id
                   AND olh.line_id = pn_line_id
                   AND olh.hist_type_code = 'CANCELLATION'
                   AND olh.reason_id = oer.reason_id
                   AND oer.reason_code = gv_change_reason
                   AND olh.header_id = oer.header_id
                   AND oer.entity_code = 'LINE'
                   AND olh.line_id = oer.entity_id;
        ELSIF pv_reason_code = 'BLK_ADJ_PGM'
        THEN
            SELECT SUM (NVL (latest_cancelled_quantity, 0))
              INTO ln_qty
              FROM oe_order_lines_history olh, oe_reasons oer
             WHERE     1 = 1
                   AND olh.header_id = pn_header_id
                   AND olh.line_id = pn_line_id
                   AND olh.hist_type_code = 'CANCELLATION'
                   AND olh.reason_id = oer.reason_id
                   AND oer.reason_code = pv_reason_code
                   AND olh.header_id = oer.header_id
                   AND oer.entity_code = 'LINE'
                   AND olh.line_id = oer.entity_id;
        ELSE
            SELECT SUM (NVL (latest_cancelled_quantity, 0))
              INTO ln_qty
              FROM oe_order_lines_history olh, oe_reasons oer
             WHERE     1 = 1
                   AND olh.header_id = pn_header_id
                   AND olh.line_id = pn_line_id
                   AND olh.hist_type_code = 'CANCELLATION'
                   AND olh.reason_id = oer.reason_id
                   AND oer.reason_code NOT IN
                           (gv_change_reason, 'BLK_ADJ_PGM')
                   AND olh.header_id = oer.header_id
                   AND oer.entity_code = 'LINE'
                   AND olh.line_id = oer.entity_id;
        END IF;

        RETURN ln_qty;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 0;
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_cum_transferred_qty;

    FUNCTION func_return_cursor (pn_org_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER, pv_brand VARCHAR2, pn_cust_account_id NUMBER, pn_cust_account_id2 NUMBER, pn_bulk_ord_hdr_id_frm NUMBER, pn_bulk_ord_hdr_id_to NUMBER, pd_req_ord_date_from DATE, pd_req_ord_date_to DATE, pd_ssd_from DATE, pd_ssd_to DATE, pd_lad_from DATE, pd_lad_to DATE, pv_demand_class_code VARCHAR2, pn_ship_from_org_id NUMBER, pv_style VARCHAR2, pv_color VARCHAR2, pn_inv_item_id VARCHAR2, pn_frm_rem_qty NUMBER
                                 , pn_to_rem_qty NUMBER)
        RETURN VARCHAR2
    IS
        lv_query       VARCHAR2 (32767) := '';
        lv_where       VARCHAR2 (32767) := '';
        lv_ref_cur     SYS_REFCURSOR;
        ln_row_count   NUMBER := 0;
        ln_tot_count   NUMBER := 0;

        CURSOR cur_ord_type IS
            SELECT TO_NUMBER (lookup_code) order_type_id
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                   AND flv.tag = pn_org_id
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1);
    BEGIN
        SELECT COUNT (lookup_code) order_type_id
          INTO ln_tot_count
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
               AND flv.tag = pn_org_id
               AND flv.language = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        lv_where   := ' AND ooha.order_type_id in (';

        FOR rec_cur_ord_type IN cur_ord_type
        LOOP
            ln_row_count   := ln_row_count + 1;

            IF ln_row_count != ln_tot_count
            THEN
                lv_where   :=
                    lv_where || rec_cur_ord_type.order_type_id || ',';
            ELSE
                lv_where   :=
                    lv_where || rec_cur_ord_type.order_type_id || ')';
            END IF;
        END LOOP;

        lv_query   :=
               'SELECT  
               ooha.header_id,
                oola.line_id,
                ooha.org_id,
                hp.party_name customer_name,
                hca.account_number customer_number,
                oola.cust_po_number,
                ooha.order_number,
                oola.line_number || ''.'' || oola.shipment_number line_number,
                oola.inventory_item_id,
                oola.request_date,
                oola.schedule_ship_date,
                oola.latest_acceptable_date,
                msib.segment1 item_number,
                msib.description item_description,
                mc.segment2 division,
                mc.segment3 department,
                (oola.ordered_quantity + oola.cancelled_quantity)
                   original_qty,
                oola.ordered_quantity ordered_quantity,
                oola.unit_selling_price,
                NULL requested_qty,
                NVL (
                   XXD_ONT_BULK_ORDER_FORM_PKG.get_cum_transferred_qty (
                      oola.header_id,
                      oola.line_id,
                      ''BLK_ADJ_PGM''),
                   0)
                   consumed_qty,
                NVL (
                   XXD_ONT_BULK_ORDER_FORM_PKG.get_cum_transferred_qty (
                      oola.header_id,
                      oola.line_id,
                      ''BLK_FORM_TRANSFER''),
                   0)
                   cum_transferred_qty,
                NVL (
                   XXD_ONT_BULK_ORDER_FORM_PKG.get_cum_transferred_qty (
                      oola.header_id,
                      oola.line_id,
                      ''OTHER''),
                   0)
                   cancelled_quantity,
                ''N'' process_flag,
                NULL error_message,
                2 select_flag,
                oola.creation_date
           FROM oe_order_headers_all ooha,
                oe_order_lines_all oola,
                hz_cust_accounts hca,
                hz_parties hp,
                mtl_system_items_b msib,
                mtl_item_categories mic,
                mtl_categories_b mc
          WHERE     ooha.header_id = oola.header_id
                AND ooha.sold_to_org_id = hca.cust_account_id
                AND hca.party_id = hp.party_id
                AND hca.attribute18 IS NULL--excluding ecom customers
                AND msib.inventory_item_id = oola.inventory_item_id
                AND msib.organization_id = oola.ship_from_org_id
                AND msib.inventory_item_id = mic.inventory_item_id
                AND msib.organization_id = mic.organization_id
                AND mc.structure_id = 101
                AND mic.category_set_id = 1
                AND mc.category_id = mic.category_id
                AND NOT EXISTS
                       (SELECT 1
                          FROM xxdo.xxd_ont_bulk_order_lines_gt xoeb
                         WHERE 1 = 1 AND xoeb.line_id = oola.line_id)
                AND ooha.org_id = '
            || pn_org_id
            || ' 
                AND ooha.open_flag = ''Y''
                AND oola.open_flag = ''Y''
                AND oola.schedule_ship_date IS NOT NULL
                AND ooha.attribute5 = '''
            || pv_brand
            || '''';


        IF pn_cust_account_id2 IS NOT NULL AND pn_cust_account_id IS NOT NULL
        THEN
            IF pn_cust_account_id = pn_cust_account_id2
            THEN
                lv_where   :=
                       lv_where
                    || ' AND hca.cust_account_id = '
                    || pn_cust_account_id;
            ELSE
                lv_where   := lv_where || ' 1=2';
            END IF;
        ELSIF pn_cust_account_id2 IS NOT NULL AND pn_cust_account_id IS NULL
        THEN
            lv_where   :=
                   lv_where
                || ' AND hca.cust_account_id = '
                || pn_cust_account_id2;
        ELSIF pn_cust_account_id IS NOT NULL AND pn_cust_account_id2 IS NULL
        THEN
            lv_where   :=
                   lv_where
                || ' AND hca.cust_account_id = '
                || pn_cust_account_id;
        END IF;


        IF     pn_bulk_ord_hdr_id_frm IS NOT NULL
           AND pn_bulk_ord_hdr_id_to IS NOT NULL
           AND pn_bulk_ord_hdr_id_frm = pn_bulk_ord_hdr_id_to
        THEN
            lv_where   :=
                   lv_where
                || ' AND ooha.order_number = '
                || pn_bulk_ord_hdr_id_frm;
        END IF;


        IF     pn_bulk_ord_hdr_id_frm IS NOT NULL
           AND pn_bulk_ord_hdr_id_to IS NOT NULL
           AND pn_bulk_ord_hdr_id_frm != pn_bulk_ord_hdr_id_to
        THEN
            lv_where   :=
                   lv_where
                || ' AND ooha.order_number BETWEEN '
                || pn_bulk_ord_hdr_id_frm
                || ' AND '
                || pn_bulk_ord_hdr_id_to;
        END IF;

        IF     pd_req_ord_date_from IS NOT NULL
           AND pd_req_ord_date_to IS NOT NULL
        THEN
            IF pd_req_ord_date_from != pd_req_ord_date_to
            THEN
                lv_where   :=
                       lv_where
                    || ' AND oola.request_date between to_date('''
                    || TO_CHAR (pd_req_ord_date_from,
                                'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'') AND to_date('''
                    || TO_CHAR (pd_req_ord_date_to, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'')';
            ELSE
                lv_where   :=
                       lv_where
                    || ' AND oola.request_date = to_date('''
                    || TO_CHAR (pd_req_ord_date_from,
                                'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'')';
            END IF;
        END IF;

        IF pd_ssd_from IS NOT NULL AND pd_ssd_to IS NOT NULL
        THEN
            IF pd_ssd_from != pd_ssd_to
            THEN
                lv_where   :=
                       lv_where
                    || ' AND oola.schedule_ship_date between to_date('''
                    || TO_CHAR (pd_ssd_from, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'') AND to_date('''
                    || TO_CHAR (pd_ssd_to, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'')';
            ELSE
                lv_where   :=
                       lv_where
                    || ' AND oola.schedule_ship_date = to_date('''
                    || TO_CHAR (pd_ssd_from, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'')';
            END IF;
        END IF;

        IF pd_lad_from IS NOT NULL AND pd_lad_to IS NOT NULL
        THEN
            IF pd_lad_from != pd_lad_to
            THEN
                lv_where   :=
                       lv_where
                    || ' AND oola.latest_acceptable_date between to_date('''
                    || TO_CHAR (pd_lad_from, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'') AND to_date('''
                    || TO_CHAR (pd_lad_to, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'')';
            ELSE
                lv_where   :=
                       lv_where
                    || ' AND oola.latest_acceptable_date = to_date('''
                    || TO_CHAR (pd_lad_from, 'DD-MON-RRRR HH24:mi:ss')
                    || ''',''DD-MON-RRRR HH24:mi:ss'')';
            END IF;
        END IF;


        IF pn_ship_from_org_id IS NOT NULL
        THEN
            lv_where   :=
                   lv_where
                || ' AND oola.ship_from_org_id = '
                || pn_ship_from_org_id;
        END IF;

        IF pv_style IS NOT NULL
        THEN
            lv_where   :=
                lv_where || ' AND mc.attribute7 = ''' || pv_style || '''';
        END IF;

        IF pv_color IS NOT NULL
        THEN
            lv_where   :=
                lv_where || ' AND mc.attribute8 = ''' || pv_color || '''';
        END IF;

        IF pn_inv_item_id IS NOT NULL
        THEN
            lv_where   :=
                   lv_where
                || ' AND oola.inventory_item_id  = '
                || pn_inv_item_id;
        END IF;

        IF pn_frm_rem_qty IS NOT NULL AND pn_to_rem_qty IS NOT NULL
        THEN
            IF pn_frm_rem_qty = pn_to_rem_qty
            THEN
                lv_where   :=
                       lv_where
                    || ' AND oola.ordered_quantity = '
                    || pn_frm_rem_qty;
            ELSE
                lv_where   :=
                       lv_where
                    || ' AND oola.ordered_quantity between '
                    || pn_frm_rem_qty
                    || ' and '
                    || pn_to_rem_qty;
            END IF;
        ELSIF pn_frm_rem_qty IS NOT NULL AND pn_to_rem_qty IS NULL
        THEN
            lv_where   :=
                   lv_where
                || ' AND oola.ordered_quantity >= '
                || pn_frm_rem_qty;
        ELSIF pn_frm_rem_qty IS NULL AND pn_to_rem_qty IS NOT NULL
        THEN
            lv_where   :=
                lv_where || ' AND oola.ordered_quantity <= ' || pn_to_rem_qty;
        END IF;

        lv_query   := lv_query || lv_where;

        RETURN lv_query;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END func_return_cursor;

    PROCEDURE xxd_ont_bulk_order_proc (pn_org_id                NUMBER,
                                       pn_user_id               NUMBER,
                                       pn_resp_id               NUMBER,
                                       pn_resp_appl_id          NUMBER,
                                       pv_brand                 VARCHAR2,
                                       pn_cust_account_id       NUMBER,
                                       pn_cust_account_id2      NUMBER,
                                       pn_bulk_ord_hdr_id_frm   NUMBER,
                                       pn_bulk_ord_hdr_id_to    NUMBER,
                                       pd_req_ord_date_from     DATE,
                                       pd_req_ord_date_to       DATE,
                                       pd_ssd_from              DATE,
                                       pd_ssd_to                DATE,
                                       pd_lad_from              DATE,
                                       pd_lad_to                DATE,
                                       pv_demand_class_code     VARCHAR2,
                                       pn_ship_from_org_id      NUMBER,
                                       pv_style                 VARCHAR2,
                                       pv_color                 VARCHAR2,
                                       pn_inv_item_id           VARCHAR2,
                                       pn_frm_rem_qty           NUMBER,
                                       pn_to_rem_qty            NUMBER,
                                       pv_mode                  VARCHAR2)
    IS
        ln_count         NUMBER;
        l_index          NUMBER := 0;
        dml_errors       EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);
        lv_err_msg       VARCHAR2 (1000);

        lv_ref_cur       VARCHAR2 (32767);

        TYPE x_ref_cur IS REF CURSOR;

        l_ref_cur        x_ref_cur;

        CURSOR cur_insert IS
            SELECT ooha.header_id, oola.line_id, ooha.org_id,
                   hp.party_name customer_name, hca.account_number customer_number, oola.cust_po_number,
                   ooha.order_number, oola.line_number || '.' || oola.shipment_number line_number, oola.inventory_item_id,
                   oola.request_date, oola.schedule_ship_date, oola.latest_acceptable_date,
                   msib.segment1 item_number, msib.description item_description, mc.segment2 division,
                   mc.segment3 department, (oola.ordered_quantity + oola.cancelled_quantity) original_qty, oola.ordered_quantity ordered_quantity,
                   oola.unit_selling_price, NULL requested_qty, NVL (xxd_ont_bulk_order_form_pkg.get_cum_transferred_qty (oola.header_id, oola.line_id, 'BLK_ADJ_PGM'), 0) consumed_qty,
                   NVL (xxd_ont_bulk_order_form_pkg.get_cum_transferred_qty (oola.header_id, oola.line_id, 'BLK_FORM_TRANSFER'), 0) cum_transferred_qty, oola.cancelled_quantity, 'N' process_flag,
                   NULL error_message, 2 select_flag, oola.creation_date
              FROM oe_order_headers_all ooha, ont.oe_order_lines_all oola, hz_cust_accounts hca,
                   hz_parties hp, mtl_system_items_b msib, mtl_item_categories mic,
                   mtl_categories_b mc
             WHERE     1 = 2
                   AND ooha.header_id = oola.header_id
                   AND ooha.sold_to_org_id = hca.cust_account_id
                   AND hca.party_id = hp.party_id
                   AND msib.inventory_item_id = oola.inventory_item_id
                   AND msib.organization_id = oola.ship_from_org_id
                   AND msib.inventory_item_id = mic.inventory_item_id
                   AND msib.organization_id = mic.organization_id
                   AND mc.structure_id = 101
                   AND mc.category_id = mic.category_id
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv, oe_transaction_types_all ott
                             WHERE     1 = 1
                                   AND flv.lookup_type =
                                       'XXD_ONT_BULK_ORDER_TYPE'
                                   AND flv.view_application_id = 660
                                   AND ott.transaction_type_id =
                                       TO_NUMBER (flv.lookup_code)
                                   AND ooha.order_type_id =
                                       ott.transaction_type_id
                                   AND ott.org_id = TO_NUMBER (flv.tag)
                                   AND ott.org_id = ooha.org_id
                                   AND flv.language = USERENV ('LANG')
                                   AND flv.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                   NVL (
                                                                       flv.start_date_active,
                                                                       SYSDATE))
                                                           AND TRUNC (
                                                                   NVL (
                                                                       flv.end_date_active,
                                                                       SYSDATE)))
                   AND ooha.org_id = gn_org_id
                   AND ooha.open_flag = 'Y'
                   AND oola.schedule_ship_date IS NOT NULL
                   AND ooha.attribute5 = pv_brand;

        TYPE t_load_tbl_typ IS TABLE OF cur_insert%ROWTYPE;

        t_load_tbl_tab   t_load_tbl_typ;
    BEGIN
        IF pv_mode = 'I'
        THEN
            EXECUTE IMMEDIATE('DELETE FROM XXDO.XXD_ONT_BULK_ORDER_LINES_GT');
        END IF;

        lv_ref_cur   :=
            func_return_cursor (pn_org_id, pn_user_id, pn_resp_id,
                                pn_resp_appl_id, pv_brand, pn_cust_account_id, pn_cust_account_id2, pn_bulk_ord_hdr_id_frm, pn_bulk_ord_hdr_id_to, pd_req_ord_date_from, pd_req_ord_date_to, pd_ssd_from, pd_ssd_to, pd_lad_from, pd_lad_to, pv_demand_class_code, pn_ship_from_org_id, pv_style, pv_color, pn_inv_item_id, pn_frm_rem_qty
                                , pn_to_rem_qty);

        OPEN l_ref_cur FOR lv_ref_cur;

        LOOP
            FETCH l_ref_cur BULK COLLECT INTO t_load_tbl_tab LIMIT 1000;

            BEGIN
                FORALL l_index IN 1 .. t_load_tbl_tab.COUNT SAVE EXCEPTIONS
                    INSERT /*+ parallel(8)*/
                           INTO xxdo.xxd_ont_bulk_order_lines_gt (
                                    header_id,
                                    line_id,
                                    org_id,
                                    customer_name,
                                    customer_number,
                                    cust_po_number,
                                    order_number,
                                    line_number,
                                    inventory_item_id,
                                    request_date,
                                    schedule_ship_date,
                                    latest_acceptable_date,
                                    item_number,
                                    item_description,
                                    division,
                                    department,
                                    original_qty,
                                    ordered_quantity,
                                    unit_selling_price,
                                    requested_qty,
                                    consumed_qty,
                                    cum_transferred_qty,
                                    cancelled_quantity,
                                    process_flag,
                                    error_message,
                                    select_flag,
                                    creation_date)
                             VALUES (
                                        t_load_tbl_tab (l_index).header_id,
                                        t_load_tbl_tab (l_index).line_id,
                                        t_load_tbl_tab (l_index).org_id,
                                        t_load_tbl_tab (l_index).customer_name,
                                        t_load_tbl_tab (l_index).customer_number,
                                        t_load_tbl_tab (l_index).cust_po_number,
                                        t_load_tbl_tab (l_index).order_number,
                                        t_load_tbl_tab (l_index).line_number,
                                        t_load_tbl_tab (l_index).inventory_item_id,
                                        t_load_tbl_tab (l_index).request_date,
                                        t_load_tbl_tab (l_index).schedule_ship_date,
                                        t_load_tbl_tab (l_index).latest_acceptable_date,
                                        t_load_tbl_tab (l_index).item_number,
                                        t_load_tbl_tab (l_index).item_description,
                                        t_load_tbl_tab (l_index).division,
                                        t_load_tbl_tab (l_index).department,
                                        t_load_tbl_tab (l_index).original_qty,
                                        t_load_tbl_tab (l_index).ordered_quantity,
                                        t_load_tbl_tab (l_index).unit_selling_price,
                                        t_load_tbl_tab (l_index).requested_qty,
                                        t_load_tbl_tab (l_index).consumed_qty,
                                        t_load_tbl_tab (l_index).cum_transferred_qty,
                                        t_load_tbl_tab (l_index).cancelled_quantity,
                                        t_load_tbl_tab (l_index).process_flag,
                                        t_load_tbl_tab (l_index).error_message,
                                        t_load_tbl_tab (l_index).select_flag,
                                        t_load_tbl_tab (l_index).creation_date);

                EXIT WHEN l_ref_cur%NOTFOUND;
            EXCEPTION
                WHEN dml_errors
                THEN
                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'Error while Inserting xxd_ont_bulk_order_lines_gt Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                    END LOOP;
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           'Error Others while inserting into xxd_ont_bulk_order_lines_gt table'
                        || SQLERRM;

                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'When Others exception: Error while inserting xxd_ont_bulk_order_lines_gt Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                    END LOOP;
            END;
        END LOOP;

        CLOSE l_ref_cur;


        ln_count   := SQL%ROWCOUNT;

        IF pv_mode <> 'I'
        THEN
            proc_reset_orders;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END xxd_ont_bulk_order_proc;

    FUNCTION get_error_count
        RETURN NUMBER
    IS
        ln_error_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_error_count
          FROM xxdo.xxd_ont_bulk_order_lines_gt
         WHERE 1 = 1 AND process_flag = 'E';

        RETURN ln_error_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_error_count;

    PROCEDURE update_interim_status
    IS
        ln_error_count   NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxd_ont_bulk_order_lines_gt
           SET process_flag   = 'I'
         WHERE 1 = 1 AND process_flag = 'N' AND select_flag = 1;

        COMMIT;

        SELECT COUNT (1)
          INTO ln_error_count
          FROM xxdo.xxd_ont_bulk_order_lines_gt
         WHERE 1 = 1 AND process_flag = 'I';
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END update_interim_status;

    FUNCTION get_ordered_quantity (pn_line_id NUMBER)
        RETURN NUMBER
    IS
        ln_ord_qty   NUMBER;
    BEGIN
        SELECT ordered_quantity
          INTO ln_ord_qty
          FROM oe_order_lines_all
         WHERE 1 = 1 AND line_id = pn_line_id;

        RETURN ln_ord_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            RETURN 0;
    END;

    PROCEDURE proc_call_process_each_order (
        pn_org_id                         NUMBER,
        pn_user_id                        NUMBER,
        pn_resp_id                        NUMBER,
        pn_resp_appl_id                   NUMBER,
        pn_header_id                      NUMBER DEFAULT NULL,
        pn_sold_to_org_id                 NUMBER,
        pv_cust_po_number                 VARCHAR2,
        x_message              OUT NOCOPY VARCHAR2)
    AS
        CURSOR get_orders_c IS
              SELECT DISTINCT header_id, order_number, org_id
                FROM xxd_ont_bulk_order_lines_gt
               WHERE     select_flag = 1
                     AND requested_qty IS NOT NULL
                     AND process_flag = 'N'
            ORDER BY header_id;

        CURSOR cur_get_orders_lines (
            p_header_id IN oe_order_headers_all.header_id%TYPE DEFAULT NULL)
        IS
              SELECT xob.header_id, xob.line_id, xob.org_id,
                     xob.customer_name, xob.customer_number, xob.cust_po_number,
                     xob.order_number, xob.line_number, xob.request_date,
                     xob.schedule_ship_date, xob.latest_acceptable_date, xob.item_number,
                     xob.inventory_item_id, xob.item_description, xob.division,
                     xob.department, xob.original_qty, oola.ordered_quantity,
                     xob.unit_selling_price, xob.requested_qty, xob.consumed_qty,
                     xob.cum_transferred_qty, xob.cancelled_quantity, xob.process_flag,
                     xob.error_message, xob.select_flag, xob.creation_date
                FROM xxd_ont_bulk_order_lines_gt xob, oe_order_lines_all oola
               WHERE     1 = 1
                     AND select_flag = 1
                     AND requested_qty IS NOT NULL
                     AND process_flag = 'N'
                     AND ((p_header_id IS NOT NULL AND xob.header_id = p_header_id) OR (p_header_id IS NULL AND 1 = 1))
                     AND xob.line_id = oola.line_id
            ORDER BY header_id;

        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER;
        ln_ord_num                 NUMBER;
        ln_success_count           NUMBER := 0;
        ln_error_count             NUMBER := 0;
        ln_total_count             NUMBER := 0;
        ln_lock_count              NUMBER := 0;
        ln_cancel_count            NUMBER := 0;
        ln_line_tbl_count          NUMBER := 0;
        lc_lock_status             VARCHAR2 (1);
        lc_return_status           VARCHAR2 (100);
        lc_msg_data                VARCHAR2 (4000);
        lc_error_message           VARCHAR2 (4000) := '';
        lv_message                 VARCHAR2 (1000) := '';
        ln_header_id               oe_order_headers_all.header_id%TYPE;
        l_bulk_header_rec          oe_order_pub.header_rec_type;
        l_bulk_line_rec            oe_order_pub.line_rec_type;
        l_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        lx_line_tbl                oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_request_rec              oe_order_pub.request_rec_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_atp_rec                  mrp_atp_pub.atp_rec_typ;
        l_atp_supply_demand        mrp_atp_pub.atp_supply_demand_typ;
        l_atp_period               mrp_atp_pub.atp_period_typ;
        l_atp_details              mrp_atp_pub.atp_details_typ;
        l_order_tbl_type           oe_holds_pvt.order_tbl_type;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        l_line_rec                 oe_order_pub.line_rec_type;
    BEGIN
        ROLLBACK;

        xxd_initialize_proc (pn_org_id, pn_user_id, pn_resp_id,
                             pn_resp_appl_id);

        -- Calculate the total
        SELECT COUNT (1)
          INTO ln_total_count
          FROM xxd_ont_bulk_order_lines_gt
         WHERE     select_flag = 1
               AND requested_qty IS NOT NULL
               AND process_flag = 'N';

        -- Verify all source orders and lock them
        FOR i IN get_orders_c
        LOOP
            lc_lock_status   := NULL;

            lc_lock_status   := lock_order (i.header_id);

            IF lc_lock_status = 'Y'
            THEN
                lc_error_message   :=
                       'One or more lines locked by another user in order '
                    || i.order_number;

                -- Fail the locked order and process the rest
                proc_update_error (i.header_id, lc_error_message);
            END IF;
        END LOOP;

        -- Verify all target orders and lock them
        IF pn_header_id IS NOT NULL AND lc_lock_status = 'N'
        THEN
            lc_lock_status   := NULL;
            lc_lock_status   := lock_order (pn_header_id);

            IF lc_lock_status = 'Y'
            THEN
                SELECT order_number
                  INTO ln_ord_num
                  FROM oe_order_headers_all
                 WHERE header_id = pn_header_id;

                lc_error_message   :=
                       'One or more lines locked by another user in order '
                    || ln_ord_num;

                -- If target order fail to lock, fail all
                proc_update_error (NULL, lc_error_message);
            END IF;
        END IF;

        -- Calculate Count After Lock Check
        SELECT COUNT (1)
          INTO ln_lock_count
          FROM xxd_ont_bulk_order_lines_gt
         WHERE     select_flag = 1
               AND requested_qty IS NOT NULL
               AND process_flag = 'N';

        IF ln_lock_count > 0
        THEN
            ln_error_count   := ln_total_count - ln_lock_count;
        ELSE
            ln_error_count   := 0;
        END IF;

        -- ======================================================================================
        -- Cancel the selected Bulk Order Lines
        -- ======================================================================================
        FOR orders_rec IN get_orders_c
        LOOP
            lc_error_message         := NULL;
            lc_msg_data              := NULL;
            ln_msg_count             := 0;
            ln_line_tbl_count        := 0;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            l_header_rec             := oe_order_pub.g_miss_header_rec;
            l_header_rec.header_id   := orders_rec.header_id;
            l_header_rec.operation   := oe_globals.g_opr_update;
            l_line_tbl               := oe_order_pub.g_miss_line_tbl;

            FOR rec_get_orders_lines
                IN cur_get_orders_lines (orders_rec.header_id)
            LOOP
                ln_line_tbl_count   := ln_line_tbl_count + 1;
                l_action_request_tbl (ln_line_tbl_count)   :=
                    oe_order_pub.g_miss_request_rec;
                l_line_tbl (ln_line_tbl_count)   :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (ln_line_tbl_count).operation   :=
                    oe_globals.g_opr_update;
                l_line_tbl (ln_line_tbl_count).header_id   :=
                    rec_get_orders_lines.header_id;
                l_line_tbl (ln_line_tbl_count).line_id   :=
                    rec_get_orders_lines.line_id;
                l_line_tbl (ln_line_tbl_count).ordered_quantity   :=
                      rec_get_orders_lines.ordered_quantity
                    - rec_get_orders_lines.requested_qty;
                l_line_tbl (ln_line_tbl_count).change_reason   :=
                    gv_change_reason;
                l_line_tbl (ln_line_tbl_count).change_comments   :=
                    gv_change_comments;
                l_line_tbl (ln_line_tbl_count).org_id   :=
                    pn_org_id;
            END LOOP;

            oe_order_pub.process_order (
                p_org_id                   => pn_org_id,
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => x_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => lx_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => x_action_request_tbl);

            IF lc_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   :=
                        SUBSTR (lc_error_message || lc_msg_data, 1, 3900);
                END LOOP;

                proc_update_error (orders_rec.header_id, lc_error_message);
                ln_error_count   := ln_error_count + lx_line_tbl.COUNT;
            END IF;
        END LOOP;

        -- Calculate the eligible records
        SELECT COUNT (1)
          INTO ln_cancel_count
          FROM xxd_ont_bulk_order_lines_gt
         WHERE     select_flag = 1
               AND requested_qty IS NOT NULL
               AND process_flag = 'N';

        -- ======================================================================================
        -- Create New Bulk Order Lines
        -- ======================================================================================
        IF ln_cancel_count > 0
        THEN
            ln_line_tbl_count   := 0;
            ln_msg_count        := 0;
            lc_msg_data         := NULL;
            lc_error_message    := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            l_header_rec        := oe_order_pub.g_miss_header_rec;
            l_line_tbl.delete;
            lx_line_tbl.delete;

            IF pn_header_id IS NOT NULL
            THEN
                l_header_rec.header_id   := pn_header_id;
                l_header_rec.org_id      := pn_org_id;
                l_header_rec.operation   := oe_globals.g_opr_update;
            ELSE
                SELECT MIN (header_id)
                  INTO ln_header_id
                  FROM xxd_ont_bulk_order_lines_gt
                 WHERE     select_flag = 1
                       AND requested_qty IS NOT NULL
                       AND process_flag = 'N';

                oe_header_util.query_row (p_header_id    => ln_header_id,
                                          x_header_rec   => l_bulk_header_rec);

                -- Header
                l_header_rec.org_id                    := pn_org_id;
                l_header_rec.transactional_curr_code   :=
                    l_bulk_header_rec.transactional_curr_code;
                l_header_rec.sold_to_org_id            := pn_sold_to_org_id;
                l_header_rec.price_list_id             :=
                    l_bulk_header_rec.price_list_id;
                l_header_rec.sold_from_org_id          :=
                    l_bulk_header_rec.sold_from_org_id;
                l_header_rec.order_type_id             :=
                    l_bulk_header_rec.order_type_id;
                l_header_rec.cust_po_number            := pv_cust_po_number;
                l_header_rec.order_source_id           :=
                    l_bulk_header_rec.order_source_id;
                l_header_rec.shipping_instructions     :=
                    l_bulk_header_rec.shipping_instructions;
                l_header_rec.packing_instructions      :=
                    l_bulk_header_rec.packing_instructions;
                l_header_rec.shipping_method_code      :=
                    l_bulk_header_rec.shipping_method_code;
                l_header_rec.freight_terms_code        :=
                    l_bulk_header_rec.freight_terms_code;
                l_header_rec.payment_term_id           :=
                    l_bulk_header_rec.payment_term_id;
                l_header_rec.deliver_to_org_id         :=
                    l_bulk_header_rec.deliver_to_org_id;
                l_header_rec.return_reason_code        :=
                    l_bulk_header_rec.return_reason_code;
                l_header_rec.attribute1                :=
                    l_bulk_header_rec.attribute1;
                l_header_rec.attribute3                :=
                    l_bulk_header_rec.attribute3;
                l_header_rec.attribute4                :=
                    l_bulk_header_rec.attribute4;
                l_header_rec.attribute5                :=
                    l_bulk_header_rec.attribute5;
                l_header_rec.attribute6                :=
                    l_bulk_header_rec.attribute6;
                l_header_rec.attribute7                :=
                    l_bulk_header_rec.attribute7;
                l_header_rec.attribute8                :=
                    l_bulk_header_rec.attribute8;
                l_header_rec.attribute9                :=
                    l_bulk_header_rec.attribute9;
                l_header_rec.attribute10               :=
                    l_bulk_header_rec.attribute10;
                l_header_rec.attribute13               :=
                    l_bulk_header_rec.attribute13;
                l_header_rec.attribute14               :=
                    l_bulk_header_rec.attribute14;
                l_header_rec.attribute15               :=
                    l_bulk_header_rec.attribute15;
                l_header_rec.request_date              :=
                    l_bulk_header_rec.request_date;
                l_header_rec.demand_class_code         :=
                    l_bulk_header_rec.demand_class_code;
                l_header_rec.sold_to_contact_id        :=
                    l_bulk_header_rec.sold_to_contact_id;
                l_header_rec.operation                 :=
                    oe_globals.g_opr_create;
                l_action_request_tbl (1)               :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (1).entity_code   :=
                    oe_globals.g_entity_header;
                l_action_request_tbl (1).request_type   :=
                    oe_globals.g_book_order;
            END IF;

            FOR rec_get_orders_lines IN cur_get_orders_lines ()
            LOOP
                oe_line_util.query_row (
                    p_line_id    => rec_get_orders_lines.line_id,
                    x_line_rec   => l_bulk_line_rec);
                --Lines
                ln_line_tbl_count                                        := ln_line_tbl_count + 1;
                l_line_tbl (ln_line_tbl_count)                           :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (ln_line_tbl_count).operation                 :=
                    oe_globals.g_opr_create;
                l_line_tbl (ln_line_tbl_count).header_id                 :=
                    NVL (pn_header_id, fnd_api.g_miss_num);
                l_line_tbl (ln_line_tbl_count).line_type_id              :=
                    l_bulk_line_rec.line_type_id;
                l_line_tbl (ln_line_tbl_count).cust_po_number            :=
                    NVL (pv_cust_po_number, fnd_api.g_miss_char);
                l_line_tbl (ln_line_tbl_count).inventory_item_id         :=
                    l_bulk_line_rec.inventory_item_id;
                l_line_tbl (ln_line_tbl_count).ordered_quantity          :=
                    rec_get_orders_lines.requested_qty;
                l_line_tbl (ln_line_tbl_count).ship_from_org_id          :=
                    l_bulk_line_rec.ship_from_org_id;
                l_line_tbl (ln_line_tbl_count).calculate_price_flag      := 'Y';
                l_line_tbl (ln_line_tbl_count).demand_class_code         :=
                    l_bulk_line_rec.demand_class_code;
                l_line_tbl (ln_line_tbl_count).unit_list_price           :=
                    l_bulk_line_rec.unit_list_price;
                l_line_tbl (ln_line_tbl_count).price_list_id             :=
                    l_bulk_line_rec.price_list_id;
                l_line_tbl (ln_line_tbl_count).agreement_id              :=
                    NVL (l_bulk_line_rec.agreement_id, fnd_api.g_miss_num);
                l_line_tbl (ln_line_tbl_count).order_source_id           :=
                    l_bulk_line_rec.order_source_id;
                l_line_tbl (ln_line_tbl_count).payment_term_id           :=
                    l_bulk_line_rec.payment_term_id;
                l_line_tbl (ln_line_tbl_count).shipping_method_code      :=
                    l_bulk_line_rec.shipping_method_code;
                l_line_tbl (ln_line_tbl_count).freight_terms_code        :=
                    l_bulk_line_rec.freight_terms_code;
                l_line_tbl (ln_line_tbl_count).request_date              :=
                    l_bulk_line_rec.request_date;
                l_line_tbl (ln_line_tbl_count).shipping_instructions     :=
                    l_bulk_line_rec.shipping_instructions;
                l_line_tbl (ln_line_tbl_count).packing_instructions      :=
                    l_bulk_line_rec.packing_instructions;
                l_line_tbl (ln_line_tbl_count).attribute1                :=
                    l_bulk_line_rec.attribute1;
                l_line_tbl (ln_line_tbl_count).attribute6                :=
                    l_bulk_line_rec.attribute6;
                l_line_tbl (ln_line_tbl_count).attribute7                :=
                    l_bulk_line_rec.attribute7;
                l_line_tbl (ln_line_tbl_count).attribute8                :=
                    l_bulk_line_rec.attribute8;
                l_line_tbl (ln_line_tbl_count).attribute10               :=
                    l_bulk_line_rec.attribute10;
                l_line_tbl (ln_line_tbl_count).attribute13               :=
                    l_bulk_line_rec.attribute13;
                l_line_tbl (ln_line_tbl_count).attribute14               :=
                    l_bulk_line_rec.attribute14;
                l_line_tbl (ln_line_tbl_count).attribute15               :=
                    l_bulk_line_rec.attribute15;
                l_line_tbl (ln_line_tbl_count).deliver_to_org_id         :=
                    l_bulk_line_rec.deliver_to_org_id;
                l_line_tbl (ln_line_tbl_count).latest_acceptable_date    :=
                    l_bulk_line_rec.latest_acceptable_date;
                l_line_tbl (ln_line_tbl_count).source_document_type_id   := 2; -- 2 for "Copy"
                l_line_tbl (ln_line_tbl_count).source_document_id        :=
                    l_bulk_line_rec.header_id;
                l_line_tbl (ln_line_tbl_count).source_document_line_id   :=
                    l_bulk_line_rec.line_id;
            END LOOP;

            oe_order_pub.process_order (
                p_org_id                   => pn_org_id,
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => x_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => lx_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => x_action_request_tbl);

            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                ln_success_count   := lx_line_tbl.COUNT;
            ELSE
                ln_success_count   := 0;
                ln_error_count     := ln_total_count;

                proc_update_error (NULL, lc_error_message);
            END IF;
        ELSE
            ln_success_count   := 0;
            ln_error_count     := ln_total_count;
        END IF;

        IF ln_success_count > 0
        THEN
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;

        lv_message   :=
               'Lines selected for transfer - '
            || NVL (ln_total_count, 0)
            || CHR (10)
            || 'Line successfully transferred - '
            || NVL (ln_success_count, 0)
            || CHR (10)
            || 'Lines failed to transfer - '
            || NVL (ln_error_count, 0)
            || CASE
                   WHEN pn_header_id IS NULL AND ln_success_count > 0
                   THEN
                          CHR (10)
                       || CHR (10)
                       || 'New Order Created; Order: '
                       || x_header_rec.order_number
                       || '. Status: '
                       || x_header_rec.flow_status_code
                   ELSE
                       NULL
               END;

        x_message   := lv_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            proc_update_error (NULL, SQLERRM);
    END proc_call_process_each_order;
END xxd_ont_bulk_order_form_pkg;
/
