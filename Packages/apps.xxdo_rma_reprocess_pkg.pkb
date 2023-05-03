--
-- XXDO_RMA_REPROCESS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_RMA_REPROCESS_PKG"
IS
    /** ****************************************************************************
     Package Name        :  XXDO_RMA_REPROCESS_PKG

     Description         :  This Package will used to Cretae New line in RTI and Reprocess RTI Stuck Records

      -- DEVELOPMENT and MAINTENANCE HISTORY

      Date            author             Version  Description
      --------------------------------
     2017/02/14     Infosys            1.0  Initial Version.
     2017/05/18     Infosys            1.1  Group ID update modified, Hdr Intf ID modified

    ***************************************************************************/
    /** ****************************************************************************
      -- Procedure Name      :  get_resp_details
      --
      -- Description         :  This procedure is used to get the responsibility details

      --
      -- DEVELOPMENT and MAINTENANCE HISTORY
      --
      -- date          author             Version  Description
      -- ------------  -----------------  -------
      -- 2017/02/14    Infosys            1.0      Initial Version.
      --
      --
      ***************************************************************************/
    PROCEDURE get_resp_details (p_org_id         IN     NUMBER,
                                p_resp_id           OUT NUMBER,
                                p_resp_appl_id      OUT NUMBER)
    IS
        lv_mo_resp_id        NUMBER;
        lv_mo_resp_appl_id   NUMBER;
        lv_const_ou_name     VARCHAR2 (200);
        lv_var_ou_name       VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT resp.responsibility_id, resp.application_id
              INTO lv_mo_resp_id, lv_mo_resp_appl_id
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

        p_resp_id        := lv_mo_resp_id;
        p_resp_appl_id   := lv_mo_resp_appl_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END get_resp_details;

    /** ****************************************************************************
     -- Procedure Name      :  XXDO_CALLING_API
     --
     -- Description         :  This procedure is used to create the New line in Lines table for Existing RMA

     --
     -- DEVELOPMENT and MAINTENANCE HISTORY
     --
     -- date          author             Version  Description
     -- ------------  -----------------  -------
     -- 2017/02/14    Infosys            1.0  Initial Version.
     --
     --
     ***************************************************************************/

    PROCEDURE XXDO_CALLING_API (P_header_id             NUMBER,
                                P_organization_id       VARCHAR2,
                                P_qty                   NUMBER,
                                P_org_id                NUMBER,
                                P_item_id               NUMBER,
                                P_new_line_id       OUT NUMBER)
    IS
        lv_procedure                   VARCHAR2 (100) := 'create_unplan_rma_line';
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

        p_error_message                VARCHAR2 (1000);
        p_return_status                NUMBER;
        l_num_resp_id                  NUMBER;
        l_num_resp_appl_id             NUMBER;
        l_org_id                       NUMBER;
    BEGIN
        p_error_message                                    := NULL;
        p_return_status                                    := 0;
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************Input Parametrs for Line Creation');
        fnd_file.put_line (fnd_file.LOG,
                           'P_header_id       =>' || P_header_id);
        fnd_file.put_line (fnd_file.LOG,
                           'P_organization_id =>' || P_organization_id);
        fnd_file.put_line (fnd_file.LOG, 'P_qty             =>' || P_qty);
        fnd_file.put_line (fnd_file.LOG, 'P_org_id          =>' || P_org_id);
        fnd_file.put_line (fnd_file.LOG, 'P_item_id         =>' || P_item_id);
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        x_debug_file                                       := oe_debug_pub.set_debug_mode ('FILE');
        oe_debug_pub.setdebuglevel (5);
        fnd_file.put_line (fnd_file.LOG, 'Begining of Process Order API');


        l_line_tbl_index                                   := 1;
        l_line_tbl (l_line_tbl_index)                      := oe_order_pub.g_miss_line_rec;
        l_line_tbl (l_line_tbl_index).header_id            := P_header_id;
        --Mandatory fields like qty, inventory item id are to be passed
        fnd_file.put_line (fnd_file.LOG, 'Deriving Values');


        SELECT oe_order_lines_s.NEXTVAL
          INTO l_line_tbl (l_line_tbl_index).line_id
          FROM DUAL;

        BEGIN
            SELECT organization_id
              INTO l_line_tbl (l_line_tbl_index).ship_from_org_id
              FROM mtl_parameters
             WHERE organization_id = P_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error message while getting organization id' || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'Organization id '
            || l_line_tbl (l_line_tbl_index).ship_from_org_id);

        /*SELECT org_id
          INTO p_header_rec.org_id
          FROM oe_order_lines_all
         WHERE header_id = c_det_unplan_rec.header_id AND ROWNUM = 1; */
        BEGIN
            SELECT order_type_id
              INTO p_header_rec.order_type_id
              FROM oe_order_headers_all
             WHERE header_id = P_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (
                    'Error while getting Order_type_id' || SQLERRM);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while getting Order_type_id' || SQLERRM);
        END;

        /* 10/1 - create unplanned RMA line with shipment 2 so it wont get extracted again */
        /*Start with UNPLAN_NULL*/
        l_num_rma_line_number                              := 0;

        BEGIN
            SELECT MAX (TO_NUMBER (line_number))
              INTO l_num_rma_line_number
              FROM oe_order_lines_all
             WHERE header_id = P_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (
                       'Error while fetching line number for order header :'
                    || SQLERRM);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while fetching line number for order header :'
                    || ''
                    || ' '
                    || SQLERRM);
        END;


        l_line_tbl (l_line_tbl_index).line_number          :=
            NVL (l_num_rma_line_number, 0) + 1;
        l_line_tbl (l_line_tbl_index).shipment_number      := 2;


        /*Ends with UNPLAN_NULL*/

        -- apps.fnd_global.apps_initialize ( 0,50746,660);
        /* apps.fnd_global.apps_initialize ( user_id => fnd_profile.VALUE ('USER_ID'),
                                      resp_id => fnd_profile.VALUE ('RESP_ID'),
                                      resp_appl_id => fnd_profile.VALUE ('RESP_APPL_ID'));*/

        SELECT org_id
          INTO l_org_id
          FROM apps.oe_order_headers_all a
         WHERE header_id = P_header_id;

        get_resp_details (l_org_id, l_num_resp_id, l_num_resp_appl_id);
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
        --   mo_global.init ('ONT');



        /*OU_BUG issue*/
        --   mo_global.set_policy_context ('S', p_header_rec.org_id);
        l_line_tbl (l_line_tbl_index).ordered_quantity     := P_qty;
        l_line_tbl (l_line_tbl_index).org_id               := P_org_id;
        l_line_tbl (l_line_tbl_index).inventory_item_id    := P_item_id;
        --   := pu_line_tbl (l_line_tbl_index).ship_from_org_id;
        --l_line_tbl (l_line_tbl_index).subinventory :=c_det_unplan_rec.host_subinventory;

        l_line_tbl (l_line_tbl_index).return_reason_code   := 'UAR - 0010';

        --  msg ('Customer return reason'|| l_line_tbl (l_line_tbl_index).return_reason_code);

        l_line_tbl (l_line_tbl_index).flow_status_code     :=
            'AWAITING_RETURN';

        -- msg ('p_header_rec.order_type_id' || p_header_rec.order_type_id);
        --msg (' p_header_rec.org_id' || c_det_unplan_rec.org_id);

        BEGIN
            SELECT default_inbound_line_type_id
              INTO l_line_tbl (l_line_tbl_index).line_type_id
              FROM oe_transaction_types_all
             WHERE     transaction_type_id = p_header_rec.order_type_id
                   AND org_id = P_org_id;
        -- msg ('Line type id ' || l_line_tbl (l_line_tbl_index).line_type_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_line_tbl (l_line_tbl_index).line_type_id   := NULL;
        END;

        /*--added for version 1.1*/
        -- l_line_tbl (l_line_tbl_index).attribute12 := c_det_unplan_rec.damage_code;                           --Added for Damege code
        l_line_tbl (l_line_tbl_index).operation            :=
            oe_globals.g_opr_create;
        DBMS_OUTPUT.put_line ('Calling process order API');
        fnd_file.put_line (fnd_file.LOG, 'Calling process order API');
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
        fnd_file.put_line (fnd_file.LOG, 'After API');
        -- Retrieve messages
        fnd_file.put_line (fnd_file.LOG,
                           'API return Status' || l_return_status);
        -- dbms_output.put_line('l_return_status'||l_return_status);
        fnd_file.put_line (fnd_file.LOG, 'error message is ' || l_msg_data);
        fnd_file.put_line (fnd_file.LOG,
                           'New Line_id ' || lv_line_tbl (1).line_id);

        fnd_file.put_line (fnd_file.LOG, 'Order Line msg' || l_msg_count);

        --dbms_output.put_line ('Order Line msg' || l_msg_count);

        IF l_return_status <> 'S'
        THEN
            FOR k IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => k, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => lv_next_msg);
                fnd_file.put_line (fnd_file.LOG, 'message is:' || l_msg_data);
                DBMS_OUTPUT.put_line ('l_msg_data' || l_msg_data);
            END LOOP;
        ELSE
            P_new_line_id   := lv_line_tbl (1).line_id;
            DBMS_OUTPUT.put_line (
                'Line careted successfully' || lv_line_tbl (1).line_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Unknown Error Message ' || SQLERRM);
    END;

    /*****************************************************************************************************/
    /** ****************************************************************************
      -- Procedure Name      :  XXDO_RTI_INSERT
      --
      -- Description         :  This procedure is used to Create the new line in RCV_HEADERS_INTERFACE,RCV_TRANSACTIONS_INTERFACE tables

      --
      -- DEVELOPMENT and MAINTENANCE HISTORY
      --
      -- date          author             Version  Description
      -- ------------  -----------------  -------
      -- 2017/02/14    Infosys            1.0      Initial Version.
      --
      --
      ***************************************************************************/
    PROCEDURE XXDO_RTI_INSERT (P_CUSTOMER_ID NUMBER, P_RECEIPT_SOURCE_CODE VARCHAR2, P_ORG_ID NUMBER, P_UNIT_OF_MEASURE VARCHAR2, P_ITEM_ID NUMBER, P_TO_ORGANIZATION_ID NUMBER, P_SOURCE_DOCUMENT_CODE VARCHAR2, P_LOCATION_ID NUMBER, P_DELIVER_TO_LOCATION_ID NUMBER, P_SUBINVENTORY VARCHAR2, P_EXPECTED_RECEIPT_DATE DATE, P_LOCATOR_ID NUMBER, P_HEADER_ID NUMBER, P_CUSTOMER_SITE_ID NUMBER, P_QTY NUMBER
                               , P_LINE_ID NUMBER, P_SHIPMENT_HEADER_ID NUMBER, P_SHIPMENT_NUM VARCHAR2)
    IS
        lv_first             NUMBER;
        l_hdr_interface_id   NUMBER;
        l_ship_header_id     NUMBER := 0;
        l_group_id           NUMBER;
    BEGIN
        BEGIN
            fnd_file.put_line (fnd_file.LOG,
                               'Shipment Number' || P_SHIPMENT_NUM);

            SELECT DISTINCT SHIPMENT_HEADER_ID
              INTO l_ship_header_id
              FROM apps.rcv_shipment_headers
             WHERE shipment_num = P_SHIPMENT_NUM AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Unable to get Shipment_header_id');
        END;


        SELECT apps.rcv_interface_groups_s.NEXTVAL INTO lv_first FROM DUAL;

        SELECT apps.rcv_headers_interface_s.NEXTVAL
          INTO l_hdr_interface_id
          FROM DUAL;

        fnd_file.put_line (fnd_file.LOG, 'Inserting Headers table');

        INSERT INTO rcv_headers_interface (CUSTOMER_ID,
                                           HEADER_INTERFACE_ID,
                                           GROUP_ID,
                                           RECEIPT_SOURCE_CODE,
                                           EXPECTED_RECEIPT_DATE,
                                           processing_status_code,
                                           validation_flag,
                                           transaction_type,
                                           AUTO_TRANSACT_CODE,
                                           CREATED_BY,
                                           LAST_UPDATED_BY,
                                           CREATION_DATE,
                                           LAST_UPDATE_DATE,
                                           LAST_UPDATE_LOGIN)
             VALUES (P_CUSTOMER_ID, l_hdr_interface_id, lv_first,
                     P_RECEIPT_SOURCE_CODE, NULL,                        --TBD
                                                  'PENDING',
                     'Y', 'RECEIVE', 'DELIVER',
                     apps.fnd_global.user_id, apps.fnd_global.user_id, SYSDATE
                     , SYSDATE, USERENV ('SESSIONID'));

        fnd_file.put_line (fnd_file.LOG,
                           'Insert Records count' || SQL%ROWCOUNT);

        /* SELECT MAX (header_interface_id)
           INTO l_hdr_interface_id
           FROM rcv_headers_interface;*/

        fnd_file.put_line (fnd_file.LOG,
                           'l_hdr_interface_id:' || l_hdr_interface_id);

        SELECT GROUP_ID
          INTO l_group_id
          FROM rcv_headers_interface
         WHERE header_interface_id = l_hdr_interface_id;

        fnd_file.put_line (fnd_file.LOG, 'l_group_id:' || l_group_id);

        fnd_file.put_line (fnd_file.LOG,
                           'l_ship_header_id:' || l_ship_header_id);

        fnd_file.put_line (fnd_file.LOG, 'Inserting RTI table');

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
                                                        , l_group_id --group_id
                                                                    , P_org_id, SYSDATE --last_update_date
                                                                                       , fnd_global.user_id --last_updated_by
                                                                                                           , SYSDATE --creation_date
                                                                                                                    , apps.fnd_global.user_id --created_by
                                                                                                                                             , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                    , 'RECEIVE', -- lv_trx_type                                --transaction_type
                                                                                                                                                                                 /* 9/15 if the receipt date is in old month, default it to sysdate */
                                                                                                                                                                                 --p_receipt_date                             --transaction_date
                                                                                                                                                                                 SYSDATE, --PAST_RECEIPT TBD
                                                                                                                                                                                          'PENDING' --processing_status_code
                                                                                                                                                                                                   , 'BATCH' --processing_mode_code
                                                                                                                                                                                                            , 'PENDING' --transaction_status_code
                                                                                                                                                                                                                       , P_QTY --quantity
                                                                                                                                                                                                                              , P_UNIT_OF_MEASURE, --p_uom                                       --unit_of_measure
                                                                                                                                                                                                                                                   'RCV' --interface_source_code
                                                                                                                                                                                                                                                        , P_item_id --item_id
                                                                                                                                                                                                                                                                   , --    p_employee_id                                   --employee_id    ---CRP Issue
                                                                                                                                                                                                                                                                     'DELIVER' --auto_transact_code
                                                                                                                                                                                                                                                                              , NVL (P_SHIPMENT_HEADER_ID, l_ship_header_id) --shipment_header_id
                                                                                                                                                                                                                                                                                                                            , NULL --shipment_line_id
                                                                                                                                                                                                                                                                                                                                  , NULL --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                        , P_receipt_source_code --receipt_source_code-TBD
                                                                                                                                                                                                                                                                                                                                                               , P_TO_ORGANIZATION_ID --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                     , P_SOURCE_DOCUMENT_CODE --source_document_code--TBD
                                                                                                                                                                                                                                                                                                                                                                                                             , NULL --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                   , NULL --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                         , 'INVENTORY' --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                      , NULL --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                            , P_LOCATION_ID --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                           , P_DELIVER_TO_LOCATION_ID --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , P_subinventory --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , P_SHIPMENT_NUM --shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , P_expected_receipt_date --expected_receipt_date,TBD
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , l_hdr_interface_id --header_interface_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , 'Y' --validation_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , P_LOCATOR_ID, --p_locator_id,TBD
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       P_header_id, --oe_order_header_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    P_LINE_ID, --p_oe_order_line_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               P_customer_id, --TBD--p_customer_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              P_customer_site_id, --TBDp_customer_site_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  NULL, NULL FROM DUAL);

        fnd_file.put_line (fnd_file.LOG,
                           'Insert Records count' || SQL%ROWCOUNT);

        NULL;
    END;

    /****************************************************************************************************/
    /** ****************************************************************************
      -- Procedure Name      :  XXDO_RTI_UPDATE
      --
      -- Description         :  This procedure is used to update the RCV_HEADERS_INTERFACE,RCV_TRASACTION_INTERFACE Tables

      --
      -- DEVELOPMENT and MAINTENANCE HISTORY
      --
      -- date          author             Version  Description
      -- ------------  -----------------  -------
      -- 2017/02/14    Infosys            1.0      Initial Version.
      --
      --
      ***************************************************************************/
    PROCEDURE XXDO_RTI_UPDATE (P_INTERFACE_TRANSACTION_ID   NUMBER,
                               P_LINE_ID                    NUMBER,
                               P_Qty                        NUMBER,
                               P_SHIPMENT_HEADER_ID         NUMBER,
                               P_SHIPMENT_NUM               VARCHAR2)
    IS
        lv_ship_header_id   NUMBER;
    BEGIN
        BEGIN
            fnd_file.put_line (fnd_file.LOG,
                               'Shipment Number' || P_SHIPMENT_NUM);

            SELECT DISTINCT SHIPMENT_HEADER_ID
              INTO lv_ship_header_id
              FROM apps.rcv_shipment_headers
             WHERE shipment_num = P_SHIPMENT_NUM AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Unable to get Shipment_header_id');
        END;


        UPDATE rcv_headers_interface
           SET processing_request_id = NULL, validation_flag = 'Y', processing_status_code = 'PENDING',
               receipt_header_id = NULL, receipt_num = NULL
         WHERE HEADER_INTERFACE_ID IN
                   (SELECT HEADER_INTERFACE_ID
                      FROM rcv_transactions_interface
                     WHERE INTERFACE_TRANSACTION_ID IN
                               (P_INTERFACE_TRANSACTION_ID));

        fnd_file.put_line (
            fnd_file.LOG,
            'INTERFACE_TRANSACTION_ID' || P_INTERFACE_TRANSACTION_ID);
        fnd_file.put_line (fnd_file.LOG, 'Update RHI' || SQL%ROWCOUNT);

        UPDATE rcv_transactions_interface
           SET oe_order_line_id = P_line_id, QUANTITY = NVL (p_qty, QUANTITY), shipment_header_id = NVL (P_SHIPMENT_HEADER_ID, lv_ship_header_id),
               oe_order_num = NULL, oe_order_line_num = NULL, document_num = NULL,
               DOCUMENT_LINE_NUM = NULL, processing_status_code = 'PENDING', transaction_status_code = 'PENDING',
               processing_request_id = NULL, validation_flag = 'Y', request_id = NULL
         WHERE     1 = 1
               AND INTERFACE_TRANSACTION_ID = P_INTERFACE_TRANSACTION_ID;

        fnd_file.put_line (
            fnd_file.LOG,
            'INTERFACE_TRANSACTION_ID' || P_INTERFACE_TRANSACTION_ID);
        fnd_file.put_line (fnd_file.LOG, 'Update RTI count' || SQL%ROWCOUNT);

        DELETE FROM PO.po_interface_errors
              WHERE INTERFACE_LINE_ID = P_INTERFACE_TRANSACTION_ID;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unknown Exception' || SQLERRM);
    END;

    /****************************************************************************************************/
    /** ****************************************************************************
      -- Procedure Name      :  XXDO_RMA_REPROCESS
      --
      -- Description         :  This procedure is used to Reprocess the RTI Stuck Records

      --
      -- DEVELOPMENT and MAINTENANCE HISTORY
      --
      -- date          author             Version  Description
      -- ------------  -----------------  -------
      -- 2017/02/14    Infosys            1.0  Initial Version.
      --
      --
      ***************************************************************************/

    PROCEDURE XXDO_RMA_REPROCESS (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_rma_num VARCHAR2
                                  , p_item_number VARCHAR2, P_qty NUMBER)
    IS
        CURSOR c_rma IS
            SELECT DISTINCT msi.segment1,                      --test distinct
                                          rt.document_num, rt.oe_order_line_id,
                            rt.INTERFACE_TRANSACTION_ID, rt.quantity, rt.oe_order_header_id,
                            rt.customer_id, rt.CUSTOMER_SITE_ID, rt.RECEIPT_SOURCE_CODE,
                            rt.org_id, rt.to_organization_id, rt.item_id,
                            RT.SUBINVENTORY, rt.UNIT_OF_MEASURE, rt.SOURCE_DOCUMENT_CODE,
                            RT.LOCATION_ID, rt.DELIVER_TO_LOCATION_ID, rt.expected_receipt_date,
                            rt.LOCATOR_ID, rt.SHIPMENT_HEADER_ID, rt.shipment_num
              FROM rcv_transactions_interface rt, mtl_system_items_b msi, apps.po_interface_errors pi
             WHERE     document_num = p_rma_num
                   AND msi.organization_id = rt.TO_ORGANIZATION_ID
                   AND msi.inventory_item_id = rt.item_id
                   AND msi.segment1 = p_item_number
                   AND rt.transaction_type <> 'SHIP'
                   AND rt.processing_status_code <> 'PENDING'
                   AND pi.INTERFACE_LINE_ID(+) = rt.INTERFACE_TRANSACTION_ID;

        CURSOR cur_line IS
              SELECT ordered_quantity, line_id
                FROM apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
               WHERE     oh.order_number = p_rma_num
                     AND oh.header_id = ol.header_id
                     AND ol.ordered_item = p_item_number
                     AND ol.flow_status_code = 'AWAITING_RETURN'
                     AND ol.shipped_quantity IS NULL
                     AND ol.fulfilled_quantity IS NULL
            ORDER BY ordered_quantity DESC;

        l_qty                NUMBER;
        l_line_id            NUMBER;
        -- l_count            NUMBER;
        l_remain_qty         NUMBER;
        l_min_qty            NUMBER;
        l_min_line_id        NUMBER;
        lv_first             NUMBER;
        l_hdr_interface_id   NUMBER;
        l_ord_qty            NUMBER;
        l_line_qty           NUMBER;
        l_line_cnt           NUMBER;
        l_sum_qty            NUMBER;
        l_new_line_id        NUMBER;
        l_count              NUMBER := 1;
        L_PROCESSED_QTY      NUMBER;
        l_line_count         NUMBER;
        l_oe_line_id         NUMBER;
        -- l_remain_qty       NUMBER;
        l_msg_index_out      NUMBER (10);
        l_line_tbl_index     NUMBER;
        l_less_qty           NUMBER;
        l_oe_order_qty       NUMBER;
        l_oe_line_qty        NUMBER;
        l_rti_cnt            NUMBER;
        l_rti_qty            NUMBER;
        lv_oe_line_id        NUMBER;
        l_order_type         VARCHAR2 (50);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' inside begin');

        FOR rec_cur IN c_rma                                      ---Main Loop
        LOOP
            BEGIN
                SELECT sales_channel_code
                  INTO l_order_type
                  FROM oe_order_headers_all
                 WHERE     header_id = rec_cur.oe_order_header_id
                       AND org_id = rec_cur.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'Order not exist');
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'l_order_type: ' || l_order_type);

            IF l_order_type <> 'E-COMMERCE'
            THEN
                fnd_file.put_line (fnd_file.LOG, ' inside first for loop');

                ---Checking lines count in RTI
                SELECT COUNT (rt.interface_transaction_id), SUM (rt.quantity)
                  INTO l_rti_cnt, l_rti_qty
                  FROM rcv_transactions_interface rt, mtl_system_items_b msi
                 --  apps.po_interface_errors pi
                 WHERE     document_num = p_rma_num
                       AND msi.organization_id = rt.TO_ORGANIZATION_ID
                       AND msi.inventory_item_id = rt.item_id
                       AND msi.segment1 = p_item_number
                       AND rt.transaction_type <> 'SHIP'
                       AND rt.processing_status_code <> 'PENDING' -- AND pi.INTERFACE_LINE_ID       = rt.INTERFACE_TRANSACTION_ID(+)
                                                                 ;

                fnd_file.put_line (fnd_file.LOG,
                                   ' rti count is ' || l_rti_cnt);

                IF l_rti_cnt = 1
                THEN
                    SELECT COUNT (line_id), SUM (ordered_quantity)
                      INTO l_line_cnt, l_sum_qty
                      FROM apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
                     WHERE     oh.order_number = rec_cur.document_num
                           AND oh.header_id = ol.header_id
                           AND ol.ordered_item = rec_cur.segment1
                           AND ol.flow_status_code = 'AWAITING_RETURN'
                           AND ol.shipped_quantity IS NULL
                           AND ol.fulfilled_quantity IS NULL;

                    fnd_file.put_line (fnd_file.LOG,
                                       ' Lines count :' || l_line_cnt);
                    fnd_file.put_line (fnd_file.LOG,
                                       ' RMA Total Qty :' || l_sum_qty);
                    fnd_file.put_line (fnd_file.LOG,
                                       ' RTI Qty :' || rec_cur.quantity);

                    /**************************Update for RTI ,OE quantity is same and OE lines table having single line******/
                    IF l_line_cnt = 1
                    THEN
                        SELECT ordered_quantity, line_id
                          INTO l_qty, l_line_id
                          FROM apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
                         WHERE     oh.order_number = rec_cur.document_num
                               AND oh.header_id = ol.header_id
                               AND ol.ordered_item = rec_cur.segment1
                               AND ol.flow_status_code = 'AWAITING_RETURN'
                               AND ol.shipped_quantity IS NULL
                               AND ol.fulfilled_quantity IS NULL;

                        IF rec_cur.quantity <= l_qty
                        THEN
                            XXDO_RTI_UPDATE (
                                P_INTERFACE_TRANSACTION_ID   =>
                                    rec_cur.INTERFACE_TRANSACTION_ID,
                                P_LINE_ID        => l_line_id,
                                P_Qty            => rec_cur.quantity,
                                P_SHIPMENT_HEADER_ID   =>
                                    rec_cur.SHIPMENT_HEADER_ID,
                                P_SHIPMENT_NUM   => rec_cur.shipment_num);
                        END IF;

                        /****************************end for RTI=OE******************************************/
                        /*******************Update for if OE lines having less than RTI Quantity and Single line in OE OE<RTI******/

                        IF rec_cur.quantity > l_sum_qty
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Update for if OE lines having less than RTI Quantity and Single line in OE OE<RTI');

                            BEGIN
                                l_qty       := NULL;
                                l_line_id   := NULL;

                                SELECT ordered_quantity, line_id
                                  INTO l_qty, l_line_id
                                  FROM apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
                                 WHERE     oh.order_number =
                                           rec_cur.document_num
                                       AND oh.header_id = ol.header_id
                                       AND ol.ordered_item = rec_cur.segment1
                                       AND ol.flow_status_code =
                                           'AWAITING_RETURN'
                                       --AND ol.ordered_quantity    = rec_cur.quantity
                                       AND ol.shipped_quantity IS NULL
                                       AND ol.fulfilled_quantity IS NULL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error While getting line_id in SCENARIO 1'
                                        || SQLERRM);
                            END;

                            XXDO_RTI_UPDATE (
                                P_INTERFACE_TRANSACTION_ID   =>
                                    rec_cur.INTERFACE_TRANSACTION_ID,
                                P_LINE_ID        => l_line_id,
                                P_Qty            => l_qty,
                                P_SHIPMENT_HEADER_ID   =>
                                    rec_cur.SHIPMENT_HEADER_ID,
                                P_SHIPMENT_NUM   => rec_cur.shipment_num);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'INTERFACE_TRANSACTION_ID' || rec_cur.INTERFACE_TRANSACTION_ID);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'rec_cur.quantity and l_qty'
                                || rec_cur.quantity
                                || 'and'
                                || l_qty);
                            l_less_qty   := rec_cur.quantity - l_qty;
                            fnd_file.put_line (fnd_file.LOG,
                                               'l_less_qty :' || l_less_qty);
                            --Calling API for create New Line
                            --if l_order_type<>'E-COMMERCE' then
                            XXDO_CALLING_API (
                                P_header_id         => rec_cur.oe_order_header_id,
                                P_organization_id   =>
                                    rec_cur.to_organization_id,
                                P_qty               => l_less_qty,
                                P_org_id            => rec_cur.org_id,
                                P_item_id           => rec_cur.item_id,
                                P_new_line_id       => l_oe_line_id);
                            -- end if;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'New Line_id 1 is :' || l_oe_line_id);
                            ---Creating new line in RTI for  remaining qty
                            XXDO_RTI_INSERT (
                                P_CUSTOMER_ID       => rec_cur.CUSTOMER_ID,
                                P_RECEIPT_SOURCE_CODE   =>
                                    rec_cur.RECEIPT_SOURCE_CODE,
                                P_ORG_ID            => rec_cur.org_id,
                                P_UNIT_OF_MEASURE   => rec_cur.UNIT_OF_MEASURE,
                                P_ITEM_ID           => rec_cur.item_id,
                                P_TO_ORGANIZATION_ID   =>
                                    rec_cur.TO_ORGANIZATION_ID,
                                P_SOURCE_DOCUMENT_CODE   =>
                                    rec_cur.SOURCE_DOCUMENT_CODE,
                                P_LOCATION_ID       => rec_cur.LOCATION_ID,
                                P_DELIVER_TO_LOCATION_ID   =>
                                    rec_cur.DELIVER_TO_LOCATION_ID,
                                P_SUBINVENTORY      => rec_cur.subinventory,
                                P_EXPECTED_RECEIPT_DATE   =>
                                    rec_cur.expected_receipt_date,
                                P_LOCATOR_ID        => rec_cur.LOCATOR_ID,
                                P_HEADER_ID         =>
                                    rec_cur.oe_order_header_id,
                                P_CUSTOMER_SITE_ID   =>
                                    rec_cur.customer_site_id,
                                P_QTY               => l_less_qty,
                                P_LINE_ID           =>
                                    NVL (l_oe_line_id,
                                         rec_cur.oe_order_line_id),
                                P_SHIPMENT_HEADER_ID   =>
                                    rec_cur.SHIPMENT_HEADER_ID,
                                P_SHIPMENT_NUM      => rec_cur.shipment_num);
                        END IF;
                    /******************************************************************************************/
                    /******************************IF OE lines having multiple lines************************************/
                    ELSE
                        IF rec_cur.quantity >= l_sum_qty
                        THEN
                            l_processed_qty   := rec_cur.quantity;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'l_processed_qty' || l_processed_qty);

                            FOR rec_line IN cur_line
                            LOOP
                                l_processed_qty   :=
                                      l_processed_qty
                                    - rec_line.ordered_quantity;

                                IF l_count = 1
                                THEN
                                    XXDO_RTI_UPDATE (
                                        P_INTERFACE_TRANSACTION_ID   =>
                                            rec_cur.INTERFACE_TRANSACTION_ID,
                                        P_LINE_ID   => rec_line.line_id,
                                        P_Qty       =>
                                            rec_line.ordered_quantity,
                                        P_SHIPMENT_HEADER_ID   =>
                                            rec_cur.SHIPMENT_HEADER_ID,
                                        P_SHIPMENT_NUM   =>
                                            rec_cur.shipment_num);
                                END IF;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'INTERFACE_TRANSACTION_ID' || rec_cur.INTERFACE_TRANSACTION_ID);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Update RTI count' || SQL%ROWCOUNT);

                                IF l_count > 1
                                THEN
                                    XXDO_RTI_INSERT (
                                        P_CUSTOMER_ID   => rec_cur.CUSTOMER_ID,
                                        P_RECEIPT_SOURCE_CODE   =>
                                            rec_cur.RECEIPT_SOURCE_CODE,
                                        P_ORG_ID        => rec_cur.org_id,
                                        P_UNIT_OF_MEASURE   =>
                                            rec_cur.UNIT_OF_MEASURE,
                                        P_ITEM_ID       => rec_cur.item_id,
                                        P_TO_ORGANIZATION_ID   =>
                                            rec_cur.TO_ORGANIZATION_ID,
                                        P_SOURCE_DOCUMENT_CODE   =>
                                            rec_cur.SOURCE_DOCUMENT_CODE,
                                        P_LOCATION_ID   => rec_cur.LOCATION_ID,
                                        P_DELIVER_TO_LOCATION_ID   =>
                                            rec_cur.DELIVER_TO_LOCATION_ID,
                                        P_SUBINVENTORY   =>
                                            rec_cur.subinventory,
                                        P_EXPECTED_RECEIPT_DATE   =>
                                            rec_cur.expected_receipt_date,
                                        P_LOCATOR_ID    => rec_cur.LOCATOR_ID,
                                        P_HEADER_ID     =>
                                            rec_cur.oe_order_header_id,
                                        P_CUSTOMER_SITE_ID   =>
                                            rec_cur.customer_site_id,
                                        P_QTY           =>
                                            rec_line.ordered_quantity,
                                        P_LINE_ID       => rec_line.line_id,
                                        P_SHIPMENT_HEADER_ID   =>
                                            rec_cur.SHIPMENT_HEADER_ID,
                                        P_SHIPMENT_NUM   =>
                                            rec_cur.shipment_num);
                                END IF;

                                l_count   := l_count + 1;
                            END LOOP;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'l_processed_qty' || l_processed_qty);

                            IF l_processed_qty > 0
                            THEN
                                -- if l_order_type<>'E-COMMERCE' then
                                XXDO_CALLING_API (
                                    P_header_id     =>
                                        rec_cur.oe_order_header_id,
                                    P_organization_id   =>
                                        rec_cur.to_organization_id,
                                    P_qty           => l_processed_qty,
                                    P_org_id        => rec_cur.org_id,
                                    P_item_id       => rec_cur.item_id,
                                    P_new_line_id   => l_oe_line_id);
                                -- end if;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'New line_id 2' || l_oe_line_id);
                                ---Creating new line in RTI for  remaining qty
                                XXDO_RTI_INSERT (
                                    P_CUSTOMER_ID    => rec_cur.CUSTOMER_ID,
                                    P_RECEIPT_SOURCE_CODE   =>
                                        rec_cur.RECEIPT_SOURCE_CODE,
                                    P_ORG_ID         => rec_cur.org_id,
                                    P_UNIT_OF_MEASURE   =>
                                        rec_cur.UNIT_OF_MEASURE,
                                    P_ITEM_ID        => rec_cur.item_id,
                                    P_TO_ORGANIZATION_ID   =>
                                        rec_cur.TO_ORGANIZATION_ID,
                                    P_SOURCE_DOCUMENT_CODE   =>
                                        rec_cur.SOURCE_DOCUMENT_CODE,
                                    P_LOCATION_ID    => rec_cur.LOCATION_ID,
                                    P_DELIVER_TO_LOCATION_ID   =>
                                        rec_cur.DELIVER_TO_LOCATION_ID,
                                    P_SUBINVENTORY   => rec_cur.subinventory,
                                    P_EXPECTED_RECEIPT_DATE   =>
                                        rec_cur.expected_receipt_date,
                                    P_LOCATOR_ID     => rec_cur.LOCATOR_ID,
                                    P_HEADER_ID      =>
                                        rec_cur.oe_order_header_id,
                                    P_CUSTOMER_SITE_ID   =>
                                        rec_cur.customer_site_id,
                                    P_QTY            => l_processed_qty,
                                    P_LINE_ID        => l_oe_line_id,
                                    P_SHIPMENT_HEADER_ID   =>
                                        rec_cur.SHIPMENT_HEADER_ID,
                                    P_SHIPMENT_NUM   => rec_cur.shipment_num);
                            END IF;   --RTI qty greater than EBS Qty condition
                        END IF;
                    END IF;                             --line count condition

                    /*******************************If  RTI line_id is NULL  then**************************************/
                    IF l_line_cnt = 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Calling API if lines table line_id column is null');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'rec_cur.quantity' || rec_cur.quantity);
                        -- if l_order_type<>'E-COMMERCE' then
                        XXDO_CALLING_API (
                            P_header_id         => rec_cur.oe_order_header_id,
                            P_organization_id   => rec_cur.to_organization_id,
                            P_qty               => rec_cur.quantity,
                            P_org_id            => rec_cur.org_id,
                            P_item_id           => rec_cur.item_id,
                            P_new_line_id       => l_oe_line_id);

                        -- end if;
                        IF l_oe_line_id IS NOT NULL
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Before Updating RTI Line_id' || l_oe_line_id);
                            XXDO_RTI_UPDATE (
                                P_INTERFACE_TRANSACTION_ID   =>
                                    rec_cur.INTERFACE_TRANSACTION_ID,
                                P_LINE_ID        => l_oe_line_id,
                                P_Qty            => NULL,
                                P_SHIPMENT_HEADER_ID   =>
                                    rec_cur.SHIPMENT_HEADER_ID,
                                P_SHIPMENT_NUM   => rec_cur.shipment_num);
                        END IF;
                    END IF;
                ELSE
                    -----------------------IF RTI having multiple lines -------------------------------------------------------------


                    SELECT SUM (ordered_quantity), COUNT (line_id)
                      INTO l_oe_order_qty, l_oe_line_qty
                      FROM apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
                     WHERE     oh.order_number = p_rma_num
                           AND oh.header_id = ol.header_id
                           AND ol.ordered_item = p_item_number
                           AND ol.flow_status_code = 'AWAITING_RETURN'
                           AND ol.shipped_quantity IS NULL
                           AND ol.fulfilled_quantity IS NULL;

                    IF l_rti_qty <= l_oe_order_qty
                    THEN
                        IF l_oe_line_qty = 1
                        THEN
                            SELECT line_id
                              INTO lv_oe_line_id
                              FROM apps.oe_order_lines_all ol, apps.oe_order_headers_all oh
                             WHERE     oh.order_number = p_rma_num
                                   AND oh.header_id = ol.header_id
                                   AND ol.ordered_item = p_item_number
                                   AND ol.flow_status_code =
                                       'AWAITING_RETURN'
                                   AND ol.shipped_quantity IS NULL
                                   AND ol.fulfilled_quantity IS NULL;

                            --------------------Updating the Total Quantity in RTI with OE line_id---------------------------------------
                            XXDO_RTI_UPDATE (
                                P_INTERFACE_TRANSACTION_ID   =>
                                    rec_cur.INTERFACE_TRANSACTION_ID,
                                P_LINE_ID        => lv_oe_line_id,
                                P_Qty            => l_rti_qty,
                                P_SHIPMENT_HEADER_ID   =>
                                    rec_cur.SHIPMENT_HEADER_ID,
                                P_SHIPMENT_NUM   => rec_cur.shipment_num);

                            DELETE FROM
                                rcv_headers_interface
                                  WHERE HEADER_INTERFACE_ID IN
                                            (SELECT HEADER_INTERFACE_ID
                                               FROM rcv_transactions_interface
                                              WHERE INTERFACE_TRANSACTION_ID IN
                                                        (rec_cur.INTERFACE_TRANSACTION_ID));

                            DELETE FROM
                                rcv_transactions_interface
                                  WHERE     1 = 1
                                        AND INTERFACE_TRANSACTION_ID =
                                            rec_cur.INTERFACE_TRANSACTION_ID
                                        AND oe_order_line_id <> lv_oe_line_id;
                        ELSE
                            FOR rec_oe_line IN cur_line
                            LOOP
                                IF rec_cur.quantity =
                                   rec_oe_line.ordered_quantity
                                THEN
                                    XXDO_RTI_UPDATE (
                                        P_INTERFACE_TRANSACTION_ID   =>
                                            rec_cur.INTERFACE_TRANSACTION_ID,
                                        P_LINE_ID   => rec_oe_line.line_id,
                                        P_Qty       =>
                                            rec_oe_line.ordered_quantity,
                                        P_SHIPMENT_HEADER_ID   =>
                                            rec_cur.SHIPMENT_HEADER_ID,
                                        P_SHIPMENT_NUM   =>
                                            rec_cur.shipment_num);
                                END IF;
                            END LOOP;
                        END IF;
                    END IF;
                END IF;
            END IF;                                     --Order type Condition
        END LOOP;                                         -- Main cursor close

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Error message' || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Unknown Error' || SQLERRM);
    END;
END XXDO_RMA_REPROCESS_PKG;
/
