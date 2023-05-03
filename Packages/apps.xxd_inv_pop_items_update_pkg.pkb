--
-- XXD_INV_POP_ITEMS_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_POP_ITEMS_UPDATE_PKG"
AS
    --  ####################################################################################################
    --  Package      : xxd_inv_pop_items_update_pkg
    --  Design       : This package is used to update the flags for POP items.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  02-Sep-2020     1.0        Showkath Ali             Initial Version - CCR0008684
    --  04-AUG-2021     1.1        Satyanarayana Kotha      Added for CCR0008684
    --  ####################################################################################################

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;

    /************************************************************************************************
 ************ Function to identify if item is exists in Open PO or SO ****************************
 ************************************************************************************************/

    FUNCTION get_open_po_so_det (p_inventory_item_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_so_count   NUMBER := 0;
        ln_po_count   NUMBER := 0;
        lv_message    VARCHAR2 (4000);
    BEGIN
        BEGIN
            SELECT COUNT (1)
              INTO ln_po_count
              FROM mtl_item_categories a, mtl_system_items_b b, rcv_shipment_lines d
             WHERE     1 = 1
                   AND a.inventory_item_id = b.inventory_item_id
                   AND a.inventory_item_id = d.item_id
                   AND d.shipment_line_status_code IN
                           ('EXPECTED', 'PARTIALLY RECEIVED')
                   AND b.organization_id = a.organization_id
                   AND b.inventory_item_id = p_inventory_item_id
                   AND a.category_id IN (SELECT category_id
                                           FROM mtl_categories
                                          WHERE 1 = 1 AND segment3 = 'POP');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_po_count   := 0;
        END;

        IF ln_po_count > 0
        THEN
            lv_message   := lv_message || 'Open PO Exist for this item';
        END IF;

        BEGIN
            SELECT COUNT (1)
              INTO ln_so_count
              FROM oe_order_lines_all a, oe_order_headers_all b
             WHERE     1 = 1
                   AND a.header_id = b.header_id
                   AND a.flow_status_code IN
                           ('PICKED', 'PICKED_PARTIAL', 'RELEASED_TO_WAREHOUSE')
                   AND a.inventory_item_id IN
                           (SELECT DISTINCT b.inventory_item_id
                              FROM mtl_item_categories a, mtl_system_items_b b
                             WHERE     1 = 1
                                   AND a.inventory_item_id =
                                       b.inventory_item_id
                                   AND b.inventory_item_id =
                                       p_inventory_item_id
                                   AND a.category_id IN
                                           (SELECT category_id
                                              FROM mtl_categories
                                             WHERE 1 = 1 AND segment3 = 'POP'));
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_so_count   := 0;
        END;

        IF ln_so_count > 0
        THEN
            lv_message   :=
                lv_message || '-' || 'Open SO Exist for this item';
        END IF;

        RETURN lv_message;
    END get_open_po_so_det;

    /************************************************************************************************
 ************ Procudure to identify eligible POP items and to insert into custom table ***********
 ************************************************************************************************/

    PROCEDURE insert_pop_items (p_organization_id     IN NUMBER,
                                p_inventory_item_id   IN NUMBER)
    IS
        CURSOR fetch_pop_items IS
              SELECT xct.inventory_item_id, xct.item_number, xct.organization_id,
                     moq.subinventory_code, moq.cost_group_id, costing_enabled_flag,
                     inventory_asset_flag, moq.transaction_uom_code, xct.brand,
                     SUM (NVL (moq.primary_transaction_quantity, 0)) quantity -- 282, 35757
                FROM xxd_common_items_v xct, mtl_system_items_b msib, mtl_onhand_quantities_detail moq
               WHERE     department = 'POP'
                     AND xct.inventory_item_id = msib.inventory_item_id
                     AND xct.organization_id = msib.organization_id
                     AND xct.inventory_item_id = moq.inventory_item_id(+)
                     AND xct.organization_id = moq.organization_id(+)
                     AND msib.organization_id =
                         NVL (p_organization_id, msib.organization_id)
                     AND msib.inventory_item_id =
                         NVL (p_inventory_item_id, msib.inventory_item_id)
                     AND (NVL (costing_enabled_flag, 'Z') <> 'N' OR NVL (inventory_asset_flag, 'Z') <> 'N')
            GROUP BY xct.inventory_item_id, xct.item_number, xct.organization_id,
                     moq.subinventory_code, moq.cost_group_id, costing_enabled_flag,
                     inventory_asset_flag, moq.transaction_uom_code, xct.brand
            ORDER BY inventory_item_id, organization_id;

        l_cursor_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Custom table insertion starts');

        FOR i IN fetch_pop_items
        LOOP
            l_cursor_count   := l_cursor_count + 1;

            BEGIN
                INSERT INTO xxdo.xxd_inv_pop_item_update_t (inventory_item_id, item_number, organization_id, subinventory_code, cost_group_id, costing_enabled_flag, inventory_asset_flag, transaction_uom_code, quantity, brand, created_by, creation_date, last_updated_by, last_update_date, request_id
                                                            , current_flag)
                     VALUES (i.inventory_item_id, i.item_number, i.organization_id, i.subinventory_code, i.cost_group_id, i.costing_enabled_flag, i.inventory_asset_flag, i.transaction_uom_code, i.quantity, i.brand, gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_request_id
                             , 'Y');

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into custom table failed'
                        || '-'
                        || SQLERRM);
            --p_retcode := 1;
            -- p_errbuf := 'Inserting data into custom table failed';
            -- EXIT;
            END;
        END LOOP;

        --If no records exists complete the program and return

        IF l_cursor_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'No POP items for the given parameters');
        END IF;

        -- Updating all the zero quantity items as zero quantity -- QA defect change
        BEGIN
            UPDATE xxdo.xxd_inv_pop_item_update_t
               SET status = 'ZERO QUANTITY', last_update_date = SYSDATE
             WHERE quantity = 0 AND STATUS IS NULL AND error_message IS NULL;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to update staging table' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'In insert_pop_items Procedure Exception' || SQLERRM);
    END insert_pop_items;

    /************************************************************************************************
 ******************************* PROCEDURE to perform Account alias issue ***********************
 ************************************************************************************************/

    PROCEDURE aai_non_zero_items (p_organization_id     IN NUMBER,
                                  p_inventory_item_id   IN NUMBER)
    IS
        CURSOR fetch_nonzero_qty_items IS
              SELECT *
                FROM xxdo.xxd_inv_pop_item_update_t
               WHERE     quantity <> 0
                     AND organization_id =
                         NVL (p_organization_id, organization_id)
                     AND inventory_item_id =
                         NVL (p_inventory_item_id, inventory_item_id)
                     AND status IS NULL
                     AND error_message IS NULL
            ORDER BY inventory_item_id, organization_id;

        ln_trxn_intf_id          NUMBER;
        ln_trxn_hdr_id           NUMBER;
        ln_trxn_intf_id1         NUMBER;
        ln_trxn_hdr_id1          NUMBER;
        v_ret_status             VARCHAR2 (100);
        v_msg_cnt                NUMBER;
        v_msg_data               VARCHAR2 (2000);
        v_ret_value              NUMBER;
        v_trans_count            NUMBER;
        l_item_tbl_typ           ego_item_pub.item_tbl_type;
        x_item_table             ego_item_pub.item_tbl_type;
        x_inventory_item_id      mtl_system_items_b.inventory_item_id%TYPE;
        x_organization_id        mtl_system_items_b.organization_id%TYPE;
        x_return_status          VARCHAR2 (1);
        x_msg_count              NUMBER (10);
        x_msg_data               VARCHAR2 (1000);
        x_message_list           error_handler.error_tbl_type;
        l_costing_enabled_flag   VARCHAR2 (1);
        l_inventory_asset_flag   VARCHAR2 (1);
        l_error                  VARCHAR2 (4000);
        ln_trxn_source_id        NUMBER;
        ln_trxn_source_id1       NUMBER;
        lv_message               VARCHAR2 (4000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Account Alias issue starts');

        -- insert the record in mtl_transaction_interface for Account Alias Issue
        FOR i IN fetch_nonzero_qty_items
        LOOP
            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_trxn_intf_id
              FROM DUAL;

            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_trxn_hdr_id
              FROM DUAL;

            BEGIN
                IF i.organization_id = 107
                THEN
                    SELECT MAX (disposition_id)
                      INTO ln_trxn_source_id
                      FROM mtl_generic_dispositions a
                     WHERE     organization_id = i.organization_id
                           AND attribute1 = i.brand
                           AND description LIKE '%Conversion%';
                ELSE
                    SELECT MAX (disposition_id)
                      INTO ln_trxn_source_id
                      FROM mtl_generic_dispositions a
                     WHERE     organization_id = i.organization_id
                           AND attribute1 = i.brand;
                END IF;

                IF ln_trxn_source_id IS NULL
                THEN
                    SELECT MAX (disposition_id)
                      INTO ln_trxn_source_id
                      FROM mtl_generic_dispositions a
                     WHERE organization_id = i.organization_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_trxn_source_id   := NULL;
            END;

            BEGIN
                INSERT INTO mtl_transactions_interface (
                                source_code,
                                source_line_id,
                                source_header_id,
                                process_flag,
                                transaction_mode,
                                lock_flag,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                inventory_item_id,
                                organization_id,
                                transaction_quantity,
                                transaction_uom,
                                transaction_date,
                                subinventory_code,
                                transaction_type_id,
                                transaction_reference,
                                transaction_interface_id,
                                primary_quantity,
                                transaction_header_id,
                                transaction_source_id)
                     VALUES ('Account alias', 99, 99,
                             1, 3, 2,
                             SYSDATE, gn_user_id, SYSDATE,
                             gn_user_id, i.inventory_item_id, i.organization_id, (-1 * i.quantity), i.transaction_uom_code, SYSDATE, i.subinventory_code, 31, 'POP', ln_trxn_intf_id, (-1 * i.quantity), ln_trxn_hdr_id
                             , ln_trxn_source_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into custom table failed'
                        || '-'
                        || SQLERRM);
            END;

            -- call the API

            BEGIN
                v_ret_value   :=
                    inv_txn_manager_pub.process_transactions (
                        p_api_version        => 1.0,
                        p_init_msg_list      => 'T',
                        p_commit             => 'T',
                        p_validation_level   => 100,
                        x_return_status      => v_ret_status,
                        x_msg_count          => v_msg_cnt,
                        x_msg_data           => v_msg_data,
                        x_trans_count        => v_trans_count,
                        p_table              => 1,
                        p_header_id          => ln_trxn_hdr_id);

                COMMIT;
                fnd_file.put_line (fnd_file.LOG,
                                   'API return status is: ' || v_ret_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'API msg count is: ' || v_msg_cnt);
                fnd_file.put_line (fnd_file.LOG,
                                   'API msg data is: ' || v_msg_data);

                IF (NVL (v_ret_status, 'X') = 'S')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Account Alias issue success: ' || i.inventory_item_id);

                    BEGIN
                        UPDATE xxdo.xxd_inv_pop_item_update_t
                           SET status = 'AAI Done', last_update_date = SYSDATE
                         WHERE     inventory_item_id = i.inventory_item_id
                               AND organization_id = i.organization_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Failed to update staging table' || SQLERRM);
                    END;
                ELSE
                    /* error_handler.get_message_list (x_message_list => x_message_list);
                     FOR i IN 1 .. x_message_list.COUNT
                     LOOP
               l_error :=SUBSTR(l_error||x_message_list (i).MESSAGE_TEXT,1,3999);
                     END LOOP;*/
                    -- check whether open so and open po exists
                    l_error      := v_msg_data;
                    lv_message   := get_open_po_so_det (i.inventory_item_id);
                    l_error      := l_error || '-' || lv_message;

                    BEGIN
                        UPDATE xxdo.xxd_inv_pop_item_update_t
                           SET status = 'AAI Failed', error_message = l_error, last_update_date = SYSDATE
                         WHERE     inventory_item_id = i.inventory_item_id
                               AND organization_id = i.organization_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Failed to update staging table' || SQLERRM);
                    END;
                END IF;
            END;
        --END;

        END LOOP;
    END aai_non_zero_items;

    /************************************************************************************************
 ******************************* PROCEDURE to update falgs ***************************************
 ************************************************************************************************/

    PROCEDURE update_all_items (p_organization_id     IN NUMBER,
                                p_inventory_item_id   IN NUMBER)
    IS
        CURSOR fetch_all_items IS
              SELECT DISTINCT pop_cust.inventory_item_id
                FROM xxdo.xxd_inv_pop_item_update_t pop_cust
               WHERE     1 = 1
                     AND pop_cust.inventory_item_id =
                         NVL (p_inventory_item_id, pop_cust.inventory_item_id)
                     AND pop_cust.error_message IS NULL
                     AND pop_cust.status IN ('AAI Done', 'ZERO QUANTITY')
                     AND NVL (pop_cust.current_flag, 'N') = 'Y'
                     AND pop_cust.inventory_item_id NOT IN
                             (2197786, 3604786, 11389256,
                              12850721, 4627798, 3391787,
                              4630798, 11442256, 12852721,
                              2195786, 12847722, 12847723,
                              12851721, 4628798, 900028976,
                              3605787, 3390787, 4631798,
                              12846721, 12847721, 3657787,
                              3605786, 4629798, 4633798,
                              11443256, 900028962, 2196786,
                              900028961, 900028963, 4632798,
                              12849721, 2195787, 3389787,
                              3603786, 4632799, 11390256)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_inv_pop_item_update_t pop
                               WHERE     1 = 1
                                     AND pop.inventory_item_id =
                                         pop_cust.inventory_item_id
                                     AND pop.error_message IS NOT NULL
                                     AND NVL (pop.current_flag, 'N') = 'Y')
            ORDER BY inventory_item_id;

        CURSOR error_update (p_request_id IN NUMBER)
        IS
              SELECT msii.segment1, mie.error_message, mie.request_id
                FROM apps.mtl_interface_errors mie, apps.mtl_system_items_interface msii
               WHERE     1 = 1
                     AND mie.transaction_id = msii.transaction_id
                     AND mie.request_id = p_request_id
            ORDER BY msii.segment1;

        ln_trxn_intf_id          NUMBER;
        ln_trxn_hdr_id           NUMBER;
        ln_trxn_intf_id1         NUMBER;
        ln_trxn_hdr_id1          NUMBER;
        v_ret_status             VARCHAR2 (100);
        v_msg_cnt                NUMBER;
        v_msg_data               VARCHAR2 (2000);
        v_ret_value              NUMBER;
        v_trans_count            NUMBER;
        l_item_tbl_typ           ego_item_pub.item_tbl_type;
        x_item_table             ego_item_pub.item_tbl_type;
        x_inventory_item_id      mtl_system_items_b.inventory_item_id%TYPE;
        x_organization_id        mtl_system_items_b.organization_id%TYPE;
        x_return_status          VARCHAR2 (1);
        x_msg_count              NUMBER (10);
        x_msg_data               VARCHAR2 (1000);
        x_message_list           error_handler.error_tbl_type;
        l_costing_enabled_flag   VARCHAR2 (1);
        l_inventory_asset_flag   VARCHAR2 (1);
        l_error                  VARCHAR2 (4000);
        ln_trxn_source_id        NUMBER;
        ln_trxn_source_id1       NUMBER;
        v_organization_id        NUMBER := 0;
        v_request_id             NUMBER := 0;
        v_phase                  VARCHAR2 (240);
        v_status                 VARCHAR2 (240);
        v_request_phase          VARCHAR2 (240);
        v_request_status         VARCHAR2 (240);
        v_finished               BOOLEAN;
        v_message                VARCHAR2 (240);
        v_sub_status             BOOLEAN := FALSE;
    BEGIN
        -- run the API to update the flags
        fnd_file.put_line (
            fnd_file.LOG,
            'Updating costing_enabled_flag and inventory_asset_flag starts');

        FOR i IN fetch_all_items
        LOOP
            --l_costing_enabled_flag:='';
            --  l_inventory_asset_flag:='';
            -- l_error:='';
            -- Inserting required data in mtl_system_items_interface
            BEGIN
                INSERT INTO mtl_system_items_interface (process_flag, set_process_id, inventory_item_id, transaction_type, costing_enabled_flag, inventory_asset_flag
                                                        , organization_id)
                     VALUES (1, 1, i.inventory_item_id,
                             'UPDATE', 'N', 'N',
                             106);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into custom table failed'
                        || '-'
                        || SQLERRM);
            END;
        END LOOP;

        BEGIN
            v_request_id   :=
                fnd_request.submit_request (application => 'INV', program => 'INCOIN', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => 106, -- Organization id
                                                                                                                                                                           argument2 => 1, -- All organizations
                                                                                                                                                                                           argument3 => 1, -- Validate Items
                                                                                                                                                                                                           argument4 => 1, -- Process Items
                                                                                                                                                                                                                           argument5 => 1, -- Delete Processed Rows
                                                                                                                                                                                                                                           argument6 => NULL, -- Process Set (Null for All)
                                                                                                                                                                                                                                                              argument7 => 2
                                            ,        -- Create or Update Items
                                              argument8 => 1 -- Gather Statistics
                                                            );

            COMMIT;
        END;

        IF (v_request_id = 0)
        THEN
            DBMS_OUTPUT.put_line ('Item Import Program Not Submitted');
            v_sub_status   := FALSE;
        ELSE
            v_finished   :=
                fnd_concurrent.wait_for_request (
                    request_id   => v_request_id,
                    INTERVAL     => 0,
                    max_wait     => 0,
                    phase        => v_phase,
                    status       => v_status,
                    dev_phase    => v_request_phase,
                    dev_status   => v_request_status,
                    MESSAGE      => v_message);

            DBMS_OUTPUT.put_line ('Request Phase  : ' || v_request_phase);
            DBMS_OUTPUT.put_line ('Request Status : ' || v_request_status);
            DBMS_OUTPUT.put_line ('Request id     : ' || v_request_id);

            BEGIN
                UPDATE xxdo.xxd_inv_pop_item_update_t
                   SET status = 'Falgs Update Submitted', last_update_date = SYSDATE
                 WHERE     inventory_item_id =
                           NVL (p_inventory_item_id, inventory_item_id)
                       AND error_message IS NULL
                       AND inventory_item_id NOT IN
                               (2197786, 3604786, 11389256,
                                12850721, 4627798, 3391787,
                                4630798, 11442256, 12852721,
                                2195786, 12847722, 12847723,
                                12851721, 4628798, 900028976,
                                3605787, 3390787, 4631798,
                                12846721, 12847721, 3657787,
                                3605786, 4629798, 4633798,
                                11443256, 900028962, 2196786,
                                900028961, 900028963, 4632798,
                                12849721, 2195787, 3389787,
                                3603786, 4632799, 11390256);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to update staging table' || SQLERRM);
            END;
        END IF;

        FOR i IN error_update (v_request_id)
        LOOP
            BEGIN
                UPDATE xxdo.xxd_inv_pop_item_update_t
                   SET error_message = i.error_message, last_update_date = SYSDATE
                 WHERE item_number = i.segment1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to update staging table' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                   'Error in Submitting Item Import Program and error is '
                || SUBSTR (SQLERRM, 1, 200));
    END update_all_items;

    /************************************************************************************************
 ******************************* PROCEDURE to perform account alias receipt***********************
 ************************************************************************************************/

    PROCEDURE aar_non_zero_items (p_organization_id     IN NUMBER,
                                  p_inventory_item_id   IN NUMBER)
    IS
        CURSOR fetch_nonzero_qty_items IS
              SELECT *
                FROM xxdo.xxd_inv_pop_item_update_t
               WHERE     quantity <> 0
                     AND organization_id =
                         NVL (p_organization_id, organization_id)
                     AND inventory_item_id =
                         NVL (p_inventory_item_id, inventory_item_id)
                     AND status = 'Falgs Update Submitted'
                     AND NVL (current_flag, 'N') = 'Y'
            ORDER BY inventory_item_id, organization_id;

        ln_trxn_intf_id          NUMBER;
        ln_trxn_hdr_id           NUMBER;
        ln_trxn_intf_id1         NUMBER;
        ln_trxn_hdr_id1          NUMBER;
        v_ret_status             VARCHAR2 (100);
        v_msg_cnt                NUMBER;
        v_msg_data               VARCHAR2 (2000);
        v_ret_value              NUMBER;
        v_trans_count            NUMBER;
        l_item_tbl_typ           ego_item_pub.item_tbl_type;
        x_item_table             ego_item_pub.item_tbl_type;
        x_inventory_item_id      mtl_system_items_b.inventory_item_id%TYPE;
        x_organization_id        mtl_system_items_b.organization_id%TYPE;
        x_return_status          VARCHAR2 (1);
        x_msg_count              NUMBER (10);
        x_msg_data               VARCHAR2 (1000);
        x_message_list           error_handler.error_tbl_type;
        l_costing_enabled_flag   VARCHAR2 (1);
        l_inventory_asset_flag   VARCHAR2 (1);
        l_error                  VARCHAR2 (4000);
        ln_trxn_source_id        NUMBER;
        ln_trxn_source_id1       NUMBER;
    BEGIN
        -- insert the data in MTI for Account alias receipt
        fnd_file.put_line (fnd_file.LOG, 'Account Alias Receipt starts');

        FOR i IN fetch_nonzero_qty_items
        LOOP
            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_trxn_intf_id1
              FROM DUAL;

            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_trxn_hdr_id1
              FROM DUAL;

            BEGIN
                IF i.organization_id = 107
                THEN
                    SELECT MAX (disposition_id)
                      INTO ln_trxn_source_id
                      FROM mtl_generic_dispositions a
                     WHERE     organization_id = i.organization_id
                           AND attribute1 = i.brand
                           AND description LIKE '%Conversion%';
                ELSE
                    SELECT MAX (disposition_id)
                      INTO ln_trxn_source_id
                      FROM mtl_generic_dispositions a
                     WHERE     organization_id = i.organization_id
                           AND attribute1 = i.brand;
                END IF;

                IF ln_trxn_source_id IS NULL
                THEN
                    SELECT MAX (disposition_id)
                      INTO ln_trxn_source_id
                      FROM mtl_generic_dispositions a
                     WHERE organization_id = i.organization_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_trxn_source_id   := NULL;
            END;

            BEGIN
                INSERT INTO mtl_transactions_interface (
                                source_code,
                                source_line_id,
                                source_header_id,
                                process_flag,
                                transaction_mode,
                                lock_flag,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                inventory_item_id,
                                organization_id,
                                transaction_quantity,
                                transaction_uom,
                                transaction_date,
                                subinventory_code,
                                transaction_type_id,
                                transaction_reference,
                                transaction_interface_id,
                                primary_quantity,
                                transaction_header_id,
                                transaction_source_id)
                     VALUES ('Account alias', 99, 99,
                             1, 3, 2,
                             SYSDATE, gn_user_id, SYSDATE,
                             gn_user_id, i.inventory_item_id, i.organization_id, i.quantity, i.transaction_uom_code, SYSDATE, i.subinventory_code, 41, 'POP', ln_trxn_intf_id1, i.quantity, ln_trxn_hdr_id1
                             , ln_trxn_source_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into custom table failed'
                        || '-'
                        || SQLERRM);
            END;

            -- call the API

            BEGIN
                v_ret_value   :=
                    inv_txn_manager_pub.process_transactions (
                        p_api_version        => 1.0,
                        p_init_msg_list      => 'T',
                        p_commit             => 'T',
                        p_validation_level   => 100,
                        x_return_status      => v_ret_status,
                        x_msg_count          => v_msg_cnt,
                        x_msg_data           => v_msg_data,
                        x_trans_count        => v_trans_count,
                        p_table              => 1,
                        p_header_id          => ln_trxn_hdr_id1);

                COMMIT;
                fnd_file.put_line (fnd_file.LOG,
                                   'API return status is: ' || v_ret_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'API msg count is: ' || v_msg_cnt);
                fnd_file.put_line (fnd_file.LOG,
                                   'API msg data is: ' || v_msg_data);
                fnd_file.put_line (fnd_file.LOG,
                                   'API Trans count is: ' || v_trans_count);

                IF (NVL (v_ret_status, 'X') = 'S')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Account Alias Receipt success: ' || i.inventory_item_id);

                    BEGIN
                        UPDATE xxdo.xxd_inv_pop_item_update_t
                           SET status = 'AAR Done', last_update_date = SYSDATE
                         WHERE     inventory_item_id = i.inventory_item_id
                               AND organization_id = i.organization_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Failed to update staging table' || SQLERRM);
                    END;
                ELSE
                    /* error_handler.get_message_list (x_message_list => x_message_list);
                     FOR i IN 1 .. x_message_list.COUNT
                     LOOP
               l_error :=SUBSTR(l_error||x_message_list (i).MESSAGE_TEXT,1,3999);
                     END LOOP;*/
                    -- check whether open so and open po exists
                    l_error   := v_msg_data;

                    --lv_message:=get_open_po_so_det(i.inventory_item_id);
                    --l_error:=l_error||'-'||lv_message;
                    BEGIN
                        UPDATE xxdo.xxd_inv_pop_item_update_t
                           SET status = 'AAR Failed', error_message = l_error, last_update_date = SYSDATE
                         WHERE     inventory_item_id = i.inventory_item_id
                               AND organization_id = i.organization_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Failed to update staging table' || SQLERRM);
                    END;
                END IF;
            END;
        END LOOP;

        BEGIN
            UPDATE xxdo.xxd_inv_pop_item_update_t
               SET current_flag = 'N', last_update_date = SYSDATE
             WHERE current_flag = 'Y' OR current_flag IS NULL;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to update staging table' || SQLERRM);
        END;
    END aar_non_zero_items;

    /************************************************************************************************
  *************************************** Main Procudure *****************************************
  ************************************************************************************************/

    PROCEDURE main (p_errbuf                 OUT VARCHAR2,
                    p_retcode                OUT NUMBER,
                    p_organization_id     IN     NUMBER,
                    p_inventory_item_id   IN     NUMBER,
                    p_transaction_type    IN     VARCHAR2)
    AS
        lv_costed_flag   VARCHAR2 (3);
        l_sleep_count    NUMBER := 0;

        -- Start for CCR0008684
        CURSOR pop_item_orders IS
            SELECT 'Sales Order : ' || TO_CHAR (b.order_number) Order_Number, d.organization_id
              FROM oe_order_lines_all a, oe_order_headers_all b, mtl_system_items_b d,
                   mtl_item_categories c
             WHERE     1 = 1
                   AND a.header_id = b.header_id
                   AND a.flow_status_code IN
                           ('PICKED', 'PICKED_PARTIAL', 'RELEASED_TO_WAREHOUSE')
                   AND a.inventory_item_id = d.inventory_item_id
                   AND a.ship_from_org_id = d.organization_id
                   AND d.inventory_item_id = c.inventory_item_id
                   AND d.organization_id = c.organization_id
                   AND c.category_id IN (SELECT category_id
                                           FROM mtl_categories
                                          WHERE 1 = 1 AND segment3 = 'POP')
            UNION
            SELECT    'Purchase Order : '
                   || (SELECT segment1
                         FROM po_headers_all
                        WHERE po_header_id = d.po_header_id) Order_Number,
                   b.organization_id
              FROM mtl_item_categories a, mtl_system_items_b b, rcv_shipment_lines d
             WHERE     1 = 1
                   AND a.inventory_item_id = b.inventory_item_id
                   AND a.inventory_item_id = d.item_id
                   AND d.shipment_line_status_code IN
                           ('EXPECTED', 'PARTIALLY RECEIVED')
                   AND b.organization_id = a.organization_id
                   AND a.category_id IN (SELECT category_id
                                           FROM mtl_categories
                                          WHERE 1 = 1 AND segment3 = 'POP');
    -- End for CCR0008684
    BEGIN
        --added for CCR0008684
        fnd_file.put_line (fnd_file.LOG, 'Deckers POP Item Orders List');

        FOR pop_item_orders_rec IN pop_item_orders
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   pop_item_orders_rec.Order_Number
                || ' Organization Id : '
                || pop_item_orders_rec.organization_id);
        END LOOP;

        -- End for CCR0008684
        fnd_file.put_line (fnd_file.LOG,
                           'Deckers POP Items Update Program starts here');
        fnd_file.put_line (fnd_file.LOG,
                           '--------------------------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Parameters');
        fnd_file.put_line (fnd_file.LOG,
                           'p_organization_id:' || p_organization_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_inventory_item_id:' || p_inventory_item_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_transaction_type:' || p_transaction_type);

        IF NVL (p_transaction_type, 'X') = 'Insert Records'
        THEN
            -- procedure to insert the eligible records in custom table
            insert_pop_items (p_organization_id, p_inventory_item_id);
        ELSIF NVL (p_transaction_type, 'X') = 'Account alias issue'
        THEN
            aai_non_zero_items (p_organization_id, p_inventory_item_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   'gn_request_id:'
                || gn_request_id
                || '-'
                || 'p_organization_id'
                || p_organization_id);
        ELSIF NVL (p_transaction_type, 'X') = 'Update Flags'
        THEN
            update_all_items (p_organization_id, p_inventory_item_id);
        ELSIF NVL (p_transaction_type, 'X') = 'Account alias receipt'
        THEN
            aar_non_zero_items (p_organization_id, p_inventory_item_id);
        ELSIF p_transaction_type IS NULL
        THEN
            -- procedure to insert the eligible records in custom table
            insert_pop_items (p_organization_id, p_inventory_item_id);
            aai_non_zero_items (p_organization_id, p_inventory_item_id);
            --DBMS_LOCK.sleep (600);
            update_all_items (p_organization_id, p_inventory_item_id);
            aar_non_zero_items (p_organization_id, p_inventory_item_id);
        END IF;
    /* BEGIN
     LOOP
     l_sleep_count:=l_sleep_count+1;
     <<loopstart>>
        BEGIN
    SELECT DISTINCT costed_flag
       INTO lv_costed_flag
     FROM mtl_material_transactions mmt
     WHERE request_id = gn_request_id
        AND organization_id = NVL(p_organization_id,organization_id)
        AND exists
        (SELECT 1
        FROM xxd_common_items_v  a
        where department = 'POP'
        AND a.inventory_item_id = mmt.inventory_item_id
        );
     EXCEPTION WHEN OTHERS THEN
     lv_costed_flag := 'N';
     END;
     IF lv_costed_flag IS NULL OR l_sleep_count >3 THEN
      EXIT;--
        ELSE */
    --DBMS_LOCK.sleep (600);
    -- END IF;
    ---- END LOOP;
    --END;

    END main;
END xxd_inv_pop_items_update_pkg;
/
