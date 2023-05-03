--
-- XXD_WMS_OH_INTR_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_OH_INTR_CONV_PKG"
AS
    /******************************************************************************************
     * Package      : XXD_WMS_OH_INTR_CONV_PKG
     * Design       : This package is used for creating IR/ISO to move OH inventory from one org to anorther
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 03-SEP-2019  1.0        Greg Jensen           Initial Version
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
        := 'Deckers Order Management Super User' ;
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
    gv_ir_interface_source_code             VARCHAR2 (40) := 'OH_CONV';

    gn_master_org                  CONSTANT NUMBER := 106;
    gn_mrp_not_planned             CONSTANT NUMBER := 6;         --Not Planned

    /**********************
   Logging
   **********************/
    PROCEDURE insert_message (pv_message_type   IN VARCHAR2,
                              pv_message        IN VARCHAR2)
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insert_message;

    --Wrapper around executing con current request with wait for completion
    PROCEDURE exec_conc_request (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_request_id OUT NUMBER, pv_application IN VARCHAR2 DEFAULT NULL, pv_program IN VARCHAR2 DEFAULT NULL, pv_argument1 IN VARCHAR2 DEFAULT CHR (0), pv_argument2 IN VARCHAR2 DEFAULT CHR (0), pv_argument3 IN VARCHAR2 DEFAULT CHR (0), pv_argument4 IN VARCHAR2 DEFAULT CHR (0), pv_argument5 IN VARCHAR2 DEFAULT CHR (0), pv_argument6 IN VARCHAR2 DEFAULT CHR (0), pv_argument7 IN VARCHAR2 DEFAULT CHR (0), pv_argument8 IN VARCHAR2 DEFAULT CHR (0), pv_argument9 IN VARCHAR2 DEFAULT CHR (0), pv_argument10 IN VARCHAR2 DEFAULT CHR (0), pv_argument11 IN VARCHAR2 DEFAULT CHR (0), pv_argument12 IN VARCHAR2 DEFAULT CHR (0), pv_argument13 IN VARCHAR2 DEFAULT CHR (0), pv_argument14 IN VARCHAR2 DEFAULT CHR (0), pv_argument15 IN VARCHAR2 DEFAULT CHR (0), pv_argument16 IN VARCHAR2 DEFAULT CHR (0), pv_argument17 IN VARCHAR2 DEFAULT CHR (0), pv_argument18 IN VARCHAR2 DEFAULT CHR (0), pv_argument19 IN VARCHAR2 DEFAULT CHR (0), pv_argument20 IN VARCHAR2 DEFAULT CHR (0), pv_argument21 IN VARCHAR2 DEFAULT CHR (0), pv_argument22 IN VARCHAR2 DEFAULT CHR (0), pv_argument23 IN VARCHAR2 DEFAULT CHR (0), pv_argument24 IN VARCHAR2 DEFAULT CHR (0), pv_argument25 IN VARCHAR2 DEFAULT CHR (0), pv_argument26 IN VARCHAR2 DEFAULT CHR (0), pv_argument27 IN VARCHAR2 DEFAULT CHR (0), pv_argument28 IN VARCHAR2 DEFAULT CHR (0), pv_argument29 IN VARCHAR2 DEFAULT CHR (0), pv_argument30 IN VARCHAR2 DEFAULT CHR (0), pv_argument31 IN VARCHAR2 DEFAULT CHR (0), pv_argument32 IN VARCHAR2 DEFAULT CHR (0), pv_argument33 IN VARCHAR2 DEFAULT CHR (0), pv_argument34 IN VARCHAR2 DEFAULT CHR (0), pv_argument35 IN VARCHAR2 DEFAULT CHR (0), pv_argument36 IN VARCHAR2 DEFAULT CHR (0), pv_argument37 IN VARCHAR2 DEFAULT CHR (0), pv_argument38 IN VARCHAR2 DEFAULT CHR (0), pv_wait_for_request IN VARCHAR2 DEFAULT 'Y', pn_interval IN NUMBER DEFAULT 60
                                 , pn_max_wait IN NUMBER DEFAULT 0)
    IS
        l_req_status   BOOLEAN;
        l_request_id   NUMBER;

        l_phase        VARCHAR2 (120 BYTE);
        l_status       VARCHAR2 (120 BYTE);
        l_dev_phase    VARCHAR2 (120 BYTE);
        l_dev_status   VARCHAR2 (120 BYTE);
        l_message      VARCHAR2 (2000 BYTE);
    BEGIN
        l_request_id   :=
            apps.fnd_request.submit_request (application   => pv_application,
                                             program       => pv_program,
                                             start_time    => SYSDATE,
                                             sub_request   => FALSE,
                                             argument1     => pv_argument1,
                                             argument2     => pv_argument2,
                                             argument3     => pv_argument3,
                                             argument4     => pv_argument4,
                                             argument5     => pv_argument5,
                                             argument6     => pv_argument6,
                                             argument7     => pv_argument7,
                                             argument8     => pv_argument8,
                                             argument9     => pv_argument9,
                                             argument10    => pv_argument10,
                                             argument11    => pv_argument11,
                                             argument12    => pv_argument12,
                                             argument13    => pv_argument13,
                                             argument14    => pv_argument14,
                                             argument15    => pv_argument15,
                                             argument16    => pv_argument16,
                                             argument17    => pv_argument17,
                                             argument18    => pv_argument18,
                                             argument19    => pv_argument19,
                                             argument20    => pv_argument20,
                                             argument21    => pv_argument21,
                                             argument22    => pv_argument22,
                                             argument23    => pv_argument23,
                                             argument24    => pv_argument24,
                                             argument25    => pv_argument25,
                                             argument26    => pv_argument26,
                                             argument27    => pv_argument27,
                                             argument28    => pv_argument28,
                                             argument29    => pv_argument29,
                                             argument30    => pv_argument30,
                                             argument31    => pv_argument31,
                                             argument32    => pv_argument32,
                                             argument33    => pv_argument33,
                                             argument34    => pv_argument34,
                                             argument35    => pv_argument35,
                                             argument36    => pv_argument36,
                                             argument37    => pv_argument37,
                                             argument38    => pv_argument38);
        COMMIT;

        IF l_request_id <> 0
        THEN
            IF pv_wait_for_request = 'Y'
            THEN
                l_req_status   :=
                    apps.fnd_concurrent.wait_for_request (
                        request_id   => l_request_id,
                        interval     => pn_interval,
                        max_wait     => pn_max_wait,
                        phase        => l_phase,
                        status       => l_status,
                        dev_phase    => l_dev_phase,
                        dev_status   => l_dev_status,
                        MESSAGE      => l_message);



                IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
                THEN
                    IF NVL (l_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        pv_error_stat   := 'W';
                    ELSE
                        pv_error_stat   := apps.fnd_api.g_ret_sts_error;
                    END IF;

                    pv_error_msg   :=
                        NVL (
                            l_message,
                               'The request ended with a status of '
                            || NVL (l_dev_status, 'ERROR'));
                ELSE
                    pv_error_stat   := 'S';
                END IF;
            ELSE
                pv_error_stat   := 'S';
            END IF;
        ELSE
            pv_error_stat   := 'E';
            pv_error_msg    := 'No request launched';
            pn_request_id   := NULL;
            RETURN;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error : ' || SQLERRM;
    END;


    PROCEDURE insert_into_oh_table (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_inv_org_id IN NUMBER, pv_brand IN VARCHAR2:= NULL, pv_style IN VARCHAR2:= NULL, pn_dest_inv_org_id IN NUMBER
                                    , pn_max_req_qty IN NUMBER:= 1000)
    IS
        CURSOR c_rec IS
            SELECT (SELECT operating_unit
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = a.organization_id)
                       org_id,
                   a.organization_id,
                   a.organization_code,
                   a.inventory_item_id,
                   a.primary_transaction_quantity
                       ttl_qty,
                   a.transaction_uom_code
                       uom_code,
                   LEAST (
                       receipt_quantity,
                         LEAST (primary_transaction_quantity - running_total,
                                primary_transaction_quantity)
                       + receipt_quantity)
                       quantity,
                   rcv_date
                       inv_date,
                   apps.iid_to_sku (inventory_item_id)
                       sku,
                   (SELECT brand
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = a.organization_id
                           AND vw.inventory_item_id = a.inventory_item_id)
                       brand,
                   (SELECT style_number
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = a.organization_id
                           AND vw.inventory_item_id = a.inventory_item_id)
                       style,
                   (SELECT list_price_per_unit
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = a.organization_id
                           AND msib.inventory_item_id = a.inventory_item_id)
                       unit_price
              FROM (  SELECT moqd.organization_id, mp.organization_code, moqd.primary_transaction_quantity,
                             moqd.transaction_uom_code, moqd.inventory_item_id, rt.quantity receipt_quantity,
                             rt.transaction_date rcv_date, SUM (rt.quantity) OVER (PARTITION BY moqd.organization_id, moqd.inventory_item_id ORDER BY rt.transaction_date DESC) AS running_total
                        FROM (  SELECT organization_id, SUM (primary_transaction_quantity) primary_transaction_quantity, inventory_item_id,
                                       transaction_uom_code
                                  FROM apps.mtl_onhand_quantities_detail
                              GROUP BY organization_id, inventory_item_id, transaction_uom_code)
                             moqd,
                             (  SELECT rt1.organization_id, TRUNC (rt1.transaction_date) transaction_date, SUM (rt1.quantity) quantity,
                                       rsl.item_id
                                  FROM rcv_transactions rt1, rcv_shipment_lines rsl
                                 WHERE     transaction_type = 'DELIVER'
                                       AND rt1.destination_type_code =
                                           'INVENTORY'
                                       AND rt1.source_document_code IN
                                               ('PO', 'REQ')
                                       AND rt1.shipment_line_id =
                                           rsl.shipment_line_id
                              GROUP BY rt1.organization_id, TRUNC (rt1.transaction_date), rsl.item_id)
                             rt,
                             mtl_parameters mp
                       WHERE     1 = 1
                             AND moqd.organization_id = rt.organization_id
                             AND moqd.inventory_item_id = rt.item_id
                             AND moqd.organization_id = mp.organization_id
                             AND mp.organization_id = pn_inv_org_id
                             AND XXD_WMS_OH_INTR_CONV_PKG.check_item_attributes (
                                     moqd.inventory_item_id,
                                     pn_inv_org_id,
                                     pn_dest_inv_org_id) =
                                 1
                             AND moqd.inventory_item_id IN
                                     (SELECT DISTINCT inventory_item_id
                                        FROM apps.xxd_common_items_v
                                       WHERE     brand = pv_brand
                                             AND organization_id =
                                                 gn_master_org
                                             AND style_number =
                                                 NVL (pv_style, style_number))
                    ORDER BY moqd.organization_id, moqd.inventory_item_id, rt.transaction_date DESC)
                   a
             WHERE   LEAST (primary_transaction_quantity - running_total,
                            primary_transaction_quantity)
                   + receipt_quantity >
                   0
            UNION
            SELECT (SELECT operating_unit
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = moqd.organization_id)
                       org_id,
                   moqd.organization_id,
                   organization_code,
                   inventory_item_id,
                   primary_transaction_quantity,
                   transaction_uom_code,
                     primary_transaction_quantity
                   - NVL (
                         (SELECT SUM (rt1.quantity)
                            FROM rcv_transactions rt1, rcv_shipment_lines rsl
                           WHERE     transaction_type = 'DELIVER'
                                 AND rt1.source_document_code IN
                                         ('PO', 'REQ')
                                 AND rt1.shipment_line_id =
                                     rsl.shipment_line_id
                                 AND moqd.organization_id =
                                     rt1.organization_id
                                 AND moqd.inventory_item_id = rsl.item_id),
                         0)
                       qty,
                   TRUNC (SYSDATE - 30, 'month') + 14
                       inv_date,
                   apps.iid_to_sku (inventory_item_id)
                       sku,
                   (SELECT brand
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = moqd.organization_id
                           AND vw.inventory_item_id = moqd.inventory_item_id)
                       brand,
                   (SELECT style_number
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = moqd.organization_id
                           AND vw.inventory_item_id = moqd.inventory_item_id)
                       style,
                   (SELECT list_price_per_unit
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = moqd.organization_id
                           AND msib.inventory_item_id =
                               moqd.inventory_item_id)
                       unit_price
              FROM (  SELECT organization_id, transaction_uom_code, SUM (primary_transaction_quantity) primary_transaction_quantity,
                             inventory_item_id
                        FROM apps.mtl_onhand_quantities_detail
                    GROUP BY organization_id, inventory_item_id, transaction_uom_code)
                   moqd,
                   mtl_parameters mp
             WHERE     1 = 1
                   AND primary_transaction_quantity >
                       NVL (
                           (SELECT SUM (rt1.quantity)
                              FROM rcv_transactions rt1, rcv_shipment_lines rsl
                             WHERE     transaction_type = 'DELIVER'
                                   AND rt1.source_document_code IN
                                           ('PO', 'REQ')
                                   AND rt1.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND moqd.organization_id =
                                       rt1.organization_id
                                   AND moqd.inventory_item_id = rsl.item_id),
                           0)
                   AND moqd.organization_id = mp.organization_id
                   AND mp.organization_id = pn_inv_org_id
                   AND XXD_WMS_OH_INTR_CONV_PKG.check_item_attributes (
                           moqd.inventory_item_id,
                           pn_inv_org_id,
                           pn_dest_inv_org_id) =
                       1
                   AND moqd.inventory_item_id IN
                           (SELECT DISTINCT inventory_item_id
                              FROM apps.xxd_common_items_v
                             WHERE     brand = pv_brand
                                   AND organization_id = gn_master_org
                                   AND style_number =
                                       NVL (pv_style, style_number))
            ORDER BY 2, 4, 8 DESC;

        ln_record_id           NUMBER;
        ln_dest_org_id         NUMBER;
        ln_ccid                NUMBER;
        ld_need_by_date        DATE;
        ln_group_number        NUMBER := 1;
        ln_rec_number          NUMBER := 1;
        n_cnt                  NUMBER;
        ln_inventory_item_id   NUMBER;
    BEGIN
        --Get dest OU for record
        SELECT operating_unit
          INTO ln_dest_org_id
          FROM apps.org_organization_definitions
         WHERE organization_id = pn_dest_inv_org_id;

        --Get account ID for dest org
        SELECT material_account
          INTO ln_ccid
          FROM mtl_parameters
         WHERE organization_id = pn_dest_inv_org_id;

        --Get Need By Date for req
        SELECT TRUNC (DECODE (TO_CHAR (SYSDATE, 'FMDAY'),  'FRIDAY', SYSDATE + 3,  'SATURDAY', SYSDATE + 2,  SYSDATE + 1))
          INTO ld_need_by_date
          FROM DUAL;

        --Get next group value from seq
        SELECT XXD_WMS_OH_IR_XFER_GRP_SEQ.NEXTVAL
          INTO ln_group_number
          FROM DUAL;

        FOR rec IN c_rec
        LOOP
            --Only add if org/item combination does not exist in staging table for a diffetent session
            SELECT COUNT (*)
              INTO n_cnt
              FROM XXD_WMS_OH_IR_XFER_STG
             WHERE     organization_id = rec.organization_id
                   AND inventory_item_id = rec.inventory_item_id
                   AND request_id != gn_request_id;

            IF n_cnt = 0
            THEN
                --If reachecd max rows start a new group
                IF     ln_rec_number > pn_max_req_qty
                   AND rec.inventory_item_id <> ln_inventory_item_id --Only start new group for new SKU
                THEN
                    SELECT XXD_WMS_OH_IR_XFER_GRP_SEQ.NEXTVAL
                      INTO ln_group_number
                      FROM DUAL;

                    ln_rec_number   := 1;
                END IF;

                SELECT XXD_WMS_OH_IR_XFER_SEQ.NEXTVAL
                  INTO ln_record_id
                  FROM DUAL;

                BEGIN
                    INSERT INTO XXD_WMS_OH_IR_XFER_STG (RECORD_ID, ORG_ID, ORGANIZATION_ID, SUBINVENTORY_CODE, DEST_ORG_ID, DEST_ORGANIZATION_ID, DEST_LOCATION_ID, DEST_SUBINVENTORY_CODE, NEED_BY_DATE, BRAND, STYLE, SKU, INVENTORY_ITEM_ID, UOM_CODE, GROUP_NO, QUANTITY, UNIT_PRICE, AGING_DATE, CHARGE_ACCOUNT_ID, REQ_HEADER_ID, REQ_LINE_ID, STATUS, MESSAGE, REQUEST_ID, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE
                                                        , LAST_UPDATED_BY)
                             VALUES (
                                        ln_record_id,
                                        rec.org_id,
                                        rec.organization_id,
                                        NULL,
                                        ln_dest_org_id,
                                        pn_dest_inv_org_id,
                                        (SELECT location_id
                                           FROM hr_organization_units_v
                                          WHERE organization_id =
                                                pn_dest_inv_org_id),
                                        NULL,        -- rec.subinventory_code,
                                        ld_need_by_date,
                                        rec.brand,
                                        rec.style,                     --style
                                        rec.sku,
                                        rec.inventory_item_id,
                                        rec.uom_code,
                                        ln_group_number,        --group_number
                                        rec.quantity,
                                        rec.unit_price,
                                        rec.inv_date,
                                        ln_ccid,          --charge_account_id,
                                        NULL,                 --rec_header_id,
                                        NULL,                    --rec_line_id
                                        'N',                         --status,
                                        NULL,                       --message,
                                        gn_request_id,           --request_id,
                                        SYSDATE,
                                        fnd_global.user_id,
                                        SYSDATE,
                                        fnd_global.user_id);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        insert_message (
                            'BOTH',
                               'Inv Org ID : '
                            || rec.organization_id
                            || ' Item : '
                            || rec.inventory_item_id
                            || ' Aging Date '
                            || TO_CHAR (rec.inv_date, 'MM-DD-YYYY')
                            || '-'
                            || SQLERRM);
                END;

                ln_rec_number   := ln_rec_number + 1;
            END IF;

            --Set current SKU
            ln_inventory_item_id   := rec.inventory_item_id;
        END LOOP;

        COMMIT;

        SELECT COUNT (*)
          INTO n_cnt
          FROM XXD_WMS_OH_IR_XFER_STG
         WHERE request_id = gn_request_id;

        IF n_cnt = 0
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'No records found for Org/Subinv/(Style)';
            RETURN;
        END IF;



        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE create_oh_xfer_ir (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_src_organization_id IN NUMBER
                                 , pn_dest_organization_id IN NUMBER, pv_brand IN VARCHAR2, pv_style IN VARCHAR2:= NULL)
    IS
        CURSOR c_header_rec IS
            SELECT DISTINCT group_no, dest_org_id
              FROM XXDO.XXD_WMS_OH_IR_XFER_STG stg
             WHERE     organization_id = pn_src_organization_id
                   AND brand = pv_brand
                   AND style = NVL (pv_style, style)
                   AND status = 'P';


        CURSOR c_line_rec (n_group_no NUMBER)
        IS
            SELECT record_id, org_id, dest_org_id,
                   charge_account_id, organization_id, uom_code,
                   quantity, dest_organization_id, dest_location_id,
                   inventory_item_id, aging_date, need_by_date
              FROM XXDO.XXD_WMS_OH_IR_XFER_STG stg
             WHERE group_no = n_group_no;


        lv_src_type_code    VARCHAR2 (20) := 'INVENTORY';
        lv_dest_type_code   VARCHAR2 (20) := 'INVENTORY';
        lv_source_code      VARCHAR2 (20) := gv_ir_interface_source_code;
        ln_batch_id         NUMBER := 1;
        l_request_id        NUMBER;
        l_req_status        BOOLEAN;
        l_dest_org          NUMBER;

        --TODO: need to determine these.
        ln_person_id        NUMBER;
        ln_user_id          NUMBER;


        l_phase             VARCHAR2 (80);
        l_status            VARCHAR2 (80);
        l_dev_phase         VARCHAR2 (80);
        l_dev_status        VARCHAR2 (80);
        l_message           VARCHAR2 (255);

        ln_req_header_id    NUMBER;
    BEGIN
        SELECT employee_id
          INTO ln_person_id
          FROM fnd_user
         WHERE user_name = fnd_global.user_name;


        FOR h_rec IN c_header_rec
        LOOP
            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', h_rec.dest_org_id);
            FND_REQUEST.SET_ORG_ID (h_rec.dest_org_id);

            FOR l_rec IN c_line_rec (h_rec.group_no)
            LOOP
                INSERT INTO APPS.PO_REQUISITIONS_INTERFACE_ALL (
                                BATCH_ID,
                                INTERFACE_SOURCE_CODE,
                                ORG_ID,
                                DESTINATION_TYPE_CODE,
                                AUTHORIZATION_STATUS,
                                PREPARER_ID,
                                CHARGE_ACCOUNT_ID,
                                SOURCE_TYPE_CODE,
                                SOURCE_ORGANIZATION_ID,
                                UOM_CODE,
                                LINE_TYPE_ID,
                                QUANTITY,
                                UNIT_PRICE,
                                DESTINATION_ORGANIZATION_ID,
                                DELIVER_TO_LOCATION_ID,
                                DELIVER_TO_REQUESTOR_ID,
                                ITEM_ID,
                                SUGGESTED_VENDOR_ID,
                                SUGGESTED_VENDOR_SITE_ID,
                                HEADER_DESCRIPTION,
                                NEED_BY_DATE,
                                LINE_ATTRIBUTE11,
                                line_attribute15,
                                CREATION_DATE,
                                CREATED_BY,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY) --Place SO organization code in this field
                         VALUES (
                                    h_rec.group_no,
                                    lv_source_code,
                                    l_rec.dest_org_id,
                                    lv_dest_type_code,
                                    'APPROVED',
                                    ln_person_id,
                                    l_rec.charge_account_id,
                                    lv_src_type_code,
                                    l_rec.organization_id,
                                    (SELECT primary_uom_code
                                       FROM apps.mtl_system_items_b
                                      WHERE     inventory_item_id =
                                                l_rec.inventory_item_id
                                            AND organization_id =
                                                l_rec.dest_organization_id),
                                    1,
                                    l_rec.quantity,
                                    (SELECT list_price_per_unit
                                       FROM apps.mtl_system_items_b
                                      WHERE     inventory_item_id =
                                                l_rec.inventory_item_id
                                            AND organization_id =
                                                l_rec.dest_organization_id),
                                    l_rec.dest_organization_id,
                                    l_rec.dest_location_id,
                                    ln_person_id,
                                    l_rec.inventory_item_id,
                                    NULL,
                                    NULL,
                                    /*   (SELECT description
                                          FROM apps.mtl_system_items_b
                                         WHERE     inventory_item_id = l_rec.inventory_item_id
                                               AND organization_id =
                                                      l_rec.dest_organization_id),*/
                                    NULL,                 --header description
                                    l_rec.need_by_date,
                                    TO_CHAR (l_rec.aging_date, 'DD-MON-YYYY'),
                                    TO_CHAR (l_rec.record_id), --Pointer to sourcing staging record for mapping
                                    SYSDATE,
                                    ln_user_id,
                                    SYSDATE,
                                    ln_user_id); --Set autosource to P so that passed in vendor/vendor site is used
            END LOOP;

            COMMIT;

            exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => l_request_id, pv_application => 'PO', pv_program => 'REQIMPORT', pv_argument1 => lv_source_code, --Interface source code
                                                                                                                                                                                                               pv_argument2 => h_rec.group_no, --batch id
                                                                                                                                                                                                                                               pv_argument3 => 'INVENTORY', pv_argument4 => '', pv_argument5 => 'N', pv_argument6 => 'Y', pv_wait_for_request => 'Y'
                               , pn_interval => 10, pn_max_wait => 90);

            IF pv_error_stat != 'S'
            THEN
                pv_error_stat   := pv_error_stat;
                pv_error_msg    :=
                    'Requisition import error : ' || pv_error_msg;
                RETURN;
            END IF;

            --Get req created
            BEGIN
                SELECT requisition_header_id
                  INTO ln_req_header_id
                  FROM po_requisition_headers_all
                 WHERE     interface_source_code = lv_source_code
                       AND request_id = l_request_id;
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    --Multiple Reqs created. No error
                    NULL;
                WHEN NO_DATA_FOUND
                THEN
                    --If we cannot reteieve the created IR fail these records and continue to next group
                    pv_error_stat   := 'E';
                    pv_error_msg    := 'Unable to find created Requisition';

                    UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
                       SET status = 'E', MESSAGE = 'Error retrieving created internal requisition'
                     WHERE GROUP_NO = h_rec.group_no;


                    CONTINUE;
            END;

            UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
               SET status = 'E', MESSAGE = 'Item not added to requisition'
             WHERE     GROUP_NO = h_rec.group_no
                   AND request_id = gn_request_id
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_header_id =
                                       prha.requisition_header_id
                                   AND prha.interface_source_code =
                                       lv_source_code
                                   AND prla.attribute15 =
                                       TO_CHAR (stg.record_id));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE run_create_internal_orders (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_org_id IN NUMBER)
    IS
        ln_req_request_id   NUMBER;
        ln_user_id          NUMBER := fnd_global.user_id;
        ln_resp_id          NUMBER := fnd_global.resp_id;
        ln_resp_appl_id     NUMBER := fnd_global.resp_appl_id;
        lv_chr_phase        VARCHAR2 (120 BYTE);
        lv_chr_status       VARCHAR2 (120 BYTE);
        lv_chr_dev_phase    VARCHAR2 (120 BYTE);
        lv_chr_dev_status   VARCHAR2 (120 BYTE);
        lv_chr_message      VARCHAR2 (2000 BYTE);
        lb_bol_result       BOOLEAN;
        lv_error_stat       VARCHAR2 (1);
        lv_error_msg        VARCHAR2 (2000);
    BEGIN
        --Set ORG ID for Create Internal Orders
        fnd_request.set_org_id (pn_org_id);

        exec_conc_request (pv_error_stat => lv_error_stat, pv_error_msg => lv_error_msg, pn_request_id => ln_req_request_id, pv_application => 'PO', -- application short name
                                                                                                                                                     pv_program => 'POCISO', -- program short name
                                                                                                                                                                             pv_wait_for_request => 'Y'
                           , pn_interval => 10, pn_max_wait => 0);

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := lv_error_stat;
            pv_error_msg    :=
                'Create internal orders error : ' || lv_error_msg;
            RETURN;
        END IF;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE run_order_import (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_org_id IN NUMBER
                                , pv_int_source_code IN VARCHAR2, pn_requisition_id IN NUMBER, pn_number_oimp_threads IN NUMBER)
    IS
        ln_req_request_id    NUMBER;

        ln_user_id           NUMBER := fnd_global.user_id;
        ln_resp_id           NUMBER := fnd_global.resp_id;
        ln_resp_appl_id      NUMBER := fnd_global.resp_appl_id;

        ln_org_id            NUMBER;


        lv_requisition_num   VARCHAR2 (100);
        lv_chr_phase         VARCHAR2 (120 BYTE);
        lv_chr_status        VARCHAR2 (120 BYTE);
        lv_chr_dev_phase     VARCHAR2 (120 BYTE);
        lv_chr_dev_status    VARCHAR2 (120 BYTE);
        lv_chr_message       VARCHAR2 (2000 BYTE);
        lb_bol_result        BOOLEAN;
    BEGIN
        IF pn_requisition_id IS NOT NULL
        THEN
            BEGIN
                SELECT prha.segment1, ohia.org_id
                  INTO lv_requisition_num, ln_org_id
                  FROM apps.po_requisition_headers_all prha, oe_headers_iface_all ohia
                 WHERE     prha.interface_source_code = pv_int_source_code
                       AND TO_CHAR (prha.requisition_header_id) =
                           ohia.orig_sys_document_ref
                       AND prha.requisition_header_id = pn_requisition_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    pv_error_msg    := 'Requisition not found';
                    pv_error_stat   := 'E';
                    RETURN;
            END;
        ELSE
            ln_org_id   := pn_org_id;
        END IF;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (ln_org_id, NULL, 'ONT');

        exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => ln_req_request_id, pv_application => 'ONT', -- application short name
                                                                                                                                                      pv_program => 'OEOIMP', -- program short name
                                                                                                                                                                              pv_wait_for_request => 'Y', pv_argument1 => ln_org_id, -- Operating Unit
                                                                                                                                                                                                                                     pv_argument2 => 10, -- Internal Order
                                                                                                                                                                                                                                                         pv_argument3 => NVL (pn_requisition_id, NULL), -- Orig Sys Document Ref
                                                                                                                                                                                                                                                                                                        pv_argument4 => NULL, -- operation code
                                                                                                                                                                                                                                                                                                                              pv_argument5 => 'N', -- Validate Only
                                                                                                                                                                                                                                                                                                                                                   pv_argument6 => NULL, -- Debug level
                                                                                                                                                                                                                                                                                                                                                                         pv_argument7 => pn_number_oimp_threads, -- Instances
                                                                                                                                                                                                                                                                                                                                                                                                                 pv_argument8 => NULL, -- Sold to Org Id
                                                                                                                                                                                                                                                                                                                                                                                                                                       pv_argument9 => NULL, -- Sold To Org
                                                                                                                                                                                                                                                                                                                                                                                                                                                             pv_argument10 => NULL, -- Change seq
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    pv_argument11 => NULL, -- Perf Param
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           pv_argument12 => 'N', -- Trim Trailing Blanks
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 pv_argument13 => NULL, -- Process Orders with no org
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        pv_argument14 => NULL, -- Default org id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               pv_argument15 => 'Y'
                           ,                      -- Validate Desc Flex Fields
                             pn_interval => 60, pn_max_wait => 0);

        IF pv_error_stat != 'S'
        THEN
            pv_error_msg   := 'Order import request error : ' || pv_error_msg;
            RETURN;
        END IF;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE relieve_atp (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (500);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);


        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;

        CURSOR c_order_number IS
              SELECT DISTINCT ooha.order_number,
                              ooha.header_id,
                              ooha.org_id,
                              (SELECT DISTINCT oola.ship_from_org_id
                                 FROM oe_order_lines_all oola
                                WHERE ooha.header_id = oola.header_id) ship_from_org_id
                FROM apps.oe_order_headers_all ooha
               WHERE ooha.order_number = pn_order_number
            ORDER BY ooha.order_number;

        CURSOR c_line_details (pv_order_number VARCHAR2)
        IS
              SELECT oola.line_id, oola.header_id, oola.ordered_quantity,
                     oola.ordered_item, oola.request_date
                FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
               WHERE     1 = 1
                     AND ooha.order_number = pv_order_number
                     AND ooha.header_id = oola.header_id
                     AND oola.open_flag = 'Y'
            ORDER BY oola.ordered_quantity DESC;

        ln_ordered_quantity            NUMBER;
        ln_total_sum                   NUMBER;
        ln_initial_quantity            NUMBER;
    BEGIN
        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_resp_id        := 50746;
                gn_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);



        FOR r_order_number IN c_order_number
        LOOP
            mo_global.Set_org_context (r_order_number.org_id, NULL, 'ONT');

            oe_debug_pub.initialize;
            oe_msg_pub.initialize;
            l_line_tbl_index         := 1;
            l_line_tbl.delete ();

            l_header_rec             := OE_ORDER_PUB.G_MISS_HEADER_REC;
            l_header_rec.header_id   := r_order_number.header_id;
            l_header_rec.operation   := OE_GLOBALS.G_OPR_UPDATE;

            FOR r_line_details
                IN c_line_details (r_order_number.order_number)
            LOOP
                ln_ordered_quantity                                    :=
                    GREATEST (r_line_details.ordered_quantity, 0);

                -- Changed attributes
                l_line_tbl (l_line_tbl_index)                          :=
                    OE_ORDER_PUB.G_MISS_LINE_REC;
                l_line_tbl (l_line_tbl_index).operation                :=
                    OE_GLOBALS.G_OPR_UPDATE;
                l_line_tbl (l_line_tbl_index).header_id                :=
                    r_line_details.header_id;        -- header_id of the order
                l_line_tbl (l_line_tbl_index).line_id                  :=
                    r_line_details.line_id;       -- line_id of the order line
                l_line_tbl (l_line_tbl_index).ordered_quantity         :=
                    ln_ordered_quantity;               -- new ordered quantity
                l_line_tbl (l_line_tbl_index).Override_atp_date_code   := 'Y';
                l_line_tbl (l_line_tbl_index).change_reason            := '1'; -- change reason code
                l_line_tbl (l_line_tbl_index).schedule_arrival_date    :=
                    r_line_details.request_date;
                l_line_tbl_index                                       :=
                    l_line_tbl_index + 1;
            END LOOP;

            IF l_line_tbl.COUNT > 0
            THEN
                -- CALL TO PROCESS ORDER
                OE_ORDER_PUB.process_order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => l_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    x_header_rec               => p_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_Header_Adj_tbl           => x_Header_Adj_tbl,
                    x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
                    x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
                    x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
                    x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
                    x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
                    x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
                    x_line_tbl                 => p_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_Line_Adj_tbl             => x_Line_Adj_tbl,
                    x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
                    x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
                    x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
                    x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
                    x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
                    x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
                    x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
                    x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
                    x_action_request_tbl       => p_action_request_tbl);

                -- Check the return status
                IF l_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    COMMIT;
                ELSE
                    -- Retrieve messages
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        insert_message (
                            'BOTH',
                            'message index is: ' || l_msg_index_out);
                        insert_message ('BOTH', 'message is: ' || l_msg_data);
                    END LOOP;
                END IF;
            END IF;

            COMMIT;
        END LOOP;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE pick_release_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        lv_err_stat          VARCHAR2 (1);
        lv_err_msg           VARCHAR2 (2000);
        ln_user_id           NUMBER := 28227;                --JONATHAN.PETROU
        l_batch_info_rec     WSH_PICKING_BATCHES_PUB.BATCH_INFO_REC;

        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1);
        ln_batch_prefix      VARCHAR2 (10);
        ln_new_batch_id      NUMBER;

        ln_count             NUMBER;
        ln_request_id        NUMBER;

        lb_bol_result        BOOLEAN;
        lv_chr_phase         VARCHAR2 (250) := NULL;
        lv_chr_status        VARCHAR2 (250) := NULL;
        lv_chr_dev_phase     VARCHAR2 (250) := NULL;
        lv_chr_dev_status    VARCHAR2 (250) := NULL;
        lv_chr_message       VARCHAR2 (250) := NULL;

        ln_header_id         NUMBER;
        ln_org_id            NUMBER;
        ln_order_type_id     NUMBER;
        ln_organization_id   NUMBER;

        lv_subinventory      VARCHAR2 (40) := 'RECEIVING';
    BEGIN
        -- do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_app_id);

        BEGIN
            SELECT header_id,
                   org_id,
                   order_type_id,
                   (SELECT DISTINCT ship_from_org_id
                      FROM oe_order_lines_all oola
                     WHERE ooha.header_id = oola.header_id) organization_id
              INTO ln_header_id, ln_org_id, ln_order_type_id, ln_organization_id
              FROM oe_order_headers_all ooha
             WHERE order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order does not exist';
                RETURN;
        END;

        --Find subinventory for items in SO from staging table
        BEGIN
            SELECT DISTINCT dest_subinventory_code
              INTO lv_subinventory
              FROM XXDO.XXD_WMS_OH_IR_XFER_STG stg
             WHERE stg.iso_number = pn_order_number;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                NULL;
            WHEN NO_DATA_FOUND
            THEN
                lv_subinventory   := 'RECEIVING';
            WHEN OTHERS
            THEN
                lv_subinventory   := 'RECEIVING';
        END;

        --  apps.fnd_profile.put ('MFG_ORGANIZATION_ID', ln_organization_id);
        -- mo_global.init ('ONT');

        lv_return_status                              := wsh_util_core.g_ret_sts_success;

        l_batch_info_rec                              := NULL;
        insert_message ('BOTH', 'User ID : ' || gn_user_id);
        insert_message ('BOTH', 'Resp ID : ' || gn_resp_id);
        insert_message ('BOTH', 'Resp App ID : ' || gn_resp_appl_id);

        insert_message ('BOTH', 'Order Number : ' || pn_order_number);
        insert_message ('BOTH', 'Order Type ID : ' || ln_order_type_id);
        insert_message ('BOTH', 'Organization_id : ' || ln_organization_id);

        l_batch_info_rec.order_number                 := pn_order_number;
        l_batch_info_rec.order_type_id                := ln_order_type_id;
        l_batch_info_rec.Autodetail_Pr_Flag           := 'Y';
        l_batch_info_rec.organization_id              := ln_organization_id;
        l_batch_info_rec.autocreate_delivery_flag     := 'Y';
        l_batch_info_rec.Backorders_Only_Flag         := 'I';
        l_batch_info_rec.allocation_method            := 'I';
        l_batch_info_rec.auto_pick_confirm_flag       := 'Y';
        l_batch_info_rec.autopack_flag                := 'N';
        l_batch_info_rec.append_flag                  := 'N';
        l_batch_info_rec.Pick_From_Subinventory       := NULL; --lv_subinventory;
        l_batch_info_rec.Default_Stage_Subinventory   := NULL; --lv_subinventory;
        ln_batch_prefix                               := NULL;
        ln_new_batch_id                               := NULL;

        WSH_PICKING_BATCHES_PUB.CREATE_BATCH (
            p_api_version     => 1.0,
            p_init_msg_list   => fnd_api.g_true,
            p_commit          => fnd_api.g_true,
            x_return_status   => lv_return_status,
            x_msg_count       => ln_msg_count,
            x_msg_data        => lv_msg_data,
            p_rule_id         => NULL,
            p_rule_name       => NULL,
            p_batch_rec       => l_batch_info_rec,
            p_batch_prefix    => ln_batch_prefix,
            x_batch_id        => ln_new_batch_id);

        IF lv_return_status <> 'S'
        THEN
            insert_message (
                'BOTH',
                'CREATE_BATCH: lv_return_status ' || lv_return_status);
            insert_message ('BOTH', 'Message count ' || ln_msg_count);

            IF ln_msg_count = 1
            THEN
                insert_message ('BOTH', 'lv_msg_data ' || lv_msg_data);
            ELSIF ln_msg_count > 1
            THEN
                LOOP
                    ln_count   := ln_count + 1;
                    lv_msg_data   :=
                        FND_MSG_PUB.Get (FND_MSG_PUB.G_NEXT, FND_API.G_FALSE);

                    IF lv_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    insert_message (
                        'BOTH',
                        'Message' || ln_count || '---' || lv_msg_data);
                END LOOP;
            END IF;

            pv_error_stat   := lv_return_status;
            RETURN;
        ELSE
            -- Release the batch Created Above
            WSH_PICKING_BATCHES_PUB.RELEASE_BATCH (
                P_API_VERSION     => 1.0,
                P_INIT_MSG_LIST   => fnd_api.g_true,
                P_COMMIT          => fnd_api.g_true,
                X_RETURN_STATUS   => lv_return_status,
                X_MSG_COUNT       => ln_msg_count,
                X_MSG_DATA        => lv_msg_data,
                P_BATCH_ID        => ln_new_batch_id,
                P_BATCH_NAME      => NULL,
                P_LOG_LEVEL       => 1,
                P_RELEASE_MODE    => 'ONLINE',       -- (ONLINE or CONCURRENT)
                X_REQUEST_ID      => ln_request_id);



            IF ln_request_id <> 0
            THEN
                lb_bol_result   :=
                    fnd_concurrent.wait_for_request (ln_request_id,
                                                     15,
                                                     0,
                                                     lv_chr_phase,
                                                     lv_chr_status,
                                                     lv_chr_dev_phase,
                                                     lv_chr_dev_status,
                                                     lv_chr_message);
            END IF;
        END IF;

        pv_error_stat                                 := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE reprice_sales_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        l_api_version_number       NUMBER := 1;
        l_init_msg_list            VARCHAR2 (30) := fnd_api.g_false;
        l_return_values            VARCHAR2 (30) := fnd_api.g_false;
        l_action_commit            VARCHAR2 (30) := fnd_api.g_false;
        l_line_tab                 oe_order_pub.line_tbl_type;
        x_line_tab                 oe_order_pub.line_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_return_status            VARCHAR2 (10);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (2000);
        lc_error_msg               VARCHAR2 (2000);
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_action_request_tbl_out   oe_order_pub.request_tbl_type;
        ln_record_count            NUMBER := 0;


        ln_header_id               NUMBER;
        ln_org_id                  NUMBER;
        ln_inv_org_id              NUMBER;
        ln_user_id                 NUMBER := fnd_global.user_id;
        ln_resp_id                 NUMBER := fnd_global.resp_id;
        ln_resp_appl_id            NUMBER := fnd_global.resp_appl_id;
    BEGIN
        BEGIN
            SELECT DISTINCT ooha.header_id, ooha.org_id, oola.ship_from_org_id
              INTO ln_header_id, ln_org_id, ln_inv_org_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.order_number = pn_order_number
                   AND oola.flow_status_code NOT IN ('CANCELLED', 'ENTERED');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'Order not found';
                pv_error_stat   := 'E';
                RETURN;
            WHEN TOO_MANY_ROWS
            THEN
                pv_error_msg    := 'Multiple ship from for order';
                pv_error_stat   := 'E';
                RETURN;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        apps.fnd_profile.put ('MFG_ORGANIZATION_ID', ln_inv_org_id);

        mo_global.init ('ONT');

        l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
        l_action_request_tbl (1).entity_id      := ln_header_id;
        l_action_request_tbl (1).entity_code    := oe_globals.g_entity_header;
        l_action_request_tbl (1).request_type   := oe_globals.g_price_order;

        oe_order_pub.process_order (
            p_org_id                   => ln_org_id,
            p_operating_unit           => NULL,
            p_api_version_number       => l_api_version_number,
            p_init_msg_list            => l_init_msg_list,
            p_return_values            => l_return_values,
            p_action_commit            => l_action_commit,
            x_return_status            => x_return_status,
            x_msg_count                => x_msg_count,
            x_msg_data                 => x_msg_data,
            p_line_tbl                 => l_line_tab,
            p_line_adj_tbl             => l_line_adj_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => l_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => x_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => l_action_request_tbl_out);

        IF x_return_status != fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. x_msg_count
            LOOP
                lc_error_msg   :=
                    oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        ELSE
            pv_error_stat   := 'E';
            pv_error_msg    := SUBSTR (lc_error_msg, 1, 2000);
        END IF;

        pv_error_stat                           := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    --Function to check item attributes for OH cursor
    FUNCTION check_item_attributes (pn_inventory_item_id IN NUMBER, pn_src_org_id IN NUMBER, pn_dest_org_id IN NUMBER)
        RETURN NUMBER
    IS
        n_cnt   NUMBER;
    BEGIN
        --First check master
        SELECT COUNT (*)
          INTO n_cnt
          FROM mtl_system_items_b
         WHERE     organization_id = gn_master_org
               AND inventory_item_id = pn_inventory_item_id
               AND enabled_flag = 'Y'
               AND inventory_item_status_code = 'Active'
               AND purchasing_enabled_flag = 'Y'
               AND customer_order_enabled_flag = 'Y'
               AND internal_order_enabled_flag = 'Y'
               AND NVL (end_date_active, TRUNC (SYSDATE)) >= TRUNC (SYSDATE);

        IF n_cnt = 0
        THEN
            RETURN 0;
        END IF;

        --Check source org
        SELECT COUNT (*)
          INTO n_cnt
          FROM mtl_system_items_b
         WHERE     organization_id = pn_src_org_id
               AND inventory_item_id = pn_inventory_item_id
               AND enabled_flag = 'Y'
               AND inventory_item_status_code = 'Active'
               AND purchasing_enabled_flag = 'Y'
               AND customer_order_enabled_flag = 'Y'
               AND internal_order_enabled_flag = 'Y'
               AND NVL (end_date_active, TRUNC (SYSDATE)) >= TRUNC (SYSDATE)
               AND atp_flag = 'Y'
               AND mrp_planning_code != gn_mrp_not_planned;      --Not planned

        IF n_cnt = 0
        THEN
            RETURN 0;
        END IF;

        --Check dest org
        SELECT COUNT (*)
          INTO n_cnt
          FROM mtl_system_items_b
         WHERE     organization_id = pn_dest_org_id
               AND inventory_item_id = pn_inventory_item_id
               AND enabled_flag = 'Y'
               AND inventory_item_status_code = 'Active'
               AND purchasing_enabled_flag = 'Y'
               AND customer_order_enabled_flag = 'Y'
               AND internal_order_enabled_flag = 'Y'
               AND NVL (end_date_active, TRUNC (SYSDATE)) >= TRUNC (SYSDATE)
               AND atp_flag = 'Y'
               AND mrp_planning_code != gn_mrp_not_planned;      --Not planned

        IF n_cnt = 0
        THEN
            RETURN 0;
        END IF;

        RETURN 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END;



    PROCEDURE do_validation (pv_err_stat                  OUT VARCHAR2,
                             pv_err_msg                   OUT VARCHAR2,
                             pn_src_organization_id    IN     NUMBER,
                             pn_dest_organization_id   IN     VARCHAR2,
                             pv_brand                  IN     VARCHAR2)
    IS
        n_cnt   NUMBER;
    BEGIN
        IF    pn_src_organization_id IS NULL  --    OR pv_subinventory IS NULL
           OR pn_dest_organization_id IS NULL
           OR pv_brand IS NULL
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'One or more required parameters is NULL';
            RETURN;
        END IF;



        --Check that selected Inventory organization is valid
        SELECT COUNT (*)
          INTO n_cnt
          FROM mtl_parameters
         WHERE organization_id = pn_src_organization_id;

        IF n_cnt = 0
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Source organization is not valid';
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO n_cnt
          FROM mtl_parameters
         WHERE organization_id = pn_dest_organization_id;

        IF n_cnt = 0
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Destination organization is not valid';
            RETURN;
        END IF;

        --Check if Brand is valid
        SELECT COUNT (*)
          INTO n_cnt
          FROM do_custom.do_brands_v
         WHERE UPPER (brand_name) = UPPER (pv_brand);

        IF n_cnt = 0
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Brand is not valid';
            RETURN;
        END IF;
    END;

    PROCEDURE validate_items (pv_err_stat                  OUT VARCHAR2,
                              pv_err_msg                   OUT VARCHAR2,
                              pn_src_organization_id    IN     NUMBER,
                              pn_dest_organization_id   IN     NUMBER,
                              pv_brand                  IN     VARCHAR2)
    IS
        CURSOR c_oh (n_org_src NUMBER, n_org_dest NUMBER, v_brand VARCHAR2)
        IS
            SELECT itm.item_number, moqd.inventory_item_id, moqd.organization_id,
                   qty
              FROM (  SELECT inventory_item_id, organization_id, SUM (primary_transaction_quantity) qty
                        FROM mtl_onhand_quantities_detail
                    GROUP BY inventory_item_id, organization_id) moqd,
                   (SELECT brand, item_number, style_number,
                           inventory_item_id
                      FROM xxd_common_items_v v
                     WHERE v.organization_id = gn_master_org) itm
             WHERE     moqd.inventory_item_id = itm.inventory_item_id
                   AND moqd.organization_id = n_org_src
                   AND XXD_WMS_OH_INTR_CONV_PKG.check_item_attributes (
                           moqd.inventory_item_id,
                           n_org_src,
                           n_org_dest) =
                       0
                   AND brand = v_brand;

        lv_enabled_flag                  VARCHAR2 (1);
        lv_inventory_item_status_code    VARCHAR2 (10);
        lv_purchasing_enabled_flag       VARCHAR2 (1);
        lv_customer_order_enabled_flag   VARCHAR2 (1);
        lv_internal_order_enabled_flag   VARCHAR2 (1);
        ld_end_date_active               DATE;
        lv_atp_flag                      VARCHAR2 (1);
        ln_mrp_planning_code             NUMBER;
        lv_msg                           VARCHAR2 (4000);
        n_cnt                            NUMBER := 0;
        n_err                            NUMBER := 0;
    BEGIN
        FOR oh_rec
            IN c_oh (pn_src_organization_id,
                     pn_dest_organization_id,
                     pv_brand)
        LOOP
            lv_msg   := NULL;

            --Check flags in MST org
            BEGIN
                SELECT b.enabled_flag, b.inventory_item_status_code, b.purchasing_enabled_flag,
                       b.customer_order_enabled_flag, b.internal_order_enabled_flag, b.end_date_active,
                       b.atp_flag, b.mrp_planning_code
                  INTO lv_enabled_flag, lv_inventory_item_status_code, lv_purchasing_enabled_flag, lv_customer_order_enabled_flag,
                                      lv_internal_order_enabled_flag, ld_end_date_active, lv_atp_flag,
                                      ln_mrp_planning_code
                  FROM mtl_system_items_b b
                 WHERE     b.organization_id = gn_master_org
                       AND b.inventory_item_id = oh_rec.inventory_item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_msg   :=
                           'Error gathering maaster data for '
                        || oh_rec.item_number
                        || '  '
                        || SQLERRM;
            END;

            ---Check Master parameters
            IF lv_inventory_item_status_code = 'Inactive'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Inventory_item status code is Inactive in master org. ';
            END IF;

            IF lv_enabled_flag = 'N'
            THEN
                lv_msg   := lv_msg || ' Item not enabled in master org. ';
            END IF;

            IF ld_end_date_active IS NOT NULL
            THEN
                lv_msg   := lv_msg || ' Item is end-dated in master org. ';
            END IF;

            IF lv_purchasing_enabled_flag = 'N'
            THEN
                lv_msg   :=
                    lv_msg || ' Item not purchasing enabled in master org. ';
            END IF;

            IF lv_customer_order_enabled_flag = 'N'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Item not customer order enabled in master org. ';
            END IF;

            IF lv_internal_order_enabled_flag = 'N'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Item not internal order enabled in master org. ';
            END IF;

            ---Check source org

            BEGIN
                SELECT b.enabled_flag, b.inventory_item_status_code, b.purchasing_enabled_flag,
                       b.customer_order_enabled_flag, b.internal_order_enabled_flag, b.end_date_active,
                       b.atp_flag, b.mrp_planning_code
                  INTO lv_enabled_flag, lv_inventory_item_status_code, lv_purchasing_enabled_flag, lv_customer_order_enabled_flag,
                                      lv_internal_order_enabled_flag, ld_end_date_active, lv_atp_flag,
                                      ln_mrp_planning_code
                  FROM mtl_system_items_b b
                 WHERE     b.organization_id = pn_src_organization_id
                       AND b.inventory_item_id = oh_rec.inventory_item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_msg   :=
                           'Error gathering maaster data for '
                        || oh_rec.item_number
                        || '  '
                        || SQLERRM;
            END;

            ---Check Master parameters
            IF lv_inventory_item_status_code = 'Inactive'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Inventory_item status code is Inactive in source org. ';
            END IF;

            IF lv_enabled_flag = 'N'
            THEN
                lv_msg   := lv_msg || ' Item not enabled in source org. ';
            END IF;

            IF ld_end_date_active IS NOT NULL
            THEN
                lv_msg   := lv_msg || ' Item is end-dated in source org. ';
            END IF;

            IF lv_purchasing_enabled_flag = 'N'
            THEN
                lv_msg   :=
                    lv_msg || ' Item not purchasing enabled in source org. ';
            END IF;

            IF lv_customer_order_enabled_flag = 'N'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Item not customer order enabled in source org. ';
            END IF;

            IF lv_internal_order_enabled_flag = 'N'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Item not internal order enabled in source org. ';
            END IF;

            IF lv_atp_flag = 'N'
            THEN
                lv_msg   := lv_msg || ' Item not ATP enabled in source org. ';
            END IF;

            IF     lv_atp_flag = 'Y'
               AND ln_mrp_planning_code = gn_mrp_not_planned
            THEN
                lv_msg   := lv_msg || ' Item not collectable in source org. ';
            END IF;

            ---Check dest org

            BEGIN
                SELECT b.enabled_flag, b.inventory_item_status_code, b.purchasing_enabled_flag,
                       b.customer_order_enabled_flag, b.internal_order_enabled_flag, b.end_date_active,
                       b.atp_flag, b.mrp_planning_code
                  INTO lv_enabled_flag, lv_inventory_item_status_code, lv_purchasing_enabled_flag, lv_customer_order_enabled_flag,
                                      lv_internal_order_enabled_flag, ld_end_date_active, lv_atp_flag,
                                      ln_mrp_planning_code
                  FROM mtl_system_items_b b
                 WHERE     b.organization_id = pn_dest_organization_id
                       AND b.inventory_item_id = oh_rec.inventory_item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_msg   :=
                           'Error gathering dest org data for '
                        || oh_rec.item_number
                        || '  '
                        || SQLERRM;
            END;

            ---Check Master parameters
            IF lv_inventory_item_status_code = 'Inactive'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Inventory_item status code is Inactive in dest org. ';
            END IF;

            IF lv_enabled_flag = 'N'
            THEN
                lv_msg   := lv_msg || ' Item not enabled in dest org. ';
            END IF;

            IF ld_end_date_active IS NOT NULL
            THEN
                lv_msg   := lv_msg || ' Item is end-dated in dest org. ';
            END IF;

            IF lv_purchasing_enabled_flag = 'N'
            THEN
                lv_msg   :=
                    lv_msg || ' Item not purchasing enabled in dest org. ';
            END IF;

            IF lv_customer_order_enabled_flag = 'N'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Item not customer order enabled in dest org. ';
            END IF;

            IF lv_internal_order_enabled_flag = 'N'
            THEN
                lv_msg   :=
                       lv_msg
                    || ' Item not internal order enabled in dest org. ';
            END IF;

            IF lv_atp_flag = 'N'
            THEN
                lv_msg   := lv_msg || ' Item not ATP enabled in dest org. ';
            END IF;

            IF     lv_atp_flag = 'Y'
               AND ln_mrp_planning_code = gn_mrp_not_planned
            THEN
                lv_msg   := lv_msg || ' Item not collectable in dest org. ';
            END IF;


            IF lv_msg IS NOT NULL
            THEN
                insert_message (
                    'BOTH',
                    oh_rec.item_number || CHR (9) || lv_msg || CHR (13));
                n_err   := n_err + 1;
            END IF;
        END LOOP;

        insert_message (
            'BOTH',
            'Item validation complete. ' || n_err || ' Items have errors ');

        IF n_err > 0
        THEN
            pv_err_stat   := 'W';
            pv_err_msg    := 'One or more items failed validation';
        ELSE
            pv_err_stat   := 'S';
            pv_err_msg    := '';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    :=
                'Exception occurrec validating items. ' || SQLERRM;
    END;

    PROCEDURE check_reservations (
        pv_err_stat             OUT VARCHAR2,
        pv_err_msg              OUT VARCHAR2,
        pn_organization_id   IN     NUMBER,
        pv_brand             IN     VARCHAR2,
        pv_style             IN     VARCHAR2 := NULL)
    IS
        n_cnt   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO n_cnt
          FROM mtl_onhand_quantities_detail moqd
         WHERE     (   EXISTS                              --Hard reservations
                           (SELECT NULL
                              FROM mtl_reservations mr
                             WHERE     mr.organization_id =
                                       moqd.organization_id
                                   AND mr.inventory_item_id =
                                       moqd.inventory_item_id
                                   AND mr.subinventory_code =
                                       moqd.subinventory_code)
                    OR EXISTS                              --soft reservations
                           (SELECT NULL
                              FROM mtl_reservations mr
                             WHERE     mr.organization_id =
                                       moqd.organization_id
                                   AND mr.inventory_item_id =
                                       moqd.inventory_item_id
                                   AND mr.subinventory_code IS NULL))
               AND organization_id = pn_organization_id
               AND inventory_item_id IN
                       (SELECT DISTINCT inventory_item_id
                          FROM xxd_common_items_v iv
                         WHERE     iv.brand = pv_brand
                               AND IV.STYLE_NUMBER =
                                   NVL (pv_style, iv.style_number)
                               AND iv.organization_id = moqd.organization_id);


        IF n_cnt > 0
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Reservations exists for Org/Brand';
            insert_message (
                'BOTH',
                'Check Reservations - pv_err_stat : ' || pv_err_stat);
            RETURN;
        END IF;


        pv_err_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
    END;

    PROCEDURE run_om_schedule_orders (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        ln_org_id           NUMBER;
        ln_req_request_id   NUMBER;
    BEGIN
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM oe_order_headers_all
             WHERE order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order not found';
        END;


        exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => ln_req_request_id, pv_application => 'ONT', -- application short name
                                                                                                                                                      pv_program => 'SCHORD', -- program short name
                                                                                                                                                                              pv_wait_for_request => 'Y', pv_argument1 => ln_org_id, -- Operating Unit
                                                                                                                                                                                                                                     pv_argument2 => pn_order_number, -- Internal Order
                                                                                                                                                                                                                                                                      pv_argument3 => pn_order_number, pv_argument4 => '', pv_argument5 => '', pv_argument6 => '', pv_argument7 => '', pv_argument8 => '', pv_argument9 => '', pv_argument10 => '', pv_argument11 => '', pv_argument12 => '', pv_argument13 => '', pv_argument14 => '', pv_argument15 => '', pv_argument16 => '', pv_argument17 => '', pv_argument18 => '', pv_argument19 => '', pv_argument20 => '', pv_argument21 => '', pv_argument22 => '', pv_argument23 => '', pv_argument24 => '', pv_argument25 => '', pv_argument26 => '', pv_argument27 => '', pv_argument28 => '', pv_argument29 => '', pv_argument30 => '', pv_argument31 => '', pv_argument32 => '', pv_argument33 => '', pv_argument34 => '', pv_argument35 => '', pv_argument36 => 'Y'
                           , pv_argument37 => '1000', pv_argument38 => ''); -- Orig Sys Document Ref
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE schedule_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (4000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (4000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.Line_Rec_Type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;

        ln_user_id                     NUMBER := fnd_global.user_id;
        ln_resp_id                     NUMBER := fnd_global.resp_id;
        ln_resp_appl_id                NUMBER := fnd_global.resp_appl_id;

        CURSOR line_cur (n_header_id NUMBER)
        IS
            SELECT line_id, request_date
              FROM oe_order_lines_all
             WHERE header_id = n_header_id;

        ln_header_id                   NUMBER;
        ln_org_id                      NUMBER;
    BEGIN
        BEGIN
            SELECT DISTINCT ooha.header_id, ooha.org_id
              INTO ln_header_id, ln_org_id
              FROM oe_order_headers_all ooha
             WHERE ooha.order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'Order not found';
                pv_error_stat   := 'E';
                RETURN;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        mo_global.init ('ONT');
        mo_global.Set_org_context (ln_org_id, NULL, 'ONT');

        v_line_tbl.delete ();

        FOR line_rec IN line_cur (ln_header_id)
        LOOP
            j                                       := j + 1;

            v_line_tbl (j)                          := OE_ORDER_PUB.G_MISS_LINE_REC;
            v_line_tbl (j).header_id                := ln_header_id;
            v_line_tbl (j).line_id                  := line_rec.line_id;
            v_line_tbl (j).operation                := oe_globals.G_OPR_UPDATE;
            v_line_tbl (j).OVERRIDE_ATP_DATE_CODE   := 'Y';
            v_line_tbl (j).schedule_arrival_date    := line_rec.request_date;
        --   v_line_tbl (j).schedule_ship_date := line_rec.request_date;
        -- v_line_tbl(j).schedule_action_code := oe_order_sch_util.oesch_act_schedule;
        END LOOP;

        IF j > 0
        THEN
            OE_ORDER_PUB.PROCESS_ORDER (
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl,
                x_header_rec               => v_header_rec_out,
                x_header_val_rec           => v_header_val_rec_out,
                x_header_adj_tbl           => v_header_adj_tbl_out,
                x_header_adj_val_tbl       => v_header_adj_val_tbl_out,
                x_header_price_att_tbl     => v_header_price_att_tbl_out,
                x_header_adj_att_tbl       => v_header_adj_att_tbl_out,
                x_header_adj_assoc_tbl     => v_header_adj_assoc_tbl_out,
                x_header_scredit_tbl       => v_header_scredit_tbl_out,
                x_header_scredit_val_tbl   => v_header_scredit_val_tbl_out,
                x_line_tbl                 => v_line_tbl_out,
                x_line_val_tbl             => v_line_val_tbl_out,
                x_line_adj_tbl             => v_line_adj_tbl_out,
                x_line_adj_val_tbl         => v_line_adj_val_tbl_out,
                x_line_price_att_tbl       => v_line_price_att_tbl_out,
                x_line_adj_att_tbl         => v_line_adj_att_tbl_out,
                x_line_adj_assoc_tbl       => v_line_adj_assoc_tbl_out,
                x_line_scredit_tbl         => v_line_scredit_tbl_out,
                x_line_scredit_val_tbl     => v_line_scredit_val_tbl_out,
                x_lot_serial_tbl           => v_lot_serial_tbl_out,
                x_lot_serial_val_tbl       => v_lot_serial_val_tbl_out,
                x_action_request_tbl       => v_action_request_tbl_out,
                x_return_status            => v_return_status,
                x_msg_count                => v_msg_count,
                x_msg_data                 => v_msg_data);


            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                pv_error_stat   := 'S';
                COMMIT;
            ELSE
                ROLLBACK;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                pv_error_stat   := 'E';
                pv_error_msg    := SUBSTR (v_msg_data, 1, 2000);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE run_process_output (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pv_status IN VARCHAR2:= NULL)
    IS
        CURSOR c_rec IS
            SELECT stg.*, src_org.name source_org, dest_org.name dest_org,
                   prla.attribute11 req_aging_date
              FROM XXDO.XXD_WMS_OH_IR_XFER_STG stg, hr_all_organization_units src_org, hr_all_organization_units dest_org,
                   po_requisition_lines_all prla
             WHERE     stg.request_id = gn_request_id
                   AND stg.organization_id = src_org.organization_id
                   AND stg.dest_organization_id = dest_org.organization_id
                   AND stg.req_line_id = prla.requisition_line_id(+)
                   AND NVL (pv_status, stg.status) = stg.status;
    BEGIN
        -- Output header cols
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Source Inv Org', 30, ' ')
            || RPAD ('SKU', 20, ' ')
            || RPAD ('Subinventory Code', 20, ' ')
            || RPAD ('On-Hand Quantity', 20, ' ')
            || RPAD ('Aging Date', 15, ' ')
            || RPAD ('Item Unit Cost', 20, ' ')
            || RPAD ('Item Total Cost', 20, ' ')
            || RPAD ('Internal Req #', 20, ' ')
            || RPAD ('Internal SO #', 20, ' ')
            || RPAD ('Aging Date in IR Line', 30, ' ')
            || RPAD ('ISO Destination Org', 30, ' ')
            || CHR (13)
            || CHR (10));

        FOR rec IN c_rec
        LOOP
            --output line data
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (rec.source_org, 30, ' ')
                || RPAD (rec.sku, 20, ' ')
                || RPAD (rec.subinventory_code, 20, ' ')
                || RPAD (rec.quantity, 20, ' ')
                || RPAD (rec.aging_date, 15, ' ')
                || RPAD (rec.unit_price, 20, ' ')
                || RPAD (rec.unit_price * rec.quantity, 20, ' ')
                || RPAD (rec.requisition_number, 20, ' ')
                || RPAD (rec.iso_number, 20, ' ')
                || RPAD (rec.req_aging_date, 30, ' ')
                || RPAD (rec.dest_org, 30, ' ')
                || CHR (13)
                || CHR (10));
        END LOOP;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;


    PROCEDURE run_oh_conversion (
        pv_err_stat                  OUT VARCHAR2,
        pv_err_msg                   OUT VARCHAR2,
        pn_src_organization_id    IN     NUMBER,
        pn_dest_organization_id   IN     VARCHAR2,
        pv_brand                  IN     VARCHAR2,
        pv_style                  IN     VARCHAR2 := NULL,
        pn_max_req_qty            IN     NUMBER := 1000,
        pn_number_oimp_threads    IN     NUMBER := 4)
    IS
        lv_err_stat                 VARCHAR2 (10);
        lv_err_msg                  VARCHAR2 (2000);
        lv_subinventory             VARCHAR2 (20);
        lv_brand                    VARCHAR2 (10);
        lv_item_validation_result   VARCHAR2 (1);

        ln_src_org_id               NUMBER;
        ln_org_id                   NUMBER;

        exProcess                   EXCEPTION;
    BEGIN
        insert_message ('BOTH', 'run_oh_conversion - Start');
        insert_message ('BOTH', 'Brand : ' || pv_brand);
        insert_message ('BOTH', 'Style : ' || pv_style);


        --  lv_subinventory := UPPER (pv_subinventory);
        lv_brand      := UPPER (pv_brand);

        insert_message ('BOTH', 'Validation');
        --Validation
        do_validation (pv_err_stat               => lv_err_stat,
                       pv_err_msg                => lv_err_msg,
                       pn_src_organization_id    => pn_src_organization_id,
                       pn_dest_organization_id   => pn_dest_organization_id,
                       pv_brand                  => lv_brand);


        IF lv_err_stat != 'S'
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Validation failed : ' || lv_err_msg;
            insert_message ('BOTH', pv_err_msg);
            RETURN;
        END IF;

        insert_message ('BOTH', 'Validate Items');
        validate_items (pv_err_stat               => lv_err_stat,
                        pv_err_msg                => lv_err_msg,
                        pn_src_organization_id    => pn_src_organization_id,
                        pn_dest_organization_id   => pn_dest_organization_id,
                        pv_brand                  => lv_brand);

        IF pv_err_stat = 'W'                     --items had validation errors
        THEN
            lv_item_validation_result   := 'W';
        ELSE
            IF pv_err_stat = 'E'              --Item validation returned error
            THEN
                pv_err_stat   := lv_err_stat;
                pv_err_msg    := lv_err_msg;
                RETURN;
            ELSE
                lv_item_validation_result   := 'S';
            END IF;
        END IF;



        insert_message ('BOTH', 'Insert into staging table');
        --Insert needed records into staging table
        insert_into_oh_table (pv_error_stat => lv_err_stat, pv_error_msg => lv_err_msg, pn_inv_org_id => pn_src_organization_id, pv_brand => lv_brand, pv_style => pv_style, pn_dest_inv_org_id => pn_dest_organization_id
                              , pn_max_req_qty => pn_max_req_qty);

        IF lv_err_stat != 'S'
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'insert into OH table failed : ' || lv_err_msg;
            insert_message ('BOTH', pv_err_msg);
            RETURN;
        END IF;

        COMMIT;
        insert_message ('BOTH', 'Check Reservations');
        --Check for any OH reservations
        check_reservations (pv_err_stat => lv_err_stat, pv_err_msg => lv_err_msg, pn_organization_id => pn_src_organization_id
                            , pv_brand => lv_brand, pv_style => pv_style);

        insert_message ('BOTH', 'Check Reservations ' || pv_err_stat);

        IF lv_err_stat != 'S'
        THEN
            --Report on all reservation issues
            UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
               SET STATUS = 'E', MESSAGE = 'Reservations exist for this SKU/Organization'
             WHERE     EXISTS
                           (SELECT NULL
                              FROM mtl_reservations mr
                             WHERE     stg.organization_id =
                                       mr.organization_id
                                   AND stg.inventory_item_id =
                                       mr.inventory_item_id)
                   AND stg.ORGANIZATION_ID = pn_src_organization_id
                   AND stg.BRAND = lv_brand
                   AND stg.style = NVL (pv_style, style);

            pv_err_stat   := 'E';
            pv_err_msg    := 'Reservations exist for items';
            insert_message ('BOTH', pv_err_msg);

            --Run output report
            run_process_output (pv_error_stat   => lv_err_stat,
                                pv_error_msg    => lv_err_msg,
                                pv_status       => 'E');
            RETURN;
        END IF;

        --Start procesing

        --Get ou of dest organization
        SELECT operating_unit
          INTO ln_org_id
          FROM apps.org_organization_definitions
         WHERE organization_id = pn_dest_organization_id;

        --Get ou of source organization
        SELECT operating_unit
          INTO ln_src_org_id
          FROM apps.org_organization_definitions
         WHERE organization_id = pn_src_organization_id;

        --Update staging table for added records to processing
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
           SET STATUS = 'P', request_id = gn_request_id
         WHERE     ORGANIZATION_ID = pn_src_organization_id
               AND BRAND = lv_brand
               AND style = NVL (pv_style, style);

        COMMIT;

        --Get responsibility for Purchasing
        insert_message ('BOTH', 'Create IR');
        -- Create DC-DC xfer requisitions
        CREATE_OH_XFER_IR (
            pv_error_stat             => lv_err_stat,
            pv_error_msg              => lv_err_msg,
            pn_src_organization_id    => pn_src_organization_id,
            pn_dest_organization_id   => pn_dest_organization_id,
            pv_brand                  => pv_brand,
            pv_style                  => pv_style);

        IF pv_err_stat != 'S'
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Create IR failed : ' || lv_err_msg;
            RAISE exProcess;
        END IF;

        insert_message ('BOTH', 'Update links');

        --Update staging records with IDs from generated IR
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
           SET req_header_id   =
                   (SELECT prha.requisition_header_id
                      FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                     WHERE     prla.requisition_header_id =
                               prha.requisition_header_id
                           AND prla.attribute15 = TO_CHAR (record_id)
                           AND prha.interface_source_code =
                               gv_ir_interface_source_code),
               req_line_id   =
                   (SELECT prla.requisition_line_id
                      FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                     WHERE     prla.requisition_header_id =
                               prha.requisition_header_id
                           AND prla.attribute15 = TO_CHAR (record_id)
                           AND prha.interface_source_code =
                               gv_ir_interface_source_code),
               requisition_number   =
                   (SELECT prha.segment1
                      FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                     WHERE     prla.requisition_header_id =
                               prha.requisition_header_id
                           AND prla.attribute15 = TO_CHAR (record_id)
                           AND prha.interface_source_code =
                               gv_ir_interface_source_code)
         WHERE request_id = gn_request_id;

        insert_message ('BOTH', 'Create internal orders');
        --Create internal orders
        run_create_internal_orders (pv_error_stat   => lv_err_stat,
                                    pv_error_msg    => lv_err_msg,
                                    pn_org_id       => ln_org_id);

        IF lv_err_stat != 'S'
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Create orders failed : ' || lv_err_msg;
            RAISE exProcess;
        END IF;

        --Order Management tasks


        BEGIN
            SELECT responsibility_id, application_id
              INTO gn_resp_id, gn_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name = --  'Deckers Order Management Super User - US'
                                             'Order Management Super User'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_resp_id        := 50746;
                gn_resp_appl_id   := 660;
        END;

        do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

        --Check for created Order IFace record

        insert_message ('BOTH', 'Order Import');
        insert_message ('BOTH', 'OIMP');
        insert_message ('BOTH', 'Source org ID : ' || ln_src_org_id);

        run_order_import (pv_error_stat            => lv_err_stat,
                          pv_error_msg             => lv_err_msg,
                          pn_org_id                => ln_src_org_id,
                          pv_int_source_code       => gv_ir_interface_source_code,
                          pn_requisition_id        => NULL,
                          pn_number_oimp_threads   => pn_number_oimp_threads);

        IF lv_err_stat != 'S'
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'Order import failed : ' || lv_err_msg;
            RAISE exProcess;
        END IF;

        --Update stg table data fields;
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
           SET iso_number   =
                   (SELECT DISTINCT ooha.order_number
                      FROM oe_order_headers_all ooha, oe_order_lines_all oola
                     WHERE     oola.header_id = ooha.header_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.inventory_item_id = stg.inventory_item_id)
         WHERE request_id = gn_request_id;

        COMMIT;

        --Set records to E for any that do not have ISO set
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
           SET STATUS = 'E', MESSAGE = 'ISO line not created for this record', last_update_date = SYSDATE,
               last_updated_by = gn_user_id
         WHERE stg.iso_number IS NULL AND request_id = gn_request_id;


        --Update staging table status fields
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
           SET STATUS = 'Y', MESSAGE = NULL, last_update_date = SYSDATE,
               last_updated_by = gn_user_id
         WHERE request_id = gn_request_id AND status != 'E';

        COMMIT;

        insert_message ('BOTH', 'Run output report');
        --Run output report
        run_process_output (pv_error_stat   => lv_err_stat,
                            pv_error_msg    => lv_err_msg);

        --End of first prog

        --If no other error but there were item validation errors then return warning
        IF lv_item_validation_result = 'W'
        THEN
            pv_err_stat   := 'W';
            pv_err_msg    :=
                'One or more items failed validation. Refer to log for list of items';
        END IF;

        pv_err_stat   := 'S';
    EXCEPTION
        WHEN exProcess
        THEN
            insert_message ('BOTH', 'Error : ' || pv_err_msg);

            UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG
               SET STATUS = 'E', MESSAGE = pv_err_msg, last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE request_id = gn_request_id;

            COMMIT;
            --Run output report
            run_process_output (pv_error_stat   => lv_err_stat,
                                pv_error_msg    => lv_err_msg);
        WHEN OTHERS
        THEN
            insert_message ('BOTH', 'Error : ' || SQLERRM);
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
    END;

    PROCEDURE stage_conv_internal_so (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_iso_number IN NUMBER)
    IS
        ln_unschedule_cnt   NUMBER;
        ln_delivery_id      NUMBER;
        ln_booked_cnt       NUMBER;

        lv_error_stat       VARCHAR2 (10);
        lv_error_msg        VARCHAR2 (2000);
    BEGIN
        --Validate ISO number entered
        --Progress lines to awaiting shipping/scheduled
        --Check for unscheduled lines and schedule
        insert_message ('BOTH', 'stage_conv_internal_so - start');


        --Set override ATP Date Code
        insert_message ('BOTH', 'Relieve ATP');
        relieve_atp (pv_error_stat     => lv_error_stat,
                     pv_error_msg      => lv_error_msg,
                     pn_order_number   => pn_iso_number);

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Relieve ATP failed : ' || lv_error_msg;
            RETURN;
        END IF;

        SELECT COUNT (1)
          INTO ln_unschedule_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = pn_iso_number
               AND ooha.header_id = oola.header_id
               AND (schedule_ship_date IS NULL OR schedule_status_code IS NULL)
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code = 'AWAITING_SHIPPING';

        insert_message ('BOTH', 'Unscheduled Count : ' || ln_unschedule_cnt);

        IF ln_unschedule_cnt > 0
        THEN
            --Schedule order
            -- 'Deckers Order Management Manager - US'
            insert_message ('BOTH', 'Schedule order');
            schedule_order (pv_error_stat     => lv_error_stat,
                            pv_error_msg      => lv_error_msg,
                            pn_order_number   => pn_iso_number);
        END IF;

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := ' Schedule orders failed : ' || lv_error_msg;
            RETURN;
        END IF;

        --Check for lines in booked status
        SELECT SUM (DECODE (oola.flow_status_code, 'BOOKED', 1, 0))
          INTO ln_booked_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = pn_iso_number
               AND ooha.header_id = oola.header_id
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING');

        insert_message ('BOTH', 'Count booked ' || ln_booked_cnt);


        --Progress BOOKED lines to AWAITING_SHIPPING
        IF ln_booked_cnt > 0
        THEN
            insert_message ('BOTH', 'Run OM Schedule orders');
            run_om_schedule_orders (pv_error_stat     => lv_error_stat,
                                    pv_error_msg      => lv_error_msg,
                                    pn_order_number   => pn_iso_number);


            IF lv_error_stat != 'S'
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    :=
                    'Run OM Schedule orders : ' || lv_error_msg;
                RETURN;
            END IF;
        END IF;

        --Pick confirm
        /*      insert_message ('BOTH', 'Reprice Order');
              --Reprice SO
              reprice_sales_order (pv_error_stat     => lv_error_stat,
                                   pv_error_msg      => lv_error_msg,
                                   pn_order_number   => pn_iso_number);

              IF lv_error_stat != 'S'
              THEN
                 -- pv_err_stat := 'E';
                 pv_error_msg := 'reprice sales order failed : ' || lv_error_msg;
              END IF;

              RETURN;*/

        --Shipping user tasks

        SELECT responsibility_id, application_id
          INTO gn_resp_id, gn_resp_appl_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = 'Order Management Super User';

        do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

        insert_message ('BOTH', 'Release Order');
        --Pick Release order
        Pick_release_order (pv_error_stat     => lv_error_stat,
                            pv_error_msg      => lv_error_msg,
                            pn_order_number   => pn_iso_number);

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            insert_message ('BOTH', 'pick release failed : ' || lv_error_msg);
            pv_error_msg    := 'pick release failed : ' || lv_error_msg;
            RETURN;
        END IF;

        BEGIN
            --Get confirmed delivery
            SELECT DISTINCT wda.delivery_id
              INTO ln_delivery_id
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, oe_order_lines_all oola,
                   oe_order_headers_all ooha
             WHERE     ooha.order_number = pn_iso_number
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND oola.header_id = ooha.header_id
                   AND wdd.source_code = 'OE';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'W';
                pv_error_msg    := 'No delivery created';
            WHEN TOO_MANY_ROWS
            THEN
                pv_error_msg   := 'multiple delivery created';
        END;

        insert_message ('BOTH', 'Delivery Created : ' || ln_delivery_id);

        --update staging table delivery fields
        UPDATE XXDO.XXD_WMS_OH_IR_XFER_STG stg
           SET delivery_id       =
                   (SELECT delivery_id
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd, oe_order_lines_all oola
                     WHERE     wda.delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wdd.source_line_id = oola.line_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.inventory_item_id = stg.inventory_item_id
                           AND wdd.source_code = 'OE'),
               delivery_line_status   =
                   (SELECT released_status
                      FROM wsh_delivery_details wdd, oe_order_lines_all oola
                     WHERE     wdd.source_line_id = oola.line_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.inventory_item_id = stg.inventory_item_id
                           AND wdd.source_code = 'OE'),
               last_update_date   = SYSDATE,
               last_updated_by    = apps.fnd_global.user_id,
               request_id         = gn_request_id
         WHERE iso_number = pn_iso_number;

        --Run output report
        run_process_output (pv_error_stat   => pv_error_stat,
                            pv_error_msg    => pv_error_msg);

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error in ISO Staging process. : ' || SQLERRM;
    END;
END XXD_WMS_OH_INTR_CONV_PKG;
/
