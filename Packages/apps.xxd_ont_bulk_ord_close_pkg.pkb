--
-- XXD_ONT_BULK_ORD_CLOSE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_ORD_CLOSE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORD_CLOSE_PKG
    * Design       : This package will be used to force close Bulk Order headers and
    *                update the delivery detail records
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 24-May-2022  1.0        Viswanathan Pandian/    Initial Version
    --                         Jayarajan AK
    ******************************************************************************************/
    gv_debug   VARCHAR2 (1);

    PROCEDURE msg (p_msg IN VARCHAR2)
    AS
    BEGIN
        IF gv_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception in MSG: ' || SQLERRM);
    END msg;

    PROCEDURE close_bulk_order_header (p_org_id IN NUMBER, p_request_date_from IN DATE, p_request_date_to IN DATE)
    AS
        CURSOR get_orders IS
            SELECT ooha.order_number, ooha.request_date, ooha.header_id
              FROM oe_order_headers_all ooha, oe_transaction_types_all otta
             WHERE     1 = 1
                   AND otta.transaction_type_id = ooha.order_type_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all oola
                             WHERE     1 = 1
                                   AND oola.header_id = ooha.header_id
                                   AND oola.open_flag = 'Y')
                   AND ooha.open_flag = 'Y'
                   AND otta.attribute5 = 'BO'
                   AND ooha.org_id = p_org_id
                   -- Request Date From
                   AND ((p_request_date_from IS NOT NULL AND ooha.request_date > p_request_date_from - 1) OR (p_request_date_from IS NULL AND 1 = 1))
                   -- Request Date To
                   AND ((p_request_date_to IS NOT NULL AND ooha.request_date < p_request_date_to + 1) OR (p_request_date_to IS NULL AND 1 = 1));

        lv_return_status           VARCHAR2 (1);
        lv_error_message           VARCHAR2 (4000);
        lv_msg_data                VARCHAR2 (1000);
        lv_header_flag             VARCHAR2 (1) := 'N';
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER;
        ln_record_count            NUMBER := 0;
        ln_success_count           NUMBER := 0;
        ln_error_count             NUMBER := 0;
        l_header_rec               oe_order_pub.header_rec_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_request_rec              oe_order_pub.request_rec_type;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
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
    BEGIN
        mo_global.set_policy_context ('S', p_org_id);
        fnd_global.apps_initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);
        oe_msg_pub.initialize;

        FOR i IN get_orders
        LOOP
            ln_record_count          := ln_record_count + 1;
            lv_return_status         := NULL;
            lv_error_message         := NULL;
            oe_msg_pub.delete_msg;
            l_header_rec             := oe_order_pub.g_miss_header_rec;
            l_line_tbl               := oe_order_pub.g_miss_line_tbl;
            l_action_request_tbl     := oe_order_pub.g_miss_request_tbl;
            l_header_rec.header_id   := i.header_id;
            l_header_rec.open_flag   := 'N';
            l_header_rec.operation   := oe_globals.g_opr_update;
            -- CALL TO PROCESS ORDER
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_org_id                   => p_org_id,
                p_init_msg_list            => fnd_api.g_true,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => lv_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lv_msg_data,
                p_header_rec               => l_header_rec,
                p_header_adj_tbl           => l_header_adj_tbl,
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

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lv_error_message
                                    , p_msg_index_out => ln_msg_index_out);
                END LOOP;

                lv_error_message   :=
                    NVL (lv_error_message, 'OE_ORDER_PUB Failed');
                ln_error_count   := ln_error_count + 1;
            ELSE
                ln_success_count   := ln_success_count + 1;
            END IF;

            IF MOD (ln_success_count, 100) = 0
            THEN
                COMMIT;
            END IF;

            IF lv_header_flag = 'N'
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'Order Number'
                    || CHR (9)
                    || CHR (9)
                    || 'Request Date'
                    || CHR (9)
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || CHR (9)
                    || 'Error Message');
                fnd_file.put_line (fnd_file.output, (RPAD ('=', 130, '=')));
                lv_header_flag   := 'Y';
            END IF;

            fnd_file.put_line (
                fnd_file.output,
                   i.order_number
                || CHR (9)
                || CHR (9)
                || i.request_date
                || CHR (9)
                || CHR (9)
                || lv_return_status
                || CHR (9)
                || CHR (9)
                || lv_error_message);
        END LOOP;

        COMMIT;
        msg ('Total Order Count = ' || ln_record_count);
        msg ('Success Order Count = ' || ln_success_count);
        msg ('Error Order Count = ' || ln_error_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception in CLOSE_BULK_ORDER_HEADER = ' || SQLERRM);
    END close_bulk_order_header;

    PROCEDURE close_delivery_detail (p_org_id IN NUMBER, p_request_date_from IN DATE, p_request_date_to IN DATE)
    AS
        CURSOR get_delivery_details IS
            SELECT ooha.order_number, ooha.request_date, ooha.header_id,
                   wdd.delivery_detail_id, wdd.released_status
              FROM oe_order_headers_all ooha, oe_transaction_types_all otta, oe_order_lines_all oola,
                   wsh_delivery_details wdd
             WHERE     1 = 1
                   AND otta.transaction_type_id = ooha.order_type_id
                   AND oola.header_id = ooha.header_id
                   AND wdd.source_header_id = ooha.header_id
                   AND wdd.source_line_id = oola.line_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status <> 'D'
                   AND oola.open_flag = 'N'
                   AND otta.attribute5 = 'BO'
                   AND ooha.org_id = p_org_id
                   -- Request Date From
                   AND ((p_request_date_from IS NOT NULL AND ooha.request_date > p_request_date_from - 1) OR (p_request_date_from IS NULL AND 1 = 1))
                   -- Request Date To
                   AND ((p_request_date_to IS NOT NULL AND ooha.request_date < p_request_date_to + 1) OR (p_request_date_to IS NULL AND 1 = 1));

        lv_return_status          VARCHAR2 (1);
        lv_error_message          VARCHAR2 (4000);
        lv_msg_data               VARCHAR2 (1000);
        lv_header_flag            VARCHAR2 (1) := 'N';
        ln_msg_count              NUMBER;
        ln_msg_index_out          NUMBER;
        ln_record_count           NUMBER := 0;
        ln_success_count          NUMBER := 0;
        ln_error_count            NUMBER := 0;
        l_delivery_details_info   wsh_glbl_var_strct_grp.delivery_details_rec_type;
    BEGIN
        oe_msg_pub.initialize;

        FOR i IN get_delivery_details
        LOOP
            oe_msg_pub.delete_msg;
            lv_return_status   := NULL;
            wsh_delivery_details_pkg.table_to_record (
                p_delivery_detail_id    => i.delivery_detail_id,
                x_delivery_detail_rec   => l_delivery_details_info,
                x_return_status         => lv_return_status);

            IF lv_return_status = fnd_api.g_ret_sts_success
            THEN
                l_delivery_details_info.released_status   := 'D';
                wsh_delivery_details_pkg.update_delivery_details (
                    p_delivery_details_info   => l_delivery_details_info,
                    x_return_status           => lv_return_status);
            END IF;

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lv_error_message
                                    , p_msg_index_out => ln_msg_index_out);
                END LOOP;

                lv_error_message   :=
                    NVL (lv_error_message, 'OE_ORDER_PUB Failed');
                ln_error_count   := ln_error_count + 1;
            ELSE
                ln_success_count   := ln_success_count + 1;
            END IF;

            IF MOD (ln_success_count, 100) = 0
            THEN
                COMMIT;
            END IF;
        /*
              IF lv_header_flag = 'N'
              THEN
                fnd_file.put_line (
                  fnd_file.output,
                     'Order Number'
                  || CHR (9)
                  || CHR (9)
                  || 'Request Date'
                  || CHR (9)
                  || CHR (9)
                  || 'Status'
                  || CHR (9)
                  || CHR (9)
                  || 'Error Message');
                fnd_file.put_line (fnd_file.output, (RPAD ('=', 130, '=')));
                lv_header_flag := 'Y';
              END IF;
        */
        /*fnd_file.put_line (
          fnd_file.output,
             i.order_number
          || CHR (9)
          || CHR (9)
          || i.request_date
          || CHR (9)
          || CHR (9)
          || lv_return_status
          || CHR (9)
          || CHR (9)
        || lv_error_message);*/
        END LOOP;

        COMMIT;
        msg ('Total Delivery Detail Count = ' || ln_record_count);
        msg ('Success Delivery Detail Count = ' || ln_success_count);
        msg ('Error Delivery Detail Count = ' || ln_error_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception in CLOSE_DELIVERY_DETAIL = ' || SQLERRM);
    END close_delivery_detail;


    PROCEDURE main (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_org_id IN NUMBER, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_action IN VARCHAR2
                    , p_debug IN VARCHAR2)
    AS
        lv_err_msg             VARCHAR2 (2000);
        ld_request_date_from   DATE;
        ld_request_date_to     DATE;
    BEGIN
        msg ('p_org_id: ' || p_org_id);
        msg ('p_request_date_from: ' || p_request_date_from);
        msg ('p_request_date_to: ' || p_request_date_to);
        msg ('p_action: ' || p_action);
        msg ('p_debug: ' || p_debug);

        gv_debug   := p_debug;
        ld_request_date_from   :=
            fnd_conc_date.string_to_date (p_request_date_from);
        ld_request_date_to   :=
            fnd_conc_date.string_to_date (p_request_date_to);

        msg ('ld_request_date_from: ' || ld_request_date_from);
        msg ('ld_request_date_to: ' || ld_request_date_to);

        IF p_action IN ('All', 'Close Bulk Order Headers')
        THEN
            close_bulk_order_header (p_org_id,
                                     ld_request_date_from,
                                     ld_request_date_to);
        END IF;

        IF p_action IN ('All', 'Close Bulk Order Delivery Details')
        THEN
            close_delivery_detail (p_org_id,
                                   ld_request_date_from,
                                   ld_request_date_to);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in MAIN = ' || SQLERRM);
    END main;
END xxd_ont_bulk_ord_close_pkg;
/
