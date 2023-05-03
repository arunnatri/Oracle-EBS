--
-- XXDOEC_PROCESS_SFS_SHIPMENTS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PROCESS_SFS_SHIPMENTS"
AS
    /******************************************************************************************************
       * Program Name : XXDOEC_PROCESS_SFS_SHIPMENTS
       * Description  :
       *
       * REVISION History :
       *
       * ===============================================================================
       * Who                   Version    Comments                          When
       * ===============================================================================
       * Vijay Reddy           1.0        Initial Version
       * Vijay Reddy           1.1        Added a check to ignore Cancelled Lines 01/24/2019 CCR0007769
       *
       ******************************************************************************************************/
    PROCEDURE populate_sfs_shipment_dtls (
        P_WEB_ORDER_NUMBER      IN     VARCHAR2,
        P_LINE_ID               IN     NUMBER,
        P_ITEM_CODE             IN     VARCHAR2,
        P_STATUS                IN     VARCHAR2,
        P_STORE_NUMBER          IN     VARCHAR2,
        P_SHIPPED_DATE          IN     DATE,
        P_SHIPPED_QUANTITY      IN     NUMBER,
        P_UNIT_PRICE            IN     NUMBER,
        P_SHIP_METHOD_CODE      IN     VARCHAR2,
        P_TRACKING_NUMBER       IN     VARCHAR2,
        P_PROCESS_FLAG          IN     VARCHAR2,
        P_ERROR_MESSAGE         IN     VARCHAR2,
        P_PO_LINE_LOCATION_ID   IN     NUMBER,
        P_CREATION_DATE         IN     DATE,
        P_LAST_UPDATE_DATE      IN     DATE,
        X_RTN_STATUS               OUT VARCHAR2,
        X_RTN_MESSAGE              OUT VARCHAR2)
    IS
        CURSOR c_dup_check IS
            SELECT sfs_shipment_id
              FROM xxdoec_sfs_shipment_dtls_stg
             WHERE line_id = p_line_id;

        l_sfs_shipment_id   NUMBER;
        l_dummy             NUMBER;
        l_duplicate_excep   EXCEPTION;
    BEGIN
        OPEN c_dup_check;

        FETCH c_dup_check INTO l_dummy;

        IF c_dup_check%FOUND
        THEN
            CLOSE c_dup_check;

            RAISE l_duplicate_excep;
        ELSE
            CLOSE c_dup_check;

            -- Insert Shipment record
            SELECT xxdo.xxdoec_sfs_shipment_dtls_stg_s.NEXTVAL
              INTO l_sfs_shipment_id
              FROM DUAL;

            --

            INSERT INTO XXDOEC_SFS_SHIPMENT_DTLS_STG (SFS_SHIPMENT_ID, WEB_ORDER_NUMBER, LINE_ID, ITEM_CODE, STATUS, STORE_NUMBER, SHIPPED_DATE, SHIPPED_QUANTITY, UNIT_PRICE, SHIP_METHOD_CODE, TRACKING_NUMBER, PROCESS_FLAG, ERROR_MESSAGE, PO_LINE_LOCATION_ID, CREATION_DATE
                                                      , LAST_UPDATE_DATE)
                 VALUES (l_sfs_shipment_id, P_WEB_ORDER_NUMBER, P_LINE_ID,
                         P_ITEM_CODE, P_STATUS, P_STORE_NUMBER,
                         P_SHIPPED_DATE, P_SHIPPED_QUANTITY, P_UNIT_PRICE,
                         P_SHIP_METHOD_CODE, P_TRACKING_NUMBER, P_PROCESS_FLAG, P_ERROR_MESSAGE, P_PO_LINE_LOCATION_ID, P_CREATION_DATE
                         , P_LAST_UPDATE_DATE);
        END IF;
    EXCEPTION
        WHEN l_duplicate_excep
        THEN
            x_rtn_status   := 'E';
            x_rtn_message   :=
                   'Duplicate Shipment Record. Order ID: '
                || p_web_order_number
                || ' Order Line ID: '
                || p_line_id;
        WHEN OTHERS
        THEN
            x_rtn_status   := 'U';
            x_rtn_message   :=
                   'Un-expected Error while populating SFS Shipment details. Error: '
                || SQLERRM;
    END populate_sfs_shipment_dtls;

    -- +++++++++++++++++++++++++++++++++++++

    PROCEDURE receive_po_lines (x_errbuf               OUT VARCHAR2,
                                x_retcode              OUT NUMBER,
                                p_sfs_shipment_id   IN     NUMBER)
    IS
        l_user_id      NUMBER := fnd_global.USER_ID;
        l_request_id   NUMBER;

        CURSOR c_shipments IS
            SELECT ool.header_id, fu.user_name, ssd.*
              FROM xxdoec_sfs_shipment_dtls_stg ssd, oe_order_lines_all ool, fnd_user fu
             WHERE     ool.line_id = ssd.line_id
                   AND NVL (ool.cancelled_flag, 'N') <> 'Y'      -- CCR0007769
                   AND fu.user_id = ool.created_by
                   AND NVL (ssd.process_flag, 'N') IN ('N', 'E')
                   AND ssd.sfs_shipment_id =
                       NVL (p_sfs_shipment_id, sfs_shipment_id);

        CURSOR c_po_lines_to_receive (p_order_line_id IN NUMBER)
        IS
            SELECT pol.item_id, pol.line_num, pll.quantity,
                   pol.unit_meas_lookup_code, mp.organization_code, pll.closed_code,
                   pll.quantity_received, pll.cancel_flag, pll.shipment_num,
                   pll.line_location_id, pol.po_line_id, poh.po_header_id,
                   poh.vendor_id
              FROM apps.oe_drop_ship_sources dss, apps.po_line_locations_all pll, apps.po_lines_all pol,
                   apps.po_headers_all poh, apps.mtl_parameters mp
             WHERE     dss.line_id = p_order_line_id
                   AND pll.line_location_id = dss.line_location_id
                   AND pol.po_line_id = pll.po_line_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pll.ship_to_organization_id = mp.organization_id;
    BEGIN
        FOR c_sh IN c_shipments
        LOOP
            BEGIN
                FOR c1 IN c_po_lines_to_receive (c_sh.line_id)
                LOOP
                    BEGIN
                        -- populate interface header
                        INSERT INTO RCV_HEADERS_INTERFACE (
                                        HEADER_INTERFACE_ID,
                                        GROUP_ID,
                                        PROCESSING_STATUS_CODE,
                                        RECEIPT_SOURCE_CODE,
                                        TRANSACTION_TYPE,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATE_LOGIN,
                                        VENDOR_ID,
                                        EXPECTED_RECEIPT_DATE,
                                        VALIDATION_FLAG)
                            SELECT RCV_HEADERS_INTERFACE_S.NEXTVAL, RCV_INTERFACE_GROUPS_S.NEXTVAL, 'PENDING',
                                   'VENDOR', 'NEW', SYSDATE,
                                   l_USER_ID, 0, c1.VENDOR_ID,
                                   SYSDATE, 'Y'
                              FROM DUAL;

                        --
                        IF     c1.CLOSED_CODE IN ('APPROVED', 'OPEN')
                           AND c1.QUANTITY_RECEIVED < c1.QUANTITY
                           AND NVL (c1.CANCEL_FLAG, 'N') = 'N'
                        THEN
                            -- populate interface lines
                            INSERT INTO RCV_TRANSACTIONS_INTERFACE (
                                            INTERFACE_TRANSACTION_ID,
                                            GROUP_ID,
                                            LAST_UPDATE_DATE,
                                            LAST_UPDATED_BY,
                                            CREATION_DATE,
                                            CREATED_BY,
                                            LAST_UPDATE_LOGIN,
                                            TRANSACTION_TYPE,
                                            TRANSACTION_DATE,
                                            PROCESSING_STATUS_CODE,
                                            PROCESSING_MODE_CODE,
                                            TRANSACTION_STATUS_CODE,
                                            PO_HEADER_ID,
                                            PO_LINE_ID,
                                            ITEM_ID,
                                            QUANTITY,
                                            UNIT_OF_MEASURE,
                                            PO_LINE_LOCATION_ID,
                                            AUTO_TRANSACT_CODE,
                                            DESTINATION_TYPE_CODE,
                                            RECEIPT_SOURCE_CODE,
                                            TO_ORGANIZATION_CODE,
                                            SUBINVENTORY,
                                            LOCATOR_ID,
                                            SOURCE_DOCUMENT_CODE,
                                            HEADER_INTERFACE_ID,
                                            VALIDATION_FLAG)
                                SELECT RCV_TRANSACTIONS_INTERFACE_S.NEXTVAL, RCV_INTERFACE_GROUPS_S.CURRVAL, SYSDATE,
                                       l_USER_ID, SYSDATE, l_USER_ID,
                                       0, 'RECEIVE', SYSDATE,
                                       'PENDING', 'BATCH', 'PENDING',
                                       c1.PO_HEADER_ID, c1.PO_LINE_ID, c1.ITEM_ID,
                                       c_sh.SHIPPED_QUANTITY, c1.UNIT_MEAS_LOOKUP_CODE, c1.LINE_LOCATION_ID,
                                       'DELIVER', 'INVENTORY', 'VENDOR',
                                       c1.ORGANIZATION_CODE, 'RECEIVING', NULL,
                                       'PO', RCV_HEADERS_INTERFACE_S.CURRVAL, 'Y'
                                  FROM DUAL;

                            --
                            UPDATE xxdoec_sfs_shipment_dtls_stg
                               SET po_line_location_id = c1.line_location_id, process_flag = 'Y', last_update_date = SYSDATE
                             WHERE sfs_shipment_id = c_sh.sfs_shipment_id;

                            -- Populate Store ID
                            IF c_sh.store_number IS NOT NULL -- start CCR0007769
                            THEN
                                INSERT INTO APPS.XXDOEC_ORDER_ATTRIBUTE (
                                                ATTRIBUTE_ID,
                                                ATTRIBUTE_TYPE,
                                                ATTRIBUTE_VALUE,
                                                USER_NAME,
                                                ORDER_HEADER_ID,
                                                LINE_ID,
                                                CREATION_DATE)
                                     VALUES (XXDOEC_ATTRIBUTE_ID_S.NEXTVAL, 'STOREID', c_sh.store_number, c_sh.user_name, c_sh.header_id, c_sh.line_id
                                             , SYSDATE);
                            END IF;                          -- End CCR0007769

                            COMMIT;
                        ELSE
                            ROLLBACK;

                            --
                            UPDATE xxdoec_sfs_shipment_dtls_stg
                               SET po_line_location_id = c1.line_location_id, process_flag = 'E', error_message = 'PO line ' || c1.LINE_NUM || ' is either closed, cancelled, received.',
                                   last_update_date = SYSDATE
                             WHERE sfs_shipment_id = c_sh.sfs_shipment_id;

                            COMMIT;
                            FND_FILE.put_line (
                                FND_FILE.LOG,
                                   'PO line '
                                || c1.LINE_NUM
                                || ' is either closed, cancelled, received.');
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FND_FILE.put_line (FND_FILE.LOG, SQLERRM);
                    END;
                END LOOP;                                           -- c1 loop
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := -1;
                    x_errbuf    := SQLERRM;
            END;
        END LOOP;                                                 -- c_sh loop

        -- Submit RTP concurrent job
        l_request_id   :=
            FND_REQUEST.SUBMIT_REQUEST ('PO', 'RVCTP', 'RECEIVE REQUEST',
                                        NULL, FALSE, 'BATCH',
                                        NULL);

        IF l_request_id <> 0
        THEN
            COMMIT;
            FND_FILE.put_line (FND_FILE.LOG,
                               '*** Request ID: ' || l_request_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := -2;
            x_errbuf    := SQLERRM;
    END receive_po_lines;
END xxdoec_process_sfs_shipments;
/
