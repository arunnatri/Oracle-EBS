--
-- XXD_SCHEDULE_ORDERS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_schedule_orders_pkg
AS
    PROCEDURE xxd_schedule_ordders_prc (p_header_id IN xxd_btom_oeheader_tbltype, p_orgid IN NUMBER, p_scheddate IN DATE, p_schedule_type IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                        , p_resp_appl_id IN NUMBER, x_err_code OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    IS
        v_order_header_rec          oe_order_pub.header_rec_type;
        v_order_hdr_slcrtab         oe_order_pub.header_scredit_tbl_type;
        v_order_line_tab            oe_order_pub.line_tbl_type;
        v_order_header_val_rec      oe_order_pub.header_val_rec_type;
        v_order_header_adj_tbl      oe_order_pub.header_adj_tbl_type;
        v_order_hdr_adj_val_tbl     oe_order_pub.header_adj_val_tbl_type;
        v_order_hdr_pri_att_tbl     oe_order_pub.header_price_att_tbl_type;
        v_order_hdr_adj_att_tbl     oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_adj_asc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        v_order_hdr_scr_val_tbl     oe_order_pub.header_scredit_val_tbl_type;
        v_order_line_val_tbl        oe_order_pub.line_val_tbl_type;
        v_order_line_adj_tbl        oe_order_pub.line_adj_tbl_type;
        v_order_line_adj_val_tbl    oe_order_pub.line_adj_val_tbl_type;
        v_order_line_pri_att_tbl    oe_order_pub.line_price_att_tbl_type;
        v_order_line_adj_att_tbl    oe_order_pub.line_adj_att_tbl_type;
        v_order_line_adj_asc_tbl    oe_order_pub.line_adj_assoc_tbl_type;
        v_order_line_scredit_tbl    oe_order_pub.line_scredit_tbl_type;
        v_order_line_scr_val_tbl    oe_order_pub.line_scredit_val_tbl_type;
        v_order_lot_serial_tbl      oe_order_pub.lot_serial_tbl_type;
        v_order_lot_serl_val_tbl    oe_order_pub.lot_serial_val_tbl_type;
        v_order_request_tbl         oe_order_pub.request_tbl_type;
        lr_order_header_rec         oe_order_pub.header_rec_type;
        lr_order_hdr_slcrtab        oe_order_pub.header_scredit_tbl_type;
        lr_order_line_tab           oe_order_pub.line_tbl_type;
        lr_order_line_tab1          oe_order_pub.line_tbl_type;
        lr_line_rec_type            oe_order_pub.line_rec_type;
        lr_order_header_val_rec     oe_order_pub.header_val_rec_type;
        lr_order_header_adj_tbl     oe_order_pub.header_adj_tbl_type;
        lr_order_hdr_adj_val_tbl    oe_order_pub.header_adj_val_tbl_type;
        lr_order_hdr_pri_att_tbl    oe_order_pub.header_price_att_tbl_type;
        lr_order_hdr_adj_att_tbl    oe_order_pub.header_adj_att_tbl_type;
        lr_order_hdr_adj_asc_tbl    oe_order_pub.header_adj_assoc_tbl_type;
        lr_order_hdr_scr_val_tbl    oe_order_pub.header_scredit_val_tbl_type;
        lr_order_line_val_tbl       oe_order_pub.line_val_tbl_type;
        lr_order_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
        lr_order_line_adj_val_tbl   oe_order_pub.line_adj_val_tbl_type;
        lr_order_line_pri_att_tbl   oe_order_pub.line_price_att_tbl_type;
        lr_order_line_adj_att_tbl   oe_order_pub.line_adj_att_tbl_type;
        lr_order_line_adj_asc_tbl   oe_order_pub.line_adj_assoc_tbl_type;
        lr_order_line_scredit_tbl   oe_order_pub.line_scredit_tbl_type;
        lr_order_line_scr_val_tbl   oe_order_pub.line_scredit_val_tbl_type;
        lr_order_lot_serial_tbl     oe_order_pub.lot_serial_tbl_type;
        lr_order_lot_serl_val_tbl   oe_order_pub.lot_serial_val_tbl_type;
        lr_order_request_tbl        oe_order_pub.request_tbl_type;
        vreturnstatus               VARCHAR2 (30);
        vmsgcount                   NUMBER;
        vmsgdata                    VARCHAR2 (2000);
        l_count                     NUMBER;

        CURSOR lc_ord_lines_schedule (p_oe_header_id NUMBER)
        IS
            SELECT ool.header_id, ool.line_id, ool.schedule_ship_date,
                   ool.flow_status_code
              FROM oe_order_lines_all ool, oe_order_headers_all ooh
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.header_id = p_oe_header_id
                   AND ooh.org_id = p_orgid
                   AND ool.flow_status_code IN
                           ('ENTERED', 'AWAITING_SHIPPING', 'BOOKED');

        CURSOR lc_ord_lines_unschedule (p_oe_header_id NUMBER)
        IS
            SELECT ool.header_id, ool.line_id, ool.schedule_ship_date,
                   ool.flow_status_code
              FROM oe_order_lines_all ool, oe_order_headers_all ooh
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.header_id = p_oe_header_id
                   AND ooh.org_id = p_orgid
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.flow_status_code IN
                           ('ENTERED', 'AWAITING_SHIPPING', 'BOOKED');

        TYPE rec_c1 IS TABLE OF lc_ord_lines_schedule%ROWTYPE;

        lv_rec_c1                   rec_c1;
    BEGIN
        mo_global.init ('ONT');
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_appl_id);
        mo_global.set_policy_context ('S', p_orgid);
        vreturnstatus   := NULL;
        vmsgcount       := 0;
        vmsgdata        := NULL;
        l_count         := 0;

        l_count         := p_header_id.COUNT;


        FOR k IN 1 .. l_count
        LOOP
            DBMS_OUTPUT.put_line (
                'p_header_id (k).header_id - ' || p_header_id (k).header_id);

            IF p_schedule_type = 'SCHEDULE'
            THEN
                OPEN lc_ord_lines_schedule (p_header_id (k).header_id);

                FETCH lc_ord_lines_schedule BULK COLLECT INTO lv_rec_c1;

                CLOSE lc_ord_lines_schedule;
            ELSIF p_schedule_type = 'UNSCHEDULE'
            THEN
                OPEN lc_ord_lines_unschedule (p_header_id (k).header_id);

                FETCH lc_ord_lines_unschedule BULK COLLECT INTO lv_rec_c1;

                CLOSE lc_ord_lines_unschedule;
            END IF;

            --initilaize line table
            v_order_line_tab.DELETE;

            FOR i IN 1 .. lv_rec_c1.COUNT
            LOOP
                v_order_header_rec                  :=
                    oe_header_util.query_row (lv_rec_c1 (i).header_id);
                v_order_header_rec.operation        := oe_globals.g_opr_update;
                v_order_header_rec.header_id        := lv_rec_c1 (i).header_id;
                v_order_line_tab (i)                :=
                    oe_line_util.query_row (lv_rec_c1 (i).line_id);
                v_order_line_tab (i).operation      := oe_globals.g_opr_update;
                v_order_line_tab (i).line_id        := lv_rec_c1 (i).line_id;
                v_order_line_tab (i).request_date   := p_scheddate;
                --v_order_line_tab (i).schedule_action_code := 'SCHEDULE';
                v_order_line_tab (i).schedule_action_code   :=
                    p_schedule_type;
            END LOOP;

            IF v_order_line_tab.COUNT > 0
            THEN
                DBMS_OUTPUT.put_line ('Calling the API');
                oe_order_pub.process_order (
                    p_api_version_number       => 1.0,
                    p_org_id                   => p_orgid,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    p_header_rec               => v_order_header_rec,
                    p_header_val_rec           => v_order_header_val_rec,
                    p_header_scredit_tbl       => v_order_hdr_slcrtab,
                    p_line_tbl                 => v_order_line_tab,
                    p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                    p_action_request_tbl       => v_order_request_tbl,
                    x_return_status            => vreturnstatus,
                    x_msg_count                => vmsgcount,
                    x_msg_data                 => vmsgdata,
                    x_header_rec               => lr_order_header_rec,
                    x_header_val_rec           => lr_order_header_val_rec,
                    x_header_adj_tbl           => lr_order_header_adj_tbl,
                    x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                    x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                    x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                    x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                    x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                    x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                    x_line_tbl                 => lr_order_line_tab,
                    x_line_val_tbl             => lr_order_line_val_tbl,
                    x_line_adj_tbl             => lr_order_line_adj_tbl,
                    x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                    x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                    x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                    x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                    x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                    x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                    x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                    x_action_request_tbl       => lr_order_request_tbl);
                DBMS_OUTPUT.put_line ('Completion of API');

                IF vreturnstatus = fnd_api.g_ret_sts_success
                THEN
                    IF p_schedule_type = 'SCHEDULE'
                    THEN
                        x_err_msg   := 'Scheduling order is success.';
                    ELSIF p_schedule_type = 'UNSCHEDULE'
                    THEN
                        x_err_msg   := 'Unscheduling order is success.';
                    END IF;

                    x_err_code   := 'S';
                    COMMIT;
                ELSE
                    ROLLBACK;
                    x_err_code   := 'E';

                    IF p_schedule_type = 'SCHEDULE'
                    THEN
                        x_err_msg   := 'Error while scheduling order - ';
                    ELSIF p_schedule_type = 'UNSCHEDULE'
                    THEN
                        x_err_msg   := 'Error while unscheduling order - ';
                    END IF;

                    FOR j IN 1 .. vmsgcount
                    LOOP
                        vmsgdata    :=
                            oe_msg_pub.get (p_msg_index => j, p_encoded => 'F');
                        x_err_msg   := x_err_msg || vmsgdata;
                    END LOOP;
                END IF;
            ELSE
                IF p_schedule_type = 'SCHEDULE'
                THEN
                    x_err_msg   :=
                        'There are no eligible order lines to schedule.';
                ELSIF p_schedule_type = 'UNSCHEDULE'
                THEN
                    x_err_msg   :=
                        'There are no eligible order lines to unschedule.';
                END IF;

                x_err_code   := 'E';
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_code   := 'E';
            x_err_msg    := SQLERRM;
    END;

    PROCEDURE xxd_schedule_ordder_lines_prc (p_orgid IN NUMBER, p_line_id IN xxd_btom_oeline_tbltype, p_scheddate IN DATE, p_schedule_type IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                             , p_resp_appl_id IN NUMBER, x_err_code OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    IS
        v_order_header_rec          oe_order_pub.header_rec_type;
        v_order_hdr_slcrtab         oe_order_pub.header_scredit_tbl_type;
        v_order_line_tab            oe_order_pub.line_tbl_type;
        v_order_header_val_rec      oe_order_pub.header_val_rec_type;
        v_order_header_adj_tbl      oe_order_pub.header_adj_tbl_type;
        v_order_hdr_adj_val_tbl     oe_order_pub.header_adj_val_tbl_type;
        v_order_hdr_pri_att_tbl     oe_order_pub.header_price_att_tbl_type;
        v_order_hdr_adj_att_tbl     oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_adj_asc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        v_order_hdr_scr_val_tbl     oe_order_pub.header_scredit_val_tbl_type;
        v_order_line_val_tbl        oe_order_pub.line_val_tbl_type;
        v_order_line_adj_tbl        oe_order_pub.line_adj_tbl_type;
        v_order_line_adj_val_tbl    oe_order_pub.line_adj_val_tbl_type;
        v_order_line_pri_att_tbl    oe_order_pub.line_price_att_tbl_type;
        v_order_line_adj_att_tbl    oe_order_pub.line_adj_att_tbl_type;
        v_order_line_adj_asc_tbl    oe_order_pub.line_adj_assoc_tbl_type;
        v_order_line_scredit_tbl    oe_order_pub.line_scredit_tbl_type;
        v_order_line_scr_val_tbl    oe_order_pub.line_scredit_val_tbl_type;
        v_order_lot_serial_tbl      oe_order_pub.lot_serial_tbl_type;
        v_order_lot_serl_val_tbl    oe_order_pub.lot_serial_val_tbl_type;
        v_order_request_tbl         oe_order_pub.request_tbl_type;
        lr_order_header_rec         oe_order_pub.header_rec_type;
        lr_order_hdr_slcrtab        oe_order_pub.header_scredit_tbl_type;
        lr_order_line_tab           oe_order_pub.line_tbl_type;
        lr_order_line_tab1          oe_order_pub.line_tbl_type;
        lr_line_rec_type            oe_order_pub.line_rec_type;
        lr_order_header_val_rec     oe_order_pub.header_val_rec_type;
        lr_order_header_adj_tbl     oe_order_pub.header_adj_tbl_type;
        lr_order_hdr_adj_val_tbl    oe_order_pub.header_adj_val_tbl_type;
        lr_order_hdr_pri_att_tbl    oe_order_pub.header_price_att_tbl_type;
        lr_order_hdr_adj_att_tbl    oe_order_pub.header_adj_att_tbl_type;
        lr_order_hdr_adj_asc_tbl    oe_order_pub.header_adj_assoc_tbl_type;
        lr_order_hdr_scr_val_tbl    oe_order_pub.header_scredit_val_tbl_type;
        lr_order_line_val_tbl       oe_order_pub.line_val_tbl_type;
        lr_order_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
        lr_order_line_adj_val_tbl   oe_order_pub.line_adj_val_tbl_type;
        lr_order_line_pri_att_tbl   oe_order_pub.line_price_att_tbl_type;
        lr_order_line_adj_att_tbl   oe_order_pub.line_adj_att_tbl_type;
        lr_order_line_adj_asc_tbl   oe_order_pub.line_adj_assoc_tbl_type;
        lr_order_line_scredit_tbl   oe_order_pub.line_scredit_tbl_type;
        lr_order_line_scr_val_tbl   oe_order_pub.line_scredit_val_tbl_type;
        lr_order_lot_serial_tbl     oe_order_pub.lot_serial_tbl_type;
        lr_order_lot_serl_val_tbl   oe_order_pub.lot_serial_val_tbl_type;
        lr_order_request_tbl        oe_order_pub.request_tbl_type;
        vreturnstatus               VARCHAR2 (30);
        vmsgcount                   NUMBER;
        vmsgdata                    VARCHAR2 (2000);
        l_count                     NUMBER;
        i                           NUMBER;

        CURSOR lc_ord_lines_schedule (p_oe_line_id NUMBER)
        IS
            SELECT ool.header_id, ool.line_id, ool.schedule_ship_date,
                   ool.flow_status_code, ool.request_date
              FROM oe_order_lines_all ool, oe_order_headers_all ooh
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_id = p_oe_line_id
                   AND ool.org_id = p_orgid
                   AND ool.flow_status_code IN
                           ('ENTERED', 'AWAITING_SHIPPING', 'BOOKED');

        CURSOR lc_ord_lines_unschedule (p_oe_line_id NUMBER)
        IS
            SELECT ool.header_id, ool.line_id, ool.schedule_ship_date,
                   ool.flow_status_code, ool.request_date
              FROM oe_order_lines_all ool, oe_order_headers_all ooh
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_id = p_oe_line_id
                   AND ool.org_id = p_orgid
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.flow_status_code IN
                           ('ENTERED', 'AWAITING_SHIPPING', 'BOOKED');

        TYPE rec_c1 IS TABLE OF lc_ord_lines_schedule%ROWTYPE;

        lv_rec_c1                   rec_c1;
    BEGIN
        DBMS_OUTPUT.put_line ('Starting of script');
        mo_global.init ('ONT');
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_appl_id);
        mo_global.set_policy_context ('S', p_orgid);
        vreturnstatus   := NULL;
        vmsgcount       := 0;
        vmsgdata        := NULL;
        l_count         := 0;
        i               := 0;
        l_count         := p_line_id.COUNT;
        DBMS_OUTPUT.put_line ('THE COUNT OF lINES IS : ' || l_count);

        FOR k IN 1 .. l_count
        LOOP
            IF p_schedule_type = 'SCHEDULE'
            THEN
                FOR lr_ord_lines
                    IN lc_ord_lines_schedule (p_line_id (k).line_id)
                LOOP
                    i                              := i + 1;
                    v_order_line_tab (i)           :=
                        oe_line_util.query_row (lr_ord_lines.line_id);
                    v_order_line_tab (i).operation   :=
                        oe_globals.g_opr_update;
                    v_order_line_tab (i).line_id   := lr_ord_lines.line_id;
                    --v_order_line_tab (i).request_date := p_scheddate;
                    v_order_line_tab (i).request_date   :=
                        lr_ord_lines.request_date;
                    --v_order_line_tab (i).schedule_action_code := 'SCHEDULE';
                    v_order_line_tab (i).schedule_action_code   :=
                        p_schedule_type;
                END LOOP;
            ELSIF p_schedule_type = 'UNSCHEDULE'
            THEN
                FOR lr_ord_lines1
                    IN lc_ord_lines_unschedule (p_line_id (k).line_id)
                LOOP
                    i                              := i + 1;
                    v_order_line_tab (i)           :=
                        oe_line_util.query_row (lr_ord_lines1.line_id);
                    v_order_line_tab (i).operation   :=
                        oe_globals.g_opr_update;
                    v_order_line_tab (i).line_id   := lr_ord_lines1.line_id;
                    --v_order_line_tab (i).request_date := p_scheddate;
                    v_order_line_tab (i).request_date   :=
                        lr_ord_lines1.request_date;
                    --v_order_line_tab (i).schedule_action_code := 'SCHEDULE';
                    v_order_line_tab (i).schedule_action_code   :=
                        p_schedule_type;
                END LOOP;
            END IF;
        END LOOP;

        IF v_order_line_tab.COUNT > 0
        THEN
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_org_id                   => p_orgid,
                p_init_msg_list            => fnd_api.g_true,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_true,
                p_header_rec               => v_order_header_rec,
                p_header_val_rec           => v_order_header_val_rec,
                p_header_scredit_tbl       => v_order_hdr_slcrtab,
                p_line_tbl                 => v_order_line_tab,
                p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                p_action_request_tbl       => v_order_request_tbl,
                x_return_status            => vreturnstatus,
                x_msg_count                => vmsgcount,
                x_msg_data                 => vmsgdata,
                x_header_rec               => lr_order_header_rec,
                x_header_val_rec           => lr_order_header_val_rec,
                x_header_adj_tbl           => lr_order_header_adj_tbl,
                x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                x_line_tbl                 => lr_order_line_tab,
                x_line_val_tbl             => lr_order_line_val_tbl,
                x_line_adj_tbl             => lr_order_line_adj_tbl,
                x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                x_action_request_tbl       => lr_order_request_tbl);
            DBMS_OUTPUT.put_line ('Completion of API');

            IF vreturnstatus = fnd_api.g_ret_sts_success
            THEN
                IF p_schedule_type = 'SCHEDULE'
                THEN
                    x_err_msg   := 'Scheduling lines are successful.';
                ELSIF p_schedule_type = 'UNSCHEDULE'
                THEN
                    x_err_msg   := 'Unscheduling lines are successful.';
                END IF;

                x_err_code   := 'S';
                COMMIT;
            ELSE
                ROLLBACK;
                x_err_code   := 'E';

                IF p_schedule_type = 'SCHEDULE'
                THEN
                    x_err_msg   := 'Error while scheduling line - ';
                ELSIF p_schedule_type = 'UNSCHEDULE'
                THEN
                    x_err_msg   := 'Error while unscheduling line - ';
                END IF;

                FOR j IN 1 .. vmsgcount
                LOOP
                    vmsgdata    :=
                        oe_msg_pub.get (p_msg_index => j, p_encoded => 'F');
                    x_err_msg   := x_err_msg || vmsgdata;
                END LOOP;
            END IF;
        ELSE
            IF p_schedule_type = 'SCHEDULE'
            THEN
                x_err_msg   :=
                    'There are no eligible order lines to schedule.';
            ELSIF p_schedule_type = 'UNSCHEDULE'
            THEN
                x_err_msg   :=
                    'There are no eligible order lines to unschedule.';
            END IF;

            x_err_code   := 'E';
        END IF;
    --END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_code   := 'E';
            x_err_msg    := SQLERRM;
            DBMS_OUTPUT.put_line (
                'Exception in scheduling the orders' || x_err_msg);
    END;
END xxd_schedule_orders_pkg;
/
