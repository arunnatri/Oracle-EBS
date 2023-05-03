--
-- XXD_ONT_ECOMM_CALC_TAX_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_ECOMM_CALC_TAX_PKG"
--****************************************************************************************************
--*  NAME       : XXD_ONT_ECOMM_CALC_TAX_PKG
--*  APPLICATION: Oracle Order Management
--*
--*  AUTHOR     : Gaurav Joshi
--*  DATE       : 14-Jan-2018
--*
--*  DESCRIPTION: This package will do the following
--*               A. Do recalculate tax on eCOM Order(s) based on the i/p params.
--*  REVISION HISTORY:
--*  Change Date     Version             By              Change Description
--****************************************************************************************************
--* 14-Jan-2018      1.0           Gaurav Joshi       Initial Creation
--****************************************************************************************************
IS
    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER, -- mandatory
                                                                                                       p_order_source IN NUMBER, p_no_of_days IN NUMBER, --  mandatory
                                                                                                                                                         p_order_number IN NUMBER
                            ,                                      -- optional
                              p_mode IN NUMBER                    --  optional
                                              )
    IS
        v_api_version_number            NUMBER := 1;
        v_return_status                 VARCHAR2 (2000);
        v_msg_count                     NUMBER;
        v_msg_data                      VARCHAR2 (2000);

        -- IN Variables --
        v_header_rec                    oe_order_pub.header_rec_type;
        v_line_tbl                      oe_order_pub.line_tbl_type;
        v_action_request_tbl            oe_order_pub.request_tbl_type;
        v_line_adj_tbl                  oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out                oe_order_pub.header_rec_type;
        v_header_val_rec_out            oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out            oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out        oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out      oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out        oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out      oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out        oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out    oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                  oe_order_pub.line_tbl_type;
        v_line_val_tbl_out              oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out              oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out          oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out        oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out          oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out        oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out          oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out      oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out            oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out        oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out        oe_order_pub.request_tbl_type;
        l_day_of_date_without_add_sec   NUMBER;
        l_day_of_date_with_add_sec      NUMBER;
        l_tax_date_with_added_sec       DATE;
        l_tax_date_with_sub_sec         DATE;
        l_om_tv_before_api_call         NUMBER;
        l_om_tv_after_api_call          NUMBER;
        l_ecomm_tv                      NUMBER;
        l_order_number                  NUMBER;
        l_line_id                       NUMBER;
        l_debug_level                   NUMBER := 5;
        l_debug_file                    VARCHAR2 (2000);
        l_level                         NUMBER;
        l_debug_mode                    VARCHAR2 (200);
        l_line_num                      NUMBER;
        l_count                         NUMBER := 0;
        l_msg_index_out                 NUMBER;
        l_error_message                 VARCHAR2 (4000);

        CURSOR c_get_eligible_orders IS
            (SELECT ol.flow_status_code line_status, ol.line_number || '.' || ol.shipment_number line_num, ol.tax_date,
                    ol.header_id, oh.order_number, ol.line_id,
                    ol.tax_value order_line_tax, ol.tax_line_value, ool.tax_value ecomm_tax_value
               FROM do_om.do_order_lines ool, apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
              WHERE     ool.org_id = p_operating_unit                 -- input
                    AND ool.orig_sys_document_ref = ol.orig_sys_document_ref
                    AND ool.org_id = ol.org_id
                    AND ol.org_id = p_operating_unit                  -- input
                    AND ool.ship_to_org_id = ol.ship_to_org_id
                    AND ool.sold_to_org_id = ol.sold_to_org_id
                    AND oh.header_id = ol.header_id
                    AND oh.org_id = p_operating_unit                  -- input
                    AND oh.open_flag = 'Y'
                    AND ol.line_number = ool.line_number
                    AND ol.inventory_item_id = ool.inventory_item_id
                    AND ol.tax_value <> ool.tax_value
                    AND ol.tax_value <> 0
                    AND ol.ordered_quantity = ool.ordered_quantity
                    AND ol.actual_shipment_date IS NULL -- will ignore Shipped and Invoiced lines
                    AND ol.open_flag = 'Y'                    -- Ignore Closed
                    AND ol.order_source_id = p_order_source           -- input
                    AND ((p_order_number IS NOT NULL AND oh.order_number = p_order_number) OR (p_order_number IS NULL AND ool.creation_date >= (TRUNC (SYSDATE - p_no_of_days) - INTERVAL '1' SECOND))));
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Concurrent Program Parameters:');
        fnd_file.put_line (fnd_file.LOG,
                           ' p_operating_unit:' || p_operating_unit);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_order_source:' || p_order_source);
        fnd_file.put_line (fnd_file.LOG, ' p_no_of_days:' || p_no_of_days);
        fnd_file.put_line (
            fnd_file.LOG,
               ' Order Created After MidNight of :'
            || (TRUNC (SYSDATE - p_no_of_days) - INTERVAL '1' SECOND));
        fnd_file.put_line (fnd_file.LOG,
                           ' p_order_number:' || p_order_number);
        fnd_file.put_line (fnd_file.LOG, ' p_debug_level:' || p_mode);
        fnd_file.put_line (fnd_file.LOG, ' User Id:' || fnd_global.user_id);
        fnd_file.put_line (fnd_file.LOG, ' Resp Id:' || fnd_global.resp_id);
        fnd_file.put_line (fnd_file.LOG,
                           ' Resp Appl Id:' || fnd_global.resp_appl_id);

        mo_global.init ('ONT');
        oe_msg_pub.delete_msg;
        oe_msg_pub.initialize;
        mo_global.set_policy_context ('S', p_operating_unit);
        fnd_global.apps_initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);

        IF (p_mode IS NOT NULL)
        THEN
            IF p_mode > 5
            THEN
                l_level   := 5;
            ELSE
                l_level   := p_mode;
            END IF;

            -- Enable OM Debug
            oe_debug_pub.debug_on;
            oe_debug_pub.setdebuglevel (l_level);
            l_debug_mode   := oe_debug_pub.set_debug_mode ('CONC');
        END IF;

        FOR i IN c_get_eligible_orders
        LOOP
            l_error_message                := '';
            l_count                        := l_count + 1;

            -- PRINT HEADER ONLY WHEN THERE ATLEAST A RECORD
            IF l_count = 1
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                    'ORDER_NUMER~LINE_ID~LINE_NUM~TAX_VALUE_BEFORE~TAX_VALUE_ATER~ECOMM_TAX_VALUE~STATUS~MESSAGE');
            END IF;

            IF l_level IS NOT NULL
            THEN
                oe_debug_pub.add (
                       ' *******Begin: Debugging Order Number:'
                    || i.order_number
                    || ' AND Line Number:'
                    || i.line_num
                    || '********');
            END IF;

            l_om_tv_before_api_call        := i.order_line_tax;
            l_ecomm_tv                     := i.ecomm_tax_value;
            l_order_number                 := i.order_number;
            l_line_id                      := i.line_id;
            l_line_num                     := i.line_num;

            SELECT EXTRACT (DAY FROM tax_date), EXTRACT (DAY FROM tax_date + INTERVAL '1' SECOND), (tax_date + INTERVAL '1' SECOND),
                   (tax_date - INTERVAL '1' SECOND)
              INTO l_day_of_date_without_add_sec, l_day_of_date_with_add_sec, l_tax_date_with_added_sec, l_tax_date_with_sub_sec
              FROM oe_order_lines_all
             WHERE line_id = i.line_id;

            v_action_request_tbl (1)       := oe_order_pub.g_miss_request_rec;
            -- Line Record --
            v_line_tbl (1)                 := oe_order_pub.g_miss_line_rec;
            v_line_tbl (1).header_id       := i.header_id; -- Existing order header id
            v_line_tbl (1).line_id         := i.line_id;           --  line id
            v_line_tbl (1).operation       := oe_globals.g_opr_update;
            v_line_tbl (1).change_reason   := 'MANUAL';

            /** Begin: Block to add or subract one sec to the existing tax date such that
           existing  tax date wont change to next day.
           for instance: 12-Dec-2018 11:59:59PM. in this case adding sec to the existing
           tax date will change the day to 13-Dec and might cause different tax rate.
            **/
            IF l_day_of_date_without_add_sec = l_day_of_date_with_add_sec
            THEN               -- day remains same even after adding sec to it
                v_line_tbl (1).tax_date   := l_tax_date_with_added_sec;
            ELSE
                --tax date is changing by adding sec to it. subract sec from the current tax date
                v_line_tbl (1).tax_date   := l_tax_date_with_sub_sec;
            END IF;

            oe_order_pub.process_order (
                p_org_id                   => p_operating_unit,
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl, -- OUT variables
                x_header_rec               => v_header_rec_out,
                x_header_val_rec           => v_header_val_rec_out,
                x_header_adj_tbl           => v_header_adj_tbl_out,
                x_header_adj_val_tbl       => v_header_adj_val_tbl_out,
                x_header_price_att_tbl     => v_header_price_att_tbl_out,
                x_header_adj_att_tbl       => v_header_adj_att_tbl_out,
                x_header_adj_assoc_tbl     => v_header_adj_assoc_tbl_out,
                x_header_scredit_tbl       => v_header_scredit_tbl_out,
                x_header_scredit_val_tbl   => v_header_scredit_val_tbl_out,
                x_line_tbl                 => v_line_tbl_out,
                x_line_val_tbl             => v_line_val_tbl_out,
                x_line_adj_tbl             => v_line_adj_tbl_out,
                x_line_adj_val_tbl         => v_line_adj_val_tbl_out,
                x_line_price_att_tbl       => v_line_price_att_tbl_out,
                x_line_adj_att_tbl         => v_line_adj_att_tbl_out,
                x_line_adj_assoc_tbl       => v_line_adj_assoc_tbl_out,
                x_line_scredit_tbl         => v_line_scredit_tbl_out,
                x_line_scredit_val_tbl     => v_line_scredit_val_tbl_out,
                x_lot_serial_tbl           => v_lot_serial_tbl_out,
                x_lot_serial_val_tbl       => v_lot_serial_val_tbl_out,
                x_action_request_tbl       => v_action_request_tbl_out,
                x_return_status            => v_return_status,
                x_msg_count                => v_msg_count,
                x_msg_data                 => v_msg_data);


            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                v_msg_data   := 'Process Order API completed Successfully';
            ELSE
                IF v_return_status <> fnd_api.g_ret_sts_success
                THEN
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => v_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        l_error_message   := l_error_message || v_msg_data;
                    END LOOP;
                END IF;
            END IF;

            SELECT tax_value
              INTO l_om_tv_after_api_call
              FROM oe_order_lines_all
             WHERE line_id = l_line_id;

            fnd_file.put_line (
                fnd_file.output,
                (l_order_number || '~' || l_line_id || '~' || l_line_num || '~' || l_om_tv_before_api_call || '~' || l_om_tv_after_api_call || '~' || l_ecomm_tv || '~' || v_return_status || '~' || l_error_message));

            IF l_level IS NOT NULL
            THEN
                oe_debug_pub.add (
                       ' *******End :Debugging Order Number:'
                    || i.order_number
                    || ' AND Line Number:'
                    || i.line_num
                    || '********');
            END IF;
        END LOOP;

        --  NO RECORD TO PROCESS.
        IF l_count = 0
        THEN
            fnd_file.put_line (fnd_file.output,
                               ' No Eligible Record to Process');
        END IF;
    END;
END XXD_ONT_ECOMM_CALC_TAX_PKG;
/
