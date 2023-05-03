--
-- XXD_WMS_DIRECT_SHIPCONF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_DIRECT_SHIPCONF_PKG"
AS
    /************************************************************************************************
       * Package         : XXD_WMS_DIRECT_SHIPCONF_PKG
       * Description     : This package is used to ship confirm the staged pick tickets.(Calling from both SOA and EBS)
       * Notes           :
       * Modification    :
    * EBS Program     : Deckers WMS Direct Ship Order Invoice Program
       *-----------------------------------------------------------------------------------------------
       * Date         Version#   Name                     Description
       *-----------------------------------------------------------------------------------------------
       * 13-MAY-2019  1.0        Showkath Ali             Initial Version
       * 11-Sep-2019  1.1        Viswanathan Pandian      Updated for CCR0008125
       * 16-May-2022  2.0        Gaurav Joshi             Updated for CCR0009921
       * 30-May-2022  2.1        Aravind Kannuri          Updated for CCR0009887
    * 21-Nov-2022  2.2        Shivanshu                Updated for CCR0010291 - Direct Ship Improvements
    * 12-Dec-2022  2.3        Aravind Kannuri          Updated for CCR0009817 - HK Wholesale Changes
       ************************************************************************************************/
    ln_request_id   NUMBER;                          -- fnd_global.request_id;

    -- begin 2.0
    -- procedure to insert the debug/errors in debug table
    PROCEDURE insert_into_email_table (p_data IN xxd_wms_email_output_type)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        FORALL i IN p_data.FIRST .. p_data.LAST
            INSERT INTO xxdo.xxd_wms_email_output_t (
                            request_id,
                            container_number,
                            order_number,
                            cust_po_number,
                            delivery_id,
                            old_triggering_event_name,
                            new_triggering_event_name,
                            created_by,
                            creation_date,
                            last_update_date,
                            last_updated_by,
                            last_update_login)
                     VALUES (p_data (i).request_id,
                             p_data (i).container_number,
                             p_data (i).order_number,
                             p_data (i).cust_po_number,
                             p_data (i).delivery_id,
                             p_data (i).old_triggering_event_name,
                             p_data (i).new_triggering_event_name,
                             p_data (i).created_by,
                             p_data (i).creation_date,
                             p_data (i).last_update_date,
                             p_data (i).last_updated_by,
                             p_data (i).last_update_login);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_into_email_table;

    -- end 2.0

    -- procedure to insert the debug/errors in debug table
    PROCEDURE insert_debug (p_debug_text      IN VARCHAR2,
                            p_debug_message   IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        /*  --Commented for 2.1
        INSERT INTO custom.do_debug (debug_text,
                                     creation_date,
                                     created_by,
                                     session_id,
                                     debug_id,
                                     request_id,
                                     application_id,
                                     call_stack)
             VALUES (p_debug_text,
                     SYSDATE,
                     NVL (gn_created_by, -1),
                     NVL (gn_session_id, -1),
                     NVL (gn_debug_id, -1),
                     NVL (gn_request_id, -1),
                     gv_application,
                     p_debug_message);*/

        --Start Added for 2.1
        INSERT INTO xxdo.xxd_wms_custom_debug_t (request_id,
                                                 debug_text,
                                                 creation_date,
                                                 created_by,
                                                 last_update_date,
                                                 last_updated_by,
                                                 session_id,
                                                 debug_id,
                                                 debug_message)
                 VALUES (NVL (ln_request_id, -1),
                         p_debug_text,
                         gd_date,
                         NVL (gn_created_by, -1),
                         gd_date,
                         NVL (gn_last_updated_by, -1),
                         NVL (gn_session_id, -1),
                         NVL (gn_debug_id, -1),
                         p_debug_message);

        --End Added for 2.1
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_debug;

    --Start Added for 2.1
    FUNCTION get_triggering_event_lkp (p_customer_id IN NUMBER, p_organization_id IN NUMBER, p_triggering_event IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_triggering_event   VARCHAR2 (250) := NULL;
    BEGIN
        --Get Triggering event from lookup associated with Customer and Organization
        SELECT TRIM (flv.attribute3)
          INTO lv_triggering_event
          FROM fnd_lookup_values flv, hz_cust_accounts_all hca, mtl_parameters mp
         WHERE     flv.language = 'US'
               AND TRIM (flv.attribute1) = hca.account_number
               AND hca.cust_account_id = p_customer_id
               AND TRIM (flv.attribute2) = mp.organization_code
               AND mp.organization_id = p_organization_id
               AND flv.lookup_type = 'XXD_ODC_CUST_INV_EVENT_LKP'
               AND TRIM (flv.attribute3) = p_triggering_event
               AND flv.enabled_flag = 'Y'                      --Added for 2.3
               AND SYSDATE BETWEEN flv.start_date_active
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        RETURN lv_triggering_event;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_triggering_event   := NULL;
            RETURN lv_triggering_event;
            fnd_file.put_line (fnd_file.LOG, 'EXP- Error : ' || SQLERRM);
    END;

    --End Added for 2.1

    --Start Added for 2.3
    --Validate Input Parameters combinations
    FUNCTION validate_err_inputs (p_bol_number IN VARCHAR2 DEFAULT NULL, p_container IN VARCHAR2 DEFAULT NULL, p_delivery_number IN NUMBER DEFAULT NULL)
        RETURN VARCHAR2
    IS
        ln_exists   NUMBER := 0;
    BEGIN
        --Validate BOL\Container\Delivery
        BEGIN
            SELECT COUNT (1)
              INTO ln_exists
              FROM apps.oe_order_headers_all ooha,
                   apps.wsh_new_deliveries wnd,
                   apps.wsh_carriers wc,
                   apps.hz_cust_accounts_all hzca,
                   (SELECT DISTINCT s.asn_reference_no, s.vessel_name, s.etd,
                                    s.bill_of_lading, c.container_ref, i.atr_number
                      FROM custom.do_shipments s, custom.do_containers c, custom.do_items i
                     WHERE     s.shipment_id = c.shipment_id
                           AND c.container_id = i.container_id) ship
             WHERE     ooha.header_id = wnd.source_header_id
                   AND ooha.sold_to_org_id = wnd.customer_id
                   AND ooha.sold_to_org_id = hzca.cust_account_id
                   AND wnd.attribute8 = ship.atr_number
                   AND wnd.carrier_id = wc.carrier_id
                   AND ooha.open_flag = 'Y'
                   AND wnd.status_code = 'OP'
                   AND ship.bill_of_lading =
                       NVL (p_bol_number, ship.bill_of_lading) --BOL: BANQDILL10292A
                   AND ship.container_ref =
                       NVL (p_container, ship.container_ref) --CONTAINER: DILL10291C\DILL10291B
                   AND wnd.delivery_id =
                       NVL (p_delivery_number, wnd.delivery_id); --DELIVERY: 574431666\574431028
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_exists   := -99;
        END;

        IF NVL (ln_exists, 0) > 0
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_exists   := -99;
            fnd_file.put_line (fnd_file.LOG, 'EXP- Error : ' || SQLERRM);
            RETURN 'N';
    END;

    --End Added for 2.3

    PROCEDURE validations_prc (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_bol_number IN VARCHAR2, p_container IN VARCHAR2, p_delivery_id IN NUMBER, p_user_account IN VARCHAR2
                               , p_source IN VARCHAR2)
    IS
        l_edi_count      NUMBER;
        l_staged_count   NUMBER;
        l_detail_count   NUMBER;
        l_packed_count   NUMBER;
        l_ship_grant     NUMBER;
    BEGIN
        -- VALIDATION2: Delivery should be available in EDI 856 custom table
        SELECT COUNT (1)
          INTO l_edi_count
          FROM do_edi.do_edi856_shipments ship, do_edi.do_edi856_pick_tickets pt
         WHERE     ship.shipment_id = pt.shipment_id
               AND pt.delivery_id = p_delivery_id;

        IF l_edi_count = 0
        THEN
            gv_debug_text      :=
                   'Delivery is not exist in EDI 856 Shipment Table for delivery:'
                || p_delivery_id;
            gv_debug_message   := 'validations_prc Procedure';
            insert_debug (gv_debug_text, gv_debug_message);

            IF p_source = 'EBS'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Delivery is not exist in EDI 856 Shipment Table for delivery:'
                    || p_delivery_id);
            END IF;

            BEGIN
                UPDATE xxdo.xxd_wms_ship_confirm_t
                   SET shipment_status = 'E', error_message = 'Delivery is not exist in EDI 856 Shipment Table for delivery:' || p_delivery_id, last_updated_by = gn_created_by,
                       last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id              --Added for 2.1
                 WHERE delivery_id = p_delivery_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gv_debug_text      :=
                           'Updating the custom table failed for delivery:'
                        || p_delivery_id
                        || '-'
                        || SQLERRM;
                    gv_debug_message   := 'validations_prc Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF p_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for delivery:'
                            || p_delivery_id
                            || '-'
                            || SQLERRM);
                    END IF;
            END;

            retcode            := 1;
            errbuf             :=
                   'Delivery is not exist in EDI 856 Shipment Table for delivery: '
                || p_delivery_id;
            RETURN;
        END IF;

        -- Validation to check all the lines are STAGED
        SELECT COUNT (wdd.delivery_detail_id)
          INTO l_staged_count
          FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
         WHERE     wda.delivery_detail_id = wdd.delivery_detail_id
               AND wdd.released_status = 'Y'
               AND wda.delivery_id = p_delivery_id;

        SELECT COUNT (wdd.delivery_detail_id)
          INTO l_detail_count
          FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
         WHERE     wda.delivery_detail_id = wdd.delivery_detail_id
               AND wdd.source_code = 'OE'
               AND wda.delivery_id = p_delivery_id;

        IF l_staged_count <> l_detail_count
        THEN
            gv_debug_text      :=
                'All the lines are not staged for delivery:' || p_delivery_id;
            gv_debug_message   := 'validations_prc Procedure';
            insert_debug (gv_debug_text, gv_debug_message);

            IF p_source = 'EBS'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'All the lines are not staged for delivery:'
                    || p_delivery_id);
            END IF;

            BEGIN
                UPDATE xxdo.xxd_wms_ship_confirm_t
                   SET shipment_status = 'E', error_message = 'All the lines are not staged for delivery:' || p_delivery_id, last_updated_by = gn_created_by,
                       last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id              --Added for 2.1
                 WHERE delivery_id = p_delivery_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gv_debug_text      :=
                           'Updating the custom table failed for delivery:'
                        || p_delivery_id
                        || '-'
                        || SQLERRM;
                    gv_debug_message   := 'validations_prc Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF p_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for delivery:'
                            || p_delivery_id
                            || '-'
                            || SQLERRM);
                    END IF;
            END;

            retcode            := 1;
            errbuf             :=
                   'All the lines are not staged for delivery: '
                || p_delivery_id;
            RETURN;
        END IF;

        -- Validation to check all the lines in the delivery are packed to LPN
        SELECT COUNT (wda.delivery_detail_id)
          INTO l_packed_count
          FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd1
         WHERE     wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd1.delivery_detail_id = wda.parent_delivery_detail_id
               AND wda.delivery_id = p_delivery_id;

        IF l_packed_count <> l_detail_count
        THEN
            gv_debug_text      :=
                'All the lines are not packed for delivery:' || p_delivery_id;
            gv_debug_message   := 'validations_prc Procedure';
            insert_debug (gv_debug_text, gv_debug_message);

            IF p_source = 'EBS'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'All the lines are not packed for delivery:'
                    || p_delivery_id);
            END IF;

            BEGIN
                UPDATE xxdo.xxd_wms_ship_confirm_t
                   SET shipment_status = 'E', error_message = 'All the lines are not packed for delivery:' || p_delivery_id, last_updated_by = gn_created_by,
                       last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id              --Added for 2.1
                 WHERE delivery_id = p_delivery_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gv_debug_text      :=
                           'Updating the custom table failed for delivery:'
                        || p_delivery_id
                        || '-'
                        || SQLERRM;
                    gv_debug_message   := 'validations_prc Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF p_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for delivery:'
                            || p_delivery_id
                            || '-'
                            || SQLERRM);
                    END IF;
            END;

            retcode            := 1;
            errbuf             :=
                   'All the lines are not packed for delivery: '
                || p_delivery_id;
            RETURN;
        END IF;
    END validations_prc;

    PROCEDURE ship_confirm_prc (p_ship_delivery_id IN NUMBER, p_source IN VARCHAR2, p_result OUT VARCHAR2)
    IS
        --Standard Parameters
        p_api_version               NUMBER;
        p_init_msg_list             VARCHAR2 (30);
        p_commit                    VARCHAR2 (30);
        --Parameters for WSH_DELIVERIES_PUB.Delivery_Action.
        p_action_code               VARCHAR2 (15);
        p_delivery_id               NUMBER;
        p_delivery_name             VARCHAR2 (30);
        p_asg_trip_id               NUMBER;
        p_asg_trip_name             VARCHAR2 (30);
        p_asg_pickup_stop_id        NUMBER;
        p_asg_pickup_loc_id         NUMBER;
        p_asg_pickup_loc_code       VARCHAR2 (30);
        p_asg_pickup_arr_date       DATE;
        p_asg_pickup_dep_date       DATE;
        p_asg_dropoff_stop_id       NUMBER;
        p_asg_dropoff_loc_id        NUMBER;
        p_asg_dropoff_loc_code      VARCHAR2 (30);
        p_asg_dropoff_arr_date      DATE;
        p_asg_dropoff_dep_date      DATE;
        p_sc_action_flag            VARCHAR2 (10);
        p_sc_close_trip_flag        VARCHAR2 (10);
        p_sc_create_bol_flag        VARCHAR2 (10);
        p_sc_stage_del_flag         VARCHAR2 (10);
        p_sc_trip_ship_method       VARCHAR2 (30);
        p_sc_actual_dep_date        VARCHAR2 (30);
        p_sc_report_set_id          NUMBER;
        p_sc_report_set_name        VARCHAR2 (60);
        p_wv_override_flag          VARCHAR2 (10);
        p_sc_defer_interface_flag   VARCHAR2 (1);
        x_trip_id                   VARCHAR2 (30);
        x_trip_name                 VARCHAR2 (30);
        --out parameters
        x_return_status             VARCHAR2 (10);
        x_msg_count                 NUMBER;
        x_msg_data                  VARCHAR2 (4000);
        x_msg_details               VARCHAR2 (4000);
        x_msg_summary               VARCHAR2 (4000);
        -- Handle exceptions
        vapierrorexception          EXCEPTION;
        l_user_id                   NUMBER;
        l_resp_id                   NUMBER;
        l_resp_appl_id              NUMBER;
        l_sqlerrm                   VARCHAR2 (4000);
        l_confirm_date              wsh_new_deliveries.confirm_date%TYPE;
        l_result                    VARCHAR2 (10);
    BEGIN
        -- Initialize return status
        x_return_status             := wsh_util_core.g_ret_sts_success;

        BEGIN
            SELECT frt.responsibility_id, fa.application_id
              INTO l_resp_id, l_resp_appl_id
              FROM fnd_responsibility_tl frt, fnd_application fa
             WHERE     frt.application_id = fa.application_id
                   AND frt.responsibility_name = 'Deckers WMS Shipping User'
                   AND language = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_resp_id        := -1;
                l_resp_appl_id   := -1;
        END;

        -- Call this procedure to initialize applications parameters
        fnd_global.apps_initialize (user_id        => gn_created_by,
                                    resp_id        => l_resp_id,
                                    resp_appl_id   => l_resp_appl_id);

        -- Values for Ship Confirming the delivery
        p_action_code               := 'CONFIRM'; -- The action code for ship confirm
        p_delivery_id               := p_ship_delivery_id; -- The delivery that needs to be confirmed
        p_sc_action_flag            := 'S';          -- Ship entered quantity.
        p_sc_close_trip_flag        := 'Y'; -- Close the trip after ship confirm
        p_sc_defer_interface_flag   := 'Y';                                 --

        -- Call to WSH_DELIVERIES_PUB.Delivery_Action.
        wsh_deliveries_pub.delivery_action (
            p_api_version_number        => 1.0,
            p_init_msg_list             => p_init_msg_list,
            x_return_status             => x_return_status,
            x_msg_count                 => x_msg_count,
            x_msg_data                  => x_msg_data,
            p_action_code               => p_action_code,
            p_delivery_id               => p_delivery_id,
            p_delivery_name             => p_delivery_name,
            p_asg_trip_id               => p_asg_trip_id,
            p_asg_trip_name             => p_asg_trip_name,
            p_asg_pickup_stop_id        => p_asg_pickup_stop_id,
            p_asg_pickup_loc_id         => p_asg_pickup_loc_id,
            p_asg_pickup_loc_code       => p_asg_pickup_loc_code,
            p_asg_pickup_arr_date       => p_asg_pickup_arr_date,
            p_asg_pickup_dep_date       => p_asg_pickup_dep_date,
            p_asg_dropoff_stop_id       => p_asg_dropoff_stop_id,
            p_asg_dropoff_loc_id        => p_asg_dropoff_loc_id,
            p_asg_dropoff_loc_code      => p_asg_dropoff_loc_code,
            p_asg_dropoff_arr_date      => p_asg_dropoff_arr_date,
            p_asg_dropoff_dep_date      => p_asg_dropoff_dep_date,
            p_sc_action_flag            => p_sc_action_flag,
            p_sc_close_trip_flag        => p_sc_close_trip_flag,
            p_sc_create_bol_flag        => p_sc_create_bol_flag,
            p_sc_stage_del_flag         => p_sc_stage_del_flag,
            p_sc_trip_ship_method       => p_sc_trip_ship_method,
            p_sc_actual_dep_date        => p_sc_actual_dep_date,
            p_sc_report_set_id          => p_sc_report_set_id,
            p_sc_report_set_name        => p_sc_report_set_name,
            p_wv_override_flag          => p_wv_override_flag,
            p_sc_defer_interface_flag   => p_sc_defer_interface_flag,
            x_trip_id                   => x_trip_id,
            x_trip_name                 => x_trip_name);

        IF (x_return_status <> wsh_util_core.g_ret_sts_success)
        THEN
            RAISE vapierrorexception;
            p_result   := 'E';
        ELSE
            IF p_source = 'EBS'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'The confirm action on the delivery '
                    || p_delivery_id
                    || ' is successful. Trip Id:'
                    || x_trip_id
                    || ', Trip Name:'
                    || x_trip_name);
            END IF;

            -- Update the custom table shipment_status as S for successfull records
            p_result           := 'S';

            -- Fetching the min of ship_confirm date from deliveries table
            BEGIN
                SELECT MIN (wnd.confirm_date)
                  INTO l_confirm_date
                  FROM wsh_new_deliveries wnd, do_edi.do_edi856_pick_tickets pt
                 WHERE     wnd.delivery_id = pt.delivery_id
                       AND pt.shipment_id =
                           (SELECT ship.shipment_id
                              FROM do_edi.do_edi856_shipments ship, do_edi.do_edi856_pick_tickets pt
                             WHERE     ship.shipment_id = pt.shipment_id
                                   AND pt.delivery_id = p_delivery_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_confirm_date     := NULL;
                    gv_debug_text      :=
                           'Fetching the ship_confirm date has been failed for delivery_id:' --Updation of shipment_date in EDI856 Table faild'
                        || p_delivery_id
                        || '-'
                        || SQLERRM;
                    gv_debug_message   := 'ship_confirm_prc Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF p_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Fetching the ship_confirm date has been failed for delivery_id:'
                            || p_delivery_id
                            || '-'
                            || SQLERRM);
                    END IF;
            END;

            -- Update the shipment date in EDI856 shipment table
            BEGIN
                UPDATE do_edi.do_edi856_shipments
                   SET ship_confirm_date = l_confirm_date, last_updated_by = gn_created_by, last_update_date = SYSDATE
                 WHERE     shipment_id =
                           (SELECT ship.shipment_id
                              FROM do_edi.do_edi856_shipments ship, do_edi.do_edi856_pick_tickets pt
                             WHERE     ship.shipment_id = pt.shipment_id
                                   AND pt.delivery_id = p_delivery_id)
                       AND ship_confirm_date IS NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gv_debug_text      :=
                           'Updation of shipment_date in EDI856 Table faild for drlivery_id: '
                        || p_delivery_id
                        || '-'
                        || SQLERRM;
                    gv_debug_message   := 'ship_confirm_prc Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF p_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updation of shipment_date in EDI856 Table faild for drlivery_id: '
                            || p_delivery_id
                            || '-'
                            || SQLERRM);
                    END IF;
            END;

            gv_debug_text      :=
                   'The confirm action on the delivery '
                || p_delivery_id
                || ' is successful';
            gv_debug_message   := 'ship_confirm_prc Procedure';
            insert_debug (gv_debug_text, gv_debug_message);
        END IF;
    EXCEPTION
        WHEN vapierrorexception
        THEN
            wsh_util_core.get_messages ('Y', x_msg_summary, x_msg_details,
                                        x_msg_count);

            IF x_msg_count > 1
            THEN
                x_msg_data         := x_msg_summary || x_msg_details;

                IF p_source = 'EBS'
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Message Data : ' || x_msg_data);
                END IF;

                BEGIN
                    UPDATE xxdo.xxd_wms_ship_confirm_t
                       SET shipment_status = 'E', error_message = 'Message Data : ' || x_msg_data, last_updated_by = gn_created_by,
                           last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id          --Added for 2.1
                     WHERE delivery_id = p_delivery_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gv_debug_text      :=
                               'Updating the custom table failed'
                            || '-'
                            || SQLERRM;
                        gv_debug_message   := 'ship_confirm_prc Procedure';
                        insert_debug (gv_debug_text, gv_debug_message);

                        IF p_source = 'EBS'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for delivery:'
                                || p_delivery_id
                                || '-'
                                || SQLERRM);
                        END IF;
                END;

                gv_debug_text      := 'Message Data : ' || x_msg_data;
                gv_debug_message   := 'ship_confirm_prc Procedure';
                insert_debug (gv_debug_text, gv_debug_message);
            ELSE
                x_msg_data         := x_msg_summary;

                IF p_source = 'EBS'
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Message Data : ' || x_msg_data);
                END IF;

                BEGIN
                    UPDATE xxdo.xxd_wms_ship_confirm_t
                       SET shipment_status = 'E', error_message = 'Message Data : ' || x_msg_data, last_updated_by = gn_created_by,
                           last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id          --Added for 2.1
                     WHERE delivery_id = p_delivery_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gv_debug_text      := 'Updating the custom table failed';
                        gv_debug_message   := 'ship_confirm_prc Procedure';
                        insert_debug (gv_debug_text, gv_debug_message);

                        IF p_source = 'EBS'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for delivery:'
                                || p_delivery_id
                                || '-'
                                || SQLERRM);
                        END IF;
                END;

                gv_debug_text      := 'Message Data : ' || x_msg_data;
                gv_debug_message   := 'ship_confirm_prc Procedure';
                insert_debug (gv_debug_text, gv_debug_message);

                IF p_source = 'EBS'
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Message Data : ' || x_msg_data);
                END IF;
            END IF;
        WHEN OTHERS
        THEN
            IF p_source = 'EBS'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Unexpected Error: ' || SQLERRM);
            END IF;

            l_sqlerrm          := SQLERRM;

            BEGIN
                UPDATE xxdo.xxd_wms_ship_confirm_t
                   SET shipment_status = 'E', error_message = 'Unexpected Error: ' || l_sqlerrm, last_updated_by = gn_created_by,
                       last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id              --Added for 2.1
                 WHERE delivery_id = p_delivery_id;

                COMMIT;

                IF p_source = 'EBS'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Updating the custom table failed for delivery:'
                        || p_delivery_id
                        || '-'
                        || SQLERRM);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gv_debug_text      := 'Unexpected Error: ' || SQLERRM;
                    gv_debug_message   := 'ship_confirm_prc Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);
            END;

            gv_debug_text      := 'Unexpected Error: ' || SQLERRM;
            gv_debug_message   := 'ship_confirm_prc Procedure';
            insert_debug (gv_debug_text, gv_debug_message);
    END ship_confirm_prc;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_user_account IN VARCHAR2, p_bol_number IN VARCHAR2, p_container IN VARCHAR2, p_triggering_event IN VARCHAR2
                    ,                                          --Added for 2.1
                      p_delivery_number IN NUMBER              --Added for 2.3
                                                 )
    AS
        CURSOR open_pick_tickets IS
            SELECT wnd.delivery_id, ship.bill_of_lading, ship.container_ref,
                   ooha.order_number, hzca.account_number, wnd.attribute8,
                   wnd.organization_id                           --w.r.t 2.1.1
              FROM apps.oe_order_headers_all ooha,
                   apps.wsh_new_deliveries wnd,
                   apps.wsh_carriers wc,
                   apps.hz_cust_accounts_all hzca,
                   (SELECT DISTINCT s.asn_reference_no, s.vessel_name, s.etd,
                                    s.bill_of_lading, c.container_ref, i.atr_number
                      FROM custom.do_shipments s, custom.do_containers c, custom.do_items i
                     WHERE     s.shipment_id = c.shipment_id
                           AND c.container_id = i.container_id) ship
             WHERE     ooha.header_id = wnd.source_header_id
                   AND ooha.sold_to_org_id = wnd.customer_id
                   AND ooha.sold_to_org_id = hzca.cust_account_id
                   AND wnd.attribute8 = ship.atr_number
                   --Start Added for 2.1
                   AND ((p_triggering_event IS NOT NULL AND NVL (wnd.attribute7, NVL (get_triggering_event_lkp (ooha.sold_to_org_id, ooha.ship_from_org_id, p_triggering_event), 'NA')) = p_triggering_event) OR (p_triggering_event IS NULL AND 1 = 2) OR (p_triggering_event = 'MANUAL') OR ((p_triggering_event = 'CUSTOM_INVOICE') AND NVL (get_triggering_event_lkp (ooha.sold_to_org_id, ooha.ship_from_org_id, p_triggering_event), 'NA') = p_triggering_event)) --w.r.t 2.2
                   --End Added for 2.1
                   AND wnd.carrier_id = wc.carrier_id
                   AND ooha.open_flag = 'Y'
                   AND wnd.status_code = 'OP'
                   AND ooha.order_type_id =
                       (SELECT transaction_type_id
                          FROM apps.oe_transaction_types_tl ottl
                         WHERE     ottl.name = 'Direct Ship - US'
                               AND ottl.language = USERENV ('LANG'))
                   AND EXISTS
                           (SELECT NULL
                              FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                             WHERE     wdd.delivery_detail_id =
                                       wda.delivery_detail_id
                                   AND wda.delivery_id = wnd.delivery_id
                                   AND wdd.source_header_id = ooha.header_id
                                   AND wdd.attribute8 = ship.atr_number
                                   AND wdd.released_status = 'Y')
                   AND ship.bill_of_lading = p_bol_number
                   AND ship.container_ref = p_container
                   AND wnd.delivery_id =
                       NVL (p_delivery_number, wnd.delivery_id) --Added for 2.3
            UNION                                             -- ADDED FOR US7
            SELECT wnd.delivery_id, WAYBILL,                 -- bill of lading
                                             wnd.attribute9, -- container_ref ATT9
                   ooha.order_number, hzca.account_number, wnd.attribute8, -- IT WILL BE NULL FOR US7
                   wnd.organization_id
              FROM apps.oe_order_headers_all ooha, apps.wsh_new_deliveries wnd, apps.hz_cust_accounts_all hzca
             WHERE     ooha.header_id = wnd.source_header_id
                   AND ooha.sold_to_org_id = wnd.customer_id
                   AND hzca.cust_account_id = ooha.sold_to_org_id
                   AND wnd.attribute9 = p_container
                   AND wnd.delivery_id =
                       NVL (p_delivery_number, wnd.delivery_id) --Added for 2.3
                   AND WAYBILL = p_bol_number
                   --Start Added for 2.1
                   AND ((p_triggering_event IS NOT NULL AND NVL (wnd.attribute7, NVL (get_triggering_event_lkp (ooha.sold_to_org_id, ooha.ship_from_org_id, p_triggering_event), 'NA')) = p_triggering_event) OR (p_triggering_event IS NULL AND 1 = 2) OR (p_triggering_event = 'MANUAL') OR ((p_triggering_event = 'CUSTOM_INVOICE') AND NVL (get_triggering_event_lkp (ooha.sold_to_org_id, ooha.ship_from_org_id, p_triggering_event), 'NA') = p_triggering_event)) --w.r.t 2.2
                   --End Added for 2.1
                   AND ooha.open_flag = 'Y'
                   AND wnd.status_code = 'OP'
                   AND (   ooha.order_type_id =
                           (SELECT transaction_type_id
                              FROM apps.oe_transaction_types_tl ottl
                             WHERE     ottl.name = 'Direct Ship OriginHub-US'
                                   AND ottl.language = USERENV ('LANG'))
                        OR ooha.ship_from_org_id IN
                               (SELECT organization_id
                                  FROM fnd_lookup_values A, MTL_PARAMETERS b
                                 WHERE     1 = 1
                                       AND lookup_type =
                                           'XXD_ODC_ORG_CODE_LKP'
                                       AND enabled_flag = 'Y'
                                       AND a.lookup_code =
                                           b.organization_code
                                       AND language = USERENV ('LANG')
                                       AND SYSDATE BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               SYSDATE + 1)));

        l_delivery_id            NUMBER;
        l_errbuf                 VARCHAR2 (4000);
        l_retcode                NUMBER;
        l_source                 VARCHAR2 (10);
        l_delivery_exist_count   NUMBER;
        l_ship_status            VARCHAR2 (10);
        l_cursor_count           NUMBER := 0;
        l_out_header_count       NUMBER := 0;                  --Added for 2.1
        l_output_heading         VARCHAR2 (1000);
        l_output_values          VARCHAR2 (4000);
        l_ship_grant             NUMBER;
        l_phase_code             VARCHAR2 (10);
        l_interfaced_count       NUMBER;
        l_delivery_count         NUMBER;
        l_request_id             NUMBER;
        l_chr_errbuf             VARCHAR2 (4000);
        l_sqlerrm                VARCHAR2 (4000);
        l_chr_ret_code           VARCHAR2 (30);
        lv_organization_code     VARCHAR2 (50);
        --Start Added for 2.3
        lv_bol_result            VARCHAR2 (50);
        lv_cont_result           VARCHAR2 (50);
        lv_del_result            VARCHAR2 (50);
        lv_input_param_error     VARCHAR2 (1000);
        --End Added for 2.3
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF NVL (gn_request_id, -1) = -1
        THEN
            l_source           := 'SOA';

            SELECT XXD_CONT_CLOSE_SOA_REQ_ID_S.NEXTVAL
              INTO l_request_id
              FROM DUAL;

            ln_request_id      := l_request_id;
            gv_debug_text      := 'The Program called by SOA';
            gv_debug_message   := 'Main Procedure';
            insert_debug (gv_debug_text, gv_debug_message);
        ELSE
            l_source           := 'EBS';
            ln_request_id      := gn_request_id;
            gv_debug_text      := 'The Program called by EBS';
            gv_debug_message   := 'Main Procedure';
            insert_debug (gv_debug_text, gv_debug_message);
        END IF;

        /*-- commenting as part of 2.1.1
                BEGIN
                    DELETE xxd_wms_ship_confirm_t
                     WHERE creation_date <= SYSDATE - 30;

                    COMMIT;

                    IF l_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '30 Days Older Records Purge Count = ' || SQL%ROWCOUNT);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
          -- commenting as part of 2.1.1 */

        IF l_source = 'EBS'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Main Program starts here');
        END IF;

        -- Print the parameters in debug table
        gv_debug_text      :=
               'Input Parameters Are: p_bol_number:'
            || p_bol_number
            || ' and container:'
            || p_container
            || ' and delivery_number:'                         --Added for 2.3
            || p_delivery_number                               --Added for 2.3
            || ' and triggering_event:'                        --Added for 2.1
            || p_triggering_event                              --Added for 2.1
            || ' and p_user_account:'
            || p_user_account;

        IF l_source = 'EBS'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Input Parameters Are: p_bol_number:'
                || p_bol_number
                || ' and container:'
                || p_container
                || ' and delivery_number:'                     --Added for 2.3
                || p_delivery_number                           --Added for 2.3
                || ' and triggering_event:'                    --Added for 2.1
                || p_triggering_event                          --Added for 2.1
                || ' and p_user_account:'
                || p_user_account);
        END IF;

        gv_debug_message   := 'Main Procedure';
        insert_debug (gv_debug_text, gv_debug_message);

        -- Validation1: Parameters should not be null - If SOA calls Oracle API with only one parameter then fail.
        IF l_source = 'SOA'
        THEN
            IF    p_bol_number IS NULL
               OR p_container IS NULL
               OR p_user_account IS NULL
               OR p_triggering_event IS NULL                   --Added for 2.1
            THEN
                gv_debug_text      :=
                    'All the 4 parameters are Mandatory, Parameter value should not be null';
                gv_debug_message   := 'Main Procedure';
                insert_debug (gv_debug_text, gv_debug_message);
                retcode            := 1;
                errbuf             :=
                    'All the 4 parameters are Mandatory, Parameter value should not be null';
                RETURN;
            END IF;
        END IF;

        -- Priting output headings
        IF l_source = 'EBS'
        THEN
            --Start Added for 2.1
            FOR i IN open_pick_tickets
            LOOP
                l_out_header_count   := l_out_header_count + 1;
            END LOOP;

            IF NVL (l_out_header_count, 0) > 0
            THEN
                --End Added for 2.1
                fnd_file.put_line (
                    fnd_file.output,
                    'Deckers WMS Direct Ship Order Invoice Program');
                fnd_file.put_line (
                    fnd_file.output,
                    '----------------------------------------------');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('Delivery id', 20)
                    || RPAD ('Bol Number', 30)
                    || RPAD ('Container Number', 30)
                    || RPAD ('Order Number', 20)
                    || RPAD ('Account Number', 25)
                    || RPAD ('Shipment Number', 50)
                    || RPAD ('Creation Date', 20)
                    || RPAD ('Shipment Status', 20));

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('-----------', 20)
                    || RPAD ('----------', 30)
                    || RPAD ('----------------', 30)
                    || RPAD ('------------', 20)
                    || RPAD ('--------------', 25)
                    || RPAD ('---------------', 50)
                    || RPAD ('-------------', 20)
                    || RPAD ('---------------', 20));
            END IF;                                            --Added for 2.1
        END IF;

        -- Get the user details
        -- Start changes for CCR0008125
        /*BEGIN
            BEGIN
                SELECT fnd_profile.VALUE ('USER_ID')
                  INTO gn_created_by
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gn_created_by := -1;
            END;

            IF NVL (gn_created_by, -1) = -1
            THEN*/
        -- End changes for CCR0008125
        BEGIN
            SELECT user_id
              INTO gn_created_by
              FROM fnd_user
             WHERE user_name = p_user_account;
        EXCEPTION
            WHEN OTHERS
            THEN
                IF l_source = 'EBS'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'No user exist in EBS with the user name provided for user:'
                        || p_user_account
                        || '-'
                        || SQLERRM);
                END IF;

                gv_debug_text      :=
                       'No user exist in EBS with the user name provided for user:'
                    || p_user_account
                    || '-'
                    || SQLERRM;
                gv_debug_message   := 'Main Procedure';
                insert_debug (gv_debug_text, gv_debug_message);
                retcode            := 1;
                errbuf             :=
                    'No user exist in EBS with the user name provided for user:';
                RETURN;
        END;

        IF l_source = 'EBS'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'gn_created_by : '
                || gn_created_by
                || ' for user_account :'
                || p_user_account);
        END IF;

        -- Start changes for CCR0008125
        --END IF;
        --END;
        -- End changes for CCR0008125

        -- Validation to check the user has shipping grants or not'
        /*Commented as part of 2.1.1
        BEGIN
            BEGIN                                              --Added for 2.1
                SELECT COUNT (d.user_name)
                  INTO l_ship_grant
                  FROM wsh_roles            a,
                       wsh_role_privileges  b,
                       wsh_grants           c,
                       fnd_user             d
                 WHERE     a.role_id = b.role_id
                       AND b.role_id = c.role_id
                       AND c.user_id = d.user_id
                       AND b.privilege_code = 'DLVY_SHIP_CONFIRM'
                       AND c.end_date IS NULL
                       AND d.user_id = gn_created_by
                       AND c.organization_id =
                           (SELECT organization_id
                              FROM mtl_parameters
                             WHERE organization_code = 'USX');
            --Start Added for 2.1
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ship_grant := -1;
            END;

            --End Added for 2.1

            IF l_ship_grant = 0
            THEN
                IF l_source = 'EBS'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Shipping Grants are not exist to this user'
                        || gn_created_by);
                END IF;

                gv_debug_text :=
                       'Shipping Grants are not exist to this user'
                    || gn_created_by;
                gv_debug_message := 'Main Procedure';
                insert_debug (gv_debug_text, gv_debug_message);
                retcode := 2;
                errbuf :=
                       'Shipping Grants are not exist to this user: '
                    || gn_created_by;
                RETURN;
            END IF;
        END;
   Commented as part of 2.1.1 */

        FOR i IN open_pick_tickets
        LOOP
            l_cursor_count   := l_cursor_count + 1;


            ---Shipping Grants
            BEGIN                                              --Added for 2.1
                SELECT COUNT (d.user_name)
                  INTO l_ship_grant
                  FROM wsh_roles a, wsh_role_privileges b, wsh_grants c,
                       fnd_user d
                 WHERE     a.role_id = b.role_id
                       AND b.role_id = c.role_id
                       AND c.user_id = d.user_id
                       AND b.privilege_code = 'DLVY_SHIP_CONFIRM'
                       AND d.user_id = gn_created_by
                       --Start Changes for 2.3
                       -- AND c.end_date IS NULL
                       -- AND c.organization_id = i.organization_id
                       AND SYSDATE BETWEEN NVL (c.start_date, SYSDATE)
                                       AND NVL (c.end_date, SYSDATE + 1)
                       AND NVL (c.organization_id, i.organization_id) =
                           i.organization_id;
            --End Changes for 2.3
            --Start Added for 2.1
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ship_grant   := -1;
            END;

            --End Added for 2.1

            -- Start W.r.t Version 2.2
            IF l_ship_grant = 0
            THEN
                IF l_source = 'EBS'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Shipping Grants are not exist to this user '
                        || gn_created_by
                        || ' for the delivery : '
                        || i.delivery_id);
                END IF;

                gv_debug_text      :=
                       'Shipping Grants are not exist to this user'
                    || gn_created_by
                    || ' for the delivery : '
                    || i.delivery_id;
                gv_debug_message   := 'Main Procedure';
                insert_debug (gv_debug_text, gv_debug_message);
                retcode            := 1;
                errbuf             :=
                       'Shipping Grants are not exist to this user: '
                    || gn_created_by;
                GOTO NEXT_RECORD;
            END IF;

            --Shipping Grants Ends 2.2

            -- Before inserting into the table verify the delivery_id is exist or not, if exist remove shipment_status and error message
            BEGIN
                SELECT COUNT (1)
                  INTO l_delivery_exist_count
                  FROM xxdo.xxd_wms_ship_confirm_t
                 WHERE delivery_id = i.delivery_id AND shipment_status <> 'S';

                IF NVL (l_delivery_exist_count, 0) = 1
                THEN
                    IF l_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Delivery Id is exist with error status, removed shipment status and error message'
                            || i.delivery_id);
                    END IF;

                    gv_debug_text      :=
                           'Delivery Id is exist with error status, removed shipment status and error message'
                        || i.delivery_id;
                    gv_debug_message   := 'Main Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    BEGIN
                        UPDATE xxdo.xxd_wms_ship_confirm_t
                           SET shipment_status = NULL, error_message = NULL, last_updated_by = gn_created_by,
                               last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id      --Added for 2.1
                         WHERE delivery_id = i.delivery_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            gv_debug_text      :=
                                   'Updating the custom table failed for delivery_id:'
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            gv_debug_message   := 'Main Procedure';
                            insert_debug (gv_debug_text, gv_debug_message);

                            IF l_source = 'EBS'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the custom table failed for delivery_id: '
                                    || i.delivery_id
                                    || '-'
                                    || SQLERRM);
                            END IF;
                    END;
                ELSE
                    BEGIN
                        SELECT organization_code
                          INTO lv_organization_code
                          FROM mtl_parameters
                         WHERE organization_id = i.organization_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_organization_code   := NULL;
                    END;

                    -- Insert the cursor data in custom table
                    BEGIN
                        INSERT INTO xxdo.xxd_wms_ship_confirm_t (
                                        delivery_id,
                                        bill_of_lading,
                                        container_number,
                                        order_number,
                                        account_number,
                                        shipment_number,
                                        request_id,            --Added for 2.1
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        organizaiton_code,
                                        milestone_event        --Added for 2.2
                                                       )
                             VALUES (i.delivery_id, i.bill_of_lading, i.container_ref, i.order_number, i.account_number, i.attribute8, ln_request_id, -- gn_request_id,            --Added for 2.1
                                                                                                                                                      gn_created_by, SYSDATE, gn_created_by, SYSDATE, lv_organization_code
                                     , p_triggering_event      --Added for 2.2
                                                         );

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            IF l_source = 'EBS'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Inserting data into custom table failed for delivery_id:'
                                    || i.delivery_id
                                    || '-'
                                    || SQLERRM);
                            END IF;

                            gv_debug_text      :=
                                   'Inserting data into custom table failed for delivery_id:'
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            gv_debug_message   := 'Main Procedure';
                            insert_debug (gv_debug_text, gv_debug_message);
                            retcode            := 1;
                            errbuf             :=
                                   'Inserting data into custom table failed for delivery_id: '
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            EXIT;
                    END;
                END IF;
            END;

            -- Calling Validation PROCEDURE
            validations_prc (l_errbuf, l_retcode, p_bol_number,
                             p_container, i.delivery_id, p_user_account,
                             l_source);

            IF l_retcode = 1
            THEN
                retcode   := 1;
                errbuf    := l_errbuf;
                RETURN;
                EXIT;
            END IF;

            -- Calling Ship Confirm PROCEDURE
            ship_confirm_prc (i.delivery_id, l_source, l_ship_status);

            -- Printing the output for successfull shipments
            IF l_ship_status = 'S'
            THEN
                IF l_source = 'EBS'
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (i.delivery_id, 20)
                        || RPAD (i.bill_of_lading, 30)
                        || RPAD (i.container_ref, 30)
                        || RPAD (i.order_number, 20)
                        || RPAD (i.account_number, 25)
                        || RPAD (i.attribute8, 50)
                        || RPAD (SYSDATE, 20)
                        || RPAD ('Success', 20));
                END IF;

                -- Calling interface_all_wrp API.
                BEGIN
                    wsh_ship_confirm_actions.interface_all_wrp (
                        errbuf          => l_chr_errbuf,
                        retcode         => l_chr_ret_code,
                        p_mode          => 'ALL',
                        p_delivery_id   => i.delivery_id);
                    COMMIT;

                    gv_debug_text      :=
                           'l_chr_errbuf is:'
                        || l_chr_errbuf
                        || ',l_chr_ret_code is:'
                        || l_chr_ret_code
                        || ',for delivery:'
                        || i.delivery_id
                        || ',error:'
                        || SQLERRM;
                    gv_debug_message   := 'Main Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF l_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_chr_errbuf is:'
                            || l_chr_errbuf
                            || ',l_chr_ret_code is:'
                            || l_chr_ret_code
                            || ',for delivery:'
                            || i.delivery_id
                            || ',error:'
                            || SQLERRM);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gv_debug_text      :=
                               'l_chr_errbuf is:'
                            || l_chr_errbuf
                            || ',l_chr_ret_code is:'
                            || l_chr_ret_code
                            || ',for delivery:'
                            || i.delivery_id
                            || ',error:'
                            || SQLERRM;
                        gv_debug_message   := 'Main Procedure';
                        insert_debug (gv_debug_text, gv_debug_message);

                        IF l_source = 'EBS'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_chr_errbuf is:'
                                || l_chr_errbuf
                                || ',l_chr_ret_code is:'
                                || l_chr_ret_code
                                || ',for delivery:'
                                || i.delivery_id
                                || ',error:'
                                || SQLERRM);
                        END IF;
                END;

                IF l_chr_ret_code = 0
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_wms_ship_confirm_t
                           SET shipment_status = 'S', last_updated_by = gn_created_by, last_update_date = SYSDATE,
                               request_id = ln_request_id --gn_request_id      --Added for 2.1
                         WHERE delivery_id = i.delivery_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            gv_debug_text   :=
                                   'Updating the custom table failed for delivery:'
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            gv_debug_message   :=
                                'ship_confirm_prc Procedure';
                            insert_debug (gv_debug_text, gv_debug_message);

                            IF l_source = 'EBS'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the custom table failed for delivery:'
                                    || i.delivery_id
                                    || '-'
                                    || SQLERRM);
                            END IF;
                    END;

                    -- Updating split lines line id in Rcv_shipment_lines attribute3 for delivery_id
                    BEGIN
                        UPDATE rcv_shipment_lines rsl
                           SET attribute3        =
                                   NVL (
                                       (SELECT DISTINCT oola.line_id
                                          FROM oe_order_lines_all oola, oe_order_lines_all oola1, wsh_delivery_details wdd,
                                               wsh_delivery_assignments wda
                                         WHERE     1 = 1
                                               AND rsl.item_id =
                                                   oola1.inventory_item_id
                                               AND rsl.attribute3 =
                                                   oola1.line_id
                                               AND oola.split_from_line_id =
                                                   oola1.line_id
                                               AND oola.line_number =
                                                   oola1.line_number
                                               AND oola.header_id =
                                                   oola1.header_id
                                               AND oola1.line_id =
                                                   wdd.source_line_id
                                               AND wdd.delivery_detail_id =
                                                   wda.delivery_detail_id
                                               AND wda.delivery_id =
                                                   i.delivery_id),
                                       attribute3),
                               last_update_date   = SYSDATE,
                               last_updated_by    = gn_created_by
                         WHERE rsl.shipment_line_id IN
                                   (SELECT DISTINCT rsl1.shipment_line_id
                                      FROM rcv_shipment_lines rsl1, rcv_shipment_headers rsh, oe_order_lines_all oola,
                                           wsh_delivery_details wdd, wsh_delivery_assignments wda, wsh_new_deliveries wnd
                                     WHERE     rsl1.attribute3 =
                                               oola.split_from_line_id
                                           AND oola.split_from_line_id =
                                               wdd.source_line_id
                                           AND oola.inventory_item_id =
                                               wdd.inventory_item_id
                                           AND wda.delivery_detail_id =
                                               wdd.delivery_detail_id
                                           AND wnd.delivery_id =
                                               wda.delivery_id
                                           AND rsl1.shipment_header_id =
                                               rsh.shipment_header_id
                                           AND rsh.shipment_num !=
                                               wnd.attribute8
                                           AND wnd.delivery_id =
                                               i.delivery_id);

                        COMMIT;
                        gv_debug_text      :=
                               'shipment line attribute3 updated for the delivery:'
                            || i.delivery_id;
                        gv_debug_message   := 'Main Procedure';
                        insert_debug (gv_debug_text, gv_debug_message);

                        IF l_source = 'EBS'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'shipment line attribute3 updated for the delivery:'
                                || i.delivery_id);
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            gv_debug_text      :=
                                   'No Split lines found for the delivery:'
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            gv_debug_message   := 'Main Procedure';
                            insert_debug (gv_debug_text, gv_debug_message);

                            IF l_source = 'EBS'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Split lines found for the delivery:'
                                    || i.delivery_id
                                    || '-'
                                    || SQLERRM);
                            END IF;
                        WHEN OTHERS
                        THEN
                            IF l_source = 'EBS'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'shipment line attribute3 updation failed for the delivery:'
                                    || i.delivery_id
                                    || '-'
                                    || SQLERRM);
                            END IF;

                            gv_debug_text      :=
                                   'shipment line attribute3 updation failed for the delivery:'
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            gv_debug_message   := 'Main Procedure';
                            insert_debug (gv_debug_text, gv_debug_message);
                    END;
                ELSE                                    -- l_chr_ret_code <> 0
                    gv_debug_text      :=
                        'Interface trip stop is Failed. So skipped the RSL.attribute3 updation';
                    gv_debug_message   := 'Main Procedure';
                    insert_debug (gv_debug_text, gv_debug_message);

                    IF l_source = 'EBS'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Interface trip stop is Failed. So skipped the RSL.attribute3 updation');
                    END IF;

                    BEGIN
                        l_sqlerrm   := SQLERRM;

                        UPDATE xxdo.xxd_wms_ship_confirm_t
                           SET shipment_status = 'E', error_message = 'l_chr_errbuf is:' || l_chr_errbuf || ',l_chr_ret_code is:' || l_chr_ret_code || ',for delivery:' || i.delivery_id || ',error:' || l_sqlerrm, last_updated_by = gn_created_by,
                               last_update_date = SYSDATE, request_id = ln_request_id --gn_request_id      --Added for 2.1
                         WHERE delivery_id = i.delivery_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            gv_debug_text      :=
                                   'Updating the custom table failed for delivery:'
                                || i.delivery_id
                                || '-'
                                || SQLERRM;
                            gv_debug_message   := 'Main Procedure';
                            insert_debug (gv_debug_text, gv_debug_message);

                            IF l_source = 'EBS'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the custom table failed for delivery:'
                                    || i.delivery_id
                                    || '-'
                                    || SQLERRM);
                            END IF;
                    END;
                END IF;                                  -- l_chr_ret_code = 0
            END IF;

           <<NEXT_RECORD>>
            NULL;
        END LOOP;

        IF l_cursor_count = 0
        THEN
            gv_debug_text      :=
                   'No Pick Ticket exist for bol_number: '
                || p_bol_number
                || ' and container: '
                || p_container
                || ' and delivery_number: '                    --Added for 2.3
                || p_delivery_number                           --Added for 2.3
                || ' and triggering_event:'                    --Added for 2.1
                || p_triggering_event;                         --Added for 2.1
            fnd_file.put_line (fnd_file.LOG,
                               'l_cursor_count = 0 :' || gv_debug_text);

            --Start changes for 2.3
            --Validate Input Parameters combinations (BOL\Container\Delivery)
            lv_bol_result      :=
                validate_err_inputs (p_bol_number => p_bol_number);

            lv_cont_result     :=
                validate_err_inputs (p_container => p_container);

            lv_del_result      :=
                validate_err_inputs (p_delivery_number => p_delivery_number);

            IF NVL (lv_bol_result, 'N') = 'E'
            THEN
                lv_input_param_error   :=
                       'Unable to progress the input combinations due to Invalid BOL Number :'
                    || p_bol_number;
            ELSIF NVL (lv_cont_result, 'N') = 'E'
            THEN
                lv_input_param_error   :=
                       'Unable to progress the input combinations due to Invalid Container :'
                    || p_container;
            ELSIF NVL (lv_del_result, 'N') = 'E'
            THEN
                lv_input_param_error   :=
                       'Unable to progress the input combinations due to Invalid Delivery :'
                    || p_delivery_number;
            ELSE
                lv_input_param_error   :=
                       'Unable to progress the input combinations due to Invalid Milestone Event :'
                    || p_triggering_event;
            END IF;

            gv_debug_text      := lv_input_param_error;

            --End changes for 2.3

            --added w.r.t to 2.2
            INSERT INTO xxdo.xxd_wms_ship_confirm_t (delivery_id,
                                                     bill_of_lading,
                                                     container_number,
                                                     order_number,
                                                     account_number,
                                                     shipment_number,
                                                     request_id,
                                                     created_by,
                                                     creation_date,
                                                     last_updated_by,
                                                     last_update_date,
                                                     organizaiton_code,
                                                     milestone_event,
                                                     shipment_status,
                                                     error_message)
                 VALUES (p_delivery_number, --Added for 2.3   --NULL,   --Commented for 2.3
                                            p_bol_number, p_container,
                         NULL, NULL, NULL,
                         ln_request_id, -- gn_request_id,            --Added for 2.1
                                        gn_created_by, SYSDATE,
                         gn_created_by, SYSDATE, NULL,
                         p_triggering_event, 'E', -- 'No Delivery found for given Inputs');   --Commented for 2.3
                                                  lv_input_param_error);

            --ended w.r.t to 2.2

            COMMIT;

            IF l_source = 'EBS'
            THEN
                fnd_file.put_line (fnd_file.LOG, gv_debug_text);
                --Start Added for 2.1
                fnd_file.put_line (
                    fnd_file.LOG,
                    '                                                         ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    '---------------------------------------------------------');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No deliveries identified for the given Input parameter combinations.');
                fnd_file.put_line (fnd_file.LOG, lv_input_param_error);
                fnd_file.put_line (
                    fnd_file.LOG,
                    '---------------------------------------------------------');

                --OUTPUT Message if nothing fetch for Input parameters
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    '                                                         ');
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    '---------------------------------------------------------');
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    'No deliveries identified for the given Input parameters.');
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    '---------------------------------------------------------');
            --End Added for 2.1
            END IF;

            gv_debug_message   := 'Main Procedure';
            insert_debug (gv_debug_text, gv_debug_message);
            errbuf             := gv_debug_text;
            --retcode := 2;                                    --Commented for 2.1
            RETURN;
        ELSE                                                   --Added for 2.1
            --Calling Email procedure
            ship_confirm_email_out (ln_request_id);
        END IF;
    END main;

    -- begin ver 2.0

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================

    PROCEDURE write_log (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in write_log = ' || SQLERRM);
    END write_log;

    PROCEDURE write_out (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.output, p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Others Exception in write_output = ' || SQLERRM);
    END write_out;

    PROCEDURE update_delivery_attrs (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_event_name IN VARCHAR2
                                     , p_order_number IN NUMBER, p_container_number IN VARCHAR2, p_delivery_number IN NUMBER) --Added for 2.3
    AS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        l_delimiter         VARCHAR2 (1) := '~';

        CURSOR get_deliveries IS
            -- for us7
            SELECT delivery_data.container_number, delivery_data.order_number, delivery_data.cust_po_number,
                   delivery_data.old_triggering_event_name, delivery_data.delivery_id, new_triggering_event_name,
                   line_data, delivery_data.created_by, delivery_data.creation_date,
                   delivery_data.last_update_date, delivery_data.last_updated_by
              FROM (SELECT wnd.attribute9 container_number, ooha.order_number, cust_po_number,
                           wnd.attribute7 old_triggering_event_name, wnd.delivery_id, p_event_name new_triggering_event_name,
                           fnd_global.user_id created_by, SYSDATE creation_date, SYSDATE last_update_date,
                           fnd_global.user_id last_updated_by, (wnd.attribute9 || l_delimiter || ooha.order_number || l_delimiter || cust_po_number || l_delimiter || wnd.delivery_id || l_delimiter || wnd.attribute7 || l_delimiter || p_event_name || l_delimiter || fnd_global.user_name || l_delimiter || SYSDATE) line_data
                      FROM apps.oe_order_headers_all ooha, apps.wsh_new_deliveries wnd
                     WHERE     ooha.header_id = wnd.source_header_id
                           AND ooha.sold_to_org_id = wnd.customer_id
                           AND wnd.attribute9 =
                               NVL (p_container_number, wnd.attribute9)
                           AND order_number =
                               NVL (p_order_number, order_number)
                           --Start Added for 2.3
                           AND wnd.delivery_id =
                               NVL (p_delivery_number, wnd.delivery_id)
                           --End Added for 2.3
                           AND ooha.open_flag = 'Y'
                           AND wnd.status_code = 'OP'
                           AND (   ooha.order_type_id =
                                   (SELECT transaction_type_id
                                      FROM apps.oe_transaction_types_tl ottl
                                     WHERE     ottl.name =
                                               'Direct Ship OriginHub-US'
                                           AND ottl.language =
                                               USERENV ('LANG'))
                                OR ooha.ship_from_org_id IN
                                       (SELECT organization_id
                                          FROM fnd_lookup_values A, MTL_PARAMETERS b
                                         WHERE     1 = 1
                                               AND lookup_type =
                                                   'XXD_ODC_ORG_CODE_LKP'
                                               AND enabled_flag = 'Y'
                                               AND a.lookup_code =
                                                   b.organization_code
                                               AND language =
                                                   USERENV ('LANG')
                                               AND SYSDATE BETWEEN start_date_active
                                                               AND NVL (
                                                                       end_date_active,
                                                                         SYSDATE
                                                                       + 1)))
                    /* AND EXISTS
                             (SELECT NULL
                                FROM apps.wsh_delivery_details      wdd,
                                     apps.wsh_delivery_assignments  wda
                               WHERE     wdd.delivery_detail_id =
                                         wda.delivery_detail_id
                                     AND wda.delivery_id = wnd.delivery_id
                                     AND wdd.source_header_id = ooha.header_id
                                     AND wdd.released_status <> 'C')  */
                    UNION
                    -- for usx
                    SELECT ship.container_ref container_number, ooha.order_number, cust_po_number,
                           wnd.attribute7 old_triggering_event_name, wnd.delivery_id, p_event_name new_triggering_event_name,
                           fnd_global.user_id created_by, SYSDATE creation_date, SYSDATE last_update_date,
                           fnd_global.user_id last_updated_by, (ship.container_ref || l_delimiter || ooha.order_number || l_delimiter || cust_po_number || l_delimiter || wnd.delivery_id || l_delimiter || wnd.attribute7 || l_delimiter || p_event_name || l_delimiter || fnd_global.user_name || l_delimiter || SYSDATE) line_data
                      FROM apps.oe_order_headers_all ooha,
                           apps.wsh_new_deliveries wnd,
                           (SELECT DISTINCT s.asn_reference_no, s.vessel_name, s.etd,
                                            s.bill_of_lading, c.container_ref, i.atr_number
                              FROM custom.do_shipments s, custom.do_containers c, custom.do_items i
                             WHERE     s.shipment_id = c.shipment_id
                                   AND c.container_id = i.container_id) ship
                     WHERE     ooha.header_id = wnd.source_header_id
                           AND ooha.sold_to_org_id = wnd.customer_id
                           AND wnd.attribute8 = ship.atr_number
                           AND ooha.open_flag = 'Y'
                           AND wnd.status_code = 'OP'
                           AND order_number =
                               NVL (p_order_number, order_number)
                           AND ship.container_ref =
                               NVL (p_container_number, ship.container_ref)
                           --Start Added for 2.3
                           AND wnd.delivery_id =
                               NVL (p_delivery_number, wnd.delivery_id)
                           --End Added for 2.3
                           AND (ooha.order_type_id =
                                (SELECT transaction_type_id
                                   FROM apps.oe_transaction_types_tl ottl
                                  WHERE     ottl.name = 'Direct Ship - US'
                                        AND ottl.language = USERENV ('LANG'))) /*  AND EXISTS
                                                                                         (SELECT NULL
                                                                                            FROM apps.wsh_delivery_details      wdd,
                                                                                                 apps.wsh_delivery_assignments  wda
                                                                                           WHERE     wdd.delivery_detail_id =
                                                                                                     wda.delivery_detail_id
                                                                                                -- AND wda.delivery_id = wnd.delivery_id
                                                                                                -- AND wdd.source_header_id = ooha.header_id
                                                                                                 AND wdd.attribute8 = ship.atr_number
                                                                                                 AND wdd.released_status <> 'C') */
                                                                              )
                   delivery_data,
                   apps.wsh_new_deliveries wnd1
             WHERE     1 = 1
                   AND wnd1.delivery_id = delivery_data.delivery_id
                   AND wnd1.status_code = 'OP';

        TYPE xxd_delivery_typ IS TABLE OF get_deliveries%ROWTYPE;

        TYPE type_email_data IS TABLE OF xxdo.xxd_wms_email_output_t%ROWTYPE;

        v_type_email_data   xxd_wms_email_output_type
                                := xxd_wms_email_output_type ();

        v_ins_type          xxd_delivery_typ := xxd_delivery_typ ();
        v_ins_type_1        xxd_delivery_typ := xxd_delivery_typ ();
        l_flag              VARCHAR2 (1) := 'N';
        l_index             NUMBER := 0;
        l_header            VARCHAR2 (1000)
            := 'Container Number~Order Number~Cust PO Number~Delivery~Triggering Event OLd Value~Triggering Event new value~Program Ran By~Program Run date/time';
        l_data              VARCHAR2 (4000) := NULL;
    BEGIN
        -- either of the parameter is mandaotry for the query
        IF    p_container_number IS NOT NULL
           OR p_order_number IS NOT NULL
           OR p_delivery_number IS NOT NULL                    --Added for 2.3
        THEN
            write_out (l_header);

            OPEN get_deliveries;

            LOOP
                FETCH get_deliveries BULK COLLECT INTO v_ins_type LIMIT 1000;


                IF (v_ins_type.COUNT > 0)
                THEN
                    l_flag   := 'Y';

                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            UPDATE wsh_new_deliveries
                               SET attribute7 = v_ins_type (i).new_triggering_event_name, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                             WHERE delivery_id = v_ins_type (i).delivery_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While updating deliveries' || v_ins_type (ln_error_num).delivery_id || lv_error_code || ' #'),
                                        1,
                                        4000);
                                write_log (
                                       ln_error_num
                                    || lv_error_code
                                    || lv_error_msg);
                            END LOOP;
                    END;
                ELSE
                    write_log ('cursor query couldnt fetched anything.');
                END IF;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR i IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        l_index   := l_index + 1;

                        v_type_email_data (l_index).container_number   :=
                            v_ins_type (i).container_number;
                        v_type_email_data (l_index).order_number   :=
                            v_ins_type (i).order_number;
                        v_type_email_data (l_index).delivery_id   :=
                            v_ins_type (i).delivery_id;
                        v_type_email_data (l_index).cust_po_number   :=
                            v_ins_type (i).cust_po_number;
                        v_type_email_data (l_index).old_triggering_event_name   :=
                            v_ins_type (i).old_triggering_event_name;
                        v_type_email_data (l_index).new_triggering_event_name   :=
                            v_ins_type (i).new_triggering_event_name;
                        v_type_email_data (l_index).created_by   :=
                            v_ins_type (i).created_by;
                        v_type_email_data (l_index).request_id   :=
                            gn_request_id;
                        v_type_email_data (l_index).creation_date   :=
                            v_ins_type (i).creation_date;
                        v_type_email_data (l_index).last_update_date   :=
                            v_ins_type (i).last_update_date;
                        v_type_email_data (l_index).last_updated_by   :=
                            v_ins_type (i).last_updated_by;

                        write_out (v_ins_type (i).line_data);
                    END LOOP;

                    insert_into_email_table (v_type_email_data);
                END IF;

                EXIT WHEN get_deliveries%NOTFOUND;
            END LOOP;

            CLOSE get_deliveries;
        ELSE
            write_log ('Either of the parameter is mandatory.');
        END IF;

        IF l_flag = 'N'   -- L_FLAG IS n MEANS NO RECORD FETEHED IN THE CURSOR
        THEN
            write_out ('***No Deliveries Identified for update***');
        END IF;

        email_output (gn_request_id);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END update_delivery_attrs;

    FUNCTION email_recipients (p_request_id NUMBER, p_called_from VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;

        CURSOR recipients_cur IS
            SELECT b.email_address email_id
              FROM wsh_grants_v a, fnd_user b
             WHERE     1 = 1
                   -- AND organization_code = 'USX'
                   AND role_name = 'Upgrade Role'
                   AND a.user_name = b.user_name
                   AND SYSDATE BETWEEN a.start_date
                                   AND NVL (a.end_date, SYSDATE + 1)
                   AND email_address IS NOT NULL
                   AND 'EVENTUPDATE' = p_called_from
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_wms_email_output_t c, apps.wsh_new_deliveries d
                             WHERE     c.request_id = p_request_id
                                   AND c.delivery_id = d.delivery_id
                                   AND a.organization_id = d.organization_id)
            UNION ALL
            SELECT b.email_address email_id
              FROM wsh_grants_v a, fnd_user b
             WHERE     1 = 1
                   -- AND organization_code = 'USX'
                   AND role_name = 'Upgrade Role'
                   AND a.user_name = b.user_name
                   AND SYSDATE BETWEEN a.start_date
                                   AND NVL (a.end_date, SYSDATE + 1)
                   AND email_address IS NOT NULL
                   AND 'CONTAINERCLOSE' = p_called_from
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_wms_ship_confirm_t c, apps.wsh_new_deliveries d
                             WHERE     c.request_id = p_request_id
                                   AND c.delivery_id = d.delivery_id
                                   AND a.organization_id = d.organization_id);
    BEGIN
        lv_def_mail_recips.delete;

        SELECT applications_system_name
          INTO lv_appl_inst_name
          FROM apps.fnd_product_groups;

        IF lv_appl_inst_name IN ('EBSPROD')
        THEN
            FOR recipients_rec IN recipients_cur
            LOOP
                lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                    recipients_rec.email_id;
            END LOOP;
        ELSE
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'BTAppsNotification@deckers.com'; -- 'aravind.kannuri@deckers.com';
        END IF;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
            RETURN lv_def_mail_recips;
    END email_recipients;

    PROCEDURE email_output (p_request_id NUMBER)
    IS
        CURSOR report_cur IS
            SELECT container_number, order_number, cust_po_number,
                   delivery_id, old_triggering_event_name, new_triggering_event_name,
                   creation_date, fnd_global.user_name user_name
              FROM xxdo.xxd_wms_email_output_t
             WHERE request_id = p_request_id;


        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        -- lv_email_lkp_type    VARCHAR2 (50) := 'XXD_NEG_ATP_RESCHEDULE_EMAIL';
        lv_inv_org_code      VARCHAR2 (3) := NULL;
        ln_ret_val           NUMBER := 0;
        lv_out_line          VARCHAR2 (1000);
        ln_counter           NUMBER := 0;
        ln_rec_cnt           NUMBER := 0;

        ex_no_sender         EXCEPTION;
        ex_no_recips         EXCEPTION;
    BEGIN
        --Getting the email recipients and assigning them to a table type variable
        lv_def_mail_recips   :=
            email_recipients (p_request_id, 'EVENTUPDATE');

        IF lv_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        ELSE
            --Getting the instance name
            BEGIN
                SELECT applications_system_name
                  INTO lv_appl_inst_name
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Unable to fetch the File server name in email_output procedure');
            END;

            --CCR0009753
            apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Deckers DirectShip Invoice Event Update ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                 , ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line ('', ln_ret_val);


            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'See attachment for report details.',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers DirectShip Invoice Event Update Report output '
                || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24MISS')
                || '.xls"',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line (
                   'Container Number'
                || CHR (9)
                || 'Order Number'
                || CHR (9)
                || 'Cust PO Number'
                || CHR (9)
                || 'Delivery'
                || CHR (9)
                || 'Triggering Event OLd Value'
                || CHR (9)
                || 'Triggering Event new value'
                || CHR (9)
                || 'Program Ran By'
                || CHR (9)
                || 'Program Run date/time',
                ln_ret_val);

            FOR report_rec IN report_cur
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       report_rec.container_number
                    || CHR (9)
                    || report_rec.order_number
                    || CHR (9)
                    || report_rec.cust_po_number
                    || CHR (9)
                    || report_rec.delivery_id
                    || CHR (9)
                    || report_rec.old_triggering_event_name
                    || CHR (9)
                    || report_rec.new_triggering_event_name
                    || CHR (9)
                    || report_rec.user_name
                    || CHR (9)
                    || TO_CHAR (report_rec.creation_date,
                                'DD-MON-YYYY HH24:MI:SS AM')
                    || CHR (9);

                apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
                ln_counter    := ln_counter + 1;
            END LOOP;

            write_log ('Final ln_ret_val : ' || ln_ret_val);

            apps.do_mail_utils.send_mail_close (ln_ret_val);
        END IF;
    EXCEPTION
        WHEN ex_no_sender
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_sender : There is no sender configured. Check the profile value DO: Default Alert Sender');
        WHEN ex_no_recips
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_recips : There are no recipients configured to receive the email. Check lookup for email id');
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log ('Error in Procedure email_ouput -> ' || SQLERRM);
    END email_output;

    -- end ver 2.0

    --Start Added for 2.1
    PROCEDURE ship_confirm_email_out (p_request_id IN NUMBER)
    IS
        CURSOR report_cur IS
            SELECT delivery_id, bill_of_lading, container_number,
                   order_number, account_number, shipment_number,
                   created_by, creation_date, last_updated_by,
                   last_update_date, fnd_global.user_name user_name
              FROM xxdo.xxd_wms_ship_confirm_t
             WHERE 1 = 1 AND request_id = p_request_id;


        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        lv_inv_org_code      VARCHAR2 (3) := NULL;
        ln_ret_val           NUMBER := 0;
        lv_out_line          VARCHAR2 (1000);
        ln_counter           NUMBER := 0;
        ln_rec_cnt           NUMBER := 0;

        ex_no_sender         EXCEPTION;
        ex_no_recips         EXCEPTION;
    BEGIN
        --Getting the email recipients and assigning them to a table type variable
        lv_def_mail_recips   :=
            email_recipients (p_request_id, 'CONTAINERCLOSE');

        IF lv_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        ELSE
            --Getting the instance name
            BEGIN
                SELECT applications_system_name
                  INTO lv_appl_inst_name
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Unable to fetch the File server name in ship_confirm_email_out procedure');
            END;

            --CCR0009753
            apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Deckers WMS Direct Ship Order Invoice Program ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                 , ln_ret_val);

            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line ('', ln_ret_val);


            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'See attachment for report details.',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers WMS Direct Ship Order Invoice Output '
                || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24MISS')
                || '.xls"',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line (
                   'Delivery Id'
                || CHR (9)
                || 'Bill Of Lading'
                || CHR (9)
                || 'Container Number'
                || CHR (9)
                || 'Order Number'
                || CHR (9)
                || 'Account Number'
                || CHR (9)
                || 'Shipment Number'
                || CHR (9)
                || 'Program Ran By'
                || CHR (9)
                || 'Program Run date/time',
                ln_ret_val);

            FOR report_rec IN report_cur
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       report_rec.delivery_id
                    || CHR (9)
                    || report_rec.bill_of_lading
                    || CHR (9)
                    || report_rec.container_number
                    || CHR (9)
                    || report_rec.order_number
                    || CHR (9)
                    || report_rec.account_number
                    || CHR (9)
                    || report_rec.shipment_number
                    || CHR (9)
                    || report_rec.user_name
                    || CHR (9)
                    || TO_CHAR (report_rec.creation_date,
                                'DD-MON-YYYY HH24:MI:SS AM')
                    || CHR (9);

                apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
                ln_counter    := ln_counter + 1;
            END LOOP;

            write_log ('Final ln_ret_val : ' || ln_ret_val);

            apps.do_mail_utils.send_mail_close (ln_ret_val);
        END IF;
    EXCEPTION
        WHEN ex_no_sender
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_sender : There is no sender configured. Check the profile value DO: Default Alert Sender');
        WHEN ex_no_recips
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_recips : There are no recipients configured to receive the email. Check lookup for email id');
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log ('Error in Procedure email_ouput -> ' || SQLERRM);
    END ship_confirm_email_out;
--End Added for 2.1
END xxd_wms_direct_shipconf_pkg;
/


GRANT EXECUTE ON APPS.XXD_WMS_DIRECT_SHIPCONF_PKG TO SOA_INT
/
