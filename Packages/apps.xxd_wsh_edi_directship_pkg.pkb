--
-- XXD_WSH_EDI_DIRECTSHIP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WSH_EDI_DIRECTSHIP_PKG"
AS
    /************************************************************************************************
       * Package         : XXD_WSH_EDI_DIRECTSHIP_PKG
       * Description     : This package is used for raising dock.door business event
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date         Version#      Name                       Description
       *-----------------------------------------------------------------------------------------------
       * 13-MAY-2019  1.0           Showkath Ali               Initial Version
    * 30-JUL-2020  1.1           Showkath Ali               CCR0008488 - EDI 856 EBS changes
       ************************************************************************************************/
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_reprocess IN VARCHAR2
                    , p_shipment_id IN NUMBER)
    AS
        CURSOR xxd_directship_new_cur IS
            SELECT DISTINCT ship.shipment_id, sps_event                 -- 1.1
              FROM do_edi.do_edi856_shipments ship, do_edi.do_edi856_pick_tickets pt, apps.wsh_new_deliveries wnd,
                   apps.oe_order_headers_all ooha
             WHERE     ship.shipment_id = pt.shipment_id
                   AND pt.delivery_id = wnd.delivery_id
                   AND wnd.source_header_id = ooha.header_id
                   AND ship.dock_door_event = 'Y'
                   AND (   (p_reprocess = 'Y' AND ship.asn_status = 'R' AND ship.shipment_id = p_shipment_id)
                        OR (    p_reprocess = 'N'
                            AND ship.asn_status = 'N'
                            AND ((p_shipment_id IS NOT NULL AND ship.shipment_id = p_shipment_id) OR (p_shipment_id IS NULL AND 1 = 1))
                            AND TRUNC (ooha.request_date) <=
                                  TRUNC (SYSDATE)
                                + NVL (
                                      (SELECT TO_NUMBER (attribute2)
                                         FROM fnd_lookup_values flv
                                        WHERE     lookup_type =
                                                  'XXD_ONT_DS_EDI856_LKP'
                                              AND flv.language =
                                                  USERENV ('LANG')
                                              AND flv.enabled_flag = 'Y'
                                              AND TO_NUMBER (flv.attribute1) =
                                                  ship.customer_id
                                              AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                                              AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))),
                                      0)));

        l_process_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'EDI 856 for Direct Ship Orders Program start');
        fnd_file.put_line (fnd_file.LOG, 'Reprocess: ' || p_reprocess);

        IF p_shipment_id IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Shipment ID: ' || p_shipment_id);
        END IF;

        -- If the parameter passed as No in the program the below cursor will be processed to fetch the records

        FOR i IN xxd_directship_new_cur
        LOOP
            l_process_count   := l_process_count + 1;

            -- Raise business events 'oracle.apps.xxdo.dock_door_closed’ by passing shipment id as parameter
            BEGIN
                IF NVL (i.sps_event, 'N') = 'N'
                THEN                                                     --1.1
                    wf_event.RAISE (
                        p_event_name   => 'oracle.apps.xxdo.dock_door_closed',
                        p_event_key    => i.shipment_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'XXDO_DOCK_DOOR_CLOSE_EVT Successful for shipment:'
                        || i.shipment_id);
                ELSIF NVL (i.sps_event, 'N') = 'Y'
                THEN
                    wf_event.RAISE (
                        p_event_name   =>
                            'oracle.apps.xxdo.sps_edi_transmission',
                        p_event_key   => i.shipment_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'XXDO_DOCK_DOOR_SPS_CLOSE_EVT Successful for shipment:'
                        || i.shipment_id);
                END IF;

                -- Update ASN_STATUS as “R” for processed records
                BEGIN
                    UPDATE do_edi.do_edi856_shipments
                       SET asn_status = 'R', last_updated_by = fnd_global.user_id, last_update_date = SYSDATE
                     WHERE shipment_id = i.shipment_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating asn_status was failed for shipment:'
                            || i.shipment_id
                            || SUBSTR (SQLERRM, 1, 200));
                END;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'XXDO_DOCK_DOOR_CLOSE_EVT threw exception for shipment: '
                        || i.shipment_id
                        || SUBSTR (SQLERRM, 1, 200));
            END;
        END LOOP;

        IF l_process_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'No Record exists.');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SUBSTR (SQLERRM, 1, 2000);
            retcode   := 2;
            fnd_file.put_line (fnd_file.LOG, errbuf);
    END main;
END xxd_wsh_edi_directship_pkg;
/
