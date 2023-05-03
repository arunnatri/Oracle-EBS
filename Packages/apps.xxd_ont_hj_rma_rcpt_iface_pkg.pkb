--
-- XXD_ONT_HJ_RMA_RCPT_IFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_HJ_RMA_RCPT_IFACE_PKG"
AS
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxd_ont_hj_rma_rcpt_iface_pkg
    --
    -- Description  :  This is package  for WMS to EBS Return Receiving Inbound Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date           Author                 Version     Description
    -- ------------   -----------------      -------     --------------------------------
    -- 20-Jan-2020    GJensen                1.0         Created
    -- 20-Feb-2023    Jayarajan A K          1.2         US1 to US6 Org Move changes (lines can have multiple whse)
    -- ***************************************************************************
    PROCEDURE msg (in_chr_message VARCHAR2)
    IS
    BEGIN
        IF gn_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_chr_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected Error: ' || SQLERRM);
    END;

    FUNCTION get_db_instance
        RETURN VARCHAR2
    IS
        lv_environment   VARCHAR2 (30);
        lv_short_name    VARCHAR2 (30);
    -- Get the instance name from DBA view
    BEGIN
        SELECT NAME INTO lv_environment FROM v$database;

        BEGIN
            --Get translation from lookup
            SELECT description
              INTO lv_short_name
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_EBS_HJ_INSTANCE_MAP'
                   AND language = 'US'
                   AND meaning = lv_environment;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_short_name   := lv_environment;
        END;

        RETURN lv_short_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN '-1';
    END;

    PROCEDURE get_resp_details (p_org_id IN NUMBER, p_module_name IN VARCHAR2, p_resp_id OUT NUMBER
                                , p_resp_appl_id OUT NUMBER)
    IS
        lv_mo_resp_id           NUMBER;
        lv_mo_resp_appl_id      NUMBER;
        lv_const_om_resp_name   VARCHAR2 (200)
                                    := 'Order Management Super User - ';
        lv_const_po_resp_name   VARCHAR2 (200) := 'Purchasing Super User - ';
        lv_const_ou_name        VARCHAR2 (200);
        lv_var_ou_name          VARCHAR2 (200);
    BEGIN
        IF p_module_name = 'ONT'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
                       AND hou.organization_id = p_org_id
                       AND flv.description = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;
            END;
        ELSIF p_module_name = 'PO'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
                       AND hou.organization_id = p_org_id
                       AND meaning = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;

                    BEGIN
                        SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                          INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                          FROM fnd_responsibility_vl resp
                         WHERE responsibility_name =
                               fnd_profile.VALUE ('XXDO_PO_RESP_NAME');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_mo_resp_id           := NULL;
                            lv_mo_resp_appl_id      := NULL;
                            lv_const_po_resp_name   := NULL;
                    END;
            END;
        END IF;

        msg (
               'Responsbility Application Id '
            || lv_mo_resp_appl_id
            || '-'
            || lv_mo_resp_id);

        msg (
               'Responsbility Details '
            || p_module_name
            || '-'
            || lv_const_po_resp_name);
        p_resp_id        := lv_mo_resp_id;
        p_resp_appl_id   := lv_mo_resp_appl_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END get_resp_details;

    PROCEDURE release_rma_hold (p_retcode         OUT NUMBER,
                                p_errbuf          OUT VARCHAR2,
                                p_rma_number   IN     NUMBER)
    IS
        CURSOR c_rma_hold IS
              SELECT DISTINCT oh.header_id
                FROM apps.oe_order_holds_all ooha, apps.oe_hold_sources_all ohsa, apps.oe_hold_definitions ohd,
                     apps.oe_order_lines_all ol, apps.oe_order_headers_all oh, apps.hz_cust_accounts hca,
                     apps.hz_parties hp
               WHERE     ooha.hold_source_id = ohsa.hold_source_id
                     AND ohsa.hold_id = ohd.hold_id
                     AND oh.sold_to_org_id = hca.cust_account_id
                     AND hca.party_id = hp.party_id
                     AND oh.order_number = p_rma_number
                     AND ooha.line_id = ol.line_id
                     AND ooha.released_flag = 'N'
                     AND oh.header_id = ooha.header_id
            GROUP BY hp.party_name, oh.header_id;

        CURSOR c_rma_lines (p_header_id NUMBER)
        IS
              SELECT DECODE (hold_srcs.hold_entity_code,  'S', 'Ship-To',  'B', 'Bill-To',  'I', 'Item',  'W', 'Warehouse',  'O', 'Order',  'C', 'Customer',  hold_srcs.hold_entity_code) AS hold_type, hold_defs.NAME AS hold_name, hold_defs.type_code,
                     holds.header_id, holds.org_id hold_org_id, holds.line_id,
                     ol.ordered_quantity, holds.ORDER_HOLD_ID, hold_srcs.hold_id
                FROM oe_hold_definitions hold_defs, oe_hold_sources_all hold_srcs, oe_order_holds_all holds,
                     oe_order_lines_all ol
               WHERE     hold_srcs.hold_source_id = holds.hold_source_id
                     AND hold_defs.hold_id = hold_srcs.hold_id
                     AND holds.released_flag = 'N'
                     AND ol.line_id = holds.line_id
                     AND holds.header_id = p_header_id
            ORDER BY ol.ordered_quantity ASC;

        l_order_tbl            OE_HOLDS_PVT.order_tbl_type;
        x_return_status        VARCHAR2 (30);
        x_msg_data             VARCHAR2 (256);
        x_msg_count            NUMBER;
        x_msg_index_out        NUMBER;
        in_chr_reason          VARCHAR2 (50) := 'CS-REL';
        ln_org_id              NUMBER;
        l_num_resp_id          NUMBER;
        l_num_resp_appl_id     NUMBER;
        l_hold_release_rec     oe_holds_pvt.hold_release_rec_type;
        l_hold_source_rec      oe_holds_pvt.hold_source_rec_type;
        p_io_hold_source_tbl   OE_HOLDS_PVT.order_tbl_type;
    BEGIN
        DBMS_OUTPUT.put_line ('release_rma_hold - Enter.' || p_rma_number);

        FOR r_rma_hold IN c_rma_hold
        LOOP
            SELECT org_id
              INTO ln_org_id
              FROM apps.oe_order_headers_all a
             WHERE header_id = r_rma_hold.header_id;

            get_resp_details (ln_org_id, 'ONT', l_num_resp_id,
                              l_num_resp_appl_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Responsibility ID '
                || l_num_resp_id
                || ' Resp Application ID '
                || l_num_resp_appl_id);
            apps.fnd_global.apps_initialize (
                user_id        => fnd_profile.VALUE ('USER_ID'),
                resp_id        => l_num_resp_id,
                resp_appl_id   => l_num_resp_appl_id);
            mo_global.init ('ONT');

            --  mo_global.set_policy_context('S',fnd_profile.value('ORG_ID'));
            FOR holds_rec IN c_rma_lines (r_rma_hold.header_id)
            LOOP
                --  l_cnt := l_cnt + 1;
                l_order_tbl (1).header_id   := holds_rec.header_id;
                l_order_tbl (1).line_id     := holds_rec.line_id;
                fnd_file.put_line (fnd_file.LOG,
                                   'Before calling HOLD RELEASE API...');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Qty for releasing HOLD : ' || holds_rec.ordered_quantity);
                Oe_Holds_Pub.Release_Holds (
                    p_api_version           => 1.0,
                    p_init_msg_list         => Fnd_Api.G_FALSE,
                    p_commit                => Fnd_Api.G_FALSE,
                    p_validation_level      => Fnd_Api.G_VALID_LEVEL_FULL,
                    p_order_tbl             => l_order_tbl,
                    p_hold_id               => holds_rec.hold_id,
                    p_release_reason_code   => in_chr_reason,
                    p_release_comment       =>
                        'Release Date ' || TRUNC (SYSDATE),
                    x_return_status         => x_return_status,
                    x_msg_count             => x_msg_count,
                    x_msg_data              => x_msg_data);

                IF x_return_status != 'S'
                THEN
                    FOR i IN 1 .. x_msg_count
                    LOOP
                        OE_MSG_PUB.get (p_msg_index => i, p_encoded => 'F', p_data => x_msg_data
                                        , p_msg_index_out => x_msg_index_out);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Failure msg' || x_msg_data);
                    END LOOP;

                    fnd_file.put_line (fnd_file.LOG,
                                       'Failure msg' || x_msg_data);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           '===> ********** Error ******* Hold was not Released - '
                        || x_msg_data);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Msg data is ' || x_msg_data);
                    ROLLBACK;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Hold Released for Header ID : '
                        || l_order_tbl (1).header_id
                        || ' Line ID : '
                        || l_order_tbl (1).line_id);
                    COMMIT;
                END IF;
            END LOOP;
        END LOOP;

        DBMS_OUTPUT.put_line ('release_rma_hold - Exit.' || p_rma_number);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
    END;

    PROCEDURE update_return_line (p_header_id IN NUMBER, p_line_id IN NUMBER, p_cust_ret_reason VARCHAR2
                                  , p_org_id NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2)
    IS
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        lv_line_tbl                    oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
                                           := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;
        lv_next_msg                    NUMBER;
        lv_header_id                   NUMBER;
        lv_ship_from_org_id            NUMBER;
        lv_inventory_item_id           NUMBER;
        lv_line_id                     NUMBER;
        lv_order_tbl                   oe_holds_pvt.order_tbl_type;
        lv_retcode                     NUMBER;
        lv_error_buf                   VARCHAR (1000);
        lv_hold_exists                 NUMBER;
        j                              NUMBER;
        lv_num                         NUMBER := 1;
        lv_hold_index                  NUMBER := 0;
        lv_mo_resp_id                  NUMBER;
        lv_mo_resp_appl_id             NUMBER;
    BEGIN
        p_error_message                     := NULL;
        p_return_status                     := 0;            -- g_ret_success;
        get_resp_details (p_org_id, 'ONT', lv_mo_resp_id,
                          lv_mo_resp_appl_id);


        apps.fnd_global.apps_initialize (user_id        => gn_user_id,
                                         resp_id        => lv_mo_resp_id,
                                         resp_appl_id   => lv_mo_resp_appl_id);
        mo_global.init ('ONT');


        /***************************
        apps.fnd_global.apps_initialize (user_id        => 2531,
                                         resp_id        => 50744,
                                         resp_appl_id   => 660);
        mo_global.init ('ONT');
        MO_GLOBAL.SET_POLICY_CONTEXT ('S', 95);
        msg ('CRP3..');
        /****************************/
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        x_debug_file                        := oe_debug_pub.set_debug_mode ('FILE');
        oe_debug_pub.setdebuglevel (5);
        msg ('Begining of Process Order API for updating Line');
        -- l_line_tbl_index := 1;
        l_line_tbl (1)                      := oe_order_pub.g_miss_line_rec;
        l_line_tbl (1).header_id            := p_header_id;
        l_line_tbl (1).line_id              := p_line_id;
        l_line_tbl (1).return_reason_code   := p_cust_ret_reason;
        l_line_tbl (1).operation            := oe_globals.g_opr_update;
        msg ('Calling process order API to update line');
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => l_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => lv_line_tbl,
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
            x_action_request_tbl       => l_action_request_tbl);
        COMMIT;
        -- Retrieve messages
        msg ('Order Line msg' || l_msg_count);

        FOR k IN 1 .. l_msg_count
        LOOP
            oe_msg_pub.get (p_msg_index => k, p_encoded => fnd_api.g_false, p_data => l_msg_data
                            , p_msg_index_out => lv_next_msg);
            fnd_file.put_line (fnd_file.LOG, 'message is:' || l_msg_data);
        END LOOP;

        -- Check the return status
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            msg ('Process Order Sucess');
            msg ('Line update with WMS return reason');
            COMMIT;
        ELSE
            msg (
                'Api failing with error for updating Line' || l_return_status);

            UPDATE xxdo_ont_rma_line_stg
               SET process_status = 'ERROR', result_code = 'E', error_message = 'API Failed while updating Line return reason'
             WHERE     request_id = gn_request_id
                   AND process_status = 'INPROCESS'
                   AND line_number = p_line_id;

            COMMIT;
        -- RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error occurred. ' || SQLERRM);
    END;

    PROCEDURE rcv_headers_insert (p_shipment_num VARCHAR2, p_receipt_date DATE, p_organization_id NUMBER, p_group_id NUMBER, p_customer_id NUMBER:= NULL, p_vendor_id NUMBER:= NULL, p_org_id NUMBER, p_header_interface_id OUT NUMBER, p_return_status OUT NUMBER
                                  , p_error_message OUT VARCHAR2)
    IS
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;

        SELECT rcv_headers_interface_s.NEXTVAL
          INTO p_header_interface_id
          FROM DUAL;


        ---g_ret_success;

        INSERT INTO rcv_headers_interface (header_interface_id, GROUP_ID, processing_status_code, receipt_source_code, transaction_type, auto_transact_code, last_update_date, last_updated_by, last_update_login, creation_date, created_by, shipment_num, ship_to_organization_id, expected_receipt_date, -- employee_id,  ---CRP Issue
                                                                                                                                                                                                                                                                                                            validation_flag
                                           , customer_id, vendor_id, ORG_ID)
            (SELECT p_header_interface_id                --header_interface_id
                                         , p_group_id               --group_id
                                                     , 'PENDING' --processing_status_code
                                                                , 'CUSTOMER' --receipt_source_code
                                                                            , 'NEW' --transaction_type
                                                                                   , 'DELIVER' --auto_transact_code
                                                                                              , SYSDATE --last_update_date
                                                                                                       , fnd_global.user_id --last_update_by
                                                                                                                           , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                  , SYSDATE --creation_date
                                                                                                                                                           , fnd_global.user_id --created_by
                                                                                                                                                                               , p_shipment_num --shipment_num
                                                                                                                                                                                               , p_organization_id --ship_to_organization_id
                                                                                                                                                                                                                  , p_receipt_date --expected_receipt_date
                                                                                                                                                                                                                                  , --      p_employee_id                                  --employee_id   ---CRP Issue

                                                                                                                                                                                                                                    'Y' --validation_flag
                                                                                                                                                                                                                                       , p_customer_id, p_vendor_id, p_org_id FROM DUAL);

        COMMIT;

        p_return_status   := 0;                               --g_ret_success;
        msg ('Header Record inserted-' || p_shipment_num);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Header Record inserted-Error occured' || p_shipment_num);
            p_return_status   := 2;
            p_error_message   := SQLERRM;
    END;

    PROCEDURE rcv_lines_insert (p_org_id NUMBER, p_receipt_source_code VARCHAR2, p_source_document_code VARCHAR2, p_group_id NUMBER, p_location_id NUMBER, p_subinventory VARCHAR2, p_header_interface_id NUMBER, p_shipment_num VARCHAR2, p_receipt_date DATE, p_item_id NUMBER, --   p_employee_id                         NUMBER,  ---CRP Issue
                                                                                                                                                                                                                                                                                  p_uom VARCHAR2, p_quantity NUMBER, p_return_status OUT NUMBER, p_error_message OUT VARCHAR2, p_shipment_header_id NUMBER:= NULL, p_shipment_line_id NUMBER:= NULL, p_ship_to_location_id NUMBER:= NULL, p_from_organization_id NUMBER:= NULL, p_to_organization_id NUMBER:= NULL, p_requisition_line_id NUMBER:= NULL, p_requisition_distribution_id NUMBER:= NULL, p_deliver_to_person_id NUMBER:= NULL, p_deliver_to_location_id NUMBER:= NULL, p_locator_id NUMBER:= NULL, p_oe_order_header_id NUMBER:= NULL, p_oe_order_line_id NUMBER:= NULL, p_customer_id NUMBER:= NULL
                                , p_customer_site_id NUMBER:= NULL, p_vendor_id NUMBER:= NULL, p_parent_transaction_id NUMBER:= NULL)
    IS
        lv_cnt        NUMBER;
        lv_trx_type   VARCHAR2 (20);
    BEGIN
        SELECT COUNT (1)
          INTO lv_cnt
          FROM apps.rcv_shipment_lines rsl, apps.po_line_locations_all plla, apps.fnd_lookup_values flv
         WHERE     rsl.shipment_line_id = p_shipment_line_id
               AND plla.line_location_id = rsl.po_line_location_id
               AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
               AND flv.LANGUAGE = 'US'
               AND flv.lookup_code = TO_CHAR (plla.receiving_routing_id)
               AND flv.view_application_id = 0
               AND flv.security_group_id = 0
               AND flv.meaning = 'Standard Receipt';

        IF lv_cnt = 1
        THEN
            lv_trx_type   := 'DELIVER';
        ELSE
            lv_trx_type   := 'RECEIVE';
        END IF;

        INSERT INTO rcv_transactions_interface (interface_transaction_id,
                                                GROUP_ID,
                                                org_id,
                                                last_update_date,
                                                last_updated_by,
                                                creation_date,
                                                created_by,
                                                last_update_login,
                                                transaction_type,
                                                transaction_date,
                                                processing_status_code,
                                                processing_mode_code,
                                                transaction_status_code,
                                                quantity,
                                                unit_of_measure,
                                                interface_source_code,
                                                item_id,
                                                -- employee_id,  ---CRP Issue
                                                auto_transact_code,
                                                shipment_header_id,
                                                shipment_line_id,
                                                ship_to_location_id,
                                                receipt_source_code,
                                                to_organization_id,
                                                source_document_code,
                                                requisition_line_id,
                                                req_distribution_id,
                                                destination_type_code,
                                                deliver_to_person_id,
                                                location_id,
                                                deliver_to_location_id,
                                                subinventory,
                                                shipment_num,
                                                expected_receipt_date,
                                                header_interface_id,
                                                validation_flag,
                                                locator_id,
                                                oe_order_header_id,
                                                oe_order_line_id,
                                                customer_id,
                                                customer_site_id,
                                                vendor_id,
                                                parent_transaction_id)
            (SELECT rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                        , p_group_id --group_id
                                                                    , p_org_id, SYSDATE --last_update_date
                                                                                       , fnd_global.user_id --last_updated_by
                                                                                                           , SYSDATE --creation_date
                                                                                                                    , apps.fnd_global.user_id --created_by
                                                                                                                                             , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                    , 'RECEIVE', -- lv_trx_type                                --transaction_type
                                                                                                                                                                                 /* 9/15 if the receipt date is in old month, default it to sysdate */
                                                                                                                                                                                 --p_receipt_date                             --transaction_date
                                                                                                                                                                                 DECODE (TO_CHAR (p_receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), p_receipt_date, SYSDATE), --PAST_RECEIPT
                                                                                                                                                                                                                                                                                    'PENDING' --processing_status_code
                                                                                                                                                                                                                                                                                             , 'BATCH' --processing_mode_code
                                                                                                                                                                                                                                                                                                      , 'PENDING' --transaction_status_code
                                                                                                                                                                                                                                                                                                                 , p_quantity --quantity
                                                                                                                                                                                                                                                                                                                             , '', --p_uom                                       --unit_of_measure
                                                                                                                                                                                                                                                                                                                                   'RCV' --interface_source_code
                                                                                                                                                                                                                                                                                                                                        , p_item_id --item_id
                                                                                                                                                                                                                                                                                                                                                   , --    p_employee_id                                   --employee_id    ---CRP Issue

                                                                                                                                                                                                                                                                                                                                                     'DELIVER' --auto_transact_code
                                                                                                                                                                                                                                                                                                                                                              , p_shipment_header_id --shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                                    , p_shipment_line_id --shipment_line_id
                                                                                                                                                                                                                                                                                                                                                                                                        , p_ship_to_location_id --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                               , p_receipt_source_code --receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                      , p_to_organization_id --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , p_source_document_code --source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , p_requisition_line_id --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , p_requisition_distribution_id --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , 'INVENTORY' --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , p_deliver_to_person_id --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , p_location_id --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , p_deliver_to_location_id --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_subinventory --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_shipment_num --shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_receipt_date --expected_receipt_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , p_header_interface_id --header_interface_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , 'Y' --validation_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , p_locator_id, p_oe_order_header_id, p_oe_order_line_id, p_customer_id, p_customer_site_id, p_vendor_id, p_parent_transaction_id FROM DUAL);

        COMMIT;


        p_return_status   := 0;                               --g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;                           --2 g_ret_error;
            p_error_message   := SQLERRM;
    END;

    PROCEDURE receive_return_tbl (p_group_id           OUT NUMBER,
                                  p_return_status      OUT NUMBER,
                                  p_error_message      OUT VARCHAR2,
                                  p_wh_code         IN     VARCHAR2,    --v1.2
                                  p_rma_number      IN     NUMBER)
    IS
        CURSOR c_hdr_cur IS
              SELECT rma_number, MAX (rma_receipt_date) rma_receipt_date, header_id
                FROM xxdo_ont_rma_hdr_stg hdr
               WHERE     process_status = 'INPROCESS'
                     AND result_code = 'P'
                     AND request_id = gn_request_id
                     AND rma_number = p_rma_number
                     AND wh_id = p_wh_code                              --v1.2
                     AND EXISTS
                             (SELECT NULL
                                FROM xxdo_ont_rma_line_stg line
                               WHERE     line.process_status = 'INPROCESS'
                                     AND line.result_code = 'P'
                                     AND line.type1 = 'PLANNED'
                                     AND hdr.receipt_header_seq_id =
                                         line.receipt_header_seq_id)
            GROUP BY rma_number, header_id;


        CURSOR c_det_cur IS
            SELECT org_id, ship_from_org_id, host_subinventory,
                   inventory_item_id, qty, type1,
                   line_number, cust_return_reason, receipt_line_seq_id
              FROM xxdo_ont_rma_line_stg
             WHERE     process_status = 'INPROCESS'
                   AND result_code = 'P'
                   AND type1 = 'PLANNED'
                   AND request_id = gn_request_id
                   AND wh_id = p_wh_code                                --v1.2
                   AND rma_number = p_rma_number;

        x_ret                    NUMBER;
        x_msg_cnt                NUMBER;
        x_msg_data               VARCHAR2 (2000);
        lv_ord_unit_of_measure   VARCHAR2 (240);
        lv_sold_to_id            NUMBER;
        lv_header_interface_id   NUMBER := -1;
        lv_locator_id            NUMBER;
        lv_ship_to_org_id        NUMBER;
        lv_ship_from_org_id      NUMBER;

        lv_line_ret_reason       VARCHAR2 (100);
        lv_n_org_id              NUMBER;
        lv_locator               NUMBER;
        lv_group_id              NUMBER := -1;
        ln_wh_id                 NUMBER;                                --v1.2
    BEGIN
        p_error_message                                           := NULL;
        p_return_status                                           := 0; -- g_ret_success;
        inv_rcv_common_apis.g_po_startup_value.transaction_mode   := 'BATCH';

        --Start changes v1.2
        SELECT organization_id
          INTO ln_wh_id
          FROM mtl_parameters
         WHERE organization_code = p_wh_code;

        --End changes v1.2

        FOR c_hdr_cur_rec IN c_hdr_cur
        LOOP
            SELECT apps.rcv_interface_groups_s.NEXTVAL
              INTO lv_group_id
              FROM DUAL;

            msg ('Group ID created is' || lv_group_id);

            lv_n_org_id           := NULL;
            lv_sold_to_id         := NULL;
            lv_ship_to_org_id     := NULL;
            lv_ship_from_org_id   := NULL;

            BEGIN
                SELECT DISTINCT ooh.org_id, ooh.sold_to_org_id, oola.ship_to_org_id,
                                oola.ship_from_org_id
                  INTO lv_n_org_id, lv_sold_to_id, lv_ship_to_org_id, lv_ship_from_org_id
                  FROM oe_order_lines_all oola, oe_order_headers_all ooh
                 WHERE     oola.header_id = ooh.header_id
                       AND oola.ship_from_org_id = ln_wh_id             --v1.2
                       AND c_hdr_cur_rec.header_id = ooh.header_id;
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    NULL;
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            msg ('Inserting Lines into rcv_headers_interface');
            rcv_headers_insert (p_shipment_num => c_hdr_cur_rec.rma_number, p_receipt_date => c_hdr_cur_rec.rma_receipt_date, p_organization_id => lv_ship_from_org_id, p_group_id => lv_group_id, p_customer_id => lv_sold_to_id, p_vendor_id => NULL, p_org_id => lv_n_org_id, p_header_interface_id => lv_header_interface_id, p_return_status => x_ret
                                , p_error_message => x_msg_data);

            IF x_ret != 0
            THEN
                fnd_file.put_line (fnd_file.LOG, x_msg_data);
                RETURN;
            END IF;


            FOR c_det_cur_rec IN c_det_cur
            LOOP
                BEGIN
                    msg ('Fetching Data Required Mandatory Data ');

                    lv_ord_unit_of_measure   := NULL;
                    lv_line_ret_reason       := NULL;

                    SELECT oola.order_quantity_uom, oola.return_reason_code
                      INTO lv_ord_unit_of_measure, lv_line_ret_reason
                      FROM oe_order_lines_all oola, oe_order_headers_all ooh
                     WHERE     oola.line_id = c_det_cur_rec.line_number
                           AND ooh.header_id = oola.header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                END;

                BEGIN
                    SELECT locator_type
                      INTO lv_locator
                      FROM mtl_secondary_inventories
                     WHERE     organization_id =
                               c_det_cur_rec.ship_from_org_id
                           AND secondary_inventory_name =
                               c_det_cur_rec.host_subinventory;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_locator      := 1;             --lv_locator := 999;
                        lv_locator_id   := NULL;
                END;

                --Derive the locator ID
                IF lv_locator <> 1
                THEN
                    BEGIN
                        SELECT MIN (inventory_location_id)
                          INTO lv_locator_id
                          FROM mtl_item_locations
                         WHERE     organization_id =
                                   c_det_cur_rec.ship_from_org_id
                               AND subinventory_code =
                                   c_det_cur_rec.host_subinventory
                               AND SYSDATE <= NVL (disable_date, SYSDATE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_locator_id   := NULL;
                    END;
                END IF;

                IF lv_line_ret_reason <> c_det_cur_rec.cust_return_reason
                THEN
                    msg (
                        'Return Reason are not same,then call process_order to update the line');
                    update_return_line (c_hdr_cur_rec.header_id,
                                        c_det_cur_rec.line_number,
                                        c_det_cur_rec.cust_return_reason,
                                        lv_n_org_id,
                                        p_return_status,
                                        p_error_message);
                END IF;



                msg ('Inserting Lines into rcv_transactions_interface');
                rcv_lines_insert (
                    p_org_id                        => lv_n_org_id,
                    p_receipt_source_code           => 'CUSTOMER',
                    p_source_document_code          => 'RMA',
                    p_group_id                      => lv_group_id,
                    p_location_id                   => NULL,
                    p_subinventory                  =>
                        c_det_cur_rec.host_subinventory,
                    p_header_interface_id           => lv_header_interface_id,
                    p_shipment_num                  => c_hdr_cur_rec.rma_number,
                    p_receipt_date                  => c_hdr_cur_rec.rma_receipt_date,
                    p_item_id                       =>
                        c_det_cur_rec.inventory_item_id,
                    --     p_employee_id                      => c_det_cur_rec.employee_id,   ---CRP Issue
                    p_uom                           => lv_ord_unit_of_measure,
                    p_quantity                      => c_det_cur_rec.qty,
                    p_return_status                 => x_ret,
                    p_error_message                 => x_msg_data,
                    p_shipment_header_id            => NULL,
                    p_shipment_line_id              => NULL,
                    p_ship_to_location_id           => NULL,
                    p_from_organization_id          => NULL,
                    p_to_organization_id            => NULL,
                    p_requisition_line_id           => NULL,
                    p_requisition_distribution_id   => NULL,
                    p_deliver_to_person_id          => NULL,
                    p_deliver_to_location_id        => NULL,
                    p_locator_id                    => lv_locator_id,
                    p_oe_order_header_id            => c_hdr_cur_rec.header_id,
                    p_oe_order_line_id              =>
                        c_det_cur_rec.line_number,
                    p_customer_id                   => lv_sold_to_id,
                    p_customer_site_id              => lv_ship_to_org_id,
                    p_vendor_id                     => NULL,
                    p_parent_transaction_id         => NULL);


                IF x_ret != 0
                THEN
                    msg (
                           'Error Occured in inserting into transaction interface table'
                        || x_msg_data);
                    RETURN;
                END IF;

                msg (
                    'Receipt Line Seq Id' || c_det_cur_rec.receipt_line_seq_id);
                msg ('Receipt Line Group ID' || lv_group_id);

                UPDATE xxdo_ont_rma_line_stg
                   SET GROUP_ID   = lv_group_id
                 WHERE receipt_line_seq_id =
                       c_det_cur_rec.receipt_line_seq_id;

                COMMIT;
            END LOOP;
        END LOOP;

        p_group_id                                                :=
            lv_group_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error occurred. ' || SQLERRM);
    END;


    PROCEDURE apply_hold (ph_line_tbl       IN OUT oe_holds_pvt.order_tbl_type,
                          p_org_id          IN     NUMBER,
                          p_hold_comment    IN     VARCHAR2,
                          p_return_status      OUT NUMBER,
                          p_error_message      OUT VARCHAR2)
    IS
        lv_order_tbl       oe_holds_pvt.order_tbl_type;
        lv_hold_id         NUMBER;
        lv_comment         VARCHAR2 (100);
        lv_return_status   VARCHAR2 (10);
        ln_msg_count       NUMBER;
        lv_msg_data        VARCHAR2 (200);

        lv_cnt             NUMBER;
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                              -- g_ret_success;
        lv_order_tbl      := ph_line_tbl;
        msg ('Calling Hold Package');

        BEGIN
            SELECT hold_id
              INTO lv_hold_id
              FROM oe_hold_definitions
             WHERE NAME = 'WMS_OVER_RECEIPT_HOLD';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                p_error_message   :=
                    'Hold WMS_OVER_RECEIPT_HOLD is not defined';
                p_return_status   := 2;
                RETURN;
            WHEN OTHERS
            THEN
                p_error_message   := SQLERRM;
                p_return_status   := 2;
                RETURN;
        END;

        lv_comment        :=
            NVL (p_hold_comment,
                 'Hold applied by Deckers Expected Returns program');
        msg ('Calling Apply Hold');
        oe_holds_pub.apply_holds (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            p_order_tbl          => lv_order_tbl,
            p_hold_id            => lv_hold_id,
            p_hold_until_date    => NULL,
            p_hold_comment       => lv_comment,
            x_return_status      => lv_return_status,
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data);

        IF lv_return_status <> 'S'
        THEN
            p_return_status   := 2;
            p_error_message   := lv_msg_data;

            FOR i IN lv_order_tbl.FIRST .. lv_order_tbl.LAST
            LOOP
                UPDATE xxdo_ont_rma_line_stg line
                   SET process_status = 'ERROR', result_code = 'E', type1 = 'PLANNED',
                       error_message = 'Hold Couldnt be applied for reason ' || lv_msg_data, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       last_update_login = gn_login_id
                 WHERE     process_status IN ('INPROCESS')
                       AND request_id = gn_request_id
                       AND line_id = lv_order_tbl (i).line_id;

                COMMIT;
            END LOOP;

            RETURN;
        END IF;

        IF NVL (lv_return_status, 'X') = 'S'
        THEN
            COMMIT;

            FOR i IN lv_order_tbl.FIRST .. lv_order_tbl.LAST
            LOOP
                UPDATE xxdo_ont_rma_line_stg line
                   SET process_status = 'HOLD', result_code = 'H', type1 = 'PLANNED',
                       error_message = '', last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       last_update_login = gn_login_id
                 WHERE     process_status IN ('INPROCESS')
                       AND request_id = gn_request_id
                       AND line_number = lv_order_tbl (i).line_id
                       AND EXISTS
                               (SELECT 'x'
                                  FROM oe_order_holds_all oh, oe_hold_sources_all ohs
                                 WHERE     oh.header_id =
                                           lv_order_tbl (i).header_id
                                       AND oh.line_id =
                                           lv_order_tbl (i).line_id
                                       AND oh.hold_source_id =
                                           ohs.hold_source_id
                                       AND ohs.hold_id = lv_hold_id
                                       AND oh.released_flag = 'N');

                COMMIT;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Unexpected error occurred. ' || SQLERRM);
    END apply_hold;

    PROCEDURE purge_archive (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER)
    IS
        lv_procedure        VARCHAR2 (100) := '.PURGE_ARCHIVE';
        ld_sysdate          DATE := SYSDATE;
        ln_purge_days_stg   NUMBER;
        ln_purge_days_log   NUMBER;
    BEGIN
        --Get purge date fom lookup.

        BEGIN
            SELECT TO_NUMBER (description)
              INTO ln_purge_days_stg
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'XXD_WMS_RMA_RECEIPT_UTIL_LKP'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND lookup_code = 'PURGE_DAYS_STG';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_purge_days_stg   := 60;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'PURGE DAYS STAGE : ' || ln_purge_days_stg);

        BEGIN
            SELECT TO_NUMBER (description)
              INTO ln_purge_days_log
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'XXD_WMS_RMA_RECEIPT_UTIL_LKP'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND lookup_code = 'PURGE_DAYS_LOG';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_purge_days_log   := 60;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'PURGE DAYS LOG : ' || ln_purge_days_log);


        /*RA Receipt header interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_hdr_stg_log (wh_id,
                                                  rma_number,
                                                  rma_receipt_date,
                                                  rma_reference,
                                                  customer_id,
                                                  order_number,
                                                  order_number_type,
                                                  customer_name,
                                                  customer_addr1,
                                                  customer_addr2,
                                                  customer_addr3,
                                                  customer_city,
                                                  customer_state,
                                                  customer_zip,
                                                  customer_phone,
                                                  customer_email,
                                                  comments,
                                                  rma_type,
                                                  notified_to_wms,
                                                  company,
                                                  customer_country_code,
                                                  customer_country_name,
                                                  request_id,
                                                  creation_date,
                                                  created_by,
                                                  last_update_date,
                                                  last_updated_by,
                                                  last_update_login,
                                                  attribute1,
                                                  attribute2,
                                                  attribute3,
                                                  attribute4,
                                                  attribute5,
                                                  attribute6,
                                                  attribute7,
                                                  attribute8,
                                                  attribute9,
                                                  attribute10,
                                                  attribute11,
                                                  attribute12,
                                                  attribute13,
                                                  attribute14,
                                                  attribute15,
                                                  attribute16,
                                                  attribute17,
                                                  attribute18,
                                                  attribute19,
                                                  attribute20,
                                                  source,
                                                  destination,
                                                  header_id,
                                                  process_status,
                                                  error_message,
                                                  retcode,
                                                  result_code,
                                                  record_type,
                                                  receipt_header_seq_id,
                                                  archive_request_id,
                                                  archive_date,
                                                  message_id)
                SELECT wh_id, rma_number, rma_receipt_date,
                       rma_reference, customer_id, order_number,
                       order_number_type, customer_name, customer_addr1,
                       customer_addr2, customer_addr3, customer_city,
                       customer_state, customer_zip, customer_phone,
                       customer_email, comments, rma_type,
                       notified_to_wms, company, customer_country_code,
                       customer_country_name, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, attribute1, attribute2,
                       attribute3, attribute4, attribute5,
                       attribute6, attribute7, attribute8,
                       attribute9, attribute10, attribute11,
                       attribute12, attribute13, attribute14,
                       attribute15, attribute16, attribute17,
                       attribute18, attribute19, attribute20,
                       source, destination, header_id,
                       process_status, error_message, retcode,
                       result_code, record_type, receipt_header_seq_id,
                       gn_request_id, ld_sysdate, message_id
                  FROM xxdo_ont_rma_hdr_stg hdr
                 WHERE     TRUNC (creation_date) <
                           TRUNC (ld_sysdate) - ln_purge_days_stg
                       AND process_status NOT IN ('ERROR', 'HOLD')
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM apps.xxdo_ont_rma_line_stg LN
                                 WHERE     LN.receipt_header_seq_id =
                                           hdr.receipt_header_seq_id
                                       AND LN.process_status = 'ERROR');



            DELETE FROM
                xxdo_ont_rma_hdr_stg hdr
                  WHERE     TRUNC (creation_date) <
                            TRUNC (ld_sysdate) - ln_purge_days_stg
                        AND process_status NOT IN ('ERROR', 'HOLD')
                        AND NOT EXISTS
                                (SELECT 1
                                   FROM apps.xxdo_ont_rma_line_stg LN
                                  WHERE     LN.receipt_header_seq_id =
                                            hdr.receipt_header_seq_id
                                        AND LN.process_status = 'ERROR');

            DELETE FROM
                xxdo_ont_rma_hdr_stg_log hdr
                  WHERE TRUNC (creation_date) <
                        TRUNC (ld_sysdate) - ln_purge_days_log;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA Receipt Header '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA Receipt Header Data '
                    || SQLERRM);
        END;

        /*RA Receipt line interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_line_stg_log (wh_id,
                                                   rma_number,
                                                   rma_reference,
                                                   line_number,
                                                   item_number,
                                                   type1,
                                                   disposition,
                                                   comments,
                                                   qty,
                                                   employee_id,
                                                   employee_name,
                                                   cust_return_reason,
                                                   factory_code,
                                                   damage_code,
                                                   prod_code,
                                                   uom,
                                                   host_subinventory,
                                                   attribute1,
                                                   attribute2,
                                                   attribute3,
                                                   attribute4,
                                                   attribute5,
                                                   attribute6,
                                                   attribute7,
                                                   attribute8,
                                                   attribute9,
                                                   attribute10,
                                                   attribute11,
                                                   attribute12,
                                                   attribute13,
                                                   attribute14,
                                                   attribute15,
                                                   attribute16,
                                                   attribute17,
                                                   attribute18,
                                                   attribute19,
                                                   attribute20,
                                                   request_id,
                                                   creation_date,
                                                   created_by,
                                                   last_update_date,
                                                   last_updated_by,
                                                   last_update_login,
                                                   source,
                                                   destination,
                                                   record_type,
                                                   header_id,
                                                   line_id,
                                                   process_status,
                                                   error_message,
                                                   inventory_item_id,
                                                   ship_from_org_id,
                                                   result_code,
                                                   GROUP_ID,
                                                   retcode,
                                                   receipt_header_seq_id,
                                                   receipt_line_seq_id,
                                                   rma_receipt_date,
                                                   archive_request_id,
                                                   archive_date)
                SELECT wh_id, rma_number, rma_reference,
                       line_number, item_number, type1,
                       disposition, comments, qty,
                       employee_id, employee_name, cust_return_reason,
                       factory_code, damage_code, prod_code,
                       uom, host_subinventory, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, source, destination,
                       record_type, header_id, line_id,
                       process_status, error_message, inventory_item_id,
                       ship_from_org_id, result_code, GROUP_ID,
                       retcode, receipt_header_seq_id, receipt_line_seq_id,
                       rma_receipt_date, gn_request_id, ld_sysdate
                  FROM xxdo_ont_rma_line_stg
                 WHERE     TRUNC (creation_date) <
                           TRUNC (ld_sysdate) - ln_purge_days_stg
                       AND process_status NOT IN ('ERROR', 'HOLD');



            DELETE FROM
                xxdo_ont_rma_line_stg
                  WHERE     TRUNC (creation_date) <
                            TRUNC (ld_sysdate) - ln_purge_days_stg
                        AND process_status NOT IN ('ERROR', 'HOLD');



            DELETE FROM
                xxdo_ont_rma_line_stg_log hdr
                  WHERE TRUNC (creation_date) <
                        TRUNC (ld_sysdate) - ln_purge_days_log;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA Receipt Details '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA Receipt Header Details '
                    || SQLERRM);
        END;


        /*RA XML Staging interface*/
        BEGIN
            INSERT INTO xxdo_ont_rma_xml_stg_log (process_status, xml_document, file_name, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, record_type, rma_xml_seq_id, archive_request_id
                                                  , archive_date, message_id)
                SELECT process_status, xml_document, file_name,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       record_type, rma_xml_seq_id, gn_request_id,
                       ld_sysdate, message_id
                  FROM xxdo_ont_rma_xml_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (ld_sysdate) - ln_purge_days_stg;

            DELETE FROM
                xxdo_ont_rma_xml_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (ld_sysdate) - ln_purge_days_stg;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving RA XML Statging table '
                    || SQLERRM;
                msg (
                       'Error happened while archiving RA XML Stating table '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Error occured in PROCEDURE  '
                || lv_procedure
                || '-'
                || SQLERRM);
            p_errbuf    := SQLERRM;
            p_retcode   := 2;
    END purge_archive;

    --Update the record status for RMA to process

    PROCEDURE set_in_process_status (p_errbuf           OUT VARCHAR2,
                                     p_retcode          OUT NUMBER,
                                     p_total_count      OUT NUMBER,
                                     p_wh_code       IN     VARCHAR2,   --v1.2
                                     p_rma_number    IN     VARCHAR2)
    IS
        lv_tot_count   NUMBER := 0;
    BEGIN
        msg ('Set IN-PROCESS status for RMA : ' || p_rma_number);
        --Set HDR stg records
        p_errbuf        := NULL;
        p_retcode       := 0;

        --Set any NEW records---
        UPDATE xxdo_ont_rma_hdr_stg
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     process_status IN ('NEW')
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code;                                   --v1.2

        msg ('No of headers updated  to INPROCESS ' || SQL%ROWCOUNT);
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;

        --Set Line value for any unplanned lines
        UPDATE xxdo_ont_rma_line_stg
           SET line_number   = -1
         WHERE     process_status IN ('NEW')
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND type1 = 'UNPLANNED'
               AND line_number > 0;


        UPDATE xxdo_ont_rma_line_stg
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE, line_id = NVL (line_id, line_number)
         WHERE     process_status IN ('NEW')
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code;                                   --v1.2

        msg ('No of lines updated   to INPROCESS ' || SQL%ROWCOUNT);
        -- p_total_count := SQL%ROWCOUNT ;
        --     commit;
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;


        --Set any HOLD records where hold was released
        UPDATE xxdo_ont_rma_hdr_stg hdr
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE                                  --,
         --   result_code = decode(process_status,'HOLD','A','')
         WHERE     process_status IN ('HOLD')
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh, oe_order_headers_all oeh, oe_order_lines_all oel
                         WHERE     ooh.header_id = oeh.header_id
                               AND ooh.released_flag = 'Y'
                               AND oeh.order_number = rma_number
                               AND oeh.header_id = oel.header_id
                               AND ooh.line_id = oel.line_id);

        msg ('No of headers-1 updated  to INPROCESS ' || SQL%ROWCOUNT);
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;

        UPDATE xxdo_ont_rma_line_stg line
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE, line_id = NVL (line_id, line_number)
         WHERE     process_status IN ('HOLD')
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh
                         WHERE     ooh.line_id = line.line_number
                               AND ooh.released_flag = 'Y');

        msg ('No of lines-1 updated to INPROCESS ' || SQL%ROWCOUNT);
        p_total_count   := SQL%ROWCOUNT;
        lv_tot_count    := p_total_count + lv_tot_count;
        msg (
               'No of rows updated  from XXDO_ONT_RMA_LINE_STG to INPROCESS '
            || SQL%ROWCOUNT);

        IF lv_tot_count <> 0
        THEN
            p_total_count   := lv_tot_count;
        ELSE
            p_total_count   := 0;
        END IF;

        p_retcode       := 0;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_errbuf    := SQLERRM;
            p_retcode   := 2;
    END;

    PROCEDURE update_rma_data_fields (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_wh_code IN VARCHAR2
                                      ,                                 --v1.2
                                        p_rma_number IN VARCHAR2)
    IS
    BEGIN
        --Update the stg table EBS reference fields
        msg ('Update data fields for RMA : ' || p_rma_number);

        msg ('Update header fields');

        --Update header fields
        UPDATE xxdo_ont_rma_hdr_stg x
           SET header_id   =
                   (SELECT header_id
                      FROM oe_order_headers_all ooha
                     WHERE     ooha.order_number = x.rma_number
                           AND ooha.open_flag = 'Y'
                           AND ooha.booked_flag = 'Y')
         WHERE     x.rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND request_id = gn_request_id
               AND process_status = 'INPROCESS';

        msg ('Update line fields');

        --update line fields
        UPDATE xxdo_ont_rma_line_stg x
           SET ship_from_org_id   =
                   (SELECT mp.organization_id
                      FROM mtl_parameters mp
                     WHERE mp.organization_code = x.wh_id),
               inventory_item_id   =
                   (SELECT DISTINCT inventory_item_id
                      FROM xxd_common_items_v v
                     WHERE v.item_number = x.item_number),
               header_id   =
                   (SELECT DISTINCT header_id
                      FROM xxdo_ont_rma_hdr_stg y
                     WHERE x.receipt_header_seq_id = y.receipt_header_seq_id),
               rma_receipt_date   =
                   (SELECT rma_receipt_date
                      FROM xxdo_ont_rma_hdr_stg y
                     WHERE x.receipt_header_seq_id = y.receipt_header_seq_id),
               org_id   =
                   (SELECT DISTINCT oel.org_id
                      FROM xxdo_ont_rma_hdr_stg y, oe_order_lines_all oel
                     WHERE     x.receipt_header_seq_id =
                               y.receipt_header_seq_id
                           AND y.header_id = oel.header_id)
         WHERE     x.rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND request_id = gn_request_id
               AND process_status = 'INPROCESS';

        COMMIT;

        p_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuf    := 'Error occurred updating data values. ' || SQLERRM;
            p_retcode   := 2;
    END;


    PROCEDURE validate_rma_data (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_wh_code IN VARCHAR2
                                 ,                                      --v1.2
                                   p_rma_number IN VARCHAR2)
    IS
        lv_whs_id   VARCHAR2 (10);
    BEGIN
        msg ('validate data for RMA : ' || p_rma_number);

        msg ('validate WHSID');

        --Validate WHSID
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Warehouse code is not eligible'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND x.wh_id NOT IN
                       (SELECT lookup_code
                          FROM fnd_lookup_values fvl
                         WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
                               AND NVL (LANGUAGE, USERENV ('LANG')) =
                                   USERENV ('LANG')
                               AND fvl.enabled_flag = 'Y')
               AND result_code IS NULL;

        msg ('validate RMA Number');

        --Validate RMA Number
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid RMA'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all ooh
                         WHERE     ooh.order_number = x.rma_number
                               AND ooh.open_flag = 'Y'
                               AND ooh.booked_flag = 'Y')
               AND result_code IS NULL;

        msg ('validate Receipt Date');

        --Validate receipt date
        --Note: we default this to sysdate when records are inserted so this may not be needed.
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA date cannot be null'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND rma_receipt_date IS NULL
               AND result_code IS NULL;

        --Validate receipt is not in the future
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA date cannot be future date'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND rma_receipt_date > SYSDATE /*vvap - timezone difference??*/
               AND result_code IS NULL;

        msg ('validate lines in error status');

        --Update RMA lines for headers in error status.
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA header is in error'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT h.receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg h
                         WHERE     h.request_id = gn_request_id
                               AND h.process_status = 'ERROR')
               AND result_code IS NULL;

        --Header validation complete do commit before validating lines.
        COMMIT;

        msg ('validate RMA Line number');

        --Validate RMA Line Number
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'RMA line cannot be null'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND type1 = 'PLANNED'
               AND line_number IS NULL
               AND result_code IS NULL;

        msg ('validate Item Number');

        --Validate item number
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Item can not be null'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND item_number IS NULL
               AND result_code IS NULL;


        --Validate item
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid Item'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM mtl_system_items msi
                         WHERE     msi.organization_id = x.ship_from_org_id
                               AND msi.inventory_item_id =
                                   x.inventory_item_id)
               AND result_code IS NULL;

        --Validate item on RMA (Only if item is PLANNED)
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid RMA line'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_lines_all ool
                         WHERE     ool.line_id = x.line_number
                               AND ool.ship_from_org_id = x.ship_from_org_id
                               AND ool.inventory_item_id =
                                   x.inventory_item_id)
               AND type1 = 'PLANNED'
               AND result_code IS NULL;

        msg ('validate Line Type');

        --Validate line type
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid type'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND type1 NOT IN ('PLANNED', 'UNPLANNED')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Type is null'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND type1 IS NULL
               AND result_code IS NULL;

        msg ('validate Quantity');

        --Validate quantity
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid quantity'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND NVL (qty, 0) <= 0
               AND result_code IS NULL;

        msg ('validate return reason');

        --Validate customer return reason against lookup
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid return reason'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND cust_return_reason NOT IN
                       (SELECT lookup_code
                          FROM ar_lookups al
                         WHERE     lookup_type = 'CREDIT_MEMO_REASON'
                               AND enabled_flag = 'Y')
               AND result_code IS NULL;

        msg ('validate damage code');

        --Validate damage code against lookup
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid damaged_code values'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND damage_code NOT IN
                       (SELECT fvvl.flex_value
                          FROM fnd_flex_value_sets fvs, fnd_flex_values_vl fvvl
                         WHERE     fvs.flex_value_set_name =
                                   'DO_OM_DEFECT_VS'
                               AND fvs.flex_value_set_id =
                                   fvvl.flex_value_set_id
                               AND fvvl.enabled_flag = 'Y')
               AND result_code IS NULL;


        msg ('validate subinventory');

        --Validate subinventory
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Invalid subinventory'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND host_subinventory NOT IN
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     1 = 1
                               AND lookup_type =
                                   'XXD_WMS_RMA_RECEIPT_SUBINV_LKP'
                               AND language = 'US'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (start_date_active,
                                                        SYSDATE)
                                               AND NVL (end_date_active,
                                                        SYSDATE + 1)
                               AND lookup_code = x.wh_id)
               AND result_code IS NULL;

        msg ('validate header reference');


        --Validate header reference
        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'No header reference'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_hdr_stg y
                         WHERE     y.receipt_header_seq_id =
                                   x.receipt_header_seq_id
                               AND y.request_id = gn_request_id)
               AND result_code IS NULL;

        --End validations
        COMMIT;

        p_retcode   := 0;
        p_errbuf    := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
    END;

    PROCEDURE process_rma_lines (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_wh_code IN VARCHAR2
                                 ,                                      --v1.2
                                   p_rma_number IN VARCHAR2)
    IS
        /*Line CURSOR RMA*/
        CURSOR cur_spl_rma_line IS
              SELECT DISTINCT rma_line.line_number, oel.line_id, oel.header_id,
                              oel.line_number OE_LINE_NUMBER, --<Ver 1.1 : Get Order line number>
                                                              oel.shipment_number oe_shipment_number, oel.ORDERED_ITEM, --<Ver 1.1 : Get Order line number>
                              oel.ordered_quantity, rma_line.rma_number, rma_line.qty,
                              receipt_line_seq_id, rma_line.process_status, oel.flow_status_code order_line_status,
                              /*          SUM (
                                           rma_line.qty)
                                        OVER (
                                           PARTITION BY oel.line_number, rma_line.line_number
                                           ORDER BY rma_line.rma_number, rma_line.receipt_line_seq_id)
                                           line_sum,*/
                              oel1.line_id new_line_id, oel1.shipment_number new_shipment_number, oel1.ordered_quantity new_ordered_quantity,
                              oel1.flow_status_code new_order_line_status
                FROM xxdo_ont_rma_line_stg rma_line, oe_order_lines_all oel, oe_order_headers_all oeh,
                     oe_order_lines_all oel1
               WHERE     1 = 1
                     AND rma_line.process_status IN ('INPROCESS')
                     AND rma_line.request_id = gn_request_id
                     AND rma_line.rma_number = p_rma_number
                     AND rma_line.wh_id = p_wh_code                     --v1.2
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values
                               WHERE     lookup_type = 'XXONT_WMS_WHSE'
                                     AND NVL (LANGUAGE, USERENV ('LANG')) =
                                         USERENV ('LANG')
                                     AND enabled_flag = 'Y'
                                     AND lookup_code = rma_line.wh_id)
                     AND rma_line.rma_number = oeh.order_number
                     AND oeh.header_id = oel.header_id
                     AND rma_line.line_number = oel.line_id
                     AND oel.line_number = oel1.line_number(+)
                     AND oel.header_id = oel1.header_id(+)
                     AND oel.line_id != oel1.line_id(+)
                     AND oel1.flow_status_code(+) = 'AWAITING_RETURN'
            ORDER BY oel.line_id, oel.ordered_item, rma_line.receipt_line_seq_id;

        ln_new_line_id            NUMBER := -1;
        ln_new_ordered_quantity   NUMBER := 0;
        lb_valid_line             BOOLEAN := FALSE;
        lb_is_Overreceipt         BOOLEAN := FALSE;
        l_split_count             NUMBER;
    BEGIN
        FOR rec_spl_rma_line IN cur_spl_rma_line
        LOOP
            ln_new_line_id            := -1;
            ln_new_ordered_quantity   := -1;
            lb_valid_line             := FALSE;

            --Mapped line is awaiting shipping
            IF rec_spl_rma_line.order_line_status = 'AWAITING_RETURN'
            THEN
                ln_new_line_id            := rec_spl_rma_line.line_id;
                ln_new_ordered_quantity   :=
                    rec_spl_rma_line.ordered_quantity;
                lb_valid_line             := TRUE;
            ELSE
                IF rec_spl_rma_line.new_line_id IS NOT NULL
                THEN
                    --There is a split out line for this line
                    ln_new_line_id            := rec_spl_rma_line.new_line_id;
                    ln_new_ordered_quantity   :=
                        rec_spl_rma_line.new_ordered_quantity;
                    lb_valid_line             := TRUE;
                ELSE
                    --No open split split out line then
                    ln_new_line_id            := -1;
                    ln_new_ordered_quantity   := -1;
                END IF;
            END IF;

            --check if over receipt;
            -- lb_is_Overreceipt :=
            --   rec_spl_rma_line.line_sum > ln_new_ordered_quantity;

            lb_is_Overreceipt         :=
                rec_spl_rma_line.qty > ln_new_ordered_quantity;


            IF lb_valid_line
            THEN
                IF lb_is_Overreceipt
                THEN
                    --For over receipt mark line as unplanned and reset line ID
                    UPDATE xxdo_ont_rma_line_stg
                       SET type1 = 'UNPLANNED', Line_number = -1, result_code = NULL
                     WHERE     receipt_line_seq_id =
                               rec_spl_rma_line.receipt_line_seq_id
                           AND request_id = gn_request_id;
                ELSE
                    --If new line was found then re-map stg table line
                    IF rec_spl_rma_line.line_id != ln_new_line_id
                    THEN
                        UPDATE xxdo_ont_rma_line_stg
                           SET line_number   = ln_new_line_id
                         WHERE     process_status IN ('INPROCESS')
                               AND receipt_line_seq_id =
                                   rec_spl_rma_line.receipt_line_seq_id
                               AND request_id = gn_request_id;
                    END IF;
                END IF;
            ELSE
                UPDATE xxdo_ont_rma_line_stg
                   SET type1 = 'UNPLANNED', Line_number = -1, result_code = NULL
                 WHERE     receipt_line_seq_id =
                           rec_spl_rma_line.receipt_line_seq_id
                       AND request_id = gn_request_id;
            END IF;

            COMMIT;
        END LOOP;

        --For any failures from above, fail out the entire RMA
        UPDATE xxdo_ont_rma_hdr_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'One or more lines in this RMA are in error'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT l.receipt_header_seq_id
                          FROM xxdo_ont_rma_line_stg l
                         WHERE     l.request_id = gn_request_id
                               AND l.rma_number = p_rma_number
                               AND l.wh_id = p_wh_code                  --v1.2
                               AND l.process_status = 'ERROR')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'One or more lines in this RMA are in error'
         WHERE     request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND process_status = 'INPROCESS'
               AND receipt_header_seq_id IN
                       (SELECT h.receipt_header_seq_id
                          FROM xxdo_ont_rma_hdr_stg h
                         WHERE     h.request_id = gn_request_id
                               AND h.rma_number = p_rma_number
                               AND h.wh_id = p_wh_code                  --v1.2
                               AND h.process_status = 'ERROR')
               AND result_code IS NULL;

        UPDATE xxdo_ont_rma_line_stg x
           SET process_status = 'ERROR', result_code = 'E', error_message = 'Unable to split more than one line in single process '
         WHERE request_id = gn_request_id AND process_status = 'SPLIT';

        COMMIT;
        p_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuf    := 2;
            p_retcode   := SUBSTR (SQLERRM, 1, 240);
            RETURN;
    END;

    PROCEDURE create_unplan_rma_line (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_wh_code IN VARCHAR2
                                      ,                                 --v1.2
                                        p_rma_number IN VARCHAR2)
    IS
        CURSOR c_det_unplan_cur IS
              SELECT *
                FROM xxdo_ont_rma_line_stg
               WHERE     process_status = 'INPROCESS'
                     AND result_code = 'U'
                     AND request_id = gn_request_id
                     AND rma_number = p_rma_number
                     AND wh_id = p_wh_code                              --v1.2
            ORDER BY org_id ASC;



        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        lv_line_tbl                    oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
                                           := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;
        lv_next_msg                    NUMBER;
        lv_header_id                   NUMBER;
        lv_ship_from_org_id            NUMBER;
        lv_inventory_item_id           NUMBER;
        lv_line_id                     NUMBER;
        lv_order_tbl                   oe_holds_pvt.order_tbl_type;
        lv_retcode                     NUMBER;
        lv_error_buf                   VARCHAR (1000);
        lv_hold_exists                 NUMBER;
        j                              NUMBER;
        lv_num                         NUMBER := 1;
        lv_hold_index                  NUMBER := 0;
        lv_mo_resp_id                  NUMBER;
        lv_mo_resp_appl_id             NUMBER;
        lv_org_exists                  NUMBER;
        lv_num_first                   NUMBER := 0;
        /* 10/1 - added 2 variables */
        l_num_rma_line_number          NUMBER;                 /*UNPLAN_NULL*/
    BEGIN
        p_errbuf       := NULL;
        p_retcode      := 0;                                 -- g_ret_success;


        --  lv_mo_org_id := NVL (mo_global.get_current_org_id,fnd_profile.VALUE ('ORG_ID'));

        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        x_debug_file   := oe_debug_pub.set_debug_mode ('FILE');
        oe_debug_pub.setdebuglevel (5);
        msg ('Begining of Process Order API');

        FOR c_det_unplan_rec IN c_det_unplan_cur
        LOOP
            l_line_tbl_index                          := 1;
            l_line_tbl (l_line_tbl_index)             := oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_line_tbl_index).header_id   :=
                c_det_unplan_rec.header_id;
            --Mandatory fields like qty, inventory item id are to be passed
            msg ('Deriving Values');

            IF lv_num_first = 0
            THEN
                lv_org_exists   := c_det_unplan_rec.org_id;
            END IF;


            SELECT oe_order_lines_s.NEXTVAL
              INTO l_line_tbl (l_line_tbl_index).line_id
              FROM DUAL;

            SELECT organization_id
              INTO l_line_tbl (l_line_tbl_index).ship_from_org_id
              FROM mtl_parameters
             WHERE organization_code = c_det_unplan_rec.wh_id;

            msg (
                   'Organization id '
                || l_line_tbl (l_line_tbl_index).ship_from_org_id);

            /*SELECT org_id
              INTO p_header_rec.org_id
              FROM oe_order_lines_all
             WHERE header_id = c_det_unplan_rec.header_id AND ROWNUM = 1; */

            SELECT order_type_id
              INTO p_header_rec.order_type_id
              FROM oe_order_headers_all
             WHERE header_id = c_det_unplan_rec.header_id;

            /* 10/1 - create unplanned RMA line with shipment 2 so it wont get extracted again */
            /*Start with UNPLAN_NULL*/
            l_num_rma_line_number                     := 0;

            BEGIN
                SELECT MAX (TO_NUMBER (line_number))
                  INTO l_num_rma_line_number
                  FROM oe_order_lines_all
                 WHERE header_id = c_det_unplan_rec.header_id;

                IF l_num_rma_line_number > 0
                THEN
                    l_line_tbl (l_line_tbl_index).line_number       :=
                        l_num_rma_line_number + 1;
                    l_line_tbl (l_line_tbl_index).shipment_number   := 2;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while fetching line number for order header :'
                        || c_det_unplan_rec.header_id
                        || ' '
                        || SQLERRM);
            END;

            /*Ends with UNPLAN_NULL*/

            IF (lv_num_first = 0 OR (lv_org_exists <> c_det_unplan_rec.org_id)) /*OU_BUG issue*/
            THEN
                get_resp_details (c_det_unplan_rec.org_id, 'ONT', lv_mo_resp_id
                                  , lv_mo_resp_appl_id);
                --     FND_CLIENT_INFO.SET_ORG_CONTEXT( p_header_rec.org_id );
                apps.fnd_global.apps_initialize (
                    user_id        => gn_user_id,
                    resp_id        => lv_mo_resp_id, --54066,-- 56626,--g_num_resp_id,--50225,--g_num_resp_id,--_id54066,
                    resp_appl_id   => lv_mo_resp_appl_id --20003-- 20024--g_num_resp_app_id
                                                        );
                mo_global.init ('ONT');
            /****************************
            apps.fnd_global.apps_initialize (user_id        => 2531,
                                             resp_id        => 50744,
                                             resp_appl_id   => 660);
            mo_global.init ('ONT');
            --MO_GLOBAL.SET_POLICY_CONTEXT('S', 95);
            msg ('CRP3..'); */



            END IF;

            /*OU_BUG issue*/
            --   mo_global.set_policy_context ('S', p_header_rec.org_id);
            l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                c_det_unplan_rec.qty;
            l_line_tbl (l_line_tbl_index).org_id      :=
                c_det_unplan_rec.org_id;
            l_line_tbl (l_line_tbl_index).inventory_item_id   :=
                c_det_unplan_rec.inventory_item_id;
            --   := pu_line_tbl (l_line_tbl_index).ship_from_org_id;
            l_line_tbl (l_line_tbl_index).subinventory   :=
                c_det_unplan_rec.host_subinventory;

            l_line_tbl (l_line_tbl_index).return_reason_code   :=
                NVL (
                    c_det_unplan_rec.cust_return_reason,
                    NVL (fnd_profile.VALUE ('XXDO_3PL_EDI_RET_REASON_CODE'),
                         'UAR - 0010'));
            msg (
                   'Customer return reason'
                || l_line_tbl (l_line_tbl_index).return_reason_code);
            l_line_tbl (l_line_tbl_index).flow_status_code   :=
                'AWAITING_RETURN';
            msg ('p_header_rec.order_type_id' || p_header_rec.order_type_id);
            msg (' p_header_rec.org_id' || c_det_unplan_rec.org_id);

            BEGIN
                SELECT default_inbound_line_type_id
                  INTO l_line_tbl (l_line_tbl_index).line_type_id
                  FROM oe_transaction_types_all
                 WHERE     transaction_type_id = p_header_rec.order_type_id
                       AND org_id = c_det_unplan_rec.org_id;

                msg (
                       'Line type id '
                    || l_line_tbl (l_line_tbl_index).line_type_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_line_tbl (l_line_tbl_index).line_type_id   := NULL;
            END;

            /*--added for version 1.1*/
            -- l_line_tbl (l_line_tbl_index).attribute12 := c_det_unplan_rec.damage_code;                           --Added for Damege code
            l_line_tbl (l_line_tbl_index).operation   :=
                oe_globals.g_opr_create;
            msg ('Calling process order API');
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => lv_line_tbl,
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
                x_action_request_tbl       => l_action_request_tbl);
            COMMIT;
            -- Retrieve messages
            msg ('Order Line msg' || l_msg_count);

            FOR k IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => k, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => lv_next_msg);
                fnd_file.put_line (fnd_file.LOG, 'message is:' || l_msg_data);
            END LOOP;

            -- Check the return status
            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                msg ('Process Order Sucess');
                msg ('Total Line ' || l_line_tbl.COUNT);

                FOR j IN 1 .. l_line_tbl.COUNT
                LOOP
                    msg ('Process Order Sucess');
                    lv_hold_exists   := 1;

                    UPDATE xxdo_ont_rma_line_stg
                       SET line_number = l_line_tbl (l_line_tbl_index).line_id, attribute1 = l_line_tbl (l_line_tbl_index).line_id, result_code = 'C'
                     WHERE     request_id = gn_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id =
                               c_det_unplan_rec.receipt_line_seq_id;

                    UPDATE xxdo_ont_rma_line_serl_stg
                       SET line_number = l_line_tbl (l_line_tbl_index).line_id
                     WHERE     request_id = gn_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id =
                               c_det_unplan_rec.receipt_line_seq_id;

                    COMMIT;
                END LOOP;
            ELSE
                FOR m IN 1 .. l_line_tbl.COUNT
                LOOP
                    msg ('Api failing with error' || l_return_status);

                    UPDATE xxdo_ont_rma_line_stg
                       SET line_number = c_det_unplan_rec.line_number, process_status = 'ERROR', result_code = 'E',
                           error_message = 'API Failed while creating Line'
                     WHERE     request_id = gn_request_id
                           AND process_status = 'INPROCESS'
                           AND receipt_line_seq_id =
                               c_det_unplan_rec.receipt_line_seq_id;

                    COMMIT;
                -- RETURN;
                END LOOP;
            END IF;

            lv_num_first                              :=
                lv_num_first + 1;
            lv_org_exists                             :=
                c_det_unplan_rec.org_id;


            IF lv_hold_exists = 1
            THEN
                FOR c_hold_data_rec
                    IN (SELECT header_id, line_number, org_id
                          FROM xxdo_ont_rma_line_stg
                         WHERE     process_status = 'INPROCESS'
                               AND result_code = 'C'
                               AND request_id = gn_request_id
                               AND receipt_line_seq_id =
                                   c_det_unplan_rec.receipt_line_seq_id)
                LOOP
                    lv_order_tbl (lv_num).header_id   :=
                        c_hold_data_rec.header_id;
                    lv_order_tbl (lv_num).line_id   :=
                        c_hold_data_rec.line_number;

                    -- lv_num := lv_num + 1; /*OU_BUG issue*/
                    BEGIN
                        apply_hold (lv_order_tbl, c_hold_data_rec.org_id, 'Hold applied'
                                    , lv_retcode, lv_error_buf);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_retcode   := 2;
                            msg ('Error while calling process_unplanned_rma');
                            p_errbuf    :=
                                   'Error while calling process_unplanned_rma'
                                || SQLERRM;
                    END;
                /*OU_BUG issue*/
                END LOOP;
            END IF;
        END LOOP;                           /*Main Cursor for Line ends here*/
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
            msg ('Unexpected error occurrred ' || SQLERRM);
    END;

    PROCEDURE process_rtp (p_group_id IN NUMBER, p_wait IN VARCHAR2:= 'Y', p_return_status OUT NUMBER
                           , p_error_message OUT VARCHAR2)
    IS
        lv_req_id                NUMBER;
        lv_req_status            BOOLEAN;
        lv_phase                 VARCHAR2 (80);
        lv_status                VARCHAR2 (80);
        lv_dev_phase             VARCHAR2 (80);
        lv_dev_status            VARCHAR2 (80);
        lv_message               VARCHAR2 (255);
        lv_new_mo_resp_id        NUMBER;
        lv_new_mo_resp_appl_id   NUMBER;
        lv_org_exists            NUMBER;
        lv_num_first             NUMBER := 0;
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                               --g_ret_success;

        /*OU_BUG issue*/
        FOR org_rec
            IN (  SELECT DISTINCT GROUP_ID, org_id
                    FROM xxdo_ont_rma_line_stg rti
                   WHERE     process_status = 'INPROCESS'
                         AND request_id = gn_request_id
                ORDER BY GROUP_ID)
        LOOP
            IF lv_num_first = 0
            THEN
                lv_org_exists   := org_rec.org_id;
            END IF;

            IF (lv_num_first = 0 OR (lv_org_exists != org_rec.org_id)) /*OU_BUG issue*/
            THEN
                msg ('Org id is-' || org_rec.org_id);
                get_resp_details (org_rec.org_id, 'PO', lv_new_mo_resp_id,
                                  lv_new_mo_resp_appl_id);
                apps.fnd_global.apps_initialize (
                    user_id        => gn_user_id,
                    resp_id        => lv_new_mo_resp_id,
                    resp_appl_id   => lv_new_mo_resp_appl_id);
                --  mo_global.set_policy_context('M',org_rec.org_id);
                mo_global.init ('PO');
            END IF;

            /*OU_BUG issue*/
            lv_req_id       :=
                fnd_request.submit_request (
                    application   => 'PO',
                    program       => 'RVCTP',
                    argument1     => 'BATCH',
                    argument2     => TO_CHAR (org_rec.GROUP_ID),
                    argument3     => org_rec.org_id);

            COMMIT;

            IF NVL (p_wait, 'Y') = 'Y'
            THEN
                lv_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => lv_req_id,
                        INTERVAL     => 10,
                        max_wait     => 0,
                        phase        => lv_phase,
                        status       => lv_status,
                        dev_phase    => lv_dev_phase,
                        dev_status   => lv_dev_status,
                        MESSAGE      => lv_message);

                IF NVL (lv_dev_status, 'ERROR') != 'NORMAL'
                THEN
                    IF NVL (lv_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        p_return_status   := 1;           --g_ret_sts_warning;
                    ELSE
                        p_return_status   := 2;    -- fnd_api.g_ret_sts_error;
                    END IF;

                    p_error_message   :=
                        NVL (
                            lv_message,
                               'The receiving transaction processor request ended with a status of '
                            || NVL (lv_dev_status, 'ERROR'));
                    msg ('Error In Receiing Transaction processor');
                ELSE
                    UPDATE xxdo_ont_rma_line_stg
                       SET GROUP_ID   = p_group_id
                     WHERE     process_status = 'INPROCESS'
                           AND request_id = gn_request_id;

                    COMMIT;
                END IF;
            END IF;

            lv_num_first    := lv_num_first + 1;
            lv_org_exists   := org_rec.org_id;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error occurred. ' || SQLERRM);
    END;

    PROCEDURE update_all_records (p_return_status OUT NUMBER, p_error_message OUT VARCHAR2, p_wh_code IN VARCHAR2
                                  ,                                     --v1.2
                                    p_rma_number IN NUMBER)
    IS
        lv_cnt              NUMBER := 0;
        lv_status           VARCHAR2 (2000);
        lv_error_message    VARCHAR2 (1000);
        lv_process_status   VARCHAR2 (1000);
        lv_retcode          VARCHAR2 (10);
    BEGIN
        UPDATE xxdo_ont_rma_line_stg dtl
           SET (dtl.error_message, dtl.process_status)   =
                   (SELECT SUBSTR (pie.error_message, 1, 1000), 'ERROR'
                      FROM po_interface_errors pie, rcv_transactions_interface rti
                     WHERE     pie.interface_line_id(+) =
                               rti.interface_transaction_id
                           --AND rti.transaction_status_code = 'ERROR'
                           AND rti.oe_order_header_id = dtl.header_id
                           AND rti.oe_order_line_id = dtl.line_number
                           AND dtl.GROUP_ID = rti.GROUP_ID
                           AND ROWNUM = 1),
               last_updated_by     = gn_user_id,
               last_update_date    = SYSDATE,
               last_update_login   = gn_login_id
         WHERE     dtl.process_status = 'INPROCESS'
               AND dtl.request_id = gn_request_id
               AND dtl.rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND EXISTS
                       (SELECT 1
                          FROM po_interface_errors pie, rcv_transactions_interface rti
                         WHERE     pie.interface_line_id(+) =
                                   rti.interface_transaction_id
                               --AND rti.transaction_status_code = 'ERROR'
                               AND rti.oe_order_header_id = dtl.header_id
                               AND rti.oe_order_line_id = dtl.line_number
                               AND dtl.GROUP_ID = rti.GROUP_ID);

        COMMIT;

        DELETE FROM
            po_interface_errors pie
              WHERE pie.interface_line_id IN
                        (SELECT rti.interface_transaction_id
                           FROM rcv_transactions_interface rti
                          WHERE     rti.processing_status_code = 'ERROR'
                                AND rti.GROUP_ID IN
                                        (SELECT x.GROUP_ID
                                           FROM xxdo_ont_rma_line_stg x
                                          WHERE     x.process_status =
                                                    'ERROR'
                                                AND x.request_id =
                                                    gn_request_id));

        DELETE FROM
            rcv_transactions_interface rti
              WHERE     rti.processing_status_code = 'ERROR'
                    AND rti.GROUP_ID IN
                            (SELECT x.GROUP_ID
                               FROM xxdo_ont_rma_line_stg x
                              WHERE     x.process_status = 'ERROR'
                                    AND x.request_id = gn_request_id);

        COMMIT;

        UPDATE xxdo_ont_rma_line_stg line
           SET process_status = 'HOLD', error_message = '', result_code = 'H',
               type1 = 'PLANNED', last_updated_by = gn_user_id, last_update_date = SYSDATE,
               last_update_login = gn_login_id
         WHERE     process_status IN ('INPROCESS')
               AND request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh
                         WHERE     ooh.line_id = line.line_id
                               AND ooh.released_flag = 'N');

        COMMIT;

        UPDATE xxdo.xxdo_ont_rma_line_stg
           SET process_status = 'PROCESSED', result_code = 'P', error_message = '',
               last_updated_by = gn_user_id, last_update_login = gn_login_id, last_update_date = SYSDATE
         WHERE     process_status = 'INPROCESS'
               AND request_id = gn_request_id
               AND wh_id = p_wh_code                                    --v1.2
               AND rma_number = p_rma_number;

        COMMIT;

        ---------Updating the RA Header Data
        UPDATE xxdo_ont_rma_hdr_stg head
           SET head.process_status = 'ERROR', result_code = 'E', error_message = 'Error Due to Line Record',
               last_updated_by = gn_user_id, last_update_login = gn_login_id, last_update_date = SYSDATE
         WHERE     head.process_status = 'INPROCESS'
               AND head.request_id = gn_request_id
               AND head.rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg dtl
                         WHERE     dtl.receipt_header_seq_id =
                                   head.receipt_header_seq_id
                               AND dtl.request_id = gn_request_id
                               AND dtl.process_status = 'ERROR');

        COMMIT;



        --Update Hold Record
        UPDATE xxdo_ont_rma_hdr_stg hdr
           SET process_status = 'HOLD', error_message = '', result_code = 'H',
               last_updated_by = gn_user_id, last_update_login = gn_login_id, last_update_date = SYSDATE
         WHERE     process_status IN ('INPROCESS')
               AND request_id = gn_request_id
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh, oe_order_headers_all oeh, oe_order_lines_all oel
                         WHERE     ooh.header_id = oeh.header_id
                               AND ooh.released_flag = 'N'
                               AND oeh.order_number = rma_number
                               AND oeh.header_id = oel.header_id
                               AND ooh.line_id = oel.line_id);

        COMMIT;

        UPDATE xxdo.xxdo_ont_rma_hdr_stg
           SET process_status = 'PROCESSED', result_code = 'P', error_message = '',
               last_updated_by = gn_user_id, last_update_login = gn_login_id, last_update_date = SYSDATE
         WHERE     process_status = 'INPROCESS'
               AND request_id = gn_request_id
               AND wh_id = p_wh_code                                    --v1.2
               AND rma_number = p_rma_number;

        COMMIT;

        /*Start updating DAMAGE_CODE,FACTORY_CODE,PROD_CODE*/

        BEGIN
            UPDATE oe_order_lines_all oel
               SET oel.attribute12   =
                       (SELECT line.damage_code
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = gn_request_id
                               AND line.rma_number = p_rma_number
                               AND line.wh_id = p_wh_code               --v1.2
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number)
             WHERE --oel.flow_status_code IN ('RETURNED', 'CLOSED')                 --commented for version 1.1
                   EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = gn_request_id
                               AND line.rma_number = p_rma_number
                               AND line.wh_id = p_wh_code               --v1.2
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Records in error while updating damage_code' || SQLERRM);
        END;

        BEGIN
            UPDATE oe_order_lines_all oel
               SET (attribute4)   =
                       (SELECT aps.vendor_id
                          FROM xxdo_ont_rma_line_stg line, ap_suppliers aps
                         WHERE     line.request_id = gn_request_id
                               AND line.rma_number = p_rma_number
                               AND line.wh_id = p_wh_code               --v1.2
                               AND line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number
                               AND aps.vendor_type_lookup_code =
                                   'MANUFACTURER'
                               AND NVL (aps.start_date_active, SYSDATE) <
                                   SYSDATE + 1
                               AND NVL (aps.end_date_active, SYSDATE) >=
                                   SYSDATE
                               AND NVL (aps.enabled_flag, 'N') = 'Y'
                               AND aps.attribute1 = line.factory_code)
             WHERE --oel.flow_status_code IN ('RETURNED', 'CLOSED')                                   --commented for version 1.1
                   EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = gn_request_id
                               AND line.rma_number = p_rma_number
                               AND line.wh_id = p_wh_code               --v1.2
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Records in error while updating Factory Code' || SQLERRM);
        END;

        BEGIN
            UPDATE oe_order_lines_all oel
               SET attribute5   =
                       (SELECT dom.MONTH_YEAR_CODE
                          FROM xxdo_ont_rma_line_stg line1, DO_BOM_MONTH_YEAR_V dom
                         WHERE     dom.MONTH_YEAR_CODE = line1.prod_code
                               AND line1.request_id = gn_request_id
                               AND line1.rma_number = p_rma_number
                               AND line1.wh_id = p_wh_code              --v1.2
                               AND line1.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND oel.header_id = line1.header_id
                               AND oel.line_id = line1.line_number)
             WHERE --oel.flow_status_code IN ('RETURNED', 'CLOSED')                                 --commented for version 1.1
                   EXISTS
                       (SELECT 1
                          FROM xxdo_ont_rma_line_stg line
                         WHERE     line.process_status IN
                                       ('PROCESSED', 'HOLD')
                               AND line.request_id = gn_request_id
                               AND line.rma_number = p_rma_number
                               AND line.wh_id = p_wh_code               --v1.2
                               AND oel.header_id = line.header_id
                               AND oel.line_id = line.line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Records in error while updating Prod Code' || SQLERRM);
        END;
    /*Ends  updating FACTORY_CODE,PROD_CODE*/

    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error occurred. ' || SQLERRM);
            p_return_status   := 2;
            p_error_message   := SQLERRM;
    END;


    PROCEDURE check_hold_released (p_retcode OUT NUMBER, p_errbuf OUT VARCHAR2, p_wh_code IN VARCHAR2
                                   ,                                    --v1.2
                                     p_rma_number IN NUMBER)
    IS
        lv_rel_cnt    NUMBER;
        lv_yes_hold   VARCHAR (2);
    BEGIN
        UPDATE xxdo_ont_rma_line_stg rma_line
           SET process_status = 'INPROCESS', result_code = 'P', error_message = '',
               request_id = gn_request_id
         WHERE     rma_line.process_status IN ('HOLD')
               AND rma_number = p_rma_number
               AND wh_id = p_wh_code                                    --v1.2
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_holds_all ooh
                         WHERE     ooh.line_id = rma_line.line_number
                               AND ooh.released_flag = 'N');

        UPDATE xxdo_ont_rma_hdr_stg h
           SET process_status = 'INPROCESS', result_code = 'P', error_message = '',
               request_id = gn_request_id
         WHERE     process_status IN ('HOLD')
               AND h.receipt_header_seq_id IN
                       (SELECT l.receipt_header_seq_id
                          FROM xxdo_ont_rma_line_stg l
                         WHERE     l.request_id = gn_request_id
                               AND l.rma_number = p_rma_number
                               AND l.wh_id = p_wh_code                  --v1.2
                               AND l.process_status = 'INPROCESS');

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error occurred. ' || SQLERRM);
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
    END;

    PROCEDURE Process_line_multi_receipt (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_wh_code IN VARCHAR2
                                          ,                             --v1.2
                                            p_rma_number IN NUMBER)
    AS
        CURSOR c_rma_number IS
              SELECT rma_number, line_number, item_number,
                     SUM (qty) total_qty, MAX (receipt_line_seq_id) seq_id
                FROM apps.xxdo_ont_rma_line_stg
               WHERE     process_status = 'INPROCESS'
                     AND rma_number = p_rma_number
                     AND wh_id = p_wh_code                              --v1.2
                     AND request_id = gn_request_id
            GROUP BY rma_number, line_number, item_number
              HAVING COUNT (*) > 1;
    BEGIN
        FOR r_rma_number IN c_rma_number            --cursor to get rma_number
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'RMA Number : ' || r_rma_number.rma_number);

            UPDATE xxdo_ont_rma_line_stg
               SET qty   = r_rma_number.total_qty
             WHERE     receipt_line_seq_id = r_rma_number.seq_id
                   AND line_number = r_rma_number.line_number
                   AND item_number = r_rma_number.item_number
                   AND process_status = 'INPROCESS'
                   AND request_id = gn_request_id;

            UPDATE xxdo_ont_rma_line_stg
               SET qty = 0, process_status = 'IGNORED', error_message = NULL,
                   attribute11 = 'Split line issue. Processed in Seq ID: ' || r_rma_number.seq_id
             WHERE     process_status = 'INPROCESS'
                   AND receipt_line_seq_id <> r_rma_number.seq_id
                   AND line_number = r_rma_number.line_number
                   AND item_number = r_rma_number.item_number
                   AND request_id = gn_request_id;

            COMMIT;
        END LOOP;                           -- end of cursor to get rma_number

        p_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error occurred. ' || SQLERRM);
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
    END;

    PROCEDURE Process_rma_interface (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_wh_code IN VARCHAR2, p_rma_num IN VARCHAR2, p_source IN VARCHAR2 DEFAULT 'WMS', p_destination IN VARCHAR2 DEFAULT 'EBS'
                                     , p_debug IN VARCHAR2 DEFAULT 'Y')
    IS
        CURSOR c_rma_hold IS
            SELECT DISTINCT rma_number
              FROM apps.xxdo_ont_rma_line_stg
             WHERE process_status = 'HOLD';

        --Cursor to select RMAs to process based on Record status/WHS/RMA Number parameters
        CURSOR c_rma_process IS
            SELECT DISTINCT hdr.rma_number
              FROM apps.xxdo_ont_rma_hdr_stg hdr
             WHERE     hdr.process_status IN ('NEW', 'HOLD')
                   AND hdr.wh_id = NVL (p_wh_code, hdr.wh_id)
                   AND hdr.rma_number = NVL (p_rma_num, hdr.rma_number)
                   AND rma_number IS NOT NULL;



        ln_retcode       NUMBER;
        lv_error_buf     VARCHAR2 (2000);
        lv_rma_num       VARCHAR (10);
        lv_group_id      NUMBER;
        lv_total_count   NUMBER;
        lv_rma_message   VARCHAR2 (2000);

        ex_rma_process   EXCEPTION;
        ex_rma_loop      EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Process RMA Interface records -- enter');
        fnd_file.put_line (
            fnd_file.LOG,
            'Start time : ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS'));

        --List out parameters
        fnd_file.put_line (fnd_file.LOG, 'WH CODE : ' || p_wh_code);
        fnd_file.put_line (fnd_file.LOG, 'RMA # : ' || p_rma_num);
        fnd_file.put_line (fnd_file.LOG, 'SOURCE : ' || p_source);
        fnd_file.put_line (fnd_file.LOG, 'DEST : ' || p_destination);
        fnd_file.put_line (fnd_file.LOG, 'DEBUG : ' || p_debug);

        fnd_file.put_line (fnd_file.LOG, 'USER ID : ' || fnd_global.user_id);
        fnd_file.put_line (fnd_file.LOG, 'RESP ID : ' || fnd_global.resp_id);
        fnd_file.put_line (fnd_file.LOG,
                           'APP ID : ' || fnd_global.resp_appl_id);

        IF p_debug = 'Y'
        THEN
            gn_debug   := 1;
        ELSE
            gn_debug   := 0;
        END IF;

        --Attempt to release any order holds for any RMA staging table lines in HOLD staus
        --The process does not return any indicator that the hold is released but later the HOLD status is set to INPROCESS if hold is released
        FOR r_rma_hold IN c_rma_hold
        LOOP
            XXDO_ONT_RMA_HOLD_RELEASE_PKG.main (lv_error_buf,
                                                ln_retcode,
                                                r_rma_hold.rma_number);

            IF NVL (ln_retcode, 0) = 2
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error occurred releasing hold for RMA '
                    || r_rma_hold.rma_number
                    || ' : '
                    || lv_error_buf);
            END IF;
        END LOOP;

        FOR r_rma_process IN c_rma_process
        LOOP
            BEGIN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Running RMA # : ' || r_rma_process.rma_number);

                --Combine cases of multiple references to same RMA line
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Before calling procedure set in process status');
                --Set record status to INPROCESS for records to be processed
                set_in_process_status (lv_error_buf, ln_retcode, lv_total_count
                                       , p_wh_code,                     --v1.2
                                                    r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    --Failed to set process fail RMA and goto next RMA
                    lv_rma_message   :=
                           'Failed to update record process status for RMA. '
                        || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_loop;
                END IF;

                --Combine cases of multiple r eferences to same RMA line
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Before calling procedure update data fields');

                --Update data fields from EBS
                update_rma_data_fields (lv_error_buf, ln_retcode, p_wh_code, --v1.2
                                        r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    --Failed to set process
                    lv_rma_message   :=
                           'Failed to update data fields for RMA. '
                        || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;


                --Combine cases of multiple references to same RMA line
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Before calling procedure validate RMA data');

                --Validate records for RMA
                validate_rma_data (lv_error_buf, ln_retcode, p_wh_code, --v1.2
                                   r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    --Failed to set process
                    lv_rma_message   :=
                           'Error occurred validating RMA data. '
                        || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;

                --Combine cases of multiple references to same RMA line
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Before calling procedure split reprocess');

                Process_line_multi_receipt (ln_retcode, lv_error_buf, p_wh_code
                                            ,                           --v1.2
                                              r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    lv_rma_message   :=
                           'Error During Processing of multiple line receipts: '
                        || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;

                --Run process of RMA lines
                process_rma_lines (lv_error_buf, ln_retcode, p_wh_code, --v1.2
                                   r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    --Failed to set process
                    lv_rma_message   :=
                           'Error occurred checking RMA splits. '
                        || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;

                -----------

                --Update Result code based on status
                BEGIN
                    UPDATE xxdo_ont_rma_hdr_stg
                       SET result_code = 'P', retcode = '', error_message = ''
                     WHERE     process_status IN ('INPROCESS')
                           AND request_id = gn_request_id
                           AND wh_id = p_wh_code                        --v1.2
                           AND rma_number = r_rma_process.rma_number;

                    COMMIT;

                    UPDATE xxdo_ont_rma_line_stg
                       SET result_code = 'U', retcode = '', error_message = ''
                     WHERE     process_status IN ('INPROCESS')
                           AND request_id = gn_request_id
                           AND type1 = 'UNPLANNED'
                           AND wh_id = p_wh_code                        --v1.2
                           AND rma_number = r_rma_process.rma_number;

                    COMMIT;

                    UPDATE xxdo_ont_rma_line_stg
                       SET result_code = 'P', retcode = '', error_message = ''
                     WHERE     process_status IN ('INPROCESS')
                           AND request_id = gn_request_id
                           AND type1 = 'PLANNED'
                           AND wh_id = p_wh_code                        --v1.2
                           AND rma_number = r_rma_process.rma_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --An exception thrown here should cause failure of process as only reporting result_code
                        NULL;
                END;

                create_unplan_rma_line (ln_retcode, lv_error_buf, p_wh_code, --v1.2
                                        r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    lv_rma_message   :=
                           'Error while create_unplan_rma_line: '
                        || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;


                check_hold_released (ln_retcode, lv_error_buf, p_wh_code, --v1.2
                                     r_rma_process.rma_number);

                IF ln_retcode <> 0
                THEN
                    lv_rma_message   :=
                        'Error while check_hold_released: ' || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;

                receive_return_tbl (lv_group_id, ln_retcode, lv_error_buf,
                                    p_wh_code,                          --v1.2
                                               r_rma_process.rma_number);


                IF ln_retcode <> 0
                THEN
                    lv_rma_message   :=
                        'Error while check_hold_released: ' || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;

                fnd_file.put_line (fnd_file.LOG,
                                   'GROUP ID : ' || lv_group_id);

                IF (lv_group_id <> -1)
                THEN
                    process_rtp (p_group_id => lv_group_id, p_wait => 'Y', p_return_status => ln_retcode
                                 , p_error_message => lv_error_buf);

                    IF ln_retcode <> 0
                    THEN
                        lv_rma_message   :=
                               'Error During Running Transaction processor: '
                            || lv_error_buf;
                        msg (lv_rma_message);
                        RAISE ex_rma_process;
                    END IF;
                END IF;

                update_all_records (ln_retcode, lv_error_buf, p_wh_code, --v1.2
                                    r_rma_process.rma_number);



                IF ln_retcode <> 0
                THEN
                    lv_rma_message   :=
                        'Error while updating all records: ' || lv_error_buf;
                    msg (lv_rma_message);
                    RAISE ex_rma_process;
                END IF;
            --Handle exceptions within RMA block . Update the error status to ERROR fo those records.
            EXCEPTION
                WHEN ex_rma_process
                THEN
                    UPDATE xxdo_ont_rma_hdr_stg
                       SET result_code = 'E', retcode = '', error_message = lv_rma_message
                     WHERE     process_status IN ('INPROCESS')
                           AND request_id = gn_request_id
                           AND wh_id = p_wh_code                        --v1.2
                           AND rma_number = r_rma_process.rma_number;


                    UPDATE xxdo_ont_rma_line_stg
                       SET process_status = 'ERROR', result_code = 'E', retcode = '',
                           error_message = lv_rma_message
                     WHERE     process_status IN ('INPROCESS')
                           AND request_id = gn_request_id
                           AND wh_id = p_wh_code                        --v1.2
                           AND rma_number = r_rma_process.rma_number;

                    COMMIT;
                WHEN ex_rma_loop
                THEN
                    --Occurrs when fail to update status to 'IN_PROCESS' no need to update records here as next execution may pick up
                    CONTINUE;
                WHEN OTHERS
                THEN
                    --Re-raise to master error handler
                    RAISE;
            END;
        END LOOP;



        fnd_file.put_line (fnd_file.LOG,
                           'Process RMA Interface records -- exit');
        fnd_file.put_line (
            fnd_file.LOG,
            'End time : ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
            msg (p_errbuf);
    END;

    PROCEDURE remove_rma_overreceipt_holds (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_rma_number IN NUMBER)
    IS
        lv_error_buf     VARCHAR2 (2000);
        ln_retcode       NUMBER;
        ln_line_count    NUMBER;
        ln_final_count   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Process RMA Interface records -- enter');
        fnd_file.put_line (
            fnd_file.LOG,
            'Start time : ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS'));

        --List out parameters
        fnd_file.put_line (fnd_file.LOG, 'RMA # : ' || p_rma_number);

        IF p_rma_number IS NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, 'RMA # must be supplied.');
            RETURN;
        END IF;


        --get count of affected return lines
        SELECT COUNT (*)
          INTO ln_line_count
          FROM XXD_RMA_OVERRECEIPT_LINES_V
         WHERE rma_number = p_rma_number;

        DBMS_OUTPUT.put_line ('Lines on hold : ' || ln_line_count);

        IF ln_line_count > 0
        THEN
            release_rma_hold (lv_error_buf, ln_retcode, p_rma_number);

            IF NVL (ln_retcode, 0) = 2
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error occurred releasing hold for RMA '
                    || p_rma_number
                    || ' : '
                    || lv_error_buf);
                p_errbuf    := lv_error_buf;
                p_retcode   := 2;
                RETURN;
            END IF;

            SELECT COUNT (*)
              INTO ln_final_count
              FROM XXD_RMA_OVERRECEIPT_LINES_V
             WHERE rma_number = p_rma_number;

            DBMS_OUTPUT.put_line ('Lines on hold : ' || ln_final_count);

            IF ln_final_count > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ln_final_count
                    || ' lines remaining on hold for RMA# '
                    || p_rma_number);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    ' All lines removed from hold for RMA# ' || p_rma_number);
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'No lines to release hold for RMA # ' || p_rma_number);
        END IF;

        p_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuf    := 'Error occurred releasing holds. ' || SQLERRM;
            p_retcode   := 2;
    END;

    PROCEDURE archive_rma_stage_data (p_errbuf    OUT VARCHAR2,
                                      p_retcode   OUT NUMBER)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Purge RMA Interface records -- enter');
        fnd_file.put_line (
            fnd_file.LOG,
            'Start time : ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS'));

        --copy old staging table data to log tables then purge from staging tables
        purge_archive (p_errbuf, p_retcode);

        fnd_file.put_line (
            fnd_file.LOG,
            'End time : ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    :=
                   'Error occurred when purging/archiving RMA stage data. '
                || SQLERRM;
    END;
END;
/
