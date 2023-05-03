--
-- XXD_MTL_CROSS_REFERENCES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_MTL_CROSS_REFERENCES_PKG"
AS
    /*******************************************************************************
      * Program Name : XXD_MTL_CI_XREF_IFACE_PKG
      * Language     : PL/SQL
      * Description  : This package will load data in to party, Customer, location, site, uses, contacts, account.
      *
      * History      :
      *
      * WHO                  WHAT              Desc                             WHEN
      * -------------- ---------------------------------------------- ---------------
      * BT Technology Team    1.0                                              17-JUN-2014
      *******************************************************************************/
    TYPE xxd_mtl_cross_ref_tab IS TABLE OF xxd_mtl_cross_ref_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_mtl_cross_ref_tab   xxd_mtl_cross_ref_tab;

    /******************************************************
            * Procedure: log_recordss
            *
            * Synopsis: This procedure will call we be called by the concurrent program
             * Design:
             *
             * Notes:
             *
             * PARAMETERS:
             *   IN    : p_debug    Varchar2
             *   IN    : p_message  Varchar2
             *
             * Return Values:
             * Modifications:
             *
             ******************************************************/
    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;


    FUNCTION get_inventory_org_loc (p_inv_org_id IN VARCHAR2)
        RETURN VARCHAR2
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
        x_org_loc   VARCHAR2 (250);
    BEGIN
        SELECT attribute1
          INTO x_org_loc
          FROM mtl_parameters
         WHERE organization_id = p_inv_org_id;

        log_records (
            gc_debug_flag,
            'create  If cross reference for x_org_loc => ' || x_org_loc);
        RETURN x_org_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                gn_org_id,
                'Deckers Item Cross References Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'get_new_inv_org_id',
                p_inv_org_id,
                'Exception to get_new_inv_org_id Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_inventory_org_loc;

    FUNCTION get_new_inv_org_id (p_old_org_id IN VARCHAR2)
        RETURN NUMBER
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
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        px_lookup_code   := p_old_org_id;
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING',
            -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1,
            -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM org_organization_definitions
         WHERE UPPER (organization_code) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                gn_org_id,
                'Deckers Item Cross References Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'get_new_inv_org_id',
                p_old_org_id,
                'Exception to get_new_inv_org_id Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_new_inv_org_id;

    PROCEDURE extract_1206_data (x_total_rec OUT NUMBER, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM xxd_mtl_cross_ref_stg_t
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;
        CURSOR lcu_cust_item_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   'NEW' record_status, NULL record_number, NULL batch_number,
                   inventory_item_id, organization_id, NULL target_organization_id,
                   cross_reference_type, cross_reference, last_update_date,
                   last_updated_by, creation_date, created_by,
                   last_update_login, description, org_independent_flag,
                   request_id, program_application_id, program_id,
                   program_update_date, attribute1, attribute2,
                   attribute3, attribute4, attribute5,
                   attribute6, attribute7, attribute8,
                   attribute9, attribute10, attribute11,
                   attribute12, attribute13, attribute14,
                   attribute15, attribute_category, uom_code,
                   revision_id, cross_reference_id, epc_gtin_serial,
                   source_system_id, start_date_active, end_date_active,
                   object_version_number, NULL error_message
              FROM mtl_cross_references_b@bt_read_1206 xaci
             --XXD_MTL_CROSS_REF_1206_T
             WHERE     1 = 1
                   --Modified 0n 24-JUL-2015
                   --AND xaci.inventory_item_id in (13048804) -- Testing
                   AND cross_reference_type NOT IN
                           ('Factory Code', 'Item Num Cross Reference', 'UPC Cross Reference')
                   AND organization_id IN
                           (SELECT flv.lookup_code
                              FROM fnd_lookup_values flv, mtl_parameters mp
                             WHERE     lookup_type =
                                       'XXD_1206_INV_ORG_MAPPING'
                                   AND language = 'US'
                                   AND flv.attribute1 = mp.organization_code)
                   --and 1=2
                   --Modified 0n 24-JUL-2015
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_system_items_b msb
                             WHERE xaci.inventory_item_id =
                                   msb.inventory_item_id --AND   XACI.record_status=gc_new_status
                                                        )
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_cross_references_b mtcr
                             WHERE     mtcr.inventory_item_id =
                                       xaci.inventory_item_id
                                   AND mtcr.cross_reference =
                                       xaci.cross_reference
                                   AND xaci.Cross_Reference_Type =
                                       xaci.Cross_Reference_Type --AND   XACI.record_status=gc_new_status
                                                                )
            UNION ALL
            --ORDER BY organization_id ASC
            SELECT /*+ FIRST_ROWS(10) */
                   DISTINCT 'NEW' record_status, NULL record_number, NULL batch_number,
                            msib.inventory_item_id, 7 organization_id, NULL target_organization_id,
                            'UPC Cross Reference' cross_reference_type, msib.attribute11 cross_reference, msib.last_update_date,
                            msib.last_updated_by, msib.creation_date, msib.created_by,
                            msib.last_update_login, NULL description, NVL (xaci.org_independent_flag, 'Y'), --Need to get confirmed
                            msib.request_id, msib.program_application_id, msib.program_id,
                            msib.program_update_date, msib.attribute1, msib.attribute2,
                            msib.attribute3, msib.attribute4, msib.attribute5,
                            msib.attribute6, msib.attribute7, msib.attribute8,
                            msib.attribute9, msib.attribute10, msib.attribute11,
                            msib.attribute12, msib.attribute13, msib.attribute14,
                            msib.attribute15, msib.attribute_category, xaci.uom_code,
                            xaci.revision_id, NVL (xaci.cross_reference_id, 1) cross_reference_id, xaci.epc_gtin_serial,
                            xaci.source_system_id, xaci.start_date_active, xaci.end_date_active,
                            xaci.object_version_number, NULL error_message
              FROM mtl_system_items_b msib,
                   mtl_parameters mp,
                   (SELECT uom_code, revision_id, cross_reference_id,
                           epc_gtin_serial, source_system_id, start_date_active,
                           end_date_active, object_version_number, org_independent_flag,
                           inventory_item_id
                      FROM mtl_cross_references_b@bt_read_1206
                     WHERE organization_id = 7) xaci
             WHERE     msib.attribute11 IS NOT NULL
                   AND msib.organization_id = mp.organization_id
                   AND msib.inventory_item_id = xaci.inventory_item_id(+)
                   AND mp.organization_code = 'MST'--AND msib.inventory_item_id in (13432994) -- Testing
                                                   ;
    BEGIN
        gtt_mtl_cross_ref_tab.DELETE;

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_MTL_CROSS_REF_STG_T';

        OPEN lcu_cust_item_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Site Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_mtl_cross_ref_tab.DELETE;

            FETCH lcu_cust_item_data
                BULK COLLECT INTO gtt_mtl_cross_ref_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_mtl_cross_ref_tab.COUNT
                INSERT INTO xxd_mtl_cross_ref_stg_t
                     VALUES gtt_mtl_cross_ref_tab (i);

            COMMIT;
            EXIT WHEN lcu_cust_item_data%NOTFOUND;
        END LOOP;


        DELETE xxd_mtl_cross_ref_stg_t
         WHERE ROWID NOT IN (  SELECT MIN (ROWID)
                                 FROM xxd_mtl_cross_ref_stg_t
                             GROUP BY inventory_item_id, organization_id);

        COMMIT;


        CLOSE lcu_cust_item_data;

        OPEN lcu_extract_count;

        FETCH lcu_extract_count INTO x_total_rec;

        CLOSE lcu_extract_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    PROCEDURE main (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                    , p_no_of_process IN NUMBER, p_debug_flag IN VARCHAR2)
    AS
        x_errcode              VARCHAR2 (500);
        x_errmsg               VARCHAR2 (500);
        lc_debug_flag          VARCHAR2 (1);
        ln_process             NUMBER;
        ln_ret                 NUMBER;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id        hdr_batch_id_t;
        lc_conlc_status        VARCHAR2 (150);
        ln_request_id          NUMBER := 0;
        lc_phase               VARCHAR2 (200);
        lc_status              VARCHAR2 (200);
        lc_dev_phase           VARCHAR2 (200);
        lc_dev_status          VARCHAR2 (200);
        lc_message             VARCHAR2 (200);
        ln_ret_code            NUMBER;
        lc_err_buff            VARCHAR2 (1000);
        ln_count               NUMBER;
        ln_cntr                NUMBER := 0;
        --      ln_batch_cnt          NUMBER                                   := 0;
        ln_parent_request_id   NUMBER := fnd_global.conc_request_id;
        lb_wait                BOOLEAN;
        lx_return_mesg         VARCHAR2 (2000);
        ln_valid_rec_cnt       NUMBER;
        x_total_rec            NUMBER;
        x_validrec_cnt         NUMBER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id               request_table;
    BEGIN
        gc_debug_flag   := p_debug_flag;

        IF p_process = gc_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            --          truncte_stage_tables (x_ret_code =>  x_retcode, x_return_mesg => x_errbuf);
            extract_1206_data (x_total_rec   => x_total_rec,
                               x_errbuf      => x_errbuf,
                               x_retcode     => x_retcode);
        ELSIF p_process = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling cust_item_validation :');
            fnd_file.put_line (fnd_file.LOG,
                               'Call Procedure create_batch_prc.');

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_mtl_cross_ref_stg_t
             WHERE batch_number IS NULL AND record_status = gc_new_status;

            --write_log ('Creating Batch id and update  XXD_AR_CUST_INT_STG_T');
            -- Create batches of records and assign batch id
            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT xxd_mtl_cross_ref_stg_s.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                log_records (gc_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                    || CEIL (ln_valid_rec_cnt / p_no_of_process));

                UPDATE xxd_mtl_cross_ref_stg_t
                   SET batch_number = ln_hdr_batch_id (i), request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND record_status = gc_new_status;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_MTL_CROSS_REF_STG_T');
        ELSIF p_process = gc_load_only
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Loading Process Initiated');
            fnd_file.put_line (fnd_file.LOG,
                               'Call Procedure min_max_batch_prc');
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_MTL_CROSS_REF_STG_T stage to call worker process');
            ln_cntr   := 0;

            FOR i
                IN (SELECT DISTINCT batch_number
                      FROM xxd_mtl_cross_ref_stg_t
                     WHERE     batch_number IS NOT NULL
                           AND record_status = gc_validate_status)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_MTL_CROSS_REF_STG_T');
        END IF;

        COMMIT;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            log_records (
                gc_debug_flag,
                   'Calling XXD_MTL_CROSS_REFERENCES_CHILD in batch '
                || ln_hdr_batch_id.COUNT);

            IF p_process = gc_load_only
            THEN
                UPDATE xxd_mtl_cross_ref_stg_t
                   SET batch_number   = ln_hdr_batch_id (ln_cntr) + 999
                 WHERE     target_organization_id =
                           (SELECT organization_id
                              FROM mtl_parameters
                             WHERE organization_code = 'MST')
                       AND record_status = gc_validate_status;

                ln_request_id   :=
                    apps.fnd_request.submit_request (
                        'XXDCONV',
                        'XXD_MTL_CROSS_REFERENCES_CHILD',
                        '',
                        '',
                        FALSE,
                        gc_debug_flag,
                        p_process,
                        ln_hdr_batch_id (ln_cntr) + 999,
                        ln_parent_request_id);
                log_records (gc_debug_flag,
                             'v_request_id := ' || ln_request_id);

                IF ln_request_id > 0
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;

                log_records (
                    gc_debug_flag,
                       'Calling XXD_MTL_CROSS_REFERENCES_CHILD in batch '
                    || ln_hdr_batch_id.COUNT);
                log_records (
                    gc_debug_flag,
                    'Calling WAIT FOR REQUEST XXD_MTL_CROSS_REFERENCES_CHILD to complete');

                --FOR rec in l_req_id.FIRST .. l_req_id.LAST  LOOP
                IF ln_request_id > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_request_id--ln_concurrent_request_id
                                                             ,
                                INTERVAL     => 1,
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
            END IF;

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_mtl_cross_ref_stg_t
                 WHERE batch_number = ln_hdr_batch_id (i);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        log_records (
                            gc_debug_flag,
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_MTL_CROSS_REFERENCES_CHILD',
                                '',
                                '',
                                FALSE,
                                gc_debug_flag,
                                p_process,
                                ln_hdr_batch_id (i),
                                ln_parent_request_id);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_MTL_CROSS_REFERENCES_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_MTL_CROSS_REFERENCES_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            log_records (
                gc_debug_flag,
                   'Calling XXD_MTL_CROSS_REFERENCES_CHILD in batch '
                || ln_hdr_batch_id.COUNT);
            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_MTL_CROSS_REFERENCES_CHILD to complete');

            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec)--ln_concurrent_request_id
                                                              ,
                                INTERVAL     => 1,
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
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);
    END main;

    PROCEDURE cust_item_validation (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                                    , p_batch_number IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lc_status                 VARCHAR2 (20);
        ln_cnt                    NUMBER := 0;

        CURSOR cur_cust_item (p_process VARCHAR2)
        IS
              SELECT *
                FROM xxd_mtl_cross_ref_stg_t cust
               WHERE     record_status = p_process
                     AND batch_number = p_batch_number
            ORDER BY organization_id ASC;

        TYPE lt_customer_typ IS TABLE OF cur_cust_item%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_data              lt_customer_typ;
        lc_cust_item_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lc_error_msg              VARCHAR2 (2000);
        ln_new_inv_org_id         NUMBER;
        lc_attribute11            VARCHAR2 (150);       --Added on 24-JUL-2015
        ln_organization_id        NUMBER;
    BEGIN
        x_retcode   := NULL;
        x_errbuf    := NULL;
        log_records (gc_debug_flag,
                     'validate Customer p_process =.  ' || p_process);

        OPEN cur_cust_item (p_process => 'NEW');

        LOOP
            FETCH cur_cust_item BULK COLLECT INTO lt_cust_data LIMIT 100;

            log_records (gc_debug_flag,
                         'validate Customer ' || lt_cust_data.COUNT);
            EXIT WHEN lt_cust_data.COUNT = 0;

            IF lt_cust_data.COUNT > 0
            THEN
                FOR xc_custr_rec IN lt_cust_data.FIRST .. lt_cust_data.LAST
                LOOP
                    --            gc_customer_name := lt_cust_data (xc_custr_rec).customer_name;
                    lc_cust_item_valid_data   := gc_yes_flag;
                    lc_error_msg              := NULL;

                    IF lt_cust_data (xc_custr_rec).cross_reference_type
                           IS NULL
                    THEN
                        lc_cust_item_valid_data   := gc_no_flag;
                        lc_error_msg              :=
                               lc_error_msg
                            || ' CROSS_REFERENCE_TYPE Can not be null for the customer item '
                            || lt_cust_data (xc_custr_rec).cross_reference
                            || 'and Item  '
                            || lt_cust_data (xc_custr_rec).inventory_item_id;
                    ELSE
                        BEGIN
                            SELECT 1
                              INTO ln_cnt
                              FROM mtl_cross_reference_types
                             WHERE cross_reference_type =
                                   lt_cust_data (xc_custr_rec).cross_reference_type;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_item_valid_data   := gc_no_flag;
                                lc_error_msg              :=
                                       lc_error_msg
                                    || ' CROSS_REFERENCE_TYPE Not Available in system for the customer item '
                                    || lt_cust_data (xc_custr_rec).cross_reference
                                    || 'and Item  '
                                    || lt_cust_data (xc_custr_rec).inventory_item_id;
                            WHEN OTHERS
                            THEN
                                lc_cust_item_valid_data   := gc_no_flag;
                                lc_error_msg              :=
                                       lc_error_msg
                                    || SQLERRM
                                    || ' for the customer item '
                                    || lt_cust_data (xc_custr_rec).cross_reference
                                    || 'and Item  '
                                    || lt_cust_data (xc_custr_rec).inventory_item_id;
                        END;
                    END IF;

                    BEGIN
                        SELECT 1
                          INTO ln_cnt
                          FROM mtl_system_items_b msb
                         WHERE     inventory_item_id =
                                   lt_cust_data (xc_custr_rec).inventory_item_id
                               AND EXISTS
                                       (SELECT organization_id
                                          FROM mtl_parameters mp
                                         WHERE     mp.organization_id =
                                                   msb.organization_id
                                               AND organization_code = 'MST');
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_cust_item_valid_data   := gc_no_flag;
                            lc_error_msg              :=
                                   lc_error_msg
                                || ' Item Not Available in system for the  item '
                                || lt_cust_data (xc_custr_rec).inventory_item_id
                                || 'and organization  '
                                || lt_cust_data (xc_custr_rec).organization_id;
                        WHEN OTHERS
                        THEN
                            lc_cust_item_valid_data   := gc_no_flag;
                            lc_error_msg              :=
                                   lc_error_msg
                                || SQLERRM
                                || ' for the customer item '
                                || lt_cust_data (xc_custr_rec).cross_reference
                                || 'and Item  '
                                || lt_cust_data (xc_custr_rec).inventory_item_id;
                    END;

                    IF lt_cust_data (xc_custr_rec).organization_id
                           IS NOT NULL
                    THEN
                        ln_new_inv_org_id   := NULL;
                        ln_new_inv_org_id   :=
                            get_new_inv_org_id (
                                p_old_org_id   =>
                                    lt_cust_data (xc_custr_rec).organization_id);

                        IF ln_new_inv_org_id IS NULL
                        THEN
                            lc_cust_item_valid_data   := gc_no_flag;
                            lc_error_msg              :=
                                   lc_error_msg
                                || ' Inventory Org mapping Not Available in system for the customer item '
                                || lt_cust_data (xc_custr_rec).cross_reference
                                || 'and Item  '
                                || lt_cust_data (xc_custr_rec).inventory_item_id
                                || ' and Organization id '
                                || lt_cust_data (xc_custr_rec).organization_id;
                        END IF;
                    END IF;

                    fnd_file.put_line (fnd_file.LOG, lc_cust_item_valid_data);
                    fnd_file.put_line (fnd_file.LOG, lc_error_msg);


                    IF lc_cust_item_valid_data = gc_no_flag
                    THEN
                        UPDATE xxd_mtl_cross_ref_stg_t
                           SET error_message = lc_error_msg, record_status = gc_error_status
                         WHERE     cross_reference =
                                   lt_cust_data (xc_custr_rec).cross_reference
                               AND inventory_item_id =
                                   lt_cust_data (xc_custr_rec).inventory_item_id
                               AND NVL (organization_id, 99) =
                                   NVL (
                                       lt_cust_data (xc_custr_rec).organization_id,
                                       99)
                               AND batch_number = p_batch_number;

                        xxd_common_utils.record_error (
                            'AR',
                            -1,
                            'Deckers Item Cross References Conversion Program',
                            --      SQLCODE,
                            lc_error_msg,
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            'INVENTORY_ITEM_ID',
                            lt_cust_data (xc_custr_rec).inventory_item_id,
                            'CROSS_REFERENCE',
                            lt_cust_data (xc_custr_rec).cross_reference);
                    ELSE
                        UPDATE xxd_mtl_cross_ref_stg_t
                           SET error_message = NULL, record_status = gc_validate_status, target_organization_id = ln_new_inv_org_id
                         WHERE     cross_reference =
                                   lt_cust_data (xc_custr_rec).cross_reference
                               AND inventory_item_id =
                                   lt_cust_data (xc_custr_rec).inventory_item_id
                               AND NVL (organization_id, 99) =
                                   NVL (
                                       lt_cust_data (xc_custr_rec).organization_id,
                                       99)
                               AND batch_number = p_batch_number;

                        IF lt_cust_data (xc_custr_rec).CROSS_REFERENCE_TYPE =
                           'UPC Cross Reference'
                        THEN
                            --IF get_inventory_org_loc (p_inv_org_id => ln_new_inv_org_id) = 'US'                                THEN --Modified on 24-JUL-2015
                            log_records (
                                gc_debug_flag,
                                'create  If cross reference is available in any assign to all  orgs  ');

                            --Start Modification  on 24-JUL-2015

                            /*   lc_attribute11 := NULL;

                            BEGIN
                                SELECT attribute11 into lc_attribute11
                                 from mtl_system_items_b msib
                                 where inventory_item_id =
                                                                     lt_cust_data (xc_custr_rec).inventory_item_id and attribute11 is not null and rownum = 1
                         ;
                            EXCEPTION
                            WHEN OTHERS THEN
                            NULL;
                            END; */

                            --fnd_file.put_line(fnd_file.log,'lc_attribute11 '||lc_attribute11);

                            --IF lc_attribute11 IS NOT NULL THEN
                            --End Modification  on 24-JUL-2015

                            FOR us_og
                                IN (SELECT mp.organization_id
                                      FROM mtl_parameters mp, mtl_system_items_b msib
                                     WHERE     mp.attribute1 IS NOT NULL
                                           AND mp.organization_code <> 'MST'
                                           AND msib.organization_id =
                                               mp.organization_id
                                           AND msib.inventory_item_id =
                                               lt_cust_data (xc_custr_rec).inventory_item_id)
                            LOOP
                                /* BEGIN
                                                        SELECT count (1)
                                                          INTO ln_cnt
                                                          FROM xxd_mtl_cross_ref_stg_t
                                                         WHERE cross_reference =
                                                                        lt_cust_data (xc_custr_rec).cross_reference
                                                          AND   cross_reference_type = lt_cust_data (xc_custr_rec).cross_reference_type
                                                          AND inventory_item_id =
                                                                      lt_cust_data (xc_custr_rec).inventory_item_id
                                                          AND target_organization_id =  us_og.organization_id;
                                 EXCEPTION
                                     WHEN OTHERS THEN
                                     NULL;
                                 END;

                                                          IF ln_cnt = 0 THEN*/
                                ln_organization_id   := us_og.organization_id;

                                INSERT INTO xxd_mtl_cross_ref_stg_t
                                    (SELECT /*+ FIRST_ROWS(10) */
                                            gc_validate_status, NULL record_number, lt_cust_data (xc_custr_rec).batch_number,
                                            inventory_item_id, ln_organization_id, -- organization_id,
                                                                                   us_og.organization_id,
                                            cross_reference_type, cross_reference, last_update_date,
                                            last_updated_by, creation_date, created_by,
                                            last_update_login, description, org_independent_flag,
                                            request_id, program_application_id, program_id,
                                            program_update_date, attribute1, attribute2,
                                            attribute3, attribute4, attribute5,
                                            attribute6, attribute7, attribute8,
                                            attribute9, attribute10, attribute11,
                                            attribute12, attribute13, attribute14,
                                            attribute15, attribute_category, uom_code,
                                            revision_id, cross_reference_id, epc_gtin_serial,
                                            source_system_id, start_date_active, end_date_active,
                                            object_version_number, NULL error_message
                                       FROM xxd_mtl_cross_ref_stg_t stg1
                                      WHERE     cross_reference =
                                                lt_cust_data (xc_custr_rec).cross_reference
                                            AND cross_reference_type =
                                                lt_cust_data (xc_custr_rec).cross_reference_type
                                            AND inventory_item_id =
                                                lt_cust_data (xc_custr_rec).inventory_item_id
                                            AND ROWNUM <= 1);
                            --END IF;
                            END LOOP;

                            --END IF;

                            --Modified on 24-JUL-2015
                            UPDATE xxd_mtl_cross_ref_stg_t
                               SET cross_reference = '00' || cross_reference
                             WHERE     inventory_item_id =
                                       lt_cust_data (xc_custr_rec).inventory_item_id
                                   AND CROSS_REFERENCE_TYPE =
                                       'UPC Cross Reference'
                                   AND batch_number = p_batch_number;
                        --Modified on 24-JUL-2015
                        --ELSE
                        /*    FOR us_og in (SELECT organization_id from mtl_parameters where attribute1 is not null ) LOOP

                                        SELECT count (1)
                                          INTO ln_cnt
                                          FROM xxd_mtl_cross_ref_stg_t
                                         WHERE cross_reference =
                                                        lt_cust_data (xc_custr_rec).cross_reference
                                          AND   cross_reference_type = lt_cust_data (xc_custr_rec).cross_reference_type
                                          AND inventory_item_id =
                                                      lt_cust_data (xc_custr_rec).inventory_item_id
                                          AND target_organization_id =  us_og.organization_id;

                                          IF ln_cnt = 0 THEN

                                          INSERT INTO xxd_mtl_cross_ref_stg_t (
                           SELECT   /*+ FIRST_ROWS(10) */
                        /*      gc_validate_status, NULL record_number,
                              lt_cust_data (xc_custr_rec).batch_number,
                              inventory_item_id, organization_id,
                              us_og.organization_id, cross_reference_type,
                              cross_reference, last_update_date, last_updated_by,
                              creation_date, created_by, last_update_login, description,
                              org_independent_flag, request_id, program_application_id,
                              program_id, program_update_date, attribute1, attribute2,
                              attribute3, attribute4, attribute5, attribute6, attribute7,
                              attribute8, attribute9, attribute10, attribute11,
                              attribute12, attribute13, attribute14, attribute15,
                              attribute_category, uom_code, revision_id,
                              cross_reference_id, epc_gtin_serial, source_system_id,
                              start_date_active, end_date_active, object_version_number,
                              NULL error_message
                             FROM xxd_mtl_cross_ref_stg_t stg1
                             WHERE cross_reference      =  lt_cust_data (xc_custr_rec).cross_reference
                             AND   cross_reference_type = lt_cust_data (xc_custr_rec).cross_reference_type
                             AND inventory_item_id      = lt_cust_data (xc_custr_rec).inventory_item_id
                             AND rownum <= 1
                             );

                      END IF;
                 END LOOP;*/
                        --END IF;
                        END IF;
                    END IF;

                    lc_error_msg              := NULL;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        COMMIT;

        CLOSE cur_cust_item;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
            ROLLBACK;
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception Raised During Validation Program');
            --  ROLLBACK;
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
            ROLLBACK;
    END cust_item_validation;

    PROCEDURE transfer_records (x_retcode           OUT NUMBER,
                                x_errbuf            OUT VARCHAR2,
                                p_batch_number   IN     NUMBER)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the gl_interface program               *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_ci_val_t IS TABLE OF xxd_mtl_cross_ref_stg_t%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_ci_val_type     type_ci_val_t;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
              SELECT *
                FROM xxd_mtl_cross_ref_stg_t xgpi
               WHERE     xgpi.record_status = gc_validate_status
                     AND batch_number = p_batch_number
            --and inventory_item_id = 10064262
            -- and organization_id = 7
            ORDER BY organization_id ASC;

        l_api_version      NUMBER := 1.0;
        l_init_msg_list    VARCHAR2 (2) := fnd_api.g_true;
        l_commit           VARCHAR2 (2) := fnd_api.g_true;
        l_user_id          NUMBER := -1;
        l_resp_id          NUMBER := -1;
        l_application_id   NUMBER := -1;
        --      l_user_name        VARCHAR2 (30)                        := 'PVADREVU001';
        l_resp_name        VARCHAR2 (30) := 'INVENTORY';
        l_xref_tbl         mtl_cross_references_pub.xref_tbl_type;
        x_message_list     error_handler.error_tbl_type;
        x_return_status    VARCHAR2 (2);
        x_msg_count        NUMBER := 0;
        ln_rec_cont        NUMBER := 0;
    BEGIN
        x_retcode         := NULL;
        x_errbuf          := NULL;
        gc_code_pointer   := 'transfer_records';
        log_records (gc_debug_flag, 'Start of transfer_records procedure');

        /* -- Get the user_id
         SELECT user_id
           INTO l_user_id
           FROM fnd_user
          WHERE user_name = l_user_name;*/

        -- Get the application_id and responsibility_id
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility
         WHERE responsibility_key = l_resp_name;

        fnd_global.apps_initialize (apps.fnd_global.user_id,
                                    l_resp_id,
                                    l_application_id);

        OPEN c_get_valid_rec;

        LOOP
            lt_ci_val_type.DELETE;

            FETCH c_get_valid_rec BULK COLLECT INTO lt_ci_val_type LIMIT 100;

            IF lt_ci_val_type.COUNT > 0
            THEN
                FOR row_cnt IN 1 .. lt_ci_val_type.COUNT
                LOOP
                    ln_rec_cont                                     := 1;
                    l_xref_tbl.delete;
                    -- Valid Case 1
                    l_xref_tbl (ln_rec_cont).transaction_type       := 'CREATE';
                    l_xref_tbl (ln_rec_cont).cross_reference_type   :=
                        lt_ci_val_type (row_cnt).cross_reference_type;
                    l_xref_tbl (ln_rec_cont).inventory_item_id      :=
                        lt_ci_val_type (row_cnt).inventory_item_id;
                    l_xref_tbl (ln_rec_cont).cross_reference        :=
                        lt_ci_val_type (row_cnt).cross_reference;

                    IF lt_ci_val_type (row_cnt).target_organization_id
                           IS NULL
                    THEN
                        l_xref_tbl (ln_rec_cont).org_independent_flag   :=
                            'Y';
                    ELSE
                        l_xref_tbl (ln_rec_cont).organization_id   :=
                            lt_ci_val_type (row_cnt).target_organization_id;
                    END IF;

                    l_xref_tbl (ln_rec_cont).attribute1             :=
                        lt_ci_val_type (row_cnt).attribute1;
                    l_xref_tbl (ln_rec_cont).attribute2             :=
                        lt_ci_val_type (row_cnt).attribute2;
                    l_xref_tbl (ln_rec_cont).attribute3             :=
                        lt_ci_val_type (row_cnt).attribute3;
                    l_xref_tbl (ln_rec_cont).attribute4             :=
                        lt_ci_val_type (row_cnt).attribute4;
                    l_xref_tbl (ln_rec_cont).attribute5             :=
                        lt_ci_val_type (row_cnt).attribute5;


                    mtl_cross_references_pub.process_xref (
                        p_api_version     => l_api_version,
                        p_init_msg_list   => l_init_msg_list,
                        p_commit          => l_commit,
                        p_xref_tbl        => l_xref_tbl,
                        x_return_status   => x_return_status,
                        x_msg_count       => x_msg_count,
                        x_message_list    => x_message_list);



                    IF x_return_status = fnd_api.g_ret_sts_error
                    THEN
                        --Error_Handler.GET_MESSAGE_LIST(x_message_list=>x_message_list);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error Message Count :' || x_message_list.COUNT);

                        FOR i IN 1 .. x_message_list.COUNT
                        LOOP
                            xxd_common_utils.record_error (
                                'AR',
                                -1,
                                'Deckers Item Cross References Conversion Program',
                                   --      SQLCODE,
                                   TO_CHAR (i)
                                || '. Err Rec No :
                                                '
                                || x_message_list (i).entity_index
                                || ' Table Name :
                                                '
                                || x_message_list (i).table_name,
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --    SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                p_batch_number,
                                lt_ci_val_type (row_cnt).inventory_item_id,
                                lt_ci_val_type (row_cnt).target_organization_id);
                            xxd_common_utils.record_error (
                                'AR',
                                -1,
                                'Deckers Item Cross References Conversion Program',
                                   --      SQLCODE,
                                   'Err Message: '
                                || x_message_list (i).MESSAGE_TEXT,
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --    SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                p_batch_number,
                                lt_ci_val_type (row_cnt).inventory_item_id,
                                lt_ci_val_type (row_cnt).target_organization_id);
                        END LOOP;
                    END IF;

                    ln_rec_cont                                     := 0;
                    COMMIT;
                END LOOP;
            END IF;


            EXIT WHEN c_get_valid_rec%NOTFOUND;
        END LOOP;

        --        x_rec_count := ln_valid_rec_cnt;
        UPDATE xxd_mtl_cross_ref_stg_t xgpi
           SET xgpi.record_status   = gc_process_status
         WHERE     EXISTS
                       (SELECT 1
                          FROM mtl_cross_references_b
                         WHERE     cross_reference = xgpi.cross_reference
                               AND inventory_item_id = xgpi.inventory_item_id
                               AND NVL (organization_id, 99) =
                                   NVL (xgpi.target_organization_id, 99))
               AND batch_number = p_batch_number;

        UPDATE xxd_mtl_cross_ref_stg_t xgpi
           SET xgpi.record_status   = gc_error_status
         WHERE     NOT EXISTS
                       (SELECT 1
                          FROM mtl_cross_references_b
                         WHERE     cross_reference = xgpi.cross_reference
                               AND inventory_item_id = xgpi.inventory_item_id
                               AND NVL (organization_id, 99) =
                                   NVL (xgpi.target_organization_id, 99))
               AND batch_number = p_batch_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: transfer_records');
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');
    END transfer_records;

    PROCEDURE item_ref_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N'
                              , p_action IN VARCHAR2, p_batch_number IN NUMBER, p_parent_request_id IN NUMBER)
    AS
        le_invalid_param    EXCEPTION;
        ln_new_ou_id        hr_operating_units.organization_id%TYPE;
        --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12
        ln_request_id       NUMBER := 0;
        lc_username         fnd_user.user_name%TYPE;
        lc_operating_unit   hr_operating_units.NAME%TYPE;
        lc_cust_num         VARCHAR2 (5);
        lc_pri_flag         VARCHAR2 (1);
        ld_start_date       DATE;
        ln_ins              NUMBER := 0;
        --ln_request_id             NUMBER                     := 0;
        lc_phase            VARCHAR2 (200);
        lc_status           VARCHAR2 (200);
        lc_delc_phase       VARCHAR2 (200);
        lc_delc_status      VARCHAR2 (200);
        lc_message          VARCHAR2 (200);
        ln_ret_code         NUMBER;
        lc_err_buff         VARCHAR2 (1000);
        ln_count            NUMBER;
        l_target_org_id     NUMBER;
    BEGIN
        gc_debug_flag        := p_debug_flag;

        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run By      :'
            || lc_username);
        --      fnd_file.put_line (fnd_file.LOG, '                                         Run Date    :' || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_number);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (gc_debug_flag,
                     '******** START of cust item  Import Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        gc_debug_flag        := p_debug_flag;
        gn_org_id            := 0;
        gn_conc_request_id   := p_parent_request_id;

        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling cust_item_validation :');
            cust_item_validation (x_retcode => retcode, x_errbuf => errbuf, p_process => p_action
                                  , p_batch_number => p_batch_number);
        ELSIF p_action = gc_load_only
        THEN
            transfer_records (x_retcode        => retcode,
                              x_errbuf         => errbuf,
                              p_batch_number   => p_batch_number);
            NULL;
        END IF;
    --      print_processing_summary ( x_ret_code  => RETCODE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output,
                               'Exception Raised During cust item  Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END item_ref_child;
END xxd_mtl_cross_references_pkg;
/
