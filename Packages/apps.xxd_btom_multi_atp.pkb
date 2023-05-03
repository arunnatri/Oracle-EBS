--
-- XXD_BTOM_MULTI_ATP  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_BTOM_MULTI_ATP"
AS
    /****************************************************************************************************************************************
      Modification History:
      Version       By                      Date              Comments
      1.1          Infosys               24-Feb-2017      Changes done related to "INC0340792/PRB0041192"
     ****************************************************************************************************************************************/

    PROCEDURE get_multi_atp_check (
        p_multi_atp_tbl   IN     xxd_btom_multi_atp_tbltype,
        p_org_id          IN     NUMBER,
        p_user_id         IN     NUMBER,
        p_resp_id         IN     NUMBER,
        p_resp_app_id     IN     NUMBER,
        x_multi_atp_tbl      OUT xxd_btom_multi_atp_tbltype,
        x_sum_atp            OUT NUMBER,
        x_sum_atr            OUT NUMBER,
        x_sum_onhand         OUT NUMBER,
        x_error_message      OUT VARCHAR2,
        x_error_code         OUT VARCHAR2)
    IS
        lr_atp_rec            mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        x_return_status       VARCHAR2 (10);
        x_msg_data            VARCHAR2 (4000);
        lc_error_message      VARCHAR2 (4000);
        x_msg_count           NUMBER;
        ln_session_id         NUMBER;
        ln_msg_index_out      NUMBER;
        x_qty_atr             NUMBER;
        x_onhand_qty          NUMBER;
    BEGIN
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');

        SELECT oe_order_sch_util.get_session_id INTO ln_session_id FROM DUAL;



        DBMS_OUTPUT.put_line (' ln_session_id - ' || ln_session_id);
        x_multi_atp_tbl   := xxd_btom_multi_atp_tbltype ();
        --x_multi_atp_tbl.extend(p_multi_atp_tbl.COUNT);
        msc_atp_global.extend_atp (lr_atp_rec, x_return_status, 1);

        FOR i IN 1 .. p_multi_atp_tbl.COUNT
        LOOP
            DBMS_OUTPUT.put_line ('Inside For loop ');
            x_multi_atp_tbl.EXTEND (1);
            x_multi_atp_tbl (i)                     :=
                xxd_btom_multi_atp_rcrd_type (NULL, NULL, NULL,
                                              NULL, NULL, NULL,
                                              NULL, NULL, NULL,
                                              NULL, NULL, NULL,
                                              NULL, NULL, NULL,
                                              NULL);
            lr_atp_rec.inventory_item_id (1)        :=
                p_multi_atp_tbl (i).inventory_item_id;

            IF p_multi_atp_tbl (i).ordered_qty = 0
            THEN
                --lr_atp_rec.quantity_ordered (1) := 1;
                lr_atp_rec.quantity_ordered (1)   :=
                    NVL (fnd_profile.VALUE ('XXDO_DOE_ATP_DEFAULT_REQ_QTY'),
                         999999999);
            ELSE
                lr_atp_rec.quantity_ordered (1)   :=
                    p_multi_atp_tbl (i).ordered_qty;
            END IF;

            lr_atp_rec.quantity_uom (1)             := p_multi_atp_tbl (i).uom;
            lr_atp_rec.requested_ship_date (1)      :=
                p_multi_atp_tbl (i).requested_date;
            lr_atp_rec.action (1)                   := 100;
            lr_atp_rec.source_organization_id (1)   :=
                p_multi_atp_tbl (i).inv_org_id;
            lr_atp_rec.demand_class (1)             :=
                p_multi_atp_tbl (i).demand_class_code;
            lr_atp_rec.oe_flag (1)                  := 'N';
            lr_atp_rec.req_item_detail_flag (1)     := 1;
            lr_atp_rec.insert_flag (1)              := 1;
            lr_atp_rec.attribute_04 (1)             := 1;
            lr_atp_rec.calling_module (1)           := 660;
            x_multi_atp_tbl (i).order_line_id       :=
                p_multi_atp_tbl (i).order_line_id;
            x_multi_atp_tbl (i).inventory_item_id   :=
                p_multi_atp_tbl (i).inventory_item_id;
            x_multi_atp_tbl (i).inv_org_id          :=
                p_multi_atp_tbl (i).inv_org_id;
            x_multi_atp_tbl (i).requested_date      :=
                p_multi_atp_tbl (i).requested_date;
            --x_multi_atp_tbl (i).requested_qty     :=  p_multi_atp_tbl(i).requested_qty;
            x_multi_atp_tbl (i).demand_class_code   :=
                p_multi_atp_tbl (i).demand_class_code;
            x_multi_atp_tbl (i).uom                 :=
                p_multi_atp_tbl (i).uom;

            SAVEPOINT ATPCHECKROLLBACK;                        ----1.1 Version

            ---1.1 Commented and added the below
            /*mrp_atp_pub.call_atp (p_session_id             => ln_session_id,
                                  p_atp_rec                => lr_atp_rec,
                                  x_atp_rec                => x_atp_rec,
                                  x_atp_supply_demand      => x_atp_supply_demand,
                                  x_atp_period             => x_atp_period,
                                  x_atp_details            => x_atp_details,
                                  x_return_status          => x_return_status,
                                  x_msg_data               => x_msg_data,
                                  x_msg_count              => x_msg_count
                                 );*/

            mrp_atp_pub.call_atp_no_commit (
                p_session_id          => ln_session_id,
                p_atp_rec             => lr_atp_rec,
                x_atp_rec             => x_atp_rec,
                x_atp_supply_demand   => x_atp_supply_demand,
                x_atp_period          => x_atp_period,
                x_atp_details         => x_atp_details,
                x_return_status       => x_return_status,
                x_msg_data            => x_msg_data,
                x_msg_count           => x_msg_count);
            DBMS_OUTPUT.put_line ('  x_return_status - ' || x_return_status);

            ROLLBACK TO ATPCHECKROLLBACK;                      ----1.1 Version

            COMMIT;                                              --1.1 Version

            IF (x_return_status = 'S')
            THEN
                -- FOR j IN 1 .. x_atp_rec.inventory_item_id.COUNT
                -- LOOP
                x_multi_atp_tbl (i).error_message       := '';
                x_multi_atp_tbl (i).status              := 'S';
                DBMS_OUTPUT.put_line (
                       ' x_multi_atp_tbl(i).inventory_item_id - '
                    || x_multi_atp_tbl (i).inventory_item_id);
                DBMS_OUTPUT.put_line (
                    ' x_atp_rec.available_quantity (1) - ' || x_atp_rec.available_quantity (1));

                IF x_atp_rec.available_quantity (1) IS NULL
                THEN
                    x_multi_atp_tbl (i).atp   := 0;
                ELSE
                    x_multi_atp_tbl (i).atp   :=
                        x_atp_rec.available_quantity (1);
                END IF;

                IF x_atp_rec.requested_date_quantity (1) IS NULL
                THEN
                    x_multi_atp_tbl (i).requested_qty   := 0;
                ELSE
                    x_multi_atp_tbl (i).requested_qty   :=
                        x_atp_rec.requested_date_quantity (1);
                END IF;

                /* IF p_multi_atp_tbl (i).requested_qty > x_multi_atp_tbl (i).atp
                 THEN
                   DBMS_OUTPUT.put_line (   '---4 --');
                    x_multi_atp_tbl (i).qty_validate_flag := 'Y';
                 ELSE
                   DBMS_OUTPUT.put_line (   '---5 --');
                    x_multi_atp_tbl (i).qty_validate_flag := 'N';
                 END IF;
                 */
                x_multi_atp_tbl (i).qty_validate_flag   := 'N';
                --x_multi_atp_tbl (i).avaiable_date :=   x_atp_rec.req_item_available_date (1);
                x_multi_atp_tbl (i).avaiable_date       :=
                    x_atp_rec.ship_date (1);
                DBMS_OUTPUT.put_line (
                    'x_atp_rec.ERROR_CODE (1) ' || x_atp_rec.ERROR_CODE (1));

                IF (x_atp_rec.ERROR_CODE (1) <> 0)
                THEN
                    SELECT meaning
                      INTO lc_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (1);

                    x_multi_atp_tbl (i).error_message       := lc_error_message;
                    x_multi_atp_tbl (i).qty_validate_flag   := 'Y';
                END IF;
            -- END LOOP;
            ELSE
                lc_error_message                    := NULL;

                FOR j IN 1 .. x_msg_count
                LOOP
                    fnd_msg_pub.get (j, fnd_api.g_false, x_msg_data,
                                     ln_msg_index_out);
                    lc_error_message   :=
                           lc_error_message
                        || (TO_CHAR (j) || ': ' || x_msg_data);
                END LOOP;

                x_multi_atp_tbl (i).error_message   := lc_error_message;
                x_multi_atp_tbl (i).status          := 'E';
            END IF;

            DBMS_OUTPUT.put_line ('Before calling get_atr_onhand_prc ');
            lc_error_message                        := NULL;
            get_atr_onhand_prc (x_qty_atr,
                                x_onhand_qty,
                                lc_error_message,
                                p_multi_atp_tbl (i).inventory_item_id,
                                p_multi_atp_tbl (i).inv_org_id);
            x_multi_atp_tbl (i).onhand              := x_onhand_qty;
            x_multi_atp_tbl (i).atr                 := x_qty_atr;
        END LOOP;

        SELECT SUM (requested_qty), SUM (atr), SUM (onhand)
          INTO x_sum_atp, x_sum_atr, x_sum_onhand
          FROM TABLE (x_multi_atp_tbl);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_message   :=
                   'Exception while checking ATP - '
                || SQLCODE
                || ' -ERROR- '
                || SUBSTR (SQLERRM, 1, 1500);
            x_error_code   := 'E';
    END get_multi_atp_check;

    PROCEDURE get_atr_onhand_prc (x_qty_atr                OUT NUMBER,
                                  v_qty_oh                 OUT NUMBER,
                                  p_msg_data               OUT VARCHAR2,
                                  p_inventory_item_id   IN     NUMBER,
                                  p_organization_id     IN     NUMBER)
    IS
        l_qty_uom             VARCHAR2 (10);
        l_req_date            DATE;
        l_demand_class        VARCHAR2 (80);
        v_api_return_status   VARCHAR2 (1);
        v_qty_res_oh          NUMBER;
        v_qty_res             NUMBER;
        v_qty_sug             NUMBER;
        v_qty_att             NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (4000);
    BEGIN
        inv_quantity_tree_grp.clear_quantity_cache;
        apps.inv_quantity_tree_pub.query_quantities (
            p_api_version_number    => 1,
            p_init_msg_lst          => fnd_api.g_false,
            x_return_status         => v_api_return_status,
            x_msg_count             => v_msg_count,
            x_msg_data              => v_msg_data,
            p_organization_id       => p_organization_id,
            p_inventory_item_id     => p_inventory_item_id,
            p_tree_mode             =>
                apps.inv_quantity_tree_pub.g_transaction_mode,
            --p_onhand_source => APPS.INV_QUANTITY_TREE_PVT.g_all_subs, -3,
            p_is_revision_control   => FALSE,
            p_is_lot_control        => FALSE,
            p_is_serial_control     => FALSE,
            p_revision              => NULL,
            p_lot_number            => NULL,
            p_subinventory_code     => NULL,
            p_locator_id            => NULL,
            x_qoh                   => v_qty_oh,
            x_rqoh                  => v_qty_res_oh,
            x_qr                    => v_qty_res,
            x_qs                    => v_qty_sug,
            x_att                   => v_qty_att,
            x_atr                   => x_qty_atr);

        IF v_qty_oh IS NULL
        THEN
            v_qty_oh   := 0;
        END IF;

        IF x_qty_atr IS NULL
        THEN
            x_qty_atr   := 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20001,
                   'An error was encountered in procedure get_atr_onhand_prc '
                || SQLCODE
                || ' -ERROR- '
                || SQLERRM);
    END get_atr_onhand_prc;

    PROCEDURE get_oe_lines_record (p_header_id IN NUMBER, x_multi_atp_tbl OUT xxd_btom_oeline_atp_tbltype, p_style IN VARCHAR2
                                   ,            --Added by Infosys-26-Aug-2016
                                     p_color IN VARCHAR2 --Added by Infosys-26-Aug-2016
                                                        )
    IS
        CURSOR lcu_get_line (p_header_id   IN NUMBER,
                             p_style       IN VARCHAR2, --Added by Infosys-26-Aug-2016
                             p_color       IN VARCHAR2 --Added by Infosys-26-Aug-2016
                                                      )
        IS
              SELECT header_id, line_id, line_number,
                     inventory_item_id, requested_date, ordered_quantity,
                     ship_from_org_id, color, style,
                     p_size, organization_id, organization_name,
                     avaiable_date, atp, onhand,
                     demand_class_code, demand_class, status,
                     line_status, override_atp_flag, schedule_ship_date,
                     order_uom, line_type_id, attribute1,
                     attribute2, attribute3, attribute4,
                     attribute5
                FROM (SELECT header_id, line_id, line_number,
                             a.inventory_item_id, request_date requested_date, ordered_quantity,
                             ship_from_org_id, b.color, b.style,
                             b.p_size, b.organization_name, b.organization_id,
                             '' avaiable_date, '0' atp, '0' onhand,
                             a.demand_class_code, c.meaning demand_class, 'N' status,
                             --a.flow_status_code line_status,
                             XXD_SALES_ORDER_DEFAULT_PKG.get_line_status_value (a.line_id, a.flow_status_code) line_status, NVL (a.override_atp_date_code, 'N') override_atp_flag, a.schedule_ship_date,
                             a.order_quantity_uom order_uom, a.line_type_id, NULL attribute1,
                             NULL attribute2, NULL attribute3, NULL attribute4,
                             NULL attribute5
                        FROM oe_order_lines_all a,
                             (SELECT /*+leading(mcat,micat) parallel(msi,mcats,ood ) */
                                     DISTINCT mcat.segment1 brand, mcat.segment8 color, mcat.segment7 style,
                                              msi.attribute27 p_size, msi.inventory_item_id, ood.organization_name,
                                              ood.organization_id
                                FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
                                     mtl_system_items_vl msi, org_organization_definitions ood
                               WHERE     mcats.category_set_name = 'Inventory'
                                     AND micat.category_set_id =
                                         mcats.category_set_id
                                     AND micat.category_id = mcat.category_id
                                     AND msi.inventory_item_id =
                                         micat.inventory_item_id
                                     AND msi.organization_id =
                                         micat.organization_id
                                     AND msi.organization_id =
                                         ood.organization_id) b,
                             fnd_lookup_values c
                       WHERE     a.header_id = p_header_id
                             AND b.color = NVL (p_color, b.color) --Added by Infosys-26-Aug-2016
                             AND b.style = NVL (p_style, b.style) --Added by Infosys-26-Aug-2016
                             AND a.inventory_item_id = b.inventory_item_id
                             AND a.ship_from_org_id = b.organization_id
                             AND c.lookup_type = 'DEMAND_CLASS'
                             AND c.LANGUAGE = USERENV ('LANG')
                             AND c.lookup_code = a.demand_class_code)
            --ORDER BY style,color,p_size,line_number DESC;--Added by Infosys-26-Aug-2016
            ORDER BY style ASC,          --Start :Added by Infosys-26-Aug-2016
                                color ASC, p_size ASC,
                     line_number ASC;      --End :Added by Infosys-26-Aug-2016


        ln_cnt   NUMBER := 0;
    BEGIN
        x_multi_atp_tbl   := xxd_btom_oeline_atp_tbltype ();

        FOR lr_get_line IN lcu_get_line (p_header_id, p_style, p_color) --Added by infosys-26-Aug-2016
        LOOP
            ln_cnt                                       := ln_cnt + 1;
            x_multi_atp_tbl.EXTEND (1);
            x_multi_atp_tbl (ln_cnt)                     :=
                xxd_btom_oeline_atp_type (NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL);
            x_multi_atp_tbl (ln_cnt).order_header_id     :=
                lr_get_line.header_id;
            x_multi_atp_tbl (ln_cnt).order_line_id       := lr_get_line.line_id;
            x_multi_atp_tbl (ln_cnt).line_number         :=
                lr_get_line.line_number;
            x_multi_atp_tbl (ln_cnt).inventory_item_id   :=
                lr_get_line.inventory_item_id;
            x_multi_atp_tbl (ln_cnt).inv_org_name        :=
                lr_get_line.organization_name;
            x_multi_atp_tbl (ln_cnt).inv_org_id          :=
                lr_get_line.organization_id;
            x_multi_atp_tbl (ln_cnt).style               := lr_get_line.style;
            x_multi_atp_tbl (ln_cnt).color               := lr_get_line.color;
            x_multi_atp_tbl (ln_cnt).p_size              :=
                lr_get_line.p_size;
            x_multi_atp_tbl (ln_cnt).order_qty           :=
                lr_get_line.ordered_quantity;
            x_multi_atp_tbl (ln_cnt).requested_date      :=
                lr_get_line.requested_date;
            x_multi_atp_tbl (ln_cnt).requested_qty       :=
                lr_get_line.ordered_quantity;
            x_multi_atp_tbl (ln_cnt).avaiable_date       :=
                lr_get_line.avaiable_date;
            x_multi_atp_tbl (ln_cnt).atp                 := lr_get_line.atp;
            x_multi_atp_tbl (ln_cnt).onhand              :=
                lr_get_line.onhand;
            x_multi_atp_tbl (ln_cnt).demand_class_code   :=
                lr_get_line.demand_class_code;
            x_multi_atp_tbl (ln_cnt).demand_class        :=
                lr_get_line.demand_class;
            x_multi_atp_tbl (ln_cnt).status              :=
                lr_get_line.status;
            x_multi_atp_tbl (ln_cnt).line_status         :=
                lr_get_line.line_status;
            x_multi_atp_tbl (ln_cnt).override_atp_flag   :=
                lr_get_line.override_atp_flag;
            x_multi_atp_tbl (ln_cnt).schedule_ship_date   :=
                lr_get_line.schedule_ship_date;
            x_multi_atp_tbl (ln_cnt).order_uom           :=
                lr_get_line.order_uom;
            x_multi_atp_tbl (ln_cnt).line_type_id        :=
                lr_get_line.line_type_id;
            x_multi_atp_tbl (ln_cnt).attribute1          :=
                lr_get_line.attribute1;
            x_multi_atp_tbl (ln_cnt).attribute2          :=
                lr_get_line.attribute2;
            x_multi_atp_tbl (ln_cnt).attribute3          :=
                lr_get_line.attribute3;
            x_multi_atp_tbl (ln_cnt).attribute4          :=
                lr_get_line.attribute4;
            x_multi_atp_tbl (ln_cnt).attribute5          :=
                lr_get_line.attribute5;
        END LOOP;
    END get_oe_lines_record;

    PROCEDURE modify_order (p_header_rec      IN     xxd_btom_oeheader_tbltype,
                            p_line_tbl        IN     xxd_btom_oeline_tbltype,
                            p_user_id         IN     NUMBER,
                            p_resp_id         IN     NUMBER,
                            p_resp_app_id     IN     NUMBER,
                            p_action          IN     VARCHAR2,
                            p_call_from       IN     VARCHAR2,
                            x_error_flag         OUT VARCHAR2,
                            x_error_message      OUT VARCHAR2,
                            p_cancel_code     IN     VARCHAR2 --Added by Infosys-26-Aug-2016
                                                             ,
                            p_cancel_reason   IN     VARCHAR2 --Added by Infosys-26-Aug-2016
                                                             )
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        ln_org_id                      NUMBER;
        ln_line_count                  NUMBER;
        lc_error_message               VARCHAR2 (2000);
        lc_atp_error_msg               VARCHAR2 (4000) := NULL;
        lc_atp_error_flag              VARCHAR2 (10);
        ln_salesrep_cnt                NUMBER;
        ln_salesrep_id                 NUMBER;
        -- INPUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        -- OUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        ln_order_type_id               NUMBER;
        ln_line_type_id                NUMBER;
        ex_exception                   EXCEPTION;
        lc_hold_type                   VARCHAR2 (60);
        l_request_id                   NUMBER;
        lc_flow_status_line            VARCHAR2 (60) := NULL;
        lc_cal_price_flag              VARCHAR2 (10) := NULL;
        lc_qty_update_code             VARCHAR2 (60) := NULL;
        lc_qty_update_meaning          VARCHAR2 (250) := NULL;
        ln_order_qty                   NUMBER := 0;
        l_cancel_code                  VARCHAR2 (250) := p_cancel_code; --Added by Infosys-26-Aug-2016
        l_cancel_reason                VARCHAR2 (250) := p_cancel_reason; --Added by Infosys-26-Aug-2016

        CURSOR lc_get_demand (p_cust_account_id NUMBER)
        IS
            SELECT attribute13
              FROM hz_cust_accounts
             WHERE cust_account_id = p_cust_account_id;

        CURSOR lc_get_qty_update_code IS
            SELECT lookup_code, meaning
              FROM fnd_lookup_values_vl
             WHERE     lookup_type LIKE 'CANCEL_CODE'
                   AND lookup_code IN
                           (SELECT fnd_profile.VALUE ('DO_DOE_UPDATE_QTY') FROM DUAL);
    BEGIN
        -- INITIALIZE ENVIRONMENT
        ln_org_id                       := p_header_rec (1).org_id;
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', ln_org_id);
        mo_global.init ('ONT');
        -- INITIALIZE HEADER RECORD
        l_header_rec                    := oe_order_pub.g_miss_header_rec;
        -- POPULATE REQUIRED ATTRIBUTES
        DBMS_OUTPUT.put_line (
            ' p_header_rec(1).sales_rep_id - ' || ln_salesrep_id);
        l_header_rec.operation          := oe_globals.g_opr_update;
        l_header_rec.header_id          := p_header_rec (1).header_id;
        -- l_header_rec.transactional_curr_code := p_header_rec (1).currency;
        l_header_rec.sold_from_org_id   := p_header_rec (1).org_id;
        -- INITIALIZE ACTION REQUEST RECORD
        l_action_request_tbl (1)        := oe_order_pub.g_miss_request_rec;
        --FETCH LINE COUNT
        ln_line_count                   := p_line_tbl.COUNT;

        --POPULATE LINE ATTRIBUTE
        FOR i IN 1 .. ln_line_count
        LOOP
            lc_flow_status_line                := NULL;
            ln_order_qty                       := 0;
            lc_cal_price_flag                  := NULL;

            IF p_line_tbl (i).line_id IS NOT NULL
            THEN
                SELECT flow_status_code, ordered_quantity, calculate_price_flag
                  INTO lc_flow_status_line, ln_order_qty, lc_cal_price_flag
                  FROM oe_order_lines_all
                 WHERE line_id = p_line_tbl (i).line_id;
            END IF;

            -- INITIALIZE LINE RECORD
            l_line_tbl (i)                     := oe_order_pub.g_miss_line_rec;
            --POPULATE LINE ATTRIBUTE
            l_line_tbl (i).operation           := oe_globals.g_opr_update;
            l_line_tbl (i).header_id           := p_line_tbl (i).header_id;
            l_line_tbl (i).line_id             := p_line_tbl (i).line_id;
            l_line_tbl (i).line_type_id        := p_line_tbl (i).line_type_id;
            l_line_tbl (i).inventory_item_id   :=
                p_line_tbl (i).inventory_item_id;
            l_line_tbl (i).ordered_quantity    := p_line_tbl (i).quantity;
            l_line_tbl (i).ship_from_org_id    := p_line_tbl (i).warehouse_id;
            l_line_tbl (i).demand_class_code   :=
                p_line_tbl (i).demand_class_code;
            l_line_tbl (i).request_date        :=
                p_line_tbl (i).requested_date;
            l_line_tbl (i).override_atp_date_code   :=
                p_line_tbl (i).override_atp_date_code;
            l_line_tbl (i).schedule_ship_date   :=
                p_line_tbl (i).scheduled_date;

            --Start :Added by Infosys-26-Aug-2016
            IF p_line_tbl (i).quantity = 0
            THEN
                l_line_tbl (i).change_reason     := l_cancel_code;
                l_line_tbl (i).change_comments   := l_cancel_reason;
            --End :Added by Infosys-26-Aug-2016

            ELSIF ln_order_qty > p_line_tbl (i).quantity
            THEN
                OPEN lc_get_qty_update_code;

                FETCH lc_get_qty_update_code INTO lc_qty_update_code, lc_qty_update_meaning;

                CLOSE lc_get_qty_update_code;

                l_line_tbl (i).change_reason     := lc_qty_update_code;
                l_line_tbl (i).change_comments   := lc_qty_update_meaning;
            ELSE
                l_line_tbl (i).change_reason   := p_line_tbl (i).reason;
            END IF;
        END LOOP;

        oe_msg_pub.initialize;
        --call standard api
        oe_order_pub.process_order (
            p_org_id                   => ln_org_id,
            p_operating_unit           => NULL,
            p_api_version_number       => ln_api_version_number,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            -- OUT variables
            x_header_rec               => l_header_rec_out,
            x_header_val_rec           => l_header_val_rec_out,
            x_header_adj_tbl           => l_header_adj_tbl_out,
            x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
            x_header_price_att_tbl     => l_header_price_att_tbl_out,
            x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
            x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
            x_header_scredit_tbl       => l_header_scredit_tbl_out,
            x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
            x_line_tbl                 => l_line_tbl_out,
            x_line_val_tbl             => l_line_val_tbl_out,
            x_line_adj_tbl             => l_line_adj_tbl_out,
            x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
            x_line_price_att_tbl       => l_line_price_att_tbl_out,
            x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
            x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
            x_line_scredit_tbl         => l_line_scredit_tbl_out,
            x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
            x_lot_serial_tbl           => l_lot_serial_tbl_out,
            x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
            x_action_request_tbl       => l_action_request_tbl_out,
            x_return_status            => lc_return_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lc_msg_data);

        -- CHECK RETURN STATUS
        IF lc_return_status = fnd_api.g_ret_sts_success
        THEN
            DBMS_OUTPUT.put_line (
                   'Sales Order '
                || l_header_rec_out.order_number
                || ' Successfully Modified');
            x_error_flag   := 'S';
            lc_error_message   :=
                   'Sales Order '
                || l_header_rec_out.order_number
                || ' Successfully Modified';
            x_error_message   :=
                NVL (lc_error_message, '') || x_error_message;
            COMMIT;
        ELSE
            DBMS_OUTPUT.put_line ('Failed to Modify Sales Order');
            x_error_flag      := 'E';

            FOR i IN 1 .. ln_msg_count
            LOOP
                lc_error_message   :=
                       lc_error_message
                    || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            DBMS_OUTPUT.put_line (lc_error_message);
            x_error_message   := lc_error_message;
            ROLLBACK;
        END IF;
    --Calling the workflow Background process to replicate the changes immediatly
    /*  l_request_id :=   fnd_request.submit_request (application      => 'FNDWFBG',
                                                    program          => 'Workflow Background Process',
                                                    argument1        => 'OEOL',
                                                    argument2        => NULL,
                                                    argument3        => NULL,
                                                    argument4        => 'Y',
                                                    argument5        => 'Y'
                                                   );
*/
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Exception in modify order:' || SQLERRM);
            x_error_message   := 'Exception in modify order:' || SQLERRM;
            x_error_flag      := 'E';
    END modify_order;

    PROCEDURE check_invorg_item_define (p_multi_atp_tbl IN XXD_BTOM_MULTI_ATP_TBLTYPE, x_error_message OUT VARCHAR2, x_error_code OUT VARCHAR2)
    IS
        CURSOR lcu_chk_item_count (p_inv_item_id NUMBER, p_inv_org_id NUMBER)
        IS
            SELECT COUNT (*)
              FROM mtl_system_items_b
             WHERE     inventory_item_id = p_inv_item_id
                   AND organization_id = p_inv_org_id;

        ln_count   NUMBER;
    BEGIN
        FOR i IN 1 .. p_multi_atp_tbl.COUNT
        LOOP
            OPEN lcu_chk_item_count (p_multi_atp_tbl (i).inventory_item_id,
                                     p_multi_atp_tbl (i).inv_org_id);

            FETCH lcu_chk_item_count INTO ln_count;

            CLOSE lcu_chk_item_count;

            IF ln_count = 0
            THEN
                EXIT;
            END IF;
        END LOOP;

        IF ln_count = 0
        THEN
            x_error_code   := 'E';
        ELSE
            x_error_code   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_code   := 'E';
            x_error_message   :=
                   'Exception while check_invorg_item_define - '
                || SUBSTR (SQLERRM, 1, 1500);
    END check_invorg_item_define;
END xxd_btom_multi_atp;
/
