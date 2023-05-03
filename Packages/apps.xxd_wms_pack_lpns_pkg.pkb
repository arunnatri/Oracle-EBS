--
-- XXD_WMS_PACK_LPNS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_PACK_LPNS_PKG"
AS
    PROCEDURE pack_case_lpns (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        l_return_status              VARCHAR2 (10);
        l_errorcode                  NUMBER;
        l_msg_count                  NUMBER;
        l_msg_data                   VARCHAR2 (2000);
        l_trans_count                NUMBER;
        l_message                    VARCHAR2 (2000);
        l_transaction_interface_id   NUMBER;
        l_trx_type_id                NUMBER;
        l_distribution_account_id    NUMBER;
        l_segment1                   NUMBER;
        l_segment2                   NUMBER;
        l_segment3                   NUMBER;
        l_segment4                   NUMBER;
        l_segment5                   NUMBER;
        l_return_value               NUMBER;
        l_locator_id                 NUMBER;
        l_lpn_id                     NUMBER;
        --Process Counters
        ln_loop_count                NUMBER := 0;
        ln_commit_count              NUMBER := 0;

        CURSOR cur_rec IS
            SELECT DISTINCT org_id, lpn, sub,
                            LOCATION, inventory_item_id, quantity,
                            uom
              FROM xxd_conv.xxd_inv_item_onhand_lpn_stg_t
             WHERE lpn IN
                       (SELECT license_plate_number
                          FROM apps.wms_license_plate_numbers
                         WHERE     lpn_context = 5
                               AND TRANSLATE (license_plate_number,
                                              ' 0123456789',
                                              ' ')
                                       IS NULL);
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

                -- Get the Transaction type ID
                BEGIN
                    SELECT transaction_type_id
                      INTO l_trx_type_id
                      FROM mtl_transaction_types
                     WHERE transaction_type_name = 'Container Pack';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'transaction_type_name name issue' || SQLERRM);
                END;

                --Get the distribution_acount
                BEGIN
                    SELECT distribution_account
                      INTO l_distribution_account_id
                      FROM mtl_generic_dispositions
                     WHERE     organization_id = i.org_id
                           AND segment1 LIKE 'INV%ADJ%';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'distribution_account issue' || SQLERRM);
                END;

                -- Get segment1 of account
                BEGIN
                    SELECT segment1
                      INTO l_segment1
                      FROM gl_code_combinations
                     WHERE code_combination_id = l_distribution_account_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'gl_code_combinations segment1 issue' || SQLERRM);
                END;

                --get segment2 of account
                BEGIN
                    SELECT segment2
                      INTO l_segment2
                      FROM gl_code_combinations
                     WHERE code_combination_id = l_distribution_account_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'gl_code_combinations segment2 issue' || SQLERRM);
                END;

                --get segment3 of account
                BEGIN
                    SELECT segment3
                      INTO l_segment3
                      FROM gl_code_combinations
                     WHERE code_combination_id = l_distribution_account_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'gl_code_combinations segment3 issue' || SQLERRM);
                END;

                --Get segment4 of account
                BEGIN
                    SELECT segment4
                      INTO l_segment4
                      FROM gl_code_combinations
                     WHERE code_combination_id = l_distribution_account_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'gl_code_combinations segment4 issue' || SQLERRM);
                END;

                --Get segment5 of account
                BEGIN
                    SELECT segment5
                      INTO l_segment5
                      FROM gl_code_combinations
                     WHERE code_combination_id = l_distribution_account_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'gl_code_combinations segment5 issue' || SQLERRM);
                END;

                --Get LPN ID
                BEGIN
                    SELECT lpn_id
                      INTO l_lpn_id
                      FROM wms_license_plate_numbers
                     WHERE     organization_id = i.org_id
                           AND license_plate_number = i.lpn;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'license_plate_number issue' || SQLERRM);
                END;

                --Get locator_id
                BEGIN
                    SELECT inventory_location_id
                      INTO l_locator_id
                      FROM mtl_item_locations_kfv
                     WHERE     i.org_id = organization_id
                           AND i.sub = subinventory_code
                           AND i.LOCATION = concatenated_segments;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'inventory locator issue' || SQLERRM);
                END;

                INSERT INTO mtl_transactions_interface (
                                transaction_uom,
                                transaction_date,
                                transaction_header_id,
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
                                transaction_source_id,
                                transaction_action_id,
                                distribution_account_id,
                                dst_segment1,
                                dst_segment2,
                                dst_segment3,
                                dst_segment4,
                                dst_segment5,
                                transaction_interface_id,
                                transfer_lpn_id)
                         VALUES (i.uom,                      --transaction uom
                                 SYSDATE,                   --transaction date
                                 l_transaction_interface_id, --transaction_header_id
                                 'Container Pack',
                                 --source code
                                 99,
                                 --source line id
                                 99,                        --source header id
                                 1,                             --process flag
                                 3,                         --transaction mode
                                 2,                                --lock flag
                                 l_locator_id,                    --locator id
                                 SYSDATE,                   --last update date
                                 -1,                         --last updated by
                                 SYSDATE,                      --creation date
                                 -1,                              --created by
                                 i.inventory_item_id,      --inventory item id
                                 i.sub,               --From subinventory code
                                 i.org_id,                   --organization id
                                 i.quantity,            --transaction quantity
                                 i.quantity,                --Primary quantity
                                 l_trx_type_id,          --transaction type id
                                 13,                   --transaction_source_id
                                 87,                   --transaction_action_id
                                 l_distribution_account_id,
                                 l_segment1,             --account combination
                                 l_segment2,             --account combination
                                 l_segment3,             --account combination
                                 l_segment4,             --account combination
                                 l_segment5,             --account combination
                                 l_transaction_interface_id, --transaction interface id
                                 l_lpn_id);                  --transfer lpn id

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
                    fnd_file.put_line (fnd_file.LOG, 'Error ' || SQLERRM);
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
END xxd_wms_pack_lpns_pkg;
/
