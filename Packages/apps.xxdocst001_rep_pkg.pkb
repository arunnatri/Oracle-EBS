--
-- XXDOCST001_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOCST001_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOCST001_REP_PKG
       REP NAME:Item Cost Upload - Deckers

       REVISIONS:
       Ver        Date        Author                           Description
       ---------  ----------  ---------------       ------------------------------------
       1.0       05/15/2012     Shibu                 1. Created this package Item Cost Upload - Deckers
       1.1       11/27/2014  BT Technology Team         Addition of new procedures
                                                      1) insert_into_interface
                                                      2) insert_into_custom_table
                                                          (Invoke through seperate concurrent program)
                                                      3) purge_custom_table
                                                          (Invoke through seperate concurrent program)
                                                       4)custom_table_report
                                                       (Invoke through seperate concurrent program)
                                                       5) inv_category_load - (Tariff Code Category Assignment)
                                                         (Invoke through seperate concurrent program)
      1.2         06/10/2015                           Added debug parameter for Category programs
      1.3         07/08/2015                          Changes made as per the Defect#2720
      1.4         11/16/2015                          Changes made as per the Defect#444
      1.5         12/08/2015 BT Technology Team       Changes made as per Defect#598
    ******************************************************************************/
    g_org_id            NUMBER := fnd_global.org_id;
    g_user_id           NUMBER := fnd_global.user_id;
    g_conc_request_id   NUMBER := fnd_global.conc_request_id;
    g_limit             NUMBER := 50000;


    CURSOR c_all_records IS
        SELECT *
          FROM xxdo.xxdocst_stage_std_pending_cst
         WHERE status = 'N';

    PROCEDURE print_msg_prc (p_debug VARCHAR2, p_message IN VARCHAR2)
    AS
    BEGIN
        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
            DBMS_OUTPUT.put_line (p_message);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END print_msg_prc;



    FUNCTION get_item_org_id (p_item_number   VARCHAR2,
                              p_org           VARCHAR2,
                              p_col           VARCHAR2)
        RETURN NUMBER
    IS
        l_item_id   NUMBER;
        l_org_id    NUMBER;
    BEGIN
        SELECT msib.inventory_item_id, msib.organization_id
          INTO l_item_id, l_org_id
          FROM mtl_system_items_b msib, mtl_parameters mp
         WHERE     msib.segment1 = p_item_number
               AND msib.organization_id = mp.organization_id
               AND mp.organization_code = p_org;

        IF p_col = 'ITEM'
        THEN
            RETURN l_item_id;
        ELSE
            RETURN l_org_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_item_org_id;

    FUNCTION get_resource_rate (p_item_id         NUMBER,
                                p_org_id          NUMBER,
                                p_resource_code   VARCHAR2)
        RETURN NUMBER
    AS
        l_rate   NUMBER;
    BEGIN
        SELECT usage_rate_or_amount
          INTO l_rate
          FROM cst_item_cost_details_v
         WHERE     inventory_item_id = p_item_id
               AND organization_id = p_org_id
               AND cost_type_id = gn_cost_type_id
               AND cost_element_id = gn_cost_element_id
               AND resource_code = p_resource_code;

        RETURN l_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE extract_cat_to_stg (x_errbuf       OUT NOCOPY VARCHAR2,
                                  x_retcode      OUT NOCOPY NUMBER)
    AS
        CURSOR c_cat_main IS
            SELECT *
              FROM (SELECT item, inv_org_id organization_id, 'TARRIF CODE' category_set_name,
                           tarrif_code segment1, country segment3, --DEFAULT_CATEGORY segment3,
                                                                   default_category segment4,
                           item_id inventory_item_id, GROUP_ID
                      FROM xxdocst_stage_std_pending_cst
                     WHERE     tarrif_code IS NOT NULL
                           AND status_category = gc_validate_status
                           AND (tarrif_code IS NOT NULL OR country IS NOT NULL OR default_category IS NOT NULL));

        TYPE c_main_type IS TABLE OF c_cat_main%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_main_tab      c_main_type;


        ld_date          DATE;
        ln_total_count   NUMBER;
        ln_count         NUMBER;
    BEGIN
        BEGIN
            DELETE FROM xxdo.xxd_inv_item_cat_stg_t
                  WHERE category_set_name = 'TARRIF CODE';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                        'Error while deleting Tarrif code category records from table xxdo.XXD_INV_ITEM_CAT_STG_T');
        END;

        SELECT SYSDATE INTO ld_date FROM sys.DUAL;

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'Procedure extract_main');

        OPEN c_cat_main;

        LOOP
            FETCH c_cat_main BULK COLLECT INTO lt_main_tab LIMIT 20000;

            IF lt_main_tab.COUNT = 0
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'No Valid records are present in the XXDOCST_STAGE_STD_PENDING_CST table  and SQLERRM'
                        || SQLERRM);
            ELSE
                FORALL i IN 1 .. lt_main_tab.COUNT
                    --Inserting to Staging Table XXD_INV_ITEM_CAT_STG_T
                    INSERT INTO xxd_inv_item_cat_stg_t (record_id, batch_number, record_status, item_number, organization_id, category_set_name, segment1, -- SEGMENT2 ,
                                                                                                                                                           segment3, segment4, inventory_item_id, created_by, creation_date, last_updated_by, last_update_date, error_message
                                                        , GROUP_ID)
                         VALUES (xxd_inv_item_cat_stg_t_s.NEXTVAL, NULL, 'N',
                                 lt_main_tab (i).item, lt_main_tab (i).organization_id, lt_main_tab (i).category_set_name, lt_main_tab (i).segment1, --lt_main_tab (i).SEGMENT2,
                                                                                                                                                     lt_main_tab (i).segment3, lt_main_tab (i).segment4, lt_main_tab (i).inventory_item_id, fnd_global.user_id, ld_date, fnd_global.login_id, ld_date, NULL
                                 , lt_main_tab (i).GROUP_ID);


                ln_total_count   := ln_total_count + ln_count;
                ln_count         := ln_count + 1;

                IF ln_total_count = 20000
                THEN
                    ln_total_count   := 0;
                    ln_count         := 0;
                    COMMIT;
                END IF;
            END IF;

            EXIT WHEN lt_main_tab.COUNT < 20000;
        END LOOP;

        CLOSE c_cat_main;

        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'End Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));



        UPDATE xxdocst_stage_std_pending_cst
           SET status_category   = 'I'
         WHERE     status_category = gc_validate_status
               AND (tarrif_code IS NOT NULL OR country IS NOT NULL OR default_category IS NOT NULL);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'error mesg:' || SQLERRM);
            NULL;
    END extract_cat_to_stg;


    PROCEDURE update_item_price (
        p_item_tbl_type IN ego_item_pub.item_tbl_type)
    IS
        -- l_item_tbl_typ    ego_item_pub.item_tbl_type;
        x_item_table      ego_item_pub.item_tbl_type;
        x_return_status   VARCHAR2 (1);
        x_msg_count       NUMBER (10);
        x_message_list    error_handler.error_tbl_type;
        l_count           NUMBER;
    BEGIN
        fnd_global.apps_initialize (fnd_global.user_id,             -- User Id
                                    fnd_global.resp_id,   -- Responsibility Id
                                    fnd_global.resp_appl_id  -- Application Id
                                                           );

        /* l_item_tbl_typ (1).transaction_type := 'UPDATE';
         l_item_tbl_typ (1).inventory_item_id := p_inv_item_id;
         l_item_tbl_typ (1).organization_id := p_inv_org_id;
         l_item_tbl_typ (1).list_price_per_unit := p_factory_cost;*/

        ego_item_pub.process_items (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, p_item_tbl => p_item_tbl_type, x_item_tbl => x_item_table, x_return_status => x_return_status
                                    , x_msg_count => x_msg_count);


        IF (x_return_status <> fnd_api.g_ret_sts_success)
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'Error Messages :');
            error_handler.get_message_list (x_message_list => x_message_list);


            FOR i IN 1 .. x_message_list.COUNT
            LOOP
                print_msg_prc (p_debug     => gc_debug_flag,
                               p_message   => x_message_list (i).MESSAGE_TEXT);
            END LOOP;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Exception Occured :'
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
    END update_item_price;


    PROCEDURE submit_cost_import_proc (p_return_mesg OUT VARCHAR2, p_return_code OUT VARCHAR2, p_request_id OUT NUMBER
                                       , p_group_id IN NUMBER)
    IS
        l_req_id       NUMBER;
        l_phase        VARCHAR2 (100);
        l_status       VARCHAR2 (30);
        l_dev_phase    VARCHAR2 (100);
        l_dev_status   VARCHAR2 (100);
        l_wait_req     BOOLEAN;
        l_message      VARCHAR2 (2000);
    BEGIN
        l_req_id       :=
            fnd_request.submit_request (application   => 'BOM',
                                        program       => 'CSTPCIMP',
                                        argument1     => 4,
                                        -- Import Cost Option (Import item costs,resource rates, and overhead rates)
                                        argument2     => 2,
                                        -- (Mode to Run )Remove and replace cost information
                                        argument3     => 1, -- Group Id option (specific_request_id)
                                        argument4     => NULL, --Dummy Group ID
                                        argument5     => p_group_id, -- Group Id
                                        argument6     => 'AvgRates', -- Cost Type
                                        argument7     => 2, -- Delete Successful rows
                                        start_time    => SYSDATE,
                                        sub_request   => FALSE);
        COMMIT;

        IF l_req_id = 0
        THEN
            p_return_code   := 2;
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    ' Unable to submit Cost Import concurrent program ');
        ELSE
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Cost Import concurrent request submitted successfully.');
            l_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id, interval => 5, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status
                                                 , MESSAGE => l_message);

            IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Cost Import concurrent request with the request id '
                        || l_req_id
                        || ' completed with NORMAL status.');
            ELSE
                p_return_code   := 2;
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Cost Import concurrent request with the request id '
                        || l_req_id
                        || ' did not complete with NORMAL status.');
            END IF;
        -- End of if to check if the status is normal and phase is complete
        END IF;                      -- End of if to check if request ID is 0.

        COMMIT;
        p_request_id   := l_req_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_code   := 2;
            p_return_mesg   :=
                   'Error in Cost Import '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ();
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => p_return_mesg);
    END submit_cost_import_proc;

    PROCEDURE update_interface_status (p_request_id   IN NUMBER,
                                       p_group_id     IN NUMBER)
    IS
        CURSOR c_interfaced_records IS
            SELECT *
              FROM xxdo.xxdocst_stage_std_pending_cst
             WHERE status = 'I';

        CURSOR c_err (p_item_id NUMBER, p_org_id NUMBER)
        IS
            SELECT error_flag, error_explanation
              FROM cst_item_cst_dtls_interface
             WHERE     request_id = p_request_id
                   AND inventory_item_id = p_item_id
                   AND organization_id = p_org_id;

        l_status         VARCHAR2 (1);
        l_err_msg        VARCHAR2 (4000);
        v_interfaced     VARCHAR2 (1);
        l_update_count   NUMBER := 0;
    BEGIN
        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst xssp
               SET xssp.status   = 'P'
             WHERE     EXISTS
                           (SELECT 1
                              FROM cst_item_cst_dtls_interface
                             WHERE     xssp.item_id = inventory_item_id
                                   AND xssp.inv_org_id = organization_id
                                   AND GROUP_ID = p_group_id
                                   AND error_flag IS NULL
                                   AND process_flag = 5)
                   AND xssp.GROUP_ID = p_group_id;



            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Exception Occured while updating the processed status in staging table:'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;

        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst xssp
               SET xssp.status   = 'X'
             WHERE     EXISTS
                           (SELECT 1
                              FROM cst_item_cst_dtls_interface
                             WHERE     xssp.item_id = inventory_item_id
                                   AND xssp.inv_org_id = organization_id
                                   AND GROUP_ID = p_group_id
                                   AND error_flag IS NOT NULL)
                   AND xssp.GROUP_ID = p_group_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Exception Occured while updating the processed status in staging table:'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Exception Occured while updating the interface status in staging table:'
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
    END update_interface_status;

    PROCEDURE submit_custom_table_upd_prg
    IS
        l_request_id   NUMBER;
        l_phase        VARCHAR2 (100);
        l_status       VARCHAR2 (30);
        l_dev_phase    VARCHAR2 (100);
        l_dev_status   VARCHAR2 (100);
        l_wait_req     BOOLEAN;
        l_message      VARCHAR2 (2000);
    BEGIN
        l_request_id   :=
            fnd_request.submit_request (application => 'XXDO', program => 'XXDO_CST_SUBELE_LOAD_TO_CUSTOM', start_time => SYSDATE
                                        , sub_request => FALSE);
        COMMIT;

        IF l_request_id = 0
        THEN
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    ' Unable to submit program: Sub Element Cost Upload to Custom Table - Deckers ');
        ELSE
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Sub Element Cost Upload to Custom Table - Deckers : program submitted successfully.');
            l_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => l_request_id, interval => 5, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status
                                                 , MESSAGE => l_message);
            COMMIT;

            IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Sub Element Cost Upload to Custom Table - Deckers: program with the request id '
                        || l_request_id
                        || ' completed with NORMAL status.');
            ELSE
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Sub Element Cost Upload to Custom Table - Deckers: program with the request id '
                        || l_request_id
                        || ' did not complete with NORMAL status.');
            END IF;
        -- End of if to check if the status is normal and phase is complete
        END IF;                      -- End of if to check if request ID is 0.

        COMMIT;
    END submit_custom_table_upd_prg;

    PROCEDURE insert_into_interface (errbuff   OUT VARCHAR2,
                                     retcode   OUT VARCHAR2)
    IS
        CURSOR c_subelements IS
            SELECT *
              FROM xxdo.xxdocst_stage_std_pending_cst
             WHERE status = 'V';

        l_group_id            NUMBER;
        l_price               NUMBER;
        l_cost_err_msg        VARCHAR2 (4000);
        l_cost_err_code       VARCHAR2 (4000);
        l_err_msg             VARCHAR2 (4000);
        l_duty_basis          NUMBER;
        l_freight_basis       NUMBER;
        l_oh_duty_basis       NUMBER;
        l_oh_nonduty_basis    NUMBER;
        l_freight_du_basis    NUMBER;
        l_int_req_id          NUMBER;
        p_errbuff             VARCHAR2 (4000);
        p_retcode             VARCHAR2 (4000);
        l_no_item             NUMBER;
        l_int_err             NUMBER;
        l_processed           NUMBER;
        l_total               NUMBER;
        v_interfaced          VARCHAR2 (1);
        v_processed           VARCHAR2 (1);
        l_validate_err_msg    VARCHAR2 (4000);
        user_exception        EXCEPTION;
        l_insert_count        NUMBER := 0;
        l_duplicate_records   NUMBER := 0;
        l_item_tbl_typ        ego_item_pub.item_tbl_type;
        api_index             NUMBER := 0;
    BEGIN
        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'Truncating table CST_ITEM_CST_DTLS_INTERFACE.. ');

        EXECUTE IMMEDIATE 'truncate table BOM.CST_ITEM_CST_DTLS_INTERFACE';


        BEGIN
            SELECT cc.cost_element_id
              INTO gn_cost_element_id
              FROM cst_cost_elements cc
             WHERE UPPER (cc.cost_element) = 'MATERIAL OVERHEAD';

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'cost element id for material_overhead is -'
                    || gn_cost_element_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Error while fetching cost element id '
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
                RAISE user_exception;
        END;

        FOR i IN c_subelements
        LOOP
            l_group_id       := i.GROUP_ID;
            l_insert_count   := l_insert_count + 1;
            l_price          := 0;

            BEGIN
                SELECT default_basis_type
                  INTO l_freight_basis
                  FROM bom_resources_v
                 WHERE     cost_element_id = gn_cost_element_id
                       AND resource_code = gc_freight
                       AND organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_freight_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_duty_basis
                  FROM bom_resources_v
                 WHERE     cost_element_id = gn_cost_element_id
                       AND resource_code = gc_duty
                       AND organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_duty_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_oh_duty_basis
                  FROM bom_resources_v
                 WHERE     cost_element_id = gn_cost_element_id
                       AND resource_code = gc_oh_duty
                       AND organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_oh_duty_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_oh_nonduty_basis
                  FROM bom_resources_v
                 WHERE     cost_element_id = gn_cost_element_id
                       AND resource_code = gc_oh_nonduty
                       AND organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_oh_nonduty_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_freight_du_basis
                  FROM bom_resources_v
                 WHERE     cost_element_id = gn_cost_element_id
                       AND resource_code = gc_freight_du
                       AND organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_freight_du_basis   := 1;
            END;

            IF i.duty IS NOT NULL
            THEN
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.item_id, i.inv_org_id, gc_duty,
                             i.duty, gn_cost_element_id, gc_cost_type,
                             l_duty_basis, gn_process_flag, SYSDATE,
                             1, SYSDATE, fnd_global.user_id,
                             l_group_id);
            END IF;

            IF i.freight IS NOT NULL
            THEN
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.item_id, i.inv_org_id, gc_freight,
                             i.freight, gn_cost_element_id, gc_cost_type,
                             l_freight_basis, gn_process_flag, SYSDATE,
                             1, SYSDATE, fnd_global.user_id,
                             l_group_id);
            END IF;

            IF i.oh_duty IS NOT NULL
            THEN
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.item_id, i.inv_org_id, gc_oh_duty,
                             i.oh_duty, gn_cost_element_id, gc_cost_type,
                             l_oh_duty_basis, gn_process_flag, SYSDATE,
                             1, SYSDATE, fnd_global.user_id,
                             l_group_id);
            END IF;

            IF i.oh_nonduty IS NOT NULL
            THEN
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.item_id, i.inv_org_id, gc_oh_nonduty,
                             i.oh_nonduty, gn_cost_element_id, gc_cost_type,
                             l_oh_nonduty_basis, gn_process_flag, SYSDATE,
                             1, SYSDATE, fnd_global.user_id,
                             l_group_id);
            END IF;

            IF i.freight_du IS NOT NULL
            THEN
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.item_id, i.inv_org_id, gc_freight_du,
                             i.freight_du, gn_cost_element_id, gc_cost_type,
                             l_freight_du_basis, gn_process_flag, SYSDATE,
                             1, SYSDATE, fnd_global.user_id,
                             l_group_id);
            END IF;



            BEGIN
                SELECT list_price_per_unit
                  INTO l_price
                  FROM mtl_system_items_b msi
                 WHERE     msi.inventory_item_id = i.item_id
                       AND organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_price   := 1;
                    print_msg_prc (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'Error while fetching list price of the item '
                            || DBMS_UTILITY.format_error_stack ()
                            || DBMS_UTILITY.format_error_backtrace ());
            END;

            IF     (l_price = 0 OR l_price IS NULL)
               AND i.factory_cost IS NOT NULL
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'updating list_price_per_unit for item - '
                        || i.item_id
                        || ' in org - '
                        || i.inv_org_id);
                api_index                                      := api_index + 1;


                l_item_tbl_typ (api_index).transaction_type    := 'UPDATE';
                l_item_tbl_typ (api_index).inventory_item_id   := i.item_id;
                l_item_tbl_typ (api_index).organization_id     :=
                    i.inv_org_id;
                l_item_tbl_typ (api_index).list_price_per_unit   :=
                    i.factory_cost;
            END IF;

            IF l_insert_count >= 2000
            THEN
                COMMIT;
                l_insert_count   := 0;

                update_item_price (l_item_tbl_typ);
                api_index        := 0;
                l_item_tbl_typ.delete;
            END IF;
        END LOOP;

        update_item_price (l_item_tbl_typ);
        l_item_tbl_typ.delete;

        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst xssp
               SET xssp.status   = 'I'
             WHERE     EXISTS
                           (SELECT 1
                              FROM cst_item_cst_dtls_interface
                             WHERE     xssp.item_id = inventory_item_id
                                   AND xssp.inv_org_id = organization_id
                                   AND GROUP_ID = l_group_id
                                   AND error_flag IS NULL
                                   AND process_flag = 1)
                   AND xssp.GROUP_ID = l_group_id;



            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Exception Occured while updating status I to staging table:'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;


        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                'successfully inserted into interface table cst_item_cst_dtls_interface');

        BEGIN
            SELECT DISTINCT 'Y'
              INTO v_interfaced
              FROM xxdo.xxdocst_stage_std_pending_cst
             WHERE EXISTS
                       (SELECT DISTINCT status
                          FROM xxdo.xxdocst_stage_std_pending_cst
                         WHERE status = 'I');
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Exception Occured while fetching v_interfaced:'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
                v_interfaced   := 'N';
        END;

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'v_interfaced = ' || v_interfaced);

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'group_id = ' || l_group_id);

        IF v_interfaced = 'Y'
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'submitting Cost Import program');
            submit_cost_import_proc (p_errbuff, p_retcode, l_int_req_id,
                                     l_group_id);
            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'updating interfcae status into staging table');
            update_interface_status (l_int_req_id, l_group_id);
            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'submitting custom table update program');

            BEGIN
                SELECT DISTINCT 'Y'
                  INTO v_processed
                  FROM xxdo.xxdocst_stage_std_pending_cst
                 WHERE EXISTS
                           (SELECT DISTINCT status
                              FROM xxdo.xxdocst_stage_std_pending_cst
                             WHERE status = 'P');
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_msg_prc (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'Exception Occured while fetching v_interfaced:'
                            || DBMS_UTILITY.format_error_stack ()
                            || DBMS_UTILITY.format_error_backtrace ());
                    v_processed   := 'N';
            END;

            IF v_processed = 'Y'
            THEN
                /*
                -- Logic to purge successful records from interface table
                print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'Deleting Processed records from intercae table');


                  BEGIN
                     DELETE FROM cst_item_cst_dtls_interface
                           WHERE     GROUP_ID = l_group_id
                                 AND process_flag = 5
                                 AND error_flag IS NULL;



                     print_msg_prc (p_debug     => gc_debug_flag,p_message   =>SQL%ROWCOUNT
                        || ' processed records deleted from interface tables');
                     COMMIT;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'Error while deleting processed records from intercae table'
                           || DBMS_UTILITY.format_error_stack ()
                           || DBMS_UTILITY.format_error_backtrace ());
                  END

                */
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'submitting custom table upload program');
                submit_custom_table_upd_prg ();
            END IF;
        END IF;

        SELECT COUNT (*)
          INTO l_total
          FROM xxdo.xxdocst_stage_std_pending_cst
         WHERE     1 = 1
               AND (duty IS NOT NULL OR freight IS NOT NULL OR freight_du IS NOT NULL OR oh_duty IS NOT NULL OR oh_nonduty IS NOT NULL);

        SELECT COUNT (*)
          INTO l_processed
          FROM xxdo.xxdocst_stage_std_pending_cst
         WHERE status = 'P';

        SELECT COUNT (*)
          INTO l_no_item
          FROM xxdo.xxdocst_stage_std_pending_cst
         WHERE status = 'E' AND error_msg = 'Item not found';

        SELECT COUNT (*)
          INTO l_duplicate_records
          FROM xxdo.xxdocst_stage_std_pending_cst
         WHERE status = 'E' AND error_msg = 'Duplicate Record';

        SELECT COUNT (*)
          INTO l_int_err
          FROM xxdo.xxdocst_stage_std_pending_cst
         WHERE status = 'X';

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '---------------------------------------------------------------------------');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                Report Status                              ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '---------------------------------------------------------------------------');
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Total Number of records  - ' || l_total);
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Number of records failed during validation due to item not found- '
            || l_no_item);

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Number of records failed during validation due to duplicate records- '
            || l_duplicate_records);

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Number of records failed in interface table - ' || l_int_err);

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Number of records processed successfully - ' || l_processed);
    EXCEPTION
        WHEN user_exception
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'Cost element not found');
            retcode   := 2;
        WHEN OTHERS
        THEN
            retcode   := 2;
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OTHERS Exception in  insert_into_interface procedure -'
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
    END insert_into_interface;

    -- Commenting this procedure as Purge Program is not required any more
    /*PROCEDURE purge_custom_table (errbuff OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
       l_invalid_date_delete   NUMBER := 0;
       l_invalid_date_insert   NUMBER := 0;
       l_invalid_item_delete   NUMBER := 0;
       l_invalid_item_insert   NUMBER := 0;
       l_total_count           NUMBER;
       raise_exception         EXCEPTION;
    BEGIN
       INSERT INTO xxdo.xxdo_invval_duty_cost_backup
          SELECT *
            FROM xxdo.xxdo_invval_duty_cost
           WHERE duty_end_date < SYSDATE;

       l_invalid_date_insert := SQL%ROWCOUNT;
       print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'l_invalid_date_insert - ' || l_invalid_date_insert);

       DELETE FROM xxdo.xxdo_invval_duty_cost
             WHERE duty_end_date < SYSDATE;

       l_invalid_date_delete := SQL%ROWCOUNT;
       print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'l_invalid_date_delete - ' || l_invalid_date_delete);

       INSERT INTO xxdo.xxdo_invval_duty_cost_backup
          SELECT xi.*
            FROM xxdo.xxdo_invval_duty_cost xi, mtl_system_items_b msi
           WHERE     xi.inventory_item_id = msi.inventory_item_id
                 AND msi.enabled_flag = 'N';

       l_invalid_item_insert := SQL%ROWCOUNT;
       print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'l_invalid_item_insert - ' || l_invalid_item_insert);

       DELETE FROM xxdo.xxdo_invval_duty_cost
             WHERE inventory_item_id IN
                      (SELECT xi.inventory_item_id
                         FROM xxdo.xxdo_invval_duty_cost xi,
                              mtl_system_items_b msi
                        WHERE     xi.inventory_item_id = msi.inventory_item_id
                              AND msi.enabled_flag = 'N');

       l_invalid_item_delete := SQL%ROWCOUNT;
       print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'l_invalid_item_delete - ' || l_invalid_item_delete);

 -- logic for deletion of records, which have not been transacted in last x days
 --     INSERT INTO xxdo.xxdo_invval_duty_cost_backup
 --   select * from xxdo.xxdo_invval_duty_cost
 --   where (inventory_item_id, inventory_org) in
 --   (select  inventory_item_id, organization_id
 --   from mtl_material_transactions
 --   having max(last_update_date) <= sysdate -x
 --   Group by inventory_item_id, organization_id )
 --
 --  delete from xxdo.xxdo_invval_duty_cost
 --  where (inventory_item_id, inventory_org) in
 --  (select  inventory_item_id, organization_id
 -- from mtl_material_transactions
 -- having max(last_update_date) <= sysdate -x
 -- Group by inventory_item_id, organization_id )

       IF (   (l_invalid_item_insert <> l_invalid_item_delete)
           OR (l_invalid_date_insert <> l_invalid_date_delete))
       THEN
          RAISE raise_exception;
       ELSE
          COMMIT;
          l_total_count := l_invalid_date_delete + l_invalid_item_delete;
          print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'Number of records deleted - ' || l_total_count);
       END IF;
    EXCEPTION
       WHEN raise_exception
       THEN
          retcode := 2;
          print_msg_prc (p_debug     => gc_debug_flag,p_message   =>
                                  'Archive Failed, so delete rollbacked');
          ROLLBACK;
       WHEN OTHERS
       THEN
          retcode := 2;
          print_msg_prc (p_debug     => gc_debug_flag,p_message   =>'Others Exception in procedure purge_custom_table - '
             || DBMS_UTILITY.format_error_stack ()
             || DBMS_UTILITY.format_error_backtrace ());
          ROLLBACK;
    END purge_custom_table; */

    PROCEDURE insert_into_custom_table (errbuff   OUT VARCHAR2,
                                        retcode   OUT VARCHAR2)
    IS
        CURSOR cur_data IS
            SELECT ood.operating_unit, xp.county_of_origin, xp.prime_duty,
                   xp.oh_duty, xp.oh_nonduty, xp.additional_duty,
                   xp.inv_org_id inventory_org, xp.item_id, xp.duty,
                   xp.duty_start_date, xp.duty_end_date, xp.style_color
              FROM xxdo.xxdocst_stage_std_pending_cst xp, org_organization_definitions ood
             WHERE     1 = 1
                   AND ood.organization_code = xp.inventory_org
                   AND status IN ('P', 'C');

        TYPE cost_data_type IS TABLE OF cur_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        cost_data_tbl    cost_data_type;
        e_bulk_errors    EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_indx           NUMBER;
        l_insert_count   NUMBER := 0;
        l_update_count   NUMBER := 0;
        l_indx1          NUMBER;
        l_error_count    NUMBER;
        l_error_count1   NUMBER;
        l_msg            VARCHAR2 (4000);
        l_msg1           VARCHAR2 (4000);
        l_idx            NUMBER;
        l_idx1           NUMBER;
    BEGIN
        OPEN cur_data;

        cost_data_tbl.delete;

        LOOP
            FETCH cur_data BULK COLLECT INTO cost_data_tbl LIMIT g_limit;

            EXIT WHEN cost_data_tbl.COUNT = 0;

            BEGIN
                FORALL l_indx1 IN 1 .. cost_data_tbl.COUNT SAVE EXCEPTIONS
                    UPDATE xxdo.xxdo_invval_duty_cost idc
                       SET idc.last_update_date = SYSDATE, idc.last_updated_by = NVL ((SELECT TO_NUMBER (apps.fnd_profile.VALUE ('user_id')) FROM DUAL), -1), idc.duty_start_date = NVL (idc.duty_start_date, '01-JAN-1952'),
                           idc.duty_end_date = NVL (cost_data_tbl (l_indx1).duty_start_date, TRUNC (SYSDATE)) - 1
                     WHERE     idc.inventory_org =
                               cost_data_tbl (l_indx1).inventory_org
                           AND idc.inventory_item_id =
                               cost_data_tbl (l_indx1).item_id
                           -- Start modification by BT Technology Team for Defect#598 on 08-Dec-2015
                           AND NVL (idc.country_of_origin, -1) =
                               NVL (cost_data_tbl (l_indx1).county_of_origin,
                                    -1)
                           -- End modification by BT Technology Team for Defect#598 on 08-Dec-2015
                           AND NVL (
                                   idc.duty_end_date,
                                   NVL (
                                       cost_data_tbl (l_indx1).duty_start_date,
                                       TRUNC (SYSDATE))) >=
                               NVL (cost_data_tbl (l_indx1).duty_start_date,
                                    TRUNC (SYSDATE));

                /*          INSERT INTO xxdo.xxdo_invval_duty_cost (operating_unit,
                                                                  country_of_origin,
                                                                  primary_duty_flag,
                                                                  oh_duty,
                                                                  oh_nonduty,
                                                                  additional_duty,
                                                                  inventory_org,
                                                                  inventory_item_id,
                                                                  duty,
                                                                  last_update_date,
                                                                  last_updated_by,
                                                                  creation_date,
                                                                  created_by,
                                                                  duty_start_date,
                                                                  duty_end_date,
                                                                  style_color)
                               VALUES (cost_data_tbl (l_indx1).operating_unit,
                                       cost_data_tbl (l_indx1).county_of_origin,
                                       cost_data_tbl (l_indx1).prime_duty,
                                       cost_data_tbl (l_indx1).oh_duty,
                                       cost_data_tbl (l_indx1).oh_nonduty,
                                       cost_data_tbl (l_indx1).additional_duty,
                                       cost_data_tbl (l_indx1).inventory_org,
                                       cost_data_tbl (l_indx1).item_id,
                                       cost_data_tbl (l_indx1).duty,
                                       SYSDATE,
                                       fnd_global.user_id,
                                       SYSDATE,
                                       fnd_global.user_id,
                                       cost_data_tbl (l_indx1).duty_start_date,
                                       cost_data_tbl (l_indx1).duty_end_date,
                                       cost_data_tbl (l_indx1).style_color);*/

                l_update_count   := l_update_count + SQL%ROWCOUNT;
            EXCEPTION
                WHEN e_bulk_errors
                THEN
                    print_msg_prc (p_debug     => gc_debug_flag,
                                   p_message   => 'Inside E_BULK_ERRORS');
                    l_error_count1   := SQL%BULK_EXCEPTIONS.COUNT;

                    FOR i IN 1 .. l_error_count1
                    LOOP
                        l_msg1   :=
                            SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                        l_idx1   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                        print_msg_prc (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   'Failed to update item -'
                                || cost_data_tbl (l_idx1).item_id
                                || ' for org - '
                                || cost_data_tbl (l_idx1).inventory_org
                                || ' with error_code- '
                                || l_msg1);
                    END LOOP;
                WHEN OTHERS
                THEN
                    print_msg_prc (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'Inside Others for header update. '
                            || DBMS_UTILITY.format_error_stack ()
                            || DBMS_UTILITY.format_error_backtrace ());
            END;
        END LOOP;

        CLOSE cur_data;

        COMMIT;
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                   'succesfully updated '
                || l_update_count
                || ' records into table xxdo_invval_duty_cost');

        fnd_file.put_line (
            fnd_file.output,
               'succesfully updated '
            || l_update_count
            || ' records into table xxdo_invval_duty_cost');


        OPEN cur_data;

        cost_data_tbl.delete;

        LOOP
            FETCH cur_data BULK COLLECT INTO cost_data_tbl LIMIT g_limit;

            EXIT WHEN cost_data_tbl.COUNT = 0;

            BEGIN
                FORALL l_indx IN 1 .. cost_data_tbl.COUNT SAVE EXCEPTIONS
                    /*      UPDATE xxdo.xxdo_invval_duty_cost idc
                             SET idc.Last_update_date = SYSDATE,
                                 idc.Last_updated_by =
                                    NVL (
                                       (SELECT TO_NUMBER (
                                                  apps.fnd_profile.
                                                  VALUE ('user_id'))
                                          FROM DUAL),
                                       -1),
                                 idc.Duty_start_date =
                                    NVL (idc.Duty_start_date, '01-JAN-1952'),
                                 idc.Duty_end_date =
                                    NVL (cost_data_tbl (l_indx).duty_start_date,
                                         TRUNC (SYSDATE - 1))
                           WHERE idc.inventory_org = cost_data_tbl (l_indx).inventory_org
                                 AND idc.inventory_item_id = cost_data_tbl (l_indx).item_id
                                 AND NVL(idc.duty_end_date,TRUNC(SYSDATE)) >= NVL (cost_data_tbl (l_indx).duty_start_date,TRUNC (SYSDATE));
                                 */
                    INSERT INTO xxdo.xxdo_invval_duty_cost (operating_unit, country_of_origin, primary_duty_flag, oh_duty, oh_nonduty, additional_duty, inventory_org, inventory_item_id, duty, last_update_date, last_updated_by, creation_date, created_by, duty_start_date, duty_end_date
                                                            , style_color)
                         VALUES (cost_data_tbl (l_indx).operating_unit, cost_data_tbl (l_indx).county_of_origin, cost_data_tbl (l_indx).prime_duty, cost_data_tbl (l_indx).oh_duty, cost_data_tbl (l_indx).oh_nonduty, cost_data_tbl (l_indx).additional_duty, cost_data_tbl (l_indx).inventory_org, cost_data_tbl (l_indx).item_id, cost_data_tbl (l_indx).duty, SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id, cost_data_tbl (l_indx).duty_start_date, cost_data_tbl (l_indx).duty_end_date
                                 , cost_data_tbl (l_indx).style_color);

                l_insert_count   := l_insert_count + SQL%ROWCOUNT;
            EXCEPTION
                WHEN e_bulk_errors
                THEN
                    print_msg_prc (p_debug     => gc_debug_flag,
                                   p_message   => 'Inside E_BULK_ERRORS');
                    l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                    FOR i IN 1 .. l_error_count
                    LOOP
                        l_msg   :=
                            SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                        l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                        print_msg_prc (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   'Failed to insert item -'
                                || cost_data_tbl (l_idx).item_id
                                || ' for org - '
                                || cost_data_tbl (l_idx).inventory_org
                                || ' with error_code- '
                                || l_msg);
                    END LOOP;
                WHEN OTHERS
                THEN
                    print_msg_prc (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'Inside Others for header insert. '
                            || DBMS_UTILITY.format_error_stack ()
                            || DBMS_UTILITY.format_error_backtrace ());
            END;
        END LOOP;

        CLOSE cur_data;

        COMMIT;
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                   'succesfully inserted '
                || l_insert_count
                || ' records into table xxdo_invval_duty_cost');

        fnd_file.put_line (
            fnd_file.output,
               'succesfully inserted '
            || l_insert_count
            || ' records into table xxdo_invval_duty_cost');
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OTHERS exception in insert_into_custom_table- '
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
    END insert_into_custom_table;

    PROCEDURE custom_table_report (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_item_id NUMBER, p_style_color VARCHAR2, p_creation_date VARCHAR2
                                   , p_end_date VARCHAR2)
    IS
        CURSOR i_display (p_start DATE, p_end DATE)
        IS
            --Start changes by BT Technology team on 08-JUL-2015 v1.3
            /*SELECT *
              FROM xxdo.xxdo_invval_duty_cost
             WHERE     inventory_org = NVL (p_org_id, inventory_org)
                   AND inventory_item_id = NVL (p_item_id, inventory_item_id)
                   AND style_color = NVL (p_style_color, style_color)
                   AND creation_date BETWEEN p_start AND p_end;*/
            SELECT hou.name operating_unit, xidc.country_of_origin, xidc.primary_duty_flag,
                   xidc.oh_duty, xidc.oh_nonduty, xidc.additional_duty,
                   mp.organization_code inventory_org, xidc.inventory_item_id, xidc.duty,
                   xidc.duty_start_date, xidc.duty_end_date, xciv.style_number || '-' || xciv.color_code || '-' || xciv.item_size style_color,
                   xidc.last_update_date, fnu2.user_name last_updated_by, xidc.creation_date,
                   fnu1.user_name created_by
              FROM xxdo.xxdo_invval_duty_cost xidc, mtl_parameters mp, hr_operating_units hou,
                   xxd_common_items_v xciv, fnd_user fnu1, fnd_user fnu2
             WHERE     xidc.inventory_org = NVL (p_org_id, inventory_org)
                   AND xidc.inventory_item_id =
                       NVL (p_item_id, xidc.inventory_item_id)
                   AND xidc.inventory_org = mp.organization_id
                   AND xidc.operating_unit = hou.organization_id
                   AND xidc.inventory_item_id = xciv.inventory_item_id
                   AND xidc.inventory_org = xciv.organization_id
                   AND xidc.created_by = fnu1.user_id
                   AND xidc.last_updated_by = fnu2.user_id
                   AND style_color = NVL (p_style_color, style_color)
                   AND xidc.creation_date BETWEEN p_start AND p_end;

        --End changes by BT Technology Team on 08-JUL-2015  v1.3

        l_output       VARCHAR2 (4000);
        l_end_date     DATE;
        l_start_date   DATE;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'p_from_date = ' || p_creation_date);
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'p_to_date = ' || p_end_date);
        l_end_date     := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
        l_start_date   := TO_DATE (p_creation_date, 'YYYY/MM/DD HH24:MI:SS');
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'l_start_date = ' || l_start_date);
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'l_end_date = ' || l_end_date);
        l_output       :=
               'OPERATING_UNIT'
            || CHR (9)
            || 'COUNTRY_OF_ORIGIN'
            || CHR (9)
            || 'PRIMARY_DUTY_FLAG'
            || CHR (9)
            || 'OH_DUTY'
            || CHR (9)
            || 'OH_NONDUTY'
            || CHR (9)
            || 'ADDITIONAL_DUTY'
            || CHR (9)
            || 'INVENTORY_ORG'
            || CHR (9)
            || 'INVENTORY_ITEM_ID'
            || CHR (9)
            || gc_duty
            || CHR (9)
            || 'DUTY_START_DATE'
            || CHR (9)
            || 'DUTY_END_DATE'
            || CHR (9)
            || 'STYLE_COLOR'
            || CHR (9)
            || 'LAST_UPDATE_DATE'
            || CHR (9)
            || 'LAST_UPDATED_BY'
            || CHR (9)
            || 'CREATION_DATE'
            || CHR (9)
            || 'CREATED_BY';
        apps.fnd_file.put_line (apps.fnd_file.output, l_output);

        FOR i IN i_display (l_start_date, l_end_date)
        LOOP
            l_output   :=
                   RPAD (i.operating_unit, 14)
                || CHR (9)
                || RPAD (i.country_of_origin, 16)
                || CHR (9)
                || RPAD (i.primary_duty_flag, 17)
                || CHR (9)
                || RPAD (i.oh_duty, 7)
                || CHR (9)
                || RPAD (i.oh_nonduty, 10)
                || CHR (9)
                || RPAD (i.additional_duty, 15)
                || CHR (9)
                || RPAD (i.inventory_org, 13)
                || CHR (9)
                || RPAD (i.inventory_item_id, 17)
                || CHR (9)
                || RPAD (i.duty, 4)
                || CHR (9)
                || RPAD (i.duty_start_date, 15)
                || CHR (9)
                || RPAD (i.duty_end_date, 13)
                || CHR (9)
                || RPAD (i.style_color, 20)
                || CHR (9)
                || RPAD (i.last_update_date, 16)
                || CHR (9)
                || RPAD (i.last_updated_by, 15)
                || CHR (9)
                || RPAD (i.creation_date, 13)
                || CHR (9)
                || RPAD (i.created_by, 10);
            apps.fnd_file.put_line (apps.fnd_file.output, l_output);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OTHERS exception in procedure custom_table_report- '
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
    END custom_table_report;

    --Commented by BT Technology Team on 27-Nov-2014
    /*
 Procedure  item_cost_insert( errbuf               OUT VARCHAR2,
                              retcode              OUT VARCHAR2,
                              pv_insert               IN  VARCHAR2) IS

 Cursor C_COST IS
       select
         STYLE_COLOR
        ,WHSE
        ,STYLE
        ,COLOR
        ,SZE
        ,FACTORY_COST
        ,DUTY
        ,FREIGHT
        ,OH
        ,TOTAL_COST
        from xxdo.XXDO_COST_EXT_TABLE_CSV;

  lv_output Varchar2(4000);

 Begin

 EXECUTE IMMEDIATE 'truncate table XXDO.XXDOCST_STAGE_STD_PENDING_CST';

         lv_output :=    'STYLE_COLOR'       || CHR(9)
                         ||'WHSE'              || CHR(9)
                         ||'STYLE'             || CHR(9)
                         ||'COLOR'             || CHR(9)
                         ||'SIZE'              || CHR(9)
                         ||'FACTORY_COST'      || CHR(9)
                         ||gc_duty              || CHR(9)
                         ||gc_freight           || CHR(9)
                         ||'OH'                || CHR(9)
                         ||'TOTAL_COST';

         apps.Fnd_File.PUT_LINE(apps.Fnd_File.OUTPUT,lv_output);



     For i IN C_COST Loop

          if pv_insert ='Y' Then
         INSERT INTO XXDO.XXDOCST_STAGE_STD_PENDING_CST
                 (STYLECOLOR
                ,ORGANIZATION_CODE
                ,STYLE
                ,COLOR
                ,SZE
                ,MATERIAL_COST
                ,DUTY
                ,FREIGHT
                ,OH
                ,TOTAL)
         VALUES
                 ( i.STYLE_COLOR
                ,i.WHSE
                ,i.STYLE
                ,i.COLOR
                ,i.SZE
                ,to_number(i.FACTORY_COST)
                ,to_number(i.DUTY)
                ,to_number(i.FREIGHT)
                ,to_number(i.OH)
                ,to_number(i.TOTAL_COST));

         lv_output :=    i.STYLE_COLOR                       || CHR(9)
                         ||i.WHSE                            || CHR(9)
                         ||i.STYLE                           || CHR(9)
                         ||i.COLOR                           || CHR(9)
                         ||i.SZE                             || CHR(9)
                         ||to_number(i.FACTORY_COST)         || CHR(9)
                         ||to_number(i.DUTY)                 || CHR(9)
                         ||to_number(i.FREIGHT)              || CHR(9)
                         ||to_number(i.OH)                   || CHR(9)
                         ||to_number(i.TOTAL_COST);

         apps.Fnd_File.PUT_LINE(apps.Fnd_File.OUTPUT, lv_output);
         commit;

     else
         lv_output :=    i.STYLE_COLOR                       || CHR(9)
                         ||i.WHSE                            || CHR(9)
                         ||i.STYLE                           || CHR(9)
                         ||i.COLOR                           || CHR(9)
                         ||i.SZE                             || CHR(9)
                         ||to_number(i.FACTORY_COST)         || CHR(9)
                         ||to_number(i.DUTY)                 || CHR(9)
                         ||to_number(i.FREIGHT)              || CHR(9)
                         ||to_number(i.OH)                   || CHR(9)
                         ||to_number(i.TOTAL_COST);

         apps.Fnd_File.PUT_LINE(apps.Fnd_File.OUTPUT, lv_output);
     End if;
     End Loop;


 Exception
 WHEN NO_DATA_FOUND THEN
     --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Program Terminated Abruptly');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'All Data is Not Processed');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'NO_DATA_FOUND');
     errbuf      := 'No Data Found' || SQLCODE || SQLERRM;
     retcode     := -1;

   WHEN INVALID_CURSOR THEN
    -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Program Terminated Abruptly');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'All Data is Not Processed');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'INVALID_CURSOR');
     errbuf    := 'Invalid Cursor' || SQLCODE || SQLERRM;
     retcode    := -2;

   WHEN TOO_MANY_ROWS THEN
 --    DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Program Terminated Abruptly');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'All Data is Not Processed');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'TOO_MANY_ROWS');
     errbuf    := 'Too Many Rows' || SQLCODE || SQLERRM;
     retcode    := -3;

   WHEN PROGRAM_ERROR THEN
 --    DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Program Terminated Abruptly');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'All Data is Not Processed');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'PROGRAM_ERROR');
     errbuf    := 'Program Error' || SQLCODE || SQLERRM;
     retcode    := -4;

   WHEN OTHERS THEN
 --    DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Program Terminated Abruptly');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'All Data is Not Processed');
     apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'OTHERS');
     errbuf     := 'Unhandled Error' || SQLCODE || SQLERRM;
     retcode    := -5;
 END item_cost_insert;
 */
    --Added by BT Technology Team on 27-Nov-2014
    PROCEDURE item_cost_insert (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
        CURSOR c_cost IS
            SELECT style,
                   SUBSTR (a.item,
                           1,
                             INSTR (a.item, '-', 1,
                                    2)
                           - 1)
                       style_color,
                   inventory_org,
                   item,
                   county_of_origin,
                   duty
                       file_duty,
                   NVL (
                       duty,
                       get_resource_rate (
                           get_item_org_id (a.item, a.inventory_org, 'ITEM'),
                           get_item_org_id (a.item, a.inventory_org, 'ORG'),
                           gc_duty))
                       duty,
                   prime_duty,
                   duty_start_date,
                   duty_end_date,
                   freight
                       file_freight,
                   NVL (
                       freight,
                       get_resource_rate (
                           get_item_org_id (a.item, a.inventory_org, 'ITEM'),
                           get_item_org_id (a.item, a.inventory_org, 'ORG'),
                           gc_freight))
                       freight,
                   freight_du
                       file_freight_du,
                   NVL (
                       freight_du,
                       get_resource_rate (
                           get_item_org_id (a.item, a.inventory_org, 'ITEM'),
                           get_item_org_id (a.item, a.inventory_org, 'ORG'),
                           gc_freight_du))
                       freight_du,
                   oh_duty
                       file_oh_duty,
                   NVL (
                       oh_duty,
                       get_resource_rate (
                           get_item_org_id (a.item, a.inventory_org, 'ITEM'),
                           get_item_org_id (a.item, a.inventory_org, 'ORG'),
                           gc_oh_duty))
                       oh_duty,
                   oh_nonduty
                       file_oh_nonduty,
                   NVL (
                       oh_nonduty,
                       get_resource_rate (
                           get_item_org_id (a.item, a.inventory_org, 'ITEM'),
                           get_item_org_id (a.item, a.inventory_org, 'ORG'),
                           gc_oh_nonduty))
                       oh_nonduty,
                   factory_cost,
                   additional_duty,
                   tarrif_code,
                   country,
                   default_category,
                   get_item_org_id (a.item, a.inventory_org, 'ITEM')
                       inv_item_id,
                   get_item_org_id (a.item, a.inventory_org, 'ORG')
                       inv_org_id
              FROM xxdo.xxdo_cost_ext_table_csv a
             WHERE a.item IS NOT NULL
            UNION
            SELECT style, style_color, inventory_org,
                   msib.segment1, county_of_origin, duty file_duty,
                   NVL (duty, get_resource_rate (msib.inventory_item_id, msib.organization_id, gc_duty)) duty, prime_duty, duty_start_date,
                   duty_end_date, freight file_freight, NVL (freight, get_resource_rate (msib.inventory_item_id, msib.organization_id, gc_freight)) freight,
                   freight_du file_freight_du, NVL (freight_du, get_resource_rate (msib.inventory_item_id, msib.organization_id, gc_freight_du)) freight_du, oh_duty file_oh_duty,
                   NVL (oh_duty, get_resource_rate (msib.inventory_item_id, msib.organization_id, gc_oh_duty)) oh_duty, oh_nonduty file_oh_nonduty, NVL (oh_nonduty, get_resource_rate (msib.inventory_item_id, msib.organization_id, gc_oh_nonduty)) oh_nonduty,
                   factory_cost, additional_duty, tarrif_code,
                   country, default_category, msib.inventory_item_id,
                   msib.organization_id
              FROM xxdo.xxdo_cost_ext_table_csv a, mtl_system_items_b msib, mtl_parameters mp
             WHERE     a.item IS NULL
                   AND a.style_color IS NOT NULL
                   AND a.style_color = SUBSTR (msib.segment1,
                                               1,
                                                 INSTR (msib.segment1, '-', 1
                                                        , 2)
                                               - 1)
                   AND mp.organization_code = a.inventory_org
                   AND mp.organization_id = msib.organization_id
                   AND msib.attribute27 <> 'ALL'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_cost_ext_table_csv b
                             WHERE     b.item IS NOT NULL
                                   AND b.item = msib.segment1)
            UNION
            SELECT style,
                   SUBSTR (msib.segment1,
                           1,
                             INSTR (msib.segment1, '-', 1,
                                    2)
                           - 1) style_color,
                   inventory_org,
                   msib.segment1,
                   county_of_origin,
                   duty file_duty,
                   NVL (
                       duty,
                       get_resource_rate (msib.inventory_item_id,
                                          msib.organization_id,
                                          gc_duty)) duty,
                   prime_duty,
                   duty_start_date,
                   duty_end_date,
                   freight file_freight,
                   NVL (
                       freight,
                       get_resource_rate (msib.inventory_item_id,
                                          msib.organization_id,
                                          gc_freight)) freight,
                   freight_du file_freight_du,
                   NVL (
                       freight_du,
                       get_resource_rate (msib.inventory_item_id,
                                          msib.organization_id,
                                          gc_freight_du)) freight_du,
                   oh_duty file_oh_duty,
                   NVL (
                       oh_duty,
                       get_resource_rate (msib.inventory_item_id,
                                          msib.organization_id,
                                          gc_oh_duty)) oh_duty,
                   oh_nonduty file_oh_nonduty,
                   NVL (
                       oh_nonduty,
                       get_resource_rate (msib.inventory_item_id,
                                          msib.organization_id,
                                          gc_oh_nonduty)) oh_nonduty,
                   factory_cost,
                   additional_duty,
                   tarrif_code,
                   country,
                   default_category,
                   msib.inventory_item_id,
                   msib.organization_id
              FROM xxdo.xxdo_cost_ext_table_csv a, mtl_system_items_b msib, mtl_parameters mp
             WHERE     a.item IS NULL
                   AND a.style_color IS NULL
                   AND a.style IS NOT NULL
                   AND a.style = SUBSTR (msib.segment1,
                                         1,
                                           INSTR (msib.segment1, '-', 1,
                                                  1)
                                         - 1)
                   AND mp.organization_code = a.inventory_org
                   AND mp.organization_id = msib.organization_id
                   AND msib.attribute27 <> 'ALL'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_cost_ext_table_csv b
                             WHERE b.item = msib.segment1)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_cost_ext_table_csv b
                             WHERE b.style_color = SUBSTR (msib.segment1,
                                                           1,
                                                             INSTR (msib.segment1, '-', 1
                                                                    , 2)
                                                           - 1));



        TYPE cost_record_type IS TABLE OF c_cost%ROWTYPE
            INDEX BY BINARY_INTEGER;

        rec_cost_tbl     cost_record_type;
        lv_output        VARCHAR2 (4000);
        l_insert_count   NUMBER := 0;
        e_bulk_errors    EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_indx           NUMBER;
        l_error_count    NUMBER := 0;
        l_msg            VARCHAR2 (4000);
        l_idx            NUMBER;
        l_group_id       NUMBER := xxdocst_stage_std_pending_seq.NEXTVAL;
        xv_errbuf        VARCHAR2 (4000);
        xn_retcode       NUMBER;
        user_exception   EXCEPTION;
    BEGIN
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                'Truncating table XXDO.XXDOCST_STAGE_STD_PENDING_CST.. ');

        EXECUTE IMMEDIATE 'truncate table XXDO.XXDOCST_STAGE_STD_PENDING_CST';

        BEGIN
            SELECT cc.cost_element_id
              INTO gn_cost_element_id
              FROM cst_cost_elements cc
             WHERE UPPER (cc.cost_element) = 'MATERIAL OVERHEAD';

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'cost element id for material_overhead is -'
                    || gn_cost_element_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Error while fetching cost element id '
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
                RAISE user_exception;
        END;

        BEGIN
            SELECT cost_type_id
              INTO gn_cost_type_id
              FROM cst_cost_types
             WHERE cost_type = gc_cost_type;

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'cost type id for AvgRates is -' || gn_cost_type_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Error while fetching cost type id for AvgRates'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
                RAISE user_exception;
        END;

        OPEN c_cost;

        rec_cost_tbl.delete;

        LOOP
            FETCH c_cost BULK COLLECT INTO rec_cost_tbl LIMIT g_limit;

            EXIT WHEN rec_cost_tbl.COUNT = 0;

            BEGIN
                FORALL l_indx IN 1 .. rec_cost_tbl.COUNT SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxdocst_stage_std_pending_cst (
                                    style,
                                    style_color,
                                    inventory_org,
                                    item,
                                    county_of_origin,
                                    file_duty,
                                    duty,
                                    prime_duty,
                                    duty_start_date,
                                    duty_end_date,
                                    file_freight,
                                    freight,
                                    file_freight_du,
                                    freight_du,
                                    file_oh_duty,
                                    oh_duty,
                                    file_oh_nonduty,
                                    oh_nonduty,
                                    factory_cost,
                                    additional_duty,
                                    status,
                                    tarrif_code,
                                    country,
                                    default_category,
                                    item_id,
                                    inv_org_id,
                                    status_category,
                                    GROUP_ID)
                         VALUES (TRIM (rec_cost_tbl (l_indx).style), TRIM (rec_cost_tbl (l_indx).style_color), TRIM (rec_cost_tbl (l_indx).inventory_org), TRIM (rec_cost_tbl (l_indx).item), TRIM (rec_cost_tbl (l_indx).county_of_origin), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).file_duty)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).duty)), TRIM (rec_cost_tbl (l_indx).prime_duty), --Start Changes for defect 2712
                                                                                                                                                                                                                                                                                                                                                                                         /*TO_DATE (
                                                                                                                                                                                                                                                                                                                                                                                            TRIM (rec_cost_tbl (l_indx).duty_start_date),
                                                                                                                                                                                                                                                                                                                                                                                            'dd/mm/yyyy'),
                                                                                                                                                                                                                                                                                                                                                                                         TO_DATE (TRIM (rec_cost_tbl (l_indx).duty_end_date),
                                                                                                                                                                                                                                                                                                                                                                                                  'dd/mm/yyyy'),*/

                                                                                                                                                                                                                                                                                                                                                                                         TO_DATE (TRIM (rec_cost_tbl (l_indx).duty_start_date), 'mm/dd/yyyy'), TO_DATE (TRIM (rec_cost_tbl (l_indx).duty_end_date), 'mm/dd/yyyy'), --End Changes for defect 2712
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   TO_NUMBER (TRIM (rec_cost_tbl (l_indx).file_freight)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).freight)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).file_freight_du)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).freight_du)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).file_oh_duty)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).oh_duty)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).file_oh_nonduty)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).oh_nonduty)), TO_NUMBER (TRIM (rec_cost_tbl (l_indx).factory_cost)), TO_NUMBER (REPLACE (REPLACE (rec_cost_tbl (l_indx).additional_duty, CHR (13), ''), CHR (10), '')), 'N', TRIM (rec_cost_tbl (l_indx).tarrif_code), TRIM (rec_cost_tbl (l_indx).country), TRIM (REPLACE (REPLACE (rec_cost_tbl (l_indx).default_category, CHR (13), ''), CHR (10), '')), rec_cost_tbl (l_indx).inv_item_id, rec_cost_tbl (l_indx).inv_org_id, 'N'
                                 , l_group_id);

                l_insert_count   := l_insert_count + SQL%ROWCOUNT;
                COMMIT;
            EXCEPTION
                WHEN e_bulk_errors
                THEN
                    print_msg_prc (p_debug     => gc_debug_flag,
                                   p_message   => 'Inside E_BULK_ERRORS');
                    l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                    FOR i IN 1 .. l_error_count
                    LOOP
                        l_msg   :=
                            SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                        l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                        print_msg_prc (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   'Failed to insert item -'
                                || rec_cost_tbl (l_idx).item
                                || ' for  org  -'
                                || rec_cost_tbl (l_idx).inventory_org
                                || ' with error_code- '
                                || l_msg);
                    END LOOP;
                WHEN OTHERS
                THEN
                    print_msg_prc (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'Inside Others for header insert. '
                            || DBMS_UTILITY.format_error_stack ()
                            || DBMS_UTILITY.format_error_backtrace ());
            END;
        END LOOP;

        CLOSE c_cost;

        COMMIT;



        apps.fnd_file.put_line (
            apps.fnd_file.output,
               l_insert_count
            || ' Records inserted into table xxdo.xxdocst_stage_std_pending_cst');

        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status = 'E', error_msg = 'Item not found'
             WHERE     item_id IS NULL
                   AND (duty IS NOT NULL OR freight IS NOT NULL OR freight_du IS NOT NULL OR oh_duty IS NOT NULL OR oh_nonduty IS NOT NULL)
                   AND status = 'N';


            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   SQL%ROWCOUNT
                || ' subelement records updated with error - item not found');


            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status_category = 'E', errmsg_category = 'Item not found'
             WHERE     item_id IS NULL
                   AND (tarrif_code IS NOT NULL OR country IS NOT NULL OR default_category IS NOT NULL)
                   AND status_category = 'N';

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   SQL%ROWCOUNT
                || ' category records updated with error - item not found');
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Error while updating item_not_found status'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;

        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status   = 'C'
             WHERE     prime_duty = 'N'
                   AND (duty IS NOT NULL OR freight IS NOT NULL OR freight_du IS NOT NULL OR oh_duty IS NOT NULL OR oh_nonduty IS NOT NULL);

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                SQL%ROWCOUNT || ' subelement records have non-primary duty');
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Error while updating non-primary record status'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status = 'E', error_msg = 'Duplicate Record'
             WHERE     (item, inventory_org) IN
                           (  SELECT item, inventory_org
                                FROM xxdo.xxdocst_stage_std_pending_cst
                               WHERE 1 = 1 AND status = 'N'
                            GROUP BY item, inventory_org
                              HAVING COUNT (1) > 1)
                   AND status = 'N'
                   AND (duty IS NOT NULL OR freight IS NOT NULL OR freight_du IS NOT NULL OR oh_duty IS NOT NULL OR oh_nonduty IS NOT NULL);

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   SQL%ROWCOUNT
                || ' subelement records updated with error - Duplicate Records');

            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status_category = 'E', errmsg_category = 'Duplicate Record'
             WHERE     (item, inventory_org) IN
                           (  SELECT item, inventory_org
                                FROM xxdo.xxdocst_stage_std_pending_cst
                            GROUP BY item, inventory_org
                              HAVING COUNT (1) > 1)
                   AND (tarrif_code IS NOT NULL OR country IS NOT NULL OR default_category IS NOT NULL)
                   AND status_category = 'N';

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   SQL%ROWCOUNT
                || ' category records updated with error - Duplicate Records');
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Error while updating duplicate records status '
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status   = 'V'
             WHERE     status = 'N'
                   AND (duty IS NOT NULL OR freight IS NOT NULL OR freight_du IS NOT NULL OR oh_duty IS NOT NULL OR oh_nonduty IS NOT NULL);



            apps.fnd_file.put_line (
                apps.fnd_file.output,
                SQL%ROWCOUNT || ' subelement records validated successfully');

            UPDATE xxdo.xxdocst_stage_std_pending_cst
               SET status_category   = 'V'
             WHERE     status_category = 'N'
                   AND (tarrif_code IS NOT NULL OR country IS NOT NULL OR default_category IS NOT NULL);

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                SQL%ROWCOUNT || ' category records validated successfully');

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'inserting valid category records to  staging table XXD_INV_ITEM_CAT_STG_T');

            extract_cat_to_stg (xv_errbuf, xn_retcode);
        EXCEPTION
            WHEN OTHERS
            THEN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Error while updating validation status'
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
        END;
    EXCEPTION
        WHEN user_exception
        THEN
            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'Cost type or Cost element not found');
            retcode   := 2;
        WHEN NO_DATA_FOUND
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'NO_DATA_FOUND');
            errbuf    := 'No Data Found' || SQLCODE || SQLERRM;
            retcode   := 1;
        WHEN INVALID_CURSOR
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'INVALID_CURSOR');
            errbuf    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            retcode   := 2;
        WHEN TOO_MANY_ROWS
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'TOO_MANY_ROWS');
            errbuf    := 'Too Many Rows' || SQLCODE || SQLERRM;
            retcode   := 2;
        WHEN PROGRAM_ERROR
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'PROGRAM_ERROR');
            errbuf    := 'Program Error' || SQLCODE || SQLERRM;
            retcode   := 2;
        WHEN OTHERS
        THEN
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OTHERS exception in item_cost_insert -'
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
            errbuf    := 'Unhandled Error' || SQLCODE || SQLERRM;
            retcode   := 2;
    END item_cost_insert;


    FUNCTION validate_valueset_value (p_category_set_name IN VARCHAR2, p_application_column_name IN VARCHAR2, p_flex_value IN VARCHAR2
                                      , p_flex_desc IN VARCHAR2)
        RETURN VARCHAR2
    AS
        x_rowid                VARCHAR2 (1000);
        ln_flex_value_id       NUMBER := 0;
        ln_flex_value_set_id   NUMBER := 0;
    --ln_flex_value_id            NUMBER   := 0;
    BEGIN
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                   'validate_valueset_value for '
                || p_application_column_name
                || ' and value '
                || p_flex_value);

        BEGIN
            SELECT ffs.flex_value_set_id, mcs.category_set_id
              INTO ln_flex_value_set_id, gn_category_set_id
              FROM fnd_id_flex_segments ffs, mtl_category_sets_v mcs --, fnd_flex_values ffv
             WHERE     application_id = 401
                   AND id_flex_code = 'MCAT'
                   AND id_flex_num = mcs.structure_id         --l_structure_id
                   AND ffs.enabled_flag = 'Y'
                   -- AND ffv.enabled_flag        = 'Y'
                   AND mcs.category_set_name = p_category_set_name --'TOPPS ITEM CATEGORY SET'
                   --    AND ffs.flex_value_set_id   = ffv.flex_value_set_id
                   AND application_column_name = p_application_column_name;
        --    AND flex_value              = p_flex_value  ;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_flex_value_set_id   := 1;
            WHEN OTHERS
            THEN
                ln_flex_value_set_id   := 0;
        END;


        IF ln_flex_value_set_id IS NOT NULL
        THEN
            BEGIN
                SELECT flex_value_id
                  INTO ln_flex_value_id
                  FROM fnd_flex_values ffs
                 WHERE     ln_flex_value_set_id = ffs.flex_value_set_id
                       AND flex_value = p_flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_flex_value_id   := 0;
                WHEN OTHERS
                THEN
                    ln_flex_value_id   := 0;
            END;

            IF ln_flex_value_id = 0
            THEN
                RETURN 'E';
            ELSE
                RETURN 'S';
            END IF;
        ELSE
            RETURN 'S';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gn_record_error_flag   := 1;
            print_msg_prc (p_debug => gc_debug_flag, p_message => SQLERRM);
            RETURN 'E';
        WHEN OTHERS
        THEN
            gn_record_error_flag   := 1;
            print_msg_prc (p_debug => gc_debug_flag, p_message => SQLERRM);
            RETURN 'E';
    END validate_valueset_value;


    PROCEDURE inv_category_validation (errbuf       OUT NOCOPY VARCHAR2,
                                       retcode      OUT NOCOPY NUMBER)
    /**********************************************************************************************
    *                                                                                             *
    * Function  Name       :  inv_category_validation                                             *
    *                                                                                             *
    * Description          :  Procedure to perform all the required validations                   *
    *                                                                                             *
    * Called From          :                                                                      *
    *                                                                                             *
    *  Change History                                                                             *
    *  -----------------                                                                          *
    *  Version    Date             Author                Description                              *
    *  ---------  ------------    ---------------       -----------------------------             *
    *  1.0        04-APR-2012                           Initial creation                          *
    *                                                                                             *
    **********************************************************************************************/
    IS
        CURSOR cur_item_category IS
            SELECT *
              FROM xxd_inv_item_cat_stg_t
             WHERE record_status IN (gc_new_status);      --,gc_error_status);

        --  l_errbuf    VARCHAR2(2000) := NULL;
        --  l_retcode   VARCHAR2(10)   := NULL;
        lc_err_msg              VARCHAR2 (2000) := NULL;
        x_return_status         VARCHAR2 (10) := NULL;
        l_category_set_exists   VARCHAR2 (10);
        l_old_category_id       NUMBER;
        l_segment_exists        VARCHAR2 (1);
    BEGIN
        OPEN cur_item_category;

        LOOP
            FETCH cur_item_category
                BULK COLLECT INTO gt_item_cat_rec
                LIMIT 50;

            EXIT WHEN gt_item_cat_rec.COUNT = 0;



            IF gt_item_cat_rec.COUNT > 0
            THEN
                -- Check if there are any records in the staging table that need to be processed
                FOR lc_item_cat_idx IN 1 .. gt_item_cat_rec.COUNT
                LOOP
                    gn_organization_id        := NULL;
                    gn_inventory_item_id      := NULL;
                    gn_category_id            := NULL;
                    gn_category_set_id        := NULL;
                    gc_err_msg                := NULL;
                    gc_stg_tbl_process_flag   := NULL;
                    gn_record_error_flag      := 0;
                    lc_err_msg                := NULL;
                    gn_inventory_item         :=
                        gt_item_cat_rec (lc_item_cat_idx).item_number;
                    x_return_status           := fnd_api.g_ret_sts_success;
                    l_segment_exists          := 'Y';

                    -- Check if the mandatory field Organization code exists or not and validate the organization code
                    print_msg_prc (
                        gc_debug_flag,
                        'gn_record_error_flag    => ' || gn_record_error_flag);


                    ---- Validate value set values in Segments.
                    print_msg_prc (gc_debug_flag,
                                   'Validate value set values in Segments.');

                    IF gt_item_cat_rec (lc_item_cat_idx).segment1 IS NOT NULL
                    THEN
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT1',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment1,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment1_desc);

                        print_msg_prc (
                            gc_debug_flag,
                               'Status of segment1 validation.'
                            || x_return_status);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT1 '
                                || gt_item_cat_rec (lc_item_cat_idx).segment1
                                || 'Not defind in Category Set'
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Category Assignment program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT1',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment1);
                        END IF;
                    -- ELSE
                    --gn_record_error_flag := 1;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment2.'
                        || gn_record_error_flag);
                    x_return_status           := fnd_api.g_ret_sts_success;

                    IF gt_item_cat_rec (lc_item_cat_idx).segment2 IS NOT NULL
                    THEN
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT2',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment2,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment2_desc);

                        print_msg_prc (
                            gc_debug_flag,
                               'Status of segment2 validation.'
                            || x_return_status);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT2 '
                                || gt_item_cat_rec (lc_item_cat_idx).segment2
                                || 'Not defind in Category Set'
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Category Assignment program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT2',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment2);
                        END IF;
                    --                     ELSE
                    --                     gn_record_error_flag := 1;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment3.'
                        || gn_record_error_flag);
                    x_return_status           := fnd_api.g_ret_sts_success;

                    IF gt_item_cat_rec (lc_item_cat_idx).segment3 IS NOT NULL
                    THEN
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT3',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment3,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment3_desc);

                        print_msg_prc (
                            gc_debug_flag,
                               'Status of segment3 validation.'
                            || x_return_status);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT3 '
                                || gt_item_cat_rec (lc_item_cat_idx).segment3
                                || 'Not defind in Category Set'
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Category Assignment program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT3',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment3);
                        END IF;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment4.'
                        || gn_record_error_flag);
                    x_return_status           := fnd_api.g_ret_sts_success;

                    IF gt_item_cat_rec (lc_item_cat_idx).segment4 IS NOT NULL
                    THEN
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT4',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment4,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment4_desc);

                        print_msg_prc (
                            gc_debug_flag,
                               'Status of segment4 validation.'
                            || x_return_status);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT4 '
                                || gt_item_cat_rec (lc_item_cat_idx).segment4
                                || 'Not defind in Category Set'
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Category Assignment program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT4',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment4);
                        END IF;
                    END IF;

                    /*print_msg_prc (
                       gc_debug_flag,
                          'Validate value set values in Segment5.'
                       || gn_record_error_flag);
                       x_return_status := fnd_api.g_ret_sts_success; */
                    /* IF gt_item_cat_rec(lc_item_cat_idx).segment5 IS NOT NULL THEN
                     x_return_status := validate_valueset_value(p_category_set_name       => gt_item_cat_rec(lc_item_cat_idx).category_set_name
                                            ,p_application_column_name =>  'SEGMENT5'
                                            ,p_flex_value              => gt_item_cat_rec(lc_item_cat_idx).segment5
                                            ,p_flex_desc               => gt_item_cat_rec(lc_item_cat_idx).segment5_desc);

                             IF x_return_status = 'E' THEN
                       l_segment_exists:='N';
                       lc_err_msg  :=  'SEGMENT5 ' || gt_item_cat_rec(lc_item_cat_idx).SEGMENT5 || 'Not defind in Category Set'||gt_item_cat_rec(lc_item_cat_idx).category_set_name;

                       xxd_common_utils.record_error (
                                                   p_module       => 'INV',
                                                   p_org_id       => gn_org_id,
                                                   p_program      => 'Tariff Code Item Category Assignment - Deckers',
                                                   p_error_line   => SQLCODE,
                                                   p_error_msg    => lc_err_msg,
                                                   p_created_by   => gn_user_id,
                                                   p_request_id   => gn_conc_request_id,
                                                   p_more_info1   => gt_item_cat_rec(lc_item_cat_idx).category_set_name,
                                                   p_more_info2   => gt_item_cat_rec(lc_item_cat_idx).item_number,
                                                   p_more_info3   => 'SEGMENT5',
                                                   p_more_info4   => gt_item_cat_rec(lc_item_cat_idx).SEGMENT5);
                       END IF;
                     END IF;

                     IF gt_item_cat_rec(lc_item_cat_idx).segment6 IS NOT NULL THEN
                     x_return_status := validate_valueset_value(p_category_set_name       => gt_item_cat_rec(lc_item_cat_idx).category_set_name
                                            ,p_application_column_name =>  'SEGMENT6'
                                            ,p_flex_value              => gt_item_cat_rec(lc_item_cat_idx).segment6
                                            ,p_flex_desc               => gt_item_cat_rec(lc_item_cat_idx).segment6_desc);
                              IF x_return_status = 'E' THEN
                       l_segment_exists:='N';
                       lc_err_msg  :=  'SEGMENT6 ' || gt_item_cat_rec(lc_item_cat_idx).SEGMENT6 || 'Not defind in Category Set'||gt_item_cat_rec(lc_item_cat_idx).category_set_name;

                       xxd_common_utils.record_error (
                                                   p_module       => 'INV',
                                                   p_org_id       => gn_org_id,
                                                   p_program      => 'Tariff Code Item Category Assignment - Deckers',
                                                   p_error_line   => SQLCODE,
                                                   p_error_msg    => lc_err_msg,
                                                   p_created_by   => gn_user_id,
                                                   p_request_id   => gn_conc_request_id,
                                                   p_more_info1   => gt_item_cat_rec(lc_item_cat_idx).category_set_name,
                                                   p_more_info2   => gt_item_cat_rec(lc_item_cat_idx).item_number,
                                                   p_more_info3   => 'SEGMENT6',
                                                   p_more_info4   => gt_item_cat_rec(lc_item_cat_idx).SEGMENT6);
                       END IF;
                     END IF;

                     IF gt_item_cat_rec(lc_item_cat_idx).segment7 IS NOT NULL THEN
                     x_return_status := validate_valueset_value(p_category_set_name       => gt_item_cat_rec(lc_item_cat_idx).category_set_name
                                            ,p_application_column_name =>  'SEGMENT7'
                                            ,p_flex_value              => gt_item_cat_rec(lc_item_cat_idx).segment7
                                            ,p_flex_desc               => gt_item_cat_rec(lc_item_cat_idx).segment7_desc);
                              IF x_return_status = 'E' THEN
                       l_segment_exists:='N';
                       lc_err_msg  :=  'SEGMENT7 ' || gt_item_cat_rec(lc_item_cat_idx).SEGMENT7 || 'Not defind in Category Set'||gt_item_cat_rec(lc_item_cat_idx).category_set_name;

                       xxd_common_utils.record_error (
                                                   p_module       => 'INV',
                                                   p_org_id       => gn_org_id,
                                                   p_program      => 'Tariff Code Item Category Assignment - Deckers',
                                                   p_error_line   => SQLCODE,
                                                   p_error_msg    => lc_err_msg,
                                                   p_created_by   => gn_user_id,
                                                   p_request_id   => gn_conc_request_id,
                                                   p_more_info1   => gt_item_cat_rec(lc_item_cat_idx).category_set_name,
                                                   p_more_info2   => gt_item_cat_rec(lc_item_cat_idx).item_number,
                                                   p_more_info3   => 'SEGMENT7',
                                                   p_more_info4   => gt_item_cat_rec(lc_item_cat_idx).SEGMENT7);
                       END IF;
                     END IF;

                     IF gt_item_cat_rec(lc_item_cat_idx).segment8 IS NOT NULL THEN
                     x_return_status := validate_valueset_value(p_category_set_name       => gt_item_cat_rec(lc_item_cat_idx).category_set_name
                                            ,p_application_column_name =>  'SEGMENT8'
                                            ,p_flex_value              => gt_item_cat_rec(lc_item_cat_idx).segment8
                                            ,p_flex_desc               => gt_item_cat_rec(lc_item_cat_idx).segment8_desc);
                       IF x_return_status = 'E' THEN
                       l_segment_exists:='N';
                       lc_err_msg  :=  'SEGMENT8 ' || gt_item_cat_rec(lc_item_cat_idx).SEGMENT8 || 'Not defind in Category Set'||gt_item_cat_rec(lc_item_cat_idx).category_set_name;

                       xxd_common_utils.record_error (
                                                   p_module       => 'INV',
                                                   p_org_id       => gn_org_id,
                                                   p_program      => 'Tariff Code Item Category Assignment - Deckers',
                                                   p_error_line   => SQLCODE,
                                                   p_error_msg    => lc_err_msg,
                                                   p_created_by   => gn_user_id,
                                                   p_request_id   => gn_conc_request_id,
                                                   p_more_info1   => gt_item_cat_rec(lc_item_cat_idx).category_set_name,
                                                   p_more_info2   => gt_item_cat_rec(lc_item_cat_idx).item_number,
                                                   p_more_info3   => 'SEGMENT8',
                                                   p_more_info4   => gt_item_cat_rec(lc_item_cat_idx).SEGMENT8);
                       END IF;
                     END IF;
                      print_msg_prc(gc_debug_flag,'Validate value set values in Segment9.'||gn_record_error_flag );
                     IF gt_item_cat_rec(lc_item_cat_idx).segment9 IS NOT NULL THEN
                     x_return_status := validate_valueset_value(p_category_set_name       => gt_item_cat_rec(lc_item_cat_idx).category_set_name
                                            ,p_application_column_name =>  'SEGMENT9'
                                            ,p_flex_value              => gt_item_cat_rec(lc_item_cat_idx).segment9
                                            ,p_flex_desc               => gt_item_cat_rec(lc_item_cat_idx).segment9_desc);
                              IF x_return_status = 'E' THEN
                       l_segment_exists:='N';
                       lc_err_msg  :=  'SEGMENT9 ' || gt_item_cat_rec(lc_item_cat_idx).segment9 || 'Not defind in Category Set'||gt_item_cat_rec(lc_item_cat_idx).category_set_name;

                       xxd_common_utils.record_error (
                                                   p_module       => 'INV',
                                                   p_org_id       => gn_org_id,
                                                   p_program      => 'Tariff Code Item Category Assignment - Deckers',
                                                   p_error_line   => SQLCODE,
                                                   p_error_msg    => lc_err_msg,
                                                   p_created_by   => gn_user_id,
                                                   p_request_id   => gn_conc_request_id,
                                                   p_more_info1   => gt_item_cat_rec(lc_item_cat_idx).category_set_name,
                                                   p_more_info2   => gt_item_cat_rec(lc_item_cat_idx).item_number,
                                                   p_more_info3   => 'SEGMENT9',
                                                   p_more_info4   => gt_item_cat_rec(lc_item_cat_idx).segment9);
                       END IF;
                     END IF;
*/

                    print_msg_prc (
                        gc_debug_flag,
                        'x_return_status         =>' || x_return_status);
                    print_msg_prc (
                        gc_debug_flag,
                        'gn_record_error_flag    =>' || gn_record_error_flag);
                    print_msg_prc (
                        gc_debug_flag,
                           'p_batch_number                =>'
                        || gt_item_cat_rec (lc_item_cat_idx).batch_number);
                    print_msg_prc (
                        gc_debug_flag,
                           'record_id       =>'
                        || gt_item_cat_rec (lc_item_cat_idx).record_id);

                    IF l_segment_exists = 'N'
                    THEN
                        UPDATE xxd_inv_item_cat_stg_t
                           SET record_status   = gc_validate_status
                         WHERE record_id =
                               gt_item_cat_rec (lc_item_cat_idx).record_id;
                    ELSE
                        UPDATE xxd_inv_item_cat_stg_t
                           SET record_status = gc_error_status, error_message = 'ValueSet Validation Error'
                         WHERE record_id =
                               gt_item_cat_rec (lc_item_cat_idx).record_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_item_category;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (p_debug => gc_debug_flag, p_message => SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            lc_err_msg   :=
                   'Unexpected error while cursor fetching into PL/SQL table - '
                || SQLERRM;
            print_msg_prc (gc_debug_flag, lc_err_msg);
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    => lc_err_msg,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => NULL);
    END inv_category_validation;



    PROCEDURE get_category_id (p_processing_row_id   IN     NUMBER,
                               x_return_status          OUT VARCHAR2)
    AS
        l_category_rec      inv_item_category_pub.category_rec_type;
        l_category_set_id   mtl_category_sets_v.category_set_id%TYPE;
        l_segment_array     fnd_flex_ext.segmentarray;
        l_n_segments        NUMBER := 0;
        l_delim             VARCHAR2 (1000);
        l_success           BOOLEAN;
        l_concat_segs       VARCHAR2 (32000);
        l_concat_segments   VARCHAR2 (32000);
        l_return_status     VARCHAR2 (80);
        l_error_code        NUMBER;
        l_msg_count         NUMBER;
        ln_category_id      NUMBER;
        l_msg_data          VARCHAR2 (32000);
        l_messages          VARCHAR2 (32000) := '';
        l_out_category_id   NUMBER;
        x_message_list      error_handler.error_tbl_type;
        x_msg_data          VARCHAR2 (32000);
        l_seg_description   VARCHAR2 (32000); ----new segment added for concatenated segments


        CURSOR get_segments (l_structure_id NUMBER)
        IS
              SELECT application_column_name, ROWNUM
                FROM fnd_id_flex_segments
               WHERE     application_id = 401
                     AND id_flex_code = 'MCAT'
                     AND id_flex_num = l_structure_id
                     AND enabled_flag = 'Y'
            ORDER BY segment_num ASC;

        CURSOR get_structure_id (cp_category_set_name VARCHAR2)
        IS
            SELECT structure_id, category_set_id
              FROM mtl_category_sets_v
             WHERE category_set_name = cp_category_set_name;

        CURSOR get_category_id (cp_structure_id        NUMBER,
                                cp_concatenated_segs   VARCHAR2)
        IS
            SELECT category_id
              FROM mtl_categories_b_kfv
             WHERE     structure_id = cp_structure_id
                   AND concatenated_segments = cp_concatenated_segs;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'create_category');
        l_return_status   := fnd_api.g_ret_sts_success;

        FOR lc_cat_data IN (SELECT *
                              FROM xxd_inv_item_cat_stg_t
                             WHERE record_id = p_processing_row_id)
        LOOP
            gn_category_id               := NULL;
            l_category_rec.segment1      := NULL;
            l_category_rec.segment2      := NULL;
            l_category_rec.segment3      := NULL;
            l_category_rec.segment4      := NULL;
            l_category_rec.segment5      := NULL;
            l_category_rec.segment6      := NULL;
            l_category_rec.segment7      := NULL;
            l_category_rec.segment8      := NULL;
            l_category_rec.segment9      := NULL;
            l_category_rec.segment10     := NULL;
            l_category_rec.segment11     := NULL;
            l_category_rec.segment12     := NULL;
            l_category_rec.segment13     := NULL;
            l_category_rec.segment14     := NULL;
            l_category_rec.segment15     := NULL;
            l_category_rec.segment16     := NULL;
            l_category_rec.segment17     := NULL;
            l_category_rec.segment18     := NULL;
            l_category_rec.segment19     := NULL;
            l_category_rec.segment20     := NULL;

            OPEN get_structure_id (
                cp_category_set_name => lc_cat_data.category_set_name);

            FETCH get_structure_id INTO l_category_rec.structure_id, l_category_set_id;

            CLOSE get_structure_id;


            gn_category_set_id           := l_category_set_id;
            --   SELECT f.id_flex_num
            --     INTO l_category_rec.structure_id
            --     FROM fnd_id_flex_structures f
            --    WHERE f.id_flex_structure_code = 'TOPPS ITEM CAT';


            -- Looping through the enabled segments in the target instance
            -- and setting the values for only those segments those are enabled
            l_seg_description            := NULL;

            -- gn_category_id := NULL;

            FOR c_segments IN get_segments (l_category_rec.structure_id)
            LOOP
                l_n_segments   := c_segments.ROWNUM;

                IF c_segments.application_column_name = 'SEGMENT1'
                THEN
                    l_category_rec.segment1   := lc_cat_data.segment1;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment1;
                ELSIF c_segments.application_column_name = 'SEGMENT2'
                THEN
                    l_category_rec.segment2   := lc_cat_data.segment2;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment2;
                --           IF lc_cat_data.SEGMENT2 IS NULL AND lc_cat_data.SEGMENT3 IS NOT NULL THEN
                --               l_segment_array(c_segments.rownum):= '.';
                --            END IF;

                ELSIF c_segments.application_column_name = 'SEGMENT3'
                THEN
                    l_category_rec.segment3   := lc_cat_data.segment3;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment3;
                ELSIF c_segments.application_column_name = 'SEGMENT4'
                THEN
                    l_category_rec.segment4   := lc_cat_data.segment4;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment4;
                ELSIF c_segments.application_column_name = 'SEGMENT5'
                THEN
                    l_category_rec.segment5   := lc_cat_data.segment5;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment5;
                ELSIF c_segments.application_column_name = 'SEGMENT6'
                THEN
                    l_category_rec.segment6   := lc_cat_data.segment6;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment6;
                ELSIF c_segments.application_column_name = 'SEGMENT7'
                THEN
                    l_category_rec.segment7   := lc_cat_data.segment7;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment7;
                ELSIF c_segments.application_column_name = 'SEGMENT8'
                THEN
                    l_category_rec.segment8   := lc_cat_data.segment8;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment8;
                ELSIF c_segments.application_column_name = 'SEGMENT9'
                THEN
                    l_category_rec.segment9   := lc_cat_data.segment9;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment9;
                ELSIF c_segments.application_column_name = 'SEGMENT10'
                THEN
                    l_category_rec.segment10   := lc_cat_data.segment10;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment10;
                ELSIF c_segments.application_column_name = 'SEGMENT11'
                THEN
                    l_category_rec.segment11   := lc_cat_data.segment11;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment11;
                ELSIF c_segments.application_column_name = 'SEGMENT12'
                THEN
                    l_category_rec.segment12   := lc_cat_data.segment12;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment12;
                ELSIF c_segments.application_column_name = 'SEGMENT13'
                THEN
                    l_category_rec.segment13   := lc_cat_data.segment13;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment13;
                ELSIF c_segments.application_column_name = 'SEGMENT14'
                THEN
                    l_category_rec.segment14   := lc_cat_data.segment14;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment14;
                ELSIF c_segments.application_column_name = 'SEGMENT15'
                THEN
                    l_category_rec.segment15   := lc_cat_data.segment15;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment15;
                ELSIF c_segments.application_column_name = 'SEGMENT16'
                THEN
                    l_category_rec.segment16   := lc_cat_data.segment16;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment16;
                ELSIF c_segments.application_column_name = 'SEGMENT17'
                THEN
                    l_category_rec.segment17   := lc_cat_data.segment17;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment17;
                ELSIF c_segments.application_column_name = 'SEGMENT18'
                THEN
                    l_category_rec.segment18   := lc_cat_data.segment18;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment18;
                ELSIF c_segments.application_column_name = 'SEGMENT19'
                THEN
                    l_category_rec.segment19   := lc_cat_data.segment19;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment19;
                ELSIF c_segments.application_column_name = 'SEGMENT20'
                THEN
                    l_category_rec.segment20   := lc_cat_data.segment20;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.segment20;
                END IF;
            END LOOP; -- loop to get all the enabled segments in the target inst.


            l_delim                      :=
                fnd_flex_ext.get_delimiter ('INV',
                                            'MCAT',
                                            l_category_rec.structure_id);

            l_concat_segs                :=
                fnd_flex_ext.concatenate_segments (l_n_segments,
                                                   l_segment_array,
                                                   l_delim);
            l_success                    :=
                fnd_flex_keyval.validate_segs (
                    operation          => 'FIND_COMBINATION',
                    appl_short_name    => 'INV',
                    key_flex_code      => 'MCAT',
                    structure_number   => l_category_rec.structure_id,
                    concat_segments    => l_concat_segs);
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OPEN get_category_id structure_id  => '
                    || l_category_rec.structure_id);
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OPEN get_category_id l_concat_segs  => '
                    || l_concat_segs);

            l_category_rec.description   := l_concat_segs; -- commenting the l_concat_seg as we need to pass actual description

            /*print_msg_prc (
               p_debug     => gc_debug_flag,
               p_message   =>    'Lenght of l_concat_segs  => '
                              || length(l_concat_segs));*/
            OPEN get_category_id (l_category_rec.structure_id, l_concat_segs);

            FETCH get_category_id INTO gn_category_id;

            CLOSE get_category_id;

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OPEN get_category_id gn_category_id  => '
                    || gn_category_id);


            IF (NOT l_success) AND gn_category_id IS NULL
            THEN
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'OPEN get_category_id l_success  => True');
                inv_item_category_pub.create_category (
                    p_api_version     => 1.0,
                    p_init_msg_list   => fnd_api.g_false,
                    p_commit          => fnd_api.g_false,
                    x_return_status   => l_return_status,
                    x_errorcode       => l_error_code,
                    x_msg_count       => l_msg_count,
                    x_msg_data        => l_msg_data,
                    p_category_rec    => l_category_rec,
                    x_category_id     => l_out_category_id);

                IF (l_return_status = fnd_api.g_ret_sts_success)
                THEN
                    gn_category_id   := l_out_category_id;
                    print_msg_prc (gc_debug_flag,
                                   'Category Id: ' || gn_category_id);
                ELSE
                    gn_category_id   := NULL;
                END IF;

                IF (l_return_status <> fnd_api.g_ret_sts_success)
                THEN
                    fnd_msg_pub.count_and_get (p_encoded   => 'F',
                                               p_count     => l_msg_count,
                                               p_data      => l_msg_data);
                    print_msg_prc (
                        gc_debug_flag,
                        'Category Id: Inside1 ' || l_msg_data || l_error_code);

                    FOR k IN 1 .. l_msg_count
                    LOOP
                        l_messages   :=
                               l_messages
                            || fnd_msg_pub.get (p_msg_index   => k,
                                                p_encoded     => 'F')
                            || ';';
                        print_msg_prc (
                            p_debug     => gc_debug_flag,
                            p_message   => 'l_messages => ' || l_messages);
                    END LOOP;

                    fnd_message.set_name ('FND', 'GENERIC-INTERNAL ERROR');
                    fnd_message.set_token ('ROUTINE', 'Category Migration');
                    fnd_message.set_token ('REASON', l_messages);
                    --APP_EXCEPTION.RAISE_EXCEPTION;
                    print_msg_prc (p_debug     => gc_debug_flag,
                                   p_message   => fnd_message.get);
                    xxd_common_utils.record_error (
                        p_module       => 'INV',
                        p_org_id       => gn_org_id,
                        p_program      => 'Deckers Category Assignment program',
                        p_error_line   => SQLCODE,
                        p_error_msg    => l_messages,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'GN_INVENTORY_ITEM',
                        p_more_info2   => gn_inventory_item,
                        p_more_info3   => 'CONCAT_SEGS',
                        p_more_info4   => l_concat_segs);
                END IF;
            ELSE
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'OPEN get_category_id l_success  => False');

                OPEN get_category_id (l_category_rec.structure_id,
                                      l_concat_segs);

                FETCH get_category_id INTO gn_category_id;

                CLOSE get_category_id;
            END IF;

            x_return_status              := l_return_status;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    => l_messages,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'GN_INVENTORY_ITEM',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => 'CONCAT_SEGS',
                p_more_info4   => l_concat_segs);
        WHEN OTHERS
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    => l_messages,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'GN_INVENTORY_ITEM',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => 'CONCAT_SEGS',
                p_more_info4   => l_concat_segs);
    END get_category_id;



    /*   PROCEDURE get_inv_org_id (p_inv_org_name_id   IN     NUMBER,
                                 x_inv_org_name         OUT VARCHAR2,
                                 x_inv_org_id           OUT NUMBER)
       -- +===================================================================+
       -- | Name  : GET_ORG_ID                                                |
       -- | Description      : This procedure  is used to get                 |
       -- |                    org id from EBS                                |
       -- |                                                                   |
       -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
       -- |                                                                   |
       -- |                                                                   |
       -- | Returns : x_org_id                                                |
       -- |                                                                   |
       -- +===================================================================+
       IS
          px_lookup_code   VARCHAR2 (250);
          px_meaning       VARCHAR2 (250);          -- internal name of old entity
          px_description   VARCHAR2 (250);               -- name of the old entity
          x_attribute1     VARCHAR2 (250);       -- corresponding new 12.2.3 value
          x_attribute2     VARCHAR2 (250);
          x_error_code     VARCHAR2 (250);
          x_error_msg      VARCHAR (250);
       --          x_org_id                   NUMBER;
       BEGIN
          px_lookup_code := p_inv_org_name_id;
          apps.XXD_COMMON_UTILS.get_mapping_value (
             p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING', -- Lookup type for mapping
             px_lookup_code   => px_lookup_code,
             -- Would generally be id of 12.0.6. eg: org_id
             px_meaning       => px_meaning,        -- internal name of old entity
             px_description   => px_description,         -- name of the old entity
             x_attribute1     => x_attribute1,   -- corresponding new 12.2.3 value
             x_attribute2     => x_attribute2,
             x_error_code     => x_error_code,
             x_error_msg      => x_error_msg);

          SELECT organization_id
            INTO x_inv_org_id
            FROM org_organization_definitions
           WHERE UPPER (organization_code) = (SELECT organization_code
                                                FROM mtl_parameters
                                               WHERE organization_code = 'MST');

          x_inv_org_name := x_attribute1;
       EXCEPTION
          WHEN OTHERS
          THEN
             xxd_common_utils.record_error (
                'INV',
                gn_org_id,
                'Deckers Category Assignment program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'get_inv_org_id',
                p_inv_org_name_id,
                'Exception to GET_INV_ORG_ID Procedure' || SQLERRM);

             print_msg_prc (
                gc_debug_flag,
                'Error while fetching the Organization ID ' || SQLERRM);
             x_inv_org_name := NULL;
             x_inv_org_id := NULL;
       END get_inv_org_id;*/


    PROCEDURE create_category_assignment (
        p_category_id         IN     NUMBER,
        p_category_set_id     IN     NUMBER,
        p_inventory_item_id   IN     NUMBER,
        p_organization_id     IN     NUMBER,
        x_return_status          OUT VARCHAR2)
    AS
        lx_return_status   NUMBER;
        x_error_message    VARCHAR2 (2000);
        --x_return_status       VARCHAR2 (10);
        x_msg_data         VARCHAR2 (2000);
        li_msg_count       NUMBER;
        ls_msg_data        VARCHAR2 (4000);
        l_messages         VARCHAR2 (4000);
        li_error_code      NUMBER;
        x_message_list     error_handler.error_tbl_type;
        ln_rec_cnt         NUMBER := 0;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'create_category_assignment');

        SELECT COUNT (1)
          INTO ln_rec_cnt
          FROM mtl_item_categories
         WHERE     inventory_item_id = p_inventory_item_id
               AND organization_id = p_organization_id
               AND category_set_id = p_category_set_id
               AND category_id = NVL (p_category_id, 0);

        IF ln_rec_cnt = 0
        THEN
            inv_item_category_pub.create_category_assignment (
                p_api_version         => 1,
                p_init_msg_list       => fnd_api.g_false,
                p_commit              => fnd_api.g_false,
                x_return_status       => x_return_status,
                x_errorcode           => li_error_code,
                x_msg_count           => li_msg_count,
                x_msg_data            => ls_msg_data,
                p_category_id         => p_category_id,
                p_category_set_id     => p_category_set_id,
                p_inventory_item_id   => p_inventory_item_id,
                p_organization_id     => p_organization_id);

            --  error_handler.get_message_list (x_message_list => x_message_list);

            IF x_return_status <> fnd_api.g_ret_sts_success
            THEN
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'status is count:' || x_message_list.COUNT);
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'status is 1:' || x_return_status);

                fnd_msg_pub.count_and_get (p_encoded   => 'F',
                                           p_count     => li_msg_count,
                                           p_data      => ls_msg_data);

                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'status is ls_msg_data 1:' || ls_msg_data);

                FOR k IN 1 .. li_msg_count
                LOOP
                    l_messages   :=
                           l_messages
                        || fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F')
                        || ';';
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'l_messages => ' || l_messages);
                    fnd_msg_pub.delete_msg (k);
                END LOOP;

                xxd_common_utils.record_error (
                    p_module       => 'INV',
                    p_org_id       => gn_org_id,
                    p_program      => 'Deckers Category Assignment program',
                    p_error_line   => SQLCODE,
                    p_error_msg    =>
                        NVL (SUBSTR (l_messages, 2000),
                             'Error in create_category_assignment'),
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => gn_inventory_item,
                    p_more_info2   => 'p_category_id',
                    p_more_info3   => p_category_id,
                    p_more_info4   => p_category_set_id);
            END IF;
        ELSE
            x_return_status   := fnd_api.g_ret_sts_error;
            l_messages        :=
                   'An item '
                || gn_inventory_item
                || ' can be assigned to only one category within this category set.';
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        END IF;                                                --ln_rec_cnt >0

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'status is 2:' || x_return_status);
        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'Processing category  Status ' || x_return_status);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_messages   := SQLERRM;

            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        WHEN OTHERS
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
    END create_category_assignment;

    PROCEDURE update_category_assignment (p_category_id mtl_categories_b.category_id%TYPE, p_old_category_id mtl_categories_b.category_id%TYPE, p_category_set_id mtl_category_sets_tl.category_set_id%TYPE
                                          , p_inventory_item_id mtl_system_items_b.inventory_item_id%TYPE, p_organization_id mtl_parameters.organization_id%TYPE, x_return_status OUT VARCHAR2)
    AS
        -- lx_return_status      NUMBER;
        x_error_message   VARCHAR2 (2000);
        --x_return_status       VARCHAR2 (10);
        x_msg_data        VARCHAR2 (2000);
        li_msg_count      NUMBER;
        ls_msg_data       VARCHAR2 (4000);
        l_messages        VARCHAR2 (4000);
        li_error_code     NUMBER;
        x_message_list    error_handler.error_tbl_type;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'update_category_assignment');

        inv_item_category_pub.update_category_assignment (
            p_api_version         => 1.0,
            p_init_msg_list       => fnd_api.g_false,
            p_commit              => fnd_api.g_false,
            p_category_id         => p_category_id,
            p_old_category_id     => p_old_category_id,
            p_category_set_id     => p_category_set_id,
            p_inventory_item_id   => p_inventory_item_id,
            p_organization_id     => p_organization_id,
            x_return_status       => x_return_status,
            x_errorcode           => li_error_code,
            x_msg_count           => li_msg_count,
            x_msg_data            => x_msg_data);

        IF (x_return_status <> fnd_api.g_ret_sts_success)
        THEN
            error_handler.get_message_list (x_message_list => x_message_list);
            l_messages   := NULL;

            FOR i IN 1 .. x_message_list.COUNT
            LOOP
                IF l_messages IS NULL
                THEN
                    l_messages   := x_message_list (i).MESSAGE_TEXT;
                ELSE
                    l_messages   :=
                        l_messages || ' ' || x_message_list (i).MESSAGE_TEXT;
                END IF;

                fnd_msg_pub.delete_msg (i);
            END LOOP;

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Error Messages (Update Item Category Assignment):'
                    || l_messages);
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'UPDATE_CATEGORY_ASSIGNMENT',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_messages   := SQLERRM;

            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in update_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'UPDATE_CATEGORY_ASSIGNMENT',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        WHEN OTHERS
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in update_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'UPDATE_CATEGORY_ASSIGNMENT',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
    END update_category_assignment;

    PROCEDURE cat_assignment_child_program (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_batch_number IN NUMBER
                                            , p_debug IN VARCHAR2)
    IS
        lc_err_msg              VARCHAR2 (2000) := NULL;
        x_return_status         VARCHAR2 (10) := NULL;
        l_category_set_exists   VARCHAR2 (10);
        l_old_category_id       NUMBER;
        l_segment_exists        VARCHAR2 (1);
        gn_organization_code    VARCHAR2 (30);
        xv_errbuf               VARCHAR2 (300);
        xn_retcode              NUMBER (10);
        ln_count                NUMBER (10);
        ln_success_count        NUMBER (20) := 0;
        ln_error_count          NUMBER (20) := 0;

        CURSOR cur_item_category (p_batch NUMBER)
        IS
            SELECT *
              FROM xxd_inv_item_cat_stg_t
             WHERE record_status = gc_new_status AND batch_number = p_batch;


        CURSOR get_structure_id (cp_category_set_name VARCHAR2)
        IS
            SELECT category_set_id
              FROM mtl_category_sets_v
             WHERE category_set_name = cp_category_set_name;
    BEGIN
        gc_debug_flag   := p_debug;

        OPEN cur_item_category (p_batch_number);

        LOOP
            FETCH cur_item_category
                BULK COLLECT INTO gt_item_cat_rec
                LIMIT 500;

            EXIT WHEN gt_item_cat_rec.COUNT = 0;



            IF gt_item_cat_rec.COUNT > 0
            THEN
                -- Check if there are any records in the staging table that need to be processed
                FOR lc_item_cat_idx IN 1 .. gt_item_cat_rec.COUNT
                LOOP
                    gn_organization_id        := NULL;
                    gn_inventory_item_id      := NULL;
                    gn_category_id            := NULL;
                    gn_category_set_id        := NULL;
                    gc_err_msg                := NULL;
                    gc_stg_tbl_process_flag   := NULL;
                    gn_record_error_flag      := 0;

                    gn_inventory_item         :=
                        gt_item_cat_rec (lc_item_cat_idx).item_number;
                    x_return_status           := fnd_api.g_ret_sts_success;
                    l_segment_exists          := 'Y';



                    get_category_id (
                        p_processing_row_id   =>
                            gt_item_cat_rec (lc_item_cat_idx).record_id,
                        x_return_status   => x_return_status);


                    OPEN get_structure_id (
                        cp_category_set_name   =>
                            gt_item_cat_rec (lc_item_cat_idx).category_set_name);

                    FETCH get_structure_id INTO gn_category_set_id;

                    CLOSE get_structure_id;

                    IF gn_category_id IS NULL
                    THEN
                        gn_record_error_flag   := 1;
                    ELSE
                        gn_organization_id   :=
                            gt_item_cat_rec (lc_item_cat_idx).organization_id;

                        gn_inventory_item_id   :=
                            gt_item_cat_rec (lc_item_cat_idx).inventory_item_id;


                        print_msg_prc (
                            gc_debug_flag,
                               'gn_inventory_item_id    => '
                            || gn_inventory_item_id);
                        print_msg_prc (
                            gc_debug_flag,
                            'gn_organization_id    => ' || gn_organization_id);
                        print_msg_prc (
                            gc_debug_flag,
                            'gn_category_set_id    => ' || gn_category_set_id);

                        IF     gn_organization_id IS NOT NULL
                           AND gn_inventory_item_id IS NOT NULL
                        THEN
                            BEGIN
                                SELECT category_id, 'Y'
                                  INTO l_old_category_id, l_category_set_exists
                                  FROM mtl_item_categories
                                 WHERE     inventory_item_id =
                                           gn_inventory_item_id
                                       AND organization_id =
                                           gn_organization_id
                                       AND category_set_id =
                                           gn_category_set_id;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    l_category_set_exists   := 'N';
                            END;

                            print_msg_prc (
                                gc_debug_flag,
                                'gn_category_id    => ' || gn_category_id);

                            IF l_category_set_exists = 'N'
                            THEN
                                BEGIN
                                    create_category_assignment (
                                        p_category_id     => gn_category_id,
                                        p_category_set_id   =>
                                            gn_category_set_id,
                                        p_inventory_item_id   =>
                                            gn_inventory_item_id,
                                        p_organization_id   =>
                                            gn_organization_id,
                                        x_return_status   => x_return_status);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        print_msg_prc (
                                            gc_debug_flag,
                                               'Error While Creating Category Assignment'
                                            || SQLERRM);
                                END;
                            ELSE
                                BEGIN
                                    update_category_assignment (
                                        p_category_id     => gn_category_id,
                                        p_old_category_id   =>
                                            l_old_category_id,
                                        p_category_set_id   =>
                                            gn_category_set_id,
                                        p_inventory_item_id   =>
                                            gn_inventory_item_id,
                                        p_organization_id   =>
                                            gn_organization_id,
                                        x_return_status   => x_return_status);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        print_msg_prc (
                                            gc_debug_flag,
                                               'Error While Updating Category Assignment'
                                            || SQLERRM);
                                END;
                            END IF;
                        END IF;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                        'x_return_status         =>' || x_return_status);
                    print_msg_prc (
                        gc_debug_flag,
                        'gn_record_error_flag    =>' || gn_record_error_flag);
                    --print_msg_prc(gc_debug_flag,'p_batch_number                =>'||gt_item_cat_rec(lc_item_cat_idx).batch_number );
                    print_msg_prc (
                        gc_debug_flag,
                           'record_id       =>'
                        || gt_item_cat_rec (lc_item_cat_idx).record_id);

                    IF x_return_status = 'S'
                    THEN
                        ln_success_count   := ln_success_count + 1;

                        UPDATE xxd_inv_item_cat_stg_t
                           SET record_status   = gc_process_status
                         WHERE record_id =
                               gt_item_cat_rec (lc_item_cat_idx).record_id;
                    /*
                    -- Commenting this update to make this program reusable for other category assignments also
                    update XXDOCST_STAGE_STD_PENDING_CST
                    set status_category = gc_process_status
                    where inv_org_id = gt_item_cat_rec(lc_item_cat_idx).organization_id
                    and item_id = gn_inventory_item_id;
                    */


                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        print_msg_prc (
                            gc_debug_flag,
                               'gn_inventory_item_id    =>'
                            || gn_inventory_item_id
                            || ' organization_id => '
                            || gt_item_cat_rec (lc_item_cat_idx).organization_id
                            || ' gt_item_cat_rec(lc_item_cat_idx).record_id => '
                            || gt_item_cat_rec (lc_item_cat_idx).record_id);

                        UPDATE xxd_inv_item_cat_stg_t
                           SET record_status   = gc_error_status
                         WHERE record_id =
                               gt_item_cat_rec (lc_item_cat_idx).record_id;

                        ln_count         := SQL%ROWCOUNT;
                        print_msg_prc (
                            gc_debug_flag,
                               'gn_inventory_item_id    =>'
                            || gn_inventory_item_id
                            || ' organization_id => '
                            || gt_item_cat_rec (lc_item_cat_idx).organization_id
                            || ' gt_item_cat_rec(lc_item_cat_idx).record_id => '
                            || gt_item_cat_rec (lc_item_cat_idx).record_id);

                        /*
                                  -- Commenting this update to make this program reusable for other category assignments also
                        update XXDOCST_STAGE_STD_PENDING_CST
                       set status_category = gc_error_status, errmsg_category= nvl(xv_errbuf,'Error While creating/updating Category Assignment')
                       where inv_org_id = gt_item_cat_rec(lc_item_cat_idx).organization_id
                       and item_id IN( gn_inventory_item_id,(SELECT INVENTORY_ITEM_ID FROM XXD_INV_ITEM_CAT_STG_T where organization_id = gt_item_cat_rec(lc_item_cat_idx).organization_id
                                      and record_id = gt_item_cat_rec(lc_item_cat_idx).record_id and RECORD_STATUS = 'E') ); */

                        print_msg_prc (gc_debug_flag,
                                       'ln_count    =>' || ln_count);
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_item_category;

        COMMIT;

        retcode         := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (
                gc_debug_flag,
                   ' OTHERS Exception in cat_assignment_child_program - '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());

            retcode   := 2;
    END cat_assignment_child_program;

    PROCEDURE inv_category_load (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_category_set_name IN VARCHAR2
                                 , p_debug IN VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Function  Name       :  inv_category_validation                                             *
    *                                                                                             *
    * Description          :  Procedure to perform all the required validations                   *
    *                                                                                             *
    * Called From          :                                                                      *
    *                                                                                             *
    *  Change History                                                                             *
    *  -----------------                                                                          *
    *  Version    Date             Author                Description                              *
    *  ---------  ------------    ---------------       -----------------------------             *
                                                                                                 *
    *                                                                                             *
    **********************************************************************************************/
    IS
        /* CURSOR cur_item_category
         IS
            SELECT *
              FROM XXD_INV_ITEM_CAT_STG_T
             WHERE RECORD_STATUS = gc_validate_status;*/

        CURSOR cur_item_category (p_group_id NUMBER)
        IS
            SELECT *
              FROM xxd_inv_item_cat_stg_t
             WHERE record_status = gc_new_status AND GROUP_ID = p_group_id;

        CURSOR c_batch_num IS
            SELECT DISTINCT batch_number
              FROM xxd_inv_item_cat_stg_t;

        ln_batch_num            NUMBER;                -- c_batch_num%rowtype;

        CURSOR c_batch (p_batch_size NUMBER)
        IS
            SELECT record_id,
                   NTILE (p_batch_size)
                       OVER (ORDER BY
                                 category_set_name, segment1, segment2,
                                 segment3, segment4) batch_num
              FROM xxd_inv_item_cat_stg_t
             WHERE batch_number IS NULL AND record_status = gc_new_status;

        TYPE t_batch_type IS TABLE OF c_batch%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_batch_tab             t_batch_type;



        lc_err_msg              VARCHAR2 (2000) := NULL;
        x_return_status         VARCHAR2 (10) := NULL;
        l_category_set_exists   VARCHAR2 (10);
        l_old_category_id       NUMBER;
        l_segment_exists        VARCHAR2 (1);
        gn_organization_code    VARCHAR2 (30);
        xv_errbuf               VARCHAR2 (300);
        xn_retcode              NUMBER (10);
        ln_count                NUMBER (10);
        ln_success_count        NUMBER (20) := 0;
        ln_error_count          NUMBER (20) := 0;
        l_group_id              NUMBER;
        p_batch_size            NUMBER := 10;
        ln_cntr                 NUMBER := 0;
        lc_message              VARCHAR2 (200);
        ln_loop                 NUMBER;


        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id         hdr_batch_id_t;

        lc_phase                VARCHAR2 (200);
        lc_status               VARCHAR2 (200);
        ln_batch_cnt            NUMBER;
        ln_valid_rec_cnt        NUMBER;
        ln_parent_request_id    NUMBER := fnd_global.conc_request_id;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                request_table;

        ln_request_id           NUMBER;
        lc_dev_phase            VARCHAR2 (200);
        lc_dev_status           VARCHAR2 (200);
        lb_wait                 BOOLEAN;
    BEGIN
        gc_debug_flag   := p_debug;

        BEGIN
            SELECT DISTINCT GROUP_ID
              INTO l_group_id
              FROM xxd_inv_item_cat_stg_t
             WHERE category_set_name = p_category_set_name;


            fnd_file.put_line (fnd_file.output,
                               'Group Id for this run is - ' || l_group_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                print_msg_prc (gc_debug_flag,
                               'No Records found to process. ');
                l_group_id   := NULL;
            WHEN OTHERS
            THEN
                print_msg_prc (
                    gc_debug_flag,
                       'Error while getting group id for this run - '
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
                l_group_id   := 0;
        END;



        IF l_group_id IS NOT NULL
        THEN
            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_inv_item_cat_stg_t
             WHERE     batch_number IS NULL
                   AND record_status = gc_new_status
                   AND GROUP_ID = l_group_id;

            /*  FOR i IN 1 .. p_batch_size
              LOOP
                 BEGIN
                    SELECT XXTOP_ITEM_CATEGORIES_BATCH_S.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    print_msg_prc (
                       gc_debug_flag,
                       'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                 EXCEPTION
                    WHEN OTHERS
                    THEN
                       ln_hdr_batch_id (i + 1) := ln_hdr_batch_id (i) + 1;
                 END;

                 print_msg_prc (gc_debug_flag,
                                ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                 print_msg_prc (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_batch_size) := '
                    || CEIL (ln_valid_rec_cnt / p_batch_size));

                 UPDATE XXD_INV_ITEM_CAT_STG_T
                    SET batch_number = ln_hdr_batch_id (i),
                        conc_request_id = ln_parent_request_id
                  WHERE     batch_number IS NULL
                        AND ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_size)
                        AND RECORD_STATUS = gc_new_status;
              END LOOP;*/

            --meenakshi
            OPEN c_batch (p_batch_size);

            fnd_file.put_line (fnd_file.LOG, 'p_batch_size ' || p_batch_size);

            LOOP
                t_batch_tab.delete;

                FETCH c_batch BULK COLLECT INTO t_batch_tab LIMIT 5000;

                EXIT WHEN t_batch_tab.COUNT = 0;
                fnd_file.put_line (fnd_file.LOG,
                                   ' t_batch_tab.COUNT' || t_batch_tab.COUNT);

                FOR i IN 1 .. t_batch_tab.COUNT
                LOOP
                    BEGIN
                        UPDATE xxd_inv_item_cat_stg_t
                           SET batch_number = TO_NUMBER (t_batch_tab (i).batch_num), conc_request_id = ln_parent_request_id
                         WHERE record_id = t_batch_tab (i).record_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               ' exceptiomn' || SQLERRM);
                    END;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           ' t_batch_tab(i).batch_num'
                        || t_batch_tab (i).batch_num);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           't_batch_tab (i).record_id '
                        || t_batch_tab (i).record_id);
                END LOOP;

                COMMIT;
            END LOOP;

            CLOSE c_batch;


            COMMIT;

            UPDATE xxd_inv_item_cat_stg_t x2
               SET x2.batch_number   =
                       (SELECT MIN (batch_number)
                          FROM xxd_inv_item_cat_stg_t x1
                         WHERE     NVL (x1.segment1, 'XX') =
                                   NVL (x2.segment1, 'XX')
                               AND NVL (x1.segment2, 'XX') =
                                   NVL (x2.segment2, 'XX')
                               AND NVL (x1.segment3, 'XX') =
                                   NVL (x2.segment3, 'XX')
                               AND NVL (x1.segment4, 'XX') =
                                   NVL (x2.segment4, 'XX') -- AND X1.CATEGORY_SET_NAME = 'TARRIF CODE' --                  AND rownum = 1
                                                          ) --  WHERE CATEGORY_SET_NAME = 'TARRIF CODE'
                                                           ;

            fnd_file.put_line (fnd_file.LOG, 'Test3');

            COMMIT;
            ln_loop   := 1;

            OPEN c_batch_num;

            LOOP
                FETCH c_batch_num INTO ln_batch_num;

                EXIT WHEN c_batch_num%NOTFOUND;

                ln_hdr_batch_id (ln_loop)   := ln_batch_num;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_hdr_batch_id(ln_loop) ' || ln_hdr_batch_id (ln_loop));

                ln_loop                     := ln_loop + 1;
            END LOOP;

            CLOSE c_batch_num;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_inv_item_cat_stg_t
                 WHERE     record_status = gc_new_status
                       AND batch_number = ln_hdr_batch_id (l);

                fnd_file.put_line (fnd_file.LOG, 'ln_cntr ' || ln_cntr);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request ('XXDO', 'XXDO_CAT_ASSIGNMENT_CHILD_PRG', '', '', FALSE, ln_hdr_batch_id (l)
                                                             , 'N');
                        print_msg_prc (gc_debug_flag,
                                       'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (l)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            retcode   := 2;
                            errbuf    := errbuf || SQLERRM;
                            print_msg_prc (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXDO_CAT_ASSIGNMENT_CHILD_PRG error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            retcode   := 2;
                            errbuf    := errbuf || SQLERRM;
                            print_msg_prc (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXDO_CAT_ASSIGNMENT_CHILD_PRG error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            print_msg_prc (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXDO_CAT_ASSIGNMENT_CHILD_PRG to complete');

            IF l_req_id.COUNT > 0
            THEN
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    IF l_req_id (rec) > 0
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait         :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                                  ,
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                END LOOP;
            END IF;


            SELECT COUNT (*)
              INTO ln_success_count
              FROM xxd_inv_item_cat_stg_t
             WHERE GROUP_ID = l_group_id AND record_status = 'P';

            SELECT COUNT (*)
              INTO ln_error_count
              FROM xxd_inv_item_cat_stg_t
             WHERE GROUP_ID = l_group_id AND record_status = 'E';

            fnd_file.put_line (
                fnd_file.output,
                '                                                          ');
            fnd_file.put_line (
                fnd_file.output,
                '                                                          ');
            fnd_file.put_line (
                fnd_file.output,
                '========================Total Summary=============================');
            fnd_file.put_line (
                fnd_file.output,
                   'Total Number of records successfully processed ==> '
                || ln_success_count);
            fnd_file.put_line (
                fnd_file.output,
                   'Total Number of Error records                  ==> '
                || ln_error_count);
            fnd_file.put_line (
                fnd_file.output,
                '==================================================================');
        ELSE
            fnd_file.put_line (fnd_file.output, 'No Records to process');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (p_debug => gc_debug_flag, p_message => SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            lc_err_msg   :=
                   'Unexpected error while cursor fetching into PL/SQL table - '
                || SQLERRM;
            print_msg_prc (gc_debug_flag, lc_err_msg);
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Category Assignment program',
                p_error_line   => SQLCODE,
                p_error_msg    => lc_err_msg,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => NULL);
    END inv_category_load;
END xxdocst001_rep_pkg;
/
