--
-- XXD_WMS_NEXUS_PACKLIST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_NEXUS_PACKLIST_PKG"
IS
    /****************************************************************************************
    * Package      :XXD_WMS_NEXUS_PACKLIST_PKG
    * Design       : This package is used for the NIM process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
      -- 01-Jun-2022  1.0      Shivanshu          Initial Version
    ******************************************************************************************/


    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
        fnd_file.put_line (fnd_file.LOG, p_message);
    END;


    --Set the last SO extract date in the lookup

    PROCEDURE set_asn_last_extract_date (p_code IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        msg ('  update lookup at: ' || SYSDATE);

        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_WMS_NEXUS_PACKLIST_EXT_LKP'
               AND lookup_code = p_code;

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_WMS_NEXUS_PACKLIST_EXT_LKP'
               AND lookup_code = p_code;

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_asn_last_extract_date;

    PROCEDURE packlist_extract_event (x_status       OUT NOCOPY VARCHAR2,
                                      x_message      OUT NOCOPY VARCHAR2)
    IS
        CURSOR c_asn_cur IS
              SELECT DISTINCT order_id delivery_id, shipment_id
                FROM fnd_lookup_values_vl flv, apps.org_organization_definitions od, xxdo.xxdo_wms_3pl_osc_h osch,
                     do_edi.do_edi856_pick_tickets pt
               WHERE     flv.lookup_type = 'XXD_ODC_ORG_CODE_LKP'
                     AND flv.lookup_code = organization_code
                     AND osch.organization_id = od.organization_id
                     AND osch.PROCESS_STATUS = 'S'
                     AND pt.delivery_id(+) = osch.order_id
                     AND flv.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                     AND NVL (end_date_active, SYSDATE + 1)
                     AND osch.last_update_date BETWEEN (SELECT TO_DATE (description, 'DD-MON-YYYY HH:MI:SS AM')
                                                          FROM fnd_lookup_values
                                                         WHERE     1 = 1
                                                               AND lookup_type LIKE
                                                                       'XXD_WMS_NEXUS_PACKLIST_EXT_LKP'
                                                               AND language =
                                                                   'US'
                                                               AND lookup_code =
                                                                   'NEXUS_PACKLIST_LAST_EXTRACT')
                                                   AND (SELECT TO_DATE (tag, 'DD-MON-YYYY HH:MI:SS AM')
                                                          FROM fnd_lookup_values
                                                         WHERE     1 = 1
                                                               AND lookup_type LIKE
                                                                       'XXD_WMS_NEXUS_PACKLIST_EXT_LKP'
                                                               AND language =
                                                                   'US'
                                                               AND lookup_code =
                                                                   'NEXUS_PACKLIST_LAST_EXTRACT')
            ORDER BY shipment_id;



        l_batch_throttle_time   NUMBER := 40;
        ln_rec_cnt              NUMBER := 0;
        in_count                NUMBER := 0;
        lv_event_key            VARCHAR2 (200);
        ln_shipment_id          NUMBER := 0;
    BEGIN
        ln_shipment_id   := 0;
        msg (
               '************************  STAT Program: '
            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));

        set_asn_last_extract_date ('NEXUS_PACKLIST_LAST_EXTRACT',
                                   x_status,
                                   x_message);

        FOR c_asn_rec IN c_asn_cur
        LOOP
            ln_rec_cnt   := ln_rec_cnt + 1;


            SELECT COUNT (1)
              INTO in_count
              FROM wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
             WHERE     delivery_id = c_asn_rec.delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND released_status NOT IN ('Y', 'C');


            IF in_count = 0
            THEN
                IF MOD (ln_rec_cnt, 50) = 0
                THEN
                    DBMS_LOCK.sleep (l_batch_throttle_time);
                END IF;



                IF ln_shipment_id <> NVL (c_asn_rec.shipment_id, 999)
                THEN
                    lv_event_key   :=
                           'ShipmentId:'
                        || c_asn_rec.shipment_id
                        || '|'
                        || ' DeliveryId: '
                        || c_asn_rec.delivery_id;

                    msg (
                           ' Business Event Raised for Event Key : '
                        || lv_event_key);

                    BEGIN
                        apps.wf_event.RAISE (p_event_name => 'oracle.apps.xxdo.odc_asn_event', p_event_key => lv_event_key, p_event_data => NULL
                                             , p_parameters => NULL);
                        x_status    := apps.fnd_api.g_ret_sts_success;
                        x_message   := NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_status    := apps.fnd_api.g_ret_sts_error;
                            x_message   := SQLERRM;
                            msg ('  EXCEPTION: ' || SQLERRM);
                    END;

                    COMMIT;
                END IF;
            ELSE
                msg (
                    ' Deleivery is not picked and staged : ' || c_asn_rec.delivery_id);
            END IF;

            IF c_asn_rec.shipment_id IS NOT NULL
            THEN
                ln_shipment_id   := c_asn_rec.shipment_id;
            END IF;
        END LOOP;

        msg (
               '************************  END Program: '
            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));

        x_status         := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END packlist_extract_event;
END XXD_WMS_NEXUS_PACKLIST_PKG;
/
