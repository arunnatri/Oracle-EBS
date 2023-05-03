--
-- XXDO_INV_TRANSFER_ADJ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_TRANSFER_ADJ_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_inv_transfer_adj_pkg_b.sql   1.0    2014/08/18    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_transfer_adj_pkg
    --
    -- Description  :  This is package for WMS to EBS Inventory transactions interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 18-Aug-14    Infosys            1.0       Created
    -- 31-Mar-15    Infosys            2.0       Modified not to consider the timestamp while checking open inventory
    --                                                      accounting period ; Identified by TRUNC_DT
    --16-Jul-15      Infosys           2.1       Added condition to nullify the varibales,delete record from interface in case of error
    --                                                   --Indentified by VARIABLE_DELETE
    --21-Jul-15      Infosys           2.2       Modified new parameter p_process_status identified by P_PROCESS_STATUS
    --Purge data should be in PROCESSED status , identified by PROCESSED
    --03-Sep-15    Infosys             2.3       Modified new parameter p_message_id identified by P_MESSAGE_ID
    --18-Sep-15     Infosys            2.4       Modified the code to avoid duplicate records reprocessing.
    --15-Sep-21     Techmahindra       2.5       Modified the code to clean the error record from MTI table for CCR#CCR0009543.
    --08-DEC-21     Showkath Ali       2.6       CCR0009689 -- Timezone issue for US6
    --14-Mar-22     Gaurav Joshi       2.7       CCR0009823  hj timezone issue for us6
    -- ***************************************************************************

    --- Global Variables ---

    g_chr_issue_type     VARCHAR2 (100) := 'Account alias issue';
    g_chr_receipt_type   VARCHAR2 (100) := 'Account alias receipt';
    g_pst_offset         NUMBER := 8;                                   -- 2.6

    --------------------------
    -- 2.6 changes start
    -- Function to get the Time Zone difference for Organization.
    FUNCTION get_offset_time (p_organization_code IN VARCHAR2)
        RETURN NUMBER
    IS
        l_timezone   VARCHAR2 (100);
        l_offset     NUMBER;
    BEGIN
        -- query to get timezone based on organization
        BEGIN
            SELECT hra.timezone_code
              INTO l_timezone
              FROM apps.hr_locations_all hra, apps.hr_organization_units hou
             WHERE     hou.location_id = hra.location_id
                   AND location_code LIKE '%' || p_organization_code || '%';

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Time Zone for the organization:'
                || p_organization_code
                || ' is:'
                || l_timezone);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_timezone   := NULL;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Failed to get Time Zone for the organization:'
                    || p_organization_code
                    || ' is:'
                    || l_timezone);
        END;

        -- query to get time deviation
        BEGIN
            --SELECT - (SUM (gmt_deviation_hours) / 24)
            SELECT -(g_pst_offset - SUM (gmt_deviation_hours)) / 24
              INTO l_offset
              FROM (SELECT -ht.gmt_deviation_hours AS gmt_deviation_hours
                      FROM apps.hz_timezones ht, apps.hz_timezones_tl htt
                     WHERE     htt.name = l_timezone
                           AND htt.language = 'US'
                           AND ht.timezone_id = htt.timezone_id);

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Time deviation for the organization:'
                || p_organization_code
                || ' is:'
                || l_offset);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_offset   := 0;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Failed to fetch Time deviation for the organization:'
                    || p_organization_code
                    || ' is:'
                    || l_offset);
        END;

        RETURN NVL (l_offset, 0);
    END;

    -- 2.6 changes end



    -- ***************************************************************************
    -- Procedure/Function Name  :  Purge
    --
    -- Description              :  The purpose of this procedure is to purge the old ASN receipt records
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_num_purge_days  IN : Purge days
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- ***************************************************************************

    PROCEDURE purge (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_in_num_purge_days || ' days old records...');

        BEGIN
            INSERT INTO xxdo_inv_trans_adj_dtl_log (wh_id,
                                                    source_subinventory,
                                                    dest_subinventory,
                                                    source_locator,
                                                    destination_locator,
                                                    tran_date,
                                                    item_number,
                                                    qty,
                                                    uom,
                                                    employee_id,
                                                    employee_name,
                                                    reason_code,
                                                    comments,
                                                    organization_id,
                                                    inventory_item_id,
                                                    source_locator_id,
                                                    destination_locator_id,
                                                    transaction_seq_id,
                                                    process_status,
                                                    error_message,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    source_type,
                                                    attribute1,
                                                    attribute2,
                                                    attribute3,
                                                    attribute4,
                                                    attribute5,
                                                    attribute6,
                                                    attribute7,
                                                    attribute8,
                                                    attribute9,
                                                    attribute10,
                                                    attribute11,
                                                    attribute12,
                                                    attribute13,
                                                    attribute14,
                                                    attribute15,
                                                    attribute16,
                                                    attribute17,
                                                    attribute18,
                                                    attribute19,
                                                    attribute20,
                                                    source,
                                                    destination,
                                                    record_type,
                                                    interface_transaction_id,
                                                    session_id,
                                                    server_tran_date,
                                                    archive_date,
                                                    archive_request_id)
                SELECT wh_id, source_subinventory, dest_subinventory,
                       source_locator, destination_locator, tran_date,
                       item_number, qty, uom,
                       employee_id, employee_name, reason_code,
                       comments, organization_id, inventory_item_id,
                       source_locator_id, destination_locator_id, transaction_seq_id,
                       process_status, error_message, request_id,
                       creation_date, created_by, last_update_date,
                       last_updated_by, source_type, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, source, destination,
                       record_type, interface_transaction_id, session_id,
                       server_tran_date, SYSDATE, g_num_request_id
                  FROM xxdo_inv_trans_adj_dtl_stg
                 WHERE     creation_date <
                           l_dte_sysdate - p_in_num_purge_days
                       AND process_status = 'PROCESSED';           --PROCESSED

            DELETE FROM
                xxdo_inv_trans_adj_dtl_stg
                  WHERE     creation_date <
                            l_dte_sysdate - p_in_num_purge_days
                        AND process_status = 'PROCESSED';          --PROCESSED
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving Inventory transactions data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving AInventory transactions data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_inv_trans_adj_ser_log (wh_id, source_subinventory, dest_subinventory, source_locator, destination_locator, item_number, serial_number, organization_id, inventory_item_id, source_locator_id, destination_locator_id, transaction_seq_id, serial_seq_id, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, source, destination, record_type, archive_date
                                                    , archive_request_id)
                SELECT wh_id, source_subinventory, dest_subinventory,
                       source_locator, destination_locator, item_number,
                       serial_number, organization_id, inventory_item_id,
                       source_locator_id, destination_locator_id, transaction_seq_id,
                       serial_seq_id, process_status, error_message,
                       request_id, creation_date, created_by,
                       last_update_date, last_updated_by, source_type,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, source,
                       destination, record_type, SYSDATE,
                       g_num_request_id
                  FROM xxdo_inv_trans_adj_ser_stg
                 WHERE     creation_date <
                           l_dte_sysdate - p_in_num_purge_days
                       AND process_status = 'PROCESSED';           --PROCESSED

            DELETE FROM
                xxdo_inv_trans_adj_ser_stg
                  WHERE     creation_date <
                            l_dte_sysdate - p_in_num_purge_days
                        AND process_status = 'PROCESSED';          --PROCESSED
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving Serials data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving Serails data: '
                    || SQLERRM);
        END;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    := SQLERRM;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END purge;


    -- ***************************************************************************
    -- Procedure/Function Name  :  lock_records
    --
    -- Description              :  The purpose of this procedure is to lock the records before validating and processing the inventory transactions
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_num_trans_seq_id IN : Transaction Sequence id
    --                                  p_out_num_record_count  OUT: updated records count
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/04    Infosys            1.0   Initial Version
    -- ***************************************************************************

    PROCEDURE lock_records (
        p_out_chr_errbuf            OUT VARCHAR2,
        p_out_chr_retcode           OUT VARCHAR2,
        p_in_num_trans_seq_id    IN     NUMBER,
        p_out_num_record_count      OUT NUMBER,
        p_process_status         IN     VARCHAR2 DEFAULT 'NEW') ---P_PROCESS_STATUS
    IS
    BEGIN
        p_out_chr_errbuf         := NULL;
        p_out_chr_retcode        := '0';



        UPDATE xxdo_inv_trans_adj_dtl_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, session_id = USERENV ('SESSIONID'),
               last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status IN ('NEW', p_process_status) ---P_PROCESS_STATUS
               AND transaction_seq_id =
                   NVL (p_in_num_trans_seq_id, transaction_seq_id);

        p_out_num_record_count   := SQL%ROWCOUNT;

        UPDATE xxdo_inv_trans_adj_ser_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, session_id = USERENV ('SESSIONID'),
               last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status IN ('NEW', p_process_status) ---P_PROCESS_STATUS
               AND transaction_seq_id =
                   NVL (p_in_num_trans_seq_id, transaction_seq_id);

        /***********************************************************************/
        /*Infosys Ver 2.5: Identify and mark duplicate records; Should not     */
        /*                   allow for further process.                        */
        /***********************************************************************/
        UPDATE apps.XXDO_INV_TRANS_ADJ_DTL_STG xita
           SET process_status = 'DUPLICATE', error_message = 'Record already exists for message ID ' || xita.attribute1, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'INPROCESS'
               AND request_id = g_num_request_id
               AND EXISTS
                       (SELECT *
                          FROM apps.XXDO_INV_TRANS_ADJ_DTL_STG xita2
                         WHERE     1 = 1
                               AND xita2.process_status ! = 'DUPLICATE'
                               AND xita2.item_number = xita.item_number
                               AND xita2.attribute1 = xita.attribute1
                               AND xita2.transaction_seq_id !=
                                   xita.transaction_seq_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'ERROR in lock records procedure : ' || p_out_chr_errbuf);
    END lock_records;

    -- ***************************************************************************
    -- Procedure/Function Name  :  main
    --
    -- Description              :  This is the driver procedure which processes the inventory transactions
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                p_in_chr_process_mode IN : Process Mode - Online or Batch
    --                                p_in_chr_warehouse    IN : Warehouse code
    --                                p_in_chr_from_subinv  IN : Source Subinventory
    --                                p_in_chr_from_locator IN : Source Locator
    --                                p_in_chr_to_subinv    IN : Destination Subinventory
    --                                p_in_chr_to_locator   IN : Destination Locator
    --                                p_in_chr_item         IN : Item Number
    --                                p_in_num_qty          IN : Transaction quantity
    --                                p_in_chr_uom          IN : Primary UOM
    --                                p_in_dte_trans_date   IN : Transation Date (Local time zone)
    --                                p_in_chr_reason_code  IN : Reason code
    --                                p_in_chr_comments     IN : Comments
    --                                p_in_chr_employee_id  IN : Employee id / User name
    --                                p_in_chr_employee_name IN : Employee name
    --                                p_in_num_trans_seq_id IN : Transaction sequence ID
    --                                p_in_num_purge_days   IN : Purge days
    ----
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/04    Infosys            1.0      Initial Version
    -- 2015/01/07    Infosys            2.0       Modified for BT Remediation
    -- ***************************************************************************

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_process_mode IN VARCHAR2, p_in_chr_warehouse IN VARCHAR2, p_in_chr_from_subinv IN VARCHAR2, p_in_chr_from_locator IN VARCHAR2, p_in_chr_to_subinv IN VARCHAR2, p_in_chr_to_locator IN VARCHAR2, p_in_chr_item IN VARCHAR2, p_in_num_qty IN NUMBER, p_in_chr_uom IN VARCHAR2, p_in_dte_trans_date IN DATE, p_in_chr_reason_code IN VARCHAR2, p_in_chr_comments IN VARCHAR2, p_in_chr_employee_id IN VARCHAR2, p_in_chr_employee_name IN VARCHAR2, p_in_num_trans_seq_id IN NUMBER, --                                p_in_serials_tab   IN g_inv_trans_adj_ser_tab_type,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_in_serials_tab IN inv_trans_adj_ser_obj_tab_type
                    , p_in_num_purge_days IN NUMBER, p_process_status IN VARCHAR2 DEFAULT 'NEW', ---P_PROCESS_STATUS
                                                                                                 p_in_message_id IN VARCHAR2 DEFAULT -1) --P_MESSAGE_ID
    IS
        l_chr_errbuf                   VARCHAR2 (4000);
        l_chr_retcode                  VARCHAR2 (30);
        l_num_organization_id          NUMBER;
        l_num_source_locator_id        NUMBER;
        l_num_dest_locator_id          NUMBER;
        l_chr_primary_uom_code         VARCHAR2 (30);
        l_num_inventory_item_id        NUMBER;
        l_chr_period_open_flag         VARCHAR2 (1);
        l_num_atr_quantity             NUMBER;
        l_num_record_count             NUMBER;
        l_num_txn_intf_id              NUMBER;
        l_num_return                   NUMBER;
        l_dup_count                    NUMBER;      /*Ver2.5: Added variable*/
        l_chr_return_status            VARCHAR2 (1);
        l_num_msg_count                NUMBER;
        l_chr_msg_data                 VARCHAR2 (32500);
        l_num_issue_type_id            NUMBER;
        l_num_receipt_type_id          NUMBER;
        l_num_trans_type_id            NUMBER;
        l_num_dest_org_id              NUMBER;
        l_chr_error_message            VARCHAR2 (4000);
        l_num_trans_count              NUMBER;
        l_num_trans_source_id          NUMBER;
        l_num_distr_account_id         NUMBER;
        l_num_subinv_valid             NUMBER;
        l_num_emp_user_id              NUMBER;
        l_dte_server_tran_date         DATE;
        l_chr_serial_control_flag      VARCHAR2 (1);
        l_num_serials_count            NUMBER;
        l_chr_account_alias            VARCHAR2 (40);


        l_trans_dtl_rec                xxdo_inv_trans_adj_dtl_stg%ROWTYPE;
        l_sub_inventories_tab          g_ids_var_tab_type;
        l_inv_org_attr_tab             g_inv_org_attr_tab_type;
        --    p_in_serials_tab   g_inv_trans_adj_ser_tab_type := p_in_serials_tab;

        l_exe_no_issue_trans_type      EXCEPTION;
        l_exe_no_receipt_trans_type    EXCEPTION;
        l_exe_warehouse_err            EXCEPTION;
        l_exe_src_subinv_err           EXCEPTION;
        l_exe_dest_subinv_err          EXCEPTION;
        l_exe_invalid_tran_date        EXCEPTION;
        l_exe_zero_trans_qty           EXCEPTION;
        l_exe_invalid_item             EXCEPTION;
        l_exe_src_locator_err          EXCEPTION;
        l_exe_dest_locator_err         EXCEPTION;
        l_exe_invalid_uom              EXCEPTION;
        l_exe_period_not_open          EXCEPTION;
        l_exe_no_onhand                EXCEPTION;
        l_exe_lock_err                 EXCEPTION;
        l_exe_seq                      EXCEPTION;
        l_exe_invalid_reason           EXCEPTION;
        l_exe_serials_not_exists       EXCEPTION;
        l_exe_serials_count_mismatch   EXCEPTION;
        l_exe_serials_exists           EXCEPTION;
        l_exe_record_exists            EXCEPTION;   /*Ver2.5: Added variable*/


        CURSOR cur_inv_transactions IS
            SELECT wh_id, source_subinventory, dest_subinventory,
                   source_locator, destination_locator, tran_date,
                   item_number, qty, uom,
                   employee_id, employee_name, reason_code,
                   comments, transaction_seq_id, attribute1 message_id
              FROM xxdo_inv_trans_adj_dtl_stg dtl
             WHERE     dtl.process_status = 'INPROCESS'
                   AND dtl.request_id = g_num_request_id
                   AND session_id = USERENV ('SESSIONID')
                   AND p_in_chr_process_mode = 'BATCH'
            UNION ALL
            SELECT p_in_chr_warehouse wh_id, p_in_chr_from_subinv source_subinventory, p_in_chr_to_subinv dest_subinventory,
                   p_in_chr_from_locator source_locator, p_in_chr_to_locator destination_locator, p_in_dte_trans_date tran_date,
                   p_in_chr_item item_number, p_in_num_qty qty, p_in_chr_uom uom,
                   p_in_chr_employee_id employee_id, p_in_chr_employee_name employee_name, p_in_chr_reason_code reason_code,
                   p_in_chr_comments comments, NULL transaction_seq_id, p_in_message_id message_id
              FROM DUAL
             WHERE p_in_chr_process_mode = 'ONLINE'
            ORDER BY 6;

        CURSOR cur_inv_arg_attributes (p_chr_warehouse IN VARCHAR2)
        IS
            SELECT flv.lookup_code organization_code, mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.lookup_code
                   AND flv.lookup_code =
                       NVL (p_chr_warehouse, flv.lookup_code);


        CURSOR cur_sub_inventories (p_num_organization_id IN NUMBER)
        IS
            SELECT secondary_inventory_name subinventory
              FROM mtl_secondary_inventories
             WHERE organization_id = p_num_organization_id;

        l_offset_time                  NUMBER := 0;                      --2.6
        l_chr_organization             VARCHAR2 (20);                   -- 2.6
        l_organization_code            VARCHAR2 (30);                   -- 2.7
        l_sysdate                      DATE;                            -- 2.7
    BEGIN
        p_out_chr_errbuf        := NULL;
        p_out_chr_retcode       := '0';

        l_num_issue_type_id     := 31;                  -- Account alias issue
        l_num_receipt_type_id   := 41;                 --Account alias receipt

        /*
                BEGIN
                    SELECT transaction_type_id
                        INTO l_num_issue_type_id
                      FROM  mtl_transaction_types
                    WHERE transaction_type_name = g_chr_issue_type;
                EXCEPTION
                     WHEN OTHERS THEN
                            RAISE l_exe_no_issue_trans_type;
                END;



                BEGIN
                    SELECT transaction_type_id
                        INTO l_num_receipt_type_id
                      FROM  mtl_transaction_types
                    WHERE transaction_type_name = g_chr_receipt_type;
                EXCEPTION
                     WHEN OTHERS THEN
                            RAISE l_exe_no_receipt_trans_type;
                END;
        */
        -- Lock the records by updating the status to INPROCESS and request id to current request id
        IF p_in_chr_process_mode = 'BATCH'
        THEN
            BEGIN
                lock_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_num_trans_seq_id    => p_in_num_trans_seq_id,
                    p_out_num_record_count   => l_num_record_count,
                    p_process_status         => p_process_status); ---P_PROCESS_STATUS

                IF l_chr_retcode <> '0'
                THEN
                    p_out_chr_errbuf   :=
                           'Error in lock records procedure in Batch mode : '
                        || l_chr_errbuf;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, p_out_chr_errbuf);
                    RAISE l_exe_lock_err;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf   :=
                           'Unexpected error while invoking lock records procedure in Batch mode : '
                        || SQLERRM;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, p_out_chr_errbuf);
                    RAISE l_exe_lock_err;
            END;
        ELSE
            l_num_record_count   := 1;
        END IF;

        IF NVL (l_num_record_count, 0) = 0
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'There are no eligible Inventory transactions data in the staging table');
        ELSE
            IF p_in_chr_process_mode = 'BATCH'
            THEN
                --Get WMS warehouse details
                FOR inv_arg_attributes_rec IN cur_inv_arg_attributes (NULL)
                LOOP
                    l_inv_org_attr_tab (
                        inv_arg_attributes_rec.organization_code).organization_id   :=
                        inv_arg_attributes_rec.organization_id;
                    l_inv_org_attr_tab (
                        inv_arg_attributes_rec.organization_code).warehouse_code   :=
                        inv_arg_attributes_rec.organization_code;

                    FOR sub_inventories_rec
                        IN cur_sub_inventories (
                               inv_arg_attributes_rec.organization_id)
                    LOOP
                        l_sub_inventories_tab (
                               inv_arg_attributes_rec.organization_code
                            || '|'
                            || sub_inventories_rec.subinventory)   :=
                            inv_arg_attributes_rec.organization_id;
                    END LOOP;
                END LOOP;
            END IF;

            FOR inv_transactions_rec IN cur_inv_transactions
            LOOP
                BEGIN
                    l_num_organization_id                      := NULL;
                    l_num_source_locator_id                    := NULL;
                    l_num_dest_locator_id                      := NULL;
                    l_num_inventory_item_id                    := NULL;
                    l_chr_primary_uom_code                     := NULL;
                    l_num_dest_org_id                          := NULL;
                    l_num_txn_intf_id                          := NULL;
                    l_num_trans_source_id                      := NULL;
                    l_num_distr_account_id                     := NULL;
                    l_dte_server_tran_date                     := NULL;


                    l_trans_dtl_rec                            := NULL; /* 07/16/15 initialize the record   VARIABLE_DELETE*/
                    l_trans_dtl_rec.wh_id                      := inv_transactions_rec.wh_id;
                    l_trans_dtl_rec.source_subinventory        :=
                        inv_transactions_rec.source_subinventory;
                    l_trans_dtl_rec.dest_subinventory          :=
                        inv_transactions_rec.dest_subinventory;
                    l_trans_dtl_rec.source_locator             :=
                        inv_transactions_rec.source_locator;
                    l_trans_dtl_rec.destination_locator        :=
                        inv_transactions_rec.destination_locator;
                    l_trans_dtl_rec.tran_date                  :=
                        inv_transactions_rec.tran_date;
                    l_trans_dtl_rec.item_number                :=
                        inv_transactions_rec.item_number;
                    l_trans_dtl_rec.qty                        :=
                        inv_transactions_rec.qty;
                    l_trans_dtl_rec.uom                        :=
                        inv_transactions_rec.uom;
                    l_trans_dtl_rec.employee_id                :=
                        inv_transactions_rec.employee_id;
                    l_trans_dtl_rec.employee_name              :=
                        inv_transactions_rec.employee_name;
                    l_trans_dtl_rec.reason_code                :=
                        inv_transactions_rec.reason_code;
                    l_trans_dtl_rec.comments                   :=
                        inv_transactions_rec.comments;
                    l_trans_dtl_rec.transaction_seq_id         :=
                        inv_transactions_rec.transaction_seq_id;
                    l_trans_dtl_rec.attribute1                 := p_in_message_id; --P_MESSAGE_ID


                    -- Derive the user id
                    BEGIN
                        SELECT user_id
                          INTO l_num_emp_user_id
                          FROM fnd_user
                         WHERE user_name = l_trans_dtl_rec.employee_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_emp_user_id   := g_num_user_id;
                    END;

                    l_trans_dtl_rec.created_by                 :=
                        l_num_emp_user_id;
                    l_trans_dtl_rec.last_updated_by            :=
                        l_num_emp_user_id;



                    -- validations based on the pl/sql table
                    IF p_in_chr_process_mode = 'BATCH'
                    THEN
                        -- Validate whether inventory org is WMS enabled for current ASN receipt header - appointment
                        BEGIN
                            l_num_organization_id   :=
                                l_inv_org_attr_tab (
                                    inv_transactions_rec.wh_id).organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_num_organization_id   := NULL;
                        END;

                        --                   FND_FILE.PUT_LINE (FND_FILE.LOG, 'Validating whether '|| inv_transactions_rec.wh_id||' is WMS warehouse' );
                        IF l_num_organization_id IS NULL
                        THEN
                            RAISE l_exe_warehouse_err;
                        END IF;

                        l_trans_dtl_rec.organization_id   :=
                            l_num_organization_id;

                        -- Validate whether source subinventory is valid
                        IF inv_transactions_rec.source_subinventory IS NULL
                        THEN
                            RAISE l_exe_src_subinv_err;
                        ELSIF NOT l_sub_inventories_tab.EXISTS (
                                         inv_transactions_rec.wh_id
                                      || '|'
                                      || inv_transactions_rec.source_subinventory)
                        THEN
                            RAISE l_exe_src_subinv_err;
                        END IF;

                        -- Validate whether destination subinventory is valid

                        IF inv_transactions_rec.dest_subinventory IS NOT NULL
                        THEN
                            IF NOT l_sub_inventories_tab.EXISTS (
                                          inv_transactions_rec.wh_id
                                       || '|'
                                       || inv_transactions_rec.dest_subinventory)
                            THEN
                                RAISE l_exe_dest_subinv_err;
                            END IF;
                        END IF;
                    ELSE                                        -- Online mode
                        BEGIN
                            SELECT mp.organization_id
                              INTO l_num_organization_id
                              FROM fnd_lookup_values flv, mtl_parameters mp
                             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                                       USERENV ('LANG')
                                   AND flv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                                   AND mp.organization_code = flv.lookup_code
                                   AND flv.lookup_code = p_in_chr_warehouse;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_num_organization_id   := NULL;
                        END;

                        IF l_num_organization_id IS NULL
                        THEN
                            RAISE l_exe_warehouse_err;
                        END IF;

                        l_trans_dtl_rec.organization_id   :=
                            l_num_organization_id;

                        -- Validate whether source subinventory is valid
                        IF inv_transactions_rec.source_subinventory IS NULL
                        THEN
                            RAISE l_exe_src_subinv_err;
                        ELSE
                            l_num_subinv_valid   := 0;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_num_subinv_valid
                                  FROM mtl_secondary_inventories
                                 WHERE     organization_id =
                                           l_num_organization_id
                                       AND secondary_inventory_name =
                                           inv_transactions_rec.source_subinventory;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_subinv_valid   := 0;
                            END;

                            IF l_num_subinv_valid = 0
                            THEN
                                RAISE l_exe_src_subinv_err;
                            END IF;
                        END IF;

                        -- Validate whether destination subinventory is valid

                        IF inv_transactions_rec.dest_subinventory IS NOT NULL
                        THEN
                            l_num_subinv_valid   := 0;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_num_subinv_valid
                                  FROM mtl_secondary_inventories
                                 WHERE     organization_id =
                                           l_num_organization_id
                                       AND secondary_inventory_name =
                                           inv_transactions_rec.dest_subinventory;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_subinv_valid   := 0;
                            END;

                            IF l_num_subinv_valid = 0
                            THEN
                                RAISE l_exe_dest_subinv_err;
                            END IF;
                        END IF;
                    END IF;

                    /***********************************************************************/
                    /*Infosys Ver 2.5: Identify and mark duplicate records; Should not     */
                    /*                   allow for further process.                        */
                    /***********************************************************************/
                    IF p_in_chr_process_mode = 'ONLINE'
                    THEN
                        BEGIN
                            l_dup_count   := 0;

                            SELECT COUNT (1)
                              INTO l_dup_count
                              FROM apps.XXDO_INV_TRANS_ADJ_DTL_STG xita
                             WHERE     xita.attribute1 =
                                       inv_transactions_rec.message_id
                                   AND xita.item_number =
                                       inv_transactions_rec.item_number;

                            IF l_dup_count > 0
                            THEN
                                RAISE l_exe_record_exists;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                RAISE l_exe_record_exists;
                        END;
                    END IF;


                    -- Validate whether the transaction date is null or future date
                    IF inv_transactions_rec.tran_date IS NULL
                    THEN
                        RAISE l_exe_invalid_tran_date;
                    ELSE
                        l_dte_server_tran_date   :=
                            get_server_timezone (
                                inv_transactions_rec.tran_date,
                                l_num_organization_id);

                        l_trans_dtl_rec.server_tran_date   :=
                            l_dte_server_tran_date;
                        -- ver 2.7 Begin -- US6 server is in eastcoast(pacific time), so elevate the sysdate accordiangly to eastern time i.e sysdate+0.125. 0.125(3/24) is the offset to added to convert pacitic time to eastern time
                        -- when transaction are for Us6 , they are in eastern format and thats the reason we are elevating the sysdate to eastern format
                        FND_FILE.PUT_LINE (FND_FILE.LOG,
                                           'before getting org code');

                        BEGIN
                            SELECT organization_code
                              INTO l_organization_code
                              FROM mtl_parameters
                             WHERE organization_id = l_num_organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_organization_code   := NULL;
                        END;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'after getting org code' || l_organization_code);

                        IF l_organization_code = 'US6'
                        THEN
                            l_sysdate   := SYSDATE + 0.125;
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   'for US6 : sysdate(pacific) equivalent in Eastern  is: '
                                || (SYSDATE + 0.125)
                                || ' and the Transaction time in Pacific time is: '
                                || l_dte_server_tran_date);
                        ELSE
                            l_sysdate   := SYSDATE;
                        END IF;

                        IF NVL (l_dte_server_tran_date, SYSDATE + 1) >
                           l_sysdate
                        THEN
                            RAISE l_exe_invalid_tran_date;
                        END IF;
                    -- ver 2.7 End
                    END IF;



                    -- Validate whether the transaction qty is zero
                    IF inv_transactions_rec.qty = 0
                    THEN
                        RAISE l_exe_zero_trans_qty;
                    END IF;

                    --Validate whether source locator is valid
                    IF inv_transactions_rec.source_locator IS NOT NULL
                    THEN
                        BEGIN
                            SELECT inventory_location_id
                              INTO l_num_source_locator_id
                              FROM mtl_item_locations_kfv
                             WHERE     organization_id =
                                       l_num_organization_id
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
                                l_num_source_locator_id   := NULL;
                        END;

                        IF l_num_source_locator_id IS NULL
                        THEN
                            RAISE l_exe_src_locator_err;
                        END IF;
                    END IF;

                    l_trans_dtl_rec.source_locator_id          :=
                        l_num_source_locator_id;


                    --Validate whether destination locator is valid
                    IF inv_transactions_rec.destination_locator IS NOT NULL
                    THEN
                        BEGIN
                            SELECT inventory_location_id
                              INTO l_num_dest_locator_id
                              FROM mtl_item_locations_kfv
                             WHERE     organization_id =
                                       l_num_organization_id
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
                                l_num_dest_locator_id   := NULL;
                        END;

                        IF l_num_dest_locator_id IS NULL
                        THEN
                            RAISE l_exe_dest_locator_err;
                        END IF;
                    END IF;

                    l_trans_dtl_rec.destination_locator_id     :=
                        l_num_dest_locator_id;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Item Number: ' || inv_transactions_rec.item_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'WH Id: ' || inv_transactions_rec.wh_id);

                    -- Validate whether the item is valid
                    BEGIN
                        SELECT inventory_item_id, primary_uom_code
                          INTO l_num_inventory_item_id, l_chr_primary_uom_code
                          FROM mtl_system_items_kfv -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                         WHERE     organization_id = l_num_organization_id
                               AND concatenated_segments =
                                   inv_transactions_rec.item_number; -- Modified for BT Remediation
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_inventory_item_id   := NULL;
                            l_chr_primary_uom_code    := NULL;
                    END;

                    IF l_num_inventory_item_id IS NULL
                    THEN
                        RAISE l_exe_invalid_item;
                    END IF;

                    l_trans_dtl_rec.inventory_item_id          :=
                        l_num_inventory_item_id;


                    -- Validate whether the UOM is primary UOM
                    IF l_chr_primary_uom_code <> inv_transactions_rec.uom
                    THEN
                        RAISE l_exe_invalid_uom;
                    END IF;


                    -- Validate whether inventory accounting period is open

                    l_chr_period_open_flag                     := 'N';

                    BEGIN
                        SELECT open_flag
                          INTO l_chr_period_open_flag
                          FROM org_acct_periods
                         WHERE     organization_id = l_num_organization_id
                               -- AND inv_transactions_rec.tran_date BETWEEN period_start_date AND schedule_close_date;   /* TRUNC_DT */
                               AND TRUNC (inv_transactions_rec.tran_date) BETWEEN period_start_date
                                                                              AND schedule_close_date;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_period_open_flag   := 'N';
                    END;

                    IF l_chr_period_open_flag = 'N'
                    THEN
                        RAISE l_exe_period_not_open;
                    END IF;


                    -- Validate whether onhand is available in the source for negative transaction and sub inventory transfer
                    l_num_atr_quantity                         := 0;

                    IF    inv_transactions_rec.qty < 0
                       OR inv_transactions_rec.dest_subinventory IS NOT NULL
                    THEN            -- -ve adjustment or subinventory transfer
                        BEGIN
                            get_current_onhand (
                                p_in_num_org_id          => l_num_organization_id,
                                p_in_chr_sub_inv_code    =>
                                    inv_transactions_rec.source_subinventory,
                                p_in_num_locator_id      =>
                                    l_num_source_locator_id,
                                p_in_num_inv_item_id     =>
                                    l_num_inventory_item_id,
                                p_out_num_atr_quantity   => l_num_atr_quantity);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_num_atr_quantity   := 0;
                        END;

                        IF ABS (inv_transactions_rec.qty) >
                           l_num_atr_quantity
                        THEN
                            RAISE l_exe_no_onhand;
                        END IF;
                    END IF;

                    l_num_trans_source_id                      := NULL;
                    l_num_distr_account_id                     := NULL;
                    l_chr_account_alias                        := NULL;

                    IF inv_transactions_rec.dest_subinventory IS NULL
                    THEN                            -- +ve and -ve adjustments
                        IF inv_transactions_rec.reason_code IS NULL
                        THEN
                            RAISE l_exe_invalid_reason;
                        ELSE
                            BEGIN
                                /*  Brand needs to be considered for account alias derivation
                                  SELECT disposition_id,
                                             distribution_account
                                     INTO l_num_trans_source_id,
                                             l_num_distr_account_id
                                    FROM mtl_generic_dispositions
                                  WHERE segment1 =  inv_transactions_rec.reason_code
                                      AND organization_id = l_num_organization_id;
                                */
                                SELECT mgd.disposition_id, mgd.distribution_account, mgd.segment1
                                  INTO l_num_trans_source_id, l_num_distr_account_id, l_chr_account_alias
                                  FROM mtl_generic_dispositions_dfv mgdd, mtl_generic_dispositions mgd, mtl_item_categories cat,
                                       mtl_categories_b mc, mtl_system_items_kfv msi -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                                 WHERE     cat.organization_id =
                                           msi.organization_id
                                       AND cat.inventory_item_id =
                                           msi.inventory_item_id
                                       AND cat.category_set_id = 1
                                       AND mc.category_id = cat.category_id
                                       AND mgdd.context = '3PL'
                                       AND mgdd.row_id = mgd.ROWID
                                       AND mgdd.brand = mc.segment1
                                       AND mgd.organization_id =
                                           msi.organization_id
                                       AND msi.organization_id =
                                           l_num_organization_id
                                       AND msi.inventory_item_id =
                                           l_num_inventory_item_id
                                       AND NVL (mgdd.adj_code, '-1') =
                                           NVL (
                                               inv_transactions_rec.reason_code,
                                               '-1')
                                       AND TRUNC (l_dte_server_tran_date) BETWEEN TRUNC (
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
                                    RAISE l_exe_invalid_reason;
                            END;
                        END IF;
                    END IF;

                    l_trans_dtl_rec.account_alias              :=
                        l_chr_account_alias;

                    l_chr_serial_control_flag                  := 'N';

                    BEGIN
                        l_chr_serial_control_flag   :=
                            xxdo_iid_to_serial (l_num_inventory_item_id,
                                                l_num_organization_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_serial_control_flag   := 'N';
                    END;

                    -- QR Code Validation
                    IF NVL (l_chr_serial_control_flag, 'N') = 'Y'
                    THEN                       -- If item is serial controlled
                        IF p_in_chr_process_mode = 'ONLINE'
                        THEN -- If the process mode is online, get the count from table parameter
                            -- Serials count
                            BEGIN
                                l_num_serials_count   :=
                                    p_in_serials_tab.COUNT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    RAISE l_exe_serials_not_exists;
                            END;
                        ELSE -- If the process mode is batch - the serials are already present in the staging table and locked
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_num_serials_count
                                  FROM xxdo_inv_trans_adj_ser_stg
                                 WHERE     transaction_seq_id =
                                           inv_transactions_rec.transaction_seq_id
                                       AND session_id = USERENV ('SESSIONID')
                                       AND process_status = 'INPROCESS';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_serials_count   := 0;
                            END;
                        END IF;

                        IF l_num_serials_count = 0
                        THEN
                            RAISE l_exe_serials_not_exists;
                        ELSIF l_num_serials_count <>
                              ABS (inv_transactions_rec.qty)
                        THEN
                            RAISE l_exe_serials_count_mismatch;
                        END IF;
                    ELSE                      -- Item is not serial controlled
                        IF p_in_chr_process_mode = 'ONLINE'
                        THEN -- If the process mode is online, get the count from table parameter
                            -- Serials count
                            BEGIN
                                l_num_serials_count   :=
                                    p_in_serials_tab.COUNT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_serials_count   := 0;
                            END;
                        ELSE -- If the process mode is batch - the serials are already present in the staging table and locked
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_num_serials_count
                                  FROM xxdo_inv_trans_adj_ser_stg
                                 WHERE     transaction_seq_id =
                                           inv_transactions_rec.transaction_seq_id
                                       AND session_id = USERENV ('SESSIONID')
                                       AND process_status = 'INPROCESS';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_serials_count   := 0;
                            END;
                        END IF;

                        IF l_num_serials_count <> 0
                        THEN
                            RAISE l_exe_serials_exists;
                        END IF;
                    END IF;



                    -- Set the transaction type id, destination org id

                    IF inv_transactions_rec.qty < 0
                    THEN                                     -- -ve adjustment
                        l_num_trans_type_id   := l_num_issue_type_id;
                    ELSIF inv_transactions_rec.dest_subinventory IS NOT NULL
                    THEN                              --sub inventory transfer
                        l_num_trans_type_id      := 2; --- Standard Subinventory Transfer
                        l_num_dest_org_id        := l_num_organization_id;
                        l_num_trans_source_id    := NULL;
                        l_num_distr_account_id   := NULL;
                    ELSE                                       -- +ve transfer
                        l_num_trans_type_id   := l_num_receipt_type_id;
                    END IF;

                    ------Start for CCR CCR0009543-----
                    BEGIN
                        DELETE FROM
                            mtl_transactions_interface
                              WHERE     process_flag = '3'
                                    AND source_code = 'WS'
                                    AND inventory_item_id =
                                        l_num_inventory_item_id
                                    AND organization_id =
                                        l_num_organization_id
                                    AND transaction_type_id =
                                        l_num_trans_type_id
                                    AND transfer_organization =
                                        l_num_dest_org_id;
                    END;

                    ------End for CCR CCR0009543-----

                    --- Insert into interface table
                    --Resolve interface row id from sequence
                    BEGIN
                        SELECT mtl_material_transactions_s.NEXTVAL
                          INTO l_num_txn_intf_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            RAISE l_exe_seq;
                    END;

                    -- 2.6 changes start
                    -- query to get organization_code
                    BEGIN
                        SELECT organization_code
                          INTO l_chr_organization
                          FROM mtl_parameters
                         WHERE organization_id = l_num_organization_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_organization   := NULL;
                    END;

                    -- 2.6 changes end
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Organization_code:' || l_chr_organization);

                    -- query to get offset details
                    BEGIN
                        l_offset_time   :=
                            get_offset_time (l_chr_organization);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_offset_time   := 0;
                    END;

                    -- 2.6 changes end
                    -- adding offset time to the receipt date -- 5.3
                    FND_FILE.PUT_LINE (FND_FILE.LOG,
                                       'l_offset_time:' || l_offset_time);
                    l_dte_server_tran_date                     :=
                        l_dte_server_tran_date + NVL (l_offset_time, 0);
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Transaction date after adding offset time:'
                        || l_dte_server_tran_date);
                    -- 5.3 changes end

                    l_trans_dtl_rec.interface_transaction_id   :=
                        l_num_txn_intf_id;

                    -- Insert record in mtl_transactions_interface
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
                                        l_num_txn_intf_id,
                                        l_num_txn_intf_id, --g_num_request_id,
                                        'WS',
                                        g_num_request_id,
                                        g_num_request_id,
                                        1,
                                        3,
                                        SYSDATE,
                                        l_num_emp_user_id,
                                        SYSDATE,
                                        l_num_emp_user_id,
                                        l_num_inventory_item_id,
                                        l_num_organization_id,
                                        inv_transactions_rec.qty,
                                        inv_transactions_rec.uom,
                                        DECODE (
                                            TO_CHAR (l_dte_server_tran_date,
                                                     'YYYYMM'),
                                            TO_CHAR (SYSDATE, 'YYYYMM'), l_dte_server_tran_date,
                                            SYSDATE), /*Ver 2.5: Identify and mark duplicate records; Should not     */
                                        --l_dte_server_tran_date, --inv_transactions_rec.tran_date,
                                        inv_transactions_rec.source_subinventory,
                                        l_num_source_locator_id,
                                        l_num_trans_type_id,
                                        l_num_dest_org_id,
                                        inv_transactions_rec.dest_subinventory,
                                        l_num_dest_locator_id,
                                        l_num_trans_source_id,
                                        l_num_distr_account_id,
                                        SUBSTRB (
                                            inv_transactions_rec.comments,
                                            1,
                                            240));

                    l_num_return                               :=
                        apps.inv_txn_manager_pub.process_transactions (
                            p_api_version     => 1.0,
                            p_commit          => fnd_api.g_false,
                            x_return_status   => l_chr_return_status,
                            x_msg_count       => l_num_msg_count,
                            x_msg_data        => l_chr_msg_data,
                            x_trans_count     => l_num_trans_count,
                            p_table           => 1,
                            p_header_id       => l_num_txn_intf_id);

                    l_chr_error_message                        := NULL;

                    IF l_chr_return_status = 'S'
                    THEN
                        l_trans_dtl_rec.process_status   := 'PROCESSED';
                    ELSE
                        l_chr_error_message              := l_chr_msg_data;
                        l_trans_dtl_rec.process_status   := 'ERROR';

                        /* 07/16/15 delete record from interface in case of error  VARIABLE_DELETE */
                        DELETE FROM mtl_transactions_interface
                              --where transaction_interface_id = l_num_txn_intf_id;-- Comment for  CCR CCR0009543
                              WHERE transaction_header_id = l_num_txn_intf_id; -- Added for  CCR CCR0009543
                    /*
                   SELECT mti.error_explanation
                     INTO l_chr_error_message
                     FROM mtl_transactions_interface mti
                    WHERE     mti.process_flag = 3
                          AND (mti.ERROR_CODE IS NOT NULL OR mti.error_explanation IS NOT NULL)
                          AND mti.transaction_interface_id = l_num_txn_intf_id;
                  */
                    END IF;

                    l_trans_dtl_rec.error_message              :=
                        l_chr_error_message;

                    update_stg_records (
                        p_in_chr_process_mode   => p_in_chr_process_mode,
                        p_in_trans_rec          => l_trans_dtl_rec,
                        p_in_serials_tab        => p_in_serials_tab);
                EXCEPTION
                    WHEN l_exe_record_exists
                    THEN
                        l_trans_dtl_rec.process_status   := 'DUPLICATE';
                        l_trans_dtl_rec.error_message    :=
                               'Record already exists for message ID '
                            || l_trans_dtl_rec.attribute1;
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_warehouse_err
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Warehouse is not WMS Enabled';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_src_subinv_err
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Source Subinventory is not valid';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_dest_subinv_err
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Destination Subinventory is not valid';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_invalid_tran_date
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Transaction Date is not valid';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_zero_trans_qty
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Transaction Qty is Zero';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_invalid_item
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Inventory Item is not valid';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_src_locator_err
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Source Locator is not valid';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_dest_locator_err
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Destination Locator is not valid';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_invalid_uom
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'UOM is not Primary UOM';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_period_not_open
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Inventory accounting period is not open';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_no_onhand
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'No Enough onhand for Inventory Adjustment or Host Transfer';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_invalid_reason
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Invalid Reason Code';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_serials_not_exists
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'QR details were not sent for a serialized item transaction';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_serials_count_mismatch
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'QRs count and Transaction count are not matching';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN l_exe_serials_exists
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'QR details were sent for a non-serialized item transaction';
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                    WHEN OTHERS
                    THEN
                        l_trans_dtl_rec.process_status   := 'ERROR';
                        l_trans_dtl_rec.error_message    :=
                            'Unexpected Error : ' || SQLERRM;
                        update_stg_records (
                            p_in_chr_process_mode   => p_in_chr_process_mode,
                            p_in_trans_rec          => l_trans_dtl_rec,
                            p_in_serials_tab        => p_in_serials_tab);
                END;

                IF p_in_chr_process_mode = 'ONLINE'
                THEN
                    IF l_trans_dtl_rec.process_status = 'ERROR'
                    THEN
                        p_out_chr_errbuf    := l_trans_dtl_rec.error_message;
                        p_out_chr_retcode   := '2';
                    ELSE
                        p_out_chr_errbuf    := NULL;
                        p_out_chr_retcode   := '0';
                    END IF;
                END IF;
            END LOOP;
        END IF;



        -- Purge the records
        IF p_in_num_purge_days IS NOT NULL
        THEN
            BEGIN
                purge (p_out_chr_errbuf      => l_chr_errbuf,
                       p_out_chr_retcode     => l_chr_retcode,
                       p_in_num_purge_days   => p_in_num_purge_days);

                IF l_chr_retcode <> '0'
                THEN
                    p_out_chr_errbuf    :=
                        'Error in Purge procedure : ' || l_chr_errbuf;
                    p_out_chr_retcode   := '1';
                    FND_FILE.PUT_LINE (FND_FILE.LOG, p_out_chr_errbuf);
                ELSE
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        p_in_num_purge_days || ' old days records are purged');
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf    :=
                           'Unexpected error while invoking purge procedure : '
                        || SQLERRM;
                    p_out_chr_retcode   := '1';
                    FND_FILE.PUT_LINE (FND_FILE.LOG, p_out_chr_errbuf);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_no_issue_trans_type
        THEN
            p_out_chr_errbuf    := 'Issue Transaction Type is not present';
            p_out_chr_retcode   := '2';
        WHEN l_exe_no_receipt_trans_type
        THEN
            p_out_chr_errbuf    := 'Receipt Transaction Type is not present';
            p_out_chr_retcode   := '2';
        WHEN l_exe_lock_err
        THEN
            p_out_chr_errbuf    := 'Unable to lock the staging table records';
            p_out_chr_retcode   := '2';
        WHEN l_exe_seq
        THEN
            p_out_chr_errbuf    :=
                'Unable to generate the transaction interface id';
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error at main procedure : ' || SQLERRM;
            p_out_chr_retcode   := '2';
    END main;

    -- ***************************************************************************
    -- Procedure Name      :  get_current_onhand
    --
    -- Description         :  This procedure will Return the value for onhand
    --                        (available to reserve) quantity.
    --
    -- Parameters
    -- ------------------------
    -- p_in_chr_sub_inv_code    [in]   :  Subinventory code
    -- p_in_num_org_id          [in]   :  Organization Id
    -- p_in_num_inv_item_id     [in]   :  Inventory Item Id
    -- p_out_num_atr_quaintity  [out]  :  Available to reserve Quantity
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date                 Author          Version     Description
    -- ----------           -------         -------     --------------------------
    -- 2014/09/05           Infosys         1.0     Initial version
    -- ***************************************************************************
    PROCEDURE get_current_onhand (p_in_num_org_id          IN     NUMBER,
                                  p_in_chr_sub_inv_code    IN     VARCHAR2,
                                  p_in_num_locator_id      IN     NUMBER,
                                  p_in_num_inv_item_id     IN     NUMBER,
                                  p_out_num_atr_quantity      OUT NUMBER)
    IS
        -- Local Variables
        l_chr_api_return_status   VARCHAR2 (10);
        l_num_msg_count           NUMBER := 0;
        l_chr_msg_data            VARCHAR2 (1000);
        l_num_qty_oh              NUMBER := 0;              --Total Onhand Qty
        l_num_qty_atr             NUMBER := 0;      --Available to Reserve Qty
        l_num_sum_qty_res         NUMBER := 0;
        l_num_qty_rqoh            NUMBER := 0;
        l_num_qty_qr              NUMBER := 0;                  --Reserved Qty
        l_num_qty_qs              NUMBER := 0;
        l_num_qty_att             NUMBER := 0;     --Available to Transact Qty
        l_num_qty_sqoh            NUMBER := 0;
        l_num_qty_srqoh           NUMBER := 0;
        l_num_qty_sqs             NUMBER := 0;
        l_num_qty_satt            NUMBER := 0;
        l_num_qty_satr            NUMBER := 0;
    BEGIN
        -- clear cache
        inv_quantity_tree_grp.clear_quantity_cache;
        -- call Inventory Quantity Tree Pub API to fetch Quantities for Available Sub-Inv
        inv_quantity_tree_pub.query_quantities (
            p_api_version_number           => g_num_api_version,
            p_init_msg_lst                 => fnd_api.g_false,
            x_return_status                => l_chr_api_return_status,
            x_msg_count                    => l_num_msg_count,
            x_msg_data                     => l_chr_msg_data,
            p_organization_id              => p_in_num_org_id,
            p_inventory_item_id            => p_in_num_inv_item_id,
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
            p_subinventory_code            => p_in_chr_sub_inv_code,
            p_locator_id                   => p_in_num_locator_id,
            p_onhand_source                => inv_quantity_tree_pvt.g_all_subs,
            x_qoh                          => l_num_qty_oh,
            x_rqoh                         => l_num_qty_rqoh,
            x_qr                           => l_num_qty_qr,
            x_qs                           => l_num_qty_qs,
            x_att                          => l_num_qty_att,
            x_atr                          => l_num_qty_atr,
            x_sqoh                         => l_num_qty_sqoh,
            x_srqoh                        => l_num_qty_srqoh,
            x_sqr                          => l_num_sum_qty_res,
            x_sqs                          => l_num_qty_sqs,
            x_satt                         => l_num_qty_satt,
            x_satr                         => l_num_qty_satr,
            p_transfer_subinventory_code   => NULL,
            p_cost_group_id                => NULL,
            p_lpn_id                       => NULL,
            p_transfer_locator_id          => NULL);

        IF l_chr_api_return_status = fnd_api.g_ret_sts_success
        THEN
            -- Set return values
            IF p_in_chr_sub_inv_code = 'Available'
            THEN
                p_out_num_atr_quantity   := l_num_qty_atr;
            ELSE
                p_out_num_atr_quantity   := l_num_qty_att;
            END IF;
        ELSE
            p_out_num_atr_quantity   := 0;                             --NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_num_atr_quantity   := 0;                             --NULL;
    END get_current_onhand;

    -- Procedure/Function Name  :  update_stg_records
    --
    -- Description              :  The purpose of this procedure is to update the process status of the records
    --
    -- parameters               :  p_in_chr_process_mode  IN : Process mode - Online or Batch
    --                                   p_in_trans_rec  OUT : Transaction detail record
    --
    -- Return/Exit              :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/11    Infosys            1.0   Initial Version
    -- ***************************************************************************
    PROCEDURE update_stg_records (p_in_chr_process_mode IN VARCHAR2, p_in_trans_rec IN OUT xxdo_inv_trans_adj_dtl_stg%ROWTYPE, --                                                p_in_serials_tab   IN  g_inv_trans_adj_ser_tab_type
                                                                                                                               p_in_serials_tab IN inv_trans_adj_ser_obj_tab_type)
    IS
    BEGIN
        IF p_in_chr_process_mode = 'BATCH'
        THEN
            UPDATE xxdo_inv_trans_adj_dtl_stg
               SET process_status = p_in_trans_rec.process_status, error_message = p_in_trans_rec.error_message, last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE, organization_id = p_in_trans_rec.organization_id, source_locator_id = p_in_trans_rec.source_locator_id,
                   destination_locator_id = p_in_trans_rec.destination_locator_id, inventory_item_id = p_in_trans_rec.inventory_item_id, interface_transaction_id = p_in_trans_rec.interface_transaction_id,
                   account_alias = p_in_trans_rec.account_alias, server_tran_date = p_in_trans_rec.server_tran_date
             WHERE transaction_seq_id = p_in_trans_rec.transaction_seq_id;

            UPDATE xxdo_inv_trans_adj_ser_stg
               SET process_status = p_in_trans_rec.process_status, error_message = p_in_trans_rec.error_message, last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE, organization_id = p_in_trans_rec.organization_id, source_locator_id = p_in_trans_rec.source_locator_id,
                   destination_locator_id = p_in_trans_rec.destination_locator_id, inventory_item_id = p_in_trans_rec.inventory_item_id
             WHERE transaction_seq_id = p_in_trans_rec.transaction_seq_id;
        ELSE
            p_in_trans_rec.creation_date      := SYSDATE;
            --            p_in_trans_rec.created_by := g_num_user_id;
            p_in_trans_rec.last_update_date   := SYSDATE;
            --            p_in_trans_rec.last_updated_by  := g_num_user_id;
            p_in_trans_rec.source             := 'WBS';
            p_in_trans_rec.destination        := 'EBS';
            p_in_trans_rec.record_type        := 'INSERT';
            p_in_trans_rec.request_id         := g_num_request_id;
            p_in_trans_rec.session_id         := USERENV ('SESSIONID');


            SELECT xxdo_inv_trans_adj_dtl_stg_s.NEXTVAL
              INTO p_in_trans_rec.transaction_seq_id
              FROM DUAL;

            INSERT INTO xxdo_inv_trans_adj_dtl_stg
                 VALUES p_in_trans_rec;

            IF p_in_serials_tab.EXISTS (1)
            THEN
                FOR l_num_index IN p_in_serials_tab.FIRST ..
                                   p_in_serials_tab.LAST
                LOOP
                    INSERT INTO xxdo_inv_trans_adj_ser_stg (
                                    wh_id,
                                    source_subinventory,
                                    dest_subinventory,
                                    source_locator,
                                    destination_locator,
                                    item_number,
                                    serial_number,
                                    organization_id,
                                    inventory_item_id,
                                    source_locator_id,
                                    destination_locator_id,
                                    transaction_seq_id,
                                    serial_seq_id,
                                    process_status,
                                    error_message,
                                    request_id,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    source_type,
                                    attribute1,
                                    attribute2,
                                    attribute3,
                                    attribute4,
                                    attribute5,
                                    attribute6,
                                    attribute7,
                                    attribute8,
                                    attribute9,
                                    attribute10,
                                    attribute11,
                                    attribute12,
                                    attribute13,
                                    attribute14,
                                    attribute15,
                                    attribute16,
                                    attribute17,
                                    attribute18,
                                    attribute19,
                                    attribute20,
                                    source,
                                    destination,
                                    record_type,
                                    session_id)
                             VALUES (
                                        p_in_serials_tab (l_num_index).wh_id,
                                        p_in_serials_tab (l_num_index).source_subinventory,
                                        p_in_serials_tab (l_num_index).dest_subinventory,
                                        p_in_serials_tab (l_num_index).source_locator,
                                        p_in_serials_tab (l_num_index).destination_locator,
                                        p_in_serials_tab (l_num_index).item_number,
                                        p_in_serials_tab (l_num_index).serial_number,
                                        p_in_trans_rec.organization_id,
                                        p_in_trans_rec.inventory_item_id,
                                        p_in_trans_rec.source_locator_id,
                                        p_in_trans_rec.destination_locator_id,
                                        p_in_trans_rec.transaction_seq_id,
                                        xxdo_inv_trans_adj_ser_stg_s.NEXTVAL,
                                        p_in_trans_rec.process_status,
                                        NULL,
                                        g_num_request_id,
                                        SYSDATE,
                                        g_num_user_id,
                                        SYSDATE,
                                        g_num_user_id,
                                        p_in_trans_rec.source_type,
                                        p_in_serials_tab (l_num_index).attribute1,
                                        p_in_serials_tab (l_num_index).attribute2,
                                        p_in_serials_tab (l_num_index).attribute3,
                                        p_in_serials_tab (l_num_index).attribute4,
                                        p_in_serials_tab (l_num_index).attribute5,
                                        p_in_serials_tab (l_num_index).attribute6,
                                        p_in_serials_tab (l_num_index).attribute7,
                                        p_in_serials_tab (l_num_index).attribute8,
                                        p_in_serials_tab (l_num_index).attribute9,
                                        p_in_serials_tab (l_num_index).attribute10,
                                        p_in_serials_tab (l_num_index).attribute11,
                                        p_in_serials_tab (l_num_index).attribute12,
                                        p_in_serials_tab (l_num_index).attribute13,
                                        p_in_serials_tab (l_num_index).attribute14,
                                        p_in_serials_tab (l_num_index).attribute15,
                                        p_in_serials_tab (l_num_index).attribute16,
                                        p_in_serials_tab (l_num_index).attribute17,
                                        p_in_serials_tab (l_num_index).attribute18,
                                        p_in_serials_tab (l_num_index).attribute19,
                                        p_in_serials_tab (l_num_index).attribute20,
                                        p_in_trans_rec.source,
                                        p_in_trans_rec.destination,
                                        p_in_trans_rec.record_type,
                                        USERENV ('SESSIONID'));
                END LOOP;
            END IF;
        END IF;

        -- To interface the QR information
        IF     p_in_trans_rec.process_status = 'PROCESSED'
           AND p_in_trans_rec.dest_subinventory IS NULL
        THEN
            BEGIN
                UPDATE xxdo.xxdo_serial_temp xst
                   SET (status_id, source_code_reference, source_code)   =
                           (SELECT DECODE (p_in_trans_rec.reason_code,  'DESTROY', 9,  'DONATE', 2,  'OUTLET', 2,  1), p_in_trans_rec.account_alias, 'INV_ADJUST'
                              FROM xxdo_inv_trans_adj_ser_stg xos
                             WHERE     xos.process_status = 'PROCESSED'
                                   AND xos.serial_number = xst.serial_number
                                   AND xos.transaction_seq_id =
                                       p_in_trans_rec.transaction_seq_id
                                   AND xos.session_id = USERENV ('SESSIONID'))
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo_inv_trans_adj_ser_stg xos
                             WHERE     xos.process_status = 'PROCESSED'
                                   AND xos.serial_number = xst.serial_number
                                   AND xos.transaction_seq_id =
                                       p_in_trans_rec.transaction_seq_id
                                   AND xos.session_id = USERENV ('SESSIONID'));

                INSERT INTO xxdo.xxdo_serial_temp xst (serial_number,
                                                       inventory_item_id,
                                                       last_update_date,
                                                       last_updated_by,
                                                       creation_date,
                                                       created_by,
                                                       organization_id,
                                                       status_id,
                                                       source_code,
                                                       source_code_reference)
                    SELECT xos.serial_number, p_in_trans_rec.inventory_item_id, SYSDATE,
                           g_num_user_id, SYSDATE, g_num_user_id,
                           p_in_trans_rec.organization_id, DECODE (p_in_trans_rec.reason_code,  'DESTROY', 9,  'DONATE', 2,  'OUTLET', 2,  1), 'INV_ADJUST',
                           p_in_trans_rec.account_alias
                      FROM xxdo_inv_trans_adj_ser_stg xos
                     WHERE     xos.process_status = 'PROCESSED'
                           AND xos.transaction_seq_id =
                               p_in_trans_rec.transaction_seq_id
                           AND xos.session_id = USERENV ('SESSIONID')
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdo_serial_temp xst
                                     WHERE xos.serial_number =
                                           xst.serial_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END update_stg_records;

    -- ***************************************************************************
    -- Procedure/Function Name  :  get_server_timezone
    --
    -- Description              :  This function converts the local time to server time
    --
    -- parameters               :  p_in_num_inv_org_local_time IN : Local time
    --                                   p_in_num_inv_org_id   IN : Inventory Org Id
    ----
    -- Return/Exit              :  Server time
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/04    Infosys            1.0   Initial Version
    -- ***************************************************************************


    FUNCTION get_server_timezone (p_in_num_inv_org_local_time   DATE,
                                  p_in_num_inv_org_id           NUMBER)
        RETURN DATE
    IS
        l_num_leid          NUMBER;
        l_dte_server_date   DATE := NULL;
    BEGIN
        BEGIN
            SELECT legal_entity
              INTO l_num_leid
              FROM org_organization_definitions ood
             WHERE organization_id = p_in_num_inv_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_leid   := -1;
        END;


        BEGIN
            SELECT XLE_LE_TIMEZONE_GRP.Get_Server_Day_Time_For_Le (p_in_num_inv_org_local_time, l_num_leid)
              INTO l_dte_server_date
              FROM DUAL;
        END;

        RETURN l_dte_server_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_server_timezone;

    PROCEDURE process_batch (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER
                             , p_process_status IN VARCHAR2 DEFAULT 'NEW') ---P_PROCESS_STATUS
    IS
        l_chr_errbuf    VARCHAR2 (2000);
        l_chr_retcode   VARCHAR2 (1);
    BEGIN
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;

        main (p_out_chr_errbuf         => l_chr_errbuf,
              p_out_chr_retcode        => l_chr_retcode,
              p_in_chr_process_mode    => 'BATCH',
              p_in_chr_warehouse       => NULL,
              p_in_chr_from_subinv     => NULL,
              p_in_chr_from_locator    => NULL,
              p_in_chr_to_subinv       => NULL,
              p_in_chr_to_locator      => NULL,
              p_in_chr_item            => NULL,
              p_in_num_qty             => NULL,
              p_in_chr_uom             => NULL,
              p_in_dte_trans_date      => NULL,
              p_in_chr_reason_code     => NULL,
              p_in_chr_comments        => NULL,
              p_in_chr_employee_id     => NULL,
              p_in_chr_employee_name   => NULL,
              p_in_num_trans_seq_id    => NULL,
              p_in_serials_tab         => NULL,
              p_in_num_purge_days      => p_in_num_purge_days,
              p_process_status         => p_process_status); ---P_PROCESS_STATUS

        p_out_chr_retcode   := l_chr_retcode;
        p_out_chr_errbuf    := l_chr_errbuf;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Unexpected error in process batch procedure : '
                || p_out_chr_errbuf);
    END process_batch;
END xxdo_inv_transfer_adj_pkg;
/


GRANT EXECUTE ON APPS.XXDO_INV_TRANSFER_ADJ_PKG TO SOA_INT
/
