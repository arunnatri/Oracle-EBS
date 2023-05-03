--
-- XXD_EDI_SHIPMENT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_EDI_SHIPMENT_PKG"
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Project         :
    --  Description     :
    --  Module          : xxd_edi_shipment_pkg
    --  File            : xxd_edi_shipment_pkg.pks
    --  Schema          : APPS
    --  Date            : 16-JUL-2015
    --  Version         : 1.0
    --  Author(s)       : Rakesh Dudani [ Suneratech Consulting]
    --  Purpose         : Package used to update the shipment's load id.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  16-JUL-2015     Rakesh Dudani       1.0                             Initial Version
    --
    --
    --  ###################################################################################


    PROCEDURE update_shipment_load_id (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_ship_delivery IN VARCHAR2, pv_dummy_input IN VARCHAR2, pn_ship_del_id IN NUMBER, pv_load_id IN VARCHAR2, pv_tracking_num IN VARCHAR2, pv_waybill IN VARCHAR2, pv_pro_number IN VARCHAR2
                                       , pv_scac IN VARCHAR2)
    IS
        ln_delivery_id     NUMBER;
        ln_shipment_id     NUMBER;


        CURSOR shipment_to_update (ln_delivery_id   NUMBER,
                                   ln_shipment_id   NUMBER)
        IS
            SELECT DISTINCT ship.shipment_id
              FROM do_edi.do_edi856_shipments ship, apps.wsh_new_deliveries wnd, do_edi.do_edi856_pick_tickets pt,
                   apps.ra_customers custs, apps.oe_order_headers_all ooha, custom.do_edi_lookup_values lv,
                   apps.wsh_carriers c, do_edi.do_edi850in_headers edih
             WHERE     wnd.attribute2 = c.freight_code(+)
                   --AND wnd.confirm_date >= trunc(SYSDATE) - 1
                   --AND wnd.confirm_date >=  TO_DATE('01-AUG-2015', 'DD-MON-YYYY HH24:MI:SS')
                   AND ship.customer_id = custs.customer_id
                   AND ship.shipment_id =
                       NVL (ln_shipment_id, ship.shipment_id)
                   AND pt.delivery_id = wnd.delivery_id
                   AND ship.shipment_id = pt.shipment_id
                   AND wnd.source_header_id = ooha.header_id
                   AND wnd.status_code = 'CL'
                   --AND ship.asn_status = 'R'
                   AND ooha.order_number = edih.order_number(+)
                   AND ooha.cust_po_number = edih.po_number(+)
                   AND lv.lookup_type IN ('856_EXPORT', '856_LOADID_REQ')
                   AND lv.enabled_flag = 'Y'
                   AND lv.meaning = 'Y'
                   AND ((custs.customer_number = '1997' AND ship.tracking_number IS NULL) OR custs.customer_number != '1997')
                   --AND load_id IS NULL
                   AND pt.delivery_id = NVL (ln_delivery_id, pt.delivery_id)
                   AND custs.customer_id = TO_NUMBER (lv.lookup_code);

        shipment_rec       shipment_to_update%ROWTYPE;

        ln_load_id         NUMBER;
        ln_waybill         NUMBER;
        ln_tracking_num    VARCHAR2 (30);
        ln_record_update   NUMBER := 0;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Update Shipment Load ID Starta at '
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS')
            || ' FOR '
            || pv_ship_delivery);

        IF pv_ship_delivery = 'DELIVERY ID'
        THEN
            ln_delivery_id   := pn_ship_del_id;
            ln_shipment_id   := NULL;
        ELSE
            ln_shipment_id   := pn_ship_del_id;
            ln_delivery_id   := NULL;
        END IF;


        BEGIN
            FOR shipment_rec
                IN shipment_to_update (ln_delivery_id, ln_shipment_id)
            LOOP
                /*
                   BEGIN
                      SELECT wnd.attribute1, wnd.attribute15, waybill
                        INTO ln_tracking_num, ln_load_id, ln_waybill
                        FROM apps.wsh_new_deliveries wnd
                       WHERE wnd.delivery_id = shipment_rec.delivery_id;
                   EXCEPTION
                      WHEN NO_DATA_FOUND
                      THEN
                         APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'There is no data for delivery id = '
                            || shipment_rec.delivery_id
                            || '  Error '
                            || SQLERRM);
                      WHEN OTHERS
                      THEN
                         APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'There is an unexpected error for delivery id = '
                            || shipment_rec.delivery_id
                            || '  Error '
                            || SQLERRM);
                   END;
                   */
                ln_record_update   := ln_record_update + 1;

                BEGIN
                    IF pv_load_id IS NOT NULL
                    THEN
                        UPDATE do_edi.do_edi856_shipments
                           SET asn_date = NULL, load_id = pv_load_id
                         WHERE shipment_id = shipment_rec.shipment_id;

                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Shipment Id # '
                            || shipment_rec.shipment_id
                            || ' is updated with Load_id = '
                            || pv_load_id);
                    END IF;

                    IF pv_tracking_num IS NOT NULL
                    THEN
                        UPDATE do_edi.do_edi856_shipments
                           SET tracking_number   = pv_tracking_num
                         WHERE shipment_id = shipment_rec.shipment_id;

                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Shipment Id # '
                            || shipment_rec.shipment_id
                            || ' is updated with tracking_number = '
                            || pv_tracking_num);
                    END IF;

                    IF pv_waybill IS NOT NULL
                    THEN
                        UPDATE do_edi.do_edi856_shipments
                           SET asn_date = NULL, waybill = pv_waybill
                         WHERE shipment_id = shipment_rec.shipment_id;

                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Shipment Id # '
                            || shipment_rec.shipment_id
                            || ' is updated with Waybill = '
                            || pv_waybill);
                    END IF;


                    IF pv_pro_number IS NOT NULL
                    THEN
                        UPDATE do_edi.do_edi856_shipments
                           SET asn_date = NULL, pro_number = pv_pro_number
                         WHERE shipment_id = shipment_rec.shipment_id;

                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Shipment Id # '
                            || shipment_rec.shipment_id
                            || ' is updated with pro_number = '
                            || pv_pro_number);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Shipment Id # '
                            || shipment_rec.shipment_id
                            || ' is updated with Waybill = '
                            || pv_waybill
                            || ' pn_tracking_num '
                            || pv_tracking_num);

                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'An exception occured while updating load_id : '
                            || SQLERRM);
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'No Rows to be updated for the '
                    || pv_ship_delivery
                    || ' '
                    || pn_ship_del_id
                    || ' Error '
                    || SQLERRM);
        END;

        apps.fnd_file.put_line (apps.fnd_file.LOG, ln_delivery_id || SQLERRM);

        IF ln_delivery_id IS NOT NULL AND pv_scac IS NOT NULL
        THEN
            BEGIN
                UPDATE wsh.wsh_new_deliveries
                   SET ATTRIBUTE2   = pv_scac
                 WHERE delivery_id = ln_delivery_id;

                COMMIT;
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'DELIVERY Id # '
                    || ln_delivery_id
                    || ' is updated with SCAC = '
                    || pv_scac);
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'No Rows to be updated for the '
                        || pv_ship_delivery
                        || ' '
                        || pn_ship_del_id
                        || ' Error '
                        || SQLERRM);
            END;
        END IF;


        IF ln_record_update > 0
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'NUMBER OF ROWS UPDATED'
                || ln_record_update
                || ' For '
                || pv_ship_delivery
                || ' '
                || pn_ship_del_id);
        ELSE
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'No Rows to be updated for the '
                || pv_ship_delivery
                || ' '
                || pn_ship_del_id);
        END IF;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'There is an exception : ' || SQLERRM);
            errbuff   := 'There is an exception : ' || SQLERRM;
    END;
END xxd_edi_shipment_pkg;
/
