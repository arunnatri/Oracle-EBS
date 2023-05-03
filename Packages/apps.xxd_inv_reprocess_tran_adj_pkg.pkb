--
-- XXD_INV_REPROCESS_TRAN_ADJ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_REPROCESS_TRAN_ADJ_PKG"
AS
    --  #########################################################################################
    --  Author(s)       : Tejaswi Gangumalla
    --  System          : Oracle Applications
    --  Subsystem       :
    --  Change          :
    --  Schema          : APPS
    --  Purpose         : This package is used for re-processing of the inventory transaction messages which are in ERROR status
    --  Dependency      : N
    --  Change History
    --  --------------
    --  Date            Name                    Ver     Change                  Description
    --  ----------      --------------          -----   --------------------    ---------------------
    --  16-June-2019     Tejaswi Gangumalla       1.0     NA                      Initial Version
    --  23-Mar-2022      Techmahindra             1.1                             Modified the code to clean the error record from MTI table for CCR#CCR0009862.
    --
    --  #########################################################################################
    gn_request_id        NUMBER := fnd_global.conc_request_id;
    gn_user_id           NUMBER := fnd_global.user_id;
    gn_api_version       NUMBER := 1.0;
    gn_issue_type_id     NUMBER := 31;
    gn_receipt_type_id   NUMBER := 41;

    /* Procedure to write messages to log or output file*/
    PROCEDURE msg (pv_msg IN VARCHAR2, pv_file IN VARCHAR2 DEFAULT 'LOG')
    IS
    BEGIN
        IF UPPER (pv_file) = 'OUT'
        THEN
            fnd_file.put_line (fnd_file.output, pv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error in msg procedure');
    END msg;

    /*Prcedure to get transaction date in legal entity timezone */
    FUNCTION get_server_timezone (pn_inv_org_local_time   DATE,
                                  pn_num_inv_org_id       NUMBER)
        RETURN DATE
    IS
        ln_leid          NUMBER;
        ld_server_date   DATE := NULL;
    BEGIN
        --Get he legal entity of the organization
        BEGIN
            SELECT legal_entity
              INTO ln_leid
              FROM org_organization_definitions ood
             WHERE organization_id = pn_num_inv_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_leid   := -1;
        END;

        BEGIN
            --Conveting time to logal entity time zone
            SELECT xle_le_timezone_grp.get_server_day_time_for_le (pn_inv_org_local_time, ln_leid)
              INTO ld_server_date
              FROM DUAL;
        END;

        RETURN ld_server_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in get_server_timezone procedure');
            RETURN NULL;
    END get_server_timezone;

    /*Procedure to get current onhand quantity*/
    PROCEDURE get_current_onhand (pn_org_id         IN     NUMBER,
                                  pv_sub_inv_code   IN     VARCHAR2,
                                  pn_locator_id     IN     NUMBER,
                                  pn_inv_item_id    IN     NUMBER,
                                  pn_atr_quantity      OUT NUMBER)
    IS
        lv_api_return_status   VARCHAR2 (10);
        ln_msg_count           NUMBER := 0;
        lv_msg_data            VARCHAR2 (1000);
        ln_qty_oh              NUMBER := 0;                 --Total Onhand Qty
        ln_qty_atr             NUMBER := 0;         --Available to Reserve Qty
        ln_sum_qty_res         NUMBER := 0;
        ln_qty_rqoh            NUMBER := 0;
        ln_qty_qr              NUMBER := 0;                     --Reserved Qty
        ln_qty_qs              NUMBER := 0;
        ln_qty_att             NUMBER := 0;
        --Available to Transact Qty
        ln_qty_sqoh            NUMBER := 0;
        ln_qty_srqoh           NUMBER := 0;
        ln_qty_sqs             NUMBER := 0;
        ln_qty_satt            NUMBER := 0;
        ln_qty_satr            NUMBER := 0;
    BEGIN
        -- clear cache
        inv_quantity_tree_grp.clear_quantity_cache;
        -- call Inventory Quantity Tree Pub API to fetch Quantities for Available Sub-Inv
        inv_quantity_tree_pub.query_quantities (
            p_api_version_number           => gn_api_version,
            p_init_msg_lst                 => fnd_api.g_false,
            x_return_status                => lv_api_return_status,
            x_msg_count                    => ln_msg_count,
            x_msg_data                     => lv_msg_data,
            p_organization_id              => pn_org_id,
            p_inventory_item_id            => pn_inv_item_id,
            p_tree_mode                    => 0,
            p_is_revision_control          => FALSE,
            p_is_lot_control               => FALSE,
            p_is_serial_control            => FALSE,
            p_grade_code                   => -9999,
            p_demand_source_type_id        => -9999,
            p_demand_source_header_id      => -9999,
            p_demand_source_line_id        => -9999,
            p_demand_source_name           => NULL,
            p_lot_expiration_date          => NULL,
            p_revision                     => NULL,
            p_lot_number                   => NULL,
            p_subinventory_code            => pv_sub_inv_code,
            p_locator_id                   => pn_locator_id,
            p_onhand_source                => inv_quantity_tree_pvt.g_all_subs,
            x_qoh                          => ln_qty_oh,
            x_rqoh                         => ln_qty_rqoh,
            x_qr                           => ln_qty_qr,
            x_qs                           => ln_qty_qs,
            x_att                          => ln_qty_att,
            x_atr                          => ln_qty_atr,
            x_sqoh                         => ln_qty_sqoh,
            x_srqoh                        => ln_qty_srqoh,
            x_sqr                          => ln_sum_qty_res,
            x_sqs                          => ln_qty_sqs,
            x_satt                         => ln_qty_satt,
            x_satr                         => ln_qty_satr,
            p_transfer_subinventory_code   => NULL,
            p_cost_group_id                => NULL,
            p_lpn_id                       => NULL,
            p_transfer_locator_id          => NULL);

        IF lv_api_return_status = fnd_api.g_ret_sts_success
        THEN
            -- Set return values
            IF pv_sub_inv_code = 'Available'
            THEN
                pn_atr_quantity   := ln_qty_atr;
            ELSE
                pn_atr_quantity   := ln_qty_att;
            END IF;
        ELSE
            pn_atr_quantity   := 0;                                    --NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in get_current_onhand procedure');
            pn_atr_quantity   := 0;
    END get_current_onhand;

    /*Porcedure to updated new records to inprocess status and cehck for duplicate records*/
    PROCEDURE lock_records (pn_update_record_count OUT NUMBER)
    IS
    BEGIN
        --Updated new records to inprocess status
        BEGIN
            UPDATE xxdo_inv_trans_adj_dtl_stg
               SET process_status = 'INPROCESS', session_id = USERENV ('SESSIONID'), last_updated_by = gn_user_id,
                   last_update_date = SYSDATE
             WHERE process_status = 'NEW' AND request_id = gn_request_id;

            pn_update_record_count   := SQL%ROWCOUNT;
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error while updating records to inprocess status');
        END;

        --Update records status to Duplicate if any
        BEGIN
            UPDATE apps.xxdo_inv_trans_adj_dtl_stg xita
               SET process_status = 'DUPLICATE', error_message = 'Record already exists for message ID ' || xita.attribute1, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND request_id = gn_request_id
                   AND EXISTS
                           (SELECT *
                              FROM apps.xxdo_inv_trans_adj_dtl_stg xita2
                             WHERE     1 = 1
                                   AND xita2.process_status ! = 'DUPLICATE'
                                   AND xita2.item_number = xita.item_number
                                   AND xita2.attribute1 = xita.attribute1
                                   AND xita2.transaction_seq_id !=
                                       xita.transaction_seq_id);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error while updating records to duplicate status');
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in lock_records procedure');
    END lock_records;

    /*Main procedure called by concurrent program*/
    PROCEDURE control_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER)
    IS
        ln_eligible_records_count    NUMBER;
        ln_inprocess_records_count   NUMBER;
        lv_error_flag                VARCHAR2 (2);
        lv_submit_program            VARCHAR2 (2);
        lv_error_msg                 VARCHAR2 (4000);
    BEGIN
        --Calling procedure update_error_records to update error records to new records
        update_error_records (ln_eligible_records_count);

        -- If there are records updated to new status
        IF ln_eligible_records_count > 0
        THEN
            --Calling procedure loc_records to update new records to inprocess
            lock_records (ln_inprocess_records_count);

            --If the records are locked
            IF ln_inprocess_records_count > 0
            THEN
                --Calling procedure validate_and_insert_into_int to validate records and insert into interface table
                validate_and_insert_into_int (lv_submit_program);

                --If the records are inserted into interface table
                IF NVL (lv_submit_program, 'N') = 'Y'
                THEN
                    --Calling procedure submit_prgram to submit concurrent program "Process transaction interface"
                    submit_program (lv_error_flag, lv_error_msg);
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in control_proc procedure');
    END control_proc;

    PROCEDURE update_error_records (pn_count_records OUT NUMBER)
    IS
    BEGIN
        pn_count_records   := 0;

        --Update error records to NEW status to reprocess
        BEGIN
            UPDATE xxdo_inv_trans_adj_dtl_stg
               SET process_status = 'NEW', error_message = NULL, request_id = gn_request_id,
                   last_updated_by = fnd_global.user_id, last_update_date = SYSDATE, session_id = USERENV ('SESSIONID')
             WHERE process_status = 'ERROR';

            pn_count_records   := SQL%ROWCOUNT;
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Error while updating error records to new process_status');
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in update_error_records procedure');
    END update_error_records;

    PROCEDURE validate_and_insert_into_int (pv_submit_prog OUT VARCHAR2)
    IS
        CURSOR inv_transactions_cur IS
            SELECT *
              FROM apps.xxdo_inv_trans_adj_dtl_stg
             WHERE     process_status = 'INPROCESS'
                   AND request_id = gn_request_id;

        ln_org_id                      NUMBER;
        lv_error_flag                  VARCHAR2 (2);
        ln_count_source_subinventory   NUMBER;
        lv_error_msg                   VARCHAR2 (4000);
        ld_server_tran_date            DATE;
        ln_source_locator_id           NUMBER;
        ln_dest_locator_id             NUMBER;
        ln_inventory_item_id           NUMBER;
        lv_primary_uom_code            VARCHAR2 (20);
        lv_period_open_flag            VARCHAR2 (20);
        ln_atr_quantity                NUMBER;
        ln_trans_source_id             NUMBER;
        ln_distr_account_id            NUMBER;
        lv_account_alias               VARCHAR2 (40);
        ln_trans_type_id               NUMBER;
        ln_dest_org_id                 NUMBER;
        ln_txn_intf_id                 NUMBER;
        ln_emp_user_id                 NUMBER;
        ln_success_records             NUMBER := 0;
    BEGIN
        --Ope cursor to get records for current request_id and in Inprocess status
        FOR inv_transactions_rec IN inv_transactions_cur
        LOOP
            lv_error_flag                  := NULL;
            lv_error_msg                   := NULL;
            ln_org_id                      := NULL;
            ln_count_source_subinventory   := 0;
            ln_count_source_subinventory   := 0;
            ld_server_tran_date            := NULL;
            ln_source_locator_id           := NULL;
            ln_dest_locator_id             := NULL;
            ln_inventory_item_id           := NULL;
            lv_primary_uom_code            := NULL;

            /* Warehouse validation start*/
            BEGIN
                IF inv_transactions_rec.wh_id IS NULL
                THEN
                    lv_error_flag   := 'Y';
                    lv_error_msg    := 'Warehouse Cannot Be Null';
                    msg (
                           'Warehouse Cannot Be Null For Transaction Seq ID  :'
                        || inv_transactions_rec.transaction_seq_id);
                ELSE
                    BEGIN
                        SELECT organization_id
                          INTO ln_org_id
                          FROM mtl_parameters
                         WHERE organization_code = inv_transactions_rec.wh_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_org_id   := NULL;
                            msg (
                                   'Warehouse Validation Failed For Transaction Seq ID :'
                                || inv_transactions_rec.transaction_seq_id
                                || '-'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            ln_org_id   := NULL;
                            msg (
                                   'Error While Validating Warehouse For Transaction Seq ID :'
                                || inv_transactions_rec.transaction_seq_id
                                || '-'
                                || SQLERRM);
                    END;
                END IF;
            END;

            /* Warehouse validation end*/
            IF ln_org_id IS NULL
            THEN
                lv_error_flag   := 'Y';
                lv_error_msg    :=
                    lv_error_msg || ' ' || 'Warehouse Validation Failed';
            ELSE
                /* Source_subinventory validation start*/
                BEGIN
                    IF inv_transactions_rec.source_subinventory IS NULL
                    THEN
                        lv_error_flag   := 'Y';
                        lv_error_msg    :=
                               lv_error_msg
                            || ' '
                            || 'Source Subinventory Cannot Be Null';
                        msg (
                               'source_subinventory Cannot Be Null For Transaction Seq ID  :'
                            || inv_transactions_rec.transaction_seq_id);
                    ELSE
                        BEGIN
                            SELECT COUNT (*)
                              INTO ln_count_source_subinventory
                              FROM mtl_secondary_inventories
                             WHERE     organization_id = ln_org_id
                                   AND secondary_inventory_name =
                                       inv_transactions_rec.source_subinventory;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                --lv_error_flag := 'Y';
                                ln_count_source_subinventory   := 0;
                                msg (
                                       'Error While Validating Source Subinventory For Transaction Seq ID :'
                                    || inv_transactions_rec.transaction_seq_id
                                    || '-'
                                    || SQLERRM);
                        END;

                        IF ln_count_source_subinventory = 0
                        THEN
                            lv_error_flag   := 'Y';
                            lv_error_msg    :=
                                   lv_error_msg
                                || ' '
                                || 'Source Subinventory Validation Failed';
                            msg (
                                   'Source Subinventory Validation Failed For Transaction Seq ID:'
                                || inv_transactions_rec.transaction_seq_id);
                        END IF;
                    END IF;
                END;

                /* Source_subinventory validation end*/

                /*Destination Subinventory validation start*/
                BEGIN
                    IF inv_transactions_rec.dest_subinventory IS NOT NULL
                    THEN
                        BEGIN
                            SELECT COUNT (*)
                              INTO ln_count_source_subinventory
                              FROM mtl_secondary_inventories
                             WHERE     organization_id = ln_org_id
                                   AND secondary_inventory_name =
                                       inv_transactions_rec.dest_subinventory;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                --lv_error_flag := 'Y';
                                ln_count_source_subinventory   := 0;
                                msg (
                                       'Error While Validating Dest Subinventory For Transaction Seq ID :'
                                    || inv_transactions_rec.transaction_seq_id
                                    || '-'
                                    || SQLERRM);
                        END;

                        IF ln_count_source_subinventory = 0
                        THEN
                            lv_error_flag   := 'Y';
                            lv_error_msg    :=
                                   lv_error_msg
                                || ' '
                                || 'Dest Subinventory Validation Failed For Transaction Seq ID';
                            msg (
                                   'Destination Subinventory Validation Failed For Transaction Seq ID:'
                                || inv_transactions_rec.transaction_seq_id);
                        END IF;
                    END IF;
                END;

                /*Destination Subinventory validation end*/

                /*Transaction date validation start*/
                BEGIN
                    IF inv_transactions_rec.tran_date IS NULL
                    THEN
                        lv_error_flag   := 'Y';
                        lv_error_msg    :=
                               lv_error_msg
                            || ' '
                            || 'Transaction Date Validation Failed';
                        msg (
                               'Transaction Date Validation Failed For Transaction Seq ID :'
                            || inv_transactions_rec.transaction_seq_id);
                    ELSE
                        --convert transaction_date legal entity timezone
                        ld_server_tran_date   :=
                            get_server_timezone (
                                inv_transactions_rec.tran_date,
                                ln_org_id);

                        IF NVL (ld_server_tran_date, SYSDATE + 1) > SYSDATE
                        THEN
                            lv_error_flag   := 'Y';
                            lv_error_msg    :=
                                   lv_error_msg
                                || ' '
                                || 'Transaction Date Validation Failed';
                            msg (
                                   'Transaction Date Validation Failed For Transaction Seq ID :'
                                || inv_transactions_rec.transaction_seq_id);
                        END IF;
                    END IF;
                END;

                /*Transaction date validation end*/

                /*Quantity Validation start*/
                BEGIN
                    IF    inv_transactions_rec.qty = 0
                       OR inv_transactions_rec.qty IS NULL
                    THEN
                        lv_error_flag   := 'Y';
                        lv_error_msg    :=
                               lv_error_msg
                            || ' '
                            || 'Quantity  Validation Failed For Transaction';
                        msg (
                               'Quantity Validation Failed For Transaction Seq ID :'
                            || inv_transactions_rec.transaction_seq_id);
                    END IF;
                END;

                /*Quantity Validation end*/

                /*Source locator validation start*/
                BEGIN
                    IF inv_transactions_rec.source_locator IS NOT NULL
                    THEN
                        BEGIN
                            SELECT inventory_location_id
                              INTO ln_source_locator_id
                              FROM mtl_item_locations_kfv
                             WHERE     organization_id = ln_org_id
                                   AND subinventory_code =
                                       inv_transactions_rec.source_subinventory
                                   AND concatenated_segments =
                                       inv_transactions_rec.source_locator
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                                   AND NVL (disable_date, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_source_locator_id   := NULL;
                                msg (
                                       'Error Ocuured While Validation Source Locator For Transaction Seq ID :'
                                    || inv_transactions_rec.transaction_seq_id
                                    || '-'
                                    || SQLERRM);
                        END;

                        IF ln_source_locator_id IS NULL
                        THEN
                            lv_error_flag   := 'Y';
                            lv_error_msg    :=
                                   lv_error_msg
                                || ' '
                                || 'Source Locator Failed For Transaction';
                        END IF;
                    END IF;
                END;

                /*Source locator validation start*/

                /*Destination locator validation start*/
                BEGIN
                    IF inv_transactions_rec.destination_locator IS NOT NULL
                    THEN
                        BEGIN
                            SELECT inventory_location_id
                              INTO ln_dest_locator_id
                              FROM mtl_item_locations_kfv
                             WHERE     organization_id = ln_org_id
                                   AND subinventory_code =
                                       inv_transactions_rec.dest_subinventory
                                   AND concatenated_segments =
                                       inv_transactions_rec.destination_locator
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                                   AND NVL (disable_date, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_dest_locator_id   := NULL;
                                msg (
                                       'Error Ocuured While Validation Destination Locator For Transaction Seq ID :'
                                    || inv_transactions_rec.transaction_seq_id
                                    || '-'
                                    || SQLERRM);
                        END;

                        IF ln_dest_locator_id IS NULL
                        THEN
                            lv_error_flag   := 'Y';
                            lv_error_msg    :=
                                   lv_error_msg
                                || ' '
                                || 'Destination Locator Failed For Transaction';
                        END IF;
                    END IF;
                END;

                /*Destination locator validation start*/

                /*Item validation start*/
                BEGIN
                    BEGIN
                        SELECT inventory_item_id, primary_uom_code
                          INTO ln_inventory_item_id, lv_primary_uom_code
                          FROM mtl_system_items_kfv
                         WHERE     organization_id = ln_org_id
                               AND concatenated_segments =
                                   inv_transactions_rec.item_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_inventory_item_id   := NULL;
                            lv_primary_uom_code    := NULL;
                            msg (
                                   'Error Ocuured While Validation Inventory Item For Transaction Seq ID :'
                                || inv_transactions_rec.transaction_seq_id
                                || '-'
                                || SQLERRM);
                    END;

                    IF ln_inventory_item_id IS NULL
                    THEN
                        lv_error_flag   := 'Y';
                        lv_error_msg    :=
                               lv_error_msg
                            || ' '
                            || 'Inventory Item Validation Failed For Transaction';
                    END IF;
                END;

                /*Item validation end */

                /*UOM validation start*/
                BEGIN
                    IF    lv_primary_uom_code <> inv_transactions_rec.uom
                       OR lv_primary_uom_code IS NULL
                    THEN
                        lv_error_flag   := 'Y';
                        lv_error_msg    :=
                               lv_error_msg
                            || ' '
                            || 'UOM Validation Failed For Transaction';
                        msg (
                               'UOM Validation Failed For Transaction Seq ID :'
                            || inv_transactions_rec.transaction_seq_id);
                    END IF;
                END;

                /*UOM validation end*/

                /*Accounting period validation start*/
                BEGIN
                    lv_period_open_flag   := 'N';

                    BEGIN
                        SELECT open_flag
                          INTO lv_period_open_flag
                          FROM org_acct_periods
                         WHERE     organization_id = ln_org_id
                               AND TRUNC (inv_transactions_rec.tran_date) BETWEEN period_start_date
                                                                              AND schedule_close_date;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_period_open_flag   := 'N';
                            msg (
                                   'Error Ocuured While Validation Inventory Accounting Period For Transaction Seq ID :'
                                || inv_transactions_rec.transaction_seq_id
                                || '-'
                                || SQLERRM);
                    END;

                    IF lv_period_open_flag = 'N'
                    THEN
                        lv_error_flag   := 'Y';
                        lv_error_msg    :=
                               lv_error_msg
                            || ' '
                            || 'Inventory Accoutning Period  Failed For Transaction';
                    END IF;
                END;

                /*Accounting period validation start*/

                /*Validate whether onhand is available in the source for negative transaction and sub inventory transfer start*/
                BEGIN
                    ln_atr_quantity   := 0;

                    IF    inv_transactions_rec.qty < 0
                       OR inv_transactions_rec.dest_subinventory IS NOT NULL
                    THEN            -- -ve adjustment or subinventory transfer
                        BEGIN
                            get_current_onhand (
                                pn_org_id         => ln_org_id,
                                pv_sub_inv_code   =>
                                    inv_transactions_rec.source_subinventory,
                                pn_locator_id     => ln_source_locator_id,
                                pn_inv_item_id    => ln_inventory_item_id,
                                pn_atr_quantity   => ln_atr_quantity);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_atr_quantity   := 0;
                        END;

                        IF ABS (inv_transactions_rec.qty) > ln_atr_quantity
                        THEN
                            lv_error_flag   := 'Y';
                            msg (
                                   'No Enough onhand for Inventory Adjustment or Host Transfer For Transaction Seq ID :'
                                || inv_transactions_rec.transaction_seq_id);
                            lv_error_msg    :=
                                   lv_error_msg
                                || ' '
                                || 'No Enough onhand for Inventory Adjustment or Host Transfer';
                        END IF;
                    END IF;
                END;

                /*Validate whether onhand is available in the source for negative transaction and sub inventory transfer end*/

                /* Account alias derivation start*/
                ln_trans_source_id    := NULL;
                ln_distr_account_id   := NULL;
                lv_account_alias      := NULL;

                IF inv_transactions_rec.dest_subinventory IS NULL
                THEN                                -- +ve and -ve adjustments
                    IF inv_transactions_rec.reason_code IS NULL
                    THEN
                        lv_error_flag   := 'Y';
                        msg (
                               'Invalid Reason Code For Transaction Seq ID :'
                            || inv_transactions_rec.transaction_seq_id);
                        lv_error_msg    :=
                            lv_error_msg || ' ' || 'Invalid Reason Code';
                    ELSE
                        BEGIN
                            /*  Brand needs to be considered for account alias derivation*/
                            SELECT mgd.disposition_id, mgd.distribution_account, mgd.segment1
                              INTO ln_trans_source_id, ln_distr_account_id, lv_account_alias
                              FROM mtl_generic_dispositions_dfv mgdd, mtl_generic_dispositions mgd, mtl_item_categories cat,
                                   mtl_categories_b mc, mtl_system_items_kfv msi
                             WHERE     cat.organization_id =
                                       msi.organization_id
                                   AND cat.inventory_item_id =
                                       msi.inventory_item_id
                                   AND cat.category_set_id = 1
                                   AND mc.category_id = cat.category_id
                                   AND mgdd.CONTEXT = '3PL'
                                   AND mgdd.row_id = mgd.ROWID
                                   AND mgdd.brand = mc.segment1
                                   AND mgd.organization_id =
                                       msi.organization_id
                                   AND msi.organization_id = ln_org_id
                                   AND msi.inventory_item_id =
                                       ln_inventory_item_id
                                   AND NVL (mgdd.adj_code, '-1') =
                                       NVL (inv_transactions_rec.reason_code,
                                            '-1')
                                   AND TRUNC (ld_server_tran_date) BETWEEN TRUNC (
                                                                               NVL (
                                                                                   mgd.effective_date,
                                                                                     SYSDATE
                                                                                   - 1))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   mgd.disable_date,
                                                                                     SYSDATE
                                                                                   + 1));
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_flag   := 'Y';
                                msg (
                                       'Error While Fetching Account Alias For Transaction Seq ID :'
                                    || inv_transactions_rec.transaction_seq_id);
                                lv_error_msg    :=
                                       lv_error_msg
                                    || ' '
                                    || 'Error While Fetching Account Alias';
                        END;
                    END IF;
                END IF;

                /* Account alias derivation end */
                -- Set the transaction type id, destination org id
                IF inv_transactions_rec.qty < 0              -- -ve adjustment
                THEN
                    ln_trans_type_id   := gn_issue_type_id;
                    ln_dest_org_id     := NULL; -- CCR CCR0009862 GJensen (For Issue NULL dest org)
                ELSIF inv_transactions_rec.dest_subinventory IS NOT NULL
                --sub inventory transfer
                THEN
                    ln_trans_type_id      := 2;
                    --- Standard Subinventory Transfer
                    ln_dest_org_id        := ln_org_id;
                    ln_trans_source_id    := NULL;
                    ln_distr_account_id   := NULL;
                ELSE                                           -- +ve transfer
                    ln_trans_type_id   := gn_receipt_type_id;
                    ln_dest_org_id     := NULL; -- CCR CCR0009862 GJensen (For Rcpt NULL dest org)
                END IF;
            END IF;

            /*If there are any validation errors update stagign table records to ERRRO status*/
            IF NVL (lv_error_flag, 'N') = 'Y'
            THEN
                BEGIN
                    UPDATE xxdo_inv_trans_adj_dtl_stg
                       SET process_status = 'ERROR', error_message = lv_error_msg, last_updated_by = gn_user_id,
                           last_update_date = SYSDATE
                     WHERE     transaction_seq_id =
                               inv_transactions_rec.transaction_seq_id
                           AND request_id = gn_request_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                            'Error While Updating Error Records :' || SQLERRM);
                END;
            ELSE
                /*If there are no validation errors insert records into interface table*/
                BEGIN
                    SELECT mtl_material_transactions_s.NEXTVAL
                      INTO ln_txn_intf_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'Error While Getting Transaction Interface ID :'
                            || SQLERRM);
                END;

                BEGIN
                    SELECT user_id
                      INTO ln_emp_user_id
                      FROM fnd_user
                     WHERE user_name = inv_transactions_rec.employee_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_emp_user_id   := gn_user_id;
                END;

                ------Start for CCR CCR0009862-----
                BEGIN
                    DELETE FROM
                        mtl_transactions_interface
                          WHERE     process_flag = '3'
                                AND source_code = 'WS'
                                AND inventory_item_id = ln_inventory_item_id
                                AND organization_id = ln_org_id
                                AND transaction_type_id = ln_trans_type_id
                                AND NVL (transfer_organization, -1) =
                                    NVL (ln_dest_org_id, -1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                ------End for CCR CCR0009862-----

                ln_success_records   := ln_success_records + 1;

                INSERT INTO mtl_transactions_interface (
                                transaction_interface_id,
                                transaction_header_id,
                                source_code,
                                source_header_id,
                                source_line_id,
                                process_flag,
                                transaction_mode,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                inventory_item_id,
                                organization_id,
                                transaction_quantity,
                                transaction_uom,
                                transaction_date,
                                subinventory_code,
                                locator_id,
                                transaction_type_id,
                                transfer_organization,
                                transfer_subinventory,
                                transfer_locator,
                                transaction_source_id,
                                distribution_account_id,
                                transaction_reference)
                         VALUES (
                                    ln_txn_intf_id,
                                    ln_txn_intf_id,
                                    'WS',
                                    inv_transactions_rec.transaction_seq_id,
                                    inv_transactions_rec.transaction_seq_id,
                                    1,
                                    3,
                                    SYSDATE,
                                    ln_emp_user_id,
                                    SYSDATE,
                                    ln_emp_user_id,
                                    ln_inventory_item_id,
                                    ln_org_id,
                                    inv_transactions_rec.qty,
                                    inv_transactions_rec.uom,
                                    DECODE (
                                        TO_CHAR (ld_server_tran_date,
                                                 'YYYYMM'),
                                        TO_CHAR (SYSDATE, 'YYYYMM'), ld_server_tran_date,
                                        SYSDATE),
                                    inv_transactions_rec.source_subinventory,
                                    ln_source_locator_id,
                                    ln_trans_type_id,
                                    ln_dest_org_id,
                                    inv_transactions_rec.dest_subinventory,
                                    ln_dest_locator_id,
                                    ln_trans_source_id,
                                    ln_distr_account_id,
                                    SUBSTRB (inv_transactions_rec.comments,
                                             1,
                                             240));

                COMMIT;
            END IF;
        END LOOP;

        IF ln_success_records > 0
        THEN
            pv_submit_prog   := 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in validate_and_insert_into_int procedure');
    END validate_and_insert_into_int;

    /*Procedure to submit cocnurrent program "Process transaction interface"*/
    PROCEDURE submit_program (pv_error_flag   OUT VARCHAR2,
                              pv_error_msg    OUT VARCHAR2)
    IS
        ln_interface_request_id   NUMBER;
        lb_concreqcallstat        BOOLEAN := FALSE;
        lv_phasecode              VARCHAR2 (100) := NULL;
        lv_statuscode             VARCHAR2 (100) := NULL;
        lv_devphase               VARCHAR2 (100) := NULL;
        lv_devstatus              VARCHAR2 (100) := NULL;
        lv_returnmsg              VARCHAR2 (200) := NULL;
        lv_error_msg              VARCHAR2 (4000);
    BEGIN
        fnd_global.apps_initialize (gn_user_id, 51835, 50002);
        ln_interface_request_id   :=
            --Submit concurrent program
             apps.fnd_request.submit_request (application   => 'INV',
                                              program       => 'INCTCM',
                                              description   => NULL,
                                              start_time    => SYSDATE,
                                              sub_request   => FALSE);
        COMMIT;

        IF ln_interface_request_id IS NOT NULL
        THEN
            msg (
                   'Concurrent Program Process transaction interface Submmitted. Request ID: '
                || ln_interface_request_id);

            LOOP
                --Wait for the concurrent program to complete
                lb_concreqcallstat   :=
                    apps.fnd_concurrent.wait_for_request (
                        ln_interface_request_id,
                        5,                 -- wait 5 seconds between db checks
                        0,
                        lv_phasecode,
                        lv_statuscode,
                        lv_devphase,
                        lv_devstatus,
                        lv_returnmsg);
                EXIT WHEN lv_devphase = 'COMPLETE';
            END LOOP;
        ELSE
            pv_error_flag   := 'Y';
            pv_error_msg    :=
                SUBSTR (
                       'Error while submitting requisition import. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (pv_error_msg);
        END IF;

        BEGIN
            --Update staging table with interface error records
            UPDATE xxdo_inv_trans_adj_dtl_stg stg
               SET stg.process_status   = 'ERROR',
                   error_message       =
                       (SELECT error_explanation
                          FROM mtl_transactions_interface
                         WHERE     source_header_id = stg.transaction_seq_id
                               AND process_flag = 3
                               AND ROWNUM = 1)
             WHERE     stg.request_id = gn_request_id
                   AND stg.process_status = 'INPROCESS'
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_transactions_interface
                             WHERE     source_header_id =
                                       stg.transaction_seq_id
                                   AND process_flag = 3);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Error while updating staging table with interface error records');
        END;

        BEGIN
            --Update staging table status to 'PROCESSED' for success records
            UPDATE xxdo_inv_trans_adj_dtl_stg stg
               SET stg.process_status   = 'PROCESSED'
             WHERE     stg.request_id = gn_request_id
                   AND stg.process_status = 'INPROCESS';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Error while updating staging table with success records');
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error in submit_program procedure');
    END submit_program;
END xxd_inv_reprocess_tran_adj_pkg;
/
