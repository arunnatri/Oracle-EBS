--
-- XXDO_B2B_PO_COPY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_B2B_PO_COPY_PKG"
AS
    /*******************************************************************************
    * Program      : Deckers B2B SO Copy Program
    * File Name    : XXDO_B2B_PO_COPY_PKG
    * Language     : PL/SQL
    * Description  : This package is for Deckers B2B SO Copy Program
    * History      :
    *
    * WHO                  Version  When         Desc
    * --------------------------------------------------------------------------
    * BT Technology Team   1.1      23-JUL-2015  Modified for Japan Lead Time CR# 104
    * BT Technology Team   1.2      20-Oct-2015  Modified for Defect#3132
    * BT Technology Team   1.3      03-Nov-2015  Modified for Defect#420
    * BT Technology Team   1.4      11-Nov-2015  Modified for Billed to defect
    * BT Technology Team   1.5      17-Nov-2015  Modified for Defect#667
    * Infosys              1.6      07-Oct-2016  Modified for Problem PRB0040889 - Excluding Cancelled PO Lines
    * GJensen              1.7      01-Jan-2018  CCR0006934 - Set SO request date to po promised date minus preferred ship metho dayes (ocean days if not set)
    * GJensen              1.8      07-Oct-2019  CCR0007836 - Update ASN_header_CUR to select distinct factory ASNs
    * --------------------------------------------------------------------------- */
    PROCEDURE ASN_CREATION_MAIN_PRC (P_ERRBUF OUT VARCHAR2, P_RETCODE OUT NUMBER, P_PO_HEADER_ID NUMBER)
    IS
        CURSOR ASN_HEADER_CUR IS                                  --CCR0007836
            SELECT DISTINCT header_id, shipment_num, expected_date,
                            ship_to_organization_id, vendor_id, attribute1,
                            attribute2, attribute3, attribute4,
                            attribute5, attribute6, attribute7,
                            attribute8, attribute9, attribute10,
                            attribute11, attribute12, attribute13,
                            attribute14, attribute15          --End CCR0007836
              FROM xxd_asn_sales_order_h_v
             WHERE PO_HEADER_ID = NVL (P_PO_HEADER_ID, PO_HEADER_ID);

        CURSOR ASN_LINE_CUR (p_header_id NUMBER)
        IS
            SELECT *
              FROM XXD_ASN_SALES_ORDER_L_V
             WHERE header_id = p_header_id;

        CURSOR Created_ASN_CUR (v_request_id NUMBER)
        IS
            SELECT DISTINCT rsh.shipment_num, pha.segment1
              FROM rcv_shipment_lines rsl, po_headers_all pha, rcv_shipment_headers rsh
             WHERE     rsl.request_id = v_request_id
                   AND rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsl.po_header_id = pha.po_header_id;

        Created_ASN_rec    Created_ASN_CUR%ROWTYPE;

        ASN_LINE_rec       ASN_LINE_CUR%ROWTYPE;

        CURSOR ASN_ERR_CUR (P_GROUP_ID NUMBER)
        IS
            SELECT POIE.*, POL.LINE_NUM, POH.SEGMENT1
              FROM PO_INTERFACE_ERRORS POIE, rcv_transactions_interface RT, PO_HEADERS_ALL POH,
                   PO_LINES_ALL POL
             WHERE     POIE.BATCH_ID = P_GROUP_ID
                   AND POIE.INTERFACE_TRANSACTION_ID =
                       RT.INTERFACE_TRANSACTION_ID
                   AND RT.PO_HEADER_ID = POH.PO_HEADER_ID
                   AND RT.PO_LINE_ID = POL.PO_LINE_ID;

        ASN_ERR_REC        ASN_ERR_CUR%ROWTYPE;


        TYPE ASN_HEADER_TAB IS TABLE OF ASN_HEADER_CUR%ROWTYPE
            INDEX BY BINARY_INTEGER;

        ASN_HEADER_T       ASN_HEADER_TAB;


        TYPE l_rcv_header_tab IS TABLE OF rcv_headers_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_rcv_header       l_rcv_header_tab;

        TYPE l_rcv_line_tab IS TABLE OF rcv_transactions_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_rcv_line         l_rcv_line_tab;

        l_location         mtl_item_locations%ROWTYPE;
        v_count            NUMBER := 0;
        v_user_id          NUMBER := -1;
        v_resp_id          NUMBER := -1;
        v_resp_appl_id     NUMBER := -1;
        V_ORG_ID           NUMBER;
        V_REQ_ID           NUMBER;
        v_request_status   BOOLEAN;
        v_phase            VARCHAR2 (2000);
        v_wait_status      VARCHAR2 (2000);
        v_dev_phase        VARCHAR2 (2000);
        v_dev_status       VARCHAR2 (2000);
        v_message          VARCHAR2 (2000);
        lg_rcv_group_id    NUMBER;
        lg_rcv_header_id   NUMBER;
        cnt                NUMBER;
    BEGIN
        SELECT ORGANIZATION_ID
          INTO V_ORG_ID
          FROM HR_OPERATING_UNITS HOU
         WHERE NAME = 'Deckers Japan OU';

        OPEN ASN_HEADER_CUR;

        LOOP
            FETCH ASN_HEADER_CUR BULK COLLECT INTO ASN_HEADER_T LIMIT 1000;

            EXIT WHEN ASN_HEADER_T.COUNT = 0;

            FOR i IN ASN_HEADER_T.FIRST .. ASN_HEADER_T.LAST
            LOOP
                IF lg_rcv_group_id IS NULL
                THEN
                    SELECT apps.rcv_interface_groups_s.NEXTVAL
                      INTO lg_rcv_group_id
                      FROM DUAL;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Inside header for shipment_num'
                    || ASN_HEADER_T (i).shipment_num);

                l_rcv_header (i).header_interface_id      :=
                    apps.rcv_headers_interface_s.NEXTVAL;
                l_rcv_header (i).GROUP_ID                 := lg_rcv_group_id;
                l_rcv_header (i).processing_Status_code   := 'PENDING';
                l_rcv_header (i).receipt_source_code      := 'VENDOR';
                l_rcv_header (i).asn_type                 := 'ASN';
                l_rcv_header (i).org_id                   := V_ORG_ID;
                l_rcv_header (i).transaction_type         := 'NEW';
                l_rcv_header (i).validation_flag          := 'Y';
                l_rcv_header (i).shipped_date             :=
                    GREATEST (SYSDATE, ASN_HEADER_T (i).expected_date);
                l_rcv_header (i).last_update_date         := SYSDATE;
                l_rcv_header (i).num_of_containers        := 1;
                l_rcv_header (i).creation_date            := SYSDATE;
                l_rcv_header (i).last_update_date         := SYSDATE;
                l_rcv_header (i).last_updated_by          :=
                    fnd_global.user_id;
                l_rcv_header (i).created_by               :=
                    fnd_global.user_id;
                l_rcv_header (i).LAST_UPDATE_LOGIN        :=
                    fnd_global.login_id;

                SELECT employee_id
                  INTO l_rcv_header (i).employee_id
                  FROM fnd_user
                 WHERE user_id = fnd_global.user_id;

                l_rcv_header (i).ship_to_organization_id   :=
                    ASN_HEADER_T (i).ship_to_organization_id;
                l_rcv_header (i).vendor_id                :=
                    ASN_HEADER_T (i).vendor_id;
                l_rcv_header (i).expected_receipt_date    :=
                    GREATEST (SYSDATE, ASN_HEADER_T (i).expected_date);
                l_rcv_header (i).shipment_num             :=
                    ASN_HEADER_T (i).shipment_num;

                l_rcv_header (i).attribute1               :=
                    ASN_HEADER_T (i).attribute1;
                l_rcv_header (i).attribute2               :=
                    ASN_HEADER_T (i).attribute2;
                l_rcv_header (i).attribute3               :=
                    ASN_HEADER_T (i).attribute3;
                l_rcv_header (i).attribute4               :=
                    ASN_HEADER_T (i).attribute4;
                l_rcv_header (i).attribute5               :=
                    ASN_HEADER_T (i).attribute5;
                l_rcv_header (i).attribute6               :=
                    ASN_HEADER_T (i).attribute6;
                l_rcv_header (i).attribute7               :=
                    ASN_HEADER_T (i).attribute7;
                l_rcv_header (i).attribute8               :=
                    ASN_HEADER_T (i).attribute8;
                l_rcv_header (i).attribute9               :=
                    ASN_HEADER_T (i).attribute9;
                l_rcv_header (i).attribute10              :=
                    ASN_HEADER_T (i).attribute10;
                l_rcv_header (i).attribute11              :=
                    ASN_HEADER_T (i).attribute11;
                l_rcv_header (i).attribute12              :=
                    ASN_HEADER_T (i).attribute12;
                l_rcv_header (i).attribute13              :=
                    ASN_HEADER_T (i).attribute13;
                l_rcv_header (i).attribute14              :=
                    ASN_HEADER_T (i).attribute14;
                l_rcv_header (i).attribute15              :=
                    ASN_HEADER_T (i).attribute15;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'before line loop: ' || ASN_HEADER_T (i).header_id);

                OPEN ASN_LINE_CUR (ASN_HEADER_T (i).header_id);

                LOOP
                    FETCH ASN_LINE_CUR INTO ASN_LINE_rec;

                    EXIT WHEN ASN_LINE_CUR%NOTFOUND;
                    fnd_file.put_line (fnd_file.LOG, 'after fetch');

                    IF ASN_LINE_rec.locator_id IS NOT NULL
                    THEN
                        SELECT *
                          INTO l_location
                          FROM mtl_item_locations
                         WHERE inventory_location_id =
                               ASN_LINE_rec.locator_id;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Inside line loop for line id: ' || ASN_LINE_rec.po_line_id);

                    l_rcv_line (v_count).header_interface_id       :=
                        l_rcv_header (i).header_interface_id;
                    l_rcv_line (v_count).interface_transaction_id   :=
                        rcv_transactions_interface_s.NEXTVAL;
                    l_rcv_line (v_count).GROUP_ID                  := lg_rcv_group_id;
                    l_rcv_line (v_count).transaction_type          := 'SHIP';
                    l_rcv_line (v_count).transaction_date          := SYSDATE;
                    l_rcv_line (v_count).processing_status_code    :=
                        'PENDING';
                    l_rcv_line (v_count).processing_mode_code      := 'BATCH';
                    l_rcv_line (v_count).transaction_status_code   :=
                        'PENDING';
                    l_rcv_line (v_count).auto_transact_code        := 'SHIP';
                    l_rcv_line (v_count).validation_flag           := 'Y';
                    l_rcv_line (v_count).last_update_date          := SYSDATE;
                    l_rcv_line (v_count).last_updated_by           :=
                        fnd_global.user_id;
                    l_rcv_line (v_count).creation_date             := SYSDATE;
                    l_rcv_line (v_count).created_by                :=
                        fnd_global.user_id;
                    l_rcv_line (v_count).last_update_login         :=
                        fnd_global.login_id;
                    l_rcv_line (v_count).receipt_source_code       :=
                        'VENDOR';
                    l_rcv_line (v_count).source_document_code      := 'PO';
                    l_rcv_line (v_count).org_id                    :=
                        V_ORG_ID;
                    l_rcv_line (v_count).item_id                   :=
                        ASN_LINE_rec.item_id;
                    l_rcv_line (v_count).to_organization_id        :=
                        l_rcv_header (i).ship_to_organization_id;
                    l_rcv_line (v_count).quantity                  :=
                        ASN_LINE_rec.quantity;
                    --  l_rcv_line.unit_of_measure := l_po_line_location.unit_meas_lookup_code;
                    --  l_rcv_line.PRIMARY_UNIT_OF_MEASURE := l_po_line_location.unit_meas_lookup_code; --l_system_item.PRIMARY_UNIT_OF_MEASURE;
                    l_rcv_line (v_count).po_header_id              :=
                        ASN_LINE_rec.po_header_id;
                    l_rcv_line (v_count).po_line_id                :=
                        ASN_LINE_rec.po_line_id;
                    l_rcv_line (v_count).po_line_location_id       :=
                        ASN_LINE_rec.po_line_location_id;
                    l_rcv_line (v_count).subinventory              :=
                        l_location.subinventory_code;
                    l_rcv_line (v_count).ship_to_location_id       :=
                        ASN_LINE_rec.ship_to_location_id;
                    l_rcv_line (v_count).locator_id                :=
                        l_location.inventory_location_id;

                    l_rcv_line (v_count).container_num             :=
                        ASN_LINE_rec.container_number;
                    l_rcv_line (v_count).barcode_label             :=
                        ASN_LINE_rec.license_plate_number;
                    l_rcv_line (v_count).license_plate_number      :=
                        ASN_LINE_rec.license_plate_number;

                    IF ASN_LINE_rec.license_plate_number IS NOT NULL
                    THEN
                        SELECT COUNT (*)
                          INTO cnt
                          FROM wms_license_plate_numbers
                         WHERE license_plate_number =
                               ASN_LINE_rec.license_plate_number;

                        IF cnt != 0
                        THEN
                            UPDATE wms_license_plate_numbers
                               SET lpn_context = 5, subinventory_code = NULL, locator_id = NULL,
                                   source_header_id = NULL, source_name = NULL, organization_id = l_rcv_header (i).ship_to_organization_id,
                                   outermost_lpn_id = lpn_id, parent_lpn_id = NULL
                             WHERE license_plate_number =
                                   ASN_LINE_rec.license_plate_number;
                        ELSE
                            SELECT COUNT (*)
                              INTO cnt
                              FROM wms_lpn_interface
                             WHERE license_plate_number =
                                   ASN_LINE_rec.license_plate_number;

                            IF cnt = 0
                            THEN
                                INSERT INTO apps.wms_lpn_interface (
                                                license_plate_number,
                                                last_update_date,
                                                last_updated_by,
                                                creation_date,
                                                created_by,
                                                source_group_id,
                                                organization_id)
                                         VALUES (
                                                    ASN_LINE_rec.license_plate_number,
                                                    SYSDATE,
                                                    l_rcv_line (v_count).last_updated_by,
                                                    SYSDATE,
                                                    l_rcv_line (v_count).created_by,
                                                    lg_rcv_group_id,
                                                    l_rcv_header (i).ship_to_organization_id);

                                l_rcv_line (v_count).lpn_group_id   :=
                                    lg_rcv_group_id;
                            END IF;
                        END IF;
                    END IF;

                    v_count                                        :=
                        v_count + 1;
                END LOOP;

                CLOSE ASN_LINE_CUR;
            END LOOP;

            FORALL i IN l_rcv_header.FIRST .. l_rcv_header.LAST
                INSERT INTO rcv_headers_interface
                     VALUES l_rcv_header (I);

            FORALL i IN l_rcv_line.FIRST .. l_rcv_line.LAST
                INSERT INTO rcv_transactions_interface
                     VALUES l_rcv_line (I);

            /*forall i in l_rcv_header.first..l_rcv_header.last
            update APPS.xxd_asn_sales_order_h_v
            set flag_column := 'COMPLETE'
            WHERE HEADER_ID = l_rcv_header(i).header_id;*/

            v_count   := 0;
        END LOOP;

        CLOSE ASN_HEADER_CUR;

        COMMIT;


        BEGIN
            ---receiving transaction processor----

            v_resp_appl_id   := fnd_global.resp_appl_id;
            v_resp_id        := fnd_global.resp_id;
            v_user_id        := fnd_global.user_id;
            APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                             v_resp_id,
                                             v_resp_appl_id);
            --  APPS.fnd_global.APPS_INITIALIZE (0, 50766, 201);


            /*         MO_GLOBAL.SET_POLICY_CONTEXT('S',81);
          DBMS_OUTPUT.PUT_LINE('after Policy context');*/

            mo_global.init ('PO');
            mo_global.set_policy_context ('S', V_ORG_ID);
            -------
            v_req_id         :=
                fnd_request.submit_request (application   => 'PO',
                                            program       => 'RVCTP',
                                            description   => NULL,
                                            start_time    => SYSDATE,
                                            sub_request   => FALSE,
                                            argument1     => 'BATCH',
                                            argument2     => lg_rcv_group_id,
                                            argument3     => v_org_id);

            COMMIT;


            IF v_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || fnd_message.get
                    || '".');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'The ASN Import Program submitted  Request id :'
                    || v_req_id);
            END IF;

            IF v_req_id > 0
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   '   Waiting for the ASN Import Program');

                LOOP
                    v_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => v_req_id,
                            INTERVAL     => 60,
                            max_wait     => 0,
                            phase        => v_phase,
                            status       => v_wait_status,
                            dev_phase    => v_dev_phase,
                            dev_status   => v_dev_status,
                            MESSAGE      => v_message);

                    EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
                              OR UPPER (v_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  ASN Import Program Request Phase'
                    || '-'
                    || v_dev_phase);
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  ASN Import Program Request Dev status'
                    || '-'
                    || v_dev_status);

                IF     UPPER (v_phase) = 'COMPLETED'
                   AND UPPER (v_wait_status) = 'ERROR'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'The ASN Import prog completed in error. See log for request id');
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);

                    OPEN ASN_ERR_CUR (lg_rcv_group_id);

                    LOOP
                        FETCH ASN_ERR_CUR INTO ASN_ERR_REC;

                        EXIT WHEN ASN_ERR_CUR%NOTFOUND;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'PO#: '
                            || ASN_ERR_REC.SEGMENT1
                            || 'Line Number: '
                            || ASN_ERR_REC.LINE_NUM
                            || 'Error Column: '
                            || ASN_ERR_REC.COLUMN_NAME
                            || 'Error Message: '
                            || ASN_ERR_REC.ERROR_MESSAGE_NAME
                            || CHR (10));
                    END LOOP;

                    CLOSE ASN_ERR_CUR;

                    RETURN;
                ELSIF     UPPER (v_phase) = 'COMPLETED'
                      AND UPPER (v_wait_status) = 'NORMAL'
                THEN
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                           'The ASN Import successfully completed for request id: '
                        || v_req_id);

                    OPEN Created_ASN_CUR (v_req_id);

                    LOOP
                        FETCH Created_ASN_CUR INTO Created_ASN_rec;

                        EXIT WHEN Created_ASN_CUR%NOTFOUND;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'PO#: '
                            || Created_ASN_rec.SEGMENT1
                            || 'Shipment Num: '
                            || Created_ASN_rec.shipment_num
                            || CHR (10));
                    END LOOP;

                    CLOSE Created_ASN_CUR;

                    OPEN ASN_ERR_CUR (lg_rcv_group_id);

                    LOOP
                        FETCH ASN_ERR_CUR INTO ASN_ERR_REC;

                        EXIT WHEN ASN_ERR_CUR%NOTFOUND;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'PO#: '
                            || ASN_ERR_REC.SEGMENT1
                            || 'Line Number: '
                            || ASN_ERR_REC.LINE_NUM
                            || 'Error Column: '
                            || ASN_ERR_REC.COLUMN_NAME
                            || 'Error Message: '
                            || ASN_ERR_REC.ERROR_MESSAGE_NAME
                            || CHR (10));
                    END LOOP;

                    CLOSE ASN_ERR_CUR;
                ELSE
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                        'The ASN Import request failed.Review log for Oracle request id ');
                    Fnd_File.PUT_LINE (Fnd_File.LOG, SQLERRM);

                    RETURN;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                IF ASN_ERR_CUR%ISOPEN
                THEN
                    CLOSE ASN_ERR_CUR;
                END IF;

                IF ASN_HEADER_CUR%ISOPEN
                THEN
                    CLOSE ASN_HEADER_CUR;
                END IF;

                IF ASN_LINE_CUR%ISOPEN
                THEN
                    CLOSE ASN_LINE_CUR;
                END IF;

                IF Created_ASN_CUR%ISOPEN
                THEN
                    CLOSE Created_ASN_CUR;
                END IF;

                Fnd_File.PUT_LINE (
                    Fnd_File.LOG,
                    'WHEN OTHERS ASN IMPORT STANDARD CALL' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            Fnd_File.PUT_LINE (Fnd_File.LOG,
                               'WHEN OTHERS ASN main procedure' || SQLERRM);
    END;

    FUNCTION get_list_price (p_header_id IN NUMBER, p_unit_price IN NUMBER, p_vendor_id IN NUMBER
                             , p_item_id IN NUMBER, p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        lv_style            VARCHAR2 (10);
        lv_color            VARCHAR2 (10);
        lv_item_price       NUMBER;
        lv_corporate_rate   NUMBER;
        lv_from_currency    VARCHAR2 (10);
    BEGIN
        SELECT DISTINCT style_number, color_code
          INTO lv_style, lv_color
          FROM apps.XXD_COMMON_ITEMS_V
         WHERE inventory_item_id = p_item_id AND organization_id = p_org_id;

        SELECT transactional_curr_code
          INTO lv_from_currency
          FROM apps.oe_order_headers_all
         WHERE header_id = p_header_id;


        IF (lv_from_currency <> 'JPY')
        THEN
            SELECT conversion_rate
              INTO lv_corporate_rate
              FROM apps.gl_daily_rates
             WHERE     from_currency = lv_from_currency
                   AND to_currency = 'JPY'
                   AND conversion_type = 'Corporate'
                   AND TRUNC (conversion_date) = TRUNC (SYSDATE);
        ELSE
            lv_corporate_rate   := 1;
        END IF;

        BEGIN
            SELECT ROUND ((p_unit_price * lv_corporate_rate) * NVL (rate_multiplier, 0) + NVL (rate_amount, 0), 0)
              INTO lv_item_price
              FROM do_custom.xxdo_po_price_rule xppr, do_custom.xxdo_po_price_rule_assignment xppra, AP_SUPPLIERS APS,
                   HR_ORGANIZATION_UNITS HROU
             WHERE     xppr.po_price_rule = xppra.po_price_rule
                   --AND xppr.vendor_id = p_vendor_id
                   -- AND xppra.target_item_org_id = p_org_id --changed after conversion
                   AND xppr.VENDOR_NAME = APS.VENDOR_NAME
                   AND APS.VENDOR_ID = p_vendor_id
                   AND xppra.target_item_orgANIZATION = HROU.NAME
                   AND HROU.ORGANIZATION_ID = P_ORG_ID
                   AND xppra.item_segment1 = lv_style
                   AND xppra.item_segment2 = lv_color;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_item_price   := p_unit_price * lv_corporate_rate;
        END;

        RETURN lv_item_price;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            Fnd_File.PUT_LINE (
                Fnd_File.LOG,
                   'Error while calculating the list price of item '
                || p_item_id
                || ' for JP5('
                || SQLERRM
                || ')');
            RETURN NULL;
        WHEN OTHERS
        THEN
            Fnd_File.PUT_LINE (
                Fnd_File.LOG,
                   'Error while calculating the list price of item '
                || p_item_id
                || ' for JP5('
                || SQLERRM
                || ')');
            RETURN NULL;
    END;

    PROCEDURE process_order_prc (p_errbuf IN OUT VARCHAR2, p_retcode IN OUT NUMBER, p_header_rec IN oe_order_pub.header_rec_type, p_line_tbl IN oe_order_pub.line_tbl_type, l_header_rec_out OUT oe_order_pub.header_rec_type, l_line_tbl_out OUT oe_order_pub.line_tbl_type
                                 , p_action_request_tbl IN oe_order_pub.request_tbl_type, p_account_name IN VARCHAR2)
    AS
        --   PRAGMA AUTONOMOUS_TRANSACTION;
        l_api_version_number           NUMBER := 1;
        l_return_status                VARCHAR2 (2000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (2000);
        /*****************PARAMETERS****************************************************/
        l_debug_level                  NUMBER := 5;  -- OM DEBUG LEVEL (MAX 5)
        l_org                          NUMBER;               -- OPERATING UNIT
        /*****************INPUT VARIABLES FOR PROCESS_ORDER API*************************/



        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        /*****************OUT VARIABLES FOR PROCESS_ORDER API***************************/
        --  l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        --  l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        l_msg_index                    NUMBER;
        l_data                         VARCHAR2 (2000);
        l_loop_count                   NUMBER;
        l_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);

        v_user_id                      NUMBER := -1;
        v_resp_id                      NUMBER := -1;
        v_resp_appl_id                 NUMBER := -1;
    BEGIN
        SELECT ORGANIZATION_ID
          INTO l_org
          FROM HR_OPERATING_UNITS HOU
         WHERE NAME = 'Deckers Macau OU';

        /*v_resp_appl_id := fnd_global.resp_appl_id;
        v_resp_id := fnd_global.resp_id;
        v_user_id := fnd_global.user_id;*/
        --commented as per defect#3132

        --  APPS.fnd_global.APPS_INITIALIZE (0, 50766, 201);

        /*****************INITIALIZE DEBUG INFO*************************************/
        IF (l_debug_level > 0)
        THEN
            l_debug_file   := oe_debug_pub.set_debug_mode ('FILE');
            oe_debug_pub.initialize;
            oe_debug_pub.setdebuglevel (l_debug_level);
            oe_msg_pub.initialize;
            fnd_file.put_line (fnd_file.LOG,
                               'l_debug_file => ' || l_debug_file);
        END IF;

        /*****************INITIALIZE ENVIRONMENT*************************************/
        --APPS.fnd_global.APPS_INITIALIZE (v_user_id, v_resp_id, v_resp_appl_id); --commented as per defect#3132

        mo_global.init ('ONT');                            -- Required for R12
        mo_global.set_policy_context ('S', l_org);         -- Required for R12
        FND_REQUEST.SET_ORG_ID (l_org);

        /*****************CALLTO PROCESS ORDER API*********************************/
        oe_order_pub.process_order (
            p_org_id                   => l_org,    --added as per defect#3132
            p_api_version_number       => l_api_version_number,
            p_header_rec               => p_header_rec,
            p_line_tbl                 => p_line_tbl,
            p_action_request_tbl       => p_action_request_tbl,
            p_line_adj_tbl             => l_line_adj_tbl      -- OUT variables
                                                        ,
            x_header_rec               => l_header_rec_out,
            x_header_val_rec           => l_header_val_rec_out,
            x_header_adj_tbl           => l_header_adj_tbl_out,
            x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
            x_header_price_att_tbl     => l_header_price_att_tbl_out,
            x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
            x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
            x_header_scredit_tbl       => l_header_scredit_tbl_out,
            x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
            x_line_tbl                 => l_line_tbl_out,
            x_line_val_tbl             => l_line_val_tbl_out,
            x_line_adj_tbl             => l_line_adj_tbl_out,
            x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
            x_line_price_att_tbl       => l_line_price_att_tbl_out,
            x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
            x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
            x_line_scredit_tbl         => l_line_scredit_tbl_out,
            x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
            x_lot_serial_tbl           => l_lot_serial_tbl_out,
            x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
            x_action_request_tbl       => l_action_request_tbl_out,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data);

        /*****************CHECK RETURN STATUS***********************************/
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            fnd_file.put_line (
                fnd_file.OUTPUT,
                   'order_number#: '
                || TO_CHAR (l_header_rec_out.order_number)
                || 'PO#-CUST ACCT NAME: '
                || l_header_rec_out.CUST_PO_NUMBER
                || '-'
                || p_account_name
                || CHR (10));

            IF l_header_rec_out.order_number IS NOT NULL
            THEN
                --p_header_rec := l_header_rec_out;
                -- p_line_tbl := l_line_tbl_out;
                p_retcode   := 0;

                FORALL i IN l_line_tbl_out.FIRST .. l_line_tbl_out.LAST
                    UPDATE PO_LINES_ALL
                       SET ATTRIBUTE5 = TO_CHAR (l_line_tbl_out (i).LINE_ID), ATTRIBUTE_CATEGORY = 'Intercompany PO Copy'
                     WHERE     PO_LINE_ID =
                               l_line_tbl_out (i).orig_sys_line_ref
                           AND l_line_tbl_out (i).LINE_ID IS NOT NULL;

                FOR i IN l_line_tbl_out.FIRST .. l_line_tbl_out.LAST
                LOOP
                    SELECT unit_selling_price
                      INTO l_line_tbl_out (i).unit_selling_price
                      FROM oe_order_lines_all
                     WHERE l_line_tbl_out (i).line_id = line_id;
                END LOOP;



                COMMIT;
            ELSE
                p_retcode   := 1;
            END IF;
        ELSIF l_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            p_retcode   := 1;

            fnd_file.PUT_LINE (
                fnd_file.LOG,
                   'process order api error:PO#-CUST ACCT NAME: '
                || P_HEADER_REC.CUST_PO_NUMBER
                || '-'
                || p_account_name
                || CHR (10));

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                       FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F')
                    || CHR (10));
            END LOOP;

            ROLLBACK;
        ELSIF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR
        THEN
            p_retcode   := 1;
            fnd_file.PUT_LINE (
                fnd_file.LOG,
                   'process order unexpected error:PO#-CUST ACCT NAME: '
                || P_HEADER_REC.CUST_PO_NUMBER
                || '-'
                || p_account_name
                || CHR (10));

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                       FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F')
                    || CHR (10));
            END LOOP;


            ROLLBACK;
        END IF;


        /*****************DISPLAY ERROR MSGS*************************************/

        FOR i IN 1 .. l_msg_count
        LOOP
            oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data
                            , p_msg_index_out => l_msg_index);
            fnd_file.put_line (fnd_file.LOG, 'message is: ' || l_data);
            fnd_file.put_line (fnd_file.LOG,
                               'message index is: ' || l_msg_index);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Debug = ' || oe_debug_pub.g_debug);
        fnd_file.put_line (
            fnd_file.LOG,
            'Debug Level = ' || TO_CHAR (oe_debug_pub.g_debug_level));
        fnd_file.put_line (
            fnd_file.LOG,
            'Debug File = ' || oe_debug_pub.g_dir || '/' || oe_debug_pub.g_file);
        fnd_file.put_line (
            fnd_file.LOG,
            '****************************************************');
        oe_debug_pub.debug_off;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'PROCESS ORDER ERROR FOR PO#-CUST ACCT '
                || P_HEADER_REC.CUST_PO_NUMBER
                || '-'
                || P_HEADER_REC.SOLD_TO_ORG_ID
                || '|'
                || SQLERRM);
    END process_order_prc;

    PROCEDURE update_unit_price (p_po_num         IN NUMBER,
                                 p_line_num       IN NUMBER,
                                 p_shipment_num   IN NUMBER,
                                 p_unit_price     IN VARCHAR2,
                                 p_org_id         IN NUMBER)
    IS
        v_resp_appl_id   NUMBER;
        v_resp_id        NUMBER;
        v_user_id        NUMBER;
        l_result         NUMBER;
        l_api_errors     PO_API_ERRORS_REC_TYPE;
        L_REVISION_NUM   NUMBER;
    BEGIN
        SELECT REVISION_NUM
          INTO L_REVISION_NUM
          FROM apps.PO_HEADERS_ALL
         WHERE SEGMENT1 = p_po_num AND ORG_ID = p_org_id;

        /* v_resp_appl_id := fnd_global.resp_appl_id;
         v_resp_id := fnd_global.resp_id;
         v_user_id := fnd_global.user_id;
         APPS.fnd_global.APPS_INITIALIZE (v_user_id, v_resp_id, v_resp_appl_id);*/
        --commented as per defect3132
        APPS.mo_global.init ('PO');
        mo_global.set_policy_context ('S', p_org_id); --added as per defect3132
        FND_REQUEST.SET_ORG_ID (p_org_id);           --added as per defect3132
        l_result   :=
            po_change_api1_s.update_po (
                x_po_number             => p_po_num,
                x_release_number        => NULL,
                x_revision_number       => L_REVISION_NUM,
                x_line_number           => p_line_num,
                x_shipment_number       => P_SHIPMENT_NUM,
                new_quantity            => NULL,
                new_price               => p_unit_price,
                new_promised_date       => NULL,
                new_need_by_date        => NULL,
                launch_approvals_flag   => 'N',                             --
                update_source           => NULL,
                version                 => '1.0',
                x_override_date         => NULL,
                x_api_errors            => l_api_errors,
                p_buyer_name            => NULL,
                p_secondary_quantity    => NULL,
                p_preferred_grade       => NULL,
                p_org_id                => P_ORG_ID);

        --  p_error_num:= l_result;
        IF l_result <> 1
        THEN
            fnd_file.put_line (fnd_file.LOG, 'update unit price error msg: ');

            FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
            LOOP
                fnd_file.put_line (fnd_file.LOG,
                                   l_api_errors.MESSAGE_TEXT (i));
            -- || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'unit price updated');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'upadte unit price when others error mmsg: ' || SQLERRM);
    -- ROLLBACK;

               /*    FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
LOOP
   fnd_file.put_line (fnd_file.LOG, l_api_errors.MESSAGE_TEXT (i));
-- || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
END LOOP;*/
    --commented as per defect#3132
    END update_unit_price;

    PROCEDURE PO_APPROVAL (p_po_num IN NUMBER, P_org_id IN NUMBER, p_error_code OUT VARCHAR2
                           , P_ERROR_TEXT OUT VARCHAR2)
    IS
        l_api_errors             PO_API_ERRORS_REC_TYPE;
        v_po_header_id           NUMBER;
        v_org_id                 NUMBER;
        v_po_num                 VARCHAR2 (50);
        v_doc_type               VARCHAR2 (50);
        v_doc_sub_type           VARCHAR2 (50);
        l_return_status          VARCHAR2 (1);
        l_api_version   CONSTANT NUMBER := 2.0;
        l_api_name      CONSTANT VARCHAR2 (50) := 'UPDATE_DOCUMENT';
        l_progress               VARCHAR2 (3) := '000';
        v_agent_id               NUMBER;
        ---
        v_item_key               VARCHAR2 (100);
        v_resp_appl_id           NUMBER;
        v_resp_id                NUMBER;
        v_user_id                NUMBER;
    --
    BEGIN
        v_org_id          := p_org_id;
        v_po_num          := p_po_num;

        BEGIN
            SELECT pha.po_header_id, pha.agent_id, pdt.document_subtype,
                   pdt.document_type_code, pha.wf_item_key
              INTO v_po_header_id, v_agent_id, v_doc_sub_type, v_doc_type,
                                 v_item_key
              FROM apps.po_headers_all pha, apps.po_document_types_all pdt
             WHERE     pha.type_lookup_code = pdt.document_subtype
                   AND pha.org_id = v_org_id
                   AND pdt.document_type_code = 'PO'
                   AND segment1 = v_po_num;

            l_progress   := '001';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_code   := 1;
        END;

        /* v_resp_appl_id := fnd_global.resp_appl_id;
         v_resp_id := fnd_global.resp_id;
         v_user_id := fnd_global.user_id;
         APPS.fnd_global.APPS_INITIALIZE (v_user_id, v_resp_id, v_resp_appl_id);*/
        --commented as per defect3132
        APPS.mo_global.init ('PO');
        mo_global.set_policy_context ('S', p_org_id); --added as per defect3132
        FND_REQUEST.SET_ORG_ID (p_org_id);           --added as per defect3132
        --calling seeded procedure to launch the po approval workflow

        po_reqapproval_init1.start_wf_process (ItemType => 'POAPPRV', ItemKey => v_item_key, WorkflowProcess => 'XXDO_POAPPRV_TOP', ActionOriginatedFrom => 'PO_FORM', DocumentID => v_po_header_id -- po_header_id
                                                                                                                                                                                                   , DocumentNumber => v_po_num -- Purchase Order Number
                                                                                                                                                                                                                               , PreparerID => v_agent_id -- Buyer/Preparer_id
                                                                                                                                                                                                                                                         , DocumentTypeCode => 'PO' --'PO'
                                                                                                                                                                                                                                                                                   , DocumentSubtype => 'STANDARD' --'STANDARD'
                                                                                                                                                                                                                                                                                                                  , SubmitterAction => 'APPROVE', forwardToID => NULL, forwardFromID => NULL, DefaultApprovalPathID => NULL, Note => NULL, PrintFlag => 'N', FaxFlag => 'N', FaxNumber => NULL, EmailFlag => 'N', EmailAddress => NULL, CreateSourcingRule => 'N', ReleaseGenMethod => 'N', UpdateSourcingRule => 'N', MassUpdateReleases => 'N', RetroactivePriceChange => 'N', OrgAssignChange => 'N', CommunicatePriceChange => 'N', p_Background_Flag => 'N', p_Initiator => NULL, p_xml_flag => NULL, FpdsngFlag => 'N'
                                               , p_source_type_code => NULL);

        l_progress        := '002';
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        IF (l_return_status = 'S')
        THEN
            p_error_code   := 0;
            P_ERROR_TEXT   := 'S';
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'wf approval success');
        ELSE
            p_error_code   := 1;
            P_ERROR_TEXT   := 'F';
        END IF;

        l_progress        := '003';
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            p_error_code   := 1;
            p_error_text   := SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG, p_error_text);
        WHEN OTHERS
        THEN
            p_error_text   := SQLERRM;
            p_error_code   := 1;
            FND_FILE.PUT_LINE (FND_FILE.LOG, p_error_text);
    END PO_APPROVAL;

    PROCEDURE main_prc (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, P_PO_HEADER_ID IN VARCHAR2 DEFAULT NULL
                        , p_destination_org_id IN NUMBER DEFAULT NULL, p_order_type_id IN NUMBER DEFAULT NULL, p_price_list_id IN NUMBER DEFAULT NULL)
    IS
        ln_destination_org_id     NUMBER;
        ln_order_type_id          NUMBER;
        ln_price_list_id          NUMBER;
        ln_line_type_id           NUMBER;
        lv_ship_method            VARCHAR2 (30);
        ln_term_id                NUMBER;
        ln_ship_from_org_id       NUMBER;
        lv_freight_terms          VARCHAR2 (30);
        lv_fob                    VARCHAR2 (30);

        v_user_id                 NUMBER := -1;
        v_resp_id                 NUMBER := -1;
        v_resp_appl_id            NUMBER := -1;

        CURSOR get_approved_po IS
            SELECT DISTINCT HCA.CUST_ACCOUNT_ID,
                            HCA.ACCOUNT_NAME,
                            PHA.SEGMENT1 po_number,
                            PHA.CREATION_DATE PO_CREATION_DATE,
                            pha.org_id,
                            APSS.VENDOR_SITE_ID,
                            apss.vendor_site_code, --Added by BT Technology Team v1.1 for CR# 104
                            PHA.VENDOR_ID,
                            POLL.SHIP_TO_ORGANIZATION_ID,
                            CASE
                                WHEN apss.vendor_site_code =
                                     (SELECT organization_code
                                        FROM mtl_parameters
                                       WHERE organization_code =
                                             apss.vendor_site_code)
                                THEN
                                    (SELECT organization_id
                                       FROM mtl_parameters
                                      WHERE organization_code =
                                            apss.vendor_site_code)
                                ELSE
                                    (SELECT ORGANIZATION_ID
                                       FROM MTL_PARAMETERS
                                      WHERE organization_code = 'MC2')
                            END WH_ORG_ID,
                            CASE
                                WHEN apss.vendor_site_code =
                                     (SELECT organization_code
                                        FROM mtl_parameters
                                       WHERE organization_code =
                                             apss.vendor_site_code)
                                THEN
                                    'INTERNAL'
                                ELSE
                                    'EXTERNAL'
                            END SOURCE_TYPE,
                            PHA.revision_num,
                            PHA.PO_HEADER_ID,
                            MCB.SEGMENT1 BRAND,
                            APS.ATTRIBUTE8 CUSTOMER
              FROM po_headers_all pha, HR_ORGANIZATION_UNITS HOU, FND_LOOKUP_VALUES FLV,
                   AP_SUPPLIERS APS, AP_SUPPLIER_SITES_ALL APSS, PO_LINE_LOCATIONS_ALL POLL,
                   PO_LINES_ALL POL, HR_ORGANIZATION_INFORMATION HOI, MTL_PARAMETERS MP,
                   -- hz_parties HP,
                   HZ_CUST_ACCOUNTS HCA, MTL_CATEGORIES_B mcb, mtl_item_categories mic,
                   MTL_CATEGORY_SETS_VL MCS, FND_ID_FLEX_STRUCTURES ffs
             WHERE     UPPER (pha.authorization_status) = 'APPROVED'
                   AND PHA.PO_HEADER_ID =
                       NVL (P_PO_HEADER_ID, PHA.PO_HEADER_ID)
                   AND PHA.ORG_ID = HOU.ORGANIZATION_ID
                   AND HOU.NAME = 'Deckers Japan OU'
                   AND PHA.VENDOR_ID = APS.VENDOR_ID
                   AND APS.vendor_type_lookup_code = FLV.LOOKUP_CODE
                   AND APS.vendor_type_lookup_code = 'TQ PROVIDER'
                   AND FLV.LOOKUP_TYPE = 'VENDOR TYPE'
                   AND FLV.LANGUAGE = 'US'
                   AND APS.ATTRIBUTE_CATEGORY = 'Supplier Data Elements'
                   AND APSS.VENDOR_SITE_ID = PHA.VENDOR_SITE_ID
                   AND apss.org_id = HOU.ORGANIZATION_ID
                   -- AND HP.PARTY_NAME = APS.ATTRIBUTE8
                   AND POL.ATTRIBUTE5 IS NULL
                   -- Added Start by PRB0040889
                   AND NVL (pha.cancel_flag, 'N') <> 'Y'
                   AND NVL (pol.cancel_flag, 'N') <> 'Y'
                   AND NVL (poll.cancel_flag, 'N') <> 'Y'
                   -- Added End by PRB0040889
                   AND POLL.PO_LINE_ID = POL.PO_LINE_ID
                   AND POL.PO_HEADER_ID = PHA.PO_HEADER_ID
                   AND POLL.SHIP_TO_ORGANIZATION_ID = MP.organization_id
                   AND POLL.SHIP_TO_ORGANIZATION_ID = HOI.ORGANIZATION_ID
                   AND HOI.ORG_INFORMATION_CONTEXT = 'Accounting Information'
                   AND HOI.ORG_INFORMATION3 = HOU.ORGANIZATION_ID
                   AND POL.ITEM_ID = mic.inventory_item_id
                   AND POLL.SHIP_TO_ORGANIZATION_ID = mic.organization_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND mcb.structure_id = ffs.id_flex_num
                   AND ffs.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                   AND HCA.ACCOUNT_NAME =
                       APS.ATTRIBUTE8 || '-' || MCB.SEGMENT1;

        CURSOR get_approved_po_lines (P_cust_account_id NUMBER, P_HEADER_ID NUMBER, P_ORG_ID NUMBER)
        IS
            SELECT DISTINCT pol.item_id, MUM.UOM_CODE UOM, pol.quantity,
                            pol.po_line_id, poll.need_by_date, poll.promised_date, --Added by BT Technology Team v1.1 for CR# 104
                            pol.line_num, poll.shipment_num, poll.attribute10 ship_method
              FROM po_headers_all pha, AP_SUPPLIERS APS, PO_LINE_LOCATIONS_ALL POLL,
                   PO_LINES_ALL POL, --hz_parties HP,
                                     HZ_CUST_ACCOUNTS HCA, MTL_CATEGORIES_B mcb,
                   mtl_item_categories mic, MTL_CATEGORY_SETS_VL MCS, FND_ID_FLEX_STRUCTURES ffs,
                   MTL_UNITS_OF_MEASURE MUM
             WHERE     UPPER (pha.authorization_status) = 'APPROVED'
                   AND PHA.PO_HEADER_ID = P_HEADER_ID
                   AND PHA.ORG_ID = P_ORG_ID
                   AND PHA.VENDOR_ID = APS.VENDOR_ID
                   AND APS.ATTRIBUTE_CATEGORY = 'Supplier Data Elements'
                   AND MUM.UNIT_OF_MEASURE = pol.unit_meas_lookup_code
                   --AND HP.PARTY_NAME = APS.ATTRIBUTE8
                   AND POLL.PO_LINE_ID = POL.PO_LINE_ID
                   AND POL.ATTRIBUTE5 IS NULL
                   -- Added Start by PRB0040889
                   AND NVL (pha.cancel_flag, 'N') <> 'Y'
                   AND NVL (pol.cancel_flag, 'N') <> 'Y'
                   AND NVL (poll.cancel_flag, 'N') <> 'Y'
                   -- Added End by PRB0040889
                   AND POL.PO_HEADER_ID = PHA.PO_HEADER_ID
                   AND POL.ITEM_ID = mic.inventory_item_id
                   AND POLL.SHIP_TO_ORGANIZATION_ID = mic.organization_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND mcb.structure_id = ffs.id_flex_num
                   AND ffs.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                   AND HCA.ACCOUNT_NAME =
                       APS.ATTRIBUTE8 || '-' || MCB.SEGMENT1
                   AND HCA.CUST_ACCOUNT_ID = P_CUST_ACCOUNT_ID;

        get_approved_po_REC       get_approved_po%ROWTYPE;

        TYPE lt_order_lines_typ IS TABLE OF get_approved_po_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;


        lt_order_lines_data       lt_order_lines_typ;
        L_header_rec              oe_order_pub.header_rec_type;
        L_line_tbl                oe_order_pub.line_tbl_type;
        L_action_request_tbl      oe_order_pub.request_tbl_type;
        l_line_tbl_out            oe_order_pub.line_tbl_type;
        l_header_rec_out          oe_order_pub.header_rec_type;
        ln_line_index             NUMBER := 0;
        p_flag                    VARCHAR2 (10) := 'Y';
        V_ORG_ID                  NUMBER;
        V_UNIT_PRICE              NUMBER;
        ln_no_of_days             VARCHAR2 (10); --Added by BT Technology Team v1.1 for CR# 104
        v_source_id               NUMBER; --Added by BT Technology Team v1.5 for Defect# 667

        --For  CCR0006934
        v_days_air                VARCHAR2 (5);
        v_days_ocean              VARCHAR2 (5);
        v_days_truck              VARCHAR2 (5);
        v_preferred_ship_method   VARCHAR2 (20);
    --End  CCR0006934
    BEGIN
        P_RETCODE        := 0;

        SELECT ORGANIZATION_ID
          INTO V_ORG_ID
          FROM HR_OPERATING_UNITS HOU
         WHERE NAME = 'Deckers Macau OU';

        --start modification for defect#3132

        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;

        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id); -- pass in user_id, responsibility_id, and application_id

        --end modification for defect#3132
        --Start of changes by BT TEchnology Team for Defect#667
        BEGIN
            SELECT ORDER_SOURCE_ID
              INTO v_source_id
              FROM OE_ORDER_SOURCES
             WHERE NAME = 'JAPANTQSO';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- end of changes by BT TEchnology Team for Defect#667
        OPEN get_approved_po;

        LOOP
            FETCH get_approved_po INTO get_approved_po_REC;


            EXIT WHEN get_approved_po%NOTFOUND;
            l_header_rec                            := oe_order_pub.g_miss_header_rec;
            l_header_rec.cust_po_number             := get_approved_po_REC.po_number;
            l_header_rec.ORG_ID                     := V_ORG_ID;
            l_header_rec.sold_to_org_id             :=
                get_approved_po_REC.CUST_ACCOUNT_ID;
            l_header_rec.ordered_date               :=
                get_approved_po_REC.PO_CREATION_DATE;
            l_header_rec.ship_from_org_id           := get_approved_po_REC.WH_ORG_ID;
            --start of changes by BT TEchnology  for Billed To Default Defect  Date -11 Nov 2015
            -- l_header_rec.ship_TO_org_id := get_approved_po_REC.SHIP_TO_ORGANIZATION_ID;
            --end of changes by BT TEchnology  for Billed To Default Defect Date -11 Nov 2015
            l_header_rec.ATTRIBUTE5                 := get_approved_po_REC.BRAND;
            l_header_rec.attribute1                 :=
                TO_CHAR (ADD_MONTHS (SYSDATE, 1), 'YYYY/MM/DD');
            -- l_header_rec.order_source := get_approved_po_REC.SOURCE_TYPE;
            -- Start of changes by BT TEchnology Team for Defect#667
            l_header_rec.order_source_id            := v_source_id;
            --  end of changes by BT TEchnology Team for Defect#667
            /*l_header_rec.shipping_method_code := lv_ship_method;
            l_header_rec.sold_from_org_id := ln_destination_org_id; --87-- warehouse
            l_header_rec.payment_term_id := ln_term_id;
            l_header_rec.ship_from_org_id := ln_ship_from_org_id;
            l_header_rec.freight_terms_code := lv_freight_terms;
            l_header_rec.fob_point_code := lv_fob;
            l_header_rec.salesrep_id := ln_salesrep_id;  */
            l_header_rec.operation                  := oe_globals.g_opr_create;
            l_header_rec.cancelled_flag             := 'N';
            l_header_rec.booked_flag                := 'Y';
            l_header_rec.flow_status_code           := 'BOOKED';
            l_header_rec.orig_sys_document_ref      :=
                   get_approved_po_REC.po_number
                || '-'
                || get_approved_po_REC.CUST_ACCOUNT_ID;
            /* l_header_rec.attribute1 := '01-JAN-2016';
             l_header_rec.attribute5 := 'UGG';*/
            -- l_header_rec.order_number := 99992;                    ---fors testing

            so_header_validation (l_header_rec, get_approved_po_REC.account_name, get_approved_po_REC.CUSTOMER
                                  , p_flag);

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'after validation');

            BEGIN
                SELECT OTT.TRANSACTION_TYPE_ID
                  INTO L_HEADER_REC.ORDER_TYPE_id
                  FROM PO_VENDOR_SITES_ALL PVSA, OE_TRANSACTION_TYPES_TL ott, OE_TRANSACTION_TYPES_ALL OTT_ALL,
                       HR_ORGANIZATION_UNITS HOU
                 WHERE     PVSA.VENDOR_SITE_ID =
                           get_approved_po_REC.VENDOR_SITE_ID
                       AND PVSA.ATTRIBUTE4 = OTT.NAME
                       AND ott.language = 'US'
                       AND OTT_ALL.ORG_ID = HOU.ORGANIZATION_ID
                       AND OTT_ALL.TRANSACTION_TYPE_ID =
                           OTT.TRANSACTION_TYPE_ID
                       AND HOU.NAME = 'Deckers Macau OU'
                       AND PVSA.ATTRIBUTE_CATEGORY = 'Supplier Data Elements';

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Order Type -' || L_HEADER_REC.ORDER_TYPE_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    P_FLAG   := 'N';
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'ORDER TYPE NOT FOUND FOR PO#-CUST ACCT: '
                        || L_HEADER_REC.CUST_PO_NUMBER
                        || '-'
                        || get_approved_po_REC.account_name
                        || CHR (10));
            END;

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'after order type');

            BEGIN
                SELECT LINE_TYPE_ID
                  INTO ln_line_type_id
                  FROM oe_workflow_assignments
                 WHERE     ORDER_TYPE_ID = l_header_rec.ORDER_type_id
                       AND PROCESS_NAME = 'R_STANDARD_LINE';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'line_type_id NOT FOUND FOR PO#-CUST ACCT'
                        || l_HEADER_REC.CUST_PO_NUMBER
                        || '-'
                        || get_approved_po_REC.account_name
                        || CHR (10));
                    p_flag   := 'N';
            END;

            --Start Modification by BT Technology Team v1.1 on 23-JUL-2015 for CR# 104
            BEGIN
                SELECT                                        --flv.attribute6
                       FLV.ATTRIBUTE5,                           -- CCR0006934
                                       FLV.attribute6, FLV.attribute7, --CCR0006934
                       flv.attribute8                            -- CCR0006934
                  INTO v_days_air,                               -- CCR0006934
                                   v_days_ocean,                 -- CCR0006934
                                                 v_days_truck,   -- CCR0006934
                                                               v_preferred_ship_method
                  -- INTO ln_no_of_days
                  FROM fnd_lookup_values flv
                 WHERE     flv.language = 'US'
                       AND flv.lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND flv.attribute1 = get_approved_po_rec.vendor_id
                       AND flv.attribute2 =
                           get_approved_po_rec.vendor_site_code
                       AND flv.attribute3 = 'JP'
                       AND flv.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN flv.start_date_active
                                       AND NVL (flv.end_date_active,
                                                SYSDATE + 1);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_no_of_days   := 0;
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Transit days not defined for Vendor Id: '
                        || get_approved_po_rec.vendor_id
                        || ' vendor site: '
                        || get_approved_po_rec.vendor_site_code);
                --begin for -- CCR0006934
                WHEN OTHERS
                THEN
                    ln_no_of_days   := 0;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, SQLERRM);
            --end for -- CCR0006934
            END;



            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Transit Days in Ocean ln_no_of_days- ' || ln_no_of_days);

            --End Modification by BT Technology Team v1.1 on 23-JUL-2015 for CR# 104

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'after line order type');



            OPEN get_approved_po_lines (l_header_rec.sold_to_org_id,
                                        get_approved_po_REC.PO_HEADER_ID,
                                        get_approved_po_REC.ORG_ID);

            --start of changes by BT Tech Team for Defect 420  on 3rd Nov 2015
            l_line_tbl.delete;
            lt_order_lines_data.delete;
            ln_line_index                           := 1;

            --end of changes by BT Tech Team for Defect 420 on 3rd Nov 2015


            LOOP
                FETCH get_approved_po_lines
                    BULK COLLECT INTO lt_order_lines_data
                    LIMIT 50;


                FND_FILE.PUT_LINE (FND_FILE.LOG, 'after line loop');

                EXIT WHEN lt_order_lines_data.COUNT = 0;

                --start of changes by BT Tech Team for Defect 420
                --ln_line_index := 1;
                --end of changes by BT Tech Team for Defect 420

                FOR xc_order_idx IN lt_order_lines_data.FIRST ..
                                    lt_order_lines_data.LAST
                LOOP
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'PO Need By Date :'
                        || TRUNC (
                               lt_order_lines_data (xc_order_idx).need_by_date));

                    --Begin for  CCR0006934--Move to line_level
                    IF NVL (lt_order_lines_data (xc_order_idx).ship_method,
                            v_preferred_ship_method) =
                       'Air'
                    THEN
                        ln_no_of_days   := TO_NUMBER (v_days_air);
                    ELSIF NVL (
                              lt_order_lines_data (xc_order_idx).ship_method,
                              v_preferred_ship_method) =
                          'Truck'
                    THEN
                        ln_no_of_days   := TO_NUMBER (v_days_truck);
                    ELSE
                        ln_no_of_days   := TO_NUMBER (v_days_ocean);
                    END IF;

                    --If not defined at this point set to 0
                    ln_no_of_days   := NVL (ln_no_of_days, 0);

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'No of days :' || TO_CHAR (ln_no_of_days));

                    -- end for CCR0006934

                    l_line_tbl (ln_line_index)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_index).source_type_code   :=
                        get_approved_po_REC.SOURCE_TYPE;
                    --Start Modification by BT Technology Team v1.1 on 23-JUL-2015 for CR# 104
                    /*l_line_tbl (ln_line_index).request_date :=
                       TRUNC (lt_order_lines_data (xc_order_idx).need_by_date);*/
                    l_line_tbl (ln_line_index).request_date   :=
                        GREATEST (
                              TRUNC (
                                  lt_order_lines_data (xc_order_idx).promised_date)
                            - ln_no_of_days,
                            TRUNC (SYSDATE));
                    --End Modification by BT Technology Team v1.1 on 23-JUL-2015 for CR# 104
                    FND_FILE.PUT_LINE (FND_FILE.LOG, 'after date');
                    -- Line attributes
                    l_line_tbl (ln_line_index).inventory_item_id   :=
                        lt_order_lines_data (xc_order_idx).ITEM_ID;  --382075;
                    l_line_tbl (ln_line_index).ordered_quantity   :=
                        lt_order_lines_data (xc_order_idx).QUANTITY;
                    l_line_tbl (ln_line_index).order_quantity_uom   :=
                        lt_order_lines_data (xc_order_idx).UOM;
                    l_line_tbl (ln_line_index).line_number   :=
                        lt_order_lines_data (xc_order_idx).line_num;
                    l_line_tbl (ln_line_index).shipment_number   :=
                        lt_order_lines_data (xc_order_idx).shipment_num;
                    l_line_tbl (ln_line_index).orig_sys_line_ref   :=
                        lt_order_lines_data (xc_order_idx).po_line_id;


                    --l_line_tbl (ln_line_index).ship_from_org_id := 262;
                    --   l_line_tbl ( ln_line_index ) .subinventory      := 'FGI';
                    l_line_tbl (ln_line_index).operation   :=
                        oe_globals.g_opr_create;

                    l_line_tbl (ln_line_index).line_type_id   :=
                        ln_line_type_id;

                    --   l_line_tbl (ln_line_index).cancelled_flag := 'N';

                    ln_line_index   :=
                        ln_line_index + 1;
                END LOOP;
            END LOOP;

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'before close line loop');

            CLOSE get_approved_po_lines;

            l_action_request_tbl (1)                :=
                oe_order_pub.g_miss_request_rec;
            l_action_request_tbl (1).request_type   :=
                oe_globals.g_book_order;
            l_action_request_tbl (1).entity_code    :=
                oe_globals.g_entity_header;

            IF P_FLAG = 'Y'
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG, 'before process order new');

                process_order_PRC (p_errbuf,
                                   p_retcode,
                                   l_header_rec,
                                   l_line_tbl,
                                   l_header_rec_out,
                                   l_line_tbl_out,
                                   l_action_request_tbl,
                                   get_approved_po_REC.account_name);

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'AFTER process order p_retcode:' || p_retcode);


                IF P_RETCODE = 0
                THEN
                    FOR I IN l_line_tbl_out.FIRST .. l_line_tbl_out.LAST
                    LOOP
                        BEGIN
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   'inside get_list_price'
                                || l_header_rec_out.header_id
                                || CHR (10)
                                || l_line_tbl_out (i).unit_selling_price
                                || CHR (10)
                                || get_approved_po_REC.vendor_id
                                || CHR (10)
                                || l_line_tbl_out (i).INVENTORY_item_id
                                || CHR (10)
                                || get_approved_po_REC.ship_TO_organization_id
                                || CHR (10)
                                || l_line_tbl_out (i).line_id);

                            SELECT get_list_price (
                                       l_header_rec_out.header_id,
                                       l_line_tbl_out (i).unit_selling_price,
                                       get_approved_po_REC.vendor_id,
                                       l_line_tbl_out (i).INVENTORY_item_id,
                                       get_approved_po_REC.ship_TO_organization_id)
                              INTO v_unit_price
                              FROM po_lines_all pla
                             WHERE     l_line_tbl_out (i).line_id =
                                       pla.attribute5
                                   AND pla.ATTRIBUTE_CATEGORY =
                                       'Intercompany PO Copy';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                NULL;
                        END;

                        FND_FILE.PUT_LINE (FND_FILE.LOG,
                                           'v_unit_price: ' || v_unit_price);

                        IF v_unit_price IS NOT NULL
                        THEN
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   'inside UPDATE_UNIT_PRICE'
                                || get_approved_po_REC.PO_NUMBER
                                || CHR (10)
                                || get_approved_po_REC.vendor_id
                                || CHR (10)
                                || l_line_tbl_out (i).LINE_NUMber
                                || CHR (10)
                                || l_line_tbl_out (i).SHIPMENT_NUMber
                                || CHR (10)
                                || get_approved_po_REC.ORG_ID
                                || CHR (10)
                                || V_UNIT_PRICE);

                            UPDATE_UNIT_PRICE (
                                get_approved_po_REC.PO_NUMBER,
                                l_line_tbl_out (i).LINE_NUMber,
                                l_line_tbl_out (i).SHIPMENT_NUMber,
                                V_UNIT_PRICE,
                                get_approved_po_REC.ORG_ID);
                        END IF;
                    END LOOP;

                    PO_APPROVAL (get_approved_po_REC.PO_NUMBER, get_approved_po_REC.ORG_ID, p_retcode
                                 , p_errbuf);
                END IF;



                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'after process order' || p_errbuf);
            END IF;



            P_FLAG                                  := 'Y';
        END LOOP;


        CLOSE get_approved_po;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_approved_po%ISOPEN
            THEN
                CLOSE get_approved_po;
            END IF;

            IF get_approved_po_lines%ISOPEN
            THEN
                CLOSE get_approved_po_lines;
            END IF;


            p_errbuf    := 'Error in main procedure: ' || SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in main procedure: ' || SQLERRM);

            p_retcode   := 2;
            RETURN;
    END;

    PROCEDURE SO_HEADER_VALIDATION (P_HEADER_REC IN OUT oe_order_pub.header_rec_type, P_CUST_ACCOUNT_NAME IN VARCHAR2, P_CUSTOMER IN VARCHAR2
                                    , P_FLAG IN OUT VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'P_CUSTOMER' || P_CUSTOMER);

        BEGIN
            SELECT HCsu.SITE_use_ID
              INTO P_HEADER_REC.ship_to_org_id
              FROM HZ_CUST_ACCT_SITES_ALL HCAS, HZ_CUST_ACCOUNTS HCA, HZ_CUSt_SITe_uses_all hcsu,
                   HR_ORGANIZATION_UNITS HOU
             WHERE     HCA.ACCOUNT_NAME = P_CUSTOMER
                   AND HCA.CUST_ACCOUNT_ID = HCAS.CUST_ACCOUNT_ID
                   AND HCAS.ORG_ID = HOU.ORGANIZATION_ID
                   AND HOU.NAME = 'Deckers Macau OU'
                   AND hcsu.CUST_ACCT_SITE_ID = hcas.CUST_ACCT_SITE_ID
                   AND hcsu.sitE_use_code = 'SHIP_TO'
                   AND hcsu.PRIMARY_FLAG = 'Y'
                   AND hcsu.STATUS = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                P_FLAG   := 'N';
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Ship_to NOT FOUND FOR PO#-CUST ACCT: '
                    || P_HEADER_REC.CUST_PO_NUMBER
                    || '-'
                    || P_CUST_ACCOUNT_NAME
                    || CHR (10));
        END;

        /* BEGIN
            SELECT HCsu.SITE_use_ID
              INTO P_HEADER_REC.INVOICE_to_org_id
              FROM HZ_CUST_ACCT_SITES_ALL HCAS,
                   HZ_CUSt_SITe_uses_all hcsu,
                   HR_ORGANIZATION_UNITS HOU
             WHERE     HCAS.CUST_ACCOUNT_ID = P_HEADER_REC.SOLD_TO_ORG_ID
                   AND HCAS.ORG_ID = HOU.ORGANIZATION_ID
                   AND HOU.NAME = 'Deckers Macau OU'
                   AND hcsu.CUST_ACCT_SITE_ID = hcas.CUST_ACCT_SITE_ID
                   AND hcsu.sitE_use_code = 'BILL_TO'
                   AND hcsu.PRIMARY_FLAG = 'Y'
                   AND hcsu.STATUS = 'A';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               P_FLAG := 'N';
               FND_FILE.PUT_LINE (
                  FND_FILE.LOG,
                     'bill_to NOT FOUND FOR PO#-CUST ACCT: '
                  || P_HEADER_REC.CUST_PO_NUMBER
                  || '-'
                  || P_CUST_ACCOUNT_NAME
                  || CHR (10));
         END;*/



        BEGIN
            SELECT qpl.PRICE_LIST_ID, QPL.CURRENCY_CODE
              INTO P_HEADER_REC.PRICE_LIST_ID, P_HEADER_REC.transactional_curr_code
              FROM qp_price_lists_v qpl
             WHERE qpl.name = fnd_profile.VALUE ('XXDO_TQ_SO_PRICELIST');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                P_FLAG   := 'N';
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'PRICE LIST NOT FOUND FOR PO#-CUST ACCT: '
                    || P_HEADER_REC.CUST_PO_NUMBER
                    || '-'
                    || P_CUST_ACCOUNT_NAME
                    || CHR (10));
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Error in SO HEADER VALIDATION procedure FOR PO#-CUST ACCT: '
                || P_HEADER_REC.CUST_PO_NUMBER
                || '-'
                || P_CUST_ACCOUNT_NAME
                || '|'
                || SQLERRM);
            P_FLAG   := 'N';
            RETURN;
    END;
END XXDO_B2B_PO_COPY_PKG;
/
