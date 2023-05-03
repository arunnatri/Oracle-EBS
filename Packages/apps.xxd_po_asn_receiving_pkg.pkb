--
-- XXD_PO_ASN_RECEIVING_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_ASN_RECEIVING_PKG"
AS
    /******************************************************************************************
     * Package      : XXD_PO_ASN_RECEIVING_PKG
     * Design       : This package is used for Receiving ASNs for Direct Ship and Special VAS
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 02-MAY-2019  1.0        Greg Jensen           Initial Version
    -- 08-MAR-2023  1.1        Aravind Kannuri       Updated for CCR0010255
    ******************************************************************************************/

    gn_resp_id                              NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id                         NUMBER := apps.fnd_global.resp_appl_id;

    gv_mo_profile_option_name_po   CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ;
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ;
    gv_responsibility_name_po      CONSTANT VARCHAR2 (240)
                                                := 'Deckers Purchasing User' ;
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
        := 'Deckers Order Management User' ;
    gv_US_OU                       CONSTANT VARCHAR2 (50) := 'Deckers US OU';

    gn_org_id                               NUMBER := fnd_global.org_id;
    gn_user_id                              NUMBER := fnd_global.user_id;
    gn_login_id                             NUMBER := fnd_global.login_id;
    gn_request_id                           NUMBER
                                                := fnd_global.conc_request_id;
    gn_employee_id                          NUMBER := fnd_global.employee_id;
    gn_application_id                       NUMBER
        := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id                    NUMBER
        := fnd_profile.VALUE ('RESP_ID');
    gc_debug_enable                         VARCHAR2 (1);

    /*******************
    Procedures to write to the log table
    ********************/
    PROCEDURE purge_status_log (pn_no_of_days IN NUMBER:= 30)
    IS
    BEGIN
        DELETE FROM xxdo.xxd_po_asn_receiving_t
              WHERE creation_date <= SYSDATE - pn_no_of_days;

        COMMIT;
    END;

    PROCEDURE record_error_log (pn_shipment_header_id IN NUMBER, pn_shipment_line_id IN NUMBER:= NULL, pn_status IN VARCHAR2:= 'E'
                                , pv_msg IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ln_seq_val   NUMBER;
    BEGIN
        --   SELECT XXDO.XXD_PO_ASN_RECEIVING_S.NEXTVAL INTO ln_seq_val FROM DUAL;

        INSERT INTO XXDO.XXD_PO_ASN_RECEIVING_T (RECORD_ID,
                                                 ORDER_TYPE,
                                                 ORG_ID,
                                                 SHIPMENT_ID,
                                                 FACTORY_INVOICE_NUMBER,
                                                 FACTORY_ASN_NUMBER,
                                                 CONTAINER_ID,
                                                 FACTORY_CONTAINER_NUMBER,
                                                 PO_HEADER_ID,
                                                 PO_NUMBER,
                                                 PO_LINE_ID,
                                                 PO_LINE_NUMBER,
                                                 PO_LINE_LOCATION_ID,
                                                 PO_SHIPMENT_NUMBER,
                                                 ORACLE_INBOUND_ASN_NUMBER,
                                                 PO_QUANTITY,
                                                 QUANTITY_RECEIVED,
                                                 SHIPMENT_LINE_STATUS_CODE,
                                                 RECEIVING_ORGANIZATION_ID,
                                                 RECEIVING_SUB_INVENTORY,
                                                 RECORD_STATUS,
                                                 ERROR_MESSAGE,
                                                 REQUEST_ID,
                                                 CREATED_BY,
                                                 CREATION_DATE,
                                                 LAST_UPDATED_BY,
                                                 LAST_UPDATE_DATE)
            SELECT XXDO.XXD_PO_ASN_RECEIVING_S.NEXTVAL,
                   NULL,                                         --   tt.name,
                   (SELECT org_id
                      FROM po_headers_all pha
                     WHERE pha.po_header_id = rsl.po_header_id),
                   REGEXP_SUBSTR (rsh.shipment_num, '[^-]+', 1,
                                  1),                            --shipment_id
                   rsh.packing_slip,
                   (SELECT s.asn_reference_no
                      FROM custom.do_shipments s
                     WHERE s.invoice_num = rsh.packing_slip),
                   REGEXP_SUBSTR (rsh.shipment_num, '[^-]+', 1,
                                  2),                           --container_id
                   rsl.container_num,
                   rsl.po_header_id,
                   (SELECT segment1
                      FROM po_headers_all pha
                     WHERE pha.po_header_id = rsl.po_header_id),
                   rsl.po_line_id,
                   (SELECT pla.line_num
                      FROM po_lines_all pla
                     WHERE pla.po_line_id = rsl.po_line_id),
                   rsl.po_line_location_id,
                   (SELECT plla.shipment_num
                      FROM po_line_locations_all plla
                     WHERE plla.line_location_id = rsl.po_line_location_id),
                   rsh.shipment_num,
                   (SELECT pla.quantity
                      FROM po_lines_all pla
                     WHERE pla.po_line_id = rsl.po_line_id),
                   rsl.quantity_received,
                   rsl.shipment_line_status_code,
                   rsh.ship_to_org_id,
                   (SELECT subinventory
                      FROM rcv_transactions rt
                     WHERE     rt.transaction_type = 'DELIVER'
                           AND rt.shipment_line_id = rsl.shipment_line_id),
                   pn_status,
                   pv_msg,
                   gn_request_id,
                   gn_user_id,
                   SYSDATE,
                   gn_user_id,
                   SYSDATE
              FROM rcv_shipment_lines rsl, rcv_shipment_headers rsh
             WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsh.shipment_header_id = pn_shipment_header_id
                   AND (rsl.shipment_line_id = pn_shipment_line_id OR pn_shipment_line_id IS NULL);



        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;                                     --Record to process log;
    END;

    /*******************
    Write to the log file
    ********************/
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;


    /*******************
    Responsibility initialization
    ********************/

    PROCEDURE set_purchasing_context (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
                                      , pv_error_msg OUT VARCHAR2)
    IS
        pv_msg            VARCHAR2 (2000);
        pv_stat           VARCHAR2 (1);
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;

        ex_get_resp_id    EXCEPTION;
    BEGIN
        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name_po   --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_id NOT IN (51395, 51398)      --TEMP
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name_po || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = pn_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE ex_get_resp_id;
        END;

        -- DoLog ('Context Info before');
        -- DoLog ('Curr ORG: ' || apps.mo_global.get_current_org_id);
        -- DoLog ('Multi Org Enabled: ' || apps.mo_global.is_multi_org_enabled);

        --do intialize and purchssing setup
        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);

        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', pn_org_id);
        FND_REQUEST.SET_ORG_ID (pn_org_id);

        -- DoLog ('Context Info after');
        -- DoLog ('Curr ORG: ' || apps.mo_global.get_current_org_id);
        -- DoLog ('Multi Org Enabled: ' || apps.mo_global.is_multi_org_enabled);

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_get_resp_id
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error getting Purchasing context resp_id : ' || SQLERRM;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;


    /*******************
   Split a delivery detail record
   ********************/

    /*   PROCEDURE split_delivery_detail (
          p_delivery_detail_id       IN     NUMBER,
          p_x_split_quantity         IN OUT NUMBER,
          x_new_delivery_detail_id      OUT NUMBER,
          x_ret_stat                    OUT VARCHAR2,
          x_ret_msg                     OUT VARCHAR2)
       IS
          msg_count   NUMBER;
          msg_data    VARCHAR2 (2000);
          dummy       NUMBER;
       BEGIN
          x_ret_msg := '';
          wsh_delivery_details_pub.split_line (
             p_api_version        => 1.0,
             p_init_msg_list      => fnd_api.g_false,
             p_commit             => fnd_api.g_false,
             p_validation_level   => fnd_api.g_valid_level_full,
             x_return_status      => x_ret_stat,
             x_msg_count          => msg_count,
             x_msg_data           => msg_data,
             p_from_detail_id     => p_delivery_detail_id,
             x_new_detail_id      => x_new_delivery_detail_id,
             x_split_quantity     => p_x_split_quantity,
             x_split_quantity2    => dummy);


          FOR j IN 1 .. fnd_msg_pub.count_msg
          LOOP
             msg_data := fnd_msg_pub.get (j, 'F');
             msg_data := REPLACE (msg_data, CHR (0), ' ');
             x_ret_msg := x_ret_msg || msg_data;
          END LOOP;
       EXCEPTION
          WHEN OTHERS
          THEN
             NULL;
       END;*/

    /*******************************
    Split delivery details for a shipment based on shipped quantities
    ********************************/
    PROCEDURE split_delivery_details (pn_shipment_header_id IN VARCHAR2, pv_error_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR)
    IS
        CURSOR c_shipment IS
            SELECT rsh.shipment_num, rsh.shipment_header_id, rsl.shipment_line_id,
                   rsl.quantity_shipped, oola.line_id, wdd.delivery_detail_id,
                   wdd.requested_quantity, c.scac_code, rsl.container_num
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, oe_order_lines_all oola,
                   wsh_delivery_details wdd, wsh_carriers c
             WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsl.attribute3 = oola.line_id
                   AND oola.line_id = wdd.source_line_id
                   AND rsh.shipment_header_id = pn_shipment_header_id
                   AND wdd.carrier_id = c.carrier_id
                   AND wdd.attribute8 IS NULL
                   AND wdd.source_code = 'OE';

        ln_new_wdd_rec             NUMBER;
        n_new_qty                  NUMBER;
        ln_err_stat                VARCHAR2 (1);
        ln_err_msg                 VARCHAR2 (2000);
        x_new_delivery_detail_id   NUMBER;

        msg_count                  NUMBER;
        msg_data                   VARCHAR2 (2000);
        dummy                      NUMBER;
    BEGIN
        debug_msg ('+split delivery details');

        FOR rec IN c_shipment
        LOOP
            debug_msg (
                   'splitting details for shipment_line_id : '
                || rec.shipment_line_id
                || ' WDD : '
                || rec.delivery_detail_id);
            --get new quantity as the wdd requested quantity minus the ASN shipped qty
            n_new_qty   := rec.requested_quantity - rec.quantity_shipped;

            IF n_new_qty > 0
            THEN
                /*          split_delivery_detail (
                             p_delivery_detail_id       => rec.delivery_detail_id,
                             p_x_split_quantity         => n_new_qty,
                             x_new_delivery_detail_id   => ln_new_wdd_rec,
                             x_ret_stat                 => ln_err_stat,
                             x_ret_msg                  => ln_err_msg);*/
                ln_err_msg   := '';

                --Call API
                wsh_delivery_details_pub.split_line (
                    p_api_version        => 1.0,
                    p_init_msg_list      => fnd_api.g_false,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    x_return_status      => ln_err_stat,
                    x_msg_count          => msg_count,
                    x_msg_data           => msg_data,
                    p_from_detail_id     => rec.delivery_detail_id,
                    x_new_detail_id      => ln_new_wdd_rec,
                    x_split_quantity     => n_new_qty,
                    x_split_quantity2    => dummy);

                --Get process messages
                FOR j IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    msg_data     := fnd_msg_pub.get (j, 'F');
                    msg_data     := REPLACE (msg_data, CHR (0), ' ');
                    ln_err_msg   := ln_err_msg || msg_data;
                END LOOP;
            END IF;

            --If not success report delivery split and rollback all carton split actions
            IF ln_err_stat != 'S'
            THEN
                ROLLBACK;
                --Log failed delivery split to message table
                record_error_log (
                    rec.shipment_header_id,
                    rec.shipment_line_id,
                    'E',
                    'Detail delivery split failed' || ln_err_msg);
                pv_error_stat   := 'E';
                pv_err_msg      := ln_err_msg;
                RETURN;
            END IF;

            --Update reference fields in the delivery detail recode
            UPDATE wsh_delivery_details
               SET attribute8   = rec.shipment_num
             WHERE delivery_detail_id = rec.delivery_detail_id;
        END LOOP;

        COMMIT;

        pv_error_stat   := 'S';
        pv_err_msg      := '';
        debug_msg ('-split delivery details');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            pv_error_stat   := 'E';
            pv_err_msg      := SQLERRM;
            debug_msg ('-split delivery details with exception' || SQLERRM);
    END;

    /*************************
      -Check if the passed in Org/Subinventory is valid
    *************************/
    FUNCTION validate_org_subinventory (pn_org_id         IN NUMBER,
                                        pv_subinventory   IN VARCHAR2)
        RETURN BOOLEAN
    IS
        n_cnt   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO n_cnt
          FROM MTL_SECONDARY_INVENTORIES
         WHERE     organization_id = pn_org_id
               AND secondary_inventory_name = pv_subinventory
               AND NVL (disable_date, SYSDATE) > TRUNC (SYSDATE);

        IF n_cnt > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    /********************************************
    Run Receive Transaction Processor for given group ID
    *********************************************/
    PROCEDURE run_rcv_transaction_processor (
        p_group_id     IN     NUMBER,
        p_wait         IN     VARCHAR2 := 'Y',
        p_request_id      OUT NUMBER,
        x_ret_stat        OUT VARCHAR2,
        x_error_text      OUT VARCHAR2)
    IS
        l_req_id       NUMBER;
        l_req_status   BOOLEAN;
        l_phase        VARCHAR2 (80);
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        l_org_id       NUMBER;
    BEGIN
        x_ret_stat     := fnd_api.g_ret_sts_success;
        x_error_text   := NULL;

        --Get org for group
        BEGIN
            SELECT DISTINCT org_id
              INTO l_org_id
              FROM rcv_headers_interface
             WHERE GROUP_ID = p_group_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_org_id   := NULL;
        END;

        --If this is not in the group get the US ORG or USER org
        IF l_org_id IS NULL
        THEN
            BEGIN
                SELECT organization_id
                  INTO l_org_id
                  FROM hr_all_organization_units
                 WHERE name = gv_US_OU;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_org_id   := gn_org_id;
            END;
        END IF;

        debug_msg ('Setting purchasing context for org : ' || l_org_id);
        --Set purchasing context
        set_purchasing_context (gn_user_id, l_org_id, x_ret_stat,
                                x_error_text);

        IF x_ret_stat != 'S'
        THEN
            x_error_text   :=
                'Unable to set purchasing context : ' || x_error_text;
            RETURN;
        END IF;

        l_req_id       :=
            fnd_request.submit_request (application   => 'PO',
                                        program       => 'RVCTP',
                                        argument1     => 'BATCH',
                                        argument2     => TO_CHAR (p_group_id),
                                        argument3     => NULL);
        COMMIT;

        IF NVL (p_wait, 'Y') = 'Y'
        THEN
            l_req_status   :=
                fnd_concurrent.wait_for_request (request_id   => l_req_id,
                                                 interval     => 10,
                                                 max_wait     => 0,
                                                 phase        => l_phase,
                                                 status       => l_status,
                                                 dev_phase    => l_dev_phase,
                                                 dev_status   => l_dev_status,
                                                 MESSAGE      => l_message);

            IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
            THEN
                IF NVL (l_dev_status, 'ERROR') = 'WARNING'
                THEN
                    x_ret_stat   := 'W';          --fnd_api.g_ret_sts_warning;
                ELSE
                    x_ret_stat   := fnd_api.g_ret_sts_error;
                END IF;

                x_error_text   :=
                    NVL (
                        l_message,
                           'The receiving transaction processor request ended with a status of '
                        || NVL (l_dev_status, 'ERROR'));
                RETURN;
            END IF;
        END IF;

        p_request_id   := l_req_id;
        x_ret_stat     := 'S';
        x_error_text   := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat     := fnd_api.g_ret_sts_unexp_error;
            x_error_text   := SQLERRM;
    END;


    FUNCTION check_org_gl_status (pn_organization_id IN NUMBER)
        RETURN BOOLEAN
    IS
        n_cnt   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO n_cnt
          FROM org_acct_periods oap
         WHERE     oap.organization_id = pn_organization_id
               AND open_flag = 'Y'
               AND (TRUNC (SYSDATE) BETWEEN TRUNC (oap.period_start_date) AND TRUNC (oap.schedule_close_date));

        IF n_cnt > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    PROCEDURE fix_asn_oe_link_from_rsrv (pn_shipment_header_id IN NUMBER)
    IS
    BEGIN
        UPDATE rcv_shipment_lines rsl
           SET rsl.attribute3   =
                   (SELECT oola.line_id
                      FROM oe_order_lines_all oola, mtl_reservations mr
                     WHERE     rsl.po_line_location_id =
                               mr.supply_source_line_id
                           AND mr.demand_source_line_id = oola.line_id)
         WHERE    rsl.attribute3 IS NULL
               OR     rsl.attribute3 !=
                      (SELECT oola.line_id
                         FROM oe_order_lines_all oola, mtl_reservations mr
                        WHERE     rsl.po_line_location_id =
                                  mr.supply_source_line_id
                              AND mr.demand_source_line_id = oola.line_id)
                  AND shipment_header_id = pn_shipment_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;                                        --to do : add message
    END;



    PROCEDURE validate_asn (pn_shipment_header_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR)
    IS
        ln_asn_qty             NUMBER;
        ln_asn_rcv             NUMBER;
        ln_fac_asn_qty         NUMBER;
        ln_res_qty             NUMBER;
        ln_rti_qty             NUMBER;
        ln_missing_oe_link     NUMBER;
        ln_missmatch_oe_link   NUMBER;
        ln_count               NUMBER;
        lv_container_num       VARCHAR2 (35);
        lv_bill_of_lading      VARCHAR2 (30);
        lv_vessel_name         VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT ASN_QTY, ASN_RCV, FAC_ASN_QTY,
                   RES_QTY, RTI_QTY, MISSING_OE_LINK,
                   --  MISMATCH_ASN_OE_LINK,
                   CONTAINER_NUM, BILL_OF_LADING, VESSEL_NAME
              INTO ln_asn_qty, ln_asn_rcv, ln_fac_asn_qty, ln_res_qty,
                             ln_rti_qty, ln_missing_oe_link, --   ln_missmatch_oe_link,
                                                             lv_container_num,
                             lv_bill_of_lading, lv_vessel_name
              FROM XXD_RCV_EXP_ASN_HEADERS_V
             WHERE shipment_header_id = pn_shipment_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_err_msg      := 'Shipment header not found.';
        END;

        --Validate fields that are required
        --BOL
        --Container Ref
        IF lv_bill_of_lading IS NULL
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      := 'Bill Of Lading is missing for this ASN';
            RETURN;
        END IF;

        IF lv_container_num IS NULL
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      := 'container num is missing for this ASN';
            RETURN;
        END IF;

        --Validate unique vessel for shipment/container
        SELECT COUNT (1)
          INTO ln_count
          FROM xxd_asn_container_counts_v
         WHERE     container_ref = lv_container_num
               AND bill_of_lading = lv_bill_of_lading
               AND vessel_count IN (0, 1); --6/4 Added support for NULL vessel name returning 0 count

        IF ln_count = 0
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      :=
                   'Container '
                || lv_container_num
                || ': BOL '
                || lv_bill_of_lading
                || ' is not on a unique vessel.';
            RETURN;
        END IF;

        --Validate whole container has been extracted
        SELECT COUNT (1)
          INTO ln_count
          FROM xxd_asn_container_counts_v
         WHERE     container_ref = lv_container_num
               AND bill_of_lading = lv_bill_of_lading
               AND fac_asn_qty = asn_extracted_qty;

        IF ln_count = 0
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      :=
                   'Whole container '
                || lv_container_num
                || ' for BOL '
                || lv_bill_of_lading
                || ' is not extracted.';
            RETURN;
        END IF;

        --check if asn_qty matches ora_asn_qty
        IF ln_asn_qty != ln_fac_asn_qty
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      := 'ASN qty does not match fac inv qty for ASN.';
            RETURN;
        END IF;


        /*
              IF ln_missing_oe_link > 0
              THEN
                 pv_error_stat := 'E';
                 pv_err_msg :=
                    'This ASN has lines missing the custom attribute link to the order line.';
                 RETURN;
              END IF;*/

        IF ln_rti_qty > 0
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      := 'RTI records exist for this ASN ';
            RETURN;
        END IF;

        pv_error_stat   := 'S';
        pv_err_msg      := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      := SQLERRM;
    END;

    PROCEDURE receive_asn (pn_shipment_header_id IN NUMBER, pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2)
    IS
        CURSOR c_header IS
            SELECT *
              FROM XXD_RCV_EXP_ASN_HEADERS_V
             WHERE shipment_header_id = pn_shipment_header_id;

        CURSOR c_line IS
            SELECT SHIPMENT_HEADER_ID, SHIPMENT_LINE_ID, LINE_LOCATION_ID,
                   ITEM_ID, QUANTITY_SHIPPED, QUANTITY_RECEIVED,
                   FAC_ASN_QTY, RECEIVING_ORGANIZATION_ID, SOURCE_DOCUMENT_CODE,
                   SHIP_TO_LOCATION_ID
              FROM XXD_RCV_EXP_ASN_LINES_V
             WHERE shipment_header_id = pn_shipment_header_id;

        ln_header_interface_id   NUMBER;
        ln_rcv_group_id          NUMBER;
        ln_created_by            NUMBER := gn_user_id; --apps.fnd_global.user_id; --1876;                     --BATCH.P2P
        ln_employee_id           NUMBER := gn_employee_id; --apps.fnd_global.employee_id;--134
        ln_cnt                   NUMBER;
        lv_trx_type              VARCHAR2 (10);

        ln_request_id            NUMBER;
        ln_err_stat              VARCHAR2 (10);
        ln_err_msg               VARCHAR2 (2000);
    BEGIN
        debug_msg ('+Receive ASN ');

        FOR h_rec IN c_header
        LOOP
            ln_header_interface_id   := rcv_headers_interface_s.NEXTVAL;
            ln_rcv_group_id          := rcv_interface_groups_s.NEXTVAL;

            debug_msg ('Inserting into RHI');

            INSERT INTO apps.rcv_headers_interface (header_interface_id,
                                                    GROUP_ID,
                                                    processing_status_code,
                                                    receipt_source_code,
                                                    transaction_type,
                                                    auto_transact_code,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    creation_date,
                                                    created_by,
                                                    shipment_num,
                                                    ship_to_organization_id,
                                                    expected_receipt_date,
                                                    employee_id,
                                                    validation_flag,
                                                    vendor_id)
                 VALUES (ln_header_interface_id          --header_interface_id
                                               , ln_rcv_group_id    --group_id
                                                                , 'PENDING' --processing_status_code
                                                                           ,
                         'VENDOR'                        --receipt_source_code
                                 , 'NEW'                    --transaction_type
                                        , 'DELIVER'       --auto_transact_code
                                                   ,
                         SYSDATE                            --last_update_date
                                , ln_created_by               --last_update_by
                                               , USERENV ('SESSIONID') --last_update_login
                                                                      ,
                         SYSDATE                               --creation_date
                                , ln_created_by                   --created_by
                                               , h_rec.shipment_num --shipment_num
                                                                   ,
                         h_rec.to_organization_id    --ship_to_organization_id
                                                 , NVL (h_rec.expected_receipt_date, SYSDATE + 1) --expected_receipt_date
                                                                                                 , ln_employee_id --employee_id
                         , 'Y'                               --validation_flag
                              , h_rec.vendor_id);

            FOR l_rec IN c_line
            LOOP
                SELECT COUNT (1)
                  INTO ln_cnt
                  FROM apps.rcv_shipment_lines rsl, apps.po_line_locations_all plla, apps.fnd_lookup_values flv
                 WHERE     rsl.shipment_line_id = l_rec.shipment_line_id
                       AND plla.line_location_id = rsl.po_line_location_id
                       AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
                       AND flv.LANGUAGE = 'US'
                       AND flv.lookup_code =
                           TO_CHAR (plla.receiving_routing_id)
                       AND flv.view_application_id = 0
                       AND flv.security_group_id = 0
                       AND flv.meaning = 'Standard Receipt';

                IF ln_cnt = 1
                THEN
                    lv_trx_type   := 'DELIVER';
                ELSE
                    lv_trx_type   := 'RECEIVE';
                END IF;

                debug_msg ('Inserting into RTI');

                INSERT INTO apps.rcv_transactions_interface (
                                interface_transaction_id,
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
                                -- unit_of_measure,
                                interface_source_code,
                                item_id,
                                employee_id,
                                auto_transact_code,
                                shipment_header_id,
                                shipment_line_id,
                                ship_to_location_id,
                                receipt_source_code,
                                to_organization_id,
                                source_document_code,
                                -- requisition_line_id,
                                -- req_distribution_id,
                                destination_type_code,
                                -- deliver_to_person_id,
                                --location_id,
                                --deliver_to_location_id,
                                subinventory,
                                shipment_num,
                                -- expected_receipt_date,
                                header_interface_id,
                                validation_flag,
                                vendor_id)
                     VALUES (apps.rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                                      , ln_rcv_group_id --group_id
                                                                                       , h_rec.org_id, SYSDATE --last_update_date
                                                                                                              , ln_created_by --last_updated_by
                                                                                                                             , SYSDATE --creation_date
                                                                                                                                      , ln_created_by --created_by
                                                                                                                                                     , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                            , lv_trx_type --transaction_type
                                                                                                                                                                                         , --Added as per CCR0006788
                                                                                                                                                                                           SYSDATE --transaction_date
                                                                                                                                                                                                  , --End for CCR0006788
                                                                                                                                                                                                    'PENDING' --processing_status_code
                                                                                                                                                                                                             , 'BATCH' --processing_mode_code
                                                                                                                                                                                                                      , 'PENDING' --transaction_status_code
                                                                                                                                                                                                                                 , l_rec.quantity_shipped - NVL (l_rec.quantity_received, 0) --quantity
                                                                                                                                                                                                                                                                                            , -- p_uom                                    --unit_of_measure
                                                                                                                                                                                                                                                                                              --      ,
                                                                                                                                                                                                                                                                                              'RCV' --interface_source_code
                                                                                                                                                                                                                                                                                                   , l_rec.item_id --item_id
                                                                                                                                                                                                                                                                                                                  , ln_employee_id --employee_id
                                                                                                                                                                                                                                                                                                                                  , 'DELIVER' --auto_transact_code
                                                                                                                                                                                                                                                                                                                                             , l_rec.shipment_header_id --shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                       , l_rec.shipment_line_id --shipment_line_id
                                                                                                                                                                                                                                                                                                                                                                                               , l_rec.ship_to_location_id --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                          , 'VENDOR' --receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                    , l_rec.receiving_organization_id --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , l_rec.source_document_code --source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 -- l_rec.requisition_line_id            --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , -- l_rec.requisition_distribution_id    --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   'INVENTORY' --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , -- l_rec.deliver_to_person_id          --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                --                          ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                -- l_rec.location_id                            --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                --                  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                --l_rec.deliver_to_location_id      --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                --                            ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                h_rec.subinventory --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , h_rec.shipment_num --shipment_num
                             , -- h_rec.expected_receipt_date       --expected_receipt_date,
                               --                            ,
                               ln_header_interface_id    --header_interface_id
                                                     , 'Y'   --validation_flag
                                                          , h_rec.vendor_id);
            END LOOP;

            COMMIT;
            debug_msg (
                   'Run rcv_transacton_processor - group ID : '
                || ln_rcv_group_id);

            run_rcv_transaction_processor (ln_rcv_group_id, 'Y', ln_request_id
                                           , ln_err_stat, ln_err_msg);
            COMMIT;
        END LOOP;

        pv_err_stat   := ln_err_stat;
        pv_err_msg    := ln_err_msg;
        debug_msg ('-Receive ASN ');
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
            debug_msg ('+Receive ASN with exception : ' || SQLERRM);
    END;

    PROCEDURE receive_asn (pv_shipment_num IN VARCHAR2, pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2)
    IS
        ln_shipment_header_id   NUMBER;
    BEGIN
        SELECT shipment_header_id
          INTO ln_shipment_header_id
          FROM rcv_shipment_headers
         WHERE shipment_num = pv_shipment_num;

        pv_err_stat   := 'S';
        pv_err_msg    := '';
        receive_asn (ln_shipment_header_id, pv_err_stat, pv_err_msg);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'shipment num is invalid';
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
    END;

    --Public accessable functions

    PROCEDURE reset_rcv_interface (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pn_group_id IN NUMBER)
    IS
    BEGIN
        UPDATE rcv_transactions_interface
           SET processing_status_code   = 'PENDING'
         WHERE GROUP_ID = pn_group_id;

        UPDATE rcv_headers_interface
           SET processing_status_code   = 'PENDING'
         WHERE GROUP_ID = pn_group_id;

        pv_err_stat   := 'S';
        pv_err_msg    := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
    END;

    PROCEDURE do_post_asn_validation (ln_shipment_header_id IN NUMBER, pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2)
    IS
        CURSOR c_rti IS
            SELECT *
              FROM rcv_transactions_interface
             WHERE shipment_header_id = ln_shipment_header_id;
    BEGIN
        debug_msg ('+do_post_asn_validation');
        debug_msg ('Checking for RTI records after receipt');

        --Check for any RTI records
        FOR rti_rec IN c_rti
        LOOP
            Record_error_log (
                rti_rec.shipment_header_id,
                rti_rec.shipment_line_id,
                'E',
                   'After receipt: Record in rcv_transactions_interface with status of : '
                || rti_rec.processing_status_code);
        END LOOP;

        pv_err_stat   := 'S';
        pv_err_msg    := '';
        debug_msg ('-do_post_asn_validation');
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
            debug_msg (
                '-do_post_asn_validation with exception : ' || SQLERRM);
    END;

    PROCEDURE do_Post_process_validation (pv_err_stat   OUT VARCHAR2,
                                          pv_err_msg    OUT VARCHAR2)
    IS
    BEGIN
        --Check that entire ASN is received
        NULL;
    END;

    --Start Added for ver 1.1
    PROCEDURE validate_rtp_run_status (p_shipment_header_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_text OUT VARCHAR2)
    IS
        l_req_id        NUMBER;
        l_req_status    BOOLEAN;
        l_phase         VARCHAR2 (80) := NULL;
        l_status        VARCHAR2 (80) := NULL;
        l_dev_phase     VARCHAR2 (80) := NULL;
        l_dev_status    VARCHAR2 (80) := NULL;
        l_message       VARCHAR2 (500) := NULL;
        l_rti_cnt       NUMBER := 0;
        l_asn_rcv_cnt   NUMBER := 0;
    BEGIN
        debug_msg ('+validate_rtp_run_status');
        x_ret_stat     := fnd_api.g_ret_sts_success;
        x_error_text   := NULL;

        --Verify RTI Records in Running Status
        BEGIN
            SELECT COUNT (1)
              INTO l_rti_cnt
              FROM rcv_transactions_interface rti
             WHERE     1 = 1
                   --AND group_id = p_group_id
                   AND shipment_header_id = p_shipment_header_id
                   AND processing_status_code = 'RUNNING';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_rti_cnt   := -1;
        END;

        IF NVL (l_rti_cnt, 0) > 0
        THEN
            debug_msg (
                'RTI in RUNNING Status - l_asn_rcv_cnt => ' || l_asn_rcv_cnt);

            --Get Schedule\Other RTP running request_id if exists
            BEGIN
                  SELECT MAX (fcr.request_id)
                    INTO l_req_id
                    FROM apps.fnd_concurrent_requests fcr, apps.fnd_concurrent_programs_vl fcp
                   WHERE     fcr.concurrent_program_id =
                             fcp.concurrent_program_id
                         AND fcp.concurrent_program_name = 'RVCTP' --Receiving Transaction Processor
                         AND fcr.phase_code = 'R'             --IN ( 'P', 'R')
                         AND fcr.status_code = 'R'
                         AND fcr.request_date > SYSDATE - 1
                ORDER BY fcr.request_id DESC;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_req_id   := -1;
            END;

            IF NVL (l_req_id, 0) > 0
            THEN
                l_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_req_id,
                        interval     => 10,
                        max_wait     => 0,
                        phase        => l_phase,
                        status       => l_status,
                        dev_phase    => l_dev_phase,
                        dev_status   => l_dev_status,
                        MESSAGE      => l_message);

                IF NVL (l_dev_status, 'ERROR') = 'NORMAL'
                THEN
                    --Verify ASN is 'FULLY RECEIVED'
                    BEGIN
                        SELECT DISTINCT
                               DECODE (rsl.shipment_line_status_code, 'FULLY RECEIVED', 1, 0)
                          INTO l_asn_rcv_cnt
                          FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl
                         WHERE     rsl.shipment_header_id =
                                   rsh.shipment_header_id
                               AND rsh.shipment_header_id =
                                   p_shipment_header_id
                               AND rsh.receipt_source_code = 'VENDOR'
                               AND rsh.attribute4 = 'Y';
                    --AND rsl.shipment_line_status_code = 'FULLY RECEIVED';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_asn_rcv_cnt   := -1;
                    END;

                    IF NVL (l_asn_rcv_cnt, 0) > 0
                    THEN
                        x_ret_stat     := 'S';
                        x_error_text   := NULL;
                    ELSE
                        x_ret_stat   := apps.fnd_api.g_ret_sts_error;
                        x_error_text   :=
                            NVL (
                                l_message,
                                   'Other receiving transaction processor request ended with a status of '
                                || NVL (l_dev_status, 'ERROR'));
                    END IF;

                    RETURN;
                ELSE
                    IF NVL (l_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        x_ret_stat   := 'W';
                    ELSE
                        x_ret_stat   := apps.fnd_api.g_ret_sts_error;
                    END IF;

                    x_error_text   :=
                        NVL (
                            l_message,
                               'The receiving transaction processor request ended with a status of '
                            || NVL (l_dev_status, 'ERROR'));
                    RETURN;
                END IF;            --IF NVL (l_dev_status, 'ERROR') = 'NORMAL'
            END IF;                                   --IF nvl(l_req_id,0) > 0
        END IF;                                     --IF nvl(l_rti_cnt, 0) > 0

        --RTI in ERROR\NORMAL Status
        --Verify ASN is 'FULLY RECEIVED'
        BEGIN
            SELECT DISTINCT
                   DECODE (rsl.shipment_line_status_code, 'FULLY RECEIVED', 1, 0)
              INTO l_asn_rcv_cnt
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl
             WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsh.shipment_header_id = p_shipment_header_id
                   AND rsh.receipt_source_code = 'VENDOR'
                   AND rsh.attribute4 = 'Y';
        --AND rsl.shipment_line_status_code = 'FULLY RECEIVED';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_asn_rcv_cnt   := -1;
        END;

        debug_msg (
            'RTI in ERROR\NORMAL Status - l_asn_rcv_cnt => ' || l_asn_rcv_cnt);

        IF NVL (l_asn_rcv_cnt, 0) > 0
        THEN
            x_ret_stat     := 'S';
            x_error_text   := NULL;
        ELSE
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            x_error_text   :=
                NVL (
                    l_message,
                       'Other receiving transaction processor request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
        END IF;

        debug_msg ('-validate_rtp_run_status');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('EXP-validate_rtp_run_status :' || SQLERRM);
            x_ret_stat     := fnd_api.g_ret_sts_unexp_error;
            x_error_text   := 'EXP - ' || SQLERRM;
    END;

    --End Added for ver 1.1

    --Main access function for Receive ASN Process

    PROCEDURE do_receive (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pv_asn_number IN VARCHAR2:= NULL
                          , pv_debug IN VARCHAR2)
    IS
        CURSOR c_orgs IS
            SELECT DISTINCT mp.organization_id, mp.organization_code, flv.attribute3 subinventory
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.attribute2 = mp.organization_id
                   AND flv.lookup_type = 'XXD_ONT_CUSTOM_PICK_LKP'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                   AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1));

        CURSOR c_asn IS
            SELECT SHIPMENT_HEADER_ID, SHIP_CONFIRM, SHIPMENT_NUM
              FROM XXD_RCV_EXP_ASN_HEADERS_V
             WHERE (SHIPMENT_NUM = pv_asn_number OR pv_asn_number IS NULL);

        ln_shipment_header_id   NUMBER;
        lv_err_msg              VARCHAR2 (2000);
        lv_err_stat             VARCHAR2 (1);
        ex_glb_exception        EXCEPTION;
    BEGIN
        gc_debug_enable   := NVL (gc_debug_enable, NVL (pv_debug, 'N')); --Enable logging
        debug_msg ('Start ASN Receiving process');


        debug_msg ('ORG ID : ' || fnd_global.org_id);
        debug_msg ('USER ID : ' || fnd_global.user_id);
        debug_msg ('LOGIN ID : ' || fnd_global.login_id);
        debug_msg ('CC ID : ' || fnd_global.conc_request_id);
        debug_msg ('EMPLOYEE ID : ' || fnd_global.employee_id);
        debug_msg ('RESP APPL ID : ' || fnd_profile.VALUE ('RESP_APPL_ID'));
        debug_msg ('RESP ID : ' || fnd_profile.VALUE ('RESP_ID'));
        debug_msg ('ASN NUMBER : ' || pv_asn_number);

        --Purge the message log
        purge_status_log (30);

        --Global validations

        --GL open for period/organizatons
        --Subinventory valid for organization

        FOR org_rec IN c_orgs
        LOOP
            debug_msg (
                'Validate GL active for org ' || org_rec.organization_code);

            IF NOT check_org_gl_status (org_rec.organization_id)
            THEN
                lv_err_msg    :=
                    'GL not enabled for org: ' || org_rec.organization_code;
                lv_err_stat   := 'E';

                RAISE ex_glb_exception;
            END IF;

            debug_msg (
                   'Validate subinventory for org '
                || org_rec.organization_code
                || ':'
                || org_rec.subinventory);

            IF NOT validate_org_subinventory (org_rec.organization_id,
                                              org_rec.subinventory)
            THEN
                lv_err_msg    :=
                       'subinventory '
                    || org_rec.subinventory
                    || ' is not valid for org: '
                    || org_rec.organization_code;
                lv_err_stat   := 'E';
                RAISE ex_glb_exception;
            END IF;
        END LOOP;

        FOR rec IN c_asn
        LOOP
            debug_msg ('Validate ASN : ' || rec.shipment_num);
            --Run validation logic
            validate_asn (rec.shipment_header_id, lv_err_stat, lv_err_msg);

            --lv_err_stat := 'S';

            IF lv_err_stat = 'S'
            THEN
                debug_msg ('Receive ASN : ' || rec.shipment_num);
                receive_asn (rec.shipment_header_id, lv_err_stat, lv_err_msg);

                --Start Added for ver 1.1
                IF lv_err_stat <> 'S'
                THEN
                    debug_msg ('Other RTP Run Check : ' || rec.shipment_num);
                    validate_rtp_run_status (rec.shipment_header_id,
                                             lv_err_stat,
                                             lv_err_msg);
                END IF;
            --End Added for ver 1.1
            ELSE
                record_error_log (
                    rec.shipment_header_id,
                    NULL,
                    'E',
                    'Validation of ASN failed : ' || lv_err_msg);
                debug_msg ('Validation of ASN failed : ' || lv_err_msg);
                CONTINUE;
            END IF;

            debug_msg ('Post ASN validation : ' || rec.shipment_num);

            IF lv_err_stat = 'S'
            THEN
                --Validate ASN post receipt/ errors are not fatal and are logged to logging table
                do_post_asn_validation (rec.shipment_header_id,
                                        lv_err_stat,
                                        lv_err_msg);
            ELSE
                record_error_log (rec.shipment_header_id, NULL, 'E',
                                  'Receipt of ASN failed : ' || lv_err_msg);
            END IF;



            --Only split delivery details that have the ship confirm flag set.
            IF lv_err_stat = 'S' AND rec.ship_confirm = 'Y'
            THEN
                debug_msg (
                    'Splitting SO details for ASN: ' || rec.shipment_num);
                split_delivery_details (rec.shipment_header_id,
                                        lv_err_stat,
                                        lv_err_msg);
            END IF;
        END LOOP;

        debug_msg ('Post Process validation');
        do_Post_process_validation (lv_err_stat, lv_err_msg);

        IF lv_err_stat <> 'S'
        THEN
            pv_err_stat   := 1;
            pv_err_stat   := lv_err_stat;
            RETURN;
        END IF;

        pv_err_stat       := 0;
        pv_err_msg        := '';

        debug_msg ('End ASN Receiving process');
    EXCEPTION
        WHEN ex_glb_exception
        THEN
            pv_err_stat   := 2;
            pv_err_msg    := lv_err_msg;
            debug_msg ('End ASN Receiving process with exception');
        WHEN OTHERS
        THEN
            pv_err_stat   := 2;
            pv_err_msg    := SQLERRM;
            debug_msg ('End ASN Receiving process with exception');
    END;
END XXD_PO_ASN_RECEIVING_PKG;
/
