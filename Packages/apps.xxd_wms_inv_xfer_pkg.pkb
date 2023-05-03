--
-- XXD_WMS_INV_XFER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_INV_XFER_PKG"
IS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 22-FEB-2021  1.0        Greg Jensen             XPO Inventory Move Project
    -- 01-MAY-2021  1.1        Greg Jensen            Update to fix aging logic
    -- 10-MAR-2022  2.0        Jayarajan A K           Added procedure for CCR0009841 - US1_US6_Org_Move
    ******************************************************************************************/
    TYPE organization_rec IS RECORD
    (
        org_id                 NUMBER,
        organization_id        NUMBER,
        organization_code      VARCHAR2 (100),
        location_id            NUMBER,
        material_account_id    NUMBER
    );

    gn_resp_id                              NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id                         NUMBER := apps.fnd_global.resp_appl_id;

    gv_mo_profile_option_name_po   CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ;
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ;
    gv_responsibility_name_po      CONSTANT VARCHAR2 (240)
                                                := 'Deckers Purchasing User' ;
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
                                                := 'Deckers 3PL User' ;
    gv_US_OU                       CONSTANT VARCHAR2 (50) := 'Deckers US OU';

    -- gn_org_id                               NUMBER := fnd_global.org_id;
    gn_user_id                              NUMBER := fnd_global.user_id;
    gv_user_name                            VARCHAR2 (200)
                                                := FND_GLOBAL.USER_NAME;
    gn_login_id                             NUMBER := fnd_global.login_id;
    gn_request_id                           NUMBER
                                                := fnd_global.conc_request_id;
    gn_employee_id                          NUMBER := fnd_global.employee_id;
    gn_application_id                       NUMBER
        := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id                    NUMBER
        := fnd_profile.VALUE ('RESP_ID');
    gc_debug_enable                         VARCHAR2 (1);
    gv_ir_interface_source_code             VARCHAR2 (40) := 'PHYSICAL_MOVE';

    gn_master_org                  CONSTANT NUMBER := 106;
    gn_batchO2F_ID                 CONSTANT NUMBER := 1875;
    gn_mrp_not_planned             CONSTANT NUMBER := 6;         --Not Planned


    PROCEDURE insert_message (pv_message_type   IN VARCHAR2,
                              pv_message        IN VARCHAR2)
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insert_message;

    FUNCTION get_transaction_date (pn_item_id   IN NUMBER,
                                   pn_org_id    IN NUMBER,
                                   pn_qty       IN NUMBER)
        RETURN DATE
    IS
        CURSOR c_item_details IS
              SELECT transaction_date, SUM (qty + corrected_qty) qty
                FROM (SELECT TRUNC (rcvt.transaction_date) transaction_date,
                             NVL (rcvt.quantity, 0) qty,
                             (SELECT NVL (SUM (quantity), 0)
                                FROM apps.rcv_transactions rcvt1
                               WHERE     rcvt1.parent_transaction_id =
                                         rcvt.transaction_id
                                     AND rcvt1.transaction_type = 'CORRECT') corrected_qty
                        FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                       WHERE     rcvt.transaction_type = 'DELIVER'
                             AND rcvt.destination_type_code = 'INVENTORY'
                             AND rsl.source_document_code IN ('PO')
                             AND rsl.shipment_line_id = rcvt.shipment_line_id
                             AND rsl.item_id = pn_item_id
                             AND rcvt.organization_id = pn_org_id)
            GROUP BY transaction_date
            ORDER BY transaction_date DESC;

        ln_qty                NUMBER;
        ln_sum_qty            NUMBER;
        ld_transaction_date   DATE;
    BEGIN
        ln_qty                := pn_qty;
        ln_sum_qty            := 0;
        ld_transaction_date   := NULL;

        insert_message (
            'LOG',
               'gt Trx Date Itm ID : '
            || pn_item_id
            || ' Org ID : '
            || pn_org_id
            || ' qty : '
            || ln_qty);

        FOR r_item_details IN c_item_details
        LOOP
            ln_sum_qty   := ln_sum_qty + r_item_details.qty;
            insert_message ('LOG', ' > ln_sum_qty : ' || ln_sum_qty);

            IF ln_sum_qty >= ln_qty
            THEN
                ld_transaction_date   := r_item_details.transaction_date;
                insert_message (
                    'LOG',
                       ' > transaction_date from rec : '
                    || TO_CHAR (r_item_details.transaction_date,
                                'MM/DD/YYYY'));
                EXIT;
            END IF;
        END LOOP;

        IF ld_transaction_date IS NULL
        THEN
            ld_transaction_date   :=
                ADD_MONTHS (TRUNC (SYSDATE, 'MONTH'), -60) - 1;
            insert_message (
                'LOG',
                   ' > transaction_date from rec a: '
                || TO_CHAR (ld_transaction_date, 'MM/DD/YYYY'));
            RETURN ld_transaction_date;
        ELSE
            ld_transaction_date   := TRUNC (ld_transaction_date, 'MONTH');
            insert_message (
                'LOG',
                   ' > transaction_date from rec b: '
                || TO_CHAR (ld_transaction_date, 'MM/DD/YYYY'));
            RETURN ld_transaction_date;
        END IF;

        insert_message (
            'LOG',
            'Receiving Transaction Date: ' || ld_transaction_date);
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Unexpected error while fetching rcv date: ' || SQLERRM);
            ld_transaction_date   := ADD_MONTHS (TRUNC (SYSDATE), -60) - 1;
    END get_transaction_date;

    FUNCTION get_requisition_number (pv_interface_source_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_req_number   VARCHAR2 (50);
    BEGIN
        SELECT DISTINCT segment1
          INTO lv_req_number
          FROM po_requisition_headers_all
         WHERE interface_source_code = pv_interface_source_code;

        RETURN lv_req_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION f_get_onhand (pn_item_id IN NUMBER, pn_org_id IN NUMBER, pv_sub IN VARCHAR2
                           , pn_locator_id IN NUMBER)
        RETURN NUMBER
    IS
        v_api_return_status   VARCHAR2 (1);
        v_qty_oh              NUMBER;
        v_qty_res_oh          NUMBER;
        v_qty_res             NUMBER;
        v_qty_sug             NUMBER;
        v_qty_att             NUMBER;
        v_qty_atr             NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (1000);
        l_onhand              NUMBER := 0;
    BEGIN
        inv_quantity_tree_grp.clear_quantity_cache;

        apps.INV_QUANTITY_TREE_PUB.QUERY_QUANTITIES (p_api_version_number => 1.0, p_init_msg_lst => apps.fnd_api.g_false, x_return_status => v_api_return_status, x_msg_count => v_msg_count, x_msg_data => v_msg_data, p_organization_id => pn_org_id, p_inventory_item_id => pn_item_id, p_tree_mode => apps.inv_quantity_tree_pub.g_transaction_mode, p_onhand_source => 3, p_is_revision_control => FALSE, p_is_lot_control => FALSE, p_is_serial_control => FALSE, p_revision => NULL, p_lot_number => NULL, p_subinventory_code => pv_sub, p_locator_id => pn_locator_id, x_qoh => v_qty_oh, x_rqoh => v_qty_res_oh, x_qr => v_qty_res, x_qs => v_qty_sug, x_att => v_qty_att
                                                     , x_atr => v_qty_atr);

        l_onhand   := v_qty_oh;
        RETURN l_onhand;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_onhand   := 0;
            RETURN l_onhand;
    END f_get_onhand;

    FUNCTION get_organization_data (pn_organization_id IN NUMBER)
        RETURN organization_rec
    IS
        lr_organization        organization_rec;
        lv_organization_code   VARCHAR2 (100);
        ln_org_id              NUMBER;
    BEGIN
        lr_organization.organization_id   := pn_organization_id;

        SELECT organization_code, operating_unit
          INTO lr_organization.organization_code, lr_organization.org_id
          FROM apps.org_organization_definitions
         WHERE organization_id = pn_organization_id;

        SELECT location_id
          INTO lr_organization.location_id
          FROM hr_organization_units_v
         WHERE organization_id = pn_organization_id;

        SELECT material_account
          INTO lr_organization.material_account_id
          FROM mtl_parameters
         WHERE organization_id = pn_organization_id;

        RETURN lr_organization;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN lr_organization;
    END;

    --Wrapper around executing con current request with wait for completion
    PROCEDURE exec_conc_request (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_request_id OUT NUMBER, pv_application IN VARCHAR2 DEFAULT NULL, pv_program IN VARCHAR2 DEFAULT NULL, pv_argument1 IN VARCHAR2 DEFAULT CHR (0), pv_argument2 IN VARCHAR2 DEFAULT CHR (0), pv_argument3 IN VARCHAR2 DEFAULT CHR (0), pv_argument4 IN VARCHAR2 DEFAULT CHR (0), pv_argument5 IN VARCHAR2 DEFAULT CHR (0), pv_argument6 IN VARCHAR2 DEFAULT CHR (0), pv_argument7 IN VARCHAR2 DEFAULT CHR (0), pv_argument8 IN VARCHAR2 DEFAULT CHR (0), pv_argument9 IN VARCHAR2 DEFAULT CHR (0), pv_argument10 IN VARCHAR2 DEFAULT CHR (0), pv_argument11 IN VARCHAR2 DEFAULT CHR (0), pv_argument12 IN VARCHAR2 DEFAULT CHR (0), pv_argument13 IN VARCHAR2 DEFAULT CHR (0), pv_argument14 IN VARCHAR2 DEFAULT CHR (0), pv_argument15 IN VARCHAR2 DEFAULT CHR (0), pv_argument16 IN VARCHAR2 DEFAULT CHR (0), pv_argument17 IN VARCHAR2 DEFAULT CHR (0), pv_argument18 IN VARCHAR2 DEFAULT CHR (0), pv_argument19 IN VARCHAR2 DEFAULT CHR (0), pv_argument20 IN VARCHAR2 DEFAULT CHR (0), pv_argument21 IN VARCHAR2 DEFAULT CHR (0), pv_argument22 IN VARCHAR2 DEFAULT CHR (0), pv_argument23 IN VARCHAR2 DEFAULT CHR (0), pv_argument24 IN VARCHAR2 DEFAULT CHR (0), pv_argument25 IN VARCHAR2 DEFAULT CHR (0), pv_argument26 IN VARCHAR2 DEFAULT CHR (0), pv_argument27 IN VARCHAR2 DEFAULT CHR (0), pv_argument28 IN VARCHAR2 DEFAULT CHR (0), pv_argument29 IN VARCHAR2 DEFAULT CHR (0), pv_argument30 IN VARCHAR2 DEFAULT CHR (0), pv_argument31 IN VARCHAR2 DEFAULT CHR (0), pv_argument32 IN VARCHAR2 DEFAULT CHR (0), pv_argument33 IN VARCHAR2 DEFAULT CHR (0), pv_argument34 IN VARCHAR2 DEFAULT CHR (0), pv_argument35 IN VARCHAR2 DEFAULT CHR (0), pv_argument36 IN VARCHAR2 DEFAULT CHR (0), pv_argument37 IN VARCHAR2 DEFAULT CHR (0), pv_argument38 IN VARCHAR2 DEFAULT CHR (0), pv_wait_for_request IN VARCHAR2 DEFAULT 'Y', pn_interval IN NUMBER DEFAULT 60
                                 , pn_max_wait IN NUMBER DEFAULT 0)
    IS
        l_req_status   BOOLEAN;
        l_request_id   NUMBER;

        l_phase        VARCHAR2 (120 BYTE);
        l_status       VARCHAR2 (120 BYTE);
        l_dev_phase    VARCHAR2 (120 BYTE);
        l_dev_status   VARCHAR2 (120 BYTE);
        l_message      VARCHAR2 (2000 BYTE);
    BEGIN
        l_request_id    :=
            apps.fnd_request.submit_request (application   => pv_application,
                                             program       => pv_program,
                                             start_time    => SYSDATE,
                                             sub_request   => FALSE,
                                             argument1     => pv_argument1,
                                             argument2     => pv_argument2,
                                             argument3     => pv_argument3,
                                             argument4     => pv_argument4,
                                             argument5     => pv_argument5,
                                             argument6     => pv_argument6,
                                             argument7     => pv_argument7,
                                             argument8     => pv_argument8,
                                             argument9     => pv_argument9,
                                             argument10    => pv_argument10,
                                             argument11    => pv_argument11,
                                             argument12    => pv_argument12,
                                             argument13    => pv_argument13,
                                             argument14    => pv_argument14,
                                             argument15    => pv_argument15,
                                             argument16    => pv_argument16,
                                             argument17    => pv_argument17,
                                             argument18    => pv_argument18,
                                             argument19    => pv_argument19,
                                             argument20    => pv_argument20,
                                             argument21    => pv_argument21,
                                             argument22    => pv_argument22,
                                             argument23    => pv_argument23,
                                             argument24    => pv_argument24,
                                             argument25    => pv_argument25,
                                             argument26    => pv_argument26,
                                             argument27    => pv_argument27,
                                             argument28    => pv_argument28,
                                             argument29    => pv_argument29,
                                             argument30    => pv_argument30,
                                             argument31    => pv_argument31,
                                             argument32    => pv_argument32,
                                             argument33    => pv_argument33,
                                             argument34    => pv_argument34,
                                             argument35    => pv_argument35,
                                             argument36    => pv_argument36,
                                             argument37    => pv_argument37,
                                             argument38    => pv_argument38);
        COMMIT;

        IF l_request_id <> 0
        THEN
            IF pv_wait_for_request = 'Y'
            THEN
                l_req_status   :=
                    apps.fnd_concurrent.wait_for_request (
                        request_id   => l_request_id,
                        interval     => pn_interval,
                        max_wait     => pn_max_wait,
                        phase        => l_phase,
                        status       => l_status,
                        dev_phase    => l_dev_phase,
                        dev_status   => l_dev_status,
                        MESSAGE      => l_message);



                IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
                THEN
                    IF NVL (l_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        pv_error_stat   := 'W';
                    ELSE
                        pv_error_stat   := apps.fnd_api.g_ret_sts_error;
                    END IF;

                    pv_error_msg   :=
                        NVL (
                            l_message,
                               'The request ended with a status of '
                            || NVL (l_dev_status, 'ERROR'));
                ELSE
                    pv_error_stat   := 'S';
                END IF;
            ELSE
                pv_error_stat   := 'S';
            END IF;
        ELSE
            pv_error_stat   := 'E';
            pv_error_msg    := 'No request launched';
            pn_request_id   := NULL;
            RETURN;
        END IF;

        pn_request_id   := l_request_id;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error : ' || SQLERRM;
    END;


    PROCEDURE oh_inv_transfer_report (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_brand IN VARCHAR2, pn_src_org IN NUMBER, pn_dest_org IN NUMBER, pn_xfer_first_n_days IN NUMBER
                                      , pn_xfer_second_n_days IN NUMBER)
    IS
        --Variable Declaration
        gn_warning                 NUMBER (3) := 1;
        gn_error                   NUMBER (3) := 2;
        x_id                       UTL_FILE.file_type;
        p_source_directory         VARCHAR2 (1000) := 'XXD_WMS_INVENTORY_REPORT';
        l_delimiter                VARCHAR2 (3) := '|';
        ld_max_supply_date         DATE;
        lv_transfer_date           VARCHAR2 (100);


        CURSOR c_inv_data IS
              SELECT organization, brand, sku,
                     sku_description, item_id, NVL (oh_quantity_rcv, 0) oh_quantity_rcv,
                     NVL (oh_quantity_truck, 0) oh_quantity_truck, NVL (free_atr, 0) free_atr, NVL (supply_quantity, 0) supply_quantity,
                     NVL (free_atp, 0) free_atp, NVL (released_iso_quantity, 0) released_iso_quantity, NVL (dest_org_demand_first_n_days, 0) dest_org_demand_first_n_days,
                     NVL (dest_org_demand_second_n_days, 0) dest_org_demand_second_n_days, NVL (dest_org_demand_beyond, 0) dest_org_demand_beyond
                FROM (SELECT mp.organization_code
                                 organization,
                             xdiv.brand,
                             xdiv.item_number
                                 sku,
                             REGEXP_REPLACE (xdiv.item_description,
                                             '[^0-9A-Za-z ]')
                                 sku_description,
                             msib.inventory_item_id
                                 item_id,
                             (SELECT SUM (transaction_quantity)
                                FROM apps.mtl_onhand_quantities_detail
                               WHERE     subinventory_code IN ('RECEIVING')
                                     AND organization_id = msib.organization_id
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 oh_quantity_rcv,
                             (SELECT SUM (transaction_quantity)
                                FROM apps.mtl_onhand_quantities_detail
                               WHERE     subinventory_code IN ('TRUCK')
                                     AND organization_id = msib.organization_id
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 oh_quantity_truck,
                             apps.f_get_atr (msib.inventory_item_id, msib.organization_id, NULL
                                             , NULL)
                                 free_atr,
                             (SELECT SUM (quantity) supply_qty
                                FROM mtl_supply
                               WHERE     to_organization_id = pn_src_org
                                     AND TRUNC (expected_delivery_date) BETWEEN TRUNC (
                                                                                    SYSDATE)
                                                                            AND TO_DATE (
                                                                                    lv_transfer_date,
                                                                                    'DD-MON-YYYY')
                                     AND item_id = msib.inventory_item_id)
                                 supply_quantity,
                             (SELECT SUM (atp)
                                FROM xxdo.xxdo_atp_final atp
                               WHERE     atp.organization_id =
                                         msib.organization_id
                                     AND demand_class = '-1'
                                     AND atp.inventory_item_id =
                                         msib.inventory_item_id
                                     AND TRUNC (dte) = TRUNC (SYSDATE))
                                 free_atp,
                             (SELECT SUM (NVL (ordered_quantity, 0))
                                FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                               WHERE     flv.lookup_type =
                                         'XXD_WMS_BLANKET_ISO_LIST'
                                     AND flv.language = 'US'
                                     AND ooha.order_number = flv.lookup_code
                                     AND flv.enabled_flag = 'Y'
                                     AND ooha.header_id = oola.header_id
                                     AND oola.inventory_item_id =
                                         msib.inventory_item_id
                                     AND oola.ship_from_org_id =
                                         msib.organization_id
                                     AND oola.schedule_ship_date IS NOT NULL
                                     AND NVL (oola.open_flag, 'N') = 'Y'
                                     AND NVL (oola.cancelled_flag, 'N') = 'N'
                                     AND oola.line_category_code = 'ORDER'
                                     AND oola.flow_status_code =
                                         'AWAITING_SHIPPING')
                                 released_iso_quantity,
                             (SELECT SUM (ordered_quantity)
                                FROM apps.oe_order_lines_all
                               WHERE     TRUNC (schedule_ship_date) BETWEEN TO_DATE (
                                                                                lv_transfer_date,
                                                                                'DD-MON-YYYY')
                                                                        AND   TO_DATE (
                                                                                  lv_transfer_date,
                                                                                  'DD-MON-YYYY')
                                                                            + pn_xfer_first_n_days
                                     AND ship_from_org_id = pn_dest_org
                                     AND schedule_ship_date IS NOT NULL
                                     AND NVL (open_flag, 'N') = 'Y'
                                     AND NVL (cancelled_flag, 'N') = 'N'
                                     AND line_category_code = 'ORDER'
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 dest_org_demand_first_n_days,
                             (SELECT SUM (ordered_quantity)
                                FROM apps.oe_order_lines_all
                               WHERE     TRUNC (schedule_ship_date) BETWEEN   TO_DATE (
                                                                                  lv_transfer_date,
                                                                                  'DD-MON-YYYY')
                                                                            + pn_xfer_first_n_days
                                                                            + 1
                                                                        AND   TO_DATE (
                                                                                  lv_transfer_date,
                                                                                  'DD-MON-YYYY')
                                                                            + pn_xfer_second_n_days
                                     AND ship_from_org_id = pn_dest_org
                                     AND schedule_ship_date IS NOT NULL
                                     AND NVL (open_flag, 'N') = 'Y'
                                     AND NVL (cancelled_flag, 'N') = 'N'
                                     AND line_category_code = 'ORDER'
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 dest_org_demand_second_n_days,
                             (SELECT SUM (ordered_quantity)
                                FROM apps.oe_order_lines_all
                               WHERE     TRUNC (schedule_ship_date) >=
                                           TO_DATE (lv_transfer_date,
                                                    'DD-MON-YYYY')
                                         + pn_xfer_second_n_days
                                         + 1
                                     AND ship_from_org_id = pn_dest_org
                                     AND schedule_ship_date IS NOT NULL
                                     AND NVL (open_flag, 'N') = 'Y'
                                     AND NVL (cancelled_flag, 'N') = 'N'
                                     AND line_category_code = 'ORDER'
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 dest_org_demand_beyond
                        FROM apps.xxd_common_items_v xdiv, apps.mtl_parameters mp, apps.mtl_system_items_b msib
                       WHERE     msib.organization_id = pn_src_org
                             AND brand = UPPER (pv_brand)
                             AND msib.organization_id = mp.organization_id
                             AND xdiv.organization_id = msib.organization_id
                             AND xdiv.inventory_item_id =
                                 msib.inventory_item_id
                             --    AND xdiv.item_number = msib.segment1
                             AND msib.enabled_flag = 'Y'
                             AND msib.inventory_item_id IN
                                     (SELECT DISTINCT item_id inventory_item_id
                                        FROM apps.mtl_supply
                                       WHERE to_organization_id = pn_src_org
                                      UNION
                                      SELECT DISTINCT inventory_item_id
                                        FROM apps.mtl_onhand_quantities_detail
                                       WHERE organization_id = pn_src_org
                                      UNION
                                      SELECT DISTINCT oola.inventory_item_id
                                        FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                                       WHERE     flv.lookup_type =
                                                 'XXD_WMS_BLANKET_ISO_LIST' --TODO: Need new lookup
                                             AND flv.language = 'US'
                                             AND ooha.order_number =
                                                 flv.lookup_code
                                             AND ooha.header_id =
                                                 oola.header_id
                                             AND oola.ship_from_org_id =
                                                 pn_src_org
                                             AND oola.schedule_ship_date
                                                     IS NOT NULL
                                             AND NVL (oola.open_flag, 'N') =
                                                 'Y'
                                             AND NVL (oola.cancelled_flag, 'N') =
                                                 'N'
                                             AND oola.line_category_code =
                                                 'ORDER'
                                             AND oola.flow_status_code =
                                                 'AWAITING_SHIPPING'))
            ORDER BY released_iso_quantity DESC;

        TYPE t_inv_data_rec IS TABLE OF c_inv_data%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_inv_data_rec             t_inv_data_rec;
        ln_max_transfer_quantity   NUMBER;
        lv_include_free_atp        VARCHAR2 (1);
        ln_free_atp                NUMBER;
        ln_truck_quantity          NUMBER;
        lv_src_org                 VARCHAR2 (10);
        lv_dest_org                VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT organization_code
              INTO lv_src_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pn_src_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_src_org   := NULL;
        END;

        BEGIN
            SELECT organization_code
              INTO lv_dest_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pn_dest_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dest_org   := NULL;
        END;

        BEGIN
            SELECT flv.meaning
              INTO lv_transfer_date
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_WMS_INV_TRANSFER_DATE'
                   AND flv.language = 'US'
                   AND flv.lookup_code = lv_src_org
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                insert_message (
                    'LOG',
                    'No Transfer Date defined for the Org in the Lookup');
        END;

        insert_message ('LOG', 'Brand: ' || UPPER (pv_brand));
        insert_message ('LOG', 'Source Org: ' || lv_src_org);
        insert_message ('LOG', 'Destination Org: ' || lv_dest_org);
        insert_message ('LOG', 'Transfer Date: ' || lv_transfer_date);

        BEGIN
            SELECT flv.tag
              INTO lv_include_free_atp
              FROM apps.fnd_lookup_values flv, apps.org_organization_definitions ood
             WHERE     flv.lookup_type = 'XXDO_INCLUDE_FREE_ATP'
                   AND flv.language = 'US'
                   AND flv.lookup_code = ood.organization_code
                   AND ood.organization_id = pn_src_org
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_include_free_atp   := 'N';
                ln_free_atp           := 0;
        END;

        OPEN c_inv_data;

        FETCH c_inv_data BULK COLLECT INTO l_inv_data_rec;

        CLOSE c_inv_data;

        IF l_inv_data_rec.COUNT > 0
        THEN
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<?xml version="1.0"?>');
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ATPINFO>');

            FOR i IN 1 .. l_inv_data_rec.COUNT
            LOOP
                BEGIN
                    SELECT MAX (expected_delivery_date)
                      INTO ld_max_supply_date
                      FROM apps.mtl_supply
                     WHERE     to_organization_id = pn_src_org
                           AND item_id = l_inv_data_rec (i).item_id
                           AND TRUNC (expected_delivery_date) BETWEEN TRUNC (
                                                                          SYSDATE)
                                                                  AND TO_DATE (
                                                                          lv_transfer_date,
                                                                          'DD-MON-YYYY');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_max_supply_date   := NULL;
                END;

                IF lv_include_free_atp = 'Y'
                THEN
                    ln_free_atp   := l_inv_data_rec (i).free_atp;
                ELSE
                    ln_free_atp   := 0;
                END IF;


                -- FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</ATPINFO>');
                ln_truck_quantity   :=
                    NVL (l_inv_data_rec (i).oh_quantity_truck, 0);

                ln_max_transfer_quantity   :=
                    LEAST (
                        GREATEST (
                              (l_inv_data_rec (i).released_iso_quantity + ln_free_atp)
                            - NVL (l_inv_data_rec (i).supply_quantity, 0),
                            0),
                        l_inv_data_rec (i).free_atr);
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ITEM_DETAILS>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<ORGANIZATION>'
                    || l_inv_data_rec (i).organization
                    || '</ORGANIZATION>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                    '<BRAND>' || l_inv_data_rec (i).brand || '</BRAND>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                    '<SKU>' || l_inv_data_rec (i).sku || '</SKU>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<SKU_DESCRIPTION>'
                    || l_inv_data_rec (i).sku_description
                    || '</SKU_DESCRIPTION>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<RECEIVING_QUANTITY>'
                    || l_inv_data_rec (i).oh_quantity_rcv
                    || '</RECEIVING_QUANTITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<TRUCK_QUANTITY>'
                    || l_inv_data_rec (i).oh_quantity_truck
                    || '</TRUCK_QUANTITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<FREE_ATR>'
                    || l_inv_data_rec (i).free_atr
                    || '</FREE_ATR>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<SUPPLY_TILL_TRANSFER_DATE>'
                    || l_inv_data_rec (i).supply_quantity
                    || '</SUPPLY_TILL_TRANSFER_DATE>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<MAX_SUPPLY_DATE>'
                    || ld_max_supply_date
                    || '</MAX_SUPPLY_DATE>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<FREE_ATP>'
                    || l_inv_data_rec (i).free_atp
                    || '</FREE_ATP>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<MAXIMUM_TRANSFER_QUANITY>'
                    || ln_max_transfer_quantity
                    || '</MAXIMUM_TRANSFER_QUANITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DEST_ORG_DEMAND_FIRST_N_DAYS>'
                    || l_inv_data_rec (i).dest_org_demand_first_n_days
                    || '</DEST_ORG_DEMAND_FIRST_N_DAYS>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DEST_ORG_DEMAND_SECOND_N_DAYS>'
                    || l_inv_data_rec (i).dest_org_demand_second_n_days
                    || '</DEST_ORG_DEMAND_SECOND_N_DAYS>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DEST_ORG_DEMAND_BEYOND>'
                    || l_inv_data_rec (i).dest_org_demand_beyond
                    || '</DEST_ORG_DEMAND_BEYOND>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ITEM_DETAILS>');
            END LOOP;

            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</ATPINFO>');
        ELSE
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               'File is not generated as there is no data ');
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_operation
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid operation');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.invalid_path
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid path');
            UTL_FILE.fclose_all;
            pv_retcode   := gn_error;
        WHEN UTL_FILE.invalid_mode
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid mode');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.invalid_filehandle
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid filehandle');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.read_error
        THEN
            fnd_file.put_line (fnd_file.LOG, 'read error');
            UTL_FILE.fclose_all;
            pv_retcode   := gn_error;
        WHEN UTL_FILE.internal_error
        THEN
            fnd_file.put_line (fnd_file.LOG, 'internal error');
            UTL_FILE.fclose_all;
            pv_retcode   := gn_error;
        WHEN OTHERS
        THEN
            pv_retcode   := gn_warning;
            fnd_file.put_line (fnd_file.LOG, 'other error: ' || SQLERRM);
            UTL_FILE.fclose_all;
    END;

    FUNCTION validate_data (pv_brand               IN VARCHAR2,
                            pr_src_organization    IN organization_rec,
                            pv_src_subinv          IN VARCHAR2,
                            pv_src_locator         IN VARCHAR2,
                            pr_dest_organization   IN organization_rec)
        RETURN VARCHAR2
    IS
        CURSOR cur_validate_item_config IS
            SELECT DISTINCT segment1
              FROM apps.xxd_common_items_v xci, apps.mtl_system_items_b msib
             WHERE     1 = 1
                   AND xci.brand = pv_brand
                   AND xci.organization_id = msib.organization_id
                   AND xci.inventory_item_id = msib.inventory_item_id
                   AND msib.inventory_item_id IN
                           (SELECT DISTINCT moqd.inventory_item_id
                              FROM apps.mtl_item_locations_kfv mil, apps.mtl_onhand_quantities_detail moqd
                             WHERE     mil.subinventory_code = pv_src_subinv
                                   AND mil.concatenated_segments =
                                       pv_src_locator
                                   AND mil.organization_id =
                                       pr_src_organization.organization_id
                                   AND mil.subinventory_code =
                                       moqd.subinventory_code
                                   AND mil.inventory_location_id =
                                       moqd.locator_id
                                   AND mil.organization_id =
                                       moqd.organization_id)
                   AND msib.organization_id =
                       pr_dest_organization.organization_id
                   AND (msib.PURCHASING_ENABLED_FLAG = 'N' OR msib.INTERNAL_ORDER_ENABLED_FLAG = 'N');

        CURSOR cur_validate_item_config_src IS
            SELECT DISTINCT msib.segment1
              FROM apps.xxd_common_items_v xci, apps.mtl_system_items_b msib, apps.mtl_item_locations_kfv mil,
                   apps.mtl_onhand_quantities_detail moqd
             WHERE     1 = 1
                   AND xci.brand = pv_brand
                   AND xci.organization_id = msib.organization_id
                   AND xci.inventory_item_id = msib.inventory_item_id
                   AND msib.inventory_item_id = moqd.inventory_item_id
                   AND mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id =
                       pr_src_organization.organization_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND mil.organization_id = moqd.organization_id
                   AND msib.organization_id = moqd.organization_id
                   AND (msib.PURCHASING_ENABLED_FLAG = 'N' OR msib.INTERNAL_ORDER_ENABLED_FLAG = 'N');

        CURSOR cur_item_exists IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_item_locations_kfv mil, apps.xxd_common_items_v xci, apps.mtl_system_items_b msib,
                   apps.mtl_onhand_quantities_detail moqd
             WHERE     1 = 1
                   AND xci.brand = pv_brand
                   AND xci.organization_id = msib.organization_id
                   AND xci.inventory_item_id = msib.inventory_item_id
                   AND mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id =
                       pr_src_organization.organization_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND mil.organization_id = moqd.organization_id
                   AND msib.organization_id = moqd.organization_id
                   AND msib.inventory_item_id = moqd.inventory_item_id
                   AND NOT EXISTS
                           (SELECT msi1.segment1
                              FROM apps.mtl_system_items_kfv msi1
                             WHERE     msi1.organization_id =
                                       pr_dest_organization.organization_id
                                   AND msi1.segment1 = msib.segment1);

        CURSOR cur_check_reservations IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_item_locations_kfv mil, apps.mtl_reservations mr, apps.xxd_common_items_v xci,
                   apps.mtl_system_items_b msib
             WHERE     1 = 1
                   AND xci.brand = pv_brand
                   AND xci.organization_id = msib.organization_id
                   AND xci.inventory_item_id = msib.inventory_item_id
                   AND mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id =
                       pr_src_organization.organization_id
                   AND mil.subinventory_code = mr.subinventory_code
                   AND mil.inventory_location_id = mr.locator_id
                   AND mil.organization_id = mr.organization_id
                   AND msib.inventory_item_id = mr.inventory_item_id
                   AND msib.organization_id = mr.organization_id;

        lv_return_status           VARCHAR2 (1);
        ln_loose_quantity          NUMBER;
        ln_cnt                     NUMBER;
        lv_include_free_atp        VARCHAR2 (1);
        ln_max_transfer_quantity   NUMBER;
        ln_truck_quantity          NUMBER;
        ln_free_atp                NUMBER;
        ln_dock_door_id            NUMBER;
        ln_count                   NUMBER;
    BEGIN
        lv_return_status   := 'S';

        /* Validating SKU Configuration in Destination Organization */
        insert_message (
            'BOTH',
            '+------------------------- Start Validation --------------------------------+');
        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');

        insert_message ('LOG',
                        'Validating Source and Destination Organization');

        IF pr_src_organization.organization_id =
           pr_dest_organization.organization_id
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Source Org: '
                || pr_src_organization.organization_code
                || 'cannot be same as Destination Org: '
                || pr_dest_organization.organization_code);
        END IF;

        --TODO: Update this appropriately
        /*      SELECT COUNT (DISTINCT request_id)
                INTO ln_count
                FROM XXDO.XXD_WMS_OH_IR_XFER_STG
               WHERE  organization_id = pr_src_organization.organization_id
                     AND status <> 'Y';

              IF ln_count <> 0
              THEN
                 lv_return_status := 'E';
                 insert_message (
                    'BOTH',
                       'Truck Locator: '
                    || pv_src_locator
                    || ' is already in process. Cannot submit more than once');
              END IF;*/

        SELECT COUNT (DISTINCT moqd.inventory_item_id)
          INTO ln_count
          FROM apps.mtl_item_locations_kfv mil, apps.mtl_onhand_quantities_detail moqd, apps.xxd_common_items_v vw
         WHERE     mil.subinventory_code = pv_src_subinv
               AND vw.brand = pv_brand
               AND mil.concatenated_segments = pv_src_locator
               AND mil.organization_id = pr_src_organization.organization_id
               AND mil.subinventory_code = moqd.subinventory_code
               AND mil.inventory_location_id = moqd.locator_id
               AND mil.organization_id = moqd.organization_id
               AND moqd.inventory_item_id = vw.inventory_item_id
               AND moqd.organization_id = vw.organization_id;

        IF ln_count = 0
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'No Inventory exists in the Truck Location: '
                || pv_src_locator);
        END IF;

        insert_message (
            'LOG',
            'Validating SKU Configuration in Destination Organization');

        FOR rec_validate_item_config IN cur_validate_item_config
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Item Not purchase enabled or Internal Order Enabled Dest Org: '
                || rec_validate_item_config.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        insert_message (
            'LOG',
            'Validating SKU Configuration in Source Organization');

        FOR rec_validate_item_config_src IN cur_validate_item_config_src
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Item Not purchase enabled or Internal Order Enabled in Source Org: '
                || rec_validate_item_config_src.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Items doesnt exist in Destination Org */
        insert_message ('LOG',
                        'Checking Item exist or not in Destination Org');

        FOR rec_item_exists IN cur_item_exists
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Item doesnt exists in Destination Org: ' || rec_item_exists.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Reservations */
        insert_message ('LOG', 'Checking for Reservation');

        FOR rec_check_reservations IN cur_check_reservations
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Reservations exists for SKU: ' || rec_check_reservations.segment1);
        END LOOP;

        insert_message (
            'BOTH',
            '+-------------------------End Validation------------------------------------+');
        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');


        RETURN lv_return_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Unexpected error while Validating the Program :' || SQLERRM);
            lv_return_status   := 'E';
            RETURN lv_return_status;
            ROLLBACK;
    END;


    PROCEDURE insert_into_oh_table (pv_brand IN VARCHAR2, pr_src_organization IN organization_rec, pv_src_subinv IN VARCHAR2
                                    , pv_src_locator IN VARCHAR2, pr_dest_organization IN organization_rec, pv_return_status OUT VARCHAR2)
    IS
        CURSOR c_rec IS
            SELECT (SELECT operating_unit
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = a.organization_id)
                       org_id,
                   a.organization_id,
                   a.organization_code,
                   a.inventory_item_id,
                   a.primary_transaction_quantity
                       ttl_qty,
                   a.transaction_uom_code
                       uom_code,
                   LEAST (
                       receipt_quantity,
                         LEAST (primary_transaction_quantity - running_total,
                                primary_transaction_quantity)
                       + receipt_quantity)
                       quantity,
                   rcv_date
                       inv_date,
                   apps.iid_to_sku (inventory_item_id)
                       sku,
                   (SELECT brand
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = a.organization_id
                           AND vw.inventory_item_id = a.inventory_item_id)
                       brand,
                   (SELECT style_number
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = a.organization_id
                           AND vw.inventory_item_id = a.inventory_item_id)
                       style,
                   (SELECT list_price_per_unit
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = a.organization_id
                           AND msib.inventory_item_id = a.inventory_item_id)
                       unit_price
              FROM (  SELECT moqd.organization_id, mp.organization_code, moqd.primary_transaction_quantity,
                             moqd.transaction_uom_code, moqd.inventory_item_id, rt.quantity receipt_quantity,
                             rt.transaction_date rcv_date, SUM (rt.quantity) OVER (PARTITION BY moqd.organization_id, moqd.inventory_item_id ORDER BY rt.transaction_date DESC) AS running_total
                        FROM (  SELECT moqd1.organization_id, SUM (moqd1.primary_transaction_quantity) primary_transaction_quantity, moqd1.inventory_item_id,
                                       moqd1.transaction_uom_code
                                  FROM apps.mtl_onhand_quantities_detail moqd1, apps.mtl_item_locations_kfv mil
                                 WHERE     moqd1.subinventory_code =
                                           pv_src_subinv
                                       AND moqd1.organization_id =
                                           pr_src_organization.organization_id
                                       AND mil.concatenated_segments =
                                           pv_src_locator
                                       AND mil.subinventory_code(+) =
                                           moqd1.subinventory_code
                                       AND mil.inventory_location_id(+) =
                                           moqd1.locator_id
                                       AND mil.organization_id(+) =
                                           moqd1.organization_id
                              GROUP BY moqd1.organization_id, moqd1.inventory_item_id, moqd1.transaction_uom_code)
                             moqd,
                             (SELECT *                            --1.1 Update
                                FROM (  SELECT rt1.organization_id,
                                               NVL (TO_DATE (prla.attribute11),
                                                    TRUNC (rt1.transaction_date))
                                                   transaction_date,
                                                 SUM (rt1.quantity)
                                               - SUM (
                                                     NVL (
                                                         (SELECT SUM (ordered_quantity) iso_qty
                                                            FROM oe_order_headers_all ooha, oe_order_lines_all oola, po_requisition_lines_all prla1,
                                                                 po_requisition_headers_all prha1
                                                           WHERE     ooha.header_id =
                                                                     oola.header_id
                                                                 AND oola.order_source_id =
                                                                     10
                                                                 AND oola.inventory_item_id =
                                                                     prla1.item_id
                                                                 AND oola.source_document_line_id =
                                                                     prla1.requisition_line_id
                                                                 AND prla1.requisition_header_id =
                                                                     prha1.requisition_header_id
                                                                 AND NVL (
                                                                         prla1.cancel_flag,
                                                                         'N') =
                                                                     'N'
                                                                 AND prha1.interface_source_code LIKE
                                                                         'PHYSICAL_MOVE-%'
                                                                 AND oola.inventory_item_id =
                                                                     rsl.item_id
                                                                 AND oola.ship_from_org_id =
                                                                     rsl.to_organization_id
                                                                 AND NVL (
                                                                         TO_DATE (
                                                                             prla.attribute11),
                                                                         TRUNC (
                                                                             rt1.transaction_date)) =
                                                                     TO_DATE (
                                                                         prla1.attribute11)),
                                                         0))         --End 1.1
                                                   quantity,
                                               rsl.item_id
                                          FROM rcv_transactions rt1,
                                               rcv_shipment_lines rsl,
                                               (SELECT requisition_line_id, attribute11
                                                  FROM po_requisition_lines_all
                                                 WHERE attribute11 IS NOT NULL)
                                               prla
                                         WHERE     transaction_type = 'DELIVER'
                                               AND rt1.destination_type_code =
                                                   'INVENTORY'
                                               AND rt1.source_document_code IN
                                                       ('PO', 'REQ')
                                               AND rt1.shipment_line_id =
                                                   rsl.shipment_line_id
                                               AND rsl.requisition_line_id =
                                                   prla.requisition_line_id(+)
                                      GROUP BY rt1.organization_id, NVL (TO_DATE (prla.attribute11), TRUNC (rt1.transaction_date)), rsl.item_id)
                                     a
                               WHERE a.quantity > 0) rt,
                             mtl_parameters mp
                       WHERE     1 = 1
                             AND moqd.organization_id = rt.organization_id
                             AND moqd.inventory_item_id = rt.item_id
                             AND moqd.organization_id = mp.organization_id
                             AND mp.organization_id =
                                 pr_src_organization.organization_id
                             AND moqd.inventory_item_id IN
                                     (SELECT DISTINCT inventory_item_id
                                        FROM apps.xxd_common_items_v
                                       WHERE     brand = pv_brand
                                             AND organization_id =
                                                 gn_master_org)
                    ORDER BY moqd.organization_id, moqd.inventory_item_id, rt.transaction_date DESC)
                   a
             WHERE   LEAST (primary_transaction_quantity - running_total,
                            primary_transaction_quantity)
                   + receipt_quantity >
                   0
            UNION
            SELECT (SELECT operating_unit
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = moqd.organization_id)
                       org_id,
                   moqd.organization_id,
                   organization_code,
                   inventory_item_id,
                   primary_transaction_quantity,
                   transaction_uom_code,
                     primary_transaction_quantity
                   - NVL (
                         (SELECT SUM (rt1.quantity)
                            FROM rcv_transactions rt1, rcv_shipment_lines rsl
                           WHERE     transaction_type = 'DELIVER'
                                 AND rt1.source_document_code IN
                                         ('PO', 'REQ')
                                 AND rt1.shipment_line_id =
                                     rsl.shipment_line_id
                                 AND moqd.organization_id =
                                     rt1.organization_id
                                 AND moqd.inventory_item_id = rsl.item_id),
                         0)
                       qty,
                   TRUNC (SYSDATE - 30, 'month') + 14
                       inv_date,
                   apps.iid_to_sku (inventory_item_id)
                       sku,
                   (SELECT brand
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = moqd.organization_id
                           AND vw.inventory_item_id = moqd.inventory_item_id)
                       brand,
                   (SELECT style_number
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = moqd.organization_id
                           AND vw.inventory_item_id = moqd.inventory_item_id)
                       style,
                   (SELECT list_price_per_unit
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = moqd.organization_id
                           AND msib.inventory_item_id =
                               moqd.inventory_item_id)
                       unit_price
              FROM (  SELECT moqd1.organization_id, moqd1.transaction_uom_code, SUM (moqd1.primary_transaction_quantity) primary_transaction_quantity,
                             moqd1.inventory_item_id
                        FROM apps.mtl_onhand_quantities_detail moqd1, apps.mtl_item_locations_kfv mil
                       WHERE     moqd1.subinventory_code = pv_src_subinv
                             AND moqd1.organization_id =
                                 pr_src_organization.organization_id
                             AND mil.concatenated_segments = pv_src_locator
                             AND mil.subinventory_code(+) =
                                 moqd1.subinventory_code
                             AND mil.inventory_location_id(+) =
                                 moqd1.locator_id
                             AND mil.organization_id(+) = moqd1.organization_id
                    GROUP BY moqd1.organization_id, moqd1.inventory_item_id, moqd1.transaction_uom_code)
                   moqd,
                   mtl_parameters mp
             WHERE     1 = 1
                   AND primary_transaction_quantity >
                       NVL (
                           (SELECT SUM (rt1.quantity)
                              FROM rcv_transactions rt1,
                                   rcv_shipment_lines rsl,
                                   (SELECT requisition_line_id, attribute11
                                      FROM po_requisition_lines_all
                                     WHERE attribute11 IS NOT NULL) prla1
                             WHERE     transaction_type = 'DELIVER'
                                   AND rt1.source_document_code IN
                                           ('PO', 'REQ')
                                   AND rt1.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND moqd.organization_id =
                                       rt1.organization_id
                                   AND moqd.inventory_item_id = rsl.item_id
                                   AND rt1.requisition_line_id =
                                       prla1.requisition_line_id(+)),
                           0)
                   AND moqd.organization_id = mp.organization_id
                   AND mp.organization_id =
                       pr_src_organization.organization_id
                   AND moqd.inventory_item_id IN
                           (SELECT DISTINCT inventory_item_id
                              FROM apps.xxd_common_items_v
                             WHERE     brand = pv_brand
                                   AND organization_id = gn_master_org)
            ORDER BY 2, 4, 8 DESC;

        ln_record_id           NUMBER;
        ld_need_by_date        DATE;
        ln_group_number        NUMBER := 1;
        ln_rec_number          NUMBER := 1;
        n_cnt                  NUMBER;
        ln_inventory_item_id   NUMBER;
        ln_err_cnt             NUMBER := 0;
        ln_locator_id          NUMBER;
    BEGIN
        insert_message ('LOG', 'Inside Onhand Insert Procedure');

        --Get Need By Date for req
        SELECT TRUNC (DECODE (TO_CHAR (SYSDATE, 'FMDAY'),  'FRIDAY', SYSDATE + 3,  'SATURDAY', SYSDATE + 2,  SYSDATE + 1))
          INTO ld_need_by_date
          FROM DUAL;

        BEGIN
            SELECT inventory_location_id
              INTO ln_locator_id
              FROM mtl_item_locations_kfv kv
             WHERE KV.CONCATENATED_SEGMENTS = pv_src_locator;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_locator_id   := NULL;
        END;

        --Get next group value from seq
        SELECT XXD_WMS_OH_IR_XFER_GRP_SEQ.NEXTVAL
          INTO ln_group_number
          FROM DUAL;

        FOR rec IN c_rec
        LOOP
            SELECT XXD_WMS_OH_IR_XFER_SEQ.NEXTVAL INTO ln_record_id FROM DUAL;

            BEGIN
                INSERT INTO XXD_WMS_OH_IR_XFER_STG (RECORD_ID,
                                                    ORG_ID,
                                                    ORGANIZATION_ID,
                                                    SUBINVENTORY_CODE,
                                                    DEST_ORG_ID,
                                                    DEST_ORGANIZATION_ID,
                                                    DEST_LOCATION_ID,
                                                    DEST_SUBINVENTORY_CODE,
                                                    NEED_BY_DATE,
                                                    BRAND,
                                                    STYLE,
                                                    SKU,
                                                    INVENTORY_ITEM_ID,
                                                    UOM_CODE,
                                                    GROUP_NO,
                                                    QUANTITY,
                                                    UNIT_PRICE,
                                                    AGING_DATE,
                                                    CHARGE_ACCOUNT_ID,
                                                    REQ_HEADER_ID,
                                                    REQ_LINE_ID,
                                                    STATUS,
                                                    MESSAGE,
                                                    REQUEST_ID,
                                                    CREATION_DATE,
                                                    CREATED_BY,
                                                    LAST_UPDATE_DATE,
                                                    LAST_UPDATED_BY,
                                                    LOCATOR_NAME,
                                                    LOCATOR_ID)
                         VALUES (ln_record_id,
                                 rec.org_id,
                                 rec.organization_id,
                                 pv_src_subinv,
                                 pr_dest_organization.org_id,
                                 pr_dest_organization.organization_id,
                                 pr_dest_organization.location_id,
                                 NULL,               -- rec.subinventory_code,
                                 ld_need_by_date,
                                 rec.brand,
                                 rec.style,                            --style
                                 rec.sku,
                                 rec.inventory_item_id,
                                 rec.uom_code,
                                 ln_group_number,               --group_number
                                 rec.quantity,
                                 rec.unit_price,
                                 rec.inv_date,
                                 pr_dest_organization.material_account_id, --charge_account_id,
                                 NULL,                        --rec_header_id,
                                 NULL,                           --rec_line_id
                                 'N',                                --status,
                                 NULL,                              --message,
                                 gn_request_id,                  --request_id,
                                 SYSDATE,
                                 fnd_global.user_id,
                                 SYSDATE,
                                 fnd_global.user_id,
                                 pv_src_locator,
                                 ln_locator_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    insert_message (
                        'BOTH',
                           'Inv Org ID : '
                        || rec.organization_id
                        || ' Item : '
                        || rec.inventory_item_id
                        || ' Aging Date '
                        || TO_CHAR (rec.inv_date, 'MM-DD-YYYY')
                        || '-'
                        || SQLERRM);
                    ln_err_cnt   := ln_err_cnt + 1;
            END;
        END LOOP;

        IF ln_err_cnt > 0
        THEN
            ROLLBACK;
            pv_return_status   := 'E';
            insert_message (
                'BOTH',
                'One or more records failed to insert. Batch rolled back.');
            RETURN;
        END IF;


        COMMIT;

        SELECT COUNT (*)
          INTO n_cnt
          FROM XXD_WMS_OH_IR_XFER_STG
         WHERE request_id = gn_request_id;

        IF n_cnt = 0
        THEN
            insert_message ('BOTH', 'No Records inserted');
            pv_return_status   := 'E';

            RETURN;
        END IF;

        pv_return_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            insert_message ('BOTH', SQLERRM);
            pv_return_status   := 'E';
    END;

    PROCEDURE create_oh_xfer_ir (pv_brand IN VARCHAR2, pr_src_organization IN organization_rec, pr_dest_organization IN organization_rec
                                 , pv_return_status OUT VARCHAR2)
    IS
        CURSOR c_header_rec IS
            SELECT DISTINCT group_no, dest_org_id
              FROM XXDO.XXD_WMS_OH_IR_XFER_STG stg
             WHERE     organization_id = pr_src_organization.organization_id
                   AND brand = pv_brand
                   AND request_id = gn_request_id
                   AND status = 'P';


        CURSOR c_line_rec (n_group_no NUMBER)
        IS
            SELECT record_id, org_id, dest_org_id,
                   charge_account_id, organization_id, uom_code,
                   quantity, dest_organization_id, dest_location_id,
                   inventory_item_id, aging_date, need_by_date,
                   subinventory_code
              FROM XXDO.XXD_WMS_OH_IR_XFER_STG stg
             WHERE group_no = n_group_no;


        lv_src_type_code    VARCHAR2 (20) := 'INVENTORY';
        lv_dest_type_code   VARCHAR2 (20) := 'INVENTORY';
        lv_source_code      VARCHAR2 (50)
            := gv_ir_interface_source_code || '-' || gn_request_id;
        ln_batch_id         NUMBER := 1;
        l_request_id        NUMBER;
        l_req_status        BOOLEAN;
        l_dest_org          NUMBER;
        l_req_quantity      NUMBER;
        ln_ir_rcv_qty       NUMBER;

        --TODO: need to determine these.
        ln_person_id        NUMBER;
        ln_user_id          NUMBER;


        l_phase             VARCHAR2 (80);
        l_status            VARCHAR2 (80);
        l_dev_phase         VARCHAR2 (80);
        l_dev_status        VARCHAR2 (80);
        l_message           VARCHAR2 (255);

        pv_error_stat       VARCHAR2 (1);
        pv_error_msg        VARCHAR2 (2000);

        ln_req_header_id    NUMBER;
        lv_req_number       VARCHAR2 (20);
        ln_req_ttl_qty      NUMBER := 0;

        ld_need_by_date     DATE;

        exREQHeader         EXCEPTION;
    BEGIN
        insert_message ('BOTH',
                        'Create IR - Begin  Src : ' || lv_source_code);

        BEGIN
            SELECT employee_id
              INTO ln_person_id
              FROM fnd_user
             WHERE user_name = fnd_global.user_name;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                --User is not a buyer
                insert_message ('BOTH', 'User is not a buyer');
                pv_error_stat   := pv_error_stat;
                pv_error_msg    := 'User is not a buyer';
                RETURN;
        END;



        FOR h_rec IN c_header_rec
        LOOP
            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', h_rec.dest_org_id);
            FND_REQUEST.SET_ORG_ID (h_rec.dest_org_id);

            insert_message (
                'BOTH',
                'Start Header Loop. Group No : ' || h_rec.group_no);

            BEGIN
                SAVEPOINT rec_header;

                FOR l_rec IN c_line_rec (h_rec.group_no)
                LOOP
                    l_req_quantity   := l_rec.quantity;

                    IF l_req_quantity > 0
                    THEN
                        ln_req_ttl_qty   := ln_req_ttl_qty + l_req_quantity;
                        insert_message (
                            'BOTH',
                               'Need by date '
                            || TO_CHAR (l_rec.need_by_date, 'DD-MON-YYYY'));

                        INSERT INTO APPS.PO_REQUISITIONS_INTERFACE_ALL (
                                        BATCH_ID,
                                        INTERFACE_SOURCE_CODE,
                                        ORG_ID,
                                        DESTINATION_TYPE_CODE,
                                        AUTHORIZATION_STATUS,
                                        PREPARER_ID,
                                        CHARGE_ACCOUNT_ID,
                                        SOURCE_TYPE_CODE,
                                        SOURCE_ORGANIZATION_ID,
                                        UOM_CODE,
                                        LINE_TYPE_ID,
                                        QUANTITY,
                                        UNIT_PRICE,
                                        DESTINATION_ORGANIZATION_ID,
                                        DELIVER_TO_LOCATION_ID,
                                        DELIVER_TO_REQUESTOR_ID,
                                        ITEM_ID,
                                        SUGGESTED_VENDOR_ID,
                                        SUGGESTED_VENDOR_SITE_ID,
                                        HEADER_DESCRIPTION,
                                        NEED_BY_DATE,
                                        LINE_ATTRIBUTE11,
                                        line_attribute15,
                                        CREATION_DATE,
                                        CREATED_BY,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY) --Place SO organization code in this field
                                 VALUES (
                                            h_rec.group_no,
                                            lv_source_code,
                                            l_rec.dest_org_id,
                                            lv_dest_type_code,
                                            'APPROVED',
                                            ln_person_id,
                                            l_rec.charge_account_id,
                                            lv_src_type_code,
                                            l_rec.organization_id,
                                            (SELECT primary_uom_code
                                               FROM apps.mtl_system_items_b
                                              WHERE     inventory_item_id =
                                                        l_rec.inventory_item_id
                                                    AND organization_id =
                                                        l_rec.dest_organization_id),
                                            1,
                                            l_req_quantity,
                                            (SELECT list_price_per_unit
                                               FROM apps.mtl_system_items_b
                                              WHERE     inventory_item_id =
                                                        l_rec.inventory_item_id
                                                    AND organization_id =
                                                        l_rec.dest_organization_id),
                                            l_rec.dest_organization_id,
                                            l_rec.dest_location_id,
                                            ln_person_id,
                                            l_rec.inventory_item_id,
                                            NULL,
                                            NULL,
                                            /*   (SELECT description
                                                  FROM apps.mtl_system_items_b
                                                 WHERE     inventory_item_id = l_rec.inventory_item_id
                                                       AND organization_id =
                                                              l_rec.dest_organization_id),*/
                                            NULL,         --header description
                                            l_rec.need_by_date,
                                            TO_CHAR (l_rec.aging_date,
                                                     'DD-MON-YYYY'),
                                            TO_CHAR (l_rec.record_id), --Pointer to sourcing staging record for mapping
                                            SYSDATE,
                                            ln_user_id,
                                            SYSDATE,
                                            ln_user_id); --Set autosource to P so that passed in vendor/vendor site is used
                    ELSE
                        insert_message (
                            'BOTH',
                            'No quantity added to REQ for item : ' || apps.iid_to_sku (l_rec.inventory_item_id));
                    END IF;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --Roolback this REQ then proceed top next header
                    insert_message ('BOTH', 'Hit rollback: ' || SQLERRM);
                    ROLLBACK TO exREQHeader;
                    CONTINUE;
            END;

            IF ln_req_ttl_qty > 0
            THEN
                BEGIN
                    SELECT MAX (need_by_date)
                      INTO ld_need_by_date
                      FROM po_requisitions_interface_all
                     WHERE batch_id = h_rec.group_no;
                --    log_errors (
                --      'IFACE : ' || TO_CHAR (ld_need_by_date, 'MM/DD/YYYY'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;


                insert_message (
                    'BOTH',
                    'Before Concurrent Request. Group No  :' || h_rec.group_no);
                insert_message ('BOTH',
                                'Interface Source Code  :' || lv_source_code);

                COMMIT;

                exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => l_request_id, pv_application => 'PO', pv_program => 'REQIMPORT', pv_argument1 => lv_source_code, --Interface source code
                                                                                                                                                                                                                   pv_argument2 => h_rec.group_no, --batch id
                                                                                                                                                                                                                                                   pv_argument3 => 'INVENTORY', pv_argument4 => '', pv_argument5 => 'N', pv_argument6 => 'Y', pv_wait_for_request => 'Y'
                                   , pn_interval => 10, pn_max_wait => 0);

                IF pv_error_stat != 'S'
                THEN
                    pv_error_stat   := pv_error_stat;
                    pv_error_msg    :=
                        'Requisition import error : ' || pv_error_msg;
                    RETURN;
                END IF;

                insert_message ('BOTH', 'Check Req Created');
                insert_message ('BOTH', 'Source Code : ' || lv_source_code);
                insert_message ('BOTH', 'Req ID : ' || l_request_id);

                --Get req created
                BEGIN
                    SELECT requisition_header_id, segment1
                      INTO ln_req_header_id, lv_req_number
                      FROM po_requisition_headers_all
                     WHERE     interface_source_code = lv_source_code
                           AND request_id = l_request_id;
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        --Multiple Reqs created. No error
                        NULL;
                    WHEN NO_DATA_FOUND
                    THEN
                        --If we cannot reteieve the created IR fail these records and continue to next group
                        pv_return_status   := 'E';

                        --pv_error_msg := 'Unable to find created Requisition';

                        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
                           SET status = 'E', MESSAGE = 'Error retrieving created internal requisition'
                         WHERE GROUP_NO = h_rec.group_no;

                        insert_message ('BOTH', 'No REQ created');

                        CONTINUE;
                END;
            ELSE
                pv_return_status   := 'E';
                insert_message ('BOTH', 'No items to be added to REQ');
            END IF;

            --check/update stg records that werenot added to REQ
            UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
               SET status = 'E', MESSAGE = 'Item not added to requisition'
             WHERE     GROUP_NO = h_rec.group_no
                   AND request_id = gn_request_id
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_header_id =
                                       prha.requisition_header_id
                                   AND prha.interface_source_code =
                                       lv_source_code
                                   AND prla.attribute15 =
                                       TO_CHAR (stg.record_id));

            IF SQL%ROWCOUNT > 0
            THEN
                COMMIT;
                pv_error_msg       :=
                       'One or more items from the locator were not added to requisition: '
                    || lv_req_number;
                pv_return_status   := 'E';
                RETURN;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_return_status   := 'E';
    --pv_error_msg := SQLERRM;
    END;



    PROCEDURE insert_iso_data (pr_src_organization IN organization_rec, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2)
    IS
        ln_ordered_quantity     NUMBER;
        ln_remaining_quantity   NUMBER;
        lv_requisition_number   VARCHAR2 (50);

        CURSOR c_item_details IS
              SELECT moqd.inventory_item_id, msi.segment1 item_number, muc.conversion_rate cpq,
                     SUM (moqd.transaction_quantity) quantity
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_uom_conversions muc, apps.mtl_system_items_kfv msi,
                     apps.mtl_item_locations_kfv mil
               WHERE     moqd.organization_id =
                         pr_src_organization.organization_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.inventory_item_id = muc.inventory_item_id
                     AND muc.disable_date IS NULL
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND mil.concatenated_segments = pv_src_locator
            GROUP BY moqd.inventory_item_id, muc.conversion_rate, msi.segment1,
                     msi.primary_uom_code
            ORDER BY moqd.inventory_item_id;

        CURSOR c_order_data IS
              SELECT ooha.header_id, ooha.order_number, flv.meaning
                FROM apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
               WHERE     flv.lookup_type = 'XXD_WMS_BLANKET_ISO_LIST'
                     AND flv.language = 'US'
                     AND ooha.order_number = flv.lookup_code
                     AND flv.enabled_flag = 'Y'
            ORDER BY flv.tag;
    BEGIN
        insert_message ('LOG', 'Inside ISO Data Procedure');

        FOR r_item_details IN c_item_details
        LOOP
            ln_remaining_quantity   := r_item_details.quantity;

            FOR r_order_data IN c_order_data
            LOOP
                BEGIN
                    SELECT NVL (SUM (ordered_quantity), 0)
                      INTO ln_ordered_quantity
                      FROM apps.oe_order_lines_all
                     WHERE     header_id = r_order_data.header_id
                           AND inventory_item_id =
                               r_item_details.inventory_item_id
                           AND open_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_ordered_quantity   := 0;
                END;

                lv_requisition_number   :=
                    get_requisition_number (
                        gv_ir_interface_source_code || '-' || gn_request_id);



                IF     ln_ordered_quantity >= ln_remaining_quantity
                   AND ln_ordered_quantity > 0
                THEN
                    INSERT INTO XXDO.XXD_WMS_ISO_ITEM_ATP_STG (ISO_NUMBER, ITEM_NUMBER, INVENTORY_ITEM_ID, QUANTITY, INTERNAL_REQUISITION, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY
                                                               , REQUEST_ID)
                         VALUES (r_order_data.order_number, r_item_details.item_number, r_item_details.inventory_item_id, ln_remaining_quantity, lv_requisition_number, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                 , gn_request_id);

                    EXIT;
                ELSIF     ln_ordered_quantity > 0
                      AND ln_ordered_quantity < ln_remaining_quantity
                THEN
                    ln_remaining_quantity   :=
                        ln_remaining_quantity - ln_ordered_quantity;

                    INSERT INTO XXDO.XXD_WMS_ISO_ITEM_ATP_STG (ISO_NUMBER, ITEM_NUMBER, INVENTORY_ITEM_ID, QUANTITY, INTERNAL_REQUISITION, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY
                                                               , REQUEST_ID)
                         VALUES (r_order_data.order_number, r_item_details.item_number, r_item_details.inventory_item_id, ln_ordered_quantity, lv_requisition_number, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                 , gn_request_id);
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message ('LOG',
                            'Inside Releieve ATP Exception: ' || SQLERRM);
    END insert_iso_data;

    PROCEDURE relieve_atp (pr_src_organization IN organization_rec)
    IS
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (500);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);

        CURSOR c_order_number IS
              SELECT DISTINCT iso_number, ooha.header_id
                FROM xxdo.xxd_wms_iso_item_atp_stg stg, apps.oe_order_headers_all ooha
               WHERE     stg.request_id = gn_request_id
                     AND stg.iso_number = ooha.order_number
            ORDER BY iso_number;


        CURSOR c_line_details (pv_order_number VARCHAR2)
        IS
              SELECT oola.line_id, oola.line_number, oola.header_id,
                     oola.ordered_quantity, oola.ordered_item, oola.request_date,
                     stg.quantity stg_quantity
                FROM xxdo.xxd_wms_iso_item_atp_stg stg, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
               WHERE     stg.request_id = gn_request_id
                     AND stg.iso_number = ooha.order_number
                     AND ooha.order_number = pv_order_number
                     AND ooha.header_id = oola.header_id
                     AND oola.ordered_item = stg.item_number
                     AND oola.open_flag = 'Y'
            ORDER BY oola.ordered_quantity DESC;

        ln_ordered_quantity            NUMBER;
        ln_total_sum                   NUMBER;
        ln_initial_quantity            NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
    BEGIN
        insert_message ('LOG', 'Inside Releieve ATP Procedure');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Super User - Macau EMEA'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 52736;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_batchO2F_ID,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (pr_src_organization.org_id, NULL, 'ONT');

        FOR r_order_number IN c_order_number
        LOOP
            oe_debug_pub.initialize;
            oe_msg_pub.initialize;
            l_line_tbl_index         := 1;
            l_line_tbl.delete ();
            insert_message (
                'LOG',
                'Processing for Placeholder Order: ' || r_order_number.iso_number);

            l_header_rec             := OE_ORDER_PUB.G_MISS_HEADER_REC;
            l_header_rec.header_id   := r_order_number.header_id;
            l_header_rec.operation   := OE_GLOBALS.G_OPR_UPDATE;

            FOR r_line_details IN c_line_details (r_order_number.iso_number)
            LOOP
                ln_ordered_quantity                                    :=
                    GREATEST (
                        r_line_details.ordered_quantity - r_line_details.stg_quantity,
                        0);

                insert_message (
                    'LOG',
                       'Relieving ATP for Item: '
                    || r_line_details.ordered_item
                    || ', Line Number: '
                    || r_line_details.line_number
                    || ', for quantity: '
                    || r_line_details.ordered_quantity
                    || 'Order Quantity: '
                    || r_line_details.ordered_quantity
                    || ', Stage Quantity: '
                    || r_line_details.stg_quantity
                    || ', remaining on order: '
                    || ln_ordered_quantity);
                -- Changed attributes
                l_line_tbl (l_line_tbl_index)                          :=
                    OE_ORDER_PUB.G_MISS_LINE_REC;
                l_line_tbl (l_line_tbl_index).operation                :=
                    OE_GLOBALS.G_OPR_UPDATE;
                l_line_tbl (l_line_tbl_index).header_id                :=
                    r_line_details.header_id;        -- header_id of the order
                l_line_tbl (l_line_tbl_index).line_id                  :=
                    r_line_details.line_id;       -- line_id of the order line
                l_line_tbl (l_line_tbl_index).ordered_quantity         :=
                    ln_ordered_quantity;               -- new ordered quantity
                l_line_tbl (l_line_tbl_index).Override_atp_date_code   := 'Y';
                l_line_tbl (l_line_tbl_index).change_reason            := '1'; -- change reason code
                l_line_tbl (l_line_tbl_index).schedule_arrival_date    :=
                    r_line_details.request_date;
                l_line_tbl_index                                       :=
                    l_line_tbl_index + 1;
            END LOOP;

            IF l_line_tbl.COUNT > 0
            THEN
                -- CALL TO PROCESS ORDER
                OE_ORDER_PUB.process_order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => l_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    x_header_rec               => p_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_Header_Adj_tbl           => x_Header_Adj_tbl,
                    x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
                    x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
                    x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
                    x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
                    x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
                    x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
                    x_line_tbl                 => p_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_Line_Adj_tbl             => x_Line_Adj_tbl,
                    x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
                    x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
                    x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
                    x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
                    x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
                    x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
                    x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
                    x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
                    x_action_request_tbl       => p_action_request_tbl);

                -- Check the return status
                IF l_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    insert_message ('LOG', 'Line Quantity Update Sucessful');
                    COMMIT;
                ELSE
                    -- Retrieve messages
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        insert_message (
                            'LOG',
                            'message index is: ' || l_msg_index_out);
                        insert_message ('LOG', 'message is: ' || l_msg_data);
                    END LOOP;

                    insert_message ('LOG', 'Relieving ATP Failed');

                    UPDATE xxdo.xxd_wms_iso_item_atp_stg stg
                       SET attribute1   = 'Relieving ATP Failed'
                     WHERE     iso_number = r_order_number.iso_number
                           AND request_id = gn_request_id;
                END IF;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message ('LOG',
                            'Exception while relieving ATP: ' || SQLERRM);
    END relieve_atp;

    PROCEDURE create_internal_orders (pr_src_organization IN organization_rec, pv_return_status OUT VARCHAR2)
    IS
        ln_req_request_id   NUMBER;
        ln_resp_id          NUMBER;
        ln_resp_appl_id     NUMBER;
        lv_chr_phase        VARCHAR2 (120 BYTE);
        lv_chr_status       VARCHAR2 (120 BYTE);
        lv_chr_dev_phase    VARCHAR2 (120 BYTE);
        lv_chr_dev_status   VARCHAR2 (120 BYTE);
        lv_chr_message      VARCHAR2 (2000 BYTE);
        lb_bol_result       BOOLEAN;
    BEGIN
        insert_message ('LOG', 'Inside Create Internal Orders');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name = 'Deckers 3PL User'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 51618;
                ln_resp_appl_id   := 385;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        FND_REQUEST.SET_ORG_ID (pr_src_organization.org_id);

        ln_req_request_id   :=
            apps.fnd_request.submit_request (application => 'PO', -- application short name
                                                                  program => 'POCISO', -- program short name
                                                                                       start_time => SYSDATE
                                             , sub_request => FALSE);

        COMMIT;

        IF ln_req_request_id <> 0
        THEN
            insert_message (
                'LOG',
                'Create Internal Orders Request Id: ' || ln_req_request_id);
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF lv_chr_dev_phase = 'COMPLETE'
            THEN
                insert_message ('LOG', 'Create Internal Completed');

                IF lv_chr_status = 'Normal'
                THEN
                    pv_return_status   := 'S';
                    insert_message (
                        'LOG',
                        'Internal order program completed successfully');
                END IF;
            ELSE
                insert_message ('LOG', 'Create Internal Not Completed Yet');
            END IF;
        END IF;
    END create_internal_orders;

    PROCEDURE run_order_import (
        pr_src_organization   IN     organization_rec,
        pv_return_status         OUT VARCHAR2)
    IS
        ln_req_request_id    NUMBER;
        ln_resp_id           NUMBER;
        ln_resp_appl_id      NUMBER;
        ln_requisition_id    NUMBER;
        lv_requisition_num   VARCHAR2 (100);
        lv_chr_phase         VARCHAR2 (120 BYTE);
        lv_chr_status        VARCHAR2 (120 BYTE);
        lv_chr_dev_phase     VARCHAR2 (120 BYTE);
        lv_chr_dev_status    VARCHAR2 (120 BYTE);
        lv_chr_message       VARCHAR2 (2000 BYTE);
        lb_bol_result        BOOLEAN;
    BEGIN
        insert_message ('LOG', 'Inside Order Import program');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name = 'Deckers 3PL User'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 51618;
                ln_resp_appl_id   := 385;
        END;

        BEGIN
            SELECT requisition_header_id, segment1
              INTO ln_requisition_id, lv_requisition_num
              FROM apps.po_requisition_headers_all
             WHERE interface_source_code =
                   gv_ir_interface_source_code || '-' || gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_requisition_id   := NULL;
        END;

        IF lv_requisition_num IS NOT NULL
        THEN
            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET INTERNAL_REQUISITION   = lv_requisition_num
             WHERE REQUEST_ID = gn_request_id;

            COMMIT;

            insert_message ('BOTH',
                            'Requisition Number: ' || lv_requisition_num);
        END IF;


        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (pr_src_organization.org_id, NULL, 'ONT');

        ln_req_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',              -- application short name
                program       => 'OEOIMP',               -- program short name
                argument1     => pr_src_organization.org_id, -- Operating Unit
                argument2     => 10,                         -- Internal Order
                argument3     => NVL (ln_requisition_id, NULL), -- Orig Sys Document Ref
                argument4     => NULL,                       -- operation code
                argument5     => 'N',                         -- Validate Only
                argument6     => NULL,                          -- Debug level
                argument7     => 4,                               -- Instances
                argument8     => NULL,                       -- Sold to Org Id
                argument9     => NULL,                          -- Sold To Org
                argument10    => NULL,                           -- Change seq
                argument11    => NULL,                           -- Perf Param
                argument12    => 'N',                  -- Trim Trailing Blanks
                argument13    => NULL,           -- Process Orders with no org
                argument14    => NULL,                       -- Default org id
                argument15    => 'Y'              -- Validate Desc Flex Fields
                                    );



        COMMIT;

        IF ln_req_request_id <> 0
        THEN
            insert_message ('LOG',
                            'Order Import Request Id: ' || ln_req_request_id);
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF UPPER (lv_chr_dev_phase) = 'COMPLETE'
            THEN
                IF UPPER (lv_chr_status) = 'NORMAL'
                THEN
                    pv_return_status   := 'S';
                    insert_message ('LOG',
                                    'Order Import completed successfully');
                END IF;
            ELSE
                insert_message ('LOG', 'Create Internal Not Completed Yet');
            END IF;
        END IF;
    END run_order_import;

    PROCEDURE schedule_iso
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (4000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (4000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.Line_Rec_Type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;

        CURSOR header_cur IS
            SELECT DISTINCT ooha.order_number, ooha.header_id order_id, ooha.org_id
              FROM apps.po_requisition_headers_all prh, apps.oe_order_headers_all ooha
             WHERE     prh.interface_source_code =
                       gv_ir_interface_source_code || '-' || gn_request_id
                   AND prh.segment1 = ooha.orig_sys_document_ref
                   AND ooha.open_flag = 'Y';

        CURSOR line_cur (p_order_id NUMBER)
        IS
            SELECT DISTINCT oel.line_id, oel.request_date
              FROM apps.oe_order_lines_all oel
             WHERE     oel.header_id = p_order_id
                   AND oel.flow_status_code IN ('BOOKED')
                   AND oel.schedule_ship_date IS NULL
                   AND oel.open_flag = 'Y';
    BEGIN
        insert_message ('LOG', 'Inside Schedule ISO procedure');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50746;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        --mo_global.Set_org_context (95, NULL, 'ONT');



        FOR header_rec IN header_cur
        LOOP
            i   := i + 1;
            j   := 0;
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            mo_global.init ('ONT');
            mo_global.Set_org_context (HEADER_REC.ORG_ID, NULL, 'ONT');
            insert_message ('LOG', 'Order id: ' || header_rec.order_id);

            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET INTERNAL_ORDER   = header_rec.order_number
             WHERE REQUEST_ID = gn_request_id;

            COMMIT;

            insert_message ('BOTH',
                            'Order Number: ' || header_rec.order_number);

            /*v_header_rec                        := oe_order_pub.g_miss_header_rec;
            v_header_rec.operation              := OE_GLOBALS.G_OPR_UPDATE;
            v_header_rec.header_id              := header_rec .order_id; */


            --v_action_request_tbl (i) := oe_order_pub.g_miss_request_rec;

            v_line_tbl.delete ();

            FOR line_rec IN line_cur (header_rec.order_id)
            LOOP
                insert_message ('LOG', 'Order Line' || line_rec.line_id);
                j                                       := j + 1;

                v_line_tbl (j)                          := OE_ORDER_PUB.G_MISS_LINE_REC;
                v_line_tbl (j).header_id                := header_rec.order_id;
                v_line_tbl (j).line_id                  := line_rec.line_id;
                v_line_tbl (j).operation                := oe_globals.G_OPR_UPDATE;
                v_line_tbl (j).OVERRIDE_ATP_DATE_CODE   := 'Y';
                v_line_tbl (j).schedule_arrival_date    :=
                    line_rec.request_date;
            --  v_line_tbl (j).schedule_ship_date := line_rec.request_date;
            --v_line_tbl(j).schedule_action_code := oe_order_sch_util.oesch_act_schedule;


            END LOOP;

            IF j > 0
            THEN
                OE_ORDER_PUB.PROCESS_ORDER (
                    p_api_version_number       => v_api_version_number,
                    p_header_rec               => v_header_rec,
                    p_line_tbl                 => v_line_tbl,
                    p_action_request_tbl       => v_action_request_tbl,
                    p_line_adj_tbl             => v_line_adj_tbl,
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
                    insert_message (
                        'LOG',
                        'Update Success for order number:' || header_rec.order_number);
                ELSE
                    insert_message (
                        'LOG',
                        'Update Failed for order number:' || header_rec.order_number);
                    insert_message (
                        'LOG',
                        'Reason is:' || SUBSTR (v_msg_data, 1, 1900));
                    ROLLBACK;

                    FOR i IN 1 .. v_msg_count
                    LOOP
                        v_msg_data   :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        insert_message ('LOG', i || ') ' || v_msg_data);
                    END LOOP;

                    insert_message ('LOG', 'v_msg_data  : ' || v_msg_data);
                END IF;
            END IF;

            COMMIT;
        END LOOP;

        COMMIT;
    -- DBMS_OUTPUT.put_line ('END OF THE PROGRAM');
    END schedule_iso;

    PROCEDURE delivery_extract (pn_delivery_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2)
    IS
    BEGIN
        NULL;
    END;

    PROCEDURE onhand_extract (pv_brand IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2
                              , pv_src_locator IN VARCHAR2)
    AS
        CURSOR cur_onhand IS
            SELECT hr_src.name
                       source_org,
                   pv_src_subinv,
                   pv_src_locator,
                   sku,
                   quantity,
                   aging_date,
                   unit_price,
                   quantity * unit_price
                       total_cost,
                   requisition_number,
                   iso_number,
                   (SELECT attribute11
                      FROM po_requisition_lines_all prla
                     WHERE stg.req_line_id = prla.requisition_line_id)
                       ir_aging_date,
                   mp_dest.organization_code
                       dest_org
              FROM xxd_wms_oh_ir_xfer_stg stg, hr_all_organization_units hr_src, mtl_parameters mp_dest
             WHERE     stg.org_id = hr_src.organization_id
                   AND stg.dest_organization_id = mp_dest.organization_id
                   AND stg.request_id = gn_request_id;
    BEGIN
        insert_message ('LOG', 'Inside Onhand Extract Procedure');

        fnd_file.put_line (
            fnd_file.output,
               'Source Org'
            || ','
            || 'Source Subinventory'
            || ','
            || 'Source Locator'
            || ','
            || 'SKU'
            || ','
            || 'Quantity'
            || ','
            || 'Aging Date'
            || ','
            || 'Unit Cost'
            || ','
            || 'Total Cost'
            || ','
            || 'Internal REQ #'
            || ','
            || 'Internal Sales Order #'
            || ','
            || 'Aging Date in ISO Line'
            || ','
            || 'ISO Destination Org');

        FOR rec_onhand IN cur_onhand
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   rec_onhand.source_org
                || ','
                || pv_src_subinv
                || ','
                || pv_src_locator
                || ','
                || rec_onhand.sku
                || ','
                || rec_onhand.quantity
                || ','
                || rec_onhand.aging_date
                || ','
                || rec_onhand.unit_price
                || ','
                || rec_onhand.total_cost
                || ','
                || rec_onhand.requisition_number
                || ','
                || rec_onhand.iso_number
                || ','
                || rec_onhand.ir_aging_date
                || ','
                || rec_onhand.dest_org);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Completed Onhand Extract Procedure');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END onhand_extract;


    PROCEDURE inv_transfer_process (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_brand IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2
                                    , pn_dest_org_id IN NUMBER)
    IS
        lv_brand                 VARCHAR2 (50);
        lv_src_org               VARCHAR2 (10);
        lv_dest_org              VARCHAR2 (10);
        lv_return_status         VARCHAR2 (1) := 'S';
        ln_dock_door_id          NUMBER;
        ln_org_id                NUMBER;
        lv_transfer_date         VARCHAR2 (100);
        lv_err_message           VARCHAR2 (2000) := NULL;

        exPreProcess             EXCEPTION;
        exProcess                EXCEPTION;

        lrec_src_organization    organization_rec;
        lrec_dest_organization   organization_rec;
    BEGIN
        --Get Source Organization Data
        lrec_src_organization    := get_organization_data (pn_src_org_id);


        --Det destination Data
        lrec_dest_organization   := get_organization_data (pn_dest_org_id);


        lv_brand                 := UPPER (pv_brand);


        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');
        insert_message (
            'BOTH',
            '+------------------------------- Parameters --------------------------------+');

        insert_message ('BOTH', 'Brand: ' || lv_brand);
        insert_message (
            'BOTH',
            'Source Org: ' || lrec_src_organization.organization_code);
        insert_message ('BOTH', 'Source Subinventory: ' || pv_src_subinv);
        insert_message ('BOTH', 'Source Locator: ' || pv_src_locator);
        insert_message (
            'BOTH',
            'Destination Org: ' || lrec_dest_organization.organization_code);
        insert_message ('LOG', 'User Name: ' || gv_user_name);
        insert_message ('LOG', 'Resp Appl ID: ' || FND_GLOBAL.RESP_APPL_ID);

        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');

        --Get inventory transfer date from lookup
        BEGIN
            SELECT flv.meaning
              INTO lv_transfer_date
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_WMS_INV_TRANSFER_DATE'
                   AND flv.language = 'US'
                   AND flv.lookup_code =
                       lrec_src_organization.organization_code
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := 'E';
                insert_message (
                    'BOTH',
                    'No Transfer Date defined for the Org in the Lookup');
                lv_err_message     :=
                    'No Transfer Date defined for the Org in the Lookup';
                RAISE exPreProcess;
        END;

        insert_message ('LOG', 'Transfer Date: ' || lv_transfer_date);

        --Validate OH data in provided src/dest
        lv_return_status         :=
            validate_data (lv_brand, lrec_src_organization, pv_src_subinv,
                           pv_src_locator, lrec_dest_organization);

        IF lv_return_status = 'E'
        THEN
            lv_err_message   := 'Validation failed. See log for details';
            RAISE exPreProcess;
        END IF;

        insert_into_oh_table (lv_brand,
                              lrec_src_organization,
                              pv_src_subinv,
                              pv_src_locator,
                              lrec_dest_organization,
                              lv_return_status);

        IF lv_return_status = 'E'
        THEN
            lv_err_message   :=
                'Insert of On Hand data failed. See log for details';
            RAISE exPreProcess;
        END IF;

        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');
        insert_message (
            'BOTH',
            '+Validation and Pre-Process complete                                            +');
        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');


        --Finished Pre - Processing Stg records created
        pv_errbuf                := NULL;
        pv_retcode               := 0;

        insert_message (
            'LOG',
               'Updating stg records to ''P'' for request_id : '
            || gn_request_id);

        --Update staging table for added records to processing
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
           SET STATUS   = 'P'
         WHERE     ORGANIZATION_ID = lrec_src_organization.organization_id
               AND BRAND = lv_brand
               AND subinventory_code = pv_src_subinv
               AND locator_name = pv_src_locator
               AND status = 'N';

        COMMIT;

        create_oh_xfer_ir (Lv_brand, lrec_src_organization, lrec_dest_organization
                           , lv_return_status);

        IF lv_return_status = 'E'
        THEN
            lv_err_message   :=
                'Error during creation of internal requisitions. See log for details';
            RAISE exProcess;
        END IF;

        BEGIN
            --Update staging records with IDs from generated IR
            UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
               SET req_header_id   =
                       (SELECT prha.requisition_header_id
                          FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                         WHERE     prla.requisition_header_id =
                                   prha.requisition_header_id
                               AND prla.attribute15 = TO_CHAR (record_id)
                               AND prha.interface_source_code =
                                      gv_ir_interface_source_code
                                   || '-'
                                   || gn_request_id),
                   req_line_id   =
                       (SELECT prla.requisition_line_id
                          FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                         WHERE     prla.requisition_header_id =
                                   prha.requisition_header_id
                               AND prla.attribute15 = TO_CHAR (record_id)
                               AND prha.interface_source_code =
                                      gv_ir_interface_source_code
                                   || '-'
                                   || gn_request_id),
                   requisition_number   =
                       (SELECT prha.segment1
                          FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                         WHERE     prla.requisition_header_id =
                                   prha.requisition_header_id
                               AND prla.attribute15 = TO_CHAR (record_id)
                               AND prha.interface_source_code =
                                      gv_ir_interface_source_code
                                   || '-'
                                   || gn_request_id)
             WHERE request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        --TO DO - What type of failure here
        END;


        --TODO: Any IR Failure issues?

        --IR Created Now we progress to ISO


        insert_message ('BOTH', 'Insert ISO Data');
        insert_iso_data (lrec_src_organization,
                         pv_src_subinv,
                         pv_src_locator);

        insert_message ('BOTH', 'Relieve ATP');
        relieve_atp (lrec_src_organization);


        insert_message ('BOTH', 'Create Internal Orders');
        create_internal_orders (lrec_src_organization, lv_return_status);

        IF lv_return_status != 'S'
        THEN
            insert_message (
                'BOTH',
                'Error occurred in Create Internal Orders. See Log for details');
            RAISE exProcess;
        END IF;

        --Update customer_po_number to locator on all Order Interface Records sourced by
        --IRs created by this process

        BEGIN
            UPDATE oe_headers_iface_all
               SET customer_po_number   =
                       (SELECT segment1
                          FROM mtl_item_locations_kfv
                         WHERE concatenated_segments = pv_src_locator)
             WHERE orig_sys_document_ref IN
                       (SELECT TO_CHAR (requisition_header_id)
                          FROM po_requisition_headers_all prha
                         WHERE prha.interface_source_code =
                                  gv_ir_interface_source_code
                               || '-'
                               || gn_request_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                insert_message (
                    'BOTH',
                       'Unable to set ISO cust_po_number.locator is '
                    || pv_src_locator
                    || '. Error'
                    || SQLERRM);
        --Only ramification here is not populating ISO cust_po_number. Resulting ISO could be updated via data fix
        END;



        BEGIN
            SELECT responsibility_id, application_id
              INTO gn_resp_id, gn_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name = 'Deckers 3PL User'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_resp_id        := 51618;
                gn_resp_appl_id   := 345;
        END;

        do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);


        insert_message ('BOTH', 'Run Order Import');
        run_order_import (lrec_src_organization, lv_return_status);

        IF lv_return_status != 'S'
        THEN
            insert_message (
                'BOTH',
                'Error occurred in Run Order Import. See Log for details');
            RAISE exProcess;
        END IF;

        --Update stg table data fields;
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
           SET iso_number   =
                   (SELECT DISTINCT ooha.order_number
                      FROM oe_order_headers_all ooha, oe_order_lines_all oola
                     WHERE     oola.header_id = ooha.header_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.inventory_item_id = stg.inventory_item_id)
         WHERE request_id = gn_request_id;

        COMMIT;

        --Set records to E for any that do not have ISO set
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
           SET STATUS = 'E', MESSAGE = 'ISO line not created for this record', last_update_date = SYSDATE,
               last_updated_by = gn_user_id
         WHERE     stg.iso_number IS NULL
               AND request_id = gn_request_id
               AND STATUS != 'E';


        --Update staging table status fields
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
           SET STATUS = 'Y', MESSAGE = NULL, last_update_date = SYSDATE,
               last_updated_by = gn_user_id
         WHERE request_id = gn_request_id AND status != 'E';

        COMMIT;

        onhand_extract (lv_brand, lrec_src_organization.org_id, pv_src_subinv
                        , pv_src_locator);

        IF lv_return_status = 'S'
        THEN
            insert_message ('BOTH', 'Schedule ISO');
            schedule_iso;
        END IF;
    EXCEPTION
        WHEN exPreProcess
        THEN
            pv_errbuf    := lv_err_message;
            insert_message ('BOTH', lv_err_message);
            pv_retcode   := 2;
        WHEN exProcess
        THEN
            UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
               SET STATUS = 'E', MESSAGE = lv_err_message, last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE request_id = gn_request_id;

            COMMIT;

            pv_errbuf    := lv_err_message;
            insert_message ('BOTH', lv_err_message);
            pv_retcode   := 2;
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            insert_message ('BOTH', SQLERRM);
            pv_retcode   := 0;
    END;

    PROCEDURE pick_release_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER
                                  , pr_src_organization IN organization_rec, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2)
    IS
        lv_err_stat          VARCHAR2 (1);
        lv_err_msg           VARCHAR2 (2000);
        ln_user_id           NUMBER := 28227;                --JONATHAN.PETROU
        l_batch_info_rec     WSH_PICKING_BATCHES_PUB.BATCH_INFO_REC;

        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1);
        ln_batch_prefix      VARCHAR2 (10);
        ln_new_batch_id      NUMBER;

        ln_count             NUMBER;
        ln_request_id        NUMBER;

        lb_bol_result        BOOLEAN;
        lv_chr_phase         VARCHAR2 (250) := NULL;
        lv_chr_status        VARCHAR2 (250) := NULL;
        lv_chr_dev_phase     VARCHAR2 (250) := NULL;
        lv_chr_dev_status    VARCHAR2 (250) := NULL;
        lv_chr_message       VARCHAR2 (250) := NULL;

        ln_header_id         NUMBER;
        ln_org_id            NUMBER;
        ln_order_type_id     NUMBER;
        ln_organization_id   NUMBER;
        ln_from_locator_id   NUMBER;
        lv_order_type        VARCHAR2 (100);
        lv_org_name          VARCHAR2 (100);

        lv_src_subinv        VARCHAR2 (100);
    BEGIN
        -- do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_app_id);

        BEGIN
            SELECT DISTINCT
                   header_id,
                   org_id,
                   order_type_id,
                   (SELECT DISTINCT ship_from_org_id
                      FROM oe_order_lines_all oola
                     WHERE ooha.header_id = oola.header_id) organization_id,
                   ttl.name,
                   hr.name
              INTO ln_header_id, ln_org_id, ln_order_type_id, ln_organization_id,
                               lv_order_type, lv_org_name
              FROM oe_order_headers_all ooha, oe_transaction_types_tl ttl, hr_all_organization_units hr
             WHERE     ooha.order_type_id = ttl.transaction_type_id
                   AND ooha.ship_from_org_id = hr.organization_id
                   AND order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order does not exist';
                RETURN;
        END;

        BEGIN
            SELECT inventory_location_id
              INTO ln_from_locator_id
              FROM mtl_item_locations_kfv
             WHERE     concatenated_segments = pv_src_locator
                   AND organization_id = pr_src_organization.organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                --    lv_proceed_flag := 'N';
                ln_from_locator_id   := NULL;
                insert_message ('LOG', 'Unable to fetch from location');
        END;

        --check for subinv/locator in staging table
        SELECT COUNT (*)
          INTO ln_count
          FROM XXD_WMS_OH_IR_XFER_STG
         WHERE     subinventory_code = pv_src_subinv
               AND locator_name = pv_src_locator;

        IF ln_count > 0
        THEN
            lv_src_subinv   := pv_src_subinv;
        ELSE
            --NULL these to use default pick subinventory
            lv_src_subinv        := NULL;
            ln_from_locator_id   := NULL;
        END IF;


        --  apps.fnd_profile.put ('MFG_ORGANIZATION_ID', ln_organization_id);
        -- mo_global.init ('ONT');

        lv_return_status                              := wsh_util_core.g_ret_sts_success;

        l_batch_info_rec                              := NULL;
        -- insert_message ('BOTH', 'User ID : ' || gn_user_id);
        -- insert_message ('BOTH', 'Resp ID : ' || gn_resp_id);
        -- insert_message ('BOTH', 'Resp App ID : ' || gn_resp_appl_id);

        -- insert_message ('BOTH', 'Order Number : ' || pn_order_number);
        insert_message ('BOTH', 'Order Type : ' || lv_order_type);
        insert_message ('BOTH', 'Organization : ' || lv_org_name);

        insert_message ('BOTH', 'Subinventory : ' || lv_src_subinv);
        insert_message ('BOTH', 'Locator : ' || pv_src_locator);

        l_batch_info_rec.order_number                 := pn_order_number;
        l_batch_info_rec.order_type_id                := ln_order_type_id;
        l_batch_info_rec.Autodetail_Pr_Flag           := 'Y';
        l_batch_info_rec.organization_id              := ln_organization_id;
        l_batch_info_rec.autocreate_delivery_flag     := 'Y';
        l_batch_info_rec.Backorders_Only_Flag         := 'I';
        l_batch_info_rec.allocation_method            := 'I';
        l_batch_info_rec.auto_pick_confirm_flag       := 'Y';
        l_batch_info_rec.autopack_flag                := 'N';
        l_batch_info_rec.append_flag                  := 'N';
        l_batch_info_rec.Pick_From_Subinventory       := lv_src_subinv; --lv_subinventory;
        l_batch_info_rec.Pick_From_locator_Id         := ln_from_locator_id;
        l_batch_info_rec.Default_Stage_Subinventory   := NULL; --lv_subinventory;
        ln_batch_prefix                               := NULL;
        ln_new_batch_id                               := NULL;

        WSH_PICKING_BATCHES_PUB.CREATE_BATCH (
            p_api_version     => 1.0,
            p_init_msg_list   => fnd_api.g_true,
            p_commit          => fnd_api.g_true,
            x_return_status   => lv_return_status,
            x_msg_count       => ln_msg_count,
            x_msg_data        => lv_msg_data,
            p_rule_id         => NULL,
            p_rule_name       => NULL,
            p_batch_rec       => l_batch_info_rec,
            p_batch_prefix    => ln_batch_prefix,
            x_batch_id        => ln_new_batch_id);

        IF lv_return_status <> 'S'
        THEN
            insert_message (
                'BOTH',
                'CREATE_BATCH: lv_return_status ' || lv_return_status);
            insert_message ('BOTH', 'Message count ' || ln_msg_count);

            IF ln_msg_count = 1
            THEN
                insert_message ('BOTH', 'lv_msg_data ' || lv_msg_data);
            ELSIF ln_msg_count > 1
            THEN
                LOOP
                    ln_count   := ln_count + 1;
                    lv_msg_data   :=
                        FND_MSG_PUB.Get (FND_MSG_PUB.G_NEXT, FND_API.G_FALSE);

                    IF lv_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    insert_message (
                        'BOTH',
                        'Message' || ln_count || '---' || lv_msg_data);
                END LOOP;
            END IF;

            pv_error_stat   := lv_return_status;
            RETURN;
        ELSE
            -- Release the batch Created Above
            WSH_PICKING_BATCHES_PUB.RELEASE_BATCH (
                P_API_VERSION     => 1.0,
                P_INIT_MSG_LIST   => fnd_api.g_true,
                P_COMMIT          => fnd_api.g_true,
                X_RETURN_STATUS   => lv_return_status,
                X_MSG_COUNT       => ln_msg_count,
                X_MSG_DATA        => lv_msg_data,
                P_BATCH_ID        => ln_new_batch_id,
                P_BATCH_NAME      => NULL,
                P_LOG_LEVEL       => 1,
                P_RELEASE_MODE    => 'ONLINE',       -- (ONLINE or CONCURRENT)
                X_REQUEST_ID      => ln_request_id);



            IF ln_request_id <> 0
            THEN
                lb_bol_result   :=
                    fnd_concurrent.wait_for_request (ln_request_id,
                                                     15,
                                                     0,
                                                     lv_chr_phase,
                                                     lv_chr_status,
                                                     lv_chr_dev_phase,
                                                     lv_chr_dev_status,
                                                     lv_chr_message);
            END IF;
        END IF;

        pv_error_stat                                 := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE run_om_schedule_orders (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        ln_org_id           NUMBER;
        ln_req_request_id   NUMBER;
    BEGIN
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM oe_order_headers_all
             WHERE order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order not found';
        END;


        exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => ln_req_request_id, pv_application => 'ONT', -- application short name
                                                                                                                                                      pv_program => 'SCHORD', -- program short name
                                                                                                                                                                              pv_wait_for_request => 'Y', pv_argument1 => ln_org_id, -- Operating Unit
                                                                                                                                                                                                                                     pv_argument2 => pn_order_number, -- Internal Order
                                                                                                                                                                                                                                                                      pv_argument3 => pn_order_number, pv_argument4 => '', pv_argument5 => '', pv_argument6 => '', pv_argument7 => '', pv_argument8 => '', pv_argument9 => '', pv_argument10 => '', pv_argument11 => '', pv_argument12 => '', pv_argument13 => '', pv_argument14 => '', pv_argument15 => '', pv_argument16 => '', pv_argument17 => '', pv_argument18 => '', pv_argument19 => '', pv_argument20 => '', pv_argument21 => '', pv_argument22 => '', pv_argument23 => '', pv_argument24 => '', pv_argument25 => '', pv_argument26 => '', pv_argument27 => '', pv_argument28 => '', pv_argument29 => '', pv_argument30 => '', pv_argument31 => '', pv_argument32 => '', pv_argument33 => '', pv_argument34 => '', pv_argument35 => '', pv_argument36 => 'Y'
                           , pv_argument37 => '1000', pv_argument38 => ''); -- Orig Sys Document Ref
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE schedule_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (4000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (4000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.Line_Rec_Type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;

        ln_user_id                     NUMBER := fnd_global.user_id;
        ln_resp_id                     NUMBER := fnd_global.resp_id;
        ln_resp_appl_id                NUMBER := fnd_global.resp_appl_id;

        CURSOR line_cur (n_header_id NUMBER)
        IS
            SELECT line_id, request_date
              FROM oe_order_lines_all
             WHERE header_id = n_header_id;

        ln_header_id                   NUMBER;
        ln_org_id                      NUMBER;
    BEGIN
        BEGIN
            SELECT DISTINCT ooha.header_id, ooha.org_id
              INTO ln_header_id, ln_org_id
              FROM oe_order_headers_all ooha
             WHERE ooha.order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'Order not found';
                pv_error_stat   := 'E';
                RETURN;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        mo_global.init ('ONT');
        mo_global.Set_org_context (ln_org_id, NULL, 'ONT');

        v_line_tbl.delete ();

        FOR line_rec IN line_cur (ln_header_id)
        LOOP
            j                                       := j + 1;

            v_line_tbl (j)                          := OE_ORDER_PUB.G_MISS_LINE_REC;
            v_line_tbl (j).header_id                := ln_header_id;
            v_line_tbl (j).line_id                  := line_rec.line_id;
            v_line_tbl (j).operation                := oe_globals.G_OPR_UPDATE;
            v_line_tbl (j).OVERRIDE_ATP_DATE_CODE   := 'Y';
            v_line_tbl (j).schedule_arrival_date    := line_rec.request_date;
        --   v_line_tbl (j).schedule_ship_date := line_rec.request_date;
        -- v_line_tbl(j).schedule_action_code := oe_order_sch_util.oesch_act_schedule;
        END LOOP;

        IF j > 0
        THEN
            OE_ORDER_PUB.PROCESS_ORDER (
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl,
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
                pv_error_stat   := 'S';
                COMMIT;
            ELSE
                ROLLBACK;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                pv_error_stat   := 'E';
                pv_error_msg    := SUBSTR (v_msg_data, 1, 2000);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;


    PROCEDURE inv_xfer_pick_release (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_header_id IN NUMBER)
    IS
        ln_unschedule_cnt       NUMBER;
        ln_delivery_id          NUMBER;
        ln_booked_cnt           NUMBER;
        ln_src_org_id           NUMBER;
        lv_src_subinv           VARCHAR2 (50);
        lv_src_locator          VARCHAR2 (200);
        lv_src_locator_seg1     VARCHAR2 (200);
        lv_src_locator_id       NUMBER;

        lv_error_stat           VARCHAR2 (10);
        lv_error_msg            VARCHAR2 (2000);
        ln_delivery_quantity    NUMBER;
        ln_iso_number           NUMBER;
        lv_ir_number            VARCHAR2 (100);

        lrec_src_organization   organization_rec;
    BEGIN
        insert_message ('BOTH', 'inv_xfer_pick_release - start');



        --Validate ISO number entered
        BEGIN
            --Get the ship from org for the ISO
            SELECT DISTINCT oola.ship_from_org_id, ooha.cust_po_number, ooha.order_number,
                            prha.segment1
              INTO ln_src_org_id, lv_src_locator_seg1, ln_iso_number, lv_ir_number
              FROM oe_order_lines_all oola, oe_order_headers_all ooha, po_requisition_headers_all prha
             WHERE     oola.header_id = ooha.header_id
                   AND ooha.source_document_id =
                       prha.requisition_header_id(+)
                   AND ooha.header_id = pn_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_errbuf   := 'ISO ' || ln_iso_number || ' not found.';
                -- pv_errstat := 'E';
                RETURN;
        END;

        insert_message ('BOTH', ' segment1 : ' || lv_src_locator_seg1);
        insert_message ('BOTH', ' organization_id : ' || ln_src_org_id);


        BEGIN
            --Get Subinventory
            SELECT DISTINCT subinventory_code, concatenated_segments
              INTO lv_src_subinv, lv_src_locator
              FROM mtl_item_locations_kfv
             WHERE     segment1 = lv_src_locator_seg1
                   AND organization_id = ln_src_org_id
                   AND enabled_flag = 'Y'
                   AND NVL (disable_date, SYSDATE + 1) > TRUNC (SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_errbuf   :=
                       'Subinventory/Locator not found for locator segment1'
                    || lv_src_locator_seg1;
                RETURN;
        END;                                    --Get Source Organization Data

        lrec_src_organization   := get_organization_data (ln_src_org_id);

        insert_message ('BOTH', 'ISO Number : ' || ln_iso_number);
        insert_message ('BOTH', 'Subinventory : ' || lv_src_subinv);
        insert_message ('BOTH', 'Locator : ' || lv_src_locator);

        --TODO: Validate Locator

        --Progress lines to awaiting shipping/scheduled
        --Check for unscheduled lines and schedule

        --update the stg table records for this SO so relieve

        --Set override ATP Date Code
        -- insert_message ('BOTH', 'Relieve ATP');
        -- relieve_atp (lrec_src_organization);

        SELECT COUNT (1)
          INTO ln_unschedule_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = ln_iso_number
               AND ooha.header_id = oola.header_id
               AND (schedule_ship_date IS NULL OR schedule_status_code IS NULL)
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code = 'AWAITING_SHIPPING';

        insert_message ('BOTH', 'Unscheduled Count : ' || ln_unschedule_cnt);

        IF ln_unschedule_cnt > 0
        THEN
            --Schedule order
            -- 'Deckers Order Management Manager - US'
            insert_message ('BOTH', 'Schedule order');
            schedule_order (pv_error_stat     => lv_error_stat,
                            pv_error_msg      => lv_error_msg,
                            pn_order_number   => ln_iso_number);
        END IF;

        IF lv_error_stat != 'S'
        THEN
            pv_retcode   := 'E';
            pv_errbuf    := ' Schedule orders failed : ' || lv_error_msg;
            RETURN;
        END IF;

        --Check for lines in booked status
        SELECT SUM (DECODE (oola.flow_status_code, 'BOOKED', 1, 0))
          INTO ln_booked_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = ln_iso_number
               AND ooha.header_id = oola.header_id
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING');

        insert_message ('BOTH', 'Count booked ' || ln_booked_cnt);


        --Progress BOOKED lines to AWAITING_SHIPPING
        IF ln_booked_cnt > 0
        THEN
            insert_message ('BOTH', 'Run OM Schedule orders');
            run_om_schedule_orders (pv_error_stat     => lv_error_stat,
                                    pv_error_msg      => lv_error_msg,
                                    pn_order_number   => ln_iso_number);


            IF lv_error_stat != 'S'
            THEN
                pv_retcode   := 'E';
                pv_errbuf    := 'Run OM Schedule orders : ' || lv_error_msg;
                RETURN;
            END IF;
        END IF;

        --Shipping user tasks

        SELECT responsibility_id, application_id
          INTO gn_resp_id, gn_resp_appl_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = 'Deckers 3PL User';

        do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

        insert_message ('BOTH', 'Release Order');
        --Pick Release order
        Pick_release_order (pv_error_stat         => lv_error_stat,
                            pv_error_msg          => lv_error_msg,
                            pn_order_number       => ln_iso_number,
                            pr_src_organization   => lrec_src_organization,
                            pv_src_subinv         => lv_src_subinv,
                            pv_src_locator        => lv_src_locator);

        IF lv_error_stat != 'S'
        THEN
            pv_retcode   := 'E';
            insert_message ('BOTH', 'pick release failed : ' || lv_error_msg);
            pv_errbuf    := 'pick release failed : ' || lv_error_msg;
            RETURN;
        END IF;



        BEGIN
              --Get confirmed delivery
              SELECT wda.delivery_id, SUM (wdd.requested_quantity) delivery_qty
                INTO ln_delivery_id, ln_delivery_quantity
                FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, oe_order_lines_all oola,
                     oe_order_headers_all ooha
               WHERE     ooha.order_number = ln_iso_number
                     AND wdd.delivery_detail_id = wda.delivery_detail_id
                     AND wdd.source_line_id = oola.line_id
                     AND oola.header_id = ooha.header_id
                     AND wdd.source_code = 'OE'
            GROUP BY wda.delivery_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_retcode   := 'W';
                pv_errbuf    := 'No delivery created';
            WHEN TOO_MANY_ROWS
            THEN
                pv_retcode   := 'W';
                pv_errbuf    := 'multiple delivery created';
            WHEN OTHERS
            THEN
                pv_retcode   := 'E';
                pv_errbuf    := SQLERRM;
        END;

        IF pv_retcode != 'S'
        THEN
            RETURN;
        END IF;

        --1.1
        IF ln_delivery_id IS NULL
        THEN
            pv_retcode   := 'W';
            pv_errbuf    := 'No delivery created';
            RETURN;
        END IF;

        --end 1.1

        insert_message ('BOTH', 'Delivery Created : ' || ln_delivery_id);

        --update staging table delivery fields
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
           SET delivery_id       =
                   (SELECT delivery_id
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd, oe_order_lines_all oola
                     WHERE     wda.delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wdd.source_line_id = oola.line_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.inventory_item_id = stg.inventory_item_id
                           AND wdd.source_code = 'OE'),
               delivery_line_status   =
                   (SELECT released_status
                      FROM wsh_delivery_details wdd, oe_order_lines_all oola
                     WHERE     wdd.source_line_id = oola.line_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.inventory_item_id = stg.inventory_item_id
                           AND wdd.source_code = 'OE'),
               last_update_date   = SYSDATE,
               last_updated_by    = apps.fnd_global.user_id,
               request_id         = gn_request_id
         WHERE iso_number = ln_iso_number;

        insert_message ('BOTH', '----Output-----');
        insert_message ('BOTH', '  IR Number : ' || lv_ir_number);
        insert_message ('BOTH', '  Delivery : ' || ln_delivery_id);
        insert_message ('BOTH', '  Sub-Inventory : ' || lv_src_subinv);
        insert_message ('BOTH', '  Locator : ' || lv_src_locator);
        insert_message ('BOTH',
                        '  Delivery Quantity : ' || ln_delivery_quantity);



        pv_retcode              := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 'E';
            pv_errbuf    := 'Error in ISO Staging process. : ' || SQLERRM;
    END;

    --Start v2.0 Procedure inv_transfer_pholder_move added for US1_US6_Org_Move
    PROCEDURE inv_transfer_pholder_move (pv_errbuf           OUT VARCHAR2,
                                         pv_retcode          OUT VARCHAR2,
                                         pn_src_org_id    IN     NUMBER,
                                         pn_dest_org_id   IN     NUMBER,
                                         pv_brand         IN     VARCHAR2)
    IS
        lrec_src_organization    organization_rec;
        lrec_dest_organization   organization_rec;

        CURSOR c_item_details IS
              SELECT ooha.attribute5 brand,
                     msi.segment1 sku,
                     mcb.segment3 department,
                     msi.description item_desc,
                     oola.ordered_quantity tpo_qty,
                     apps.f_get_atr (msi.inventory_item_id, msi.organization_id, NULL
                                     , NULL) atr_qty,
                     (SELECT SUM (atp)
                        FROM xxdo.xxdo_atp_final atp
                       WHERE     atp.organization_id = msi.organization_id
                             AND demand_class = '-1'
                             AND atp.inventory_item_id = msi.inventory_item_id
                             AND TRUNC (dte) = TRUNC (SYSDATE)) free_atp,
                     (SELECT conversion_rate
                        FROM apps.mtl_uom_conversions muc
                       WHERE     muc.inventory_item_id = msi.inventory_item_id
                             AND muc.disable_date IS NULL) cpq
                FROM apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola,
                     apps.mtl_system_items_kfv msi, apps.mtl_item_categories mic, apps.mtl_categories_b mcb
               WHERE     flv.lookup_type = 'XXD_WMS_BLANKET_ISO_LIST'
                     AND flv.language = USERENV ('LANG')
                     AND flv.enabled_flag = 'Y'
                     AND flv.lookup_code = ooha.order_number
                     AND ooha.attribute5 =
                         NVL (UPPER (pv_brand), ooha.attribute5)
                     AND ooha.header_id = oola.header_id
                     AND oola.ship_from_org_id = pn_src_org_id
                     AND oola.ship_from_org_id = msi.organization_id
                     AND oola.inventory_item_id = msi.inventory_item_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND msi.organization_id = mic.organization_id
                     AND mic.category_set_id = 1
                     AND mic.category_id = mcb.category_id
                     AND EXISTS
                             (SELECT 1
                                FROM po_requisition_headers_all porh, po_requisition_lines_all porl
                               WHERE     porh.requisition_header_id =
                                         oola.source_document_id
                                     AND porh.requisition_header_id =
                                         porl.requisition_header_id
                                     AND porl.requisition_line_id =
                                         oola.source_document_line_id
                                     AND porl.item_id = oola.inventory_item_id
                                     AND porl.destination_organization_id =
                                         pn_dest_org_id)
            ORDER BY ooha.attribute5, msi.segment1;
    BEGIN
        --Get Source Organization Data
        lrec_src_organization    := get_organization_data (pn_src_org_id);
        --Get destination Data
        lrec_dest_organization   := get_organization_data (pn_dest_org_id);

        insert_message (
            'LOG',
            '+------------------------------- Parameters --------------------------------+');
        insert_message (
            'LOG',
            'Source Org: ' || lrec_src_organization.organization_code);
        insert_message (
            'LOG',
            'Destination Org: ' || lrec_dest_organization.organization_code);
        insert_message ('LOG', 'Brand: ' || pv_brand);

        insert_message ('LOG', 'User Name: ' || gv_user_name);
        insert_message ('LOG', 'Resp Appl ID: ' || FND_GLOBAL.RESP_APPL_ID);
        insert_message ('LOG', 'Inserting Output Header');

        fnd_file.put_line (
            fnd_file.output,
               'Source Org Code'
            || ','
            || 'Dest Org Code'
            || ','
            || 'Brand'
            || ','
            || 'SKU'
            || ','
            || 'Department'
            || ','
            || 'Item Description'
            || ','
            || 'TPO Qty'
            || ','
            || 'ATR Qty'
            || ','
            || 'Free ATP'
            || ','
            || 'CPQ');

        insert_message ('LOG', 'Inserting Output Records');

        FOR rec_item IN c_item_details
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   lrec_src_organization.organization_code
                || ','
                || lrec_dest_organization.organization_code
                || ','
                || rec_item.brand
                || ','
                || rec_item.sku
                || ','
                || rec_item.department
                || ','
                || rec_item.item_desc
                || ','
                || rec_item.tpo_qty
                || ','
                || rec_item.atr_qty
                || ','
                || rec_item.free_atp
                || ','
                || rec_item.cpq);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'End of Transfer Placeholder Order Move Report');
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            insert_message ('LOG', SQLERRM);
            pv_retcode   := 0;
    END inv_transfer_pholder_move;
--End changes v2.0
END;
/
