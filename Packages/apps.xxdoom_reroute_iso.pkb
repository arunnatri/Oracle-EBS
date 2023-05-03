--
-- XXDOOM_REROUTE_ISO  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM_REROUTE_ISO"
AS
    /*Creates a reservation from a SO line to a PO line*/
    PROCEDURE create_reservation_oe_to_po (oe_line_id IN NUMBER, po_line_location_id IN NUMBER, p_user_id IN NUMBER
                                           , p_mso_sales_order_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    IS
        ln_user_id              NUMBER := apps.FND_GLOBAL.User_ID;
        ld_sysdate              DATE := SYSDATE;
        ln_login_id             NUMBER := apps.FND_GLOBAL.Conc_Login_ID;
        lv_return_status        VARCHAR2 (1) := apps.FND_API.G_RET_STS_SUCCESS;
        ln_msg_count            NUMBER;
        lv_msg_data             VARCHAR2 (3000);
        ln_group_id             NUMBER := 9999;

        lr_orig_rsv_rec         apps.inv_reservation_global.mtl_reservation_rec_type;
        l_rsv_rec               apps.inv_reservation_global.mtl_reservation_rec_type;
        lr_orig_serial_number   apps.inv_reservation_global.serial_number_tbl_type;
        x_serial_number         apps.INV_RESERVATION_GLOBAL.SERIAL_NUMBER_TBL_TYPE;
        ln_msg_index            NUMBER;
        l_init_msg_list         VARCHAR2 (2) := apps.FND_API.G_TRUE;
        x_quantity_reserved     NUMBER := 0;
        x_reservation_id        NUMBER := 0;

        p_ship_from_org_id      NUMBER;
        p_inventory_item_id     NUMBER;
        p_schedule_ship_date    DATE;
        p_ordered_quantity      NUMBER;
        p_line_id               NUMBER;
        p_header_id             NUMBER;
        p_ship_to_org_id        NUMBER;
        p_order_type_id         NUMBER;
        p_order_quantity_uom    VARCHAR2 (10);

        p_po_header_id          NUMBER;
        p_line_location_id      NUMBER;
        ex_no_po_line           EXCEPTION;

        ex_no_oe_line           EXCEPTION;
        ex_missing_mso_id       EXCEPTION;

        p_resp_id               NUMBER;
        p_app_id                NUMBER;
    BEGIN
        BEGIN
            SELECT oola.ship_from_org_id, oola.inventory_item_id, TRUNC (oola.schedule_ship_date) schedule_date,
                   oola.ordered_quantity, oola.line_id, oola.header_id,
                   oola.ordered_quantity, oola.ship_to_org_id, oola.order_quantity_uom
              INTO p_ship_from_org_id, p_inventory_item_id, p_schedule_ship_date, p_ordered_quantity,
                                     p_line_id, p_header_id, p_ordered_quantity,
                                     p_ship_to_org_id, p_order_quantity_uom
              FROM apps.oe_order_lines_all oola,
                   oe_order_headers_all ooha,
                   (SELECT *
                      FROM oe_transaction_types_tl
                     WHERE language = 'US') tt
             WHERE     line_id = oe_line_id
                   AND oola.open_flag = 'Y'
                   AND ooha.order_type_id = tt.transaction_type_id
                   AND oola.header_id = ooha.header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RAISE ex_no_oe_line;
        END;

        BEGIN
            SELECT po_header_id, line_location_id
              INTO p_po_header_id, p_line_location_id
              FROM po_line_locations_all
             WHERE     line_location_id = po_line_location_id
                   AND closed_code = 'OPEN';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RAISE ex_no_po_line;
        END;

        IF p_mso_sales_order_id IS NULL
        THEN
            --get from the lineID?
            RAISE ex_missing_mso_id;
        END IF;

        DBMS_OUTPUT.put_line ('mso_sales_order_id :' || p_mso_sales_order_id);

        BEGIN
            --Log into Order Management responsibility
            SELECT DISTINCT responsibility_id, application_id
              INTO p_resp_id, p_app_id
              FROM apps.fnd_responsibility_tl
             WHERE responsibility_name = OM_Responsibility;

            apps.do_apps_initialize (p_user_id, p_resp_id, p_app_id); --Deckers Order Management Super User - Macau
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                apps.do_apps_initialize (p_user_id, OM_Rresp_id, OM_App_ID); --Deckers Order Management Super User - Macau
        END;


        l_rsv_rec.organization_id                := p_ship_from_org_id; --order source org
        l_rsv_rec.inventory_item_id              := p_inventory_item_id; --order item id
        l_rsv_rec.requirement_date               := p_schedule_ship_date; --order schedule ship date
        l_rsv_rec.demand_source_type_id          := 8;             -- Internal
        l_rsv_rec.demand_source_name             := NULL;
        l_rsv_rec.primary_reservation_quantity   := p_ordered_quantity; --ordered_quantity
        l_rsv_rec.primary_uom_code               := p_order_quantity_uom; --order uom
        l_rsv_rec.subinventory_code              := NULL;
        l_rsv_rec.demand_source_header_id        := p_mso_sales_order_id; --order header id
        l_rsv_rec.demand_source_line_id          := p_line_id; --order line id
        l_rsv_rec.reservation_uom_code           := p_order_quantity_uom; --order item UOM
        l_rsv_rec.reservation_quantity           := p_ordered_quantity; ----l_reservation_qty; -order ordered_quantity
        -- Use these lines if Inventory
        --l_rsv_rec.supply_source_header_id := null; --dmd.supply_source_header_id ;
        --l_rsv_rec.supply_source_line_id := null; -- dmd.supply_source_line_id ;
        -- l_rsv_rec.supply_source_type_id := 13; -- Inventory
        --
        -- Use these  for PO
        l_rsv_rec.supply_source_header_id        := p_po_header_id; --PO line header_id
        l_rsv_rec.supply_source_line_id          := p_line_location_id; --po line_id
        l_rsv_rec.supply_source_type_id          := 1;                   -- PO
        --
        l_rsv_rec.supply_source_name             := NULL;
        l_rsv_rec.supply_source_line_detail      := NULL;
        l_rsv_rec.lot_number                     := NULL;
        l_rsv_rec.serial_number                  := NULL;
        l_rsv_rec.ship_ready_flag                := NULL;
        l_rsv_rec.attribute15                    := NULL;
        l_rsv_rec.attribute14                    := NULL;
        l_rsv_rec.attribute13                    := NULL;
        l_rsv_rec.attribute12                    := NULL;
        l_rsv_rec.attribute11                    := NULL;
        l_rsv_rec.attribute10                    := NULL;
        l_rsv_rec.attribute9                     := NULL;
        l_rsv_rec.attribute8                     := NULL;
        l_rsv_rec.attribute7                     := NULL;
        l_rsv_rec.attribute6                     := NULL;
        l_rsv_rec.attribute5                     := NULL;
        l_rsv_rec.attribute4                     := NULL;
        l_rsv_rec.attribute3                     := NULL;
        l_rsv_rec.attribute2                     := NULL;
        l_rsv_rec.attribute1                     := '1';
        l_rsv_rec.attribute_category             := NULL;
        l_rsv_rec.lpn_id                         := NULL;
        l_rsv_rec.pick_slip_number               := NULL;
        l_rsv_rec.lot_number_id                  := NULL;
        l_rsv_rec.locator_id                     := NULL; ---inventory_location_id ;-- NULL ;
        l_rsv_rec.subinventory_id                := NULL;
        l_rsv_rec.revision                       := NULL;
        l_rsv_rec.external_source_line_id        := NULL;
        l_rsv_rec.external_source_code           := NULL;
        l_rsv_rec.autodetail_group_id            := NULL;
        l_rsv_rec.reservation_uom_id             := NULL;
        l_rsv_rec.primary_uom_id                 := NULL;
        l_rsv_rec.demand_source_delivery         := NULL;
        l_rsv_rec.crossdock_flag                 := 'N';
        l_rsv_rec.secondary_uom_code             := NULL;
        l_rsv_rec.detailed_quantity              := NULL; --lrec_batch_details.shipped_quantity;
        l_rsv_rec.secondary_detailed_quantity    := NULL; --ln_shipped_quantity;--lrec_batch_details.shipped_quantity;
        ln_msg_count                             := NULL;
        lv_msg_data                              := NULL;
        lv_return_status                         := NULL;

        apps.INV_RESERVATION_PUB.Create_Reservation (
            P_API_VERSION_NUMBER         => 1.0,
            P_INIT_MSG_LST               => l_init_msg_list,
            P_RSV_REC                    => l_rsv_rec,
            P_SERIAL_NUMBER              => lr_orig_serial_number,
            P_PARTIAL_RESERVATION_FLAG   => apps.FND_API.G_FALSE,
            P_FORCE_RESERVATION_FLAG     => apps.FND_API.G_FALSE,
            P_PARTIAL_RSV_EXISTS         => FALSE,
            P_VALIDATION_FLAG            => apps.FND_API.G_TRUE,
            X_SERIAL_NUMBER              => x_serial_number,
            X_RETURN_STATUS              => lv_return_status,
            X_MSG_COUNT                  => ln_msg_count,
            X_MSG_DATA                   => lv_msg_data,
            X_QUANTITY_RESERVED          => x_quantity_reserved,
            X_RESERVATION_ID             => x_reservation_id);
        COMMIT;
        x_ret_stat                               := lv_return_status;
        x_error_msg                              := '';
    EXCEPTION
        WHEN ex_no_oe_line
        THEN
            x_ret_stat    := 'E';
            x_error_msg   := 'Invalid order line';
        WHEN ex_no_po_line
        THEN
            x_ret_stat    := 'E';
            x_error_msg   := 'Invalid PO line';
        WHEN ex_missing_mso_id
        THEN
            x_ret_stat    := 'E';
            x_error_msg   := 'msc_sales_order_id not found';
        WHEN OTHERS
        THEN
            x_ret_stat    := 'E';
            x_error_msg   := 'Unexpected error';
    END;

    /* Deletes a reservationb based on reservation ID*/
    PROCEDURE delete_reservation_by_id (p_reservation_id IN NUMBER, p_user_id IN NUMBER, x_ret_stat OUT VARCHAR2
                                        , x_error_msg OUT VARCHAR2)
    IS
        l_rsv             apps.inv_reservation_global.mtl_reservation_rec_type;
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (240);
        l_rsv_id          NUMBER;
        l_dummy_sn        apps.inv_reservation_global.serial_number_tbl_type;
        l_status          VARCHAR2 (1);
        nCnt              NUMBER;

        p_resp_id         NUMBER;
        p_app_id          NUMBER;
        ex_no_Res_found   EXCEPTION;
    BEGIN
        SELECT COUNT (*)
          INTO nCnt
          FROM apps.mtl_reservations
         WHERE reservation_id = p_reservation_id;

        IF nCnt = 0
        THEN
            RAISE ex_no_Res_found;
        END IF;

        BEGIN
            --Log into Order Management responsibility
            SELECT DISTINCT responsibility_id, application_id
              INTO p_resp_id, p_app_id
              FROM apps.fnd_responsibility_tl
             WHERE responsibility_name = OM_Responsibility;

            apps.do_apps_initialize (p_user_id, p_resp_id, p_app_id); --Deckers Order Management Super User - Macau
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                apps.do_apps_initialize (p_user_id, OM_Rresp_id, OM_App_ID); --Deckers Order Management Super User - Macau
        END;

        l_rsv.reservation_id   := p_reservation_id;

        apps.inv_reservation_pub.delete_reservation (
            p_api_version_number   => 1.0,
            p_init_msg_lst         => apps.fnd_api.g_true,
            x_return_status        => l_status,
            x_msg_count            => l_msg_count,
            x_msg_data             => l_msg_data,
            p_rsv_rec              => l_rsv,
            p_serial_number        => l_dummy_sn);

        x_ret_stat             := apps.fnd_api.g_ret_sts_success;

        x_error_msg            := '';
    EXCEPTION
        WHEN ex_no_Res_found
        THEN
            x_ret_stat    := 'E';
            x_error_msg   := 'reservation not found';
        WHEN OTHERS
        THEN
            x_ret_stat    := 'E';
            x_error_msg   := 'Unexpected error';
    END;

    /* runs the order import concurrent program*/
    PROCEDURE run_order_import (p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_order_source_id IN NUMBER:= OS_Internal, p_user_id IN NUMBER, p_status OUT VARCHAR, p_msg OUT VARCHAR2
                                , p_request_id OUT NUMBER)
    AS
        l_request_id   NUMBER;
        x_ret_stat     VARCHAR2 (1);
        x_error_text   VARCHAR2 (20000);
        l_phase        VARCHAR2 (80);
        l_req_status   BOOLEAN;
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        l_data         VARCHAR2 (200);

        p_resp_id      NUMBER;
        p_app_id       NUMBER;

        invalid_data   EXCEPTION;
    BEGIN
        --check order_source passed
        IF p_order_source_id IS NOT NULL
        THEN
            BEGIN
                SELECT name
                  INTO l_data
                  FROM apps.oe_order_sources
                 WHERE order_source_id = p_order_source_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_message   := 'Invalid order type passed';
                    RAISE invalid_data;
            END;
        END IF;


        BEGIN
            --Log into Order Management responsibility
            SELECT DISTINCT responsibility_id, application_id
              INTO p_resp_id, p_app_id
              FROM apps.fnd_responsibility_tl
             WHERE responsibility_name = OM_Responsibility;

            apps.do_apps_initialize (p_user_id, p_resp_id, p_app_id); --Deckers Order Management Super User - Macau
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                apps.do_apps_initialize (p_user_id, OM_Rresp_id, OM_App_ID); --Deckers Order Management Super User - Macau
        END;

        apps.fnd_global.initialize ('ORG_ID', p_org_id);
        apps.fnd_request.set_org_id (p_org_id);
        --fnd_global.apps_initialize(user_id => 1037, resp_id => l_dest_resp_id, resp_appl_id => l_dest_app_id);
        --fnd_global.initialize(l_buffer_number, 1037, l_dest_resp_id, l_dest_app_id, 0, -1, -1, -1, -1, -1, 666, -1);
        apps.fnd_profile.put ('MFG_ORGANIZATION_ID', p_inv_org_id);
        DBMS_OUTPUT.put_line ('run_order_import - submit request');
        l_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',
                program       => 'OEOIMP',
                argument1     => TO_CHAR (p_org_id),
                argument2     => NVL (TO_CHAR (p_order_source_id), ''),
                argument3     => '',
                argument4     => '',
                argument5     => 'N',
                argument6     => '1');
        COMMIT;
        DBMS_OUTPUT.put_line (
            'run_order_import - after submit request -  ' || l_request_id);
        l_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => l_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);

        DBMS_OUTPUT.put_line (
            'run_order_import - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text   :=
                NVL (
                    l_message,
                       'The import orders request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
        ELSE
            x_ret_stat   := 'S';
        END IF;

        DBMS_OUTPUT.put_line (
               'run_create_internal_orders - after wait for request -  '
            || x_ret_stat);
        p_status       := x_ret_stat;
        p_msg          := x_error_text;
        p_request_id   := l_request_id;
    EXCEPTION
        WHEN Invalid_data
        THEN
            x_ret_stat     := 'E';
            x_error_text   := l_message;
        WHEN OTHERS
        THEN
            x_ret_stat   := 'U';
            x_error_text   :=
                'Order Import failed with unexpected error ' || SQLERRM;
    END;

    /* runs the create internal orders program*/
    PROCEDURE run_create_internal_orders (p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_user_id IN NUMBER
                                          , p_status OUT VARCHAR, p_msg OUT VARCHAR2, p_request_id OUT NUMBER)
    AS
        l_request_id   NUMBER;
        x_ret_stat     VARCHAR2 (1);
        x_error_text   VARCHAR2 (20000);
        l_phase        VARCHAR2 (80);
        l_req_status   BOOLEAN;
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        p_resp_id      NUMBER;
        p_app_id       NUMBER;
    BEGIN
        BEGIN
            --Log into Purchasing responsibility
            SELECT DISTINCT responsibility_id, application_id
              INTO p_resp_id, p_app_id
              FROM apps.fnd_responsibility_tl
             WHERE responsibility_name = PO_Responsibility;

            apps.do_apps_initialize (p_user_id, p_resp_id, p_app_id); ---Deckers Purchasing User - Global
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                apps.do_apps_initialize (p_user_id, PO_Rresp_id, PO_App_ID); ---Deckers Purchasing User - Global
        END;

        apps.fnd_global.initialize ('ORG_ID', p_org_id);
        apps.fnd_request.set_org_id (p_org_id);
        apps.fnd_profile.put ('MFG_ORGANIZATION_ID', p_inv_org_id);

        DBMS_OUTPUT.put_line ('run_create_internal_orders - submit request');
        l_request_id   :=
            apps.fnd_request.submit_request (application   => 'PO',
                                             program       => 'POCISO',
                                             argument1     => '',
                                             argument2     => '',
                                             argument3     => '',
                                             argument4     => '',
                                             argument5     => 'N',
                                             argument6     => 'Y');
        COMMIT;
        l_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => l_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);

        DBMS_OUTPUT.put_line (
               'run_create_internal_orders - after wait for request -  '
            || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text   :=
                NVL (
                    l_message,
                       'The create internal orders request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
        ELSE
            x_ret_stat   := 'S';
        END IF;

        DBMS_OUTPUT.put_line (
               'run_create_internal_orders - after wait for request -  '
            || x_ret_stat);
        p_status       := x_ret_stat;
        p_msg          := x_error_text;
        p_request_id   := l_request_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := 'U';
            x_error_text   :=
                   'Create internal orders failed with unexpected error '
                || SQLERRM;
    END;

    PROCEDURE run_req_import (p_import_source IN VARCHAR2, p_batch_id IN VARCHAR2:= '', p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_user_id IN NUMBER, p_status OUT VARCHAR
                              , p_msg OUT VARCHAR2, p_request_id OUT NUMBER)
    AS
        l_request_id   NUMBER;
        l_req_id       NUMBER;
        l_req_status   BOOLEAN;
        x_ret_stat     VARCHAR2 (1);
        x_error_text   VARCHAR2 (20000);
        l_phase        VARCHAR2 (80);
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        p_resp_id      NUMBER;
        p_app_id       NUMBER;
    BEGIN
        DBMS_OUTPUT.put_line ('run_req_import - enter');
        DBMS_OUTPUT.put_line ('     Import Source : ' || p_import_source);
        DBMS_OUTPUT.put_line ('     Batch ID      : ' || p_batch_id);
        DBMS_OUTPUT.put_line ('     org ID        : ' || p_org_id);
        DBMS_OUTPUT.put_line ('     inv org ID    : ' || p_inv_org_id);
        DBMS_OUTPUT.put_line ('     user_id       : ' || p_user_id);

        BEGIN
            --Log into Purchasing responsibility
            SELECT DISTINCT responsibility_id, application_id
              INTO p_resp_id, p_app_id
              FROM apps.fnd_responsibility_tl
             WHERE responsibility_name = PO_Responsibility;

            apps.do_apps_initialize (p_user_id, p_resp_id, p_app_id); ---Deckers Purchasing User - Global
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                apps.do_apps_initialize (p_user_id, PO_Rresp_id, PO_App_ID); ---Deckers Purchasing User - Global
        END;

        apps.fnd_global.initialize ('ORG_ID', p_org_id);
        apps.fnd_request.set_org_id (p_org_id);
        --fnd_global.apps_initialize(user_id => 1037, resp_id => l_dest_resp_id, resp_appl_id => l_dest_app_id);
        --fnd_global.initialize(l_buffer_number, 1037, l_dest_resp_id, l_dest_app_id, 0, -1, -1, -1, -1, -1, 666, -1);
        apps.fnd_profile.put ('MFG_ORGANIZATION_ID', p_inv_org_id);
        DBMS_OUTPUT.put_line ('run_req_import - submit request');
        l_request_id   :=
            apps.fnd_request.submit_request (application   => 'PO',
                                             program       => 'REQIMPORT',
                                             argument1     => p_import_source,
                                             argument2     => p_batch_id,
                                             argument3     => 'VENDOR',
                                             argument4     => '',
                                             argument5     => 'N',
                                             argument6     => 'Y');
        DBMS_OUTPUT.put_line (l_req_id);

        COMMIT;
        DBMS_OUTPUT.put_line (
               'run_req_import - wait for request - Request ID :'
            || l_request_id);
        l_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => l_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);

        DBMS_OUTPUT.put_line (
            'run_req_import - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text   :=
                NVL (
                    l_message,
                       'The requisition import request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
        ELSE
            x_ret_stat   := 'S';
        END IF;

        DBMS_OUTPUT.put_line (
            'run_req_import - after wait for request -  ' || x_ret_stat);
        p_status       := x_ret_stat;
        p_msg          := x_error_text;
        p_request_id   := l_request_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status       := 'U';
            p_msg          :=
                   ' requisition import failed with unexpected error '
                || SQLERRM;
            p_request_id   := NULL;
    END;

    FUNCTION copy_internal_rec (p_src_req_number IN NUMBER, p_src_org IN NUMBER, p_dest_org IN NUMBER, p_need_by_date IN DATE:= NULL, p_interface_source_code IN VARCHAR2:= Interface_Source_Code, p_undelivered_only IN VARCHAR2:= 'Y'
                                , p_run_req_import IN VARCHAR2:= 'Y', p_user_id IN NUMBER, p_preparer_id IN NUMBER)
        RETURN NUMBER
    AS
        p_req_header_id   NUMBER;
        p_org_id          NUMBER;
        x_message         VARCHAR2 (1000);
        p_status          VARCHAR2 (1);
        p_request_id      NUMBER;
        p_new_req         NUMBER;

        CURSOR c_rec IS
            SELECT prla.requisition_line_id, prha.requisition_header_id, prla.item_id,
                   prha.preparer_id, prha.org_id, prla.source_type_code,
                   prla.need_by_date, prla.quantity, prla.quantity_delivered,
                   prla.cancel_flag, prla.base_unit_price, msib.primary_uom_code,
                   prla.to_person_id
              FROM apps.po_requisition_lines_all prla, apps.po_requisition_headers_all prha, apps.mtl_system_items_b msib
             WHERE     prla.requisition_header_id =
                       prha.requisition_header_id
                   AND prla.item_id = msib.inventory_item_id
                   AND prla.destination_organization_id =
                       msib.organization_id
                   AND prla.quantity - prla.quantity_delivered > 0
                   AND prha.requisition_header_id = p_req_header_id;
    --build cursor to insert into the requisition interface based on items in another ISO

    BEGIN
        DBMS_OUTPUT.put_line ('copy_internal_rec - enter');

        BEGIN
            SELECT requisition_header_id, org_id
              INTO p_req_header_id, p_org_id
              FROM po_requisition_headers_all
             WHERE segment1 = p_src_req_number AND org_id = p_src_org;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DBMS_OUTPUT.put_line ('copy_internal_rec - req not found');
                RETURN NULL;
        END;

        DBMS_OUTPUT.put_line (
            'copy_internal_rec - REQ found - header_id : ' || p_req_header_id);

        FOR rec IN c_rec
        LOOP
            --dbms_output.put_line('Need by date : '||to_char(rec.need_by_date));
            --dbms_output.put_line('To Person ID : '||to_char(rec.to_person_id));
            INSERT INTO apps.PO_REQUISITIONS_INTERFACE_ALL (
                            INTERFACE_SOURCE_CODE,
                            BATCH_ID,
                            ORG_ID,
                            DESTINATION_TYPE_CODE,
                            AUTHORIZATION_STATUS,
                            PREPARER_ID,
                            CHARGE_ACCOUNT_ID,
                            SOURCE_TYPE_CODE,
                            --SOURCE_ORGANIZATION_ID,
                            UOM_CODE,
                            LINE_TYPE_ID,
                            QUANTITY,
                            UNIT_PRICE,
                            DESTINATION_ORGANIZATION_ID,
                            DELIVER_TO_LOCATION_ID,
                            DELIVER_TO_REQUESTOR_ID,
                            ITEM_ID,
                            HEADER_DESCRIPTION,
                            NEED_BY_DATE,
                            HEADER_ATTRIBUTE15,
                            LINE_ATTRIBUTE15)
                 VALUES (p_interface_source_code,      --Interface source code
                         TO_CHAR (p_src_req_number), --batch ID                                              ,
                         p_org_id,          --operating unit                 ,
                         'INVENTORY', --Destination Type Code                                        ,
                         'APPROVED', --Authorization Status                                       ,
                         p_preparer_id,                --(4224 = 'Torti, Joe')
                         (SELECT material_account
                            FROM apps.mtl_parameters
                           WHERE organization_id = p_dest_org), --Code Combination ID from dest Inv Org Parameters         ,
                         'INVENTORY',                       --Source Type Code
                         rec.primary_uom_code,                           --UOM
                         1,                               --Line Type of Goods
                         rec.quantity - rec.quantity_delivered,
                         rec.base_unit_price, --Unit_price (from lookup table)
                         p_dest_org, --Dest Organization Id                               ,
                         (SELECT location_id
                            FROM apps.hr_all_organization_units
                           WHERE organization_id = p_dest_org), --Dest Location Id               ,
                         rec.to_person_id, --Deliver to Requestor Id (4224 = 'Torti, Joe')
                         rec.item_id,                                   --Item
                         'IR copy program',       --Description (set to BRAND)
                         NVL (p_need_by_date, rec.need_by_date),
                         TO_CHAR (rec.requisition_header_id),
                         TO_CHAR (rec.requisition_line_id) --Post the REQ line the new REQ lines was copied from
                                                          );
        END LOOP;

        DBMS_OUTPUT.put_line ('copy_internal_rec - before req_import');

        IF p_run_req_import = 'Y'
        THEN
            DBMS_OUTPUT.put_line ('copy_internal_rec - run req import');
            run_req_import (p_import_source => p_interface_source_code, p_batch_id => TO_CHAR (p_src_req_number), p_org_id => p_org_id, p_inv_org_id => p_dest_org, p_user_id => p_user_id, p_status => p_status
                            , p_msg => x_message, p_request_id => p_request_id);
            DBMS_OUTPUT.put_line (
                   'copy_internal_rec - after run req import - status '
                || p_status);
            DBMS_OUTPUT.put_line (
                   'copy_internal_rec - after run req import - request_id '
                || p_request_id);

            BEGIN
                SELECT requisition_header_id
                  INTO p_new_req
                  FROM apps.po_requisition_headers_all
                 WHERE     request_id = p_request_id
                       AND interface_source_code = p_interface_source_code;

                DBMS_OUTPUT.put_line (
                    'copy_internal_rec - new req ' || p_new_req);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    RETURN NULL;
            END;

            RETURN p_new_req;
        ELSE
            RETURN -1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN -1;
    END;

    --function create_iso_from_ir(src_req_number in number) return number;

    --Move reservations from one SO-PO to another SO pointing to same PO
    PROCEDURE move_reservations (p_src_order_number IN NUMBER, p_dest_order_number IN NUMBER, p_user_id IN NUMBER
                                 , p_reserv_type IN NUMBER:= 1)
    AS
        x_ret_stat         VARCHAR2 (1);
        x_error_msg        VARCHAR2 (2000);
        n_order_type_id    NUMBER;
        l_message          VARCHAR2 (200);
        update_attr16      BOOLEAN := FALSE;
        p_sales_order_id   NUMBER;
        data_exception     EXCEPTION;

        CURSOR c_recs IS
            SELECT oola_src.line_id, mr.reservation_id, oola_src.flow_status_code src_line_status,
                   mr.supply_source_line_id po_line_location_id, oola_dest.line_id dest_line_id, oola_dest.flow_status_code dest_line_status
              FROM oe_order_headers_all ooha_src, oe_order_lines_all oola_src, oe_order_headers_all ooha_dest,
                   oe_order_lines_all oola_dest, mtl_reservations mr
             WHERE     oola_src.header_id = ooha_src.header_id
                   AND oola_dest.header_id = ooha_dest.header_id
                   AND oola_src.line_id = mr.demand_source_line_id(+)
                   AND ooha_src.order_number = p_src_order_number
                   AND ooha_dest.order_number = p_dest_order_number
                   AND oola_src.org_id = oola_dest.org_id
                   AND oola_src.header_id != oola_dest.header_id
                   AND oola_src.ordered_quantity = oola_dest.ordered_quantity
                   AND oola_src.inventory_item_id =
                       oola_dest.inventory_item_id
                   AND mr.supply_source_type_id = p_reserv_type;
    BEGIN
        SELECT mso.sales_order_id
          INTO p_sales_order_id
          FROM apps.oe_order_headers_all ooha,
               (SELECT *
                  FROM apps.oe_transaction_types_tl
                 WHERE language = 'US') tt,
               apps.mtl_sales_orders mso
         WHERE        ooha.order_number
                   || '-'
                   || tt.name
                   || '-'
                   || 'ORDER ENTRY' =
                   mso.segment1 || '-' || mso.segment2 || '-' || mso.segment3
               AND ooha.order_number = p_dest_order_number;


        BEGIN
            SELECT order_type_id
              INTO n_order_type_id
              FROM oe_order_headers_all ooha
             WHERE order_number = p_src_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_message   := 'Order Not found';
                RAISE data_exception;
        END;

        DBMS_OUTPUT.put_line ('Order type ID       : ' || n_order_type_id);
        DBMS_OUTPUT.put_line ('mso.sales_order_id  : ' || p_sales_order_id);
        --Update attribute16 only DC - DC transfers
        update_attr16   := n_order_type_id = DC_XFER_Order_type;

        IF update_attr16
        THEN
            DBMS_OUTPUT.put_line ('Attribute16 modification set');
        ELSE
            DBMS_OUTPUT.put_line ('No atttribute16 modification');
        END IF;

        FOR rec IN c_recs
        LOOP
            delete_reservation_by_id (rec.reservation_id, p_user_id, x_ret_stat
                                      , x_error_msg);

            IF x_ret_stat = 'S' AND update_attr16
            THEN
                DBMS_OUTPUT.put_line (
                       'Updating atribute16 on line ID : '
                    || rec.line_id
                    || ' to NULL');

                UPDATE oe_order_lines_all
                   SET attribute16   = NULL
                 WHERE line_id = rec.line_id;
            END IF;

            DBMS_OUTPUT.put_line (
                   'delete reservation - reservation ID : '
                || rec.reservation_id
                || ' result : '
                || x_ret_stat);

            IF x_ret_stat = 'S'
            THEN
                create_reservation_oe_to_po (
                    oe_line_id             => rec.dest_line_id,
                    po_line_location_id    => rec.po_line_location_id,
                    p_user_id              => p_user_id,
                    p_mso_sales_order_id   => p_sales_order_id,
                    x_ret_stat             => x_ret_stat,
                    x_error_msg            => x_error_msg);

                IF x_ret_stat = 'S' AND update_attr16
                THEN
                    DBMS_OUTPUT.put_line (
                           'Updating atribute16 on line ID : '
                        || rec.dest_line_id
                        || ' to '
                        || rec.po_line_location_id);

                    UPDATE oe_order_lines_all
                       SET attribute16   = rec.po_line_location_id
                     WHERE line_id = rec.dest_line_id;
                END IF;

                DBMS_OUTPUT.put_line (
                       'create reservation - line ID : '
                    || rec.dest_line_id
                    || ' line_location_id : '
                    || rec.po_line_location_id
                    || ' result : '
                    || x_ret_stat);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Error occured in  move_reservations ' || SQLERRM);
    END;

    /************************************************************************************************
    Main entry point for this process
    reroute_internal_so
    Parameters :
    Input:
            p_src_order_number    NUMBER        --Source ISO number
            p_so_source_org       NUMBER        --Org of the source SO
            p_dest_inv_org        NUMBER        --Destination INV ORG of new Internal REQ
            p_preparer_id         NUMBER        --Preparer ID to be used on new REQ
            p_need_by_date        DATE,         --Date for new IR
            p_interface_source_code IN VARCHAR
            p_user_id            IN NUMBER     --USER ID for process (this user needs proper purchasing and Order Management responsibilities)
    Output:
            p_new_ir_number         OUT NUMBER  --New generater internal REQ number
            p_new_iso_number        OUT NUMBER  --New generated internal SO number
            p_ret_stat              OUT VARCHAR --Return status,
            p_ret_msg               OUT VARCHAR --Return message
    *************************************************************************************************/

    PROCEDURE reroute_internal_so (p_src_order_number IN NUMBER, p_so_source_org IN NUMBER, p_dest_inv_org IN NUMBER, p_need_by_date IN DATE:= NULL, p_interface_source_code IN VARCHAR:= Interface_Source_Code, p_user_id IN NUMBER, p_partial_del_override IN VARCHAR2:= 'N', p_gtn_override IN VARCHAR2:= 'N', p_new_ir_number OUT NUMBER
                                   , p_new_iso_number OUT NUMBER, p_ret_stat OUT VARCHAR2, p_ret_msg OUT VARCHAR2)
    AS
        x_message              VARCHAR2 (200);
        x_ret_msg              VARCHAR2 (2000);
        x_stat                 VARCHAR2 (1);
        x_request_id           NUMBER;
        x_user_id              NUMBER;
        x_new_req_header_id    NUMBER;
        x_src_req_id           NUMBER;
        x_ir_org_id            NUMBER;
        x_src_req_number       NUMBER;
        x_header_id            NUMBER;
        x_org_id               NUMBER;
        x_order_type_id        NUMBER;
        n_cnt                  NUMBER;
        n_quantity             NUMBER;
        n_new_cnt              NUMBER;
        n_new_quantity         NUMBER;
        x_preparer_id          NUMBER;
        n_employee_id          NUMBER;
        x_source_inv_org_id    NUMBER;
        x_new_iso_org_id       NUMBER;
        x_new_iso_header_id    NUMBER;
        n_chk_cnt              NUMBER;
        validation_execption   EXCEPTION;
    BEGIN
        x_user_id    := p_user_id;

        BEGIN
            SELECT employee_id
              INTO n_employee_id
              FROM apps.fnd_user
             WHERE     user_id = p_user_id
                   AND NVL (TRUNC (start_date), TRUNC (SYSDATE - 1)) <=
                       SYSDATE
                   AND NVL (TRUNC (end_date), TRUNC (SYSDATE + 1)) >= SYSDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_message   := 'User not active or does not exist';
                RAISE validation_execption;
        END;

        IF n_employee_id IS NULL
        THEN
            x_message   := 'User not not setup as a buyer in the system';
            RAISE validation_execption;
        END IF;


        --TODO: DO we need to validate responsibilities for the user passed?

        DBMS_OUTPUT.put_line ('reroute_internal_so - enter');

        DBMS_OUTPUT.put_line ('--Validation step');

        BEGIN
            SELECT header_id, org_id, order_type_id
              INTO x_header_id, x_org_id, x_order_type_id
              FROM apps.oe_order_headers_all
             WHERE order_number = p_src_order_number AND open_flag = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_message   := 'Order ' || p_src_order_number || ' not found';
                RAISE validation_execption;
        END;

        IF x_org_id != p_so_source_org
        THEN
            x_message   := 'Order not in org ' || p_so_source_org;
            RAISE validation_execption;
        END IF;

        IF x_order_type_id != DC_XFER_Order_type
        THEN
            x_message   := 'Order not correct order type ' || p_so_source_org;
            RAISE validation_execption;
        END IF;

        --check for delivered quantity
        --a) there cannot be any delivered quantity against the parent IR
        --b) there cannot be any records in do_shipments for the child PO

        --TODO : if partial del override on then 'CLOSED' lines are allowed
        IF p_partial_del_override = 'Y'
        THEN
            SELECT COUNT (*)
              INTO n_cnt
              FROM oe_order_lines_all oola
             WHERE     flow_status_code NOT IN
                           ('PO_OPEN', 'CANCELLED', 'CLOSED')
                   AND oola.header_id = x_header_id;
        ELSE
            SELECT COUNT (*)
              INTO n_cnt
              FROM oe_order_lines_all oola
             WHERE     flow_status_code NOT IN ('PO_OPEN', 'CANCELLED')
                   AND oola.header_id = x_header_id;
        END IF;

        IF n_cnt > 0
        THEN
            x_message   := 'Order has lines in a invalid status for copy';
            RAISE validation_execption;
        END IF;

        --TODO : if partial del override on then delivered qty is OK
        SELECT COUNT (*)
          INTO n_cnt
          FROM apps.po_requisition_lines_all prla, oe_order_lines_all oola
         WHERE     oola.source_document_line_id = prla.requisition_line_id
               AND prla.quantity_delivered > 0
               AND oola.header_id = x_header_id;

        IF n_cnt > 0 AND p_partial_del_override != 'Y'
        THEN
            x_message   :=
                'Order has quantity delivered on parent internal req ';
            RAISE validation_execption;
        END IF;

        SELECT COUNT (*)
          INTO n_cnt
          FROM oe_order_lines_all oola, custom.do_items i
         WHERE     TO_NUMBER (oola.attribute16) = i.line_location_id
               AND NVL (i.entered_quantity, 0) > 0
               AND oola.header_id = x_header_id
               AND open_flag = 'Y';

        IF n_cnt > 0 AND p_gtn_override != 'Y'
        THEN
            x_message   := 'Order has pending GTNexus ASN/packing manefest ';
            RAISE validation_execption;
        END IF;


        SELECT COUNT (*)
          INTO n_cnt
          FROM apps.po_requisition_lines_all prla, oe_order_lines_all oola, rcv_shipment_lines rsl
         WHERE     oola.source_document_line_id = prla.requisition_line_id
               AND rsl.requisition_line_id = prla.requisition_line_id
               AND rsl.shipment_line_status_code NOT IN
                       ('CANCELLED', 'FULLY RECEIVED')
               AND oola.header_id = x_header_id;

        IF n_cnt > 0
        THEN
            x_message   := 'Order has in-transit shipment lines ';
            RAISE validation_execption;
        END IF;

        SELECT COUNT (*)
          INTO n_cnt
          FROM oe_order_lines_all oola
         WHERE     (   oola.attribute16 IS NULL
                    OR NOT EXISTS
                           (SELECT NULL
                              FROM po_line_locations_all plla, mtl_reservations mr
                             WHERE     oola.line_id =
                                       mr.demand_source_line_id
                                   AND mr.supply_source_line_id =
                                       plla.line_location_id
                                   AND mr.supply_source_type_id = 1))
               AND oola.header_id = x_header_id
               AND open_flag = 'Y';

        IF n_cnt > 0
        THEN
            x_message   := 'Order has invalid refernces to PO lines ';
            RAISE validation_execption;
        END IF;

        --End validation step
        DBMS_OUTPUT.put_line ('--Validation step - End');

          --Check order type and org of order
          --Get sorcing REQ for the so (Assumption: only one REQ will source a SO)

          --Also get count/quantity from src IR
          SELECT prha.org_id, prha.segment1, prha.requisition_header_id,
                 COUNT (*), SUM (prla.quantity - prla.quantity_delivered)
            INTO x_ir_org_id, x_src_req_number, x_src_req_id, n_cnt,
                            n_quantity
            FROM apps.po_requisition_headers_all prha,
                 apps.po_requisition_lines_all prla,
                 (  SELECT inventory_item_id, source_document_line_id, header_id
                      FROM oe_order_lines_all
                  GROUP BY inventory_item_id, source_document_line_id, header_id)
                 oola
           WHERE     oola.source_document_line_id = prla.requisition_line_id
                 AND prla.requisition_header_id = prha.requisition_header_id
                 AND oola.header_id = x_header_id
        GROUP BY prha.org_id, prha.segment1, prha.requisition_header_id,
                 prha.preparer_id
          HAVING SUM (prla.quantity - prla.quantity_delivered) > 0;

        DBMS_OUTPUT.put_line ('source REQ ID : ' || x_src_req_id);
        DBMS_OUTPUT.put_line (' Record count : ' || n_cnt);
        DBMS_OUTPUT.put_line (' quantity     : ' || n_quantity);

        --      x_message := 'Testing ';
        --      RAISE validation_execption;

        --Check if this step completed
        --Test condition - records exist where there is another IR line with an Attribute15 value pointing back to the sorcing IR line
        /*select count(*)
        into n_chk_cnt
        from po_requisition_lines_all prla, po_requisition_lines_all prla1
        where
        prla.requisition_line_id = prla1.attribute15
        and prla1.attribute_category != 'REQ_CONVERSION'
        and prla.requisition_header_id = x_src_req_id;*/

        --If n_chk_cnt is >0, what do we do?


        DBMS_OUTPUT.put_line (
            'reroute_internal_so - create new IR in dest org');
        --1) create new IR into new ORG as a copy of IR in old org(minus received if partial allowed)
        x_new_req_header_id   :=
            copy_internal_rec (p_src_req_number => x_src_req_number, p_src_org => x_ir_org_id, p_dest_org => p_dest_inv_org, p_need_by_date => p_need_by_date, p_interface_source_code => p_interface_source_code, p_user_id => x_user_id
                               , p_preparer_id => n_employee_id);
        --a) check if IR created and quantities match source
        DBMS_OUTPUT.put_line ('reroute_internal_so - validate IR creation');

          --get row count/quantity from created req
          SELECT COUNT (*), SUM (prla.quantity), prla.source_organization_id,
                 prha.segment1
            INTO n_new_cnt, n_new_quantity, x_source_inv_org_id, p_new_ir_number
            FROM apps.po_requisition_lines_all prla, apps.po_requisition_headers_all prha
           WHERE     prha.requisition_header_id = x_new_req_header_id
                 AND prla.requisition_header_id = prha.requisition_header_id
        GROUP BY prla.source_organization_id, prha.segment1;

        DBMS_OUTPUT.put_line (
            ' destination REQ ID : ' || x_new_req_header_id);
        DBMS_OUTPUT.put_line (
            ' destination REQ Number : ' || p_new_ir_number);
        DBMS_OUTPUT.put_line (' Record count : ' || n_new_cnt);
        DBMS_OUTPUT.put_line (' quantity     : ' || n_new_quantity);


        IF n_cnt != n_new_cnt OR n_quantity != n_new_quantity
        THEN
            x_message   := 'Destination req does not match source req';
            RAISE validation_execption;
        END IF;

        --2) create a new ISO from this IR

        --Check if step completed
        --Test condition - are there lines in ONT interface pointing back to the REQ
        /*   select count(*)
           into n_chk_cnt
           from oe_lines_iface_all oola,
           po_requisition_lines_all prla
           where
           to_char(prla.requisition_line_id) = oola.orig_sys_line_ref
           and to_char(prla.requisition_header_id) = oola.orig_sys_document_ref
           and prla.requisition_header_id = x_src_req_id;*/



        DBMS_OUTPUT.put_line (
            'reroute_internal_so - create internal sales order');

        run_create_internal_orders (x_ir_org_id, p_dest_inv_org, x_user_id,
                                    x_stat, x_ret_msg, x_request_id);
        DBMS_OUTPUT.put_line (
            'reroute_internal_so - after create_internal_orders');
        DBMS_OUTPUT.put_line ('     status    : ' || x_stat);
        DBMS_OUTPUT.put_line ('     message    :' || x_ret_msg);
        DBMS_OUTPUT.put_line ('     request_id :' || x_request_id);


        --Check errors returned
        IF x_stat != 'S'
        THEN
            x_message   := 'Create orders error ' || x_ret_msg;
            RAISE validation_execption;
        END IF;

          --Validate quantity/count on generated iface records for ISO (the orig_sys_document_ref value is the req header ID)
          --Get org ID and inv_org_id for import order
          SELECT org_id, ship_from_org_id, COUNT (*),
                 SUM (ordered_quantity)
            INTO x_new_iso_org_id, x_source_inv_org_id, n_new_cnt, n_new_quantity
            FROM oe_lines_iface_all
           WHERE orig_sys_document_ref = TO_CHAR (x_new_req_header_id)
        GROUP BY org_id, ship_from_org_id;

        DBMS_OUTPUT.put_line (
            'reroute_internal_so - validate ISO on interface');

        --need to get ORG and DEST WHS on order in interface
        IF n_cnt != n_new_cnt OR n_quantity != n_new_quantity
        THEN
            x_message   := 'ISO on ONT Interface does not match original IR';
            RAISE validation_execption;
        END IF;



        --Check if step completed
        --Test condition - are there lines in OOLA pointing back to the REQ
        /*    select count(*)
            into n_chk_cnt
            from oe_order_lines_all oola,
            po_requisition_lines_all prla
            where
            to_char(prla.requisition_line_id) = oola.orig_sys_line_ref
            and to_char(prla.requisition_header_id) = oola.orig_sys_document_ref
            and prla.requisition_header_id = x_src_req_id;*/


        ---Call procedure to run order import to import the order into oracle
        run_order_import (p_org_id       => x_new_iso_org_id,
                          p_inv_org_id   => x_source_inv_org_id,
                          p_user_id      => x_user_id,
                          p_status       => x_stat,
                          p_msg          => x_ret_msg,
                          p_request_id   => x_request_id);

        DBMS_OUTPUT.put_line ('reroute_internal_so - after run_order_import');
        DBMS_OUTPUT.put_line ('     status    : ' || x_stat);
        DBMS_OUTPUT.put_line ('     message    :' || x_ret_msg);
        DBMS_OUTPUT.put_line ('     request_id :' || x_request_id);

        --Check errors returned
        IF x_stat != 'S'
        THEN
            x_message   := 'Import Orders error ' || x_ret_msg;
            RAISE validation_execption;
        END IF;

          --Validate ISO created
          SELECT ooha.order_number, ooha.header_id, oola.org_id,
                 oola.ship_from_org_id, COUNT (*), SUM (ordered_quantity)
            INTO p_new_iso_number, x_new_iso_header_id, x_new_iso_org_id, x_source_inv_org_id,
                                 n_new_cnt, n_new_quantity
            FROM oe_order_lines_all oola, oe_order_headers_all ooha
           WHERE     oola.source_document_id = x_new_req_header_id
                 AND ooha.org_id = x_new_iso_org_id
                 AND oola.flow_status_code = 'SUPPLY_ELIGIBLE'
                 AND oola.header_id = ooha.header_id
        GROUP BY ooha.order_number, ooha.header_id, oola.org_id,
                 oola.ship_from_org_id;

        IF n_cnt != n_new_cnt OR n_quantity != n_new_quantity
        THEN
            x_message   := 'Created ISO does not match original IR';
            RAISE validation_execption;
        END IF;

        DBMS_OUTPUT.put_line ('ISO Number    : ' || p_new_iso_number);
        DBMS_OUTPUT.put_line ('ISO Header ID : ' || x_new_iso_header_id);

        --Has this step completed
        --Check if new ISO already has reservations to a PO


        --3) move reservations from old SO to new SO
        --a) validate reservations for all lines on new ISO
        --b) validate no reservations exist on old ISO
        move_reservations (p_src_order_number => p_src_order_number, p_dest_order_number => p_new_iso_number, p_user_id => x_user_id
                           , p_reserv_type => 1);

        SELECT COUNT (*), SUM (ordered_quantity)
          INTO n_new_cnt, n_new_quantity
          FROM oe_order_headers_all ooha, oe_order_lines_all oola, mtl_reservations mr
         WHERE     oola.header_id = ooha.header_id
               AND oola.line_id = mr.demand_source_line_id
               AND ooha.header_id = x_new_iso_header_id
               AND mr.supply_source_type_id = 1
               AND oola.flow_status_code = 'PO_OPEN';

        IF n_cnt != n_new_cnt OR n_quantity != n_new_quantity
        THEN
            x_message   := 'Reservation count not matching original SO';
            RAISE validation_execption;
        END IF;



        --4) Cancel old ISO
        --a) validate cancelled

        --5) cancel old IR
        --a) validate cancelled
        DBMS_OUTPUT.put_line (
            'reroute_internal_so - completed sucessfully !!!');
        p_ret_stat   := 'S';
    EXCEPTION
        WHEN validation_execption
        THEN
            p_ret_msg    := 'Validation exception : ' || x_message;
            p_ret_stat   := 'E';
        WHEN OTHERS
        THEN
            p_ret_msg    := 'Unexpected error : ' || SQLERRM;
            p_ret_stat   := 'U';
    END;
END xxdoom_reroute_iso;
/
