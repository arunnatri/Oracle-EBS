--
-- XXD_WMS_NEST_LPNS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_NEST_LPNS_PKG"
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
        l_pallet_id                  NUMBER;
        --Process Counters
        ln_loop_count                NUMBER := 0;
        ln_commit_count              NUMBER := 0;

        CURSOR cur_rec IS
              SELECT DISTINCT org_id, pallet, lpn,
                              sub, locator_id, inventory_item_id,
                              uom
                FROM xxd_conv.xxd_inv_item_onhand_lpn_stg_t
               -- Start Changes for Conversion by BT Team 29-FEB-2016
               WHERE TRANSLATE (PALLET, ' 0123456789', ' ') IS NULL
            ORDER BY pallet, lpn-- End Changes for Conversion by BT Team 29-FEB-2016
                                ;
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
                        fnd_file.put_line (fnd_file.LOG,
                                           'license plate issue' || SQLERRM);
                END;

                --Get PALLET ID
                BEGIN
                    SELECT lpn_id
                      INTO l_pallet_id
                      FROM wms_license_plate_numbers
                     WHERE     organization_id = i.org_id
                           AND license_plate_number = i.pallet;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'pallet issue' || SQLERRM);
                END;

                -- BEGIN
                INSERT INTO mtl_transactions_interface (
                                transaction_interface_id,
                                last_update_date                     --sysdate
                                                ,
                                last_updated_by                          -- -1
                                               ,
                                creation_date                        --sysdate
                                             ,
                                created_by                               -- -1
                                          ,
                                last_update_login                        -- -1
                                                 ,
                                inventory_item_id                        -- -1
                                                 ,
                                organization_id                          --125
                                               ,
                                subinventory_code                        --RSV
                                                 ,
                                locator_id,
                                transaction_type_id                  --87 pack
                                                   ,
                                transaction_action_id      --50 Container Pack
                                                     ,
                                transaction_source_type_id --13 Container Pack
                                                          ,
                                source_code,
                                source_line_id,
                                source_header_id,
                                process_flag,
                                transaction_mode,
                                transaction_source_id                   --NULL
                                                     ,
                                transaction_source_name                 --NULL
                                                       ,
                                transaction_quantity                     -- -1
                                                    ,
                                transaction_uom,
                                primary_quantity                         -- -1
                                                ,
                                transaction_date                     --sysdate
                                                ,
                                distribution_account_id,
                                dst_segment1,
                                dst_segment2,
                                dst_segment3,
                                dst_segment4,
                                dst_segment5,
                                transfer_lpn_id                   --parent_lpn
                                               ,
                                content_lpn_id                     --child_lpn
                                              )
                     VALUES (l_transaction_interface_id, SYSDATE, --LAST_UPDATE_DATE
                                                                  -1 --LAST_UPDATED_BY
                                                                    ,
                             SYSDATE                           --CREATION_DATE
                                    , -1                          --CREATED_BY
                                        , -1               --LAST_UPDATE_LOGIN
                                            ,
                             i.inventory_item_id--INVENTORY_ITEM_ID This is the item of the content_lpn (case level LPN)
                                                , i.org_id   --ORGANIZATION_ID
                                                          , i.sub --SUBINVENTORY_CODE
                                                                 ,
                             i.locator_id                         --LOCATOR_ID
                                         , l_trx_type_id --TRANSACTION_TYPE_ID --87 pack
                                                        , 50 --TRANSACTION_ACTION_ID --50 Container Pack
                                                            ,
                             13 --TRANSACTION_SOURCE_TYPE_ID -13 Container Pack
                               , 'NEST LPNS', 99,
                             99, 1, 3,
                             13                  -- TRANSACTION_SOURCE_ID --13
                               , NULL         --TRANSACTION_SOURCE_NAME --NULL
                                     , -1               --TRANSACTION_QUANTITY
                                         ,
                             i.uom--TRANSACTION_UOM This is the UOM of the Item in the content lpn
                                  , -1                      --PRIMARY_QUANTITY
                                      , SYSDATE             --TRANSACTION_DATE
                                               ,
                             l_distribution_account_id, l_segment1, l_segment2, l_segment3, l_segment4, l_segment5
                             , l_pallet_id      --TRANSFER_LPN_ID --parent_lpn
                                          , l_lpn_id --CONTENT_LPN_ID --child_lpn
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
END xxd_wms_nest_lpns_pkg;
/
