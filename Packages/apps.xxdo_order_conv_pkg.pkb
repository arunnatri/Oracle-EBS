--
-- XXDO_ORDER_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ORDER_CONV_PKG"
IS
    PROCEDURE process_order (out_chr_errbuf OUT VARCHAR2, out_chr_retcode OUT NUMBER, in_num_worker_number IN NUMBER
                             , in_num_parent_request_id IN NUMBER)
    IS
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_tab_out_line             oe_order_pub.line_tbl_type;
        l_old_line_tbl             oe_order_pub.line_tbl_type;
        l_request_tbl              oe_order_pub.request_tbl_type;
        l_header_rec               oe_order_pub.header_rec_type;
        l_header_val_rec           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        l_line_val_tbl             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        out_tab_proc_line          oe_order_pub.line_tbl_type;
        l_chr_poapi_ret_status     VARCHAR2 (1);
        l_num_msg_cnt              NUMBER;
        l_chr_msg_data             VARCHAR2 (2000);
        l_chr_log_data             VARCHAR2 (500);
        l_num_count                NUMBER;
        l_num_index                NUMBER;
        l_num_msg_index_out        NUMBER;
        l_chr_sysdate              VARCHAR2 (50)
            := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
        lv_calc_value              VARCHAR2 (20);
        l_set_org_id               NUMBER := 0;
        lv_user_name               VARCHAR2 (50) := 'BATCH';
        lv_appl_id                 NUMBER;
        lv_resp_id                 NUMBER;
        lv_user_id                 NUMBER;
        lv_responsbility_name      VARCHAR2 (200)
                                       := 'Order Management Super User';

        CURSOR hdr_cur IS
            SELECT DISTINCT xoc.header_id
              FROM xxdo_order_conv_stg xoc
             WHERE     request_id = in_num_parent_request_id
                   AND worker_number = in_num_worker_number;

        CURSOR order_lines (in_num_header IN NUMBER)
        IS
            SELECT xoc.ROWID, xoc.*
              FROM xxdo.xxdo_order_conv_stg xoc
             WHERE     xoc.request_id = in_num_parent_request_id
                   AND xoc.worker_number = in_num_worker_number
                   AND xoc.header_id = in_num_header;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************** P R O C E S S   O R D E R*************************');
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        BEGIN
            SELECT user_id
              INTO lv_user_id
              FROM apps.fnd_user
             WHERE user_name = lv_user_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_id   := NULL;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'User Name and User Id ' || lv_user_name || '-' || lv_user_id);

        BEGIN
            SELECT responsibility_id, application_id
              INTO lv_resp_id, lv_appl_id
              FROM apps.fnd_responsibility_vl
             WHERE responsibility_name = lv_responsbility_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_resp_id   := NULL;
                lv_appl_id   := NULL;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'Responsbility Name and Id'
            || lv_responsbility_name
            || '-'
            || lv_resp_id);

        FOR hdr_rec IN hdr_cur
        LOOP
            l_num_index   := 0;
            l_line_tbl.DELETE;

            FOR order_line_rec IN order_lines (hdr_rec.header_id)
            LOOP
                l_num_index                                     := l_num_index + 1;
                l_line_tbl (l_num_index)                        := oe_order_pub.g_miss_line_rec;
                l_line_tbl (l_num_index).header_id              := hdr_rec.header_id;
                l_line_tbl (l_num_index).line_id                :=
                    order_line_rec.line_id;
                l_line_tbl (l_num_index).ship_from_org_id       :=
                    order_line_rec.new_warehouse_id;
                l_line_tbl (l_num_index).last_update_login      :=
                    fnd_global.login_id;
                l_line_tbl (l_num_index).last_updated_by        :=
                    fnd_global.user_id;
                l_line_tbl (l_num_index).last_update_date       := SYSDATE;
                l_line_tbl (l_num_index).operation              :=
                    oe_globals.g_opr_update;
                l_line_tbl (l_num_index).schedule_ship_date     :=
                    order_line_rec.schedule_ship_date;

                SELECT org_id
                  INTO l_set_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = hdr_rec.header_id;


                IF order_line_rec.schedule_ship_date IS NOT NULL
                THEN
                    l_line_tbl (l_num_index).Override_atp_date_code   := 'Y';
                END IF;

                l_line_tbl (l_num_index).calculate_price_flag   := 'N';
            END LOOP;

            --Mo_global.set_policy_context('S', l_set_org_id);

            fnd_global.apps_initialize (user_id        => lv_user_id,
                                        resp_id        => lv_resp_id,
                                        resp_appl_id   => lv_appl_id);
            --Mo_global.init('ONT');

            fnd_file.put_line (fnd_file.LOG,
                               'l_set_org_id: ' || l_set_org_id);


            IF l_num_index > 0
            THEN
                oe_order_pub.process_order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    x_return_status            => l_chr_poapi_ret_status,
                    x_msg_count                => l_num_msg_cnt,
                    x_msg_data                 => l_chr_msg_data,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_old_line_tbl             => l_old_line_tbl,
                    x_header_rec               => l_header_rec,
                    x_header_val_rec           => l_header_val_rec,
                    x_header_adj_tbl           => l_header_adj_tbl,
                    x_header_adj_val_tbl       => l_header_adj_val_tbl,
                    x_header_price_att_tbl     => l_header_price_att_tbl,
                    x_header_adj_att_tbl       => l_header_adj_att_tbl,
                    x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl,
                    x_header_scredit_tbl       => l_header_scredit_tbl,
                    x_header_scredit_val_tbl   => l_header_scredit_val_tbl,
                    x_line_tbl                 => out_tab_proc_line,
                    x_line_val_tbl             => l_line_val_tbl,
                    x_line_adj_tbl             => l_line_adj_tbl,
                    x_line_adj_val_tbl         => l_line_adj_val_tbl,
                    x_line_price_att_tbl       => l_line_price_att_tbl,
                    x_line_adj_att_tbl         => l_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl,
                    x_line_scredit_tbl         => l_line_scredit_tbl,
                    x_line_scredit_val_tbl     => l_line_scredit_val_tbl,
                    x_lot_serial_tbl           => l_lot_serial_tbl,
                    x_lot_serial_val_tbl       => l_lot_serial_val_tbl,
                    x_action_request_tbl       => l_request_tbl);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'l_chr_poapi_ret_status :' || l_chr_poapi_ret_status);

                IF l_num_msg_cnt > 0
                THEN
                    FOR i IN 1 .. l_num_msg_cnt
                    LOOP
                        oe_msg_pub.get (
                            p_msg_index       => i,
                            p_encoded         => fnd_api.g_false,
                            p_data            => l_chr_msg_data,
                            p_msg_index_out   => l_num_msg_index_out);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error'
                            || l_num_msg_index_out
                            || ' Is:'
                            || l_chr_msg_data);
                    END LOOP;
                END IF;

                IF l_chr_poapi_ret_status = 'S'
                THEN
                    UPDATE xxdo_order_conv_stg
                       SET process_status   = 'PROCESSED'
                     WHERE     request_id = in_num_parent_request_id
                           AND worker_number = in_num_worker_number
                           AND header_id = hdr_rec.header_id;

                    UPDATE xxdo_order_conv_stg x
                       SET hold_in_target   = 'Y'
                     WHERE     request_id = in_num_parent_request_id
                           AND worker_number = in_num_worker_number
                           AND header_id = hdr_rec.header_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM oe_order_holds_all oh
                                     WHERE     oh.header_id = x.header_id
                                           AND oh.released_flag = 'N'
                                           AND oh.line_id IS NULL);

                    COMMIT;

                    UPDATE oe_order_lines_all
                       SET override_atp_date_code   = NULL
                     WHERE     header_id = hdr_rec.header_id
                           AND override_atp_date_code = 'Y';

                    COMMIT;
                ELSE
                    UPDATE xxdo_order_conv_stg
                       SET process_status = 'ERROR', error_message = SUBSTR (l_chr_msg_data, 1, 2000)
                     WHERE     request_id = in_num_parent_request_id
                           AND worker_number = in_num_worker_number
                           AND header_id = hdr_rec.header_id;
                END IF;

                COMMIT;
            END IF;
        END LOOP;

        /*  FOR c_order_lines_rec IN (select header_id,line_id,calculate_price_flag from apps.xxdo_order_conv_stg
                                                      where request_id = in_num_parent_request_id
                                                       AND worker_number = in_num_worker_number)
          LOOP

          UPDATE  OE_ORDER_LINES_ALL
             SET calculate_price_flag = c_order_lines_rec.calculate_price_flag
                    WHERE line_id=    c_order_lines_rec.line_id
                    AND header_id = c_order_lines_rec.header_id;
                    COMMIT;

          END LOOP; */

        BEGIN
            UPDATE OE_ORDER_LINES_ALL oel
               SET calculate_price_flag   =
                       (SELECT calculate_price_flag
                          FROM xxdo_order_conv_stg stg
                         WHERE     stg.line_id = oel.line_id
                               AND stg.request_id = in_num_parent_request_id
                               AND stg.worker_number = in_num_worker_number)
             WHERE line_id IN
                       (SELECT stg.line_id
                          FROM apps.xxdo_order_conv_stg stg
                         WHERE     request_id = in_num_parent_request_id
                               AND worker_number = in_num_worker_number);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Number of lines updated with calculated price flag :'
                || SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in updtaing order line '
                    || TO_CHAR (SYSDATE,
                                'DD-MON-YYYY HH24:MI:SS ' || SQLERRM));
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'End Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'process order  failed with unexpected error ::' || SQLERRM);
    END;

    PROCEDURE main (out_chr_errbuf OUT VARCHAR2, out_chr_retcode OUT NUMBER, p_source_organization IN VARCHAR2, p_target_organization IN VARCHAR2, p_so_number IN VARCHAR2, p_workers IN NUMBER, p_brand IN VARCHAR2, p_gender IN VARCHAR2, p_prod_group IN VARCHAR2
                    , p_mode IN VARCHAR2, p_request_id IN NUMBER)
    IS
        l_num_request_id        NUMBER := fnd_global.conc_request_id;
        l_num_user_id           NUMBER := fnd_global.user_id;
        l_num_old_wh            NUMBER;
        l_num_new_wh            NUMBER;
        l_num_req_id            NUMBER;
        l_num_batch_count       NUMBER;
        l_num_total_orders      NUMBER;
        l_num_workers           NUMBER := p_workers;

        lv_user_name            VARCHAR2 (50) := 'BATCH';
        lv_appl_id              NUMBER;
        lv_resp_id              NUMBER;
        lv_user_id              NUMBER;
        lv_responsbility_name   VARCHAR2 (200)
                                    := 'Order Management Super User';

        CURSOR order_cur IS
            SELECT DISTINCT worker_number
              FROM xxdo_order_conv_stg
             WHERE request_id = p_request_id;              --l_num_request_id;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Beginning of the program');

        BEGIN
            SELECT user_id
              INTO lv_user_id
              FROM apps.fnd_user
             WHERE user_name = lv_user_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_id   := NULL;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'User Name and User Id ' || lv_user_name || '-' || lv_user_id);

        BEGIN
            SELECT responsibility_id, application_id
              INTO lv_resp_id, lv_appl_id
              FROM apps.fnd_responsibility_vl
             WHERE responsibility_name = lv_responsbility_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_resp_id   := NULL;
                lv_appl_id   := NULL;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'Responsbility Name and Id'
            || lv_responsbility_name
            || '-'
            || lv_resp_id);

        fnd_global.apps_initialize (user_id        => lv_user_id,
                                    resp_id        => lv_resp_id,
                                    resp_appl_id   => lv_appl_id);

        IF p_mode = 'EXTRACT'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Source wh Code :' || p_source_organization);
            fnd_file.put_line (fnd_file.LOG,
                               'Target wh Code :' || p_target_organization);
            fnd_file.put_line (fnd_file.LOG, 'Sales Order:' || p_so_number);

            SELECT organization_id
              INTO l_num_old_wh
              FROM mtl_parameters
             WHERE organization_code = p_source_organization;

            SELECT organization_id
              INTO l_num_new_wh
              FROM mtl_parameters
             WHERE organization_code = p_target_organization;

            INSERT INTO xxdo_order_conv_stg (party_name, order_number, line_number, ordered_quantity, schedule_ship_date, creation_date, created_by, last_update_date, last_updated_by, request_id, process_status, old_warehouse_id, new_warehouse_id, header_id, line_id
                                             , calculate_price_flag)
                SELECT DISTINCT hp.party_name, ooh.order_number, ool.line_number,
                                ool.ordered_quantity, ool.schedule_ship_date, SYSDATE,
                                l_num_user_id, SYSDATE, l_num_user_id,
                                l_num_request_id, 'NEW', ool.ship_from_org_id,
                                l_num_new_wh, ooh.header_id, ool.line_id,
                                ool.calculate_price_flag
                  FROM wsh_delivery_details wdd, oe_order_lines_all ool, oe_order_headers_all ooh,
                       hz_cust_accounts_all hca, hz_parties hp, mtl_system_items_kfv msi,
                       mtl_categories_b mc, mtl_item_categories mic
                 WHERE     wdd.organization_id = l_num_old_wh
                       AND wdd.released_status IN ('R', 'B')
                       AND wdd.source_line_id = ool.line_id
                       AND ool.header_id = ooh.header_id
                       AND ool.ship_from_org_id = wdd.organization_id
                       AND ooh.sold_to_org_id = hca.cust_account_id
                       AND hca.party_id = hp.party_id
                       AND ool.open_flag = 'Y'
                       AND ooh.open_flag = 'Y'
                       AND ooh.order_number =
                           NVL (p_so_number, ooh.order_number)
                       AND mc.category_id = mic.category_id
                       AND msi.inventory_item_id = ool.inventory_item_id
                       AND wdd.organization_id = msi.organization_id
                       AND msi.organization_id = mic.organization_id
                       AND mic.category_set_id = 1
                       AND mic.inventory_item_id = msi.inventory_item_id
                       AND mc.segment1 = NVL (p_brand, mc.segment1)
                       AND mc.segment2 = NVL (p_gender, mc.segment2)
                       AND mc.segment3 = NVL (p_prod_group, mc.segment3)
                       AND l_num_old_wh <> l_num_new_wh;

            COMMIT;

            IF l_num_workers = 0
            THEN
                l_num_workers   := 1;
            END IF;

            UPDATE xxdo_order_conv_stg x
               SET hold_in_source   = 'Y'
             WHERE     request_id = l_num_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all oh
                             WHERE     oh.header_id = x.header_id
                                   AND oh.released_flag = 'N'
                                   AND oh.line_id IS NULL);

            COMMIT;

            SELECT COUNT (DISTINCT header_id)
              INTO l_num_total_orders
              FROM xxdo_order_conv_stg
             WHERE request_id = l_num_request_id;

            IF l_num_total_orders < l_num_workers
            THEN
                l_num_workers       := l_num_total_orders;
                l_num_batch_count   := 1;
            ELSE
                l_num_batch_count   :=
                    FLOOR (l_num_total_orders / l_num_workers);
            END IF;

            FOR i IN 1 .. l_num_workers
            LOOP
                UPDATE xxdo_order_conv_stg
                   SET worker_number   = i
                 WHERE     request_id = l_num_request_id
                       AND worker_number IS NULL
                       AND header_id IN
                               (SELECT y.header_id
                                  FROM (SELECT DISTINCT x.header_id
                                          FROM xxdo_order_conv_stg x
                                         WHERE     x.request_id =
                                                   l_num_request_id
                                               AND x.worker_number IS NULL) y
                                 WHERE ROWNUM <= l_num_batch_count);

                IF i = l_num_workers
                THEN
                    UPDATE xxdo_order_conv_stg
                       SET worker_number   = i
                     WHERE     request_id = l_num_request_id
                           AND worker_number IS NULL;
                END IF;

                COMMIT;
            END LOOP;
        END IF;

        IF p_mode = 'EXTRACT AND LOAD'
        THEN                               --and p_request_id is not null then
            fnd_file.put_line (fnd_file.LOG, 'order_cur');

            FOR order_rec IN order_cur
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'order_rec.worker_number' || order_rec.worker_number);
                l_num_req_id   :=
                    fnd_request.submit_request ('XXDO', 'XXDO_ORDER_CONV_CHILD', NULL, NULL, FALSE, order_rec.worker_number
                                                , p_request_id -- l_num_request_id
                                                              );
                COMMIT;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'unexpected error in main::' || SQLERRM);
    END;
END xxdo_order_conv_pkg;
/
