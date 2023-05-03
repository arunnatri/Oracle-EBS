--
-- XXDO_ONHAND_ISSUE_OUT  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_onhand_issue_out
AS
    -- =========================================================================================
    -- Description:
    -- This package generates miscellaneous issue transactions to reset existing inventory on-hand to zero.
    -- When open PO Receipts and Order Shipments are converted they will create on-hand in the system.
    -- But this on-hand balance should not contribute to the overall on-hand as the actual on-hand balance
    -- as of cutover date will be converted using on-hand conversion program.
    -- This package will be required just before running the actual onhand conversion programs to issue out all existing onhand
    --===========================================================================================

    -- Pseudo Logic
    -- Query and sum up inventory onhand qty by inventory org, subinv, locator and item
    -- Insert into MTL_TRANSACTIONS_INTERFACE
    -- Invoke 'Process transactions interface' concurrent program based on parameter value

    /******************************************************************************
     1.Components:  main_proc
       Purpose: Depending upon parameters this will run group by query to get onhand as of run date
       and insert into interface table. If param pi_submit_conc_prog = 'Y' then it will submit the standard
       program.


       Execution Method: From custom concurrent program

       Note:

     2.Components:  submit_apps_request
       Purpose: This will submit the apps request 'Process Transaction Processor'


       Execution Method:

       Note:

     3.Components:  reinstate_onhand
       Purpose: Proc to create misc receipts based on entries from backup table. To be
       used only on emergency


       Execution Method: Standalone call

       Note:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        4/21/2015             1. Created this package.
    ******************************************************************************/
    PROCEDURE main_proc (
        errbuf                           OUT VARCHAR2,
        retcod                           OUT VARCHAR2,
        pi_transaction_type           IN     VARCHAR2 DEFAULT 'Miscellaneous issue',
        pi_inventory_org_code         IN     VARCHAR2 DEFAULT NULL,
        pi_subinv_code                IN     VARCHAR2 DEFAULT NULL,
        pi_inventory_item_id          IN     NUMBER DEFAULT NULL,
        pi_source_code                IN     VARCHAR2,
        pi_distribution_natural_acc   IN     VARCHAR2)
    IS
        -- Define Variables
        v_header_id                    NUMBER;
        v_transaction_type_id          NUMBER;
        v_transaction_source_type_id   NUMBER;
        v_account                      NUMBER;
        v_insert_count                 NUMBER;
        v_message                      VARCHAR2 (2000);

        e_custom                       EXCEPTION;

        -- Define Cursors
        -- Go through all orgs which have onhand
        CURSOR c_orgs IS
              SELECT organization_code, organization_id
                FROM mtl_onhand_total_v
               WHERE organization_code =
                     NVL (pi_inventory_org_code, organization_code)
            GROUP BY organization_code, organization_id;

        -- Get the onhand details
        CURSOR c_onhand (p_inv_org_code IN VARCHAR2)
        IS
              SELECT ood.organization_code, ood.organization_id, moqd.inventory_item_id,
                     moqd.subinventory_code, moqd.locator_id, moqd.transaction_uom_code uom,
                     moqd.lpn_id, SUM (transaction_quantity) total_onhand
                FROM mtl_onhand_quantities_detail moqd, org_organization_definitions ood
               WHERE     ood.organization_code = p_inv_org_code
                     AND ood.organization_id = moqd.organization_id
                     AND moqd.inventory_item_id =
                         NVL (pi_inventory_item_id, inventory_item_id)
                     AND moqd.subinventory_code =
                         NVL (pi_subinv_code, subinventory_code)
            GROUP BY ood.organization_code, ood.organization_id, moqd.inventory_item_id,
                     moqd.subinventory_code, moqd.locator_id, moqd.transaction_uom_code,
                     moqd.lpn_id;
    BEGIN
        -- Generate source header id
        SELECT TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmddhh24miss'))
          INTO v_header_id
          FROM DUAL;

        -- Get transaction type and source IDs
        SELECT transaction_type_id, transaction_source_type_id
          INTO v_transaction_type_id, v_transaction_source_type_id
          FROM mtl_transaction_types
         WHERE transaction_type_name = pi_transaction_type;

        IF NOT is_backup_ready (
                   pi_inventory_org_code   => pi_inventory_org_code,
                   pi_subinv_code          => pi_subinv_code,
                   pi_inventory_item_id    => pi_inventory_item_id)
        THEN
            v_message   := 'Error backing up table';
            RAISE e_custom;
        ELSE
            -- Start looping through each org
            FOR c1 IN c_orgs
            LOOP
                print_message (
                    'Starting for org code: ' || c1.organization_code);
                -- Derive distribution GL account
                v_account   :=
                    get_account (pi_distribution_natural_acc,
                                 c1.organization_id);

                IF v_account <> -99
                THEN
                    -- Account derived successfully
                    -- Start insert

                    FOR c IN c_onhand (c1.organization_code)
                    LOOP
                        --Reset variable
                        v_insert_count   := 0;

                        -- Insert Statement
                        INSERT INTO mtl_transactions_interface (
                                        source_header_id,
                                        source_line_id,
                                        source_code,
                                        process_flag,
                                        transaction_mode,
                                        lock_flag,
                                        last_update_date,
                                        last_updated_by,
                                        creation_date,
                                        created_by,
                                        inventory_item_id,
                                        organization_id,
                                        lpn_id,
                                        transaction_quantity,
                                        transaction_uom,
                                        transaction_date,
                                        subinventory_code,
                                        locator_id,
                                        transaction_type_id,
                                        transaction_source_type_id,
                                        transaction_reference,
                                        distribution_account_id)
                             VALUES (v_header_id,          -- source_header_id
                                                  v_header_id, -- source_line_id
                                                               pi_source_code, -- source_code
                                                                               g_process_flag, -- process_flag
                                                                                               g_transaction_mode, -- transaction_mode
                                                                                                                   g_lock_flag, -- lock_flag
                                                                                                                                SYSDATE, -- last_update_date
                                                                                                                                         fnd_global.user_id, -- last_updated_by
                                                                                                                                                             SYSDATE, -- creation_date
                                                                                                                                                                      fnd_global.user_id, -- created_by
                                                                                                                                                                                          c.inventory_item_id, -- inventory_item_id
                                                                                                                                                                                                               c.organization_id, -- organization_id
                                                                                                                                                                                                                                  c.lpn_id, -- lpn_id
                                                                                                                                                                                                                                            -1 * c.total_onhand, -- transaction_quantity
                                                                                                                                                                                                                                                                 c.uom, -- transaction_uom
                                                                                                                                                                                                                                                                        SYSDATE, -- transaction_date
                                                                                                                                                                                                                                                                                 c.subinventory_code, -- subinventory_code
                                                                                                                                                                                                                                                                                                      c.locator_id, -- locator_id
                                                                                                                                                                                                                                                                                                                    v_transaction_type_id, -- transaction_type_id
                                                                                                                                                                                                                                                                                                                                           v_transaction_source_type_id, -- transaction_source_type_id
                                                                                                                                                                                                                                                                                                                                                                         NULL
                                     ,                -- transaction_reference
                                       v_account    -- distribution_account_id
                                                );

                        v_insert_count   := SQL%ROWCOUNT;
                    END LOOP;

                    print_message (
                           'Rows inserted into MTL_TRANSACTION_INTERFACE for org code: '
                        || c1.organization_code
                        || ' = '
                        || v_insert_count);

                    COMMIT;

                    -- Update backup table status
                    UPDATE xxdo_onhand_issue_out_bkp
                       SET status   = 'ISSUED'
                     WHERE     organization_code = c1.organization_code
                           AND inventory_item_id =
                               NVL (pi_inventory_item_id, inventory_item_id)
                           AND subinventory_code =
                               NVL (pi_subinv_code, subinventory_code);
                -- No need to submit processor from within this. Redundant code
                /* IF pi_submit_conc_prog = 'Y'
                 THEN
                    submit_apps_request (pi_inv_org_id => c1.organization_id);
                 END IF;*/
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN e_custom
        THEN
            print_message (v_message);
        WHEN OTHERS
        THEN
            print_message (
                'Unexpected error ~ ' || SUBSTR (SQLERRM, 1, 1000));
    END main_proc;

    PROCEDURE submit_apps_request (pi_inv_org_id IN NUMBER)
    IS
        -- Define variable
        v_message      VARCHAR2 (1000);
        v_request_id   NUMBER := NULL;
        -- Define Exception
        e_custom       EXCEPTION;
    BEGIN
        fnd_global.apps_initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);

        -- Change Organization
        fnd_profile.put ('MFG_ORGANIZATION_ID', pi_inv_org_id);

        v_request_id   :=
            fnd_request.submit_request ('INV', 'INCTCM', 'Process transaction interface'
                                        , SYSDATE, FALSE);
        COMMIT;

        IF v_request_id IS NOT NULL
        THEN
            -- Request submitted successfully
            v_message   :=
                   'Process transaction interface submitted. Check request ID '
                || v_request_id;

            print_message (v_message);
        ELSE
            -- Error submitting request
            RAISE e_custom;
        END IF;
    EXCEPTION
        WHEN e_custom
        THEN
            v_message   :=
                   'Error submitting Process transaction interface. Error '
                || SUBSTR (SQLERRM, 1, 200);
            print_message (v_message);
    END submit_apps_request;


    -- Print given message on DBMS output and FND Log

    PROCEDURE print_message (ip_text VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (ip_text);
        fnd_file.put_line (fnd_file.LOG, ip_text);
    END print_message;

    FUNCTION get_account (pi_distribution_natural_acc   IN VARCHAR2,
                          pi_organization_id            IN NUMBER)
        RETURN NUMBER
    IS
        v_segment1       gl_code_combinations.segment1%TYPE;
        v_segment2       gl_code_combinations.segment2%TYPE;
        v_segment3       gl_code_combinations.segment3%TYPE;
        v_segment4       gl_code_combinations.segment4%TYPE;
        v_segment5       gl_code_combinations.segment5%TYPE;
        v_segment7       gl_code_combinations.segment7%TYPE;
        v_segment8       gl_code_combinations.segment8%TYPE;
        v_account_ccid   NUMBER;
    BEGIN
        -- Get all segments exception natural account from mtl_parameters
        SELECT gcc.segment1, gcc.segment2, gcc.segment3,
               gcc.segment4, gcc.segment5, gcc.segment7,
               gcc.segment8
          INTO v_segment1, v_segment2, v_segment3, v_segment4,
                         v_segment5, v_segment7, v_segment8
          FROM mtl_parameters mp, gl_code_combinations gcc
         WHERE     mp.organization_id = pi_organization_id
               AND mp.material_account = gcc.code_combination_id;

        -- Now get the code combination ID where natural account is what is being passed and the rest of the segments are from mtl_parameters
        SELECT code_combination_id
          INTO v_account_ccid
          FROM gl_code_combinations gcc
         WHERE     enabled_flag = 'Y'
               AND summary_flag = 'N'
               AND gcc.segment1 = v_segment1
               AND gcc.segment2 = v_segment2
               AND gcc.segment3 = v_segment3
               AND gcc.segment4 = v_segment4
               AND gcc.segment5 = v_segment5
               AND gcc.segment6 = pi_distribution_natural_acc
               AND gcc.segment7 = v_segment7
               AND gcc.segment8 = v_segment8;


        RETURN v_account_ccid;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_message (
                   'Error getting CCID for '
                || v_segment1
                || '.'
                || v_segment2
                || '.'
                || v_segment3
                || '.'
                || v_segment4
                || '.'
                || v_segment5
                || '.'
                || pi_distribution_natural_acc
                || '.'
                || v_segment7
                || '.'
                || v_segment8);
            RETURN -99;
    END get_account;

    -- Function to backup the data to be issued out
    FUNCTION is_backup_ready (pi_inventory_org_code IN VARCHAR2, pi_subinv_code IN VARCHAR2, pi_inventory_item_id IN NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        -- Clear out existing data in backup table for given parameters
        DELETE FROM
            xxdo_onhand_issue_out_bkp
              WHERE     organization_code =
                        NVL (pi_inventory_org_code, organization_code)
                    AND inventory_item_id =
                        NVL (pi_inventory_item_id, inventory_item_id)
                    AND subinventory_code =
                        NVL (pi_subinv_code, subinventory_code);

        print_message (
            'Number of rows cleared from backup: ' || SQL%ROWCOUNT);


        -- Now create fresh backup
        INSERT INTO xxdo_onhand_issue_out_bkp (organization_code, organization_id, inventory_item_id, subinventory_code, locator_id, uom, lpn_id, creation_date, created_by
                                               , total_onhand)
              SELECT ood.organization_code, ood.organization_id, moqd.inventory_item_id,
                     moqd.subinventory_code, moqd.locator_id, moqd.transaction_uom_code uom,
                     moqd.lpn_id, SYSDATE, fnd_global.user_id,
                     SUM (transaction_quantity) total_onhand
                FROM mtl_onhand_quantities_detail moqd, org_organization_definitions ood
               WHERE     ood.organization_code =
                         NVL (pi_inventory_org_code, organization_code)
                     AND ood.organization_id = moqd.organization_id
                     AND moqd.inventory_item_id =
                         NVL (pi_inventory_item_id, inventory_item_id)
                     AND moqd.subinventory_code =
                         NVL (pi_subinv_code, subinventory_code)
            GROUP BY ood.organization_code, ood.organization_id, moqd.inventory_item_id,
                     moqd.subinventory_code, moqd.locator_id, moqd.transaction_uom_code,
                     moqd.lpn_id;


        print_message ('Number of rows backed up: ' || SQL%ROWCOUNT);

        COMMIT;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_message (
                   'Unexpected error while backing up data. Error ~ '
                || SUBSTR (SQLERRM, 1, 200));
            RETURN NULL;
    END is_backup_ready;

    -- Proc to create receipts based on details from backup
    -- Code does not work for LPN level onhand
    -- Only to be used for emergency
    PROCEDURE reinstate_onhand (
        pi_transaction_type     IN VARCHAR2 DEFAULT 'Miscellaneous receipt',
        pi_inventory_org_code   IN VARCHAR2,
        pi_subinv_code          IN VARCHAR2 DEFAULT NULL,
        pi_inventory_item_id    IN NUMBER DEFAULT NULL)
    IS
        v_transaction_type_id          NUMBER;
        v_transaction_source_type_id   NUMBER;
        v_account                      NUMBER;
    BEGIN
        SELECT transaction_type_id, transaction_source_type_id
          INTO v_transaction_type_id, v_transaction_source_type_id
          FROM mtl_transaction_types
         WHERE transaction_type_name = pi_transaction_type;

        -- Get material account for org
        SELECT mp.material_account
          INTO v_account
          FROM mtl_parameters mp
         WHERE mp.organization_code = pi_inventory_org_code;

        -- Insert Statement
        INSERT INTO mtl_transactions_interface (source_header_id, source_line_id, source_code, process_flag, transaction_mode, lock_flag, last_update_date, last_updated_by, creation_date, created_by, inventory_item_id, organization_id, lpn_id, transaction_quantity, transaction_uom, transaction_date, subinventory_code, locator_id, transaction_type_id, transaction_source_type_id, transaction_reference
                                                , distribution_account_id)
            SELECT -999, -999, 'Conversion - Onhand Reinstate',
                   g_process_flag, g_transaction_mode, g_lock_flag,
                   SYSDATE, fnd_global.user_id, SYSDATE,
                   fnd_global.user_id, inventory_item_id, organization_id,
                   lpn_id, total_onhand, uom,
                   SYSDATE, subinventory_code, locator_id,
                   v_transaction_type_id, v_transaction_source_type_id, NULL,
                   v_account
              FROM xxdo_onhand_issue_out_bkp
             WHERE     organization_code = pi_inventory_org_code
                   AND inventory_item_id =
                       NVL (pi_inventory_item_id, inventory_item_id)
                   AND subinventory_code =
                       NVL (pi_subinv_code, subinventory_code)
                   AND status = 'ISSUED';

        UPDATE xxdo_onhand_issue_out_bkp
           SET status   = 'REINSTATED'
         WHERE     organization_code = pi_inventory_org_code
               AND inventory_item_id =
                   NVL (pi_inventory_item_id, inventory_item_id)
               AND subinventory_code =
                   NVL (pi_subinv_code, subinventory_code)
               AND status = 'ISSUED';
    -- No commit by design
    END reinstate_onhand;
END xxdo_onhand_issue_out;
/
