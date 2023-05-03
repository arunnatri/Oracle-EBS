--
-- XXD_ONT_SO_LINE_REPROCESS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SO_LINE_REPROCESS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_SO_LINE_REPROCESS_PKG
    * Design       : This package will be used to retry order lines workflow and/or to
    *                update order lines flow status code as per Doc ID 1470700.1
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 10-Mar-2022  1.0        Somasekhar C            Initial Version for CCR0009891
    ******************************************************************************************/
    PROCEDURE order_line_status_update (p_org_id IN NUMBER, p_req_date_from IN DATE, p_req_date_to IN DATE)
    IS
        -- Cursor to fetch order lines to update line status
        CURSOR so_lines_cur IS
              SELECT oola.header_id, oola.line_id, oola.org_id
                FROM oe_order_lines_all oola, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                     mtl_txn_request_lines mtrl
               WHERE     1 = 1
                     AND oola.line_id = wdd.source_line_id
                     AND wdd.delivery_detail_id = wda.delivery_detail_id
                     AND mtrl.line_id = wdd.move_order_line_id
                     AND wdd.source_code = 'OE'
                     AND oola.flow_status_code = 'BOOKED'
                     AND oola.open_flag = 'Y'
                     AND oola.org_id = p_org_id
                     AND oola.request_date > p_req_date_from - 1
                     AND oola.request_date < p_req_date_to + 1
            GROUP BY oola.header_id, oola.line_id, oola.org_id;

        l_header_rec               oe_order_pub.header_rec_type;
        x_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl           oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
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
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        lv_return_status           VARCHAR2 (1);
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER (10);
        lv_msg_data                VARCHAR2 (4000);
        ln_record_count            NUMBER := 0;
        ln_success_count           NUMBER := 0;
        ln_error_count             NUMBER := 0;
    BEGIN
        fnd_global.apps_initialize (fnd_global.user_id,
                                    fnd_global.resp_id,
                                    fnd_global.resp_appl_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', p_org_id);

        FOR so_lines_rec IN so_lines_cur
        LOOP
            ln_record_count                   := ln_record_count + 1;
            oe_msg_pub.initialize;
            oe_msg_pub.g_msg_tbl.delete;
            l_line_tbl (1)                    := oe_order_pub.g_miss_line_rec;
            l_line_tbl (1).header_id          := so_lines_rec.header_id;
            l_line_tbl (1).line_id            := so_lines_rec.line_id;
            l_line_tbl (1).flow_status_code   := 'AWAITING_SHIPPING';
            l_line_tbl (1).operation          := oe_globals.g_opr_update;

            -- CALL TO PROCESS ORDER
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => lv_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lv_msg_data,
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
                x_line_tbl                 => x_line_tbl,
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

            -- Check the return status
            IF lv_return_status = fnd_api.g_ret_sts_success
            THEN
                ln_success_count   := ln_success_count + 1;
                COMMIT;
            ELSE
                ln_error_count   := ln_error_count + 1;
                oe_msg_pub.get (p_msg_index => 1, p_encoded => fnd_api.g_false, p_data => lv_msg_data
                                , p_msg_index_out => ln_msg_index_out);

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Line ID '
                    || so_lines_rec.line_id
                    || ' failed with error message : '
                    || lv_msg_data);

                ROLLBACK;
            END IF;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Line Update Total Count = ' || ln_record_count);
        fnd_file.put_line (
            fnd_file.LOG,
            'Line Update Success Count = ' || ln_success_count);
        fnd_file.put_line (fnd_file.LOG,
                           'Line Update Error Count = ' || ln_error_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception in ORDER_LINE_STATUS_UPDATE: ' || SQLERRM);
    END order_line_status_update;

    PROCEDURE reprocess_so_lines (x_errbuf             OUT VARCHAR2,
                                  x_retcode            OUT NUMBER,
                                  p_org_id          IN     NUMBER,
                                  p_req_date_from   IN     VARCHAR2,
                                  p_req_date_to     IN     VARCHAR2)
    IS
        ld_req_date_from   DATE
            := fnd_date.canonical_to_date (p_req_date_from);
        ld_req_date_to     DATE := fnd_date.canonical_to_date (p_req_date_to);
        lv_item_type       VARCHAR2 (30) := 'OEOL';
        lv_result          VARCHAR2 (30);
        ln_record_count    NUMBER := 0;
        ln_success_count   NUMBER := 0;
        ln_error_count     NUMBER := 0;

        -- Cursor to fetch SO lines for which workflow not initiated
        CURSOR miss_lines_cur IS
            SELECT /*+ use_nl leading (ool) parallel(4) */
                   oola.line_id
              FROM wf_items wf, oe_order_lines_all oola
             WHERE     1 = 1
                   AND wf.item_key = TO_CHAR (oola.line_id)
                   AND oola.open_flag = 'Y'
                   AND oola.flow_status_code = 'BOOKED'
                   AND oola.transaction_phase_code = 'F'
                   AND wf.item_type = lv_item_type
                   AND wf.end_date IS NULL
                   AND oola.org_id = p_org_id
                   AND oola.request_date > ld_req_date_from - 1
                   AND oola.request_date < ld_req_date_to + 1
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wf_item_activity_statuses wias
                             WHERE     wias.item_type = wf.item_type
                                   AND wias.item_key = wf.item_key);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Operating Unit: ' || p_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Request Date From: ' || ld_req_date_from);
        fnd_file.put_line (fnd_file.LOG,
                           'Request Date To: ' || ld_req_date_to);

        FOR miss_lines_rec IN miss_lines_cur
        LOOP
            ln_record_count   := ln_record_count + 1;

            BEGIN
                oe_standard_wf.oeol_selector (
                    p_itemtype   => lv_item_type,
                    p_itemkey    => TO_CHAR (miss_lines_rec.line_id),
                    p_actid      => 12345,
                    p_funcmode   => 'SET_CTX',
                    p_result     => lv_result);

                wf_engine.startprocess (lv_item_type,
                                        TO_CHAR (miss_lines_rec.line_id));
                ln_success_count   := ln_success_count + 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'WF Restart for Line ID : '
                        || miss_lines_rec.line_id
                        || ' failed with error: '
                        || SQLERRM);
                    ln_error_count   := ln_error_count + 1;
            END;

            COMMIT;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'WF Retry Total Count = ' || ln_record_count);
        fnd_file.put_line (fnd_file.LOG,
                           'WF Retry Success Count = ' || ln_success_count);
        fnd_file.put_line (fnd_file.LOG,
                           'WF Retry Error Count = ' || ln_error_count);
        -- call line status update
        order_line_status_update (p_org_id, ld_req_date_from, ld_req_date_to);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception in REPROCESS_SO_LINES: ' || SQLERRM);
    END reprocess_so_lines;
END xxd_ont_so_line_reprocess_pkg;
/
