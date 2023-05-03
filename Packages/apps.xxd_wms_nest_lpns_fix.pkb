--
-- XXD_WMS_NEST_LPNS_FIX  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_NEST_LPNS_FIX"
AS
    PROCEDURE nest_lpn (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        l_return_status              VARCHAR2 (10);
        l_errorcode                  NUMBER;
        l_msg_count                  NUMBER;
        l_msg_data                   VARCHAR2 (2000);
        l_trans_count                NUMBER;
        l_message                    VARCHAR2 (2000);
        l_transaction_interface_id   NUMBER;
        l_acct_period_id             NUMBER;

        --Process Counters
        ln_loop_count                NUMBER := 0;
        ln_commit_count              NUMBER := 0;

        CURSOR cur_rec IS
              SELECT DISTINCT
                     mmt.ORGANIZATION_ID,
                     mti.creation_date || '-' || mti.source_code,
                     mti.ERROR_CODE,
                     wlpn.license_plate_number,
                     wlpn.lpn_id,
                     (SELECT license_plate_number
                        FROM apps.wms_license_plate_numbers
                       WHERE lpn_id = mti.transfer_lpn_id)
                         expected_pallet,
                     (SELECT license_plate_number
                        FROM apps.wms_license_plate_numbers
                       WHERE lpn_id = mmt.transfer_lpn_id)
                         actual_pallet,
                     mmt.transfer_lpn_id,
                     mmt.LAST_UPDATE_DATE || '-' || mmt.source_code
                         actual_transaction,
                     mti.SUBINVENTORY_CODE,
                     (SELECT concatenated_segments
                        FROM apps.mtl_item_locations_kfv
                       WHERE INVENTORY_LOCATION_ID = mti.locator_id)
                         expected_loc,
                     mmt.SUBINVENTORY_CODE
                         actual_sub,
                     (SELECT concatenated_segments
                        FROM apps.mtl_item_locations_kfv
                       WHERE INVENTORY_LOCATION_ID = mmt.locator_id)
                         actual_loc,
                     mmt.locator_id,
                     mmt.INVENTORY_ITEM_ID
                FROM apps.mtl_material_transactions mmt, apps.mtl_transactions_interface mti, apps.wms_license_plate_numbers wlpn
               WHERE     mmt.content_LPN_ID = mti.content_LPN_ID
                     AND mti.source_code = 'NEST LPNS'
                     AND mti.content_lpn_id = wlpn.lpn_id
            ORDER BY wlpn.LPN_ID;
    BEGIN
        FOR i IN cur_rec
        LOOP
            BEGIN
                -- Get the Interface Transaction ID
                BEGIN
                    SELECT mtl_material_transactions_s.NEXTVAL
                      INTO l_transaction_interface_id
                      FROM DUAL;
                END;

                -- Get the acct_period_id
                BEGIN
                    SELECT ACCT_PERIOD_ID
                      INTO l_acct_period_id
                      FROM apps.ORG_ACCT_PERIODS_V
                     WHERE     organization_id = i.organization_id
                           AND SYSDATE < END_DATE
                           AND status = 'Open';
                END;

                INSERT INTO apps.mtl_transactions_interface (
                                transaction_interface_id,
                                acct_period_id,
                                transaction_uom,
                                transaction_date,
                                source_code,
                                source_line_id,
                                source_header_id,
                                process_flag,
                                transaction_mode,
                                lock_flag,
                                locator_id,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                inventory_item_id,
                                subinventory_code,
                                organization_id,
                                transaction_quantity,
                                primary_quantity,
                                transaction_type_id,
                                transaction_action_id,
                                transaction_source_type_id,
                                lpn_id,
                                content_lpn_id)
                     VALUES (l_transaction_interface_id, --transaction_interface_id
                                                         l_acct_period_id, --acct_period_id
                                                                           'EA', --transaction uom
                                                                                 SYSDATE, --transaction date
                                                                                          'Container UnPack', --source code
                                                                                                              99, --source line id
                                                                                                                  99, --source header id
                                                                                                                      1, --process flag
                                                                                                                         3, --transaction mode
                                                                                                                            2, --lock flag
                                                                                                                               i.locator_id, --locator id
                                                                                                                                             SYSDATE, --last update date
                                                                                                                                                      -1, --last updated by
                                                                                                                                                          SYSDATE, --creation date
                                                                                                                                                                   -1, --created by
                                                                                                                                                                       i.inventory_item_id, --inventory item id
                                                                                                                                                                                            i.actual_sub, --From subinventory code
                                                                                                                                                                                                          i.organization_id, --organization id
                                                                                                                                                                                                                             -1, --transaction quantity
                                                                                                                                                                                                                                 -1, --Primary quantity
                                                                                                                                                                                                                                     88, --transaction type id
                                                                                                                                                                                                                                         51, --transaction_action_id
                                                                                                                                                                                                                                             13, --transaction_source_type_id
                                                                                                                                                                                                                                                 i.transfer_lpn_id
                             ,                                        --lpn id
                               i.lpn_id                       --content_lpn_id
                                       );

                ln_loop_count     := ln_loop_count + 1;
                ln_commit_count   := ln_commit_count + 1;

                IF ln_commit_count = 2000
                THEN
                    COMMIT;
                    ln_commit_count   := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error inserting mtl_transactions_interface'
                        || SQLERRM);
            END;
        END LOOP;

        IF ln_loop_count < 1
        THEN
            retcode   := 1;                                         -- Warning
            errbuf    := 'No Records Processed';
        ELSE
            retcode   := 0;                                         -- Success
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in xxd_wms_pack_lpns_pkg' || SQLERRM);
    END;
END XXD_WMS_NEST_LPNS_FIX;
/
