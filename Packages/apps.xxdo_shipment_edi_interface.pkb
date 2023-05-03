--
-- XXDO_SHIPMENT_EDI_INTERFACE  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SHIPMENT_EDI_INTERFACE"
AS
    /******************************************************************************/
    /* Name       : Package XXDO_SHIPMENT_EDI_INTERFACE
    /* Created by : Infosys Ltd
    /* Created On : 2/28/2017
    /* Description: Package to build API to create Shipment EDI.
    /******************************************************************************/
    /**/
    /******************************************************************************/
    /* Name         : WRITE_MESSAGE
    /* Type          : PROCEDURE
    /* Description  : Procedure to write log
    /******************************************************************************/
    PROCEDURE WRITE_MESSAGE (P_message IN VARCHAR2)
    IS
    BEGIN
        IF g_log = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, P_message);
        ELSE
            DBMS_OUTPUT.put_line (P_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END write_message;

    /******************************************************************************/
    /* Name         : VALID_EDI_CUST
    /* Type          : FUNCTION (Return : Boolean)
    /* Description  : Function to validate EDI customer or not
    /******************************************************************************/
    FUNCTION VALID_EDI_CUST (p_cust_id IN NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        write_message ('Check Cusomer ID ' || p_cust_id || ' is Valid?');

        /*Check if customer is valid EDI customer or not only if cursor is not open because if cursor is open it has been already checked in CONC_MAIN_WRAP */

        IF cur_edi_cust%ISOPEN
        THEN
            write_message ('Conc Pgm - Valid EDI Customer ');
            RETURN TRUE;
        ELSE
            FOR rec IN cur_edi_cust
            LOOP
                IF rec.cust_account_id = p_cust_id
                THEN
                    write_message (
                        'Valid EDI Customer = ' || rec.account_number);
                    RETURN TRUE;
                END IF;
            END LOOP;
        END IF;

        write_message ('Invalid EDI Customer ');
        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        RETURN FALSE;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_message ('Error ' || SQLERRM);
            WRITE_MESSAGE (LPAD ('.', 58, '.'));
            RETURN FALSE;
    END valid_edi_cust;

    /******************************************************************************/
    /* Name         : VALID_PRONUM_REQ
    /* Type          : FUNCTION (Return : Boolean)
    /* Description  : Function to check PRO number is required or not
    /******************************************************************************/
    FUNCTION VALID_PRONUM_REQ (p_cust_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_pronum_req   CHAR (1);
    BEGIN
        /*Check if customer required PRO number or not*/
        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        write_message (
            'PRO Number Required for Cusomer ID ' || p_cust_id || ' ?');

        SELECT enabled_flag
          INTO l_pronum_req
          FROM custom.do_edi_lookup_values
         WHERE     lookup_type = '856_PRONUM_REQ'
               AND enabled_flag = 'Y'
               AND lookup_code = p_cust_id
               AND ROWNUM < 2;

        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_message ('PRO Number Is Not Required ');
            WRITE_MESSAGE (LPAD ('.', 58, '.'));
            RETURN FALSE;
        WHEN OTHERS
        THEN
            write_message ('Error ' || SQLERRM);
            WRITE_MESSAGE (LPAD ('.', 58, '.'));
            RETURN FALSE;
    END valid_pronum_req;

    /******************************************************************************/
    /* Name         : VALID_LOADID_REQ
    /* Type          : FUNCTION (Return : Boolean)
    /* Description  : Function to check LoadID is required or not
    /******************************************************************************/
    FUNCTION VALID_LOADID_REQ (p_cust_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_load_id_req   CHAR (1);
    BEGIN
        /*Check if customer required Load ID or not*/
        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        write_message (
            'Load ID Required for Cusomer ID ' || p_cust_id || ' ?');

        SELECT enabled_flag
          INTO l_load_id_req
          FROM custom.do_edi_lookup_values
         WHERE     lookup_type = '856_LOADID_REQ'
               AND enabled_flag = 'Y'
               AND lookup_code = p_cust_id
               AND ROWNUM < 2;

        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_message ('Load ID Is Not Required ');
            WRITE_MESSAGE (LPAD ('.', 58, '.'));
            RETURN FALSE;
        WHEN OTHERS
        THEN
            write_message ('Error ' || SQLERRM);
            WRITE_MESSAGE (LPAD ('.', 58, '.'));
            RETURN FALSE;
    END valid_loadid_req;

    /******************************************************************************/
    /* Name         : GET_CARTON_INFO
    /* Type          : PROCEDURE (Out  : x_carton,x_volume and  x_weight )
    /* Description  : PROCEDURE to get carton,volume and weight for delivery ID
    /******************************************************************************/
    PROCEDURE GET_CARTON_INFO (P_ORG_ID IN NUMBER, P_DELV_ID IN NUMBER, x_carton OUT NUMBER
                               , x_volume OUT NUMBER, x_weight OUT NUMBER)
    IS
        l_org_id   VARCHAR2 (10);
        l_hj_org   BOOLEAN;
        l_volume   NUMBER;
        l_weight   NUMBER;
        l_carton   NUMBER;
    BEGIN
        /*Get Carton details in delivery like no. of cartons, weight of carton and volume*/
        WRITE_MESSAGE (LPAD ('.', 58, '.'));
        l_volume   := 0;
        l_weight   := 0;
        l_carton   := 0;

        /* Check if delivery is US1 delivery or not*/
        BEGIN
            SELECT flv.lookup_code
              INTO l_org_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.lookup_code
                   AND mp.organization_id = P_ORG_ID;

            write_message ('Delivery belongs to High Jump Org ' || l_org_id);

            l_hj_org   := TRUE;
            WRITE_MESSAGE (LPAD ('.', 58, '.'));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                write_message ('Not HJ Org');
                l_hj_org   := FALSE;
                WRITE_MESSAGE (LPAD ('.', 58, '.'));
            WHEN OTHERS
            THEN
                write_message ('Error ' || SQLERRM);
                l_hj_org   := FALSE;
                WRITE_MESSAGE (LPAD ('.', 58, '.'));
        END;

        /*If delivery fulfilled in high jump then get details from interface table else calculate it from delivery.*/
        IF l_hj_org
        THEN
            BEGIN
                SELECT SUM (NVL (cartoni.weight, 0)), SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                  INTO l_weight, l_volume
                  FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                 WHERE     1 = 1
                       AND ordi.order_number = P_DELV_ID
                       AND ordi.process_status = 'PROCESSED'
                       AND ordi.shipment_number = cartoni.shipment_number
                       AND ordi.order_number = cartoni.order_number
                       AND cartoni.process_status = 'PROCESSED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_message ('HJ Get Volume and Weight ' || SQLERRM);
                    l_volume   := 0;
                    l_weight   := 0;
            END;
        ELSE
            l_volume   := 0;

            --get volume
            BEGIN
                SELECT SUM (volume)
                  INTO l_volume
                  FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                 WHERE     wda.delivery_id = P_DELV_ID
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND wdd.source_code = 'WSH'
                       AND wdd.container_flag = 'Y';

                IF NVL (l_volume, 0) = 0
                THEN
                    SELECT SUM (NVL (msib.unit_volume, 385) * wdd.shipped_quantity)
                      INTO l_volume
                      FROM mtl_system_items_b msib, wsh_delivery_details wdd, wsh_delivery_assignments wda
                     WHERE     wda.delivery_id = P_DELV_ID
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND msib.organization_id = wdd.organization_id
                           AND msib.inventory_item_id = wdd.inventory_item_id
                           AND wdd.source_code = 'OE';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_message ('Get Volume - Error ' || SQLERRM);
                    l_volume   := 0;
            END;

            -- get weight
            BEGIN
                l_weight   := 0;

                SELECT SUM (NVL (msib.unit_weight, 2) * wdd.shipped_quantity)
                  INTO l_weight
                  FROM xxd_common_items_v msib, wsh_delivery_details wdd, wsh_delivery_assignments wda
                 WHERE     wda.delivery_id = P_DELV_ID
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND msib.organization_id = wdd.organization_id
                       AND msib.inventory_item_id = wdd.inventory_item_id
                       AND wdd.source_code = 'OE';
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_message ('Get Weight - Error ' || SQLERRM);
                    l_weight   := 0;
            END;
        END IF;

        --get no. of cartons
        BEGIN
            l_carton   := 0;

            SELECT COUNT (1)
              INTO l_carton
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     wda.delivery_id = P_DELV_ID
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_code = 'WSH'
                   AND wdd.container_flag = 'Y'
                   AND EXISTS
                           (SELECT NULL
                              FROM wsh.wsh_delivery_details item, wsh.wsh_delivery_assignments cont
                             WHERE     cont.delivery_detail_id =
                                       item.delivery_detail_id
                                   AND cont.parent_delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND item.container_flag = 'N');
        EXCEPTION
            WHEN OTHERS
            THEN
                write_message ('Get Carton - Error ' || SQLERRM);
                l_carton   := 0;
        END;

        /*Display Cartons, weight and volume*/
        write_message ('No. of Cartons ' || l_carton);
        write_message ('Weight of Cartons ' || l_weight);
        write_message ('Volume of Cartons ' || l_volume);

        x_volume   := l_volume;
        x_weight   := l_weight;
        x_carton   := l_carton;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_message ('Get Carton Info - Error ' || SQLERRM);
            x_volume   := l_volume;
            x_weight   := l_weight;
            x_carton   := l_carton;
    END get_carton_info;



    /******************************************************************************/
    /* Name         : CREATE_EDI
    /* Type          : PROCEDURE (Out : P_SHIPMENT_ID)
    /* Description  : PROCEDURE to Create EDI (API) called from other interface
    /******************************************************************************/

    PROCEDURE CREATE_EDI (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ORG_ID IN NUMBER, P_BOL_TRACK_NUMBER IN VARCHAR2, P_PRO_NUMBER IN VARCHAR2, P_LOAD_ID IN VARCHAR2
                          , P_SCAC IN VARCHAR2, P_SHIPMENT_ID OUT NUMBER)
    IS
        /*Cursor to get information for given Waybill or Tracking number*/
        CURSOR cur_ship IS
            SELECT /*+ PARALLEL(WND,32) */
                   DISTINCT ooh.sold_to_org_id, ooh.SHIP_TO_ORG_ID, hcsu.LOCATION,
                            --ooh.attribute3,
                            hps.location_id ship_to_location, ool.ship_from_org_id, ooh.attribute5 brand,
                            dbrand.brand_code brand_code, wcs.freight_code, wdd.tracking_number,
                            --wdd.ship_method_code,
                            wnd.waybill, wnd.attribute1 pro_number, wnd.attribute2 SCAC,
                            wnd.attribute15 load_id
              --ool.*
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, apps.wsh_new_deliveries wnd,
                   apps.WSH_CARRIER_SHIP_METHODS wcs, apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool,
                   apps.hz_cust_acct_sites_all hcas, apps.hz_cust_site_uses_all hcsu, apps.hz_party_sites hps,
                   apps.hz_locations hl, do_custom.do_brands dbrand
             WHERE     1 = 1
                   AND ool.HEADER_ID = ooh.HEADER_ID
                   AND ool.LINE_ID = wdd.source_line_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND dbrand.brand_name = ooh.attribute5
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND hl.LOCATION_id = hps.LOCATION_id
                   AND wcs.ship_method_code = wdd.ship_method_code
                   AND hcsu.site_use_id = ooh.ship_TO_ORG_ID
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND ool.ship_from_org_id =
                       NVL (P_ORG_ID, ool.ship_from_org_id)
                   AND wdd.source_code = 'OE'
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.released_status = 'C'
                   AND wnd.organization_id = P_ORG_ID
                   AND (NVL (wdd.TRACKING_NUMBER, '-1') = NVL (NVL (P_BOL_TRACK_NUMBER, wdd.TRACKING_NUMBER), '-1') OR NVL (wnd.waybill, '-1') = NVL (NVL (P_BOL_TRACK_NUMBER, wnd.waybill), '-1'))
                   AND NVL (wnd.attribute1, '-1') =
                       NVL (NVL (P_PRO_NUMBER, wnd.attribute1), '-1')
                   AND NVL (wnd.attribute2, '-1') =
                       NVL (NVL (P_SCAC, wnd.attribute2), '-1')
                   AND NVL (wnd.attribute15, '-1') =
                       NVL (NVL (P_LOAD_ID, wnd.attribute15), '-1')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM DO_EDI.DO_EDI856_PICK_TICKETS edi
                             WHERE edi.delivery_id = wda.delivery_id);

        /*Cursor to get distinct delivery ID's associated with given parameters*/
        CURSOR cur_delv (c_bol_track_num   IN VARCHAR2,
                         c_cust_id         IN NUMBER,
                         c_pro_num         IN VARCHAR2,
                         c_scac            IN VARCHAR2,
                         c_load_id         IN VARCHAR2,
                         c_ship_to         IN NUMBER)
        IS
            SELECT DISTINCT wda.DELIVERY_ID
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, apps.wsh_new_deliveries wnd,
                   apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     1 = 1
                   AND ool.HEADER_ID = ooh.HEADER_ID
                   AND ool.LINE_ID = wdd.source_line_id
                   AND wdd.source_code = 'OE'
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND wnd.status_code = 'CL'
                   AND wdd.customer_id = c_cust_id
                   AND ooh.SHIP_TO_ORG_ID = c_ship_to
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM do_edi.do_edi856_pick_tickets dept
                             WHERE dept.delivery_id = wnd.delivery_id)
                   AND (wdd.tracking_number = c_bol_track_num OR wnd.waybill = c_bol_track_num)
                   AND NVL (wnd.attribute1, '-1') =
                       NVL (NVL (c_pro_num, wnd.attribute1), '-1')
                   AND NVL (wnd.attribute2, '-1') =
                       NVL (NVL (c_scac, wnd.attribute2), '-1')
                   AND NVL (wnd.attribute15, '-1') =
                       NVL (NVL (c_load_id, wnd.attribute15), '-1')
                   AND wdd.organization_id = p_org_id;

        /*Cursor to get UOM , ordered qty details*/
        CURSOR c_delivery_rows (c_delivery_id IN NUMBER)
        IS
              SELECT lines.header_id, MAX (lines.weight_uom_code) weight_uom_code, MAX (lines.volume_uom_code) volume_uom_code,
                     MAX (lines.shipping_quantity_uom) shipping_quantity_uom, MAX (lines.intmed_ship_to_org_id) intmed_ship_to_org_id, SUM (lines.ordered_quantity) ordered_quantity,
                     SUM (lines.shipped_quantity) shipped_quantity
                FROM (  SELECT oola.header_id, wnd.weight_uom_code, wnd.volume_uom_code,
                               oola.shipping_quantity_uom, oola.intmed_ship_to_org_id, oola.ordered_quantity,
                               SUM (wdd.requested_quantity) shipped_quantity
                          FROM oe_order_lines_all oola, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                               wsh_new_deliveries wnd
                         WHERE     wnd.delivery_id = c_delivery_id
                               AND wda.delivery_id = wnd.delivery_id
                               AND wdd.delivery_detail_id =
                                   wda.delivery_detail_id
                               AND wdd.source_code = 'OE'
                               AND oola.line_id = wdd.source_line_id
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM do_edi.do_edi856_pick_tickets dept
                                         WHERE dept.delivery_id = wnd.delivery_id) /* prevents insert of existing deliveries */
                      GROUP BY oola.header_id, oola.line_id, wnd.weight_uom_code,
                               wnd.volume_uom_code, oola.shipping_quantity_uom, oola.intmed_ship_to_org_id,
                               oola.ordered_quantity) lines
            GROUP BY lines.header_id;


        X_ERROR_CODE        NUMBER;
        X_ERROR_MESSAGE     VARCHAR2 (200);


        l_scac_des          VARCHAR2 (80);
        l_scac              VARCHAR2 (10);
        l_volume            NUMBER;
        l_weight            NUMBER;
        l_carton            NUMBER;
        l_tracking_number   VARCHAR2 (30);
        x_shipment_id       NUMBER;
        p_delivery_id       NUMBER;
        l_edi_valid         BOOLEAN;
        e_invalid           EXCEPTION;
    BEGIN
        WRITE_MESSAGE (LPAD ('-', 78, '-'));
        write_message ('CREATE_EDI');
        write_message ('P_ORG_ID :' || P_ORG_ID);
        write_message ('P_BOL_TRACK_NUMBER :' || P_BOL_TRACK_NUMBER);
        write_message ('P_PRO_NUMBER :' || P_PRO_NUMBER);
        write_message ('P_LOAD_ID :' || P_LOAD_ID);
        write_message ('P_SCAC :' || P_SCAC);

        /*Verify if Waybill/Tracking number exists*/
        IF P_BOL_TRACK_NUMBER IS NULL
        THEN
            p_out_error_code   := 2;
            p_out_error_buff   :=
                'Required Waybill Number or Tracking Number';
            RAISE e_invalid;
        END IF;

        P_SHIPMENT_ID      := -1;

        /*Open shipment cursor*/
        FOR rec_ship IN cur_ship
        LOOP
            /*Check for valid EDI customer; If not do not proceed further nad mark call as error*/
            IF NOT valid_edi_cust (rec_ship.sold_to_org_id)
            THEN
                write_message (
                    'Error - Not EDI Customer ID ' || rec_ship.sold_to_org_id);
                X_ERROR_CODE      := 2;
                X_ERROR_MESSAGE   := 'Not Valid EDI Customer';
                l_edi_valid       := FALSE;
            ELSE
                l_edi_valid   := TRUE;
            END IF;

            /*Check for required PRO number; If not do not proceed further nad mark call as error*/

            IF l_edi_valid
            THEN
                IF     valid_pronum_req (rec_ship.sold_to_org_id)
                   AND rec_ship.pro_number IS NULL
                THEN
                    write_message (
                           'Error - Required PRO Number for Customer ID '
                        || rec_ship.sold_to_org_id);
                    X_ERROR_CODE      := 2;
                    X_ERROR_MESSAGE   :=
                        'Missing PRO Number for EDI Customer';
                    l_edi_valid       := FALSE;
                ELSE
                    l_edi_valid   := TRUE;
                END IF;
            END IF;

            /*Check for required Load ID; If not do not proceed further nad mark call as error*/

            IF l_edi_valid
            THEN
                IF     valid_loadid_req (rec_ship.sold_to_org_id)
                   AND rec_ship.load_id IS NULL
                THEN
                    write_message (
                           'Error - Required Load ID for Customer ID '
                        || rec_ship.sold_to_org_id);
                    X_ERROR_CODE      := 2;
                    X_ERROR_MESSAGE   := 'Missing Load ID for EDI Customer';
                    l_edi_valid       := FALSE;
                ELSE
                    l_edi_valid   := TRUE;
                END IF;
            END IF;

            /*Check for SCAC Code; If not do not proceed further nad mark call as error*/

            IF l_edi_valid
            THEN
                /*If user not updated SCAC code thenassign frieght_code*/
                IF rec_ship.SCAC IS NULL
                THEN
                    l_scac   := rec_ship.freight_code;

                    IF l_scac IS NULL
                    THEN
                        write_message (
                               'Error - Required SCAC/Carrier information '
                            || rec_ship.sold_to_org_id);
                        X_ERROR_CODE      := 2;
                        X_ERROR_MESSAGE   :=
                            'Missing SCAC code for deliveries';
                        l_edi_valid       := FALSE;
                    END IF;
                ELSE
                    --Assign cursor SCAC code to variable
                    l_scac        := rec_ship.SCAC;
                    l_edi_valid   := TRUE;
                END IF;

                BEGIN
                    SELECT description
                      INTO l_scac_des
                      FROM apps.org_freight_tl
                     WHERE     freight_code = l_scac
                           AND organization_id = P_ORG_ID
                           AND LANGUAGE = USERENV ('LANG')
                           AND NVL (disable_date, SYSDATE + 1) > SYSDATE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_scac_des   := l_scac;
                END;
            END IF;

            /*If all validation passed then create EDI Shipment record for given shipping information*/
            IF l_edi_valid
            THEN
                x_shipment_id   := NULL;

                do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                        1,
                                        x_shipment_id);

                /*Get Shipment ID*/

                /*SELECT DO_EDI856_SHIPMENTS_SEQ.NEXTVAL
                  INTO x_shipment_id
                  FROM DUAL;*/

                /*Create Shipment record*/

                /*If LTL or Wholsale orders where Waybill number awailable then use only Waybill number ; for small parcel use tracking number */
                IF rec_ship.WAYBILL IS NOT NULL
                THEN
                    l_tracking_number   := NULL;
                ELSE
                    l_tracking_number   := rec_ship.tracking_number;
                END IF;

                INSERT INTO do_edi.do_edi856_shipments (shipment_id, customer_id, ship_to_org_id, location_id, organization_id, routing_status, tracking_number, WAYBILL, PRO_NUMBER, CARRIER, CARRIER_SCAC, LOAD_ID, comments, ship_confirm_date, created_by
                                                        , last_updated_by)
                     VALUES (x_shipment_id, rec_ship.sold_to_org_id, rec_ship.SHIP_TO_ORG_ID, rec_ship.ship_to_location, rec_ship.ship_from_org_id, 'C', l_tracking_number, rec_ship.waybill, rec_ship.pro_number, l_scac_des, l_scac, SUBSTRB (rec_ship.load_id, 1, 10), DECODE (g_log, 'N', 'API Call ' || SYSDATE || '-' || TO_CHAR (fnd_global.conc_request_id), 'Program EDI Creation ' || TO_CHAR (fnd_global.conc_request_id)), SYSDATE, NVL (fnd_profile.VALUE ('USER_ID'), -1)
                             , NVL (fnd_profile.VALUE ('USER_ID'), -1));

                write_message (
                       'Created EDI for Tracking number = '
                    || rec_ship.tracking_number
                    || ' Waybill = '
                    || rec_ship.waybill
                    || ' Shipment_ID = '
                    || x_shipment_id);


                /*if shipment record successfully created then proceed to generate pick ticket records*/
                IF x_shipment_id IS NOT NULL
                THEN
                    FOR rec_delv
                        IN cur_delv (
                               NVL (rec_ship.waybill,
                                    rec_ship.tracking_number),
                               rec_ship.sold_to_org_id,
                               rec_ship.pro_number,
                               rec_ship.SCAC,
                               rec_ship.load_id,
                               rec_ship.SHIP_TO_ORG_ID)
                    LOOP
                        p_delivery_id   := rec_delv.DELIVERY_ID;

                        write_message (
                            'Delivery ID = ' || rec_delv.DELIVERY_ID);

                        FOR c_delivery
                            IN c_delivery_rows (rec_delv.DELIVERY_ID)
                        LOOP
                            write_message ('insert pick ticket record');

                            /*Get carton, weight and volume details for given delivery*/

                            get_carton_info (P_ORG_ID    => P_ORG_ID,
                                             P_DELV_ID   => p_delivery_id,
                                             x_carton    => l_carton,
                                             x_volume    => l_volume,
                                             x_weight    => l_weight);

                            /*Create pick ticket record*/
                            INSERT INTO do_edi.do_edi856_pick_tickets (
                                            shipment_id,
                                            delivery_id,
                                            weight,
                                            number_cartons,
                                            volume,
                                            ordered_qty,
                                            shipped_qty,
                                            source_header_id,
                                            intmed_ship_to_org_id,
                                            created_by,
                                            last_updated_by,
                                            shipment_key,
                                            weight_uom,
                                            volume_uom,
                                            shipped_qty_uom)
                                     VALUES (
                                                x_shipment_id,
                                                p_delivery_id,
                                                l_weight,
                                                l_carton,
                                                l_volume,
                                                c_delivery.ordered_quantity,
                                                c_delivery.shipped_quantity,
                                                c_delivery.header_id,
                                                c_delivery.intmed_ship_to_org_id,
                                                NVL (
                                                    fnd_profile.VALUE (
                                                        'USER_ID'),
                                                    -1),
                                                NVL (
                                                    fnd_profile.VALUE (
                                                        'USER_ID'),
                                                    -1),
                                                x_shipment_id || rec_ship.brand_code,
                                                /*Weight UOM*/
                                                DECODE (
                                                    NVL (
                                                        c_delivery.weight_uom_code,
                                                        'LB'),
                                                    'Lbs', 'LB',
                                                    'LBS', 'LB',
                                                    'LB', 'LB',
                                                    SUBSTR (
                                                        c_delivery.weight_uom_code,
                                                        1,
                                                        2)),
                                                /*volume UOM*/
                                                DECODE (
                                                    NVL (
                                                        c_delivery.volume_uom_code,
                                                        'CI'),
                                                    'CI', 'CI',
                                                    'IN3', 'CI',
                                                    SUBSTR (
                                                        c_delivery.volume_uom_code,
                                                        1,
                                                        2)),
                                                /*shipped_qty_uom*/
                                                DECODE (
                                                    NVL (
                                                        c_delivery.shipping_quantity_uom,
                                                        'EA'),
                                                    'EA', 'EA',
                                                    SUBSTR (
                                                        c_delivery.shipping_quantity_uom,
                                                        1,
                                                        2)));

                            EXIT;
                        END LOOP;

                        write_message (
                               'Created EDI for Tracking number = '
                            || rec_ship.tracking_number
                            || ' Shipment_ID = '
                            || x_shipment_id
                            || ' Deliver ID = '
                            || rec_delv.DELIVERY_ID);
                    END LOOP;
                END IF;

                P_SHIPMENT_ID   := x_shipment_id;
            END IF;                                           --Valid Customer
        END LOOP;

        /*Commit only if it is API call else concurrent program will decide based on condition*/

        IF g_log = 'N'
        THEN
            COMMIT;
        END IF;

        p_out_error_code   := X_ERROR_CODE;
        p_out_error_buff   := X_ERROR_MESSAGE;
        WRITE_MESSAGE (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_message ('Error ' || SQLERRM);
            X_ERROR_CODE       := 2;
            X_ERROR_MESSAGE    := SQLERRM;
            p_out_error_code   := X_ERROR_CODE;
            p_out_error_buff   := X_ERROR_MESSAGE;

            IF g_log = 'N'
            THEN
                ROLLBACK;
            END IF;

            WRITE_MESSAGE (LPAD ('-', 78, '-'));
    END CREATE_EDI;

    /******************************************************************************/
    /* Name         : RECREATE_EDI
    /* Type          : PROCEDURE
    /* Description  : PROCEDURE to delete EDI records to recreate it
    /******************************************************************************/

    PROCEDURE RECREATE_EDI (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ORG_ID IN NUMBER
                            , P_BOL_TRACK_NUMBER IN VARCHAR2)
    IS
        ln_ship_id        NUMBER;
        X_ERROR_CODE      NUMBER;
        X_ERROR_MESSAGE   VARCHAR2 (200);
    BEGIN
        --Getting the shipment_id based on tracking number or waybill number
        WRITE_MESSAGE (LPAD ('-', 78, '-'));
        write_message (
               'Recreate Shipment for waybill/tracking number'
            || P_BOL_TRACK_NUMBER);

        FOR rec_ship_id
            IN (SELECT shipment_id
                  FROM do_edi.do_edi856_shipments
                 WHERE     organization_id = P_ORG_ID
                       AND (tracking_number = P_BOL_TRACK_NUMBER OR waybill = P_BOL_TRACK_NUMBER))
        LOOP
            write_message ('Found Shipment ID ' || rec_ship_id.shipment_id);


            INSERT INTO XXDO.XXDO_EDI856_PICK_TICKETS_LOG
                (SELECT *
                   FROM do_edi.do_edi856_pick_tickets
                  WHERE SHIPMENT_ID = rec_ship_id.shipment_id);

            INSERT INTO XXDO.XXDO_EDI856_SHIPMENTS_LOG
                (SELECT *
                   FROM do_edi.do_edi856_shipments
                  WHERE SHIPMENT_ID = rec_ship_id.shipment_id);


            DELETE FROM do_edi.do_edi856_pick_tickets
                  WHERE SHIPMENT_ID = rec_ship_id.shipment_id;

            DELETE FROM do_edi.do_edi856_shipments
                  WHERE SHIPMENT_ID = rec_ship_id.shipment_id;
        END LOOP;

        --      COMMIT;
        WRITE_MESSAGE (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_message ('Error ' || SQLERRM);
            X_ERROR_CODE       := 2;
            X_ERROR_MESSAGE    := SQLERRM;
            p_out_error_code   := X_ERROR_CODE;
            p_out_error_buff   := X_ERROR_MESSAGE;
            WRITE_MESSAGE (LPAD ('-', 78, '-'));
    END RECREATE_EDI;

    /******************************************************************************/
    /* Name         : CONC_MAIN_WRAP
    /* Type          : PROCEDURE
    /* Description  : PROCEDURE wrapper to build concurrent program and run in batch
    /******************************************************************************/
    PROCEDURE CONC_MAIN_WRAP (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_RUN_MODE IN VARCHAR2, P_RUN_TYPE IN VARCHAR2, P_ORG_ID IN NUMBER, P_BOL_TRACK_NUMBER IN VARCHAR2, P_PRO_NUMBER IN VARCHAR2, P_LOAD_ID IN VARCHAR2, P_SCAC IN VARCHAR2
                              , P_LUKBCK_DAYS IN NUMBER DEFAULT 30)
    IS
        /*Cursor to get all tracking/waybill number which are missing EDI records*/
        CURSOR cur_miss_edi (c_cust_id IN NUMBER)
        IS
            SELECT DISTINCT ooh.sold_to_org_id, ooh.SHIP_TO_ORG_ID, ool.ship_from_org_id,
                            ooh.attribute5 brand, dbrand.brand_code brand_code, wdd.tracking_number,
                            wnd.waybill, wnd.attribute1 pro_number, wnd.attribute2 SCAC,
                            wnd.attribute15 load_id
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, apps.wsh_new_deliveries wnd,
                   apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, do_custom.do_brands dbrand
             WHERE     1 = 1
                   AND ool.HEADER_ID = ooh.HEADER_ID
                   AND ool.LINE_ID = wdd.source_line_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND dbrand.brand_name = ooh.attribute5
                   AND ool.ship_from_org_id =
                       NVL (P_ORG_ID, ool.ship_from_org_id)
                   AND ooh.sold_to_org_id = c_cust_id
                   AND wdd.source_code = 'OE'
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.released_status = 'C'
                   AND (wdd.tracking_number IS NOT NULL OR wnd.waybill IS NOT NULL)
                   AND ool.last_update_date > SYSDATE - g_lukbck_days
                   AND NOT EXISTS
                           (SELECT 1
                              FROM DO_EDI.DO_EDI856_PICK_TICKETS edi
                             WHERE edi.delivery_id = wda.delivery_id);



        l_edi_cust        edi_cust_t;

        X_ERROR_CODE      NUMBER;
        X_ERROR_MESSAGE   VARCHAR2 (200);
        X_SHIPMENT_ID     NUMBER;
        c_limit           NUMBER := 100;
        e_invalid         EXCEPTION;
    BEGIN
        /*Set global variable to enable write message*/
        g_log              := 'Y';

        /*If Look back days is not null else take default 30 days*/
        IF P_LUKBCK_DAYS IS NOT NULL
        THEN
            g_lukbck_days   := P_LUKBCK_DAYS;
        END IF;

        /*Get parameter details*/
        WRITE_MESSAGE (LPAD ('+', 78, '+'));
        write_message ('Program Run Mode in ' || P_RUN_MODE);
        write_message ('Program Run Type  :' || P_RUN_TYPE);
        write_message ('Organization ID :' || P_ORG_ID);
        write_message ('Waybill/Tracking Number :' || P_BOL_TRACK_NUMBER);
        write_message ('PRO Number :' || P_PRO_NUMBER);
        write_message ('Load ID :' || P_LOAD_ID);
        write_message ('SCAC/Freight Code :' || P_SCAC);
        write_message (
            'Lookback Days :' || NVL (P_LUKBCK_DAYS, g_lukbck_days));

        /*IF run mode is Batch*/

        IF P_RUN_MODE = 'BATCH'
        THEN
            /*Fetch all EDI customer details on bulk mode*/
            OPEN cur_edi_cust;

            LOOP
                FETCH cur_edi_cust BULK COLLECT INTO l_edi_cust LIMIT c_limit;

                EXIT WHEN l_edi_cust.COUNT = 0;

                FOR i IN l_edi_cust.FIRST .. l_edi_cust.LAST
                LOOP
                    write_message (
                           'Customer Account = '
                        || l_edi_cust (i).account_number
                        || ' Customer ID = '
                        || l_edi_cust (i).cust_account_id);

                    /*Get any missing EDI records for EDI customer*/

                    FOR rec_edi
                        IN cur_miss_edi (l_edi_cust (i).cust_account_id)
                    LOOP
                        write_message (
                            'Calling XXDO_SHIPMENT_EDI_CREATE Procedure');

                        write_message (
                            'Ship From Org ID :' || rec_edi.ship_from_org_id);
                        write_message (
                               'Waybill/Tracking Number :'
                            || NVL (rec_edi.waybill, rec_edi.tracking_number));
                        write_message ('PRO Number :' || rec_edi.PRO_NUMBER);
                        write_message ('Load ID :' || rec_edi.LOAD_ID);
                        write_message ('SCAC/Freight Code :' || rec_edi.SCAC);

                        /*Call procedue CREATE_EDI for Waybill/pro number/load id /scac*/
                        CREATE_EDI (
                            p_out_error_code     => X_ERROR_CODE,
                            p_out_error_buff     => X_ERROR_MESSAGE,
                            P_ORG_ID             => rec_edi.ship_from_org_id,
                            P_BOL_TRACK_NUMBER   =>
                                NVL (rec_edi.waybill,
                                     rec_edi.tracking_number),
                            P_PRO_NUMBER         => rec_edi.PRO_NUMBER,
                            P_LOAD_ID            => rec_edi.LOAD_ID,
                            P_SCAC               => rec_edi.SCAC,
                            P_SHIPMENT_ID        => X_SHIPMENT_ID);

                        IF X_ERROR_CODE = 2
                        THEN
                            p_out_error_code   := 1;
                            p_out_error_buff   := X_ERROR_MESSAGE;
                            write_message ('Error ' || X_ERROR_MESSAGE);
                        END IF;
                    END LOOP;
                END LOOP;
            END LOOP;

            CLOSE cur_edi_cust;
        ELSE
            /*Atleast waybill number should be provided if it is not Batch Mode run*/
            IF P_BOL_TRACK_NUMBER IS NULL
            THEN
                p_out_error_code   := 2;
                p_out_error_buff   :=
                    'Required Waybill Number or Tracking Number';
                RAISE e_invalid;
            END IF;

            IF P_RUN_TYPE = 'RECREATE'
            THEN
                write_message ('Calling RECREATE_EDI Procedure');
                /*Call RECREATE_EDI to delete EDI shipment record */
                RECREATE_EDI (p_out_error_code => X_ERROR_CODE, p_out_error_buff => X_ERROR_MESSAGE, P_ORG_ID => P_ORG_ID
                              , P_BOL_TRACK_NUMBER => P_BOL_TRACK_NUMBER);

                IF X_ERROR_CODE = 2
                THEN
                    p_out_error_code   := 2;
                    p_out_error_buff   := X_ERROR_MESSAGE;
                    RAISE e_invalid;
                END IF;
            END IF;

            write_message ('Calling CREATE_EDI Procedure');

            /*Call procedue CREATE_EDI for Waybill/pro number/load id /scac*/

            CREATE_EDI (p_out_error_code => X_ERROR_CODE, p_out_error_buff => X_ERROR_MESSAGE, P_ORG_ID => P_ORG_ID, P_BOL_TRACK_NUMBER => P_BOL_TRACK_NUMBER, P_PRO_NUMBER => P_PRO_NUMBER, P_LOAD_ID => P_LOAD_ID
                        , P_SCAC => P_SCAC, P_SHIPMENT_ID => X_SHIPMENT_ID);

            IF X_ERROR_CODE = 2
            THEN
                p_out_error_code   := 2;
                p_out_error_buff   := X_ERROR_MESSAGE;
                RAISE e_invalid;
            END IF;
        END IF;

        p_out_error_code   := X_ERROR_CODE;
        p_out_error_buff   := X_ERROR_MESSAGE;
        WRITE_MESSAGE (LPAD ('+', 78, '+'));
    EXCEPTION
        WHEN e_invalid
        THEN
            p_out_error_code   := 2;
            write_message ('Error Message ' || p_out_error_buff);
            WRITE_MESSAGE (LPAD ('+', 78, '+'));
        WHEN OTHERS
        THEN
            WRITE_MESSAGE ('Error Message' || SQLERRM);
            p_out_error_code   := 2;
            p_out_error_buff   := SQLERRM;
            WRITE_MESSAGE (LPAD ('+', 78, '+'));
    END CONC_MAIN_WRAP;
END XXDO_SHIPMENT_EDI_INTERFACE;
/
