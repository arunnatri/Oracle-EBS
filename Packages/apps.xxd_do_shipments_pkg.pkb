--
-- XXD_DO_SHIPMENTS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_DO_SHIPMENTS_PKG"
IS
    /************************************************************************
    * Module Name:   xxd_do_shipments_pkg
    * Description:
    * Created By:    BT Technology Team
    * Creation Date: 25-May-2015
    *************************************************************************
    * Version  * Author                * Date             * Change Description
    *************************************************************************
    * 1.0      * BT Technology Team    * 25-May-2015      * Initial version
    * 1.1      * BT Technology Team    * 04-Nov-2015      * Defect 3491
    ************************************************************************/
    CURSOR lcu_do_items_data IS
        SELECT container_id, domestic_overseas_flag, weight_volume_flag,
               pll.ship_to_organization_id organization_id, --ORGANIZATION_ID,
                                                            pol.po_header_id order_id, --ORDER_ID,
                                                                                       order_rec_id,
               pol.po_line_id order_line_id,                  --ORDER_LINE_ID,
                                             pll.line_location_id, item_num,
               item.description, item.quantity, price,
               item.item_id, item.created_by, item.creation_date,
               item.last_updated_by, item.last_update_date, item.last_update_login,
               entered_quantity, received_quantity, calc_freight,
               calc_duty, calc_port_usage, unit_weight,
               unit_volume, pre_freight_cost, post_freight_cost,
               pre_duty_cost, post_duty_cost, atr_number,
               system_received_date, item.promised_date
          FROM xxd_conv.xxd_do_items item, po_lines_all pol, po_line_locations_all pll
         WHERE     1 = 1
               AND pol.attribute15 = item.order_line_id
               AND pol.attribute15 IS NOT NULL
               AND pol.po_line_id = pll.po_line_id;

    CURSOR lcu_do_containers_data IS
        SELECT *
          FROM xxd_conv.xxd_do_containers
         WHERE container_id IN
                   (SELECT container_id
                      FROM (SELECT container_id, ROW_NUMBER () OVER (PARTITION BY container_id ORDER BY container_id) row_num
                              FROM xxd_conv.xxd_do_items items, po_lines_all pol
                             WHERE     order_id IN
                                           (SELECT po_header_id FROM xxd_conv.xxd_po_headers_all)
                                   AND pol.attribute15 IS NOT NULL
                                   AND pol.attribute15 = items.order_line_id
                                   AND TO_CHAR (pol.attribute14) =
                                       TO_CHAR (items.order_id)
                                   AND pol.attribute14 IS NOT NULL)
                     WHERE row_num = 1);

    CURSOR lcu_do_shipments_data IS
        SELECT shipment_id, ship_to_organization_id, vendor_name,
               vendor_code, vendor_id, domestic_overseas_flag,
               weight_volume_flag, bill_of_lading, invoice_num,
               vessel_name, etd, eta,
               remark, LOCATION, ship_to_location_id,
               discharge_port, consignee, document_submit_date,
               obl_charge_date, ocean_freight, customs_release_date,
               duty_due_date, duty, duty_paid,
               last_free_day, status, customs_status,
               customs_entry_number, created_by, creation_date,
               last_updated_by, last_update_date, last_update_login,
               shipment_type, asn_reference_no, ownership_fob_date,
               SOURCE
          FROM (SELECT sh.shipment_id, pll.ship_to_organization_id, sh.vendor_name,
                       sh.vendor_code, poh.vendor_id, sh.domestic_overseas_flag,
                       sh.weight_volume_flag, sh.bill_of_lading, sh.invoice_num,
                       sh.vessel_name, sh.etd, sh.eta,
                       sh.remark, sh.LOCATION, poh.ship_to_location_id,
                       sh.discharge_port, sh.consignee, sh.document_submit_date,
                       sh.obl_charge_date, sh.ocean_freight, sh.customs_release_date,
                       sh.duty_due_date, sh.duty, sh.duty_paid,
                       sh.last_free_day, sh.status, sh.customs_status,
                       sh.customs_entry_number, sh.created_by, sh.creation_date,
                       sh.last_updated_by, sh.last_update_date, sh.last_update_login,
                       sh.shipment_type, sh.asn_reference_no, sh.ownership_fob_date,
                       sh.SOURCE, ROW_NUMBER () OVER (PARTITION BY sh.shipment_id ORDER BY sh.shipment_id) row_num
                  FROM xxd_conv.xxd_do_shipments sh, xxd_conv.xxd_do_containers cont, xxd_conv.xxd_do_items items,
                       po_headers_all poh, xxd_conv.xxd_po_headers_all cpoh, po_lines_all pol,
                       po_line_locations_all pll
                 WHERE     cont.shipment_id = sh.shipment_id
                       AND cont.container_id = items.container_id
                       AND items.order_id = cpoh.po_header_id
                       AND poh.attribute15 IS NOT NULL
                       AND poh.attribute15 = items.order_id
                       AND poh.attribute15 = cpoh.po_header_id
                       AND pol.po_header_id = poh.po_header_id
                       AND pol.attribute15 = items.order_line_id
                       AND pol.attribute14 IS NOT NULL
                       AND pll.po_line_id = pol.po_line_id)
         WHERE row_num = 1;


    CURSOR lcu_do_orders_data IS
        SELECT orders.container_id, orders.order_num, poh.po_header_id order_id,
               order_rec_id, poh.vendor_id, orders.status,
               orders.created_by, orders.creation_date, orders.last_updated_by,
               orders.last_update_date, orders.last_update_login, orders.match_shipped_quantity
          FROM xxd_conv.xxd_do_orders orders, po_headers_all poh
         WHERE     poh.attribute15 = orders.order_id
               AND poh.attribute15 IS NOT NULL;

    --  AND container_id = p_cont_id;

    CURSOR lcu_do_cartons_data IS
        SELECT container_id, pll.ship_to_organization_id organization_id, pol.po_header_id order_id,
               order_rec_id, pol.po_line_id order_line_id, cartons.line_location_id,
               cartons.item_id, cartons.quantity, carton_number,
               cartons.created_by, cartons.creation_date, cartons.last_updated_by,
               cartons.last_update_date, cartons.last_update_login, weight,
               ctn_length, ctn_width, ctn_height
          FROM xxd_conv.xxd_do_cartons cartons, po_lines_all pol, po_line_locations_all pll
         WHERE     1 = 1                  --pol.attribute14 = cartons.order_id
               AND pol.attribute15 = cartons.order_line_id
               AND pol.attribute15 IS NOT NULL
               AND pol.po_line_id = pll.po_line_id;


    TYPE do_items_tab IS TABLE OF custom.do_items%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE do_containers_tab IS TABLE OF custom.do_containers%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE do_shipments_tab IS TABLE OF custom.do_shipments%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE do_cartons_tab IS TABLE OF custom.do_cartons%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE do_orders_tab IS TABLE OF custom.do_orders%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_do_shipments_tab     do_shipments_tab;
    gtt_do_shipments_type    do_shipments_tab;
    gtt_do_containers_tab    do_containers_tab;
    gtt_do_containers_type   do_containers_tab;
    gtt_do_items_tab         do_items_tab;
    gtt_do_items_type        do_items_tab;
    gtt_do_orders_tab        do_orders_tab;
    gtt_do_orders_type       do_orders_tab;
    gtt_do_items_tab1        do_items_tab;
    gtt_do_cartons_type      do_cartons_tab;
    gtt_do_cartons_tab       do_cartons_tab;
    gn_err_const    CONSTANT NUMBER := 2;
    gn_suc_const    CONSTANT NUMBER := 0;
    gn_login_id              NUMBER := apps.fnd_global.login_id;
    gn_user_id               NUMBER := apps.fnd_global.user_id;
    gd_date                  DATE := SYSDATE;

    /******************************************************
       * Procedure: log_recordss
       *
       * Synopsis: This procedure will call we be called by the concurrent program
        * Design:
        *
        * Notes:
        *
        * PARAMETERS:
        *   IN    : p_debug    Varchar2
        *   IN    : p_message  Varchar2
        *
        * Return Values:
        * Modifications:
        *
        ******************************************************/
    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        x_ret_code   := gn_suc_const;
        log_records ('Y',
                     'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'truncate table CUSTOM.do_items';

        EXECUTE IMMEDIATE 'truncate table CUSTOM.do_containers';

        EXECUTE IMMEDIATE 'truncate table CUSTOM.do_shipments';

        EXECUTE IMMEDIATE 'truncate table CUSTOM.do_orders';

        EXECUTE IMMEDIATE 'truncate table CUSTOM.do_cartons';

        log_records ('Y', 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            log_records ('Y',
                         'Truncate Stage Table Exceptiont' || x_return_mesg);
    END truncte_stage_tables;

    PROCEDURE shipment_load (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        lc_errbuf          VARCHAR2 (6000);
        lc_retcode         VARCHAR2 (6000);
        ln_cnt_id          NUMBER;
        ln_ord_id          NUMBER;
        --ln_count           NUMBER:=0;
        ln_valid_rec_cnt   NUMBER := 0;
    BEGIN
        truncte_stage_tables (x_ret_code      => lc_retcode,
                              x_return_mesg   => lc_errbuf);
        x_retcode   := lc_retcode;
        gtt_do_items_tab.DELETE;
        log_records ('Y', 'DO Conatiners insertion');


        OPEN lcu_do_shipments_data;

        LOOP
            ln_valid_rec_cnt   := 0;
            gtt_do_shipments_type.DELETE;

            FETCH lcu_do_shipments_data
                BULK COLLECT INTO gtt_do_shipments_tab
                LIMIT 100;                                             --5000;

            EXIT WHEN gtt_do_shipments_tab.COUNT = 0;
            log_records (
                'Y',
                'do shipment count => ' || gtt_do_shipments_tab.COUNT);

            IF gtt_do_shipments_tab.COUNT > 0
            THEN
                FOR rec_get_ship_rec IN gtt_do_shipments_tab.FIRST ..
                                        gtt_do_shipments_tab.LAST
                LOOP
                    --ln_count := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                    --

                    gtt_do_shipments_type (ln_valid_rec_cnt).shipment_id   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).shipment_id;
                    gtt_do_shipments_type (ln_valid_rec_cnt).organization_id   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).organization_id;
                    gtt_do_shipments_type (ln_valid_rec_cnt).vendor_name   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).vendor_name;
                    gtt_do_shipments_type (ln_valid_rec_cnt).vendor_code   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).vendor_code;
                    gtt_do_shipments_type (ln_valid_rec_cnt).vendor_id   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).vendor_id;
                    gtt_do_shipments_type (ln_valid_rec_cnt).domestic_overseas_flag   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).domestic_overseas_flag;
                    gtt_do_shipments_type (ln_valid_rec_cnt).weight_volume_flag   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).weight_volume_flag;
                    gtt_do_shipments_type (ln_valid_rec_cnt).bill_of_lading   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).bill_of_lading;
                    gtt_do_shipments_type (ln_valid_rec_cnt).invoice_num   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).invoice_num;
                    gtt_do_shipments_type (ln_valid_rec_cnt).vessel_name   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).vessel_name;
                    gtt_do_shipments_type (ln_valid_rec_cnt).etd   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).etd;
                    gtt_do_shipments_type (ln_valid_rec_cnt).eta   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).eta;
                    gtt_do_shipments_type (ln_valid_rec_cnt).remark   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).remark;
                    gtt_do_shipments_type (ln_valid_rec_cnt).LOCATION   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).LOCATION;
                    gtt_do_shipments_type (ln_valid_rec_cnt).location_id   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).location_id;
                    gtt_do_shipments_type (ln_valid_rec_cnt).discharge_port   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).discharge_port;
                    gtt_do_shipments_type (ln_valid_rec_cnt).consignee   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).consignee;
                    gtt_do_shipments_type (ln_valid_rec_cnt).document_submit_date   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).document_submit_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).obl_charge_date   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).obl_charge_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).ocean_freight   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).ocean_freight;
                    gtt_do_shipments_type (ln_valid_rec_cnt).customs_release_date   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).customs_release_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).duty_due_date   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).duty_due_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).duty   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).duty;
                    gtt_do_shipments_type (ln_valid_rec_cnt).duty_paid   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).duty_paid;
                    gtt_do_shipments_type (ln_valid_rec_cnt).last_free_day   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).last_free_day;
                    gtt_do_shipments_type (ln_valid_rec_cnt).status   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).status;
                    gtt_do_shipments_type (ln_valid_rec_cnt).customs_status   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).customs_status;
                    gtt_do_shipments_type (ln_valid_rec_cnt).customs_entry_number   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).customs_entry_number;
                    gtt_do_shipments_type (ln_valid_rec_cnt).created_by   :=
                        gn_user_id; --gtt_do_shipments_tab (rec_get_ship_rec).created_by;
                    gtt_do_shipments_type (ln_valid_rec_cnt).creation_date   :=
                        gd_date; --gtt_do_shipments_tab (rec_get_ship_rec).creation_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).last_updated_by   :=
                        gn_user_id; --gtt_do_shipments_tab (rec_get_ship_rec).last_updated_by;
                    gtt_do_shipments_type (ln_valid_rec_cnt).last_update_date   :=
                        gd_date; --gtt_do_shipments_tab (rec_get_ship_rec).last_update_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).last_update_login   :=
                        gn_login_id; --gtt_do_shipments_tab (rec_get_ship_rec).last_update_login;
                    gtt_do_shipments_type (ln_valid_rec_cnt).shipment_type   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).shipment_type;
                    gtt_do_shipments_type (ln_valid_rec_cnt).asn_reference_no   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).asn_reference_no;
                    gtt_do_shipments_type (ln_valid_rec_cnt).ownership_fob_date   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).ownership_fob_date;
                    gtt_do_shipments_type (ln_valid_rec_cnt).SOURCE   :=
                        gtt_do_shipments_tab (rec_get_ship_rec).SOURCE;
                END LOOP;

                -------------------------------------------------------------------
                -- do a bulk insert into the XXD_PO_RCV_HEADERS_CNV_STG table
                ----------------------------------------------------------------
                log_records ('Y', 'Bulk Inser to shipment ');

                FORALL ln_shp IN 1 .. gtt_do_shipments_type.COUNT
                    INSERT INTO custom.do_shipments
                         VALUES gtt_do_shipments_type (ln_shp);
            END IF;

            COMMIT;
        END LOOP;

        IF lcu_do_shipments_data%ISOPEN
        THEN
            CLOSE lcu_do_shipments_data;
        END IF;


        OPEN lcu_do_containers_data;

        LOOP
            gtt_do_containers_type.DELETE;


            FETCH lcu_do_containers_data
                BULK COLLECT INTO gtt_do_containers_tab
                LIMIT 100;                                             --5000;

            EXIT WHEN gtt_do_containers_tab.COUNT = 0;
            log_records (
                'Y',
                'do containers count => ' || gtt_do_containers_tab.COUNT);
            --ln_count:=0;
            ln_valid_rec_cnt   := 0;

            IF gtt_do_containers_tab.COUNT > 0
            THEN
                FOR rec_get_cont_rec IN gtt_do_containers_tab.FIRST ..
                                        gtt_do_containers_tab.LAST
                LOOP
                    --ln_count := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                    --

                    gtt_do_containers_type (ln_valid_rec_cnt).container_num   :=
                        gtt_do_containers_tab (rec_get_cont_rec).container_num;
                    gtt_do_containers_type (ln_valid_rec_cnt).container_ref   :=
                        gtt_do_containers_tab (rec_get_cont_rec).container_ref;
                    gtt_do_containers_type (ln_valid_rec_cnt).container_id   :=
                        gtt_do_containers_tab (rec_get_cont_rec).container_id;
                    gtt_do_containers_type (ln_valid_rec_cnt).shipment_id   :=
                        gtt_do_containers_tab (rec_get_cont_rec).shipment_id;
                    gtt_do_containers_type (ln_valid_rec_cnt).receive_date   :=
                        gtt_do_containers_tab (rec_get_cont_rec).receive_date;
                    gtt_do_containers_type (ln_valid_rec_cnt).empty_date   :=
                        gtt_do_containers_tab (rec_get_cont_rec).empty_date;
                    gtt_do_containers_type (ln_valid_rec_cnt).drayage_carrier   :=
                        gtt_do_containers_tab (rec_get_cont_rec).drayage_carrier;
                    gtt_do_containers_type (ln_valid_rec_cnt).freight   :=
                        gtt_do_containers_tab (rec_get_cont_rec).freight;
                    gtt_do_containers_type (ln_valid_rec_cnt).total_weight   :=
                        gtt_do_containers_tab (rec_get_cont_rec).total_weight;
                    gtt_do_containers_type (ln_valid_rec_cnt).total_volume   :=
                        gtt_do_containers_tab (rec_get_cont_rec).total_volume;
                    gtt_do_containers_type (ln_valid_rec_cnt).status   :=
                        gtt_do_containers_tab (rec_get_cont_rec).status;
                    gtt_do_containers_type (ln_valid_rec_cnt).atr_extract_ready_flag   :=
                        gtt_do_containers_tab (rec_get_cont_rec).atr_extract_ready_flag;
                    gtt_do_containers_type (ln_valid_rec_cnt).orig_atr_extract_date   :=
                        gtt_do_containers_tab (rec_get_cont_rec).orig_atr_extract_date;
                    gtt_do_containers_type (ln_valid_rec_cnt).orig_atr_extract_reqid   :=
                        gtt_do_containers_tab (rec_get_cont_rec).orig_atr_extract_reqid;
                    gtt_do_containers_type (ln_valid_rec_cnt).latest_atr_extract_date   :=
                        gtt_do_containers_tab (rec_get_cont_rec).latest_atr_extract_date;
                    gtt_do_containers_type (ln_valid_rec_cnt).latest_atr_extract_reqid   :=
                        gtt_do_containers_tab (rec_get_cont_rec).latest_atr_extract_reqid;

                    gtt_do_containers_type (ln_valid_rec_cnt).created_by   :=
                        gn_user_id; --gtt_do_containers_tab (rec_get_cont_rec).created_by;
                    gtt_do_containers_type (ln_valid_rec_cnt).creation_date   :=
                        gd_date; --gtt_do_containers_tab (rec_get_cont_rec).creation_date;
                    gtt_do_containers_type (ln_valid_rec_cnt).last_updated_by   :=
                        gn_user_id; --gtt_do_containers_tab (rec_get_cont_rec).last_updated_by;
                    gtt_do_containers_type (ln_valid_rec_cnt).last_update_date   :=
                        gd_date; --gtt_do_containers_tab (rec_get_cont_rec).last_update_date;
                    gtt_do_containers_type (ln_valid_rec_cnt).last_update_login   :=
                        gn_login_id; --gtt_do_containers_tab (rec_get_cont_rec).last_update_login;
                    gtt_do_containers_type (ln_valid_rec_cnt).cartons   :=
                        gtt_do_containers_tab (rec_get_cont_rec).cartons;
                    gtt_do_containers_type (ln_valid_rec_cnt).extract_status   :=
                        gtt_do_containers_tab (rec_get_cont_rec).extract_status;
                END LOOP;

                -------------------------------------------------------------------
                -- do a bulk insert into the XXD_PO_RCV_HEADERS_CNV_STG table
                ----------------------------------------------------------------
                log_records ('Y', 'Bulk Inser to containers ');

                FORALL ln_cnt IN 1 .. gtt_do_containers_type.COUNT
                    INSERT INTO custom.do_containers
                         VALUES gtt_do_containers_type (ln_cnt);
            END IF;

            COMMIT;
        END LOOP;

        IF lcu_do_containers_data%ISOPEN
        THEN
            CLOSE lcu_do_containers_data;
        END IF;


        OPEN lcu_do_orders_data;

        LOOP
            -- SAVEPOINT insert_table1;
            gtt_do_orders_type.DELETE;


            FETCH lcu_do_orders_data
                BULK COLLECT INTO gtt_do_orders_tab
                LIMIT 100;                                             --5000;

            EXIT WHEN gtt_do_orders_tab.COUNT = 0;
            log_records ('Y',
                         'do orders count => ' || gtt_do_orders_tab.COUNT);
            --ln_count:=0;
            ln_valid_rec_cnt   := 0;

            IF gtt_do_orders_tab.COUNT > 0
            THEN
                FOR rec_get_ord_rec IN gtt_do_orders_tab.FIRST ..
                                       gtt_do_orders_tab.LAST
                LOOP
                    --ln_count := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                    --

                    gtt_do_orders_type (ln_valid_rec_cnt).container_id   :=
                        gtt_do_orders_tab (rec_get_ord_rec).container_id;
                    gtt_do_orders_type (ln_valid_rec_cnt).order_num   :=
                        gtt_do_orders_tab (rec_get_ord_rec).order_num;
                    gtt_do_orders_type (ln_valid_rec_cnt).order_id   :=
                        gtt_do_orders_tab (rec_get_ord_rec).order_id;
                    gtt_do_orders_type (ln_valid_rec_cnt).order_rec_id   :=
                        gtt_do_orders_tab (rec_get_ord_rec).order_rec_id;
                    gtt_do_orders_type (ln_valid_rec_cnt).vendor_id   :=
                        gtt_do_orders_tab (rec_get_ord_rec).vendor_id;
                    gtt_do_orders_type (ln_valid_rec_cnt).status   :=
                        gtt_do_orders_tab (rec_get_ord_rec).status;
                    gtt_do_orders_type (ln_valid_rec_cnt).created_by   :=
                        gn_user_id; --  gtt_do_orders_tab (rec_get_ord_rec).created_by;
                    gtt_do_orders_type (ln_valid_rec_cnt).creation_date   :=
                        gd_date; --gtt_do_orders_tab (rec_get_ord_rec).creation_date;
                    gtt_do_orders_type (ln_valid_rec_cnt).last_updated_by   :=
                        gn_user_id; -- gtt_do_orders_tab (rec_get_ord_rec).last_updated_by;
                    gtt_do_orders_type (ln_valid_rec_cnt).last_update_date   :=
                        gd_date; --gtt_do_orders_tab (rec_get_ord_rec).last_update_date;
                    gtt_do_orders_type (ln_valid_rec_cnt).last_update_login   :=
                        gn_login_id; --gtt_do_orders_tab (rec_get_ord_rec).last_update_login;
                    gtt_do_orders_type (ln_valid_rec_cnt).match_shipped_quantity   :=
                        gtt_do_orders_tab (rec_get_ord_rec).match_shipped_quantity;
                END LOOP;

                log_records ('Y', 'Bulk Inser to orders ');

                FORALL ln_ord IN 1 .. gtt_do_orders_type.COUNT
                    INSERT INTO custom.do_orders
                         VALUES gtt_do_orders_type (ln_ord);
            END IF;

            COMMIT;
        END LOOP;

        IF lcu_do_orders_data%ISOPEN
        THEN
            CLOSE lcu_do_orders_data;
        END IF;

        log_records ('Y', 'DO cartons insertion');



        OPEN lcu_do_cartons_data;

        LOOP
            -- SAVEPOINT insert_table1;
            gtt_do_cartons_type.DELETE;


            FETCH lcu_do_cartons_data
                BULK COLLECT INTO gtt_do_cartons_tab
                LIMIT 100;                                             --5000;

            EXIT WHEN gtt_do_cartons_tab.COUNT = 0;
            log_records ('Y',
                         'do cartons count => ' || gtt_do_cartons_tab.COUNT);
            --ln_count:=0;
            ln_valid_rec_cnt   := 0;

            IF gtt_do_cartons_tab.COUNT > 0
            THEN
                FOR rec_get_cart_rec IN gtt_do_cartons_tab.FIRST ..
                                        gtt_do_cartons_tab.LAST
                LOOP
                    --ln_count := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                    --
                    gtt_do_cartons_type (ln_valid_rec_cnt).container_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).container_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).organization_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).organization_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).order_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).order_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).order_rec_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).order_rec_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).order_line_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).order_line_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).line_location_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).line_location_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).item_id   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).item_id;
                    gtt_do_cartons_type (ln_valid_rec_cnt).quantity   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).quantity;
                    gtt_do_cartons_type (ln_valid_rec_cnt).carton_number   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).carton_number;
                    gtt_do_cartons_type (ln_valid_rec_cnt).created_by   :=
                        gn_user_id; --gtt_do_cartons_tab (rec_get_cart_rec).created_by         ;
                    gtt_do_cartons_type (ln_valid_rec_cnt).creation_date   :=
                        gd_date; --gtt_do_cartons_tab (rec_get_cart_rec).creation_date      ;
                    gtt_do_cartons_type (ln_valid_rec_cnt).last_updated_by   :=
                        gn_user_id; --gtt_do_cartons_tab (rec_get_cart_rec).last_updated_by    ;
                    gtt_do_cartons_type (ln_valid_rec_cnt).last_update_date   :=
                        gd_date; --gtt_do_cartons_tab (rec_get_cart_rec).last_update_date   ;
                    gtt_do_cartons_type (ln_valid_rec_cnt).last_update_login   :=
                        gn_login_id; --gtt_do_cartons_tab (rec_get_cart_rec).last_update_login  ;
                    gtt_do_cartons_type (ln_valid_rec_cnt).weight   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).weight;
                    gtt_do_cartons_type (ln_valid_rec_cnt).ctn_length   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).ctn_length;
                    gtt_do_cartons_type (ln_valid_rec_cnt).ctn_width   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).ctn_width;
                    gtt_do_cartons_type (ln_valid_rec_cnt).ctn_height   :=
                        gtt_do_cartons_tab (rec_get_cart_rec).ctn_height;
                END LOOP;

                log_records ('Y', 'Bulk Inser to orders ');

                FORALL ln_car IN 1 .. gtt_do_cartons_type.COUNT
                    INSERT INTO custom.do_cartons
                         VALUES gtt_do_cartons_type (ln_car);
            END IF;

            COMMIT;
        END LOOP;

        IF lcu_do_cartons_data%ISOPEN
        THEN
            CLOSE lcu_do_cartons_data;
        END IF;


        log_records ('Y', 'HERE');

        OPEN lcu_do_items_data;                      --(ln_cnt_id, ln_ord_id);

        LOOP
            gtt_do_items_tab1.DELETE;

            FETCH lcu_do_items_data
                BULK COLLECT INTO gtt_do_items_tab
                LIMIT 1000;


            ln_valid_rec_cnt   := 0;

            IF gtt_do_items_tab.COUNT > 0
            THEN
                FOR rec_lcu_do_items_data IN gtt_do_items_tab.FIRST ..
                                             gtt_do_items_tab.LAST
                LOOP
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;

                    gtt_do_items_tab1 (ln_valid_rec_cnt).container_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).CONTAINER_ID;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).domestic_overseas_flag   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).domestic_overseas_flag;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).weight_volume_flag   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).weight_volume_flag;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).organization_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).organization_id;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).order_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).order_id;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).order_rec_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).ORDER_REC_ID; --,rec_lcu_do_items_data.ORDER_REC_ID
                    gtt_do_items_tab1 (ln_valid_rec_cnt).order_line_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).order_line_id;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).line_location_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).line_location_id;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).item_num   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).item_num;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).description   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).description;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).quantity   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).quantity;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).price   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).price;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).item_id   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).item_id;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).created_by   :=
                        gn_user_id; -- gtt_do_items_tab (rec_lcu_do_items_data).created_by;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).creation_date   :=
                        gd_date; --gtt_do_items_tab (rec_lcu_do_items_data).creation_date;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).last_updated_by   :=
                        gn_user_id; --gtt_do_items_tab (rec_lcu_do_items_data).last_updated_by;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).last_update_date   :=
                        gd_date; --gtt_do_items_tab (rec_lcu_do_items_data).last_update_date;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).last_update_login   :=
                        gn_login_id; --gtt_do_items_tab (rec_lcu_do_items_data).last_update_login;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).entered_quantity   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).entered_quantity;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).received_quantity   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).received_quantity;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).calc_freight   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).calc_freight;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).calc_duty   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).calc_duty;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).calc_port_usage   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).calc_port_usage;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).unit_weight   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).unit_weight;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).unit_volume   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).unit_volume;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).pre_freight_cost   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).pre_freight_cost;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).post_freight_cost   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).post_freight_cost;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).pre_duty_cost   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).pre_duty_cost;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).post_duty_cost   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).post_duty_cost;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).atr_number   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).atr_number;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).system_received_date   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).system_received_date;
                    gtt_do_items_tab1 (ln_valid_rec_cnt).promised_date   :=
                        gtt_do_items_tab (rec_lcu_do_items_data).promised_date;
                END LOOP;
            END IF;

            --    log_records ('Y', ln_id || 'ln_id2');
            FORALL ln_itm IN 1 .. gtt_do_items_tab1.COUNT
                INSERT INTO do_items
                     VALUES gtt_do_items_tab1 (ln_itm);

            EXIT WHEN lcu_do_items_data%NOTFOUND;
            COMMIT;
        END LOOP;


        IF lcu_do_items_data%ISOPEN
        THEN
            CLOSE lcu_do_items_data;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := gn_err_const;
            x_errbuf    :=
                   'Unknown error from (xxd_do_shipments_pkg)'
                || SQLCODE
                || SQLERRM;
    END shipment_load;
END xxd_do_shipments_pkg;
/
