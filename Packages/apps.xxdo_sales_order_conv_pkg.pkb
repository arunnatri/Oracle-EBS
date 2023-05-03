--
-- XXDO_SALES_ORDER_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SALES_ORDER_CONV_PKG"
AS
    /***********************************************************************************************
    $Header:  xxdo_sales_order_conv_pkg.sql   1.0    2014/07/07    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    /* NAME:       xxdo_sales_order_conv_pkg
  --
  -- Description  :  This is package Body for Sales Order Conversion
  --
  -- DEVELOPMENT and MAINTENANCE HISTORY

     Ver        Date        Author           Description
     ---------  ----------  ---------------  ------------------------------------
     1.0        18/5/2015      Infosys       1. Created initial version.
  ******************************************************************************/
    /*
    ***********************************************************************************
    * Procedure/Function Name  :  process_order
    ***********************************************************************************
    */

    PROCEDURE process_order (p_out_chr_errbuf       OUT VARCHAR2,
                             p_out_chr_retcode      OUT NUMBER,
                             p_from_whse         IN     VARCHAR2,
                             p_to_whse           IN     VARCHAR2,
                             p_so_number         IN     VARCHAR2,
                             p_line_num          IN     VARCHAR2,
                             p_brand             IN     VARCHAR2,
                             p_gender            IN     VARCHAR2,
                             p_prod_group        IN     VARCHAR2,
                             p_over_ride_flag    IN     VARCHAR2,
                             p_atp_override      IN     VARCHAR2)
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

        lv_to_org_id               NUMBER;
        lv_from_org_id             NUMBER;
        l_cal_num_index            NUMBER := 0;
        l_num_i                    NUMBER;
        l_sch_cal_index            NUMBER := 0;
        l_so_cal_flag_tab          g_so_cal_flag_tab_type;
        l_so_schedule_tab          OE_GLOBALS.Selected_Record_Tbl;

        l_num_current_header       NUMBER := -1;


        lv_user_name               VARCHAR2 (50) := 'BATCH';
        lv_appl_id                 NUMBER;
        lv_resp_id                 NUMBER;
        lv_user_id                 NUMBER;
        lv_responsbility_name      VARCHAR2 (200)
                                       := 'Order Management Super User';

        CURSOR cur_odr_lines (p_from_whse_id NUMBER)
        IS
            SELECT ooh.header_id, ool.line_id, ool.schedule_ship_date,
                   ool.override_atp_date_code, ool.calculate_price_flag, ooh.order_number,
                   ool.flow_status_code, ooh.org_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool, apps.mtl_system_items_b msib,
                   apps.mtl_parameters mp, apps.mtl_item_categories cat, apps.mtl_categories_b mc
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.order_source_id NOT IN (1184, 10) /* Retail,iinternal */
                   AND ooh.order_number = NVL (p_so_number, ooh.order_number)
                   AND ool.ship_from_org_id = p_from_whse_id
                   AND ool.line_number || '.' || ool.shipment_number =
                       NVL (p_line_num,
                            ool.line_number || '.' || ool.shipment_number)
                   AND ool.open_flag = 'Y'
                   AND ooh.open_flag = 'Y'
                   AND ool.ordered_quantity <> 0
                   AND NVL (ool.shipped_quantity, 0) = 0
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = ool.line_id)
                   AND p_so_number IS NOT NULL
                   AND mp.organization_id = p_from_whse_id
                   AND mp.organization_id = msib.organization_id
                   AND ool.inventory_item_id = msib.inventory_item_id
                   AND cat.organization_id = msib.organization_id
                   AND cat.inventory_item_id = msib.inventory_item_id
                   AND cat.category_set_id = 1
                   AND mc.category_id = cat.category_id
                   AND mc.segment1 = NVL (p_brand, mc.segment1)
                   AND mc.segment3 = NVL (p_gender, mc.segment3)
                   AND mc.segment2 = NVL (p_prod_group, mc.segment2)
                   AND p_over_ride_flag = 'Y'
            UNION
            SELECT ooh.header_id, ool.line_id, ool.schedule_ship_date,
                   ool.override_atp_date_code, ool.calculate_price_flag, ooh.order_number,
                   ool.flow_status_code, ooh.org_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.order_source_id NOT IN (1184, 10) /* Retail,internal */
                   AND ooh.order_number = NVL (p_so_number, ooh.order_number)
                   AND ool.ship_from_org_id = p_from_whse_id
                   AND ool.line_number || '.' || ool.shipment_number =
                       NVL (p_line_num,
                            ool.line_number || '.' || ool.shipment_number)
                   AND ool.open_flag = 'Y'
                   AND ooh.open_flag = 'Y'
                   AND ool.ordered_quantity <> 0
                   AND NVL (ool.shipped_quantity, 0) = 0
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = ool.line_id)
                   AND (   p_so_number IS NOT NULL
                        OR EXISTS
                               (SELECT 1
                                  FROM apps.mtl_system_items_b msib, apps.mtl_parameters mp, apps.mtl_item_categories cat,
                                       apps.mtl_categories_b mc, fnd_lookup_values flv
                                 WHERE     1 = 1
                                       AND mp.organization_id =
                                           p_from_whse_id
                                       AND mp.organization_id =
                                           msib.organization_id
                                       AND ool.inventory_item_id =
                                           msib.inventory_item_id
                                       AND cat.organization_id =
                                           msib.organization_id
                                       AND cat.inventory_item_id =
                                           msib.inventory_item_id
                                       AND cat.category_set_id = 1
                                       AND mc.category_id = cat.category_id
                                       AND flv.lookup_type =
                                           'XXDO_US1_BRANDS'
                                       AND flv.LANGUAGE = 'US'
                                       AND flv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1)
                                       AND ((mc.segment1 || '-' || mc.segment3 || '-' || mp.organization_code = flv.meaning AND flv.tag IS NULL) OR (mc.segment1 || '-' || mc.segment2 || '-' || mp.organization_code = flv.meaning AND flv.tag = 'PRODUCTGROUP'))))
                   AND p_over_ride_flag = 'N'
            ORDER BY 1, 2;

        l_atp_tbl                  OE_ATP.Atp_Tbl_Type;
        l_new_return_status        VARCHAR2 (30);
        l_new_msg_count            NUMBER;
        l_new_msg_data             VARCHAR2 (2000);
        l_new_index_out            NUMBER;
        lv_mo_resp_id              NUMBER;
        lv_mo_resp_appl_id         NUMBER;
        lv_num_first               NUMBER := 0;
        lv_org_exists              NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Beginning of the program ');

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
               'Responsbility Name and Id '
            || lv_responsbility_name
            || '-'
            || lv_resp_id);

        fnd_global.apps_initialize (user_id        => lv_user_id,
                                    resp_id        => lv_resp_id,
                                    resp_appl_id   => lv_appl_id);

        BEGIN
            SELECT organization_id
              INTO lv_to_org_id
              FROM mtl_parameters
             WHERE organization_code = p_to_whse;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_to_org_id   := NULL;
        END;

        BEGIN
            SELECT organization_id
              INTO lv_from_org_id
              FROM mtl_parameters
             WHERE organization_code = p_from_whse;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_from_org_id   := NULL;
        END;

        IF l_so_cal_flag_tab.EXISTS (1)
        THEN
            l_so_cal_flag_tab.DELETE;
        END IF;

        IF l_so_schedule_tab.EXISTS (1)
        THEN
            l_so_schedule_tab.DELETE;
        END IF;

        IF l_line_tbl.EXISTS (1)
        THEN
            l_line_tbl.DELETE;
        END IF;

        IF l_request_tbl.EXISTS (1)
        THEN
            l_request_tbl.DELETE;
        END IF;

        IF p_from_whse = p_to_whse
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'From and to warehouses are same.. cannot proceed');
        ELSE
            l_num_current_header   := -1;
            l_num_index            := 0;
            l_cal_num_index        := 0;

            FOR cur_odr_lines_rec IN cur_odr_lines (lv_from_org_id)
            LOOP
                IF l_num_current_header <> cur_odr_lines_rec.header_id
                THEN
                    /* process previous header */


                    IF l_num_index > 0
                    THEN
                        oe_order_pub.process_order (
                            p_api_version_number     => 1.0,
                            p_init_msg_list          => fnd_api.g_true,
                            p_return_values          => fnd_api.g_true,
                            p_action_commit          => fnd_api.g_true,
                            x_return_status          => l_chr_poapi_ret_status,
                            x_msg_count              => l_num_msg_cnt,
                            x_msg_data               => l_chr_msg_data,
                            p_header_rec             => l_header_rec,
                            p_line_tbl               => l_line_tbl,
                            p_old_line_tbl           => l_old_line_tbl,
                            x_header_rec             => l_header_rec,
                            x_header_val_rec         => l_header_val_rec,
                            x_header_adj_tbl         => l_header_adj_tbl,
                            x_header_adj_val_tbl     => l_header_adj_val_tbl,
                            x_header_price_att_tbl   => l_header_price_att_tbl,
                            x_header_adj_att_tbl     => l_header_adj_att_tbl,
                            x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl,
                            x_header_scredit_tbl     => l_header_scredit_tbl,
                            x_header_scredit_val_tbl   =>
                                l_header_scredit_val_tbl,
                            x_line_tbl               => out_tab_proc_line,
                            x_line_val_tbl           => l_line_val_tbl,
                            x_line_adj_tbl           => l_line_adj_tbl,
                            x_line_adj_val_tbl       => l_line_adj_val_tbl,
                            x_line_price_att_tbl     => l_line_price_att_tbl,
                            x_line_adj_att_tbl       => l_line_adj_att_tbl,
                            x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl,
                            x_line_scredit_tbl       => l_line_scredit_tbl,
                            x_line_scredit_val_tbl   => l_line_scredit_val_tbl,
                            x_lot_serial_tbl         => l_lot_serial_tbl,
                            x_lot_serial_val_tbl     => l_lot_serial_val_tbl,
                            x_action_request_tbl     => l_request_tbl);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Process Order API Return Status :'
                            || l_chr_poapi_ret_status);
                        COMMIT;

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
                                       'Error '
                                    || l_num_msg_index_out
                                    || ' Is: '
                                    || l_chr_msg_data);
                            END LOOP;
                        END IF;

                        /* reset new header values */
                        l_num_current_header   := cur_odr_lines_rec.header_id;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Next Order Number ' || cur_odr_lines_rec.order_number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Next Header Id ' || l_num_current_header);
                        l_num_index            := 0;
                        l_cal_num_index        := 0;

                        IF l_line_tbl.EXISTS (1)
                        THEN
                            l_line_tbl.DELETE;
                        END IF;

                        IF l_request_tbl.EXISTS (1)
                        THEN
                            l_request_tbl.DELETE;
                        END IF;
                    END IF;                     ---END IF  for l_num_index > 0
                END IF;

                --END if for   l_num_current_header <> cur_odr_lines_rec.header_id
                l_num_index                                          := l_num_index + 1;
                l_cal_num_index                                      := l_cal_num_index + 1;
                l_num_current_header                                 := cur_odr_lines_rec.header_id;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Index values : - l_num_index: ' || l_num_index);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Index values :- l_cal_num_index: ' || l_cal_num_index);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Current Header ID: ' || cur_odr_lines_rec.header_id);
                l_so_cal_flag_tab (l_cal_num_index).cal_price_flag   :=
                    cur_odr_lines_rec.calculate_price_flag;
                l_so_cal_flag_tab (l_cal_num_index).override_atp_date_code   :=
                    cur_odr_lines_rec.override_atp_date_code;
                l_so_cal_flag_tab (l_cal_num_index).header_id        :=
                    cur_odr_lines_rec.header_id;
                l_so_cal_flag_tab (l_cal_num_index).line_id          :=
                    cur_odr_lines_rec.line_id;

                IF (cur_odr_lines_rec.flow_status_code = 'BOOKED' AND NVL (p_atp_override, 'N') = 'N') /*Booked Orders schdule line*/
                THEN
                    l_sch_cal_index   := l_sch_cal_index + 1;
                    l_so_schedule_tab (l_sch_cal_index).id1   :=
                        cur_odr_lines_rec.line_id;
                    l_so_schedule_tab (l_sch_cal_index).org_id   :=
                        cur_odr_lines_rec.org_id;
                END IF;

                l_line_tbl (l_num_index)                             :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (l_num_index).header_id                   :=
                    cur_odr_lines_rec.header_id;
                l_line_tbl (l_num_index).line_id                     :=
                    cur_odr_lines_rec.line_id;
                l_line_tbl (l_num_index).calculate_price_flag        := 'N';
                l_line_tbl (l_num_index).ship_from_org_id            :=
                    lv_to_org_id;
                l_line_tbl (l_num_index).last_update_login           :=
                    fnd_global.login_id;
                l_line_tbl (l_num_index).last_updated_by             :=
                    fnd_global.user_id;
                l_line_tbl (l_num_index).last_update_date            :=
                    SYSDATE;
                l_line_tbl (l_num_index).operation                   :=
                    oe_globals.g_opr_update;

                IF     cur_odr_lines_rec.schedule_ship_date IS NOT NULL
                   AND NVL (p_atp_override, 'N') = 'Y'
                THEN
                    l_line_tbl (l_num_index).override_atp_date_code   := 'Y';
                END IF;
            --  END IF;
            --  lv_num_first := lv_num_first + 1;
            -- lv_org_exists := cur_odr_lines_rec.org_id;
            END LOOP;

            IF l_num_index > 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Calling Process order API At End');

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
                       'Process Order API Return Status :'
                    || l_chr_poapi_ret_status);
                COMMIT;

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
                               'Error '
                            || l_num_msg_index_out
                            || ' Is: '
                            || l_chr_msg_data);
                    END LOOP;
                END IF;                                 /* l_num_msg_cnt > 0*/
            END IF;

            FOR l_num_i IN 1 .. l_so_cal_flag_tab.COUNT
            LOOP
                BEGIN
                    UPDATE oe_order_lines_all
                       SET calculate_price_flag = l_so_cal_flag_tab (l_num_i).cal_price_flag, override_atp_date_code = l_so_cal_flag_tab (l_num_i).override_atp_date_code
                     WHERE     header_id =
                               l_so_cal_flag_tab (l_num_i).header_id
                           AND line_id = l_so_cal_flag_tab (l_num_i).line_id;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Updated Cal Flag: '
                        || l_so_cal_flag_tab (l_num_i).cal_price_flag
                        || ' for Header ID: '
                        || l_so_cal_flag_tab (l_num_i).header_id
                        || ' for Line ID: '
                        || l_so_cal_flag_tab (l_num_i).line_id);
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error While updating SO Line '
                            || l_so_cal_flag_tab (l_num_i).line_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error While updating SO Line  ' || SQLERRM);
                END;
            END LOOP;
        END IF;

        /*Calling Schedule Line API*/
        IF l_sch_cal_index > 0
        THEN
            OE_GROUP_SCH_UTIL.Schedule_Multi_lines (
                p_selected_line_tbl   => l_so_schedule_tab,
                p_line_count          => 1,
                p_sch_action          => 'SCHEDULE',
                x_atp_tbl             => l_atp_tbl,
                x_return_status       => l_new_return_status,
                x_msg_count           => l_new_msg_count,
                x_msg_data            => l_new_msg_data);
            COMMIT;
            DBMS_OUTPUT.put_line (
                   'OM Debug file: '
                || oe_debug_pub.g_dir
                || '/'
                || oe_debug_pub.g_file);

            fnd_file.put_line (
                fnd_file.LOG,
                'Scheduling API Return Status :' || l_new_return_status);

            FOR i IN 1 .. l_new_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_new_msg_data
                                , p_msg_index_out => l_new_index_out);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error message is: ' || l_new_msg_data);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error message index is: ' || l_new_index_out);
            END LOOP;

            -- Check the return status
            IF l_new_return_status = fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Scheduling is Successful');
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Scheduling Failed');
            END IF;
        END IF;                                     /* from and to wh check */
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Process Order API Error: ' || SQLERRM);
            ROLLBACK;
            p_out_chr_retcode   := 2;
            p_out_chr_errbuf    := SQLERRM;
    END process_order;
END xxdo_sales_order_conv_pkg;
/
