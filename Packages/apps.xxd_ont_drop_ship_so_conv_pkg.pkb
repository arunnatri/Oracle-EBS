--
-- XXD_ONT_DROP_SHIP_SO_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_DROP_SHIP_SO_CONV_PKG"
/**********************************************************************************************************
    File Name    : XXD_ONT_DROP_SHIP_SO_CONV_PKG
    Created On   : 06-Apr-2014
    Created By   : BT Technology Team
    Purpose      : This  package is to extract Drop Ship Sales Orders data from 12.0.6 EBS
                   and import into 12.2.3 EBS after validations.
   ***********************************************************************************************************
   Modification History:
   Version   SCN#        By                        Date                     Comments
    1.0              BT Technology Team          06-Apr-2014               Base Version
    1.1              BT Technology Team          19-May-2015               Updated derivation for get_agent_id and get_person_id
    1.2              BT Technology Team          01-Jul-2015               Logic added to update edi status flag for PO
   **********************************************************************************************************
   Parameters: 1.Mode
               2.Number of processes
               3.Debug Flag
               4.Operating Unit
   **********************************************************************************************************/
AS
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
    TYPE XXD_ONT_ORDER_LINES_TAB
        IS TABLE OF XXD_ONT_DIST_LINES_CONV_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ont_order_lines_tab   XXD_ONT_ORDER_LINES_TAB;

    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    PROCEDURE write_log (p_message IN VARCHAR2)
    -- +===================================================================+
    -- | Name  : WRITE_LOG                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+
    IS
    BEGIN
        IF gc_debug_flag = 'Y'
        THEN
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, p_message);
        END IF;
    END write_log;

    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        log_records (gc_debug_flag,
                     'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.xxd_drop_ship_so_conv_stg_t';

        log_records (gc_debug_flag, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            log_records (gc_debug_flag,
                         'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('AR', gn_org_id, 'Deckers Drop Shipment sales Order Conversion Program', --  SQLCODE,
                                                                                                                    SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --   SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;

    PROCEDURE set_org_context (p_target_org_id IN NUMBER, p_resp_id OUT NUMBER, p_resp_appl_id OUT NUMBER)
    AS
    BEGIN
        SELECT LEVEL_VALUE_APPLICATION_ID, fr.RESPONSIBILITY_ID
          INTO p_resp_appl_id, p_resp_id
          FROM fnd_profile_option_values fpov, FND_RESPONSIBILITY_TL fr, fnd_profile_options fpo
         WHERE     fpo.PROFILE_OPTION_ID = fpov.PROFILE_OPTION_ID --AND LEVEL_ID =
               AND LEVEL_VALUE = fr.RESPONSIBILITY_ID
               AND LEVEL_ID = 10003
               AND language = 'US'
               AND PROFILE_OPTION_NAME = 'DEFAULT_ORG_ID'
               AND RESPONSIBILITY_NAME LIKE 'Purchasing%Super%User%'
               AND profile_option_value = TO_CHAR (p_target_org_id)
               AND ROWNUM < 2;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END set_org_context;

    PROCEDURE extract_1206_data (p_org_name       IN     VARCHAR2,
                                 x_total_rec         OUT NUMBER,
                                 x_validrec_cnt      OUT NUMBER,
                                 x_errbuf            OUT VARCHAR2,
                                 x_retcode           OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;
        ln_req_insert_count       NUMBER;
        ln_req_avail_count        NUMBER;

        CURSOR lcu_drop_ship_orders IS
            SELECT *
              FROM XXD_CONV.XXD_1206_OE_DROP_SHIP_REQ xods
             WHERE                                  -- xods.org_id = ln_org_id
                       EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all ool, oe_drop_ship_sources oedss
                             WHERE     ool.ORIG_SYS_DOCUMENT_REF =
                                       xods.ORIG_SYS_DOCUMENT_REF
                                   AND ool.ORIG_SYS_line_REF =
                                       xods.ORIG_SYS_line_REF
                                   AND oedss.line_id = ool.line_id
                                   AND oedss.po_line_id IS NULL
                                   AND ool.FLOW_STATUS_CODE =
                                       'AWAITING_RECEIPT')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM po_requisition_headers_all
                             WHERE SEGMENT1 = REQUISITION_NUMBER);



        /*   AND EXISTS
                  (SELECT 1
                     FROM oe_order_lines_all ool
                    WHERE     ool.ORIG_SYS_DOCUMENT_REF =xods.ORIG_SYS_DOCUMENT_REF
                               --  ('IOE-FOB-114372-20150323')
                          AND ool.FLOW_STATUS_CODE = 'AWAITING_RECEIPT')
           AND NOT EXISTS
                  (SELECT 1
                     FROM po_requisition_headers_all
                    WHERE SEGMENT1 = REQUISITION_NUMBER);*/

        TYPE XXD_ONT_DROP_SHIP_TAB
            IS TABLE OF XXD_1206_OE_DROP_SHIP_REQ%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_drop_ship_tab       XXD_ONT_DROP_SHIP_TAB;
    BEGIN
        lv_error_stage   := 'In Extract procedure extract_1206_data()';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        fnd_file.put_line (
            fnd_file.LOG,
            'Inserting data into stage table XXD_DROP_SHIP_SO_CONV_STG_T');
        t_ont_drop_ship_tab.delete;

        /*FOR lc_org
           IN (SELECT lookup_code
                 FROM apps.fnd_lookup_values
                WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                      AND attribute1 = p_org_name
                      AND language = 'US')
        LOOP*/
        OPEN lcu_drop_ship_orders;

        LOOP
            /* lv_error_stage := 'Inserting Drop ship Data into Staging';
             fnd_file.put_line (fnd_file.LOG, lv_error_stage);
             lv_error_stage := 'Org Id' || lc_org.lookup_code;
             fnd_file.put_line (fnd_file.LOG, lv_error_stage);  */
            t_ont_drop_ship_tab.delete;

            FETCH lcu_drop_ship_orders
                BULK COLLECT INTO t_ont_drop_ship_tab
                LIMIT 5000;

            IF t_ont_drop_ship_tab.COUNT > 0
            THEN
                FORALL l_indx IN 1 .. t_ont_drop_ship_tab.COUNT
                    INSERT INTO xxd_drop_ship_so_conv_stg_t (
                                    RECORD_ID,
                                    ORG_ID,
                                    CATEGORY_ID,
                                    AUTHORIZATION_STATUS,
                                    --   AGENT_NAME                 ,
                                    REQUISITION_HEADER_ID,
                                    -- CATEGORY_NAME              ,
                                    REQUISITION_TYPE,
                                    DELIVER_TO_LOCATION_ID,
                                    DESTINATION_ORGANIZATION_ID,
                                    SOURCE_ORGANIZATION_ID,
                                    DESTINATION_TYPE_CODE,
                                    ITEM_NUMBER,
                                    ITEM_DESCRIPTION,
                                    ITEM_ID,
                                    LINE_NUM,
                                    LINE_TYPE,
                                    LINE_TYPE_ID,
                                    NEED_BY_DATE,
                                    DESTINATION_ORGANIZATION_NAME,
                                    SOURCE_ORGANIZATION_NAME,
                                    PREPARER,
                                    PREPARER_ID,
                                    QUANTITY,
                                    REQUESTOR,
                                    REQUISITION_NUMBER,
                                    SOURCE_TYPE_CODE,
                                    TO_PERSON_ID,
                                    UNIT_MEAS_LOOKUP_CODE,
                                    UNIT_PRICE,
                                    OPERATING_UNIT,
                                    HEADER_ATTRIBUTE_CATEGORY,
                                    HEADER_ATTRIBUTE1,
                                    HEADER_ATTRIBUTE2,
                                    HEADER_ATTRIBUTE3,
                                    HEADER_ATTRIBUTE4,
                                    HEADER_ATTRIBUTE5,
                                    HEADER_ATTRIBUTE6,
                                    HEADER_ATTRIBUTE7,
                                    HEADER_ATTRIBUTE8,
                                    HEADER_ATTRIBUTE9,
                                    HEADER_ATTRIBUTE10,
                                    HEADER_ATTRIBUTE11,
                                    HEADER_ATTRIBUTE12,
                                    HEADER_ATTRIBUTE13,
                                    HEADER_ATTRIBUTE14,
                                    HEADER_ATTRIBUTE15,
                                    LINE_ATTRIBUTE_CATEGORY,
                                    LINE_ATTRIBUTE1,
                                    LINE_ATTRIBUTE2,
                                    LINE_ATTRIBUTE3,
                                    LINE_ATTRIBUTE4,
                                    LINE_ATTRIBUTE5,
                                    LINE_ATTRIBUTE6,
                                    LINE_ATTRIBUTE7,
                                    LINE_ATTRIBUTE8,
                                    LINE_ATTRIBUTE9,
                                    LINE_ATTRIBUTE10,
                                    LINE_ATTRIBUTE11,
                                    LINE_ATTRIBUTE12,
                                    LINE_ATTRIBUTE13,
                                    LINE_ATTRIBUTE14,
                                    LINE_ATTRIBUTE15,
                                    RECORD_STATUS,
                                    ERROR_MESSAGE,
                                    LAST_UPDATE_DATE,
                                    LAST_UPDATED_BY,
                                    LAST_UPDATED_LOGIN,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    REQUEST_ID,
                                    ORDER_NUMBER,
                                    ORIG_SYS_DOCUMENT_REF,
                                    ORIG_SYS_LINE_REF)
                             VALUES (
                                        XXD_ONT_DROP_SHIP_CONV_STG_S.NEXTVAL,
                                        t_ont_drop_ship_tab (l_indx).ORG_ID,
                                        t_ont_drop_ship_tab (l_indx).CATEGORY_ID,
                                        t_ont_drop_ship_tab (l_indx).AUTHORIZATION_STATUS,
                                        -- t_ont_drop_ship_tab (l_indx).AGENT_NAME                 ,
                                        t_ont_drop_ship_tab (l_indx).REQUISITION_HEADER_ID,
                                        --  t_ont_drop_ship_tab (l_indx).CATEGORY_NAME ,
                                        t_ont_drop_ship_tab (l_indx).REQUISITION_TYPE,
                                        t_ont_drop_ship_tab (l_indx).DELIVER_TO_LOCATION_ID,
                                        t_ont_drop_ship_tab (l_indx).DESTINATION_ORGANIZATION_ID,
                                        t_ont_drop_ship_tab (l_indx).SOURCE_ORGANIZATION_ID,
                                        t_ont_drop_ship_tab (l_indx).DESTINATION_TYPE_CODE,
                                        t_ont_drop_ship_tab (l_indx).ITEM_NUMBER,
                                        t_ont_drop_ship_tab (l_indx).ITEM_DESCRIPTION,
                                        t_ont_drop_ship_tab (l_indx).ITEM_ID,
                                        t_ont_drop_ship_tab (l_indx).LINE_NUM,
                                        t_ont_drop_ship_tab (l_indx).LINE_TYPE,
                                        t_ont_drop_ship_tab (l_indx).LINE_TYPE_ID,
                                        t_ont_drop_ship_tab (l_indx).NEED_BY_DATE,
                                        t_ont_drop_ship_tab (l_indx).DESTINATION_ORGANIZATION_NAME,
                                        t_ont_drop_ship_tab (l_indx).SOURCE_ORGANIZATION_NAME,
                                        t_ont_drop_ship_tab (l_indx).PREPARER,
                                        t_ont_drop_ship_tab (l_indx).PREPARER_ID,
                                        t_ont_drop_ship_tab (l_indx).QUANTITY,
                                        t_ont_drop_ship_tab (l_indx).REQUESTOR,
                                        t_ont_drop_ship_tab (l_indx).REQUISITION_NUMBER,
                                        t_ont_drop_ship_tab (l_indx).SOURCE_TYPE_CODE,
                                        t_ont_drop_ship_tab (l_indx).TO_PERSON_ID,
                                        t_ont_drop_ship_tab (l_indx).UNIT_MEAS_LOOKUP_CODE,
                                        t_ont_drop_ship_tab (l_indx).UNIT_PRICE,
                                        t_ont_drop_ship_tab (l_indx).OPERATING_UNIT,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE_CATEGORY,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE1,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE2,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE3,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE4,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE5,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE6,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE7,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE8,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE9,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE10,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE11,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE12,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE13,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE14,
                                        t_ont_drop_ship_tab (l_indx).HEADER_ATTRIBUTE15,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE_CATEGORY,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE1,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE2,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE3,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE4,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE5,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE6,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE7,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE8,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE9,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE10,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE11,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE12,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE13,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE14,
                                        t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE15,
                                        'N',
                                        NULL,
                                        SYSDATE,
                                        gn_user_id,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        gn_conc_request_id,
                                        t_ont_drop_ship_tab (l_indx).ORDER_NUMBER,
                                        t_ont_drop_ship_tab (l_indx).ORIG_SYS_DOCUMENT_REF,
                                        t_ont_drop_ship_tab (l_indx).ORIG_SYS_LINE_REF);

                COMMIT;
            ELSE
                EXIT;
            END IF;

            --EXIT WHEN lcu_drop_ship_orders%NOTFOUND;
            t_ont_drop_ship_tab.delete;
        END LOOP;

        CLOSE lcu_drop_ship_orders;

        -- END LOOP;
        SELECT COUNT (*)
          INTO ln_req_insert_count
          FROM xxd_drop_ship_so_conv_stg_t;

        fnd_file.put_line (
            fnd_file.LOG,
            'Total number of records inserted  : ' || ln_req_insert_count);
        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Total number of records inserted  : ' || ln_req_insert_count);
        fnd_file.put_line (fnd_file.LOG,
                           'Insertion process completed successfully');
        COMMIT;
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

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  update_requisition_num                                                                                                  --
    -- Description    :  This procedure will be called                           --
    --                   to update requisition info                              --
    --                                                                           --
    -- Parameters     :                                                          --                                                                       --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    -- p_org_name          VARCHAR2        Operating Unit                        --
    -- p_no_of_process     VARCHAR2        Instances                             --
    -- x_errbuf            VARCHAR2        Error return message                  --
    --
    -- ========================================================================= --


    PROCEDURE update_requisition_num (p_org_name IN VARCHAR2, p_no_of_process IN VARCHAR2, x_errbuf OUT VARCHAR2
                                      , x_retcode OUT NUMBER)
    IS
        CURSOR get_rec_cnt_c IS
            SELECT COUNT (DISTINCT requisition_number)
              FROM xxd_drop_ship_so_conv_stg_t
             WHERE batch_id IS NULL AND RECORD_STATUS = gc_new_status;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id               request_table;
        ln_hdr_batch_id        hdr_batch_id_t;
        ln_parent_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        ln_request_id          NUMBER;
        ln_valid_rec_cnt       NUMBER := 0;
        ln_cntr                NUMBER := 0;
    BEGIN
        OPEN get_rec_cnt_c;

        FETCH get_rec_cnt_c INTO ln_valid_rec_cnt;

        IF get_rec_cnt_c%NOTFOUND
        THEN
            ln_valid_rec_cnt   := NULL;
        END IF;

        CLOSE get_rec_cnt_c;


        IF ln_valid_rec_cnt IS NOT NULL AND ln_valid_rec_cnt > 0
        THEN
            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT XXD_ONT_DS_SO_REQ_BATCH_S.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    gc_code_pointer   :=
                        'Batches Sequence :' || ln_hdr_batch_id (i);
                    log_records (gc_debug_flag, gc_code_pointer);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                gc_code_pointer   := 'Batch_sequence sucessfully generated';
                log_records (gc_debug_flag, gc_code_pointer);

                BEGIN
                    UPDATE xxd_drop_ship_so_conv_stg_t x
                       SET batch_id = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id, RECORD_STATUS = 'BU'
                     WHERE     batch_id IS NULL
                           AND x.REQUISITION_NUMBER IN
                                   (SELECT T.REQUISITION_NUMBER
                                      FROM (SELECT DISTINCT
                                                   REQUISITION_NUMBER
                                              FROM xxd_drop_ship_so_conv_stg_t
                                             WHERE RECORD_STATUS = 'N') T
                                     WHERE ROWNUM <=
                                           CEIL (
                                                 ln_valid_rec_cnt
                                               / p_no_of_process))
                           AND RECORD_STATUS = gc_new_status;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_records (
                            gc_debug_flag,
                            'exception Requisitions update ' || SQLERRM);
                END;
            END LOOP;

            COMMIT;

            BEGIN
                UPDATE xxd_drop_ship_so_conv_stg_t
                   SET RECORD_STATUS   = gc_new_status
                 WHERE RECORD_STATUS = 'BU';
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                           'exception Requisition RECORD_STATUS update '
                        || SQLERRM);
            END;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_drop_ship_so_conv_stg_t
                 WHERE     record_status = gc_new_status
                       AND batch_id = ln_hdr_batch_id (l);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        gc_code_pointer   :=
                            'Calling drop_ship_order_child () from update_req_number()';
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                '',
                                '',
                                FALSE,
                                p_org_name,
                                gc_yes_flag,
                                gc_pur_release,
                                ln_hdr_batch_id (l),
                                ln_parent_request_id);
                        log_records (gc_debug_flag,
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
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        ELSE
            gc_code_pointer   :=
                'No records in staging table to update requisition Number    ';
            write_log ('At Stage : ' || gc_code_pointer);
            x_errbuf    := gc_code_pointer;
            x_retcode   := 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            write_log ('At Stage : ' || gc_code_pointer);
            write_log ('Exception : ' || x_errbuf);
    END update_requisition_num;

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  launch_purchase_release_order                                      --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from main_prc                                 --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    PROCEDURE launch_pur_release (p_org_name IN VARCHAR2, x_return_mesg OUT VARCHAR2, x_return_code OUT NUMBER)
    IS
        lv_error_stage    VARCHAR2 (50) := NULL;
        ln_record_count   NUMBER;
    BEGIN
        lv_error_stage   := 'In Purchase Release Procedure';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);

        FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
        LOOP
            lv_error_stage   :=
                'Calling Purchase Release for Org ID' || lc_org.lookup_code;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            OE_PUR_CONC_REQUESTS.REQUEST (
                ERRBUF                 => x_return_mesg,
                RETCODE                => x_return_code,
                p_org_id               => TO_NUMBER (lc_org.lookup_code),
                p_order_number_low     => NULL,
                p_order_number_high    => NULL,
                p_request_date_low     => NULL,
                p_request_date_high    => NULL,
                p_customer_po_number   => NULL,
                p_ship_to_location     => NULL,
                p_order_type           => NULL,
                p_customer             => NULL,
                p_item                 => NULL);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   :=
                   x_return_mesg
                || ' The procedure launch_purchase_release Failed  '
                || SQLERRM;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
            RAISE_APPLICATION_ERROR (-20003, SQLERRM);
    END launch_pur_release;


    FUNCTION GET_NEW_Line_Type_ID (p_line_type IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : NEW_Line_Type                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    NEW_Line_Type_id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_line_type             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_line_type_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_line_type_id   NUMBER;
    BEGIN
        SELECT line_type_id
          INTO x_line_type_id
          FROM po_line_types
         WHERE line_type = p_line_type;

        RETURN x_line_type_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*   xxd_common_utils.record_error
                                      ('ONT',
                                       gn_org_id,
                                       'Decker Drop Ship Orders Conversion Program',
                                 --      SQLCODE,
                                       SQLERRM,
                                       DBMS_UTILITY.format_error_backtrace,
                                    --   DBMS_UTILITY.format_call_stack,
                                   --    SYSDATE,
                                      gn_user_id,
                                       gn_conc_request_id,
                                        'GET_new_line_type_ID'
                                       ,p_line_type
                                       ,'Exception to GET_new_line_type_ID Procedure'|| SQLERRM );   */
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN -1;
    END GET_NEW_Line_Type_ID;

    FUNCTION get_req_line_id (P_ORIG_SYS_LINE_REF IN VARCHAR2, P_ITEM_NAME IN VARCHAR2, p_org_id IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : get_req_line_id                                           |
    -- | Description      : This procedure  is used to get                 |
    -- |                    get_req_line_id                                |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_req_line_id   NUMBER;
    BEGIN
        x_req_line_id   := NULL;

        SELECT odss.REQUISITION_LINE_ID                -- commented in ver 1.1
          INTO x_req_line_id
          FROM oe_drop_Ship_sources odss, oe_order_lines_all ool
         WHERE     odss.LINE_ID = ool.line_id
               AND ool.ORIG_SYS_LINE_REF = P_ORIG_SYS_LINE_REF
               AND ool.ORDERED_ITEM = P_ITEM_NAME
               AND ool.org_id = p_org_id;

        IF x_req_line_id IS NULL
        THEN
            RETURN -1;
        ELSE
            RETURN x_req_line_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_REQ_LINE_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_REQ_LINE_ID',
                P_ORIG_SYS_LINE_REF);
            write_log ('Exception to GET_REQ_LINE_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_req_line_id;



    PROCEDURE update_req_number (p_org_name IN VARCHAR2, p_batch_id IN NUMBER, x_errbuf OUT VARCHAR2
                                 , x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (50) := 'UPDATE REQ NUMBER';
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_req_num IS
            SELECT pria.INTERFACE_SOURCE_LINE_ID,
                   dss.*,
                   (SELECT line_type_id
                      FROM po_line_types
                     WHERE line_type = dss.line_type) NEW_Line_Type_ID
              FROM xxd_drop_ship_so_conv_stg_t dss, oe_drop_Ship_sources odss, PO_REQUISITIONS_INTERFACE_ALL pria,
                   oe_order_lines_all ool, oe_order_headers_all ooh
             WHERE     pria.INTERFACE_SOURCE_LINE_ID =
                       odss.DROP_SHIP_SOURCE_ID
                   AND odss.LINE_ID = ool.line_id
                   AND odss.header_id = ooh.header_id
                   AND ool.header_id = ooh.header_id
                   AND ooh.ORIG_SYS_DOCUMENT_REF = dss.ORIG_SYS_DOCUMENT_REF
                   AND dss.ORIG_SYS_LINE_REF = ool.ORIG_SYS_LINE_REF
                   AND ool.ORDERED_ITEM = dss.ITEM_NUMBER
                   -- AND dss.org_id = ln_org_id
                   AND dss.batch_id = p_batch_id;


        --   AND record_status = gc_validate_status;
        TYPE XXD_ONT_REQ_NUM_TAB IS TABLE OF lcu_req_num%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_req_num_tab         XXD_ONT_REQ_NUM_TAB;
    BEGIN
        lv_error_stage   := 'In Update requisition Number procedure';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        t_ont_req_num_tab.delete;

        /* FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
         LOOP*/
        OPEN lcu_req_num;

        LOOP
            lv_error_stage   :=
                'Updating requistion number in requistion Interface table';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            --lv_error_stage := 'Org Id' || lc_org.lookup_code;
            --fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            t_ont_req_num_tab.delete;

            FETCH lcu_req_num BULK COLLECT INTO t_ont_req_num_tab LIMIT 5000;

            lv_error_stage   := 'Inside for loop';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            fnd_file.put_line (
                fnd_file.LOG,
                'Total Count of rec :' || t_ont_req_num_tab.COUNT);

            FORALL l_indx IN 1 .. t_ont_req_num_tab.COUNT
                UPDATE PO_REQUISITIONS_INTERFACE_ALL
                   SET REQUISITION_TYPE = t_ont_req_num_tab (l_indx).REQUISITION_TYPE, REQ_NUMBER_SEGMENT1 = t_ont_req_num_tab (l_indx).REQUISiTION_NUMBER, LINE_NUM = t_ont_req_num_tab (l_indx).line_num, -- version 1.2
                       HEADER_ATTRIBUTE_CATEGORY = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE_CATEGORY, HEADER_ATTRIBUTE1 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE1, HEADER_ATTRIBUTE2 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE2,
                       HEADER_ATTRIBUTE3 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE3, HEADER_ATTRIBUTE4 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE4, HEADER_ATTRIBUTE5 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE5,
                       HEADER_ATTRIBUTE6 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE6, HEADER_ATTRIBUTE7 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE7, HEADER_ATTRIBUTE8 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE8,
                       HEADER_ATTRIBUTE9 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE9, HEADER_ATTRIBUTE10 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE10, HEADER_ATTRIBUTE11 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE11,
                       HEADER_ATTRIBUTE12 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE12, HEADER_ATTRIBUTE13 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE13, HEADER_ATTRIBUTE14 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE14,
                       HEADER_ATTRIBUTE15 = t_ont_req_num_tab (l_indx).HEADER_ATTRIBUTE15, LINE_ATTRIBUTE_CATEGORY = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE_CATEGORY, LINE_ATTRIBUTE1 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE1,
                       LINE_ATTRIBUTE2 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE2, LINE_ATTRIBUTE3 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE3, LINE_ATTRIBUTE4 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE4,
                       LINE_ATTRIBUTE5 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE5, LINE_ATTRIBUTE6 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE6, LINE_ATTRIBUTE7 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE7,
                       LINE_ATTRIBUTE8 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE8, LINE_ATTRIBUTE9 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE9, LINE_ATTRIBUTE10 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE10,
                       LINE_ATTRIBUTE11 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE11, LINE_ATTRIBUTE12 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE12, LINE_ATTRIBUTE13 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE13,
                       LINE_ATTRIBUTE14 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE14, LINE_ATTRIBUTE15 = t_ont_req_num_tab (l_indx).LINE_ATTRIBUTE15, line_type_id = t_ont_req_num_tab (l_indx).NEW_Line_Type_ID,
                       --source_type_code,
                       unit_of_measure = t_ont_req_num_tab (l_indx).UNIT_MEAS_LOOKUP_CODE, unit_price = t_ont_req_num_tab (l_indx).unit_price, quantity = t_ont_req_num_tab (l_indx).QUANTITY,
                       batch_id = p_batch_id
                 WHERE INTERFACE_SOURCE_LINE_ID =
                       t_ont_req_num_tab (l_indx).INTERFACE_SOURCE_LINE_ID;

            COMMIT;
            EXIT WHEN lcu_req_num%NOTFOUND;
        END LOOP;

        CLOSE lcu_req_num;

        --     END LOOP;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Updating record in the requisition Interface table '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END update_req_number;

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  validate_record_prc                                     --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from main                                   --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    PROCEDURE validate_record_prc (x_return_mesg   OUT VARCHAR2,
                                   x_return_code   OUT VARCHAR2)
    IS
        ------------------------------
        -- get the data for Validation
        ------------------------------
        CURSOR cur_validate_details IS
            SELECT ROWID, a.*
              FROM xxd_drop_ship_so_conv_stg_t a
             WHERE record_status = GC_NEW;

        ---
        -- Declarion of variables
        ----
        lc_error_mesg        VARCHAR2 (4000);
        lc_err_sts           VARCHAR2 (2);
        error_exception      EXCEPTION;
        log_msg              VARCHAR2 (4000);
        l_order_imp_ststus   VARCHAR2 (2);
    BEGIN
        x_return_code   := 0;
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'Start of Procedure validate_record_prc ');
        log_records (
            p_debug     => gc_debug_flag,
            p_message   => ' gn_conc_request_id  ' || gn_conc_request_id);

        -- open validation cursor
        FOR val_rec IN cur_validate_details
        LOOP
            -- lc_err_sts := GC_API_SUCCESS;
            -- lc_error_mesg := 'Order Line has not been imported';
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Inside for loop order number'
                    || val_rec.order_number
                    || ' gn_conc_request_id  '
                    || gn_conc_request_id);

            -----------------------------------------------------------------------
            -- Check if the Sales Order has been imported for the particular drop ship
            -----------------------------------------------------------------------
            BEGIN
                SELECT '1'
                  INTO l_order_imp_ststus
                  FROM oe_order_lines_all ool
                 WHERE ool.ORIG_SYS_LINE_REF = val_rec.ORIG_SYS_LINE_REF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_return_mesg        :=
                           'Error while Fetching the order in 12.2.3 for the order number '
                        || val_rec.order_number
                        || ' AND line id '
                        || val_rec.ORIG_SYS_LINE_REF
                        || ' - '
                        || SQLERRM;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, x_return_mesg);
                    l_order_imp_ststus   := '0';
            -- RAISE error_exception;
            END;

            --FND_FILE.PUT_LINE(fnd_file.log,'After validation Status of Order number  ' || lc_err_sts);
            ---------------------------------------
            -- Update the status in staging table
            ---------------------------------------
            IF l_order_imp_ststus <> '1'
            THEN
                UPDATE xxd_drop_ship_so_conv_stg_t
                   SET record_status = gc_error_status, error_message = lc_error_mesg
                 WHERE record_status = GC_NEW AND ROWID = val_rec.ROWID;
            ELSE
                UPDATE xxd_drop_ship_so_conv_stg_t
                   SET record_status   = gc_validate_status
                 WHERE record_status = GC_NEW AND ROWID = val_rec.ROWID;
            END IF;
        END LOOP;                           -- val_rec IN cur_validate_details

        COMMIT;
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'End of Procedure validate_record_prc ');
    EXCEPTION
        WHEN error_exception
        THEN
            x_return_mesg   := x_return_mesg;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
        --ROLLBACK;
        WHEN OTHERS
        THEN
            x_return_mesg   :=
                'The procedure lauch_pick_release Failed  ' || SQLERRM;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
    END validate_record_prc;

    FUNCTION get_targetorg_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : get_targetorg_id                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (NAME) = UPPER (p_org_name);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Decker Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_targetorg_id;

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      : apply_sales_order_hold                                   --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   to apply hold on sales order to sink with 12.0.6        --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    PROCEDURE apply_sales_order_hold (p_org_name IN VARCHAR2, p_batch_id IN NUMBER, x_return_mesg OUT VARCHAR2
                                      , x_return_code OUT NUMBER)
    IS
        CURSOR get_resp_dt IS
            SELECT level_value_application_id, fr.responsibility_id
              FROM FND_PROFILE_OPTION_VALUES FPOV, FND_RESPONSIBILITY_TL FR, FND_PROFILE_OPTIONS FPO,
                   HR_OPERATING_UNITS HOU
             WHERE     fpo.profile_option_id = fpov.profile_option_id --AND LEVEL_ID =
                   AND level_value = fr.responsibility_id
                   AND level_id = 10003
                   AND language = 'US'
                   AND profile_option_name = 'DEFAULT_ORG_ID'
                   AND responsibility_name LIKE 'Deck%Order%Super%'
                   AND profile_option_value = hou.organization_id
                   AND hou.name LIKE p_org_name
                   AND ROWNUM < 2;


        CURSOR get_so_hold_dt_cur IS
            SELECT DISTINCT xod.order_number, oha.header_id, oha.org_id,
                            xohold.hold_name, xohold.hold_id, xohold.hold_comment,
                            xohold.hold_entity_code
              FROM XXD_CONV.XXD_ONT_DIST_HDRS_CONV_STG_T XOD, XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T DSO, XXD_CONV.XXD_1206_ORDER_HOLDS_T XOHOLD,
                   OE_ORDER_HOLDS_ALL OHA, OE_HOLD_SOURCES_ALL OHSA, OE_HOLD_DEFINITIONS OHD,
                   OE_ORDER_HEADERS_ALL OOH
             WHERE     1 = 1
                   AND xod.record_status = 'P'
                   AND dso.ordeR_number = xod.order_number
                   AND dso.record_status = 'I'
                   AND xod.original_system_reference =
                       xohold.orig_sys_document_ref
                   AND oha.hold_source_id = ohsa.hold_source_id
                   AND ohsa.hold_id = ohd.hold_id
                   AND ooh.order_number = xod.order_number
                   AND ooh.header_id = oha.header_id
                   AND ohd.name = xohold.hold_name
                   AND dso.batch_id = p_batch_id;



        lc_return_status      VARCHAR2 (30);
        lc_msg_data           VARCHAR2 (4000);
        ln_msg_count          NUMBER;
        lr_hold_source_rec    OE_HOLDS_PVT.HOLD_SOURCE_REC_TYPE;
        ln_hold_id            NUMBER;
        lc_hold_entity_code   VARCHAR2 (10) DEFAULT 'O';
        ln_header_id          NUMBER;
        lc_error_msg          VARCHAR2 (1000);
        ln_application_id     NUMBER;
        ln_resp_id            NUMBER;
        ln_err_cnt            NUMBER;
    BEGIN
        ln_err_cnt   := 0;

        OPEN get_resp_dt;

        FETCH get_resp_dt INTO ln_application_id, ln_resp_id;

        IF get_resp_dt%NOTFOUND
        THEN
            ln_application_id   := NULL;
            ln_resp_id          := NULL;
        END IF;

        CLOSE get_resp_dt;

        FND_GLOBAL.APPS_INITIALIZE (gn_user_id,
                                    ln_application_id,
                                    ln_resp_id);
        MO_GLOBAL.INIT ('ONT');

        FOR rec_get_so_hold_dt IN get_so_hold_dt_cur
        LOOP
            -- check for hold at headers level only
            IF rec_get_so_hold_dt.hold_entity_code = 'O'
            THEN
                lr_hold_source_rec                    := OE_HOLDS_PVT.G_MISS_HOLD_SOURCE_REC;
                lr_hold_source_rec.hold_id            := rec_get_so_hold_dt.hold_id;
                lr_hold_source_rec.hold_entity_code   :=
                    rec_get_so_hold_dt.hold_entity_code;
                lr_hold_source_rec.hold_entity_id     :=
                    rec_get_so_hold_dt.header_id;
                lr_hold_source_rec.header_id          :=
                    rec_get_so_hold_dt.header_id;
                lc_return_status                      := NULL;
                lc_msg_data                           := NULL;
                ln_msg_count                          := NULL;
                gc_code_pointer                       :=
                       'Calling the API to Apply hold for order : '
                    || rec_get_so_hold_dt.order_number;
                write_log (gc_code_pointer);
                OE_HOLDS_PUB.APPLY_HOLDS (p_api_version => 1.0, p_init_msg_list => FND_API.G_TRUE, p_commit => FND_API.G_FALSE, p_hold_source_rec => lr_hold_source_rec, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                          , x_msg_data => lc_msg_data);

                IF lc_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    COMMIT;
                ELSIF lc_return_status IS NULL
                THEN
                    gc_code_pointer   :=
                        'Error occured at apply_holds() :' || lc_msg_data;
                    write_log (gc_code_pointer);

                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_msg_data    :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        lc_error_msg   := lc_error_msg || ' ' || lc_msg_data;
                        ln_err_cnt     := ln_err_cnt + 1;
                    END LOOP;

                    write_log (lc_error_msg);
                    ROLLBACK;
                ELSE
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_msg_data    :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        lc_error_msg   := lc_error_msg || ' ' || lc_msg_data;
                        ln_err_cnt     := ln_err_cnt + 1;
                    END LOOP;

                    write_log (lc_error_msg);
                    ROLLBACK;
                END IF;
            END IF;
        END LOOP;

        IF ln_err_cnt >= 1
        THEN
            x_return_code   := gn_warning;
        ELSE
            x_return_code   := gn_success;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   := 'Error : ' || SQLCODE || '---' || SQLERRM;
            x_return_code   := gn_error;
            write_log (x_return_mesg);
    END apply_sales_order_hold;

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      : req_import_prc                                       --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from main                                   --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    PROCEDURE req_import_prc (p_org_name IN VARCHAR2, p_batch_id IN NUMBER, x_return_mesg OUT VARCHAR2
                              , x_return_code OUT NUMBER)
    IS
        CURSOR cur_Batch_id IS
            SELECT DISTINCT org_id
              FROM PO_REQUISITIONS_INTERFACE_ALL
             WHERE batch_id = p_batch_id;

        x_request_id          NUMBER;
        x_application_id      NUMBER;
        x_responsibility_id   NUMBER;
        ln_count              NUMBER := 1;
        ln_exit_flag          NUMBER := 0;
        lb_flag               BOOLEAN := FALSE;
        lc_rollback           EXCEPTION;
        lc_launch_rollback    EXCEPTION;
        lc_released_Status    VARCHAR2 (200);
        ln_del_id             NUMBER;
        ln_org_id             NUMBER;
        log_msg               VARCHAR2 (4000);
        lc_phase              VARCHAR2 (2000);
        lc_wait_status        VARCHAR2 (2000);
        lc_dev_phase          VARCHAR2 (2000);
        lc_dev_status         VARCHAR2 (2000);
        lc_message            VARCHAR2 (2000);
        ln_req_id             NUMBER;
        lb_request_status     BOOLEAN;
    BEGIN
        -- x_return_sts := GC_API_SUCCESS;
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'Start of Procedure req_import_prc ');

        --    debug(GC_SOURCE_PROGRAM);
        FOR batch_id IN cur_Batch_id
        LOOP
            --ln_org_id := get_targetorg_id (p_org_name => p_org_name); --fnd_profile.VALUE ('ORG_ID');
            set_org_context (p_target_org_id   => TO_NUMBER (batch_id.org_id),
                             p_resp_id         => x_responsibility_id,
                             p_resp_appl_id    => x_application_id);
            -- mo_global.init ('PO');
            fnd_request.set_org_id (TO_NUMBER (batch_id.org_id));
            log_records (p_debug     => gc_debug_flag,
                         p_message   => 'ln_org_id' || batch_id.org_id);
            --    debug(GC_SOURCE_PROGRAM);
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Submitting requisition Import Program for batch Id  '
                || batch_id.org_id);
            -------
            ln_req_id   :=
                fnd_request.submit_request (application   => 'PO',
                                            program       => 'REQIMPORT',
                                            description   => NULL,
                                            start_time    => SYSDATE,
                                            sub_request   => FALSE,
                                            argument1     => 'ORDER ENTRY',
                                            argument2     => p_batch_id,
                                            argument3     => 'VENDOR',
                                            argument4     => NULL,
                                            argument5     => 'N',
                                            argument6     => 'Y');
            COMMIT;

            IF ln_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to ?'
                    || fnd_message.get
                    || '?.');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'The Requisition Import Program submitted ? Request id :'
                    || ln_req_id);
            END IF;

            IF ln_req_id > 0
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    '   Waiting for the Requisition Import Program');

                LOOP
                    lb_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 60,
                            max_wait     => 0,
                            phase        => lc_phase,
                            status       => lc_wait_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);
                    EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                              OR UPPER (lc_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  Requisition Import Program Request Phase'
                    || '-'
                    || lc_dev_phase);
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  Requisition Import Program Request Dev status'
                    || '-'
                    || lc_dev_status);

                IF     UPPER (lc_phase) = 'COMPLETED'
                   AND UPPER (lc_wait_status) = 'ERROR'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'The Requisition Import prog completed in error. See log for request id');
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);
                    RETURN;
                ELSIF     UPPER (lc_phase) = 'COMPLETED'
                      AND UPPER (lc_wait_status) = 'NORMAL'
                THEN
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                           'The Requisition Import successfully completed for request id: '
                        || ln_req_id);
                ELSE
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                        'The Requisition Import request failed.Review log for Oracle request id ');
                    Fnd_File.PUT_LINE (Fnd_File.LOG, SQLERRM);
                    RETURN;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   :=
                'The procedure reqisition_import Failed  ' || SQLERRM;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
            RAISE_APPLICATION_ERROR (-20003, SQLERRM);
    END req_import_prc;

    FUNCTION GET_ITEM_ID (p_item IN VARCHAR2, p_org_id IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ITEM_ID                                               |
    -- | Description      : This procedure  is used to get                 |
    -- |                    item id                                        |
    -- |                                                                   |
    -- | Parameters : p_item, p_inv_org_id                                 |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_item_id                                              |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_item_id   NUMBER;
        x_status    VARCHAR2 (10);
    BEGIN
        x_status   := 'Y';

        --  fnd_file.put_line (fnd_file.LOG, 'p_item  ' || p_item );
        --   fnd_file.put_line (fnd_file.LOG, 'p_org_id  ' || p_org_id );
        /*  SELECT inventory_item_id
            INTO x_item_id
            FROM mtl_system_items_b
           WHERE     UPPER (segment1) = UPPER (p_item)
                 AND organization_id = p_org_id;*/
        SELECT DISTINCT inventory_item_id
          INTO x_item_id
          FROM mtl_system_items_kfv msb, mtl_parameters mp
         WHERE     mp.MASTER_ORGANIZATION_ID = mp.ORGANIZATION_ID
               AND mp.ORGANIZATION_ID = msb.ORGANIZATION_ID
               AND msb.CONCATENATED_SEGMENTS = UPPER (p_item);

        --   AND mp.organization_id = p_org_id;
        --AND outside_operation_flag = 'Y';
        RETURN x_item_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_item_id   := NULL;
            x_status    := 'N';
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Item Does not exist',
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                p_item,
                'Item Does not exist');
            write_log ('Exception to GET_ITEM_ID Procedure' || SQLERRM);
            RETURN -1;
    END GET_ITEM_ID;

    FUNCTION get_org_id (p_1206_org_id IN NUMBER)
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
        --         px_meaning := p_org_name;
        px_lookup_code   := p_1206_org_id;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (NAME) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Deckers Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_org_id;

    FUNCTION get_agent_id (P_agent_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name             : get_agent_id                                   |
    -- | Description      : This procedure  is used to get                 |
    -- |                    buyer ID                                       |
    -- |                                                                   |
    -- | Parameters       : p_agent_name                                   |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns          : x_loc_id                                       |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_agent_id   NUMBER;
    BEGIN
        x_agent_id   := NULL;

        SELECT agent_id
          INTO x_agent_id
          FROM po_agents_v
         WHERE agent_name = P_agent_name;

        IF x_agent_id IS NULL
        THEN
            RETURN -1;
        ELSE
            RETURN x_agent_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_AGENT_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'AGENT NAME',
                P_agent_name);
            RETURN -1;
    END get_agent_id;

    FUNCTION get_person_id (P_emp_name IN VARCHAR2)        -- Added in ver 1.1
        RETURN NUMBER
    -- +===================================================================+
    -- | Name             : get_agent_id                                   |
    -- | Description      : This procedure  is used to get employee        |
    -- |                    person ID                                      |
    -- |                                                                   |
    -- | Parameters       : p_agent_name                                   |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns          : x_loc_id                                       |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_person_id   NUMBER;
    BEGIN
        x_person_id   := NULL;

        SELECT PERSON_ID
          INTO x_person_id
          FROM per_all_people_f papf
         WHERE     full_name = P_emp_name
               AND SYSDATE BETWEEN effective_start_date
                               AND effective_end_date
               AND current_employee_flag = 'Y';

        IF x_person_id IS NULL
        THEN
            RETURN -1;
        ELSE
            RETURN x_person_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_PERSON_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'DELIVER TO PERSON NAME',
                P_emp_name);
            write_log ('Exception to GET_PERSON_ID Procedure' || SQLERRM);
            RETURN -2;
    END get_person_id;

    ----------------------------------------------ship_to_location_code--------------------
    FUNCTION get_ship_to_location (p_1206_org_id NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        CURSOR get_ship_to_location (p_name VARCHAR2)
        IS
            SELECT DISTINCT hou.location_id
              FROM hr_organization_units hou, org_organization_definitions ood
             WHERE     ood.organization_code = p_name
                   AND hou.organization_id = ood.organization_id;

        px_lookup_code          VARCHAR2 (250);
        px_meaning              VARCHAR2 (250); -- internal name of old entity
        px_description          VARCHAR2 (250);      -- name of the old entity
        x_attribute1            VARCHAR2 (250); -- corresponding new 12.2.3 value
        x_attribute2            VARCHAR2 (250);
        x_error_code            VARCHAR2 (250);
        x_error_msg             VARCHAR (250);
        x_org_id                NUMBER;
        x_ship_to_location_id   NUMBER;
    BEGIN
        px_lookup_code          := p_1206_org_id;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);
        x_ship_to_location_id   := NULL;

        OPEN get_ship_to_location (x_attribute1);

        FETCH get_ship_to_location INTO x_ship_to_location_id;

        IF get_ship_to_location%NOTFOUND
        THEN
            x_ship_to_location_id   := -1;
        END IF;

        CLOSE get_ship_to_location;

        RETURN x_ship_to_location_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to  get_ship_to_location Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'SHIP_TO_LOC_ORG',
                p_1206_org_id);
            write_log (
                'Exception to get_ship_to_location Procedure' || SQLERRM);
            RETURN -1;
    END get_ship_to_location;

    ------------------------------   GET BILL TO LOCATION----------------------
    FUNCTION get_bill_to_location (p_vendor_site_id IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_bill_to_location_id   NUMBER;

        CURSOR get_bill_to_location IS
            SELECT bill_to_location_id
              FROM ap_supplier_sites_all
             WHERE vendor_site_id = p_vendor_site_id;
    BEGIN
        x_bill_to_location_id   := NULL;

        OPEN get_bill_to_location;

        FETCH get_bill_to_location INTO x_bill_to_location_id;

        IF get_bill_to_location%NOTFOUND
        THEN
            x_bill_to_location_id   := -1;
        END IF;

        CLOSE get_bill_to_location;

        RETURN x_bill_to_location_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to  get_bill_to_location Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'BILL_TO_LOC_VSITE',
                p_vendor_site_id);
            write_log (
                'Exception to get_bill_to_location Procedure' || SQLERRM);
            RETURN -1;
    END get_bill_to_location;

    ----------------------------------------------------------------------
    FUNCTION get_vendor_id (P_vendor_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_vendor_id   NUMBER;
    BEGIN
        SELECT asu.vendor_id
          INTO x_vendor_id
          FROM ap_suppliers asu
         WHERE     UPPER (asu.vendor_name) = UPPER (P_vendor_name)
               AND TRUNC (SYSDATE) BETWEEN NVL (
                                               TRUNC (asu.start_date_active),
                                               TRUNC (SYSDATE - 1))
                                       AND NVL (TRUNC (asu.end_date_active),
                                                TRUNC (SYSDATE + 1));

        RETURN x_vendor_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_VENDOR_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'AGENT NAME',
                P_vendor_name);
            write_log ('Exception to GET_VENDOR_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_vendor_id;

    FUNCTION get_vendor_site_id (P_vendor_name IN VARCHAR2, p_site IN VARCHAR2, p_org IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_vendor_site_id   NUMBER;
    BEGIN
        SELECT aps.vendor_site_id
          INTO x_vendor_site_id
          FROM ap_supplier_sites_all aps, ap_suppliers asu
         WHERE     asu.vendor_id = aps.vendor_id
               AND UPPER (aps.vendor_site_code) = UPPER (p_site)
               AND UPPER (asu.vendor_name) = UPPER (P_vendor_name)
               AND org_id = p_org;

        RETURN x_vendor_site_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_VENDOR_SITE_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'VENDOR NAME',
                P_vendor_name);
            write_log (
                'Exception to GET_VENDOR_SITE_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_vendor_site_id;

    FUNCTION get_new_ou_name (p_1206_org_id IN NUMBER)
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
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        --         px_meaning := p_org_name;
        px_lookup_code   := p_1206_org_id;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);
        --SELECT organization_id
        -- INTO x_org_id
        --FROM hr_operating_units
        --WHERE UPPER (NAME) = UPPER (x_attribute1);
        RETURN x_attribute1;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Deckers Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_new_ou_name;

    FUNCTION get_inv_org_id (p_1206_org_id IN NUMBER)
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
        --         px_meaning := p_org_name;
        px_lookup_code   := p_1206_org_id;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM org_organization_definitions
         WHERE UPPER (ORGANIZATION_CODE) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Deckers Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_inv_org_id;

    PROCEDURE extract_1206_po_data (p_org_name       IN     VARCHAR2,
                                    x_total_rec         OUT NUMBER,
                                    x_validrec_cnt      OUT NUMBER,
                                    x_errbuf            OUT VARCHAR2,
                                    x_retcode           OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_drop_ship_orders IS
            SELECT *
              FROM XXD_CONV.XXD_1206_OE_DROP_SHIP_PO xods
             WHERE                 --xods.Order_org_id = TO_NUMBER (ln_org_id)
                       EXISTS
                           (SELECT /*+ leading(ool) parallel(oedss,4) no_merge*/
                                   1
                              FROM apps.oe_order_lines_all ool, oe_drop_ship_sources oedss
                             WHERE     ool.ORIG_SYS_document_REF =
                                       xods.ORIG_SYS_document_REF
                                   AND ool.ORIG_SYS_line_REF =
                                       xods.ORIG_SYS_line_REF
                                   AND oedss.line_id = ool.line_id
                                   AND oedss.po_line_id IS NULL
                                   AND ool.FLOW_STATUS_CODE =
                                       'AWAITING_RECEIPT')
                   AND (   EXISTS
                               (SELECT 1
                                  FROM XXD_1206_DIST_DS_PO_MACAU_V MV
                                 WHERE xods.PO_NUMBER = MV.PO_NUMBER)
                        OR EXISTS
                               (SELECT 1
                                  FROM XXD_1206_DIST_DS_PO_TQ_V TQ
                                 WHERE xods.PO_NUMBER = TQ.PO_NUMBER))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM PO_HEADERS_ALL
                             WHERE PO_NUMBER = SEGMENT1-- and org_id = XODS.ORDER_ORG_ID
                                                       );

        /*       AND ORDER_NUMBER IN (50499023,
   50499037,
   52521331,
   50511501,
   50511575,
   50511454,
   50511398);*/

        TYPE XXD_ONT_DROP_SHIP_TAB
            IS TABLE OF XXD_CONV.XXD_1206_OE_DROP_SHIP_PO%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_drop_ship_tab       XXD_ONT_DROP_SHIP_TAB;
    BEGIN
        lv_error_stage   := 'In Extract procedure of purchase order';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        t_ont_drop_ship_tab.delete;
        /* FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
         LOOP
            lv_error_stage :=    'Processing Drop ship PO for  ORG :'
                              || lc_org.lookup_code;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);*/
        fnd_file.put_line (
            fnd_file.LOG,
            'Inserting source data into stage XXD_DROP_SHIP_PO_CONV_STG_T');

        OPEN lcu_drop_ship_orders;

        LOOP
            /* lv_error_stage := 'Inserting Drop ship Purchase Order Data into Staging';
             fnd_file.put_line (fnd_file.LOG, lv_error_stage);
             lv_error_stage := 'Org Id' || lc_org.lookup_code;
             fnd_file.put_line (fnd_file.LOG, lv_error_stage); */
            -- commnented in ver 1.1
            t_ont_drop_ship_tab.delete;

            FETCH lcu_drop_ship_orders
                BULK COLLECT INTO t_ont_drop_ship_tab
                LIMIT 5000;

            FORALL l_indx IN 1 .. t_ont_drop_ship_tab.COUNT
                INSERT INTO XXD_DROP_SHIP_PO_CONV_STG_T (
                                RECORD_ID,
                                PO_ORG_ID,
                                OU_NAME,
                                PO_NUMBER,
                                PO_CREATION_DATE,
                                DOCUMENT_TYPE_CODE,
                                DOCUMENT_SUBTYPE,
                                PO_HEADER_ID,
                                CURRENCY_CODE,
                                AGENT_NAME,
                                -- AGENT_ID                   ,
                                VENDOR_NAME,
                                VENDOR_NUMBER,
                                VENDOR_ID,
                                VENDOR_SITE_CODE,
                                VENDOR_SITE_ID,
                                VENDOR_CONTACT,
                                VENDOR_CONTACT_ID,
                                PO_SHIP_TO_LOCATION,
                                PO_SHIP_TO_LOCATION_ID,
                                PO_BILL_TO_LOCATION,
                                PO_BILL_TO_LOCATION_ID,
                                PAYMENT_TERMS,
                                --TERMS_ID                   ,
                                FREIGHT_CARRIER,
                                FOB,
                                FREIGHT_TERMS,
                                APPROVAL_STATUS,
                                APPROVED_DATE,
                                REVISED_DATE,
                                REVISION_NUM,
                                PO_NOTE_TO_VENDOR,
                                NOTE_TO_RECEIVER,
                                CONFIRMING_ORDER_FLAG,
                                COMMENTS,
                                ACCEPTANCE_REQUIRED_FLAG,
                                ACCEPTANCE_DUE_DATE,
                                PRINT_COUNT,
                                PRINTED_DATE,
                                FIRM_FLAG,
                                FROZEN_FLAG,
                                PO_CLOSED_CODE,
                                PO_CLOSED_DATE,
                                -- REPLY_                   ,
                                REPLY_METHOD,
                                RFQ_CLOSE_DATE,
                                QUOTE_WARNING_DELAY,
                                VENDOR_DOC_NUM,
                                APPROVAL_REQUIRED_FLAG,
                                edi_processed_flag,
                                edi_processed_status,
                                ATTRIBUTE_CATEGORY,
                                ATTRIBUTE1,
                                ATTRIBUTE2,
                                ATTRIBUTE3,
                                ATTRIBUTE4,
                                ATTRIBUTE5,
                                ATTRIBUTE6,
                                ATTRIBUTE7,
                                ATTRIBUTE8,
                                ATTRIBUTE9,
                                ATTRIBUTE10,
                                ATTRIBUTE11,
                                ATTRIBUTE12,
                                ATTRIBUTE13,
                                ATTRIBUTE14,
                                ATTRIBUTE15,
                                STYLE_ID,
                                STYLE_DISPLAY_NAME,
                                REFERENCE_NUM,
                                --line information
                                LINE_NUM,
                                PO_LINE_ID,
                                LINE_TYPE,
                                LINE_TYPE_ID,
                                ITEM,
                                ITEM_ID,
                                ITEM_REVISION,
                                CATEGORY_ID,
                                CATEGORY,
                                CATEGORY_SEGMENT1,
                                ITEM_DESCRIPTION,
                                UNIT_OF_MEASURE,
                                QUANTITY,
                                COMMITTED_AMOUNT,
                                MIN_ORDER_QUANTITY,
                                MAX_ORDER_QUANTITY,
                                UNIT_PRICE,
                                LIST_PRICE_PER_UNIT,
                                ALLOW_PRICE_OVERRIDE_FLAG,
                                NOT_TO_EXCEED_PRICE,
                                NEGOTIATED_BY_PREPARER_FLAG,
                                PL_NOTE_TO_VENDOR,
                                TRANSACTION_REASON_CODE,
                                TYPE_1099,
                                CAPITAL_EXPENSE_FLAG,
                                MIN_RELEASE_AMOUNT,
                                PRICE_BREAK_LOOKUP_CODE,
                                USSGL_TRANSACTION_CODE,
                                PL_CLOSED_CODE,
                                PL_CLOSED_REASON,
                                PL_CLOSED_DATE,
                                PL_CLOSED_BY,
                                PL_SHIP_TO_ORGANIZATION_CODE,
                                PL_SHIP_TO_ORGANIZATION_ID,
                                PL_SHIP_TO_LOCATION,
                                PL_SHIP_TO_LOCATION_ID,
                                NEED_BY_DATE,
                                PROMISED_DATE,
                                LINE_LOCATION_ID,
                                LINE_ATTRIBUTE_CATEGORY_LINES,
                                LINE_ATTRIBUTE1,
                                LINE_ATTRIBUTE2,
                                LINE_ATTRIBUTE3,
                                LINE_ATTRIBUTE4,
                                LINE_ATTRIBUTE5,
                                LINE_ATTRIBUTE6,
                                LINE_ATTRIBUTE7,
                                LINE_ATTRIBUTE8,
                                LINE_ATTRIBUTE9,
                                LINE_ATTRIBUTE10,
                                LINE_ATTRIBUTE11,
                                LINE_ATTRIBUTE12,
                                LINE_ATTRIBUTE13,
                                LINE_ATTRIBUTE14,
                                LINE_ATTRIBUTE15,
                                SHIPMENT_ATTRIBUTE_CATEGORY,
                                SHIPMENT_ATTRIBUTE1,
                                SHIPMENT_ATTRIBUTE2,
                                SHIPMENT_ATTRIBUTE3,
                                SHIPMENT_ATTRIBUTE4,
                                SHIPMENT_ATTRIBUTE5,
                                SHIPMENT_ATTRIBUTE6,
                                SHIPMENT_ATTRIBUTE7,
                                SHIPMENT_ATTRIBUTE8,
                                SHIPMENT_ATTRIBUTE9,
                                SHIPMENT_ATTRIBUTE10,
                                SHIPMENT_ATTRIBUTE11,
                                SHIPMENT_ATTRIBUTE12,
                                SHIPMENT_ATTRIBUTE13,
                                SHIPMENT_ATTRIBUTE14,
                                SHIPMENT_ATTRIBUTE15,
                                AUCTION_HEADER_ID,
                                AUCTION_LINE_NUMBER,
                                AUCTION_DISPLAY_NUMBER,
                                BID_NUMBER,
                                BID_LINE_NUMBER,
                                AMOUNT,
                                JOB_ID,
                                DROP_SHIP_FLAG,
                                RECORD_STATUS,
                                ERROR_MESSAGE,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY,
                                LAST_UPDATED_LOGIN,
                                CREATION_DATE,
                                CREATED_BY,
                                REQUEST_ID,
                                ORDER_NUMBER,
                                ORIG_SYS_DOCUMENT_REF,
                                ORIG_SYS_LINE_REF,
                                Order_org_id,
                                LINE_REFERENCE_NUM,
                                SUPPLIER_REF_NUMBER)
                         VALUES (
                                    XXD_ONT_DROP_SHIP_CONV_STG_S.NEXTVAL,
                                    t_ont_drop_ship_tab (l_indx).PO_ORG_ID,
                                    t_ont_drop_ship_tab (l_indx).OU_NAME,
                                    t_ont_drop_ship_tab (l_indx).PO_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).PO_CREATION_DATE,
                                    t_ont_drop_ship_tab (l_indx).DOCUMENT_TYPE_CODE,
                                    t_ont_drop_ship_tab (l_indx).DOCUMENT_SUBTYPE,
                                    t_ont_drop_ship_tab (l_indx).PO_HEADER_ID,
                                    t_ont_drop_ship_tab (l_indx).CURRENCY_CODE,
                                    t_ont_drop_ship_tab (l_indx).AGENT_NAME,
                                    -- AGENT_ID                   ,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_NAME,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_ID,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_SITE_CODE,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_SITE_ID,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_CONTACT,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_CONTACT_ID,
                                    t_ont_drop_ship_tab (l_indx).PO_SHIP_TO_LOCATION,
                                    t_ont_drop_ship_tab (l_indx).PO_SHIP_TO_LOCATION_ID,
                                    t_ont_drop_ship_tab (l_indx).PO_BILL_TO_LOCATION,
                                    t_ont_drop_ship_tab (l_indx).PO_BILL_TO_LOCATION_ID,
                                    t_ont_drop_ship_tab (l_indx).TERM_NAME,
                                    --t_ont_drop_ship_tab (l_indx).TERMS_ID                   ,
                                    t_ont_drop_ship_tab (l_indx).FREIGHT_CARRIER,
                                    t_ont_drop_ship_tab (l_indx).FOB,
                                    t_ont_drop_ship_tab (l_indx).FREIGHT_TERMS_LOOKUP_CODE,
                                    t_ont_drop_ship_tab (l_indx).APPROVAL_STATUS,
                                    t_ont_drop_ship_tab (l_indx).APPROVED_DATE,
                                    t_ont_drop_ship_tab (l_indx).REVISED_DATE,
                                    t_ont_drop_ship_tab (l_indx).REVISION_NUM,
                                    t_ont_drop_ship_tab (l_indx).PO_NOTE_TO_VENDOR,
                                    t_ont_drop_ship_tab (l_indx).NOTE_TO_RECEIVER,
                                    t_ont_drop_ship_tab (l_indx).CONFIRMING_ORDER_FLAG,
                                    t_ont_drop_ship_tab (l_indx).COMMENTS,
                                    t_ont_drop_ship_tab (l_indx).ACCEPTANCE_REQUIRED_FLAG,
                                    t_ont_drop_ship_tab (l_indx).ACCEPTANCE_DUE_DATE,
                                    t_ont_drop_ship_tab (l_indx).PRINT_COUNT,
                                    t_ont_drop_ship_tab (l_indx).PRINTED_DATE,
                                    t_ont_drop_ship_tab (l_indx).TERM_NAME,
                                    t_ont_drop_ship_tab (l_indx).FROZEN_FLAG,
                                    t_ont_drop_ship_tab (l_indx).CLOSED_CODE,
                                    t_ont_drop_ship_tab (l_indx).CLOSED_DATE,
                                    -- t_ont_drop_ship_tab (l_indx).REPLY_DATE                   ,
                                    t_ont_drop_ship_tab (l_indx).REPLY_METHOD,
                                    t_ont_drop_ship_tab (l_indx).RFQ_CLOSE_DATE,
                                    t_ont_drop_ship_tab (l_indx).QUOTE_WARNING_DELAY,
                                    t_ont_drop_ship_tab (l_indx).VENDOR_DOC_NUM,
                                    t_ont_drop_ship_tab (l_indx).APPROVAL_REQUIRED_FLAG,
                                    t_ont_drop_ship_tab (l_indx).EDI_PROCESSED_FLAG,
                                    t_ont_drop_ship_tab (l_indx).EDI_PROCESSED_STATUS,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE_CATEGORY,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE1,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE2,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE3,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE4,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE5,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE6,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE7,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE8,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE9,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE10,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE11,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE12,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE13,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE14,
                                    t_ont_drop_ship_tab (l_indx).ATTRIBUTE15,
                                    t_ont_drop_ship_tab (l_indx).STYLE_ID,
                                    t_ont_drop_ship_tab (l_indx).STYLE_DISPLAY_NAME,
                                    t_ont_drop_ship_tab (l_indx).PO_REFERENCE_NUM,
                                    --line information
                                    t_ont_drop_ship_tab (l_indx).LINE_NUM,
                                    t_ont_drop_ship_tab (l_indx).PO_LINE_ID,
                                    t_ont_drop_ship_tab (l_indx).LINE_TYPE,
                                    t_ont_drop_ship_tab (l_indx).LINE_TYPE_ID,
                                    t_ont_drop_ship_tab (l_indx).ITEM,
                                    t_ont_drop_ship_tab (l_indx).ITEM_ID,
                                    t_ont_drop_ship_tab (l_indx).ITEM_REVISION,
                                    t_ont_drop_ship_tab (l_indx).CATEGORY_ID,
                                    t_ont_drop_ship_tab (l_indx).CATEGORY,
                                    t_ont_drop_ship_tab (l_indx).CATEGORY_SEGMENT1,
                                    t_ont_drop_ship_tab (l_indx).ITEM_DESCRIPTION,
                                    t_ont_drop_ship_tab (l_indx).UNIT_OF_MEASURE,
                                    t_ont_drop_ship_tab (l_indx).QUANTITY,
                                    t_ont_drop_ship_tab (l_indx).COMMITTED_AMOUNT,
                                    t_ont_drop_ship_tab (l_indx).MIN_ORDER_QUANTITY,
                                    t_ont_drop_ship_tab (l_indx).MAX_ORDER_QUANTITY,
                                    t_ont_drop_ship_tab (l_indx).UNIT_PRICE,
                                    t_ont_drop_ship_tab (l_indx).LIST_PRICE_PER_UNIT,
                                    t_ont_drop_ship_tab (l_indx).ALLOW_PRICE_OVERRIDE_FLAG,
                                    t_ont_drop_ship_tab (l_indx).NOT_TO_EXCEED_PRICE,
                                    t_ont_drop_ship_tab (l_indx).NEGOTIATED_BY_PREPARER_FLAG,
                                    t_ont_drop_ship_tab (l_indx).PL_NOTE_TO_VENDOR,
                                    t_ont_drop_ship_tab (l_indx).TRANSACTION_REASON_CODE,
                                    t_ont_drop_ship_tab (l_indx).TYPE_1099,
                                    t_ont_drop_ship_tab (l_indx).CAPITAL_EXPENSE_FLAG,
                                    t_ont_drop_ship_tab (l_indx).MIN_RELEASE_AMOUNT,
                                    t_ont_drop_ship_tab (l_indx).PRICE_BREAK_LOOKUP_CODE,
                                    t_ont_drop_ship_tab (l_indx).USSGL_TRANSACTION_CODE,
                                    t_ont_drop_ship_tab (l_indx).PL_CLOSED_CODE,
                                    t_ont_drop_ship_tab (l_indx).PL_CLOSED_REASON,
                                    t_ont_drop_ship_tab (l_indx).PL_CLOSED_DATE,
                                    t_ont_drop_ship_tab (l_indx).PL_CLOSED_BY,
                                    t_ont_drop_ship_tab (l_indx).PL_SHIP_TO_ORGANIZATION_CODE,
                                    t_ont_drop_ship_tab (l_indx).PL_SHIP_TO_ORGANIZATION_ID,
                                    t_ont_drop_ship_tab (l_indx).PL_SHIP_TO_LOCATION,
                                    t_ont_drop_ship_tab (l_indx).PL_SHIP_TO_LOCATION_ID,
                                    t_ont_drop_ship_tab (l_indx).NEED_BY_DATE,
                                    t_ont_drop_ship_tab (l_indx).PROMISED_DATE,
                                    t_ont_drop_ship_tab (l_indx).FROM_LINE_LOCATION_ID,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE_CATEGORY_LINES,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE1,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE2,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE3,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE4,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE5,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE6,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE7,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE8,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE9,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE10,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE11,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE12,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE13,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE14,
                                    t_ont_drop_ship_tab (l_indx).LINE_ATTRIBUTE15,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE_CATEGORY,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE1,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE2,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE3,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE4,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE5,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE6,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE7,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE8,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE9,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE10,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE11,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE12,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE13,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE14,
                                    t_ont_drop_ship_tab (l_indx).SHIPMENT_ATTRIBUTE15,
                                    t_ont_drop_ship_tab (l_indx).AUCTION_HEADER_ID,
                                    t_ont_drop_ship_tab (l_indx).AUCTION_LINE_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).AUCTION_DISPLAY_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).BID_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).BID_LINE_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).AMOUNT,
                                    t_ont_drop_ship_tab (l_indx).JOB_ID,
                                    TRIM (
                                        t_ont_drop_ship_tab (l_indx).DROP_SHIP_FLAG),
                                    'N',
                                    NULL,
                                    SYSDATE,
                                    gn_user_id,
                                    gn_user_id,
                                    SYSDATE,
                                    gn_user_id,
                                    gn_conc_request_id,
                                    t_ont_drop_ship_tab (l_indx).ORDER_NUMBER,
                                    t_ont_drop_ship_tab (l_indx).ORIG_SYS_DOCUMENT_REF,
                                    t_ont_drop_ship_tab (l_indx).ORIG_SYS_LINE_REF,
                                    t_ont_drop_ship_tab (l_indx).Order_org_id,
                                    t_ont_drop_ship_tab (l_indx).LINE_REFERENCE_NUM,
                                    t_ont_drop_ship_tab (l_indx).SUPPLIER_REF_NUMBER);

            COMMIT;
            EXIT WHEN lcu_drop_ship_orders%NOTFOUND;
        END LOOP;

        CLOSE lcu_drop_ship_orders;

        --- END LOOP;
        COMMIT;
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
    END extract_1206_po_data;

    PROCEDURE validate_po_data (p_org_name IN VARCHAR2, p_batch_id NUMBER, x_errbuf OUT VARCHAR2
                                , x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'VALIDATE_PO_R12';
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;
        lc_po_val_error_mesg      VARCHAR (4000) := NULL;

        CURSOR lcu_po_details IS
            SELECT ROWID, dss.*
              FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss
             WHERE                              --dss.Order_org_id = ln_org_id
                       record_status IN (gc_new_status, gc_error_status)
                   AND batch_id = p_batch_id;

        TYPE XXD_ONT_DROP_SHIP_TAB IS TABLE OF lcu_po_details%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_drop_ship_tab       XXD_ONT_DROP_SHIP_TAB;
    BEGIN
        lv_error_stage         := 'In Validate procedure of purchase order';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        t_ont_drop_ship_tab.delete;
        lc_po_val_error_mesg   := NULL;

        /* FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
         LOOP
            lv_error_stage := 'Loop start for Org :' || lc_org.lookup_code;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            lv_error_stage := 'Current Batch ID :' || p_batch_id;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);*/
        OPEN lcu_po_details;

        LOOP
            lv_error_stage   :=
                'Validating Drop ship Purchase Order Data in Staging';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            fnd_file.put_line (fnd_file.LOG,
                               LPAD ('Drop Ship PO validation Program', 70));
            --  lv_error_stage := 'Org Id' || lc_org.lookup_code;
            -- fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            t_ont_drop_ship_tab.delete;

            FETCH lcu_po_details
                BULK COLLECT INTO t_ont_drop_ship_tab
                LIMIT 5000;

            FOR l_indx IN 1 .. t_ont_drop_ship_tab.COUNT
            LOOP
                lc_po_val_error_mesg   := NULL;
                t_ont_drop_ship_tab (l_indx).TGT_PO_ORG_ID   :=
                    get_org_id (t_ont_drop_ship_tab (l_indx).PO_ORG_ID);

                IF t_ont_drop_ship_tab (l_indx).TGT_PO_ORG_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                        lc_po_val_error_mesg || '/' || 'Invalid OU';
                -- write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                -- lines information
                t_ont_drop_ship_tab (l_indx).ITEM_ID   :=
                    GET_ITEM_ID (t_ont_drop_ship_tab (l_indx).ITEM,
                                 t_ont_drop_ship_tab (l_indx).ORDER_ORG_ID);

                IF t_ont_drop_ship_tab (l_indx).ITEM_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                        lc_po_val_error_mesg || '/' || 'Invalid ITEM';
                --  write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                t_ont_drop_ship_tab (l_indx).LINE_TYPE_ID   :=
                    GET_NEW_Line_Type_ID (
                        t_ont_drop_ship_tab (l_indx).LINE_TYPE);

                IF t_ont_drop_ship_tab (l_indx).LINE_TYPE_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                        lc_po_val_error_mesg || '/' || 'Invalid Line Type';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                t_ont_drop_ship_tab (l_indx).req_line_id   :=
                    get_req_line_id (
                        t_ont_drop_ship_tab (l_indx).ORIG_SYS_LINE_REF,
                        t_ont_drop_ship_tab (l_indx).ITEM,
                        get_org_id (
                            t_ont_drop_ship_tab (l_indx).Order_org_id));

                IF t_ont_drop_ship_tab (l_indx).req_line_id = -1
                THEN
                    lc_po_val_error_mesg   :=
                           lc_po_val_error_mesg
                        || '/'
                        || 'Invalid requisition Line';
                --  write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                t_ont_drop_ship_tab (l_indx).agent_id   :=
                    get_agent_id (t_ont_drop_ship_tab (l_indx).agent_name);

                IF t_ont_drop_ship_tab (l_indx).agent_id = -1 -- added in ver 1.1
                THEN
                    t_ont_drop_ship_tab (l_indx).agent_id   :=
                        get_agent_id ('Stewart, Celene');

                    IF t_ont_drop_ship_tab (l_indx).agent_id = -1
                    THEN
                        t_ont_drop_ship_tab (l_indx).agent_id   := NULL;
                        lc_po_val_error_mesg                    :=
                               lc_po_val_error_mesg
                            || '/'
                            || 'Invalid agent name';
                    -- write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                    END IF;
                END IF;

                t_ont_drop_ship_tab (l_indx).VENDOR_SITE_ID   :=
                    get_vendor_site_id (
                        t_ont_drop_ship_tab (l_indx).VENDOR_NAME,
                        t_ont_drop_ship_tab (l_indx).VENDOR_SITE_CODE,
                        t_ont_drop_ship_tab (l_indx).TGT_PO_ORG_ID);

                IF t_ont_drop_ship_tab (l_indx).VENDOR_SITE_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                        lc_po_val_error_mesg || '/' || 'Invalid vendor Site';
                -- write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                t_ont_drop_ship_tab (l_indx).VENDOR_ID   :=
                    get_vendor_id (t_ont_drop_ship_tab (l_indx).VENDOR_NAME);

                IF t_ont_drop_ship_tab (l_indx).VENDOR_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                        lc_po_val_error_mesg || '/' || 'Invalid Vendor ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                --------------------------------- Location Validation ----------------
                t_ont_drop_ship_tab (l_indx).PO_SHIP_TO_LOCATION_ID   :=
                    get_ship_to_location (
                        t_ont_drop_ship_tab (l_indx).PL_SHIP_TO_ORGANIZATION_ID);

                IF t_ont_drop_ship_tab (l_indx).PO_SHIP_TO_LOCATION_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                           lc_po_val_error_mesg
                        || '/'
                        || 'Invalid SHIP TO Location ';
                --  write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                -------------------------------------  BILL to Location ----------------------
                t_ont_drop_ship_tab (l_indx).PO_BILL_TO_LOCATION_ID   :=
                    get_bill_to_location (
                        t_ont_drop_ship_tab (l_indx).VENDOR_SITE_ID);

                IF t_ont_drop_ship_tab (l_indx).PO_BILL_TO_LOCATION_ID = -1
                THEN
                    lc_po_val_error_mesg   :=
                           lc_po_val_error_mesg
                        || '/'
                        || 'Invalid BILL TO Location ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                IF     t_ont_drop_ship_tab (l_indx).VENDOR_SITE_ID <> -1
                   AND t_ont_drop_ship_tab (l_indx).VENDOR_ID <> -1
                   AND t_ont_drop_ship_tab (l_indx).req_line_id <> -1
                   AND t_ont_drop_ship_tab (l_indx).TGT_PO_ORG_ID <> -1
                   AND t_ont_drop_ship_tab (l_indx).PO_BILL_TO_LOCATION_ID <>
                       -1
                   AND t_ont_drop_ship_tab (l_indx).PO_SHIP_TO_LOCATION_ID <>
                       -1
                THEN
                    UPDATE XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T
                       SET record_status = gc_validate_status, error_message = NULL, TGT_PO_ORG_ID = t_ont_drop_ship_tab (l_indx).TGT_PO_ORG_ID,
                           ITEM_ID = t_ont_drop_ship_tab (l_indx).ITEM_ID, LINE_TYPE_ID = t_ont_drop_ship_tab (l_indx).LINE_TYPE_ID, req_line_id = t_ont_drop_ship_tab (l_indx).req_line_id,
                           agent_id = t_ont_drop_ship_tab (l_indx).agent_id, PO_BILL_TO_LOCATION_ID = t_ont_drop_ship_tab (l_indx).PO_BILL_TO_LOCATION_ID, PO_SHIP_TO_LOCATION_ID = t_ont_drop_ship_tab (l_indx).PO_SHIP_TO_LOCATION_ID
                     WHERE     1 = 1
                           AND ROWID = t_ont_drop_ship_tab (l_indx).ROWID;
                ELSE
                    -- write_log ('Error in PO validate Procedure' );
                    UPDATE XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T
                       SET record_status = gc_error_status, error_message = lc_po_val_error_mesg, /*   error_message =    DECODE (
                                                                                                                           t_ont_drop_ship_tab (l_indx).agent_id,
                                                                                                                           -1, 'Invalid Agent Name ',
                                                                                                                           '')
                                                                                                                     || DECODE (
                                                                                                                           t_ont_drop_ship_tab (l_indx).VENDOR_ID,
                                                                                                                           -1, 'Invalid Vendor Name',
                                                                                                                           '')
                                                                                                                     || DECODE (
                                                                                                                           t_ont_drop_ship_tab (l_indx).req_line_id,                               -- added in ver 1.1
                                                                                                                           -1, 'Requisition Info not found',
                                                                                                                           '')
                                                                                                                     || DECODE (
                                                                                                                           t_ont_drop_ship_tab (l_indx).VENDOR_SITE_ID,                            -- updated in ver 1.1
                                                                                                                           -1, 'Invalid Vendor Site',
                                                                                                                           ''), */
                                                                                                  TGT_PO_ORG_ID = t_ont_drop_ship_tab (l_indx).TGT_PO_ORG_ID,
                           ITEM_ID = t_ont_drop_ship_tab (l_indx).ITEM_ID, LINE_TYPE_ID = t_ont_drop_ship_tab (l_indx).LINE_TYPE_ID, req_line_id = t_ont_drop_ship_tab (l_indx).req_line_id,
                           agent_id = t_ont_drop_ship_tab (l_indx).agent_id
                     WHERE     1 = 1
                           AND ROWID = t_ont_drop_ship_tab (l_indx).ROWID;

                    x_errbuf    := 'Few of the PO records failed validation';
                    x_retcode   := gn_warning;
                END IF;

                COMMIT;
            END LOOP;

            EXIT WHEN lcu_po_details%NOTFOUND;
        END LOOP;

        CLOSE lcu_po_details;

        --END LOOP;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Validating PO record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END validate_po_data;

    FUNCTION GET_ITEM_ID_S (p_item IN VARCHAR2, p_org_id IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ITEM_ID                                               |
    -- | Description      : This procedure  is used to get                 |
    -- |                    item id                                        |
    -- |                                                                   |
    -- | Parameters : p_item, p_inv_org_id                                 |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_item_id                                              |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_item_id   NUMBER;
        x_status    VARCHAR2 (10);
    BEGIN
        x_status   := 'Y';

        --  fnd_file.put_line (fnd_file.LOG, 'p_item  ' || p_item );
        --   fnd_file.put_line (fnd_file.LOG, 'p_org_id  ' || p_org_id );
        SELECT DISTINCT inventory_item_id
          INTO x_item_id
          FROM mtl_system_items_kfv msb, mtl_parameters mp
         WHERE     mp.MASTER_ORGANIZATION_ID = mp.ORGANIZATION_ID
               AND mp.ORGANIZATION_ID = msb.ORGANIZATION_ID
               AND msb.CONCATENATED_SEGMENTS = UPPER (p_item);

        --   AND mp.organization_id = p_org_id;
        --AND outside_operation_flag = 'Y';
        RETURN x_item_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_item_id   := NULL;
            x_status    := 'N';
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Item Does not exist',
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                p_item,
                'Item Does not exist');
            write_log ('Exception to GET_ITEM_ID_S Procedure' || SQLERRM);
            RETURN -1;
    END GET_ITEM_ID_S;

    FUNCTION GET_CATEGORY_ID (p_item_id IN NUMBER, p_inv_org IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_CATEGORY_ID                                           |
    -- | Description      : This procedure  is used to get                 |
    -- |                    category id from category                      |
    -- |                                                                   |
    -- | Parameters : p_item_id,p_inv_org                                  |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_category_id                                          |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_category_id   NUMBER;
    BEGIN
        SELECT category_id
          INTO x_category_id
          FROM mtl_item_categories pa, mtl_category_sets_tl mt
         WHERE     inventory_item_id = p_item_id
               AND organization_id = p_inv_org
               AND pa.category_set_id = mt.category_set_id
               --AND category_set_name = 'Purchasing'
               AND category_set_name = 'PO Item Category'
               AND mt.language = 'US';

        RETURN x_category_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_CATEGORY_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_CATEGORY_ID',
                'Item ' || p_item_id || ' and Inv Org ' || p_inv_org);
            write_log ('Exception to GET_CATEGORY_ID Procedure' || SQLERRM);
            RETURN -1;
    END GET_CATEGORY_ID;

    FUNCTION get_ship_to_loc_id (p_loc_name       IN VARCHAR2,
                                 p_bill_ship_to   IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_loc_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'p_loc_name    ' || p_loc_name);
        fnd_file.put_line (fnd_file.LOG,
                           'p_bill_ship_to   ' || p_bill_ship_to);

        SELECT hla.location_id
          INTO x_loc_id
          FROM hr_locations_all hla
         WHERE     UPPER (hla.location_code) = UPPER (p_loc_name)
               --AND hla.inventory_organization_id = p_org_id
               AND ((p_bill_ship_to = 'BILL_TO' AND hla.bill_to_site_flag = 'Y') OR (p_bill_ship_to = 'SHIP_TO' AND hla.ship_to_site_flag = 'Y'));

        --    AND NVL (hla.inactive_date, TRUNC (SYSDATE)) >= TRUNC (SYSDATE);
        RETURN x_loc_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_SHIP_TO_LOC_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_SHIP_TO_LOC_ID',
                p_loc_name);
            write_log (
                'Exception to GET_SHIP_TO_LOC_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_ship_to_loc_id;

    FUNCTION get_group_id
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_group_id   NUMBER;
    BEGIN
        SELECT RCV_INTERFACE_GROUPS_S.NEXTVAL INTO x_group_id FROM DUAL;

        RETURN x_group_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*xxd_common_utils.record_error (
               'PO',
               gn_org_id,
               'XXD Drop ship sales Orders Conversion Program',
               --      SQLCODE,
               'Exception to GET_VENDOR_ID Procedure' || SQLERRM,
               DBMS_UTILITY.format_error_backtrace,
               --   DBMS_UTILITY.format_call_stack,
               --    SYSDATE,
               gn_user_id,
               gn_conc_request_id,
               'GROUP ID',
               P_group_id);*/
            write_log ('Exception to GET_GROUP_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_group_id;

    FUNCTION get_rcv_po_header_id (p_po_number IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_po_header_id   NUMBER;
    BEGIN
        SELECT DISTINCT PO_HEADER_ID
          INTO x_po_header_id
          FROM po_headers_all
         WHERE segment1 = p_po_number;

        RETURN x_po_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program ingetting rcv po header id',
                --      SQLCODE,
                'Exception to GET_RCV_PO_HEADER_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'Order ref id',
                p_po_number);
            write_log (
                'Exception to GET_RCV_PO_HEADER_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_rcv_po_header_id;

    FUNCTION get_rcv_po_line_id (p_po_header_id   IN NUMBER,
                                 p_po_line_num    IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_RCV_PO_LINE_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_po_line_id   NUMBER;
    BEGIN
        x_po_line_id   := NULL;

        /*  SELECT DISTINCT PO_line_ID
            INTO x_po_line_id
            FROM oe_drop_ship_sources odss, oe_order_lines_all ool
           WHERE     odss.header_id = ool.header_id
                 AND odss.line_id = ool.line_id
                 AND ool.ORIG_SYS_LINE_REF = p_org_ref_line; */
        SELECT DISTINCT po_line_id
          INTO x_po_line_id
          FROM po_headers_all poh, po_lines_all pol
         WHERE     1 = 1
               AND poh.po_header_id = pol.po_header_id
               AND poh.po_header_id = p_po_header_id
               AND pol.line_num = p_po_line_num;

        IF x_po_line_id IS NULL
        THEN
            RETURN -1;
        ELSE
            RETURN x_po_line_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to get_rcv_po_line_id Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'PO Header ID',
                P_PO_HEADER_ID);
            write_log (
                'Exception to GET_RCV_PO_LINE_ID Procedure' || SQLERRM);
            RETURN -1;
    END get_rcv_po_line_id;

    FUNCTION get_rcv_po_lloc_id (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_ship_num IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_po_line_loc_id   NUMBER;
    BEGIN
        x_po_line_loc_id   := NULL;

        SELECT LINE_LOCATION_ID
          INTO x_po_line_loc_id
          FROM po_line_locations_all
         WHERE     po_line_id = p_po_line_id
               AND po_header_id = p_po_header_id
               AND shipment_num = p_ship_num;

        IF x_po_line_loc_id IS NULL
        THEN
            RETURN -1;
        ELSE
            RETURN x_po_line_loc_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_VENDOR_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'PO Line Id',
                p_po_line_id);
            write_log (
                   'Exception to GET_RCV_PO_LINE_LOCATION_ID Procedure'
                || SQLERRM);
            RETURN -1;
    END get_rcv_po_lloc_id;

    FUNCTION get_rcv_po_ldist_id (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_po_line_loc_id IN NUMBER
                                  , p_dist_num IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_po_dist_line_id   NUMBER;
    BEGIN
        x_po_dist_line_id   := NULL;

        SELECT PO_DISTRIBUTION_ID
          INTO x_po_dist_line_id
          FROM po_distributions_all
         WHERE     po_line_id = p_po_line_id
               AND po_header_id = p_po_header_id
               AND po_line_id = p_po_line_id
               AND line_location_id = p_po_line_loc_id
               AND distribution_num = p_dist_num;

        IF x_po_dist_line_id IS NULL
        THEN
            RETURN -1;
        ELSE
            RETURN x_po_dist_line_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Drop ship sales Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_VENDOR_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'PO Line Id',
                p_po_line_id);
            write_log (
                   'Exception to GET_RCV_PO_LINE_DISTRIBUTION_ID Procedure'
                || SQLERRM);
            RETURN -1;
    END get_rcv_po_ldist_id;



    PROCEDURE update_drop_ship_prc (p_org_name IN VARCHAR2, p_batch_id IN NUMBER, x_return_mesg OUT VARCHAR2
                                    , x_return_code OUT NUMBER)
    IS
        /*  CURSOR cur_Batch_id
          IS   SELECT DISTINCT phi.batch_id, phi.org_id
      FROM PO_REQUISITION_HEADERS_ALL PORH,
           PO_REQUISITION_LINES_ALL PORL,
           po_line_locations_interface PLLI,
           PO_LINES_INTERFACE PLI,
           PO_HEADERS_INTERFACE PHI,
           po_headers_all poh,
           OE_DROP_SHIP_SOURCES OEDSS
     WHERE     PORH.REQUISITION_HEADER_ID = PORL.REQUISITION_HEADER_ID
           AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
           AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
           AND PLLI.INTERFACE_LINE_ID = PLI.INTERFACE_LINE_ID
           AND PLI.INTERFACE_HEADER_ID = PHI.INTERFACE_HEADER_ID
           AND phi.po_header_id = poh.po_header_id
           AND oedss.po_header_id IS NULL; */
        CURSOR cur_Batch_id IS
            SELECT DISTINCT xdso.batch_id, poh.org_id
              FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, po_line_locations_all PLLI,
                   PO_LINES_ALL PLI, po_headers_all poh, OE_DROP_SHIP_SOURCES OEDSS,
                   XXD_DROP_SHIP_PO_CONV_STG_T xdso
             WHERE     1 = 1
                   AND xdso.record_status = 'I'
                   AND xdso.po_number = poh.segment1
                   AND PORH.REQUISITION_HEADER_ID =
                       PORL.REQUISITION_HEADER_ID
                   AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
                   AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
                   AND PLLI.po_line_id = PLI.po_line_id
                   AND PLI.po_header_id = poh.po_header_id
                   AND oedss.po_header_id IS NULL
                   AND NVL (xdso.batch_id, 999) = NVL (p_batch_id, 999);


        /*  CURSOR cur_update_drop_ship (
             p_batch_id NUMBER)
          IS
             SELECT DISTINCT PHI.PO_HEADER_ID,
                             PLI.PO_LINE_ID,
                             PLLI.LINE_LOCATION_ID,
                             porh.requisition_header_id,
                             PORL.requisition_line_id
               FROM PO_REQUISITION_HEADERS_ALL PORH,
                    PO_REQUISITION_LINES_ALL PORL,
                    po_line_locations_interface PLLI,
                    PO_LINES_INTERFACE PLI,
                    PO_HEADERS_INTERFACE PHI,
                    po_headers_all poh,
                    OE_DROP_SHIP_SOURCES OEDSS
              WHERE     PORH.REQUISITION_HEADER_ID = PORL.REQUISITION_HEADER_ID
                    AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
                    AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
                    AND PLLI.INTERFACE_LINE_ID = PLI.INTERFACE_LINE_ID
                    AND PLI.INTERFACE_HEADER_ID = PHI.INTERFACE_HEADER_ID
                    AND phi.po_header_id = poh.po_header_id
                    AND oedss.po_header_id IS NULL
                    AND phi.batch_id = p_batch_id;
                    */
        CURSOR cur_update_drop_ship (p_batch_id NUMBER, p_po_org_id NUMBER)
        IS
            SELECT DISTINCT POH.PO_HEADER_ID, PLI.PO_LINE_ID, PLLI.LINE_LOCATION_ID,
                            porh.requisition_header_id, PORL.requisition_line_id
              FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, po_line_locations_all PLLI,
                   PO_LINES_ALL PLI, po_headers_all poh, OE_DROP_SHIP_SOURCES OEDSS,
                   XXD_DROP_SHIP_PO_CONV_STG_T xdso
             WHERE     1 = 1
                   AND xdso.record_status = 'I'
                   AND xdso.po_number = poh.segment1
                   AND PORH.REQUISITION_HEADER_ID =
                       PORL.REQUISITION_HEADER_ID
                   AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
                   AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
                   AND PLLI.po_line_id = PLI.po_line_id
                   AND PLI.po_header_id = poh.po_header_id
                   AND oedss.po_header_id IS NULL
                   AND xdso.batch_id = p_batch_id
                   AND poh.org_id = p_po_org_id;


        CURSOR cur_distict_po_edi_flag IS
            SELECT DISTINCT xdso.po_number, xdso.edi_processed_flag, xdso.edi_processed_status
              FROM XXD_DROP_SHIP_PO_CONV_STG_T xdso
             WHERE     1 = 1
                   AND NVL (xdso.batch_id, 999) = NVL (p_batch_id, 999)
                   AND xdso.record_status = 'I'
                   AND EXISTS
                           (SELECT 1
                              FROM po_headers_all poh
                             WHERE poh.segment1 = xdso.po_number);

        cur_update_drop_ship_rec   cur_update_drop_ship%ROWTYPE;
        x_request_id               NUMBER;
        x_application_id           NUMBER;
        x_responsibility_id        NUMBER;
        ln_count                   NUMBER := 1;
        ln_exit_flag               NUMBER := 0;
        lb_flag                    BOOLEAN := FALSE;
        lc_rollback                EXCEPTION;
        lc_launch_rollback         EXCEPTION;
        lc_released_Status         VARCHAR2 (200);
        ln_del_id                  NUMBER;
        ln_org_id                  NUMBER;
        log_msg                    VARCHAR2 (4000);
        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);
        lc_message                 VARCHAR2 (2000);
        ln_req_id                  NUMBER;
        lb_request_status          BOOLEAN;
        v_return_status            VARCHAR2 (50);
        v_dropship_return_status   VARCHAR2 (50);
        v_dropship_Msg_Count       VARCHAR2 (50);
        v_dropship_Msg_data        VARCHAR2 (50);
    BEGIN
        -- x_return_sts := GC_API_SUCCESS;

        -- added in ver 1.2 to update edi flag status

        FOR rec_distict_po_edi_flag IN cur_distict_po_edi_flag
        LOOP
            UPDATE po_headers_all
               SET edi_processed_flag = rec_distict_po_edi_flag.edi_processed_flag, edi_processed_status = rec_distict_po_edi_flag.edi_processed_status
             WHERE segment1 = rec_distict_po_edi_flag.po_number;
        END LOOP;

        COMMIT;

        --- end of ver 1.2--------------------------

        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'Start of Procedure req_import_prc ');

        --    debug(GC_SOURCE_PROGRAM);
        FOR get_batch_id IN cur_Batch_id
        LOOP
            --ln_org_id := get_targetorg_id (p_org_name => p_org_name); --fnd_profile.VALUE ('ORG_ID');
            set_org_context (p_target_org_id   => get_batch_id.org_id,
                             p_resp_id         => x_responsibility_id,
                             p_resp_appl_id    => x_application_id);
            fnd_request.set_org_id (TO_NUMBER (get_batch_id.org_id));
            log_records (p_debug     => gc_debug_flag,
                         p_message   => 'batch_id' || get_batch_id.batch_id);
            --    debug(GC_SOURCE_PROGRAM);
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Submitting Purchase Update Program for batch Id  '
                || get_batch_id.batch_id);

            -------
            OPEN cur_update_drop_ship (TO_NUMBER (get_batch_id.batch_id),
                                       get_batch_id.org_id);

            IF cur_update_drop_ship%NOTFOUND
            THEN
                COMMIT;

                CLOSE cur_update_drop_ship;
            ELSE
                LOOP
                    FETCH cur_update_drop_ship INTO cur_update_drop_ship_rec;

                    EXIT WHEN cur_update_drop_ship%NOTFOUND;

                    BEGIN
                        APPS.OE_DROP_SHIP_GRP.Update_PO_Info (
                            p_api_version     => 1.0,
                            P_Return_Status   => v_dropship_return_status,
                            P_Msg_Count       => v_dropship_Msg_Count,
                            P_MSG_Data        => v_dropship_MSG_Data,
                            P_Req_Header_ID   =>
                                cur_update_drop_ship_rec.requisition_header_id,
                            P_Req_Line_ID     =>
                                cur_update_drop_ship_rec.requisition_line_id,
                            P_PO_Header_Id    =>
                                cur_update_drop_ship_rec.PO_HEADER_ID,
                            P_PO_Line_Id      =>
                                cur_update_drop_ship_rec.PO_LINE_ID,
                            P_Line_Location_ID   =>
                                cur_update_drop_ship_rec.LINE_LOCATION_ID);
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                               'v_dropship_return_status '
                            || CHR (10)
                            || v_dropship_return_status);

                        IF (v_dropship_return_status = FND_API.g_ret_sts_success)
                        THEN
                            x_return_code   := gn_success;
                            fnd_file.PUT_LINE (
                                fnd_file.LOG,
                                'drop ship successs' || CHR (10));

                            UPDATE PO_LINE_LOCATIONS_ALL PLLA
                               SET SHIP_TO_LOCATION_ID   =
                                       (SELECT DISTINCT
                                               PORL.DELIVER_TO_LOCATION_ID
                                          FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL
                                         WHERE     PORH.REQUISITION_HEADER_ID =
                                                   PORL.REQUISITION_HEADER_ID
                                               AND PLLA.LINE_LOCATION_ID =
                                                   PORL.LINE_LOCATION_ID
                                               AND PORL.LINE_LOCATION_ID =
                                                   cur_update_drop_ship_rec.LINE_LOCATION_ID)
                             WHERE PLLA.LINE_LOCATION_ID =
                                   cur_update_drop_ship_rec.LINE_LOCATION_ID;

                            COMMIT;
                        ELSIF v_dropship_return_status =
                              (FND_API.G_RET_STS_ERROR)
                        THEN
                            FOR i IN 1 .. FND_MSG_PUB.count_msg
                            LOOP
                                fnd_file.PUT_LINE (
                                    fnd_file.LOG,
                                    'DROP SHIP api ERROR:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                            END LOOP;

                            x_return_code   := gn_warning;
                        ELSIF v_dropship_return_status =
                              FND_API.G_RET_STS_UNEXP_ERROR
                        THEN
                            FOR i IN 1 .. FND_MSG_PUB.count_msg
                            LOOP
                                fnd_file.PUT_LINE (
                                    fnd_file.LOG,
                                       'DROP SHIP UNEXPECTED ERROR:'
                                    || FND_MSG_PUB.Get (p_msg_index   => i,
                                                        p_encoded     => 'F'));
                            END LOOP;

                            x_return_code   := gn_warning;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.PUT_LINE (fnd_file.LOG,
                                               'drop ship when others');
                    END;
                END LOOP;

                CLOSE cur_update_drop_ship;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   :=
                'The procedure reqisition_import Failed  ' || SQLERRM;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
            RAISE_APPLICATION_ERROR (-20003, SQLERRM);
    END update_drop_ship_prc;

    PROCEDURE po_interface_insert (p_org_name IN VARCHAR2, p_batch_id NUMBER, x_errbuf OUT VARCHAR2
                                   , x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (50) := 'UPDATE REQ NUMBER';
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;
        l_err_msg                 VARCHAR2 (4000);

        CURSOR lcu_po_details IS
            SELECT dss.*
              FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss;

        -- WHERE dss.Order_org_id = ln_org_id;
        CURSOR lcu_po_header_num IS
            /* SELECT DISTINCT dss.PO_NUMBER
               FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss
              WHERE dss.Order_org_id = ln_org_id AND batch_id = p_batch_id; */
            SELECT DISTINCT dss.PO_NUMBER
              FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss
             WHERE                              --dss.Order_org_id = ln_org_id
                       batch_id = p_batch_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss2
                             WHERE     dss2.record_status = 'E'
                                   AND dss2.po_number = dss.po_number);

        CURSOR lcu_po_lines (ln_po_number VARCHAR2)
        IS
            SELECT dss.*
              FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss
             WHERE     dss.PO_NUMBER = ln_po_number
                   AND record_status = gc_validate_status
                   AND batch_id = p_batch_id;

        CURSOR cur_stg_update IS
            SELECT ROWID, a.*
              FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T a
             WHERE     record_status = gc_validate_status
                   AND batch_id = p_batch_id;

        --   AND record_status = gc_validate_status;
        TYPE XXD_ONT_PO_DETAILS_TAB IS TABLE OF lcu_po_details%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lcu_po_header_REC         lcu_po_header_NUM%ROWTYPE;
        lcu_po_lines_REC          lcu_po_lines%ROWTYPE;
        t_ont_po_details_tab      XXD_ONT_PO_DETAILS_TAB;
        L_COUNT                   NUMBER := 0;
    BEGIN
        lv_error_stage   :=
            'In data into purchase order interface table procedure';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        t_ont_po_details_tab.delete;

        /*FOR lc_org
           IN (SELECT lookup_code
                 FROM apps.fnd_lookup_values
                WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                      AND attribute1 = p_org_name
                      AND language = 'US')
        LOOP
           lv_error_stage := 'Inserting Data into purchase order Interface table';
           fnd_file.put_line (fnd_file.LOG, lv_error_stage);
           lv_error_stage := 'Org Id' || lc_org.lookup_code;
           fnd_file.put_line (fnd_file.LOG, lv_error_stage);*/
        OPEN lcu_po_header_num;

        LOOP
            l_count   := 1;

            FETCH lcu_po_header_num INTO lcu_po_header_REC;

            EXIT WHEN lcu_po_header_num%NOTFOUND;

            OPEN lcu_po_lines (lcu_po_header_REC.PO_NUMBER);

            LOOP
                FETCH lcu_po_lines INTO lcu_po_lines_REC;

                EXIT WHEN lcu_po_lines%NOTFOUND;

                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'INserting PO header '
                        || lcu_po_lines_rec.PO_NUMBER
                        || 'l_count '
                        || l_count);

                    IF l_count = 1
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'INserting PO header ' || lcu_po_lines_rec.PO_NUMBER);

                        INSERT INTO PO_HEADERS_INTERFACE (
                                        action,
                                        BATCH_ID,
                                        INTERFACE_HEADER_ID,
                                        ORG_ID,
                                        DOCUMENT_TYPE_CODE,
                                        DOCUMENT_NUM,
                                        CREATION_DATE,
                                        PO_HEADER_ID,
                                        CURRENCY_CODE,
                                        AGENT_ID,
                                        VENDOR_NAME,
                                        VENDOR_SITE_CODE,
                                        SHIP_TO_LOCATION_ID,
                                        BILL_TO_LOCATION_ID,
                                        PAYMENT_TERMS,
                                        APPROVAL_STATUS,
                                        APPROVED_DATE,
                                        REVISED_DATE,
                                        REVISION_NUM,
                                        NOTE_TO_VENDOR,
                                        NOTE_TO_RECEIVER,
                                        COMMENTS,
                                        ACCEPTANCE_REQUIRED_FLAG,
                                        ACCEPTANCE_DUE_DATE,
                                        PRINT_COUNT,
                                        PRINTED_DATE,
                                        FIRM_FLAG,
                                        FROZEN_FLAG,
                                        CLOSED_CODE,
                                        CLOSED_DATE,
                                        -- REPLY_DATE    ,
                                        REPLY_METHOD,
                                        RFQ_CLOSE_DATE,
                                        QUOTE_WARNING_DELAY,
                                        VENDOR_DOC_NUM,
                                        APPROVAL_REQUIRED_FLAG,
                                        ATTRIBUTE_CATEGORY,
                                        ATTRIBUTE1,
                                        ATTRIBUTE2,
                                        ATTRIBUTE3,
                                        ATTRIBUTE4,
                                        ATTRIBUTE5,
                                        ATTRIBUTE6,
                                        ATTRIBUTE7,
                                        ATTRIBUTE8,
                                        ATTRIBUTE9,
                                        ATTRIBUTE10,
                                        ATTRIBUTE11,
                                        ATTRIBUTE12,
                                        ATTRIBUTE13,
                                        ATTRIBUTE14,
                                        ATTRIBUTE15,
                                        STYLE_DISPLAY_NAME,
                                        REFERENCE_NUM)
                             VALUES ('ORIGINAL', p_batch_id, -- lcu_po_lines_REC.po_org_id, --batch_id
                                                             po_headers_interface_s.NEXTVAL, lcu_po_lines_rec.tgt_po_org_id, --org_id
                                                                                                                             'STANDARD', lcu_po_lines_rec.PO_NUMBER, lcu_po_lines_rec.PO_CREATION_DATE, NULL, -- PO_HEADERS_S.NEXTVAL,           --PO_HEADER_ID,
                                                                                                                                                                                                              lcu_po_lines_rec.CURRENCY_CODE, lcu_po_lines_rec.AGENT_id, lcu_po_lines_rec.VENDOR_NAME, lcu_po_lines_rec.VENDOR_SITE_CODE, lcu_po_lines_rec.PO_SHIP_TO_LOCATION_ID, lcu_po_lines_rec.PO_BILL_TO_LOCATION_ID, lcu_po_lines_rec.PAYMENT_TERMS, NULL, --  lcu_po_lines_rec.APPROVAL_STATUS,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                  NULL, -- lcu_po_lines_rec.APPROVED_DATE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        NULL, --  lcu_po_lines_rec.REVISED_DATE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                              NULL, --   lcu_po_lines_rec.REVISION_NUM,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    lcu_po_lines_rec.PO_NOTE_TO_VENDOR, lcu_po_lines_rec.NOTE_TO_RECEIVER, lcu_po_lines_rec.COMMENTS, NULL, --  lcu_po_lines_rec.ACCEPTANCE_REQUIRED_FLAG,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            --  lcu_po_lines_rec.ACCEPTANCE_DUE_DATE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            TO_DATE (lcu_po_lines_rec.ACCEPTANCE_DUE_DATE, 'DD-MM-YYYY'), NULL, -- lcu_po_lines_rec.PRINT_COUNT,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                TO_DATE (lcu_po_lines_rec.PRINTED_DATE, 'DD-MM-YYYY'), NULL, -- lcu_po_lines_rec.FIRM_FLAG,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             lcu_po_lines_rec.FROZEN_FLAG, lcu_po_lines_rec.PO_CLOSED_CODE, /*TO_DATE (
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              lcu_po_lines_rec.PO_CLOSED_DATE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              'DD-MM-YYYY'),*/
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            NULL, -- REPLY_DATE    ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  lcu_po_lines_rec.REPLY_METHOD, -- lcu_po_lines_rec.RFQ_CLOSE_DATE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 TO_DATE (lcu_po_lines_rec.RFQ_CLOSE_DATE, 'DD-MM-YYYY'), -- REPLY_DATE    ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          lcu_po_lines_rec.QUOTE_WARNING_DELAY, lcu_po_lines_rec.VENDOR_DOC_NUM, lcu_po_lines_rec.APPROVAL_REQUIRED_FLAG, NVL (lcu_po_lines_rec.ATTRIBUTE_CATEGORY, 'PO Data Elements'), lcu_po_lines_rec.ATTRIBUTE1, lcu_po_lines_rec.ATTRIBUTE2, lcu_po_lines_rec.ATTRIBUTE3, lcu_po_lines_rec.ATTRIBUTE4, lcu_po_lines_rec.ATTRIBUTE5, lcu_po_lines_rec.ATTRIBUTE6, lcu_po_lines_rec.ATTRIBUTE7, lcu_po_lines_rec.ATTRIBUTE8, lcu_po_lines_rec.ATTRIBUTE9, lcu_po_lines_rec.ATTRIBUTE10, lcu_po_lines_rec.ATTRIBUTE11, lcu_po_lines_rec.ATTRIBUTE12, lcu_po_lines_rec.ATTRIBUTE13, lcu_po_lines_rec.ATTRIBUTE14, lcu_po_lines_rec.ATTRIBUTE15
                                     , NULL, -- lcu_po_lines_rec.STYLE_DISPLAY_NAME,
                                             NULL); --lcu_po_lines_rec.REFERENCE_NUM);

                        COMMIT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'INserting PO header successful '
                            || lcu_po_lines_rec.PO_NUMBER);
                        L_COUNT   := L_COUNT + 1;
                    END IF;

                    --  EXIT WHEN lcu_po_details%NOTFOUND;
                    INSERT INTO PO_lines_interface (
                                    action,
                                    interface_line_id,
                                    interface_header_id,
                                    LINE_TYPE_id,
                                    ITEM_ID,
                                    line_num,
                                    --    CATEGORY_ID,
                                    -- CATEGORY,
                                    -- CATEGORY_SEGMENT1,
                                    -- ITEM_DESCRIPTION,
                                    QUANTITY,
                                    COMMITTED_AMOUNT,
                                    MIN_ORDER_QUANTITY,
                                    MAX_ORDER_QUANTITY,
                                    ALLOW_PRICE_OVERRIDE_FLAG,
                                    NOT_TO_EXCEED_PRICE,
                                    NEGOTIATED_BY_PREPARER_FLAG,
                                    NOTE_TO_VENDOR,
                                    TRANSACTION_REASON_CODE,
                                    TYPE_1099,
                                    CAPITAL_EXPENSE_FLAG,
                                    MIN_RELEASE_AMOUNT,
                                    PRICE_BREAK_LOOKUP_CODE,
                                    USSGL_TRANSACTION_CODE,
                                    CLOSED_CODE,
                                    CLOSED_REASON,
                                    CLOSED_DATE,
                                    CLOSED_BY,
                                    SHIP_TO_LOCATION_ID,
                                    NEED_BY_DATE,
                                    PROMISED_DATE,
                                    LINE_ATTRIBUTE_CATEGORY_LINES,
                                    LINE_ATTRIBUTE1,
                                    LINE_ATTRIBUTE2,
                                    LINE_ATTRIBUTE3,
                                    LINE_ATTRIBUTE4,
                                    LINE_ATTRIBUTE5,
                                    LINE_ATTRIBUTE6,
                                    LINE_ATTRIBUTE7,
                                    LINE_ATTRIBUTE8,
                                    LINE_ATTRIBUTE9,
                                    LINE_ATTRIBUTE10,
                                    LINE_ATTRIBUTE11,
                                    LINE_ATTRIBUTE12,
                                    LINE_ATTRIBUTE13,
                                    LINE_ATTRIBUTE14,
                                    LINE_ATTRIBUTE15,
                                    SHIPMENT_ATTRIBUTE_CATEGORY,
                                    SHIPMENT_ATTRIBUTE1,
                                    SHIPMENT_ATTRIBUTE2,
                                    SHIPMENT_ATTRIBUTE3,
                                    SHIPMENT_ATTRIBUTE4,
                                    SHIPMENT_ATTRIBUTE5,
                                    SHIPMENT_ATTRIBUTE6,
                                    SHIPMENT_ATTRIBUTE7,
                                    SHIPMENT_ATTRIBUTE8,
                                    SHIPMENT_ATTRIBUTE9,
                                    SHIPMENT_ATTRIBUTE10,
                                    SHIPMENT_ATTRIBUTE11,
                                    SHIPMENT_ATTRIBUTE12,
                                    SHIPMENT_ATTRIBUTE13,
                                    SHIPMENT_ATTRIBUTE14,
                                    SHIPMENT_ATTRIBUTE15,
                                    AUCTION_DISPLAY_NUMBER,
                                    BID_NUMBER,
                                    AMOUNT,
                                    DROP_SHIP_FLAG,
                                    requisition_line_id,
                                    UNIT_PRICE)
                             VALUES (
                                        'ORIGINAL',
                                        po_lines_interface_s.NEXTVAL,
                                        po_headers_interface_s.CURRVAL,
                                        lcu_po_lines_rec.LINE_TYPE_id,
                                        lcu_po_lines_rec.ITEM_ID,
                                        lcu_po_lines_rec.line_num,
                                        --  lcu_po_lines_rec.CATEGORY_ID,
                                        -- lcu_po_lines_rec.ITEM_DESCRIPTION,
                                        lcu_po_lines_rec.QUANTITY,
                                        lcu_po_lines_rec.COMMITTED_AMOUNT,
                                        lcu_po_lines_rec.MIN_ORDER_QUANTITY,
                                        lcu_po_lines_rec.MAX_ORDER_QUANTITY,
                                        lcu_po_lines_rec.ALLOW_PRICE_OVERRIDE_FLAG,
                                        lcu_po_lines_rec.NOT_TO_EXCEED_PRICE,
                                        lcu_po_lines_rec.NEGOTIATED_BY_PREPARER_FLAG,
                                        lcu_po_lines_rec.PL_NOTE_TO_VENDOR,
                                        lcu_po_lines_rec.TRANSACTION_REASON_CODE,
                                        lcu_po_lines_rec.TYPE_1099,
                                        lcu_po_lines_rec.CAPITAL_EXPENSE_FLAG,
                                        lcu_po_lines_rec.MIN_RELEASE_AMOUNT,
                                        lcu_po_lines_rec.PRICE_BREAK_LOOKUP_CODE,
                                        lcu_po_lines_rec.USSGL_TRANSACTION_CODE,
                                        lcu_po_lines_rec.PL_CLOSED_CODE,
                                        lcu_po_lines_rec.PL_CLOSED_REASON,
                                        /*TO_DATE (
                                          lcu_po_lines_rec.PL_CLOSED_DATE,
                                          'DD-MM-YYYY'),*/
                                        NULL,
                                        lcu_po_lines_rec.PL_CLOSED_BY,
                                        lcu_po_lines_rec.PO_SHIP_TO_LOCATION_ID,
                                        TO_DATE (
                                            lcu_po_lines_rec.NEED_BY_DATE,
                                            'DD-MM-YYYY'),
                                        TO_DATE (
                                            lcu_po_lines_rec.PROMISED_DATE,
                                            'DD-MM-YYYY'),
                                        NVL (
                                            lcu_po_lines_rec.LINE_ATTRIBUTE_CATEGORY_LINES,
                                            'PO Data Elements'),
                                        lcu_po_lines_rec.LINE_ATTRIBUTE1,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE2,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE3,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE4,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE5,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE6,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE7,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE8,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE9,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE10,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE11,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE12,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE13,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE14,
                                        lcu_po_lines_rec.LINE_ATTRIBUTE15,
                                        NVL (
                                            lcu_po_lines_rec.SHIPMENT_ATTRIBUTE_CATEGORY,
                                            'PO Line Locations Elements'),
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE1,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE2,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE3,
                                        --  lcu_po_lines_rec.SHIPMENT_ATTRIBUTE4,
                                        --  lcu_po_lines_rec.SHIPMENT_ATTRIBUTE5,
                                        TO_CHAR (
                                            TO_DATE (
                                                lcu_po_lines_rec.SHIPMENT_ATTRIBUTE4,
                                                'dd-mon-yy'),
                                            'yyyy/mm/dd HH:MI:SS'),
                                        TO_CHAR (
                                            TO_DATE (
                                                lcu_po_lines_rec.SHIPMENT_ATTRIBUTE5,
                                                'dd-mon-yy'),
                                            'yyyy/mm/dd HH:MI:SS'),
                                        -- TO_CHAR(TO_DATE(lcu_po_lines_rec.SHIPMENT_ATTRIBUTE4,'DD-MON-RRRR'),'RRRR/MM/DD'),                      -- ver 1.2
                                        -- TO_CHAR(TO_DATE(lcu_po_lines_rec.SHIPMENT_ATTRIBUTE5,'DD-MON-RRRR'),'RRRR/MM/DD'),                     -- ver 1.2
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE6,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE7,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE8,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE9,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE10,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE11,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE12,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE13,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE14,
                                        lcu_po_lines_rec.SHIPMENT_ATTRIBUTE15,
                                        lcu_po_lines_rec.AUCTION_DISPLAY_NUMBER,
                                        lcu_po_lines_rec.BID_NUMBER,
                                        lcu_po_lines_rec.AMOUNT,
                                        lcu_po_lines_rec.DROP_SHIP_FLAG,
                                        lcu_po_lines_rec.req_line_id,
                                        lcu_po_lines_rec.UNIT_PRICE);

                    UPDATE XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T
                       SET record_status   = gc_interfaced
                     WHERE     record_status = gc_validate_status
                           AND ORIG_SYS_LINE_REF =
                               lcu_po_lines_rec.ORIG_SYS_LINE_REF;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_err_msg   := SQLERRM;

                        UPDATE XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T
                           SET record_status = gc_error_status, error_message = l_err_msg
                         WHERE     record_status = gc_validate_status
                               AND ORIG_SYS_LINE_REF =
                                   lcu_po_lines_rec.ORIG_SYS_LINE_REF;
                END;
            END LOOP;

            CLOSE lcu_po_lines;
        END LOOP;

        CLOSE lcu_po_header_num;

        COMMIT;
    --  END LOOP;
    --END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record in the PO Interface table '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END po_interface_insert;

    PROCEDURE po_import_prc (p_org_name IN VARCHAR2, p_batch_id NUMBER, x_return_mesg OUT VARCHAR2
                             , x_return_code OUT NUMBER)
    IS
        CURSOR cur_Batch_id IS
            SELECT DISTINCT org_id
              FROM po_headers_interface
             WHERE batch_id = p_batch_id;

        x_request_id               NUMBER;
        x_application_id           NUMBER;
        x_responsibility_id        NUMBER;
        ln_count                   NUMBER := 1;
        ln_exit_flag               NUMBER := 0;
        lb_flag                    BOOLEAN := FALSE;
        lc_rollback                EXCEPTION;
        lc_launch_rollback         EXCEPTION;
        lc_released_Status         VARCHAR2 (200);
        ln_del_id                  NUMBER;
        ln_org_id                  NUMBER;
        log_msg                    VARCHAR2 (4000);
        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);
        -- lc_message            VARCHAR2 (2000);
        -- lb_request_status     BOOLEAN;
        v_return_status            VARCHAR2 (50);
        lc_phase                   VARCHAR2 (2000);
        lc_wait_status             VARCHAR2 (2000);
        lc_dev_phase               VARCHAR2 (2000);
        lc_dev_status              VARCHAR2 (2000);
        lc_message                 VARCHAR2 (2000);
        ln_req_id                  NUMBER;
        lb_request_status          BOOLEAN;
    BEGIN
        -- x_return_sts := GC_API_SUCCESS;
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'Start of Procedure req_import_prc ');

        --    debug(GC_SOURCE_PROGRAM);
        FOR batch_id IN cur_Batch_id
        LOOP
            --ln_org_id := get_targetorg_id (p_org_name => p_org_name); --fnd_profile.VALUE ('ORG_ID');
            set_org_context (p_target_org_id   => TO_NUMBER (batch_id.org_id),
                             p_resp_id         => x_responsibility_id,
                             p_resp_appl_id    => x_application_id);
            fnd_request.set_org_id (TO_NUMBER (batch_id.org_id));
            log_records (p_debug     => gc_debug_flag,
                         p_message   => 'ln_org_id' || batch_id.org_id);
            --    debug(GC_SOURCE_PROGRAM);
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Submitting Purchase Order Import Program for batch Id  '
                || batch_id.org_id);
            --  mo_global.init ('PO');
            --   APPS.fnd_global.APPS_INITIALIZE (gn_user_id, x_responsibility_id, x_application_id);
            ln_req_id   :=
                fnd_request.submit_request (application   => 'PO',
                                            program       => 'POXPOPDOI',
                                            description   => NULL,
                                            start_time    => NULL,
                                            sub_request   => FALSE,
                                            argument1     => NULL,
                                            argument2     => 'STANDARD',
                                            argument3     => NULL,
                                            argument4     => 'N',
                                            argument5     => NULL,
                                            argument6     => 'APPROVED',
                                            argument7     => NULL,
                                            argument8     => p_batch_id,
                                            argument9     => NULL,
                                            argument10    => NULL,
                                            argument11    => NULL,
                                            argument12    => NULL,
                                            argument13    => NULL);
            COMMIT;

            -------
            IF ln_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to ?'
                    || fnd_message.get
                    || '?.');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'The PO Import Program submitted ? Request id :'
                    || ln_req_id);
            END IF;

            IF ln_req_id > 0
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   '   Waiting for the PO Import Program');

                LOOP
                    lb_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 60,
                            max_wait     => 0,
                            phase        => lc_phase,
                            status       => lc_wait_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);
                    EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                              OR UPPER (lc_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  PO Import Program Request Phase'
                    || '-'
                    || lc_dev_phase);
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  PO Import Program Request Dev status'
                    || '-'
                    || lc_dev_status);

                IF     UPPER (lc_phase) = 'COMPLETED'
                   AND UPPER (lc_wait_status) = 'ERROR'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'The PO Import prog completed in error. See log for request id');
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);
                ELSIF     UPPER (lc_phase) = 'COMPLETED'
                      AND UPPER (lc_wait_status) = 'NORMAL'
                THEN
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                           'The PO Import successfully completed for request id: '
                        || ln_req_id);
                ELSE
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                        'The PO Import request failed.Review log for Oracle request id ');
                    Fnd_File.PUT_LINE (Fnd_File.LOG, SQLERRM);
                END IF;
            END IF;
        END LOOP;


        gc_code_pointer   :=
            'Strated updating Drop ship  sources table with PO info';
        write_log (gc_code_pointer);
        update_drop_ship_prc (p_org_name => p_org_name, p_batch_id => p_batch_id, x_return_mesg => x_return_mesg
                              , x_return_code => x_return_code);

        IF x_return_code = gn_success
        THEN
            gc_code_pointer   := 'PO info updated in Drop ship table';
            write_log (gc_code_pointer);
            gc_code_pointer   := 'Started applying holds on Sales order';
            write_log (gc_code_pointer);

            apply_sales_order_hold (p_org_name => p_org_name, p_batch_id => p_batch_id, x_return_mesg => x_return_mesg
                                    , x_return_code => x_return_code);

            IF x_return_code = gn_success
            THEN
                gc_code_pointer   :=
                    'Completed applying holds on Sales order';
                write_log (gc_code_pointer);
            END IF;
        END IF;
    ------------------------  added in ver 1.2------------------------------
    -- Code for update Sales order status
    ---------------------- end of ver 1.2------------------------------------
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   := 'The procedure PO Import Failed  ' || SQLERRM;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
            RAISE_APPLICATION_ERROR (-20003, SQLERRM);
    END po_import_prc;

    PROCEDURE extract_1206_rcv_data (p_org_name       IN     VARCHAR2,
                                     x_total_rec         OUT NUMBER,
                                     x_validrec_cnt      OUT NUMBER,
                                     x_errbuf            OUT VARCHAR2,
                                     x_retcode           OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30)
                                      := 'EXTRACT_R12_DROP_SHIP_RCV' ;
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_drop_ship_orders IS
            SELECT DISTINCT xods.RECEIPT_SOURCE_CODE, xods.NOTICE_CREATION_DATE, xods.SHIPMENT_NUM,
                            xods.RECEIPT_NUM, xods.VENDOR_NAME, xods.VENDOR_NUMBER,
                            xods.VENDOR_ID, xods.FROM_ORGANIZATION_CODE, --xods.ship_to_org_id    ,
                                                                         xods.BILL_OF_LADING,
                            xods.PACKING_SLIP, xods.SHIPPED_DATE, xods.FREIGHT_CARRIER_CODE,
                            xods.EXPECTED_RECEIPT_DATE, xods.NUM_OF_CONTAINERS, xods.WAYBILL_AIRBILL_NUM,
                            xods.RCV_SHP_COMMENTS, xods.INVOICE_AMOUNT, xods.GROSS_WEIGHT,
                            xods.GROSS_WEIGHT_UOM_CODE, xods.NET_WEIGHT, xods.NET_WEIGHT_UOM_CODE,
                            xods.TAR_WEIGHT, xods.TAR_WEIGHT_UOM_CODE, xods.PACKAGING_CODE,
                            xods.CARRIER_METHOD, xods.CARRIER_EQUIPMENT, xods.SPECIAL_HANDLING_CODE,
                            xods.FREIGHT_TERMS, xods.FREIGHT_BILL_NUMBER, xods.INVOICE_NUM,
                            xods.INVOICE_DATE, xods.TAX_NAME, xods.TAX_AMOUNT,
                            xods.FREIGHT_AMOUNT, xods.CONVERSION_RATE_TYPE, xods.CONVERSION_RATE,
                            xods.PAYMENT_TERMS, xods.RCV_SHIP_ATTRIBUTE_CATEGORY, xods.RCV_SHIP_ATTRIBUTE1,
                            xods.RCV_SHIP_ATTRIBUTE2, xods.RCV_SHIP_ATTRIBUTE3, xods.RCV_SHIP_ATTRIBUTE4,
                            xods.RCV_SHIP_ATTRIBUTE5, xods.RCV_SHIP_ATTRIBUTE6, xods.RCV_SHIP_ATTRIBUTE7,
                            xods.RCV_SHIP_ATTRIBUTE8, xods.RCV_SHIP_ATTRIBUTE9, xods.RCV_SHIP_ATTRIBUTE10,
                            xods.RCV_SHIP_ATTRIBUTE11, xods.RCV_SHIP_ATTRIBUTE12, xods.RCV_SHIP_ATTRIBUTE13,
                            xods.RCV_SHIP_ATTRIBUTE14, xods.RCV_SHIP_ATTRIBUTE15, xods.EMPLOYEE_NAME,
                            xods.INVOICE_STATUS_CODE, xods.SHIP_FROM_LOCATION, xods.OPERATING_UNIT,
                            xods.PO_NUMBER, xods.PO_LINE_NUM, xods.PO_SHIP_NUM,
                            xods.PO_DIST_NUM, xods.SHIPMENT_HEADER_ID, xods.ASN_TYPE,
                            xods.TRANSACTION_TYPE, xods.TRANSACTION_DATE, xods.QUANTITY,
                            xods.UNIT_OF_MEASURE, xods.PO_UNIT_PRICE, xods.UOM_CODE,
                            xods.RT_CURRENCY_CODE, xods.RT_CURRENCY_CONV_TYPE, xods.RT_CURRENCY_CONV_RATE,
                            xods.RT_CURRENCY_CONV_DATE, xods.SUBSTITUTE_UNORDERED_CODE, xods.RECEIPT_EXCEPTION_FLAG,
                            xods.ACCRUAL_STATUS_CODE, xods.INSPECTION_STATUS_CODE, xods.RCV_TRC_COMMENTS,
                            xods.RCV_TRC_ATTRIBUTE_CATEGORY, xods.RCV_TRC_ATTRIBUTE1, xods.RCV_TRC_ATTRIBUTE2,
                            xods.RCV_TRC_ATTRIBUTE3, xods.RCV_TRC_ATTRIBUTE4, xods.RCV_TRC_ATTRIBUTE5,
                            xods.RCV_TRC_ATTRIBUTE6, xods.RCV_TRC_ATTRIBUTE7, xods.RCV_TRC_ATTRIBUTE8,
                            xods.RCV_TRC_ATTRIBUTE9, xods.RCV_TRC_ATTRIBUTE10, xods.RCV_TRC_ATTRIBUTE11,
                            xods.RCV_TRC_ATTRIBUTE12, xods.RCV_TRC_ATTRIBUTE13, xods.RCV_TRC_ATTRIBUTE14,
                            xods.RCV_TRC_ATTRIBUTE15, xods.AMOUNT, xods.INSPECTION_QUALITY_CODE,
                            xods.COUNTRY_OF_ORIGIN_CODE, xods.MOBILE_TXN, xods.SUBINVENTORY,
                            xods.PRIMARY_QUANTITY, xods.DESTINATION_TYPE_CODE, xods.RCV_TRC_VENDOR_ID,
                            xods.RCV_TRC_VENDOR_NAME, xods.RCV_TRC_VENDOR_SITE_CODE, xods.DELIVER_TO_PERSON,
                            xods.QUANTITY_SHIPPED, xods.ITEM_SEGMENT1, xods.RCV_TRC_ORGANIZATION_CODE,
                            xods.INVENTORY_ITEM_ID, xods.PO_HEADER_ID, xods.PO_LINE_ID,
                            xods.SHIPMENT_LINE_ID, xods.DROPSHIP_TYPE_CODE, xods.ORDER_NUMBER,
                            NULL ORIG_SYS_DOCUMENT_REF, NULL ORIG_SYS_LINE_REF, xods.ORDER_ORG_ID,
                            xods.PO_ORG_ID
              FROM XXD_CONV.xxd_1206_oe_drop_ship_rcv xods, po_headers_all poh, po_lines_all pol,
                   po_line_locations_all pll, po_distributions_all pda
             WHERE     1 = 1
                   AND xods.po_number = poh.segment1
                   AND poh.po_header_id = pol.po_header_id
                   AND xods.po_line_num = pol.line_num
                   AND pol.po_line_id = pll.po_line_id
                   AND pol.po_header_id = pll.po_header_id
                   AND pll.line_location_id = pda.line_location_id
                   AND pll.shipment_num = xods.po_ship_num
                   AND pda.DISTRIBUTION_NUM = xods.po_dist_num
                   --   AND xods.ORDER_ORG_ID =ln_org_id
                   /*  and xods.order_number in (50499037,
      50511398,
      50511454,
      50511501,
      50499076,
      50499023,
      50511575);*/
                   AND NOT EXISTS
                           (SELECT rsh.receipt_num
                              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, rcv_transactions rct,
                                   po_headers_all poh, po_lines_all pol
                             WHERE     1 = 1
                                   AND poh.po_header_id = pol.po_header_id
                                   AND poh.po_header_id = rsl.po_header_id
                                   AND rsl.shipment_header_id =
                                       rsh.shipment_header_id
                                   AND rct.po_header_id = poh.po_header_id
                                   AND rct.po_line_id = pol.po_line_id
                                   AND rct.shipment_header_id =
                                       rsh.shipment_header_id
                                   AND rct.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND poh.segment1 = xods.po_number
                                   AND rsh.receipt_num = xods.receipt_num
                                   AND RCT.TRANSACTION_TYPE = 'RECEIVE');

        /* TYPE XXD_ONT_DROP_SHIP_TAB
            IS TABLE OF XXD_CONV.xxd_1206_oe_drop_ship_rcv%ROWTYPE
                  INDEX BY BINARY_INTEGER;*/
        TYPE XXD_ONT_DROP_SHIP_TAB IS TABLE OF lcu_drop_ship_orders%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_drop_ship_tab       XXD_ONT_DROP_SHIP_TAB;
    BEGIN
        lv_error_stage   := 'In Extract procedure of Receipt';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        t_ont_drop_ship_tab.delete;

        /*FOR lc_org
           IN (SELECT lookup_code
                 FROM apps.fnd_lookup_values
                WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                      AND attribute1 = p_org_name
                      AND language = 'US')
        LOOP
           lv_error_stage := 'Loop start ' || lc_org.lookup_code;
           fnd_file.put_line (fnd_file.LOG, lv_error_stage);*/
        OPEN lcu_drop_ship_orders;

        LOOP
            lv_error_stage   :=
                'Inserting Drop ship receipt Data into Staging';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            --lv_error_stage := 'Org Id' || lc_org.lookup_code;
            --fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            t_ont_drop_ship_tab.delete;

            FETCH lcu_drop_ship_orders
                BULK COLLECT INTO t_ont_drop_ship_tab
                LIMIT 5000;

            FORALL l_indx IN 1 .. t_ont_drop_ship_tab.COUNT
                INSERT INTO XXD_DROP_SHIP_RCV_CONV_STG_T (
                                RECORD_ID,
                                RECEIPT_SOURCE_CODE,
                                NOTICE_CREATION_DATE,
                                SHIPMENT_NUM,
                                RECEIPT_NUM,
                                VENDOR_NAME,
                                VENDOR_NUMBER,
                                VENDOR_ID,
                                FROM_ORGANIZATION_CODE,
                                -- SHIP_TO_ORGANIZATION_ID    ,
                                BILL_OF_LADING,
                                PACKING_SLIP,
                                SHIPPED_DATE,
                                FREIGHT_CARRIER_CODE,
                                EXPECTED_RECEIPT_DATE,
                                NUM_OF_CONTAINERS,
                                WAYBILL_AIRBILL_NUM,
                                RCV_SHP_COMMENTS,
                                INVOICE_AMOUNT,
                                GROSS_WEIGHT,
                                GROSS_WEIGHT_UOM_CODE,
                                NET_WEIGHT,
                                NET_WEIGHT_UOM_CODE,
                                TAR_WEIGHT,
                                TAR_WEIGHT_UOM_CODE,
                                PACKAGING_CODE,
                                CARRIER_METHOD,
                                CARRIER_EQUIPMENT,
                                SPECIAL_HANDLING_CODE,
                                FREIGHT_TERMS,
                                FREIGHT_BILL_NUMBER,
                                INVOICE_NUM,
                                INVOICE_DATE,
                                TAX_NAME,
                                TAX_AMOUNT,
                                FREIGHT_AMOUNT,
                                CONVERSION_RATE_TYPE,
                                CONVERSION_RATE,
                                PAYMENT_TERMS,
                                RCV_SHIP_ATTRIBUTE_CATEGORY,
                                RCV_SHIP_ATTRIBUTE1,
                                RCV_SHIP_ATTRIBUTE2,
                                RCV_SHIP_ATTRIBUTE3,
                                RCV_SHIP_ATTRIBUTE4,
                                RCV_SHIP_ATTRIBUTE5,
                                RCV_SHIP_ATTRIBUTE6,
                                RCV_SHIP_ATTRIBUTE7,
                                RCV_SHIP_ATTRIBUTE8,
                                RCV_SHIP_ATTRIBUTE9,
                                RCV_SHIP_ATTRIBUTE10,
                                RCV_SHIP_ATTRIBUTE11,
                                RCV_SHIP_ATTRIBUTE12,
                                RCV_SHIP_ATTRIBUTE13,
                                RCV_SHIP_ATTRIBUTE14,
                                RCV_SHIP_ATTRIBUTE15,
                                EMPLOYEE_NAME,
                                INVOICE_STATUS_CODE,
                                SHIP_FROM_LOCATION,
                                OPERATING_UNIT,
                                PO_NUMBER,
                                PO_LINE_NUM,
                                PO_SHIP_NUM,
                                PO_DIST_NUM,
                                SHIPMENT_HEADER_ID,
                                ASN_TYPE,
                                TRANSACTION_TYPE,
                                TRANSACTION_DATE,
                                QUANTITY,
                                UNIT_OF_MEASURE,
                                PO_UNIT_PRICE,
                                UOM_CODE,
                                RT_CURRENCY_CODE,
                                RT_CURRENCY_CONV_TYPE,
                                RT_CURRENCY_CONV_RATE,
                                RT_CURRENCY_CONV_DATE,
                                SUBSTITUTE_UNORDERED_CODE,
                                RECEIPT_EXCEPTION_FLAG,
                                ACCRUAL_STATUS_CODE,
                                INSPECTION_STATUS_CODE,
                                RCV_TRC_COMMENTS,
                                RCV_TRC_ATTRIBUTE_CATEGORY,
                                RCV_TRC_ATTRIBUTE1,
                                RCV_TRC_ATTRIBUTE2,
                                RCV_TRC_ATTRIBUTE3,
                                RCV_TRC_ATTRIBUTE4,
                                RCV_TRC_ATTRIBUTE5,
                                RCV_TRC_ATTRIBUTE6,
                                RCV_TRC_ATTRIBUTE7,
                                RCV_TRC_ATTRIBUTE8,
                                RCV_TRC_ATTRIBUTE9,
                                RCV_TRC_ATTRIBUTE10,
                                RCV_TRC_ATTRIBUTE11,
                                RCV_TRC_ATTRIBUTE12,
                                RCV_TRC_ATTRIBUTE13,
                                RCV_TRC_ATTRIBUTE14,
                                RCV_TRC_ATTRIBUTE15,
                                AMOUNT,
                                INSPECTION_QUALITY_CODE,
                                COUNTRY_OF_ORIGIN_CODE,
                                MOBILE_TXN,
                                SUBINVENTORY,
                                PRIMARY_QUANTITY,
                                DESTINATION_TYPE_CODE,
                                RCV_TRC_VENDOR_ID,
                                RCV_TRC_VENDOR_NAME,
                                RCV_TRC_VENDOR_SITE_CODE,
                                DELIVER_TO_PERSON,
                                QUANTITY_SHIPPED,
                                ITEM_SEGMENT1,
                                RCV_TRC_ORGANIZATION_CODE,
                                INVENTORY_ITEM_ID,
                                PO_HEADER_ID,
                                PO_LINE_ID,
                                SHIPMENT_LINE_ID,
                                DROPSHIP_TYPE_CODE,
                                ORDER_NUMBER,
                                ORIG_SYS_DOCUMENT_REF,
                                ORIG_SYS_LINE_REF,
                                ORDER_ORG_ID,
                                PO_ORG_ID,
                                RECORD_STATUS,
                                ERROR_MESSAGE,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY,
                                LAST_UPDATED_LOGIN,
                                CREATION_DATE,
                                CREATED_BY,
                                REQUEST_ID,
                                new_po_header_id,
                                new_po_line_id)
                     VALUES (XXD_ONT_DROP_SHIP_CONV_STG_S.NEXTVAL, t_ont_drop_ship_tab (l_indx).RECEIPT_SOURCE_CODE, t_ont_drop_ship_tab (l_indx).NOTICE_CREATION_DATE, t_ont_drop_ship_tab (l_indx).SHIPMENT_NUM, t_ont_drop_ship_tab (l_indx).RECEIPT_NUM, t_ont_drop_ship_tab (l_indx).VENDOR_NAME, t_ont_drop_ship_tab (l_indx).VENDOR_NUMBER, t_ont_drop_ship_tab (l_indx).VENDOR_ID, t_ont_drop_ship_tab (l_indx).FROM_ORGANIZATION_CODE, --t_ont_drop_ship_tab (l_indx).ship_to_org_id    ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                t_ont_drop_ship_tab (l_indx).BILL_OF_LADING, t_ont_drop_ship_tab (l_indx).PACKING_SLIP, t_ont_drop_ship_tab (l_indx).SHIPPED_DATE, t_ont_drop_ship_tab (l_indx).FREIGHT_CARRIER_CODE, t_ont_drop_ship_tab (l_indx).EXPECTED_RECEIPT_DATE, t_ont_drop_ship_tab (l_indx).NUM_OF_CONTAINERS, t_ont_drop_ship_tab (l_indx).WAYBILL_AIRBILL_NUM, t_ont_drop_ship_tab (l_indx).RCV_SHP_COMMENTS, t_ont_drop_ship_tab (l_indx).INVOICE_AMOUNT, t_ont_drop_ship_tab (l_indx).GROSS_WEIGHT, t_ont_drop_ship_tab (l_indx).GROSS_WEIGHT_UOM_CODE, t_ont_drop_ship_tab (l_indx).NET_WEIGHT, t_ont_drop_ship_tab (l_indx).NET_WEIGHT_UOM_CODE, t_ont_drop_ship_tab (l_indx).TAR_WEIGHT, t_ont_drop_ship_tab (l_indx).TAR_WEIGHT_UOM_CODE, t_ont_drop_ship_tab (l_indx).PACKAGING_CODE, t_ont_drop_ship_tab (l_indx).CARRIER_METHOD, t_ont_drop_ship_tab (l_indx).CARRIER_EQUIPMENT, t_ont_drop_ship_tab (l_indx).SPECIAL_HANDLING_CODE, t_ont_drop_ship_tab (l_indx).FREIGHT_TERMS, t_ont_drop_ship_tab (l_indx).FREIGHT_BILL_NUMBER, t_ont_drop_ship_tab (l_indx).INVOICE_NUM, t_ont_drop_ship_tab (l_indx).INVOICE_DATE, t_ont_drop_ship_tab (l_indx).TAX_NAME, t_ont_drop_ship_tab (l_indx).TAX_AMOUNT, t_ont_drop_ship_tab (l_indx).FREIGHT_AMOUNT, t_ont_drop_ship_tab (l_indx).CONVERSION_RATE_TYPE, t_ont_drop_ship_tab (l_indx).CONVERSION_RATE, t_ont_drop_ship_tab (l_indx).PAYMENT_TERMS, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE_CATEGORY, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE1, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE2, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE3, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE4, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE5, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE6, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE7, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE8, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE9, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE10, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE11, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE12, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE13, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE14, t_ont_drop_ship_tab (l_indx).RCV_SHIP_ATTRIBUTE15, t_ont_drop_ship_tab (l_indx).EMPLOYEE_NAME, t_ont_drop_ship_tab (l_indx).INVOICE_STATUS_CODE, t_ont_drop_ship_tab (l_indx).SHIP_FROM_LOCATION, t_ont_drop_ship_tab (l_indx).OPERATING_UNIT, t_ont_drop_ship_tab (l_indx).PO_NUMBER, t_ont_drop_ship_tab (l_indx).PO_LINE_NUM, t_ont_drop_ship_tab (l_indx).PO_SHIP_NUM, t_ont_drop_ship_tab (l_indx).PO_DIST_NUM, t_ont_drop_ship_tab (l_indx).SHIPMENT_HEADER_ID, t_ont_drop_ship_tab (l_indx).ASN_TYPE, t_ont_drop_ship_tab (l_indx).TRANSACTION_TYPE, t_ont_drop_ship_tab (l_indx).TRANSACTION_DATE, t_ont_drop_ship_tab (l_indx).QUANTITY, t_ont_drop_ship_tab (l_indx).UNIT_OF_MEASURE, t_ont_drop_ship_tab (l_indx).PO_UNIT_PRICE, t_ont_drop_ship_tab (l_indx).UOM_CODE, t_ont_drop_ship_tab (l_indx).RT_CURRENCY_CODE, t_ont_drop_ship_tab (l_indx).RT_CURRENCY_CONV_TYPE, t_ont_drop_ship_tab (l_indx).RT_CURRENCY_CONV_RATE, t_ont_drop_ship_tab (l_indx).RT_CURRENCY_CONV_DATE, t_ont_drop_ship_tab (l_indx).SUBSTITUTE_UNORDERED_CODE, t_ont_drop_ship_tab (l_indx).RECEIPT_EXCEPTION_FLAG, t_ont_drop_ship_tab (l_indx).ACCRUAL_STATUS_CODE, t_ont_drop_ship_tab (l_indx).INSPECTION_STATUS_CODE, t_ont_drop_ship_tab (l_indx).RCV_TRC_COMMENTS, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE_CATEGORY, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE1, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE2, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE3, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE4, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE5, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE6, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE7, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE8, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE9, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE10, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE11, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE12, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE13, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE14, t_ont_drop_ship_tab (l_indx).RCV_TRC_ATTRIBUTE15, t_ont_drop_ship_tab (l_indx).AMOUNT, t_ont_drop_ship_tab (l_indx).INSPECTION_QUALITY_CODE, t_ont_drop_ship_tab (l_indx).COUNTRY_OF_ORIGIN_CODE, t_ont_drop_ship_tab (l_indx).MOBILE_TXN, t_ont_drop_ship_tab (l_indx).SUBINVENTORY, t_ont_drop_ship_tab (l_indx).PRIMARY_QUANTITY, t_ont_drop_ship_tab (l_indx).DESTINATION_TYPE_CODE, t_ont_drop_ship_tab (l_indx).RCV_TRC_VENDOR_ID, t_ont_drop_ship_tab (l_indx).RCV_TRC_VENDOR_NAME, t_ont_drop_ship_tab (l_indx).RCV_TRC_VENDOR_SITE_CODE, t_ont_drop_ship_tab (l_indx).DELIVER_TO_PERSON, t_ont_drop_ship_tab (l_indx).QUANTITY_SHIPPED, t_ont_drop_ship_tab (l_indx).ITEM_SEGMENT1, t_ont_drop_ship_tab (l_indx).RCV_TRC_ORGANIZATION_CODE, t_ont_drop_ship_tab (l_indx).INVENTORY_ITEM_ID, t_ont_drop_ship_tab (l_indx).PO_HEADER_ID, t_ont_drop_ship_tab (l_indx).PO_LINE_ID, t_ont_drop_ship_tab (l_indx).SHIPMENT_LINE_ID, t_ont_drop_ship_tab (l_indx).DROPSHIP_TYPE_CODE, t_ont_drop_ship_tab (l_indx).ORDER_NUMBER, t_ont_drop_ship_tab (l_indx).ORIG_SYS_DOCUMENT_REF, t_ont_drop_ship_tab (l_indx).ORIG_SYS_LINE_REF, t_ont_drop_ship_tab (l_indx).ORDER_ORG_ID, t_ont_drop_ship_tab (l_indx).PO_ORG_ID, 'N', NULL, SYSDATE, gn_user_id, gn_user_id, SYSDATE, gn_user_id
                             , gn_conc_request_id, NULL, NULL);

            COMMIT;
            EXIT WHEN lcu_drop_ship_orders%NOTFOUND;
        END LOOP;

        CLOSE lcu_drop_ship_orders;

        -- END LOOP;
        COMMIT;
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
    END extract_1206_rcv_data;

    PROCEDURE validate_rcv_data (p_org_name IN VARCHAR2, p_batch_id NUMBER, x_errbuf OUT VARCHAR2
                                 , x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'VALIDATE_PO_R12';
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR get_po_ifo_c (p_po_header_id   NUMBER,
                             p_po_line_id     NUMBER,
                             p_po_loc_id      NUMBER)
        IS
            SELECT DISTINCT plli.line_location_id
              FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, po_line_locations_all PLLI,
                   PO_LINES_ALL PLI, po_headers_all poh, OE_DROP_SHIP_SOURCES OEDSS
             WHERE     1 = 1
                   AND poh.po_header_id = p_po_header_id
                   AND PORH.REQUISITION_HEADER_ID =
                       PORL.REQUISITION_HEADER_ID
                   AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
                   AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
                   AND PLLI.po_line_id = PLI.po_line_id
                   AND pli.po_line_id = p_po_line_id
                   AND PLI.po_header_id = poh.po_header_id
                   AND plli.line_location_id = p_po_loc_id
                   AND oedss.po_header_id IS NOT NULL;

        CURSOR lcu_rcv_details IS
            SELECT ROWID, dss.*
              FROM XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T dss
             WHERE                              --dss.Order_org_id = ln_org_id
                   record_status = gc_new_status AND batch_id = p_batch_id;

        TYPE XXD_ONT_TRC_LINES_TAB IS TABLE OF lcu_rcv_details%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lcu_trc_lines_REC         XXD_ONT_TRC_LINES_TAB;
        lc_rcv_val_error_mesg     VARCHAR2 (4000);
        ln_loc_id                 NUMBER;
    BEGIN
        lv_error_stage   := 'In Validate procedure of Receipts';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
        lcu_trc_lines_REC.delete;

        /* FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
         LOOP
            lv_error_stage := 'Loop start ' || lc_org.lookup_code;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);*/
        OPEN lcu_rcv_details;

        LOOP
            lv_error_stage   :=
                'Validating Drop ship Receipt Data in Staging';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            --lv_error_stage := 'Org Id' || lc_org.lookup_code;
            --fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            lcu_trc_lines_REC.delete;

            FETCH lcu_rcv_details
                BULK COLLECT INTO lcu_trc_lines_REC
                LIMIT 5000;

            FOR l_indx IN 1 .. lcu_trc_lines_REC.COUNT
            LOOP
                lc_rcv_val_error_mesg   := NULL;
                gc_code_pointer         :=
                    'Validating ship_to_organization_id';
                lcu_trc_lines_REC (l_indx).ship_to_organization_id   :=
                    get_inv_org_id (
                        lcu_trc_lines_REC (l_indx).ship_to_organization_id);

                IF lcu_trc_lines_REC (l_indx).ship_to_organization_id = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid ship_to_organization_id ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                /*    lcu_trc_lines_REC (l_indx).employee_id := -- get_agnet_id (                                     comments in ver 1.1
                                                             get_person_id (
                                                                 lcu_trc_lines_REC (
                                                                    l_indx).employee_name);
                     IF lcu_trc_lines_REC (l_indx).employee_id = -1
                    THEN
                       lc_rcv_val_error_mesg :=    lc_rcv_val_error_mesg
                                               || '/'
                                               || 'Invalid employee_id ';
                      --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                    END IF;
                    */
                gc_code_pointer         :=
                    'Validating VENDOR_id';
                lcu_trc_lines_REC (l_indx).VENDOR_id   :=
                    get_vendor_id (lcu_trc_lines_REC (l_indx).VENDOR_NAME);

                IF lcu_trc_lines_REC (l_indx).VENDOR_id = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                        lc_rcv_val_error_mesg || '/' || 'Invalid VENDOR_id ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating operating_unit';
                lcu_trc_lines_REC (l_indx).operating_unit   :=
                    get_new_ou_name (lcu_trc_lines_REC (l_indx).PO_ORG_ID);

                IF lcu_trc_lines_REC (l_indx).operating_unit IS NULL
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid operating_unit ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating PO_ORG_ID';
                lcu_trc_lines_REC (l_indx).PO_ORG_ID   :=
                    get_org_id (lcu_trc_lines_REC (l_indx).PO_ORG_ID);

                -- lines information
                IF lcu_trc_lines_REC (l_indx).PO_ORG_ID = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                        lc_rcv_val_error_mesg || '/' || 'Invalid PO_ORG_ID ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating new_po_header_id';
                lcu_trc_lines_REC (l_indx).new_po_header_id   :=
                    get_rcv_po_header_id (
                        lcu_trc_lines_REC (l_indx).po_number);

                IF lcu_trc_lines_REC (l_indx).new_po_header_id = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid new_po_header_id ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating new_po_line_id';
                lcu_trc_lines_REC (l_indx).new_po_line_id   :=
                    get_rcv_po_line_id (
                        lcu_trc_lines_REC (l_indx).new_po_header_id,
                        lcu_trc_lines_REC (l_indx).PO_LINE_NUM);

                IF lcu_trc_lines_REC (l_indx).new_po_line_id = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid new_po_line_id ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating INVENTORY_ITEM_ID';
                lcu_trc_lines_REC (l_indx).INVENTORY_ITEM_ID   :=
                    GET_ITEM_ID (lcu_trc_lines_REC (l_indx).ITEM_SEGMENT1,
                                 lcu_trc_lines_REC (l_indx).Order_org_id);

                IF lcu_trc_lines_REC (l_indx).INVENTORY_ITEM_ID = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid INVENTORY_ITEM_ID ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating new_po_line_location_id';
                lcu_trc_lines_REC (l_indx).new_po_line_location_id   :=
                    get_rcv_po_lloc_id (
                        lcu_trc_lines_REC (l_indx).new_po_header_id,
                        lcu_trc_lines_REC (l_indx).new_po_line_id,
                        lcu_trc_lines_REC (l_indx).po_ship_num);

                IF lcu_trc_lines_REC (l_indx).new_po_line_location_id = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid new_po_line_location_id ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating NEW_PO_DISTRIBUTION_ID';
                lcu_trc_lines_REC (l_indx).NEW_PO_DISTRIBUTION_ID   :=
                    get_rcv_po_ldist_id (
                        lcu_trc_lines_REC (l_indx).new_po_header_id,
                        lcu_trc_lines_REC (l_indx).new_po_line_id,
                        lcu_trc_lines_REC (l_indx).new_po_line_location_id,
                        lcu_trc_lines_REC (l_indx).po_dist_num);

                IF lcu_trc_lines_REC (l_indx).NEW_PO_DISTRIBUTION_ID = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid NEW_PO_DISTRIBUTION_ID ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Validating DELIVER_TO_PERSON_id';
                lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON_id   := -- get_agent_id                                     --  updated in ver 1.1
                    get_person_id (
                        lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON);

                IF lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON_id = -1
                THEN
                    lc_rcv_val_error_mesg   :=
                           lc_rcv_val_error_mesg
                        || '/'
                        || 'Invalid DELIVER_TO_PERSON_id ';
                --   write_log ('Error in PO validate Procedure : '||lc_po_val_error_mesg );
                END IF;

                gc_code_pointer         :=
                    'Verifying if PO info updated in oe_drop_Ship_sources';

                -- write_log (gc_code_pointer);
                IF lcu_trc_lines_REC (l_indx).new_po_line_location_id <> -1
                THEN
                    ln_loc_id   := NULL;

                    OPEN get_po_ifo_c (
                        lcu_trc_lines_REC (l_indx).new_po_header_id,
                        lcu_trc_lines_REC (l_indx).new_po_line_id,
                        lcu_trc_lines_REC (l_indx).new_po_line_location_id);

                    FETCH get_po_ifo_c INTO ln_loc_id;

                    IF get_po_ifo_c%NOTFOUND
                    THEN
                        ln_loc_id   := -1;
                        lc_rcv_val_error_mesg   :=
                               lc_rcv_val_error_mesg
                            || '/'
                            || 'PO info missing in oe_drop_Ship_sources ';
                    END IF;

                    CLOSE get_po_ifo_c;
                END IF;

                IF     lcu_trc_lines_REC (l_indx).VENDOR_id <> -1
                   AND lcu_trc_lines_REC (l_indx).new_po_header_id <> -1
                   AND lcu_trc_lines_REC (l_indx).new_po_line_id <> -1
                   AND lcu_trc_lines_REC (l_indx).INVENTORY_ITEM_ID <> -1
                   AND lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON_id <> -1
                   AND lcu_trc_lines_REC (l_indx).new_po_line_location_id <>
                       -1
                   AND lcu_trc_lines_REC (l_indx).NEW_PO_DISTRIBUTION_ID <>
                       -1
                   AND ln_loc_id <> -1
                THEN
                    UPDATE XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T
                       SET record_status = gc_validate_status, ship_to_organization_id = lcu_trc_lines_REC (l_indx).ship_to_organization_id, --    employee_id = lcu_trc_lines_REC (l_indx).employee_id,
                                                                                                                                             VENDOR_id = lcu_trc_lines_REC (l_indx).VENDOR_id,
                           operating_unit = lcu_trc_lines_REC (l_indx).operating_unit, TGT_PO_ORG_ID = lcu_trc_lines_REC (l_indx).PO_ORG_ID, new_po_header_id = lcu_trc_lines_REC (l_indx).new_po_header_id,
                           new_po_line_id = lcu_trc_lines_REC (l_indx).new_po_line_id, INVENTORY_ITEM_ID = lcu_trc_lines_REC (l_indx).INVENTORY_ITEM_ID, new_po_line_location_id = lcu_trc_lines_REC (l_indx).new_po_line_location_id,
                           NEW_PO_DISTRIBUTION_ID = lcu_trc_lines_REC (l_indx).NEW_PO_DISTRIBUTION_ID, DELIVER_TO_PERSON_id = lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON_id
                     WHERE 1 = 1 AND ROWID = lcu_trc_lines_REC (l_indx).ROWID;
                ELSE
                    UPDATE XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T
                       SET record_status = gc_error_status, error_message = SUBSTR (lc_rcv_val_error_mesg, 1, 100), /*
                                                                                                                    DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).employee_id,
                                                                                                                          -1, 'Invalid Agent Name ',
                                                                                                                          '')
                                                                                                                    || DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).VENDOR_id,
                                                                                                                          -1, 'Invalid Vendor Name',
                                                                                                                          '')
                                                                                                                    --  ||decode(lcu_trc_lines_REC(l_indx).new_po_header_id    , -1,'Invalid Vendor Name','')
                                                                                                                    || DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).operating_unit,
                                                                                                                          -1, 'Invalid Vendor Name',
                                                                                                                          '')
                                                                                                                    || DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).ship_to_organization_id,
                                                                                                                          -1, 'Invalid Ship to Organization',
                                                                                                                          '')
                                                                                                                    || DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).PO_ORG_ID,
                                                                                                                          -1, 'Invalid PO Org Id',
                                                                                                                          '')
                                                                                                                    --  ||decode(lcu_trc_lines_REC(l_indx).new_po_line_id    , -1,'Invalid Vendor Name','')
                                                                                                                    || DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).INVENTORY_ITEM_ID,
                                                                                                                          -1, 'Invalid Item ',
                                                                                                                          '')
                                                                                                                    --    ||decode(lcu_trc_lines_REC(l_indx).new_po_line_location_id    , -1,'Invalid Po LIne Locations','')
                                                                                                                    --          ||decode(lcu_trc_lines_REC(l_indx).NEW_PO_DISTRIBUTION_ID     , -1,'Invalid PO Distribution line','')
                                                                                                                    || DECODE (
                                                                                                                          lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON_id,
                                                                                                                          -1, 'Invalid deliver to Person',
                                                                                                                          ''), */
                                                                                                                    ship_to_organization_id = lcu_trc_lines_REC (l_indx).ship_to_organization_id,
                           employee_id = lcu_trc_lines_REC (l_indx).employee_id, VENDOR_id = lcu_trc_lines_REC (l_indx).VENDOR_id, operating_unit = lcu_trc_lines_REC (l_indx).operating_unit,
                           TGT_PO_ORG_ID = lcu_trc_lines_REC (l_indx).PO_ORG_ID, new_po_header_id = lcu_trc_lines_REC (l_indx).new_po_header_id, new_po_line_id = lcu_trc_lines_REC (l_indx).new_po_line_id,
                           INVENTORY_ITEM_ID = lcu_trc_lines_REC (l_indx).INVENTORY_ITEM_ID, new_po_line_location_id = lcu_trc_lines_REC (l_indx).new_po_line_location_id, NEW_PO_DISTRIBUTION_ID = lcu_trc_lines_REC (l_indx).NEW_PO_DISTRIBUTION_ID,
                           DELIVER_TO_PERSON_id = lcu_trc_lines_REC (l_indx).DELIVER_TO_PERSON_id
                     WHERE     record_status = GC_NEW
                           AND ROWID = lcu_trc_lines_REC (l_indx).ROWID;
                END IF;

                COMMIT;
            END LOOP;

            EXIT WHEN lcu_rcv_details%NOTFOUND;
        END LOOP;

        CLOSE lcu_rcv_details;

        --  END LOOP;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error validating record In Receipt'
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG,
                               'Error at stage : ' || gc_code_pointer);
    END validate_rcv_data;

    PROCEDURE rcv_interface_insert (p_org_name IN VARCHAR2, p_batch_id NUMBER, x_errbuf OUT VARCHAR2
                                    , x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (50) := 'RECEIPT INTERFACE INSERT';
        lv_error_stage            VARCHAR2 (4000) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;
        l_err_msg                 VARCHAR2 (4000);
        l_group_id                NUMBER;

        /*  CURSOR lcu_po_details (ln_org_id NUMBER)
          IS
             SELECT dss.*
               FROM XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T dss
              WHERE dss.Order_org_id = ln_org_id;*/
        CURSOR lcu_ship_header_id IS
            SELECT DISTINCT dss.SHIPMENT_HEADER_ID
              FROM XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T dss
             WHERE batch_id = p_batch_id;

        CURSOR lcu_trc_lines (ln_SHIPMENT_HEADER_ID VARCHAR2)
        IS
            SELECT ROWID, dss.*
              FROM XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T dss
             WHERE     dss.SHIPMENT_HEADER_ID = ln_SHIPMENT_HEADER_ID
                   AND record_status = gc_validate_status
                   AND batch_id = p_batch_id;

        /* CURSOR cur_stg_update
     IS
           SELECT ROWID, a.*
          FROM XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T a
         WHERE record_status = GC_NEW;*/
        --   AND record_status = gc_validate_status;
        --  TYPE XXD_ONT_PO_DETAILS_TAB IS TABLE OF lcu_po_details%ROWTYPE
        --                                  INDEX BY BINARY_INTEGER;
        lcu_ship_header_REC       lcu_ship_header_id%ROWTYPE;
        lcu_trc_lines_REC         lcu_trc_lines%ROWTYPE;
        --   t_ont_po_details_tab      XXD_ONT_PO_DETAILS_TAB;
        L_COUNT                   NUMBER := 0;
    BEGIN
        lv_error_stage   :=
            'In data into receiving interface table procedure';
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);

        -- t_ont_po_details_tab.delete;
        /*FOR lc_org
           IN (SELECT lookup_code
                 FROM apps.fnd_lookup_values
                WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                      AND attribute1 = p_org_name
                      AND language = 'US')
        LOOP
           lv_error_stage := 'Inserting Data into receiving Interface table';
           fnd_file.put_line (fnd_file.LOG, lv_error_stage);
           lv_error_stage := 'Org Id' || lc_org.lookup_code;
           fnd_file.put_line (fnd_file.LOG, lv_error_stage);*/
        OPEN lcu_ship_header_id;

        LOOP
            l_count   := 1;

            FETCH lcu_ship_header_id INTO lcu_ship_header_REC;

            EXIT WHEN lcu_ship_header_id%NOTFOUND;

            OPEN lcu_trc_lines (lcu_ship_header_REC.SHIPMENT_HEADER_ID);

            LOOP
                FETCH lcu_trc_lines INTO lcu_trc_lines_REC;

                EXIT WHEN lcu_trc_lines%NOTFOUND;

                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           ' lcu_trc_lines_REC.ship_to_organization_id  '
                        || lcu_trc_lines_REC.ship_to_organization_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'INserting PO header '
                        || lcu_ship_header_REC.SHIPMENT_HEADER_ID
                        || 'l_count '
                        || l_count);

                    IF l_count = 1
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'INserting  header ' || lcu_ship_header_REC.SHIPMENT_HEADER_ID);
                        l_group_id   := get_group_id ();
                        fnd_file.put_line (fnd_file.LOG,
                                           ' l_group_id' || l_group_id);

                        BEGIN
                            INSERT INTO rcv_headers_interface (
                                            header_interface_id,
                                            GROUP_ID,
                                            processing_status_code,
                                            receipt_source_code,
                                            transaction_type,
                                            notice_creation_date,
                                            shipment_num,
                                            receipt_num,
                                            vendor_id,
                                            ship_to_organization_id,
                                            shipped_date,
                                            freight_carrier_code,
                                            expected_receipt_date,
                                            -- receiver_id,
                                            -- num_of_containers,
                                            waybill_airbill_num,
                                            comments,
                                            gross_weight,
                                            gross_weight_uom_code,
                                            net_weight,
                                            net_weight_uom_code,
                                            tar_weight,
                                            tar_weight_uom_code,
                                            packaging_code,
                                            carrier_method,
                                            carrier_equipment,
                                            special_handling_code,
                                            freight_terms,
                                            freight_bill_number,
                                            invoice_num,
                                            invoice_date,
                                            --  total_invoice_amount,
                                            tax_name,
                                            tax_amount,
                                            freight_amount,
                                            --  currency_code,
                                            conversion_rate_type,
                                            conversion_rate,
                                            --     conversion_rate_date,
                                            payment_terms_name,
                                            attribute_category,
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
                                            -- employee_name
                                            --   employee_id,
                                            VALIDATION_FLAG,
                                            created_by,
                                            last_updated_by,
                                            creation_date,
                                            last_update_date,
                                            last_update_login,
                                            --    invoice_status_code,
                                            --   processing_request_id,
                                            --   customer_account_number
                                            -- customer_id,
                                            -- customer_site_id,
                                            --         customer_party_name
                                            -- operating_unit
                                            org_id,
                                            AUTO_TRANSACT_CODE,
                                            operating_unit)
                                     VALUES (
                                                RCV_HEADERS_INTERFACE_S.NEXTVAL,
                                                lcu_trc_lines_REC.BATCH_ID, --l_group_id, --RCV_INTERFACE_GROUPS_S.NEXTVAL,
                                                'PENDING',
                                                'VENDOR',
                                                'NEW',
                                                lcu_trc_lines_REC.NOTICE_CREATION_DATE,
                                                lcu_trc_lines_REC.SHIPMENT_NUM,
                                                lcu_trc_lines_REC.RECEIPT_NUM,
                                                lcu_trc_lines_REC.VENDOR_id,
                                                -- lcu_trc_lines_REC.vendor_site_code,
                                                --  lcu_trc_lines_REC.from_organization_code,
                                                lcu_trc_lines_REC.ship_to_organization_id,
                                                --  ship_to_organization_id,
                                                lcu_trc_lines_REC.shipped_date,
                                                lcu_trc_lines_REC.freight_carrier_code,
                                                lcu_trc_lines_REC.expected_receipt_date,
                                                lcu_trc_lines_REC.waybill_airbill_num,
                                                lcu_trc_lines_REC.RCV_SHP_COMMENTS,
                                                lcu_trc_lines_REC.gross_weight,
                                                lcu_trc_lines_REC.gross_weight_uom_code,
                                                lcu_trc_lines_REC.net_weight,
                                                lcu_trc_lines_REC.net_weight_uom_code,
                                                lcu_trc_lines_REC.tar_weight,
                                                lcu_trc_lines_REC.tar_weight_uom_code,
                                                lcu_trc_lines_REC.packaging_code,
                                                lcu_trc_lines_REC.carrier_method,
                                                lcu_trc_lines_REC.carrier_equipment,
                                                lcu_trc_lines_REC.special_handling_code,
                                                lcu_trc_lines_REC.freight_terms,
                                                lcu_trc_lines_REC.freight_bill_number,
                                                lcu_trc_lines_REC.invoice_num,
                                                lcu_trc_lines_REC.invoice_date,
                                                --      lcu_trc_lines_REC.total_invoice_amount,
                                                lcu_trc_lines_REC.tax_name,
                                                lcu_trc_lines_REC.tax_amount,
                                                lcu_trc_lines_REC.freight_amount,
                                                --  lcu_trc_lines_REC.currency_code,
                                                lcu_trc_lines_REC.conversion_rate_type,
                                                lcu_trc_lines_REC.conversion_rate,
                                                --  lcu_trc_lines_REC.conversion_rate_date,
                                                lcu_trc_lines_REC.payment_terms,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute_category,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute1,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute2,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute3,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute4,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute5,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute6,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute7,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute8,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute9,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute10,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute11,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute12,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute13,
                                                lcu_trc_lines_REC.RCV_SHIP_attribute14,
                                                TRUNC (SYSDATE), -- lcu_trc_lines_REC.RCV_SHIP_attribute15,
                                                --   lcu_trc_lines_REC.employee_id,
                                                'Y',
                                                gn_user_id,
                                                gn_user_id,
                                                gd_sys_date,
                                                gd_sys_date,
                                                gn_user_id,
                                                lcu_trc_lines_REC.TGT_PO_ORG_ID,
                                                'DELIVER',
                                                lcu_trc_lines_REC.operating_unit --  employee_name,
                                                                                --  lcu_trc_lines_REC.invoice_status_code,
                                                                                --  lcu_trc_lines_REC.processing_request_id,
                                                                                -- lcu_trc_lines_REC.customer_account_number
                                                                                -- customer_id,
                                                                                -- customer_site_id,
                                                                                --  lcu_trc_lines_REC.customer_party_name
                                                                                );
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_err_msg   := SQLERRM;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'error during header insetr '
                                    || l_err_msg);
                        END;

                        COMMIT;
                        fnd_file.put_line (fnd_file.LOG,
                                           'INserting  header successful ');
                        L_COUNT      := L_COUNT + 1;
                    END IF;

                    INSERT INTO RCV_TRANSACTIONS_INTERFACE (
                                    interface_transaction_id,
                                    GROUP_ID,
                                    transaction_type,
                                    processing_status_code,
                                    processing_mode_code,
                                    transaction_status_code,
                                    --  packing_slip,
                                    transaction_date,
                                    quantity,
                                    unit_of_measure,
                                    --   uom_code,
                                    po_header_id,
                                    po_line_id,
                                    item_id,
                                    --  item_description,
                                    vendor_id,
                                    --    interface_source_code,
                                    --     auto_transact_code,
                                    --    receipt_source_code,
                                    --   source_document_code,
                                    validation_flag,
                                    header_interface_id,
                                    po_line_location_id,
                                    -- to_organization_id,
                                    po_distribution_id,
                                    -- charge_account_id,
                                    -- vendor_site_id,
                                    destination_type_code,
                                    last_updated_by,
                                    created_by,
                                    creation_date,
                                    last_update_date,
                                    last_update_login,
                                    -- deliver_to_location_id,
                                    --   locator_id,
                                    -- document_num,
                                    -- document_line_num,
                                    --   subinventory,
                                    --    location_id,
                                    employee_id,
                                    --       ship_to_location_id,
                                    --      ship_to_location_code,
                                    deliver_to_person_id,
                                    --      operating_unit,
                                    --  lpn_group_id,
                                    --   transfer_license_plate_number
                                    --      org_id,
                                    currency_code,
                                    --   deliver_to_person_name,                     --,
                                    -- document_line_num,
                                    --       subinventory,
                                    attribute_category,
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
                                    ship_line_attribute15,
                                    org_id,
                                    SUBINVENTORY)
                             --unit_price)
                             VALUES (
                                        rcv_transactions_interface_s.NEXTVAL,
                                        lcu_trc_lines_REC.BATCH_ID, --l_group_id,
                                        gc_transaction_t_type, -- commented for ASN
                                        gc_processing_status_code,
                                        gc_processing_mode_code,
                                        'PENDING', -- gc_transaction_status_code,
                                        --    lcu_po_lines_rec.packing_slip,
                                        '31-MAR-2016',          --gd_sys_date,
                                        -- lcu_trc_lines_REC.transaction_date,
                                        -- lt_rcv_trx_stg_tbl (line_v).transaction_date,
                                        lcu_trc_lines_REC.quantity,
                                        lcu_trc_lines_REC.unit_of_measure,
                                        --      lcu_po_lines_rec.uom_code,
                                        lcu_trc_lines_REC.new_po_header_id,
                                        lcu_trc_lines_REC.new_po_line_id,
                                        NULL, -- lcu_trc_lines_REC.INVENTORY_ITEM_ID,                         commnected in ver 1.1
                                        lcu_trc_lines_REC.VENDOR_id,
                                        --  lt_rcv_trx_stg_tbl (line_v).item_description,
                                        -- lt_rcv_trx_stg_tbl (line_v).vendor_id,
                                        --  gc_interface_source_code,          --'DELIVER',
                                        --  gc_auto_transact_code,   -- uncommented for ASN
                                        --     gc_receipt_source_code,
                                        --  gc_source_document_code,
                                        'Y',             --gc_validation_flag,
                                        --    ln_int_s,
                                        RCV_HEADERS_INTERFACE_S.CURRVAL,
                                        lcu_trc_lines_REC.new_po_line_location_id,
                                        -- lt_rcv_trx_stg_tbl (line_v).to_organization_id,
                                        lcu_trc_lines_REC.new_po_distribution_id,
                                        'RECEIVING', --gc_destination_type_code,                                       -- modified in ver 1.1
                                        gn_user_id,
                                        gn_user_id,
                                        gd_sys_date,
                                        gd_sys_date,
                                        gn_user_id,
                                        lcu_trc_lines_REC.employee_id,
                                        lcu_trc_lines_REC.deliver_to_person_id,
                                        lcu_trc_lines_REC.RT_CURRENCY_CODE,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE_CATEGORY,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE1,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE2,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE3,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE4,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE5,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE6,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE7,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE8,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE9,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE10,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE11,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE12,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE13,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE14,
                                        lcu_trc_lines_REC.RCV_TRC_ATTRIBUTE15,
                                        lcu_trc_lines_REC.SHIPMENT_LINE_ID,
                                        lcu_trc_lines_REC.TGT_PO_ORG_ID,
                                        NVL (lcu_trc_lines_REC.SUBINVENTORY,
                                             'FACTORY') -- lcu_trc_lines_REC.PO_UNIT_PRICE
                                                       );

                    UPDATE XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T
                       SET record_status   = gc_interfaced
                     WHERE     record_status = gc_validate_status
                           AND ROWID = lcu_trc_lines_REC.ROWID;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_err_msg   := SQLERRM;

                        UPDATE XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T
                           SET record_status = gc_error_status, error_message = l_err_msg
                         WHERE     record_status = gc_validate_status
                               AND ROWID = lcu_trc_lines_REC.ROWID;
                END;
            END LOOP;

            CLOSE lcu_trc_lines;
        END LOOP;

        CLOSE lcu_ship_header_id;

        COMMIT;
    --  END LOOP;
    -- END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record in the PO Interface table '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END rcv_interface_insert;

    PROCEDURE rcv_import_prc (p_org_name IN VARCHAR2, x_return_mesg OUT VARCHAR2, x_return_code OUT NUMBER)
    IS
        CURSOR cur_Batch_id IS
            SELECT DISTINCT org_id, GROUP_ID
              FROM rcv_headers_interface rhi, XXD_DROP_SHIP_RCV_CONV_STG_T xxdss
             WHERE     xxdss.RECEIPT_NUM = rhi.RECEIPT_NUM
                   AND rhi.processing_status_code = 'PENDING';

        --      AND RHI.RECEIPT_NUM in ('26444');
        -- AND rhi.group_id IN (6753) ;
        x_request_id               NUMBER;
        x_application_id           NUMBER;
        x_responsibility_id        NUMBER;
        ln_count                   NUMBER := 1;
        ln_exit_flag               NUMBER := 0;
        lb_flag                    BOOLEAN := FALSE;
        lc_rollback                EXCEPTION;
        lc_launch_rollback         EXCEPTION;
        lc_released_Status         VARCHAR2 (200);
        ln_del_id                  NUMBER;
        ln_org_id                  NUMBER;
        log_msg                    VARCHAR2 (4000);
        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);
        -- lc_message            VARCHAR2 (2000);
        -- lb_request_status     BOOLEAN;
        v_return_status            VARCHAR2 (50);
        lc_phase                   VARCHAR2 (2000);
        lc_wait_status             VARCHAR2 (2000);
        lc_dev_phase               VARCHAR2 (2000);
        lc_dev_status              VARCHAR2 (2000);
        lc_message                 VARCHAR2 (2000);
        ln_req_id                  NUMBER;
        lb_request_status          BOOLEAN;
    BEGIN
        -- x_return_sts := GC_API_SUCCESS;
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'Start of Procedure req_import_prc ');
        --    debug(GC_SOURCE_PROGRAM);
        FND_FILE.PUT_LINE (fnd_file.LOG,
                           'Submitting receving Transaction processor ');

        FOR batch_id IN cur_Batch_id
        LOOP
            --ln_org_id := get_targetorg_id (p_org_name => p_org_name); --fnd_profile.VALUE ('ORG_ID');
            set_org_context (p_target_org_id   => TO_NUMBER (batch_id.org_id),
                             p_resp_id         => x_responsibility_id,
                             p_resp_appl_id    => x_application_id);
            fnd_request.set_org_id (batch_id.org_id);
            /*  log_records (p_debug     => gc_debug_flag,
                           p_message   => 'ln_org_id' || batch_id.org_id);
              --    debug(GC_SOURCE_PROGRAM);
              */
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Submitting Purchase Order Import Program for batch Id  '
                || batch_id.org_id);
            mo_global.init ('PO');
            APPS.fnd_global.APPS_INITIALIZE (gn_user_id,
                                             x_responsibility_id,
                                             x_application_id);
            ln_req_id   :=
                fnd_request.submit_request (
                    application   => 'PO',
                    program       => 'RVCTP',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => 'BATCH',
                    argument2     => batch_id.GROUP_ID,
                    argument3     => batch_id.org_id);
            COMMIT;

            IF ln_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to ?'
                    || fnd_message.get
                    || '?.');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'The Receipt Import Program submitted ? Request id :'
                    || ln_req_id);
            END IF;

            IF ln_req_id > 0
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    '   Waiting for the Receipt Import Program');

                LOOP
                    lb_request_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 60,
                            max_wait     => 0,
                            phase        => lc_phase,
                            status       => lc_wait_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);
                    EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                              OR UPPER (lc_wait_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                COMMIT;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  Receipt Import Program Request Phase'
                    || '-'
                    || lc_dev_phase);
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '  Receipt Import Program Request Dev status'
                    || '-'
                    || lc_dev_status);

                IF     UPPER (lc_phase) = 'COMPLETED'
                   AND UPPER (lc_wait_status) = 'ERROR'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'The Receipt Import prog completed in error. See log for request id');
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);
                    RETURN;
                ELSIF     UPPER (lc_phase) = 'COMPLETED'
                      AND UPPER (lc_wait_status) = 'NORMAL'
                THEN
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                           'The Receipt Import successfully completed for request id: '
                        || ln_req_id);
                ELSE
                    Fnd_File.PUT_LINE (
                        Fnd_File.LOG,
                        'The Receipt Import request failed.Review log for Oracle request id ');
                    Fnd_File.PUT_LINE (Fnd_File.LOG, SQLERRM);
                    RETURN;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   :=
                'The procedure receipt_import Failed  ' || SQLERRM;
            x_return_code   := 1;
            FND_FILE.PUT_LINE (
                fnd_file.LOG,
                   'Error Status '
                || x_return_code
                || ' ,Error message '
                || x_return_mesg);
            RAISE_APPLICATION_ERROR (-20003, SQLERRM);
    END rcv_import_prc;

    PROCEDURE main (x_retcode            OUT NUMBER,
                    x_errbuf             OUT VARCHAR2,
                    p_org_name        IN     VARCHAR2,
                    p_process         IN     VARCHAR2,
                    p_debug_flag      IN     VARCHAR2,
                    p_no_of_process   IN     NUMBER)
    IS
        x_errcode                VARCHAR2 (500);
        x_errmsg                 VARCHAR2 (500);
        lc_debug_flag            VARCHAR2 (1);
        ln_process               NUMBER;
        ln_ret                   NUMBER;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id          hdr_batch_id_t;

        TYPE hdr_customer_process_t IS TABLE OF VARCHAR2 (250)
            INDEX BY BINARY_INTEGER;

        lc_hdr_customer_proc_t   hdr_customer_process_t;
        lc_conlc_status          VARCHAR2 (150);
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        --      ln_batch_cnt          NUMBER                                   := 0;
        ln_parent_request_id     NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);
        ln_valid_rec_cnt         NUMBER;
        x_total_rec              NUMBER;
        x_validrec_cnt           NUMBER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        gc_debug_flag   := p_debug_flag;

        IF p_process = gc_extract_only
        THEN
            fnd_file.put_line (
                fnd_file.output,
                LPAD ('Drop Ship SO Requistion Extract Program Started ', 70));

            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                log_records (gc_debug_flag,
                             'Code Pointer: ' || gc_code_pointer);
            END IF;

            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);
            log_records (gc_debug_flag,
                         'Woking on extract the data for the OU ');
            extract_1206_data (p_org_name => p_org_name, x_total_rec => x_total_rec, x_validrec_cnt => ln_valid_rec_cnt
                               , x_errbuf => x_errbuf, x_retcode => x_retcode);


            /* ----------------added in ver 1.2 --------------------------------- */

            gc_code_pointer   := 'Start Updating Requisition number';
            log_records (gc_debug_flag, gc_code_pointer);

            update_requisition_num (p_org_name => p_org_name, p_no_of_process => p_no_of_process, x_errbuf => x_errbuf
                                    , x_retcode => x_retcode);
        /* ----------------------end of ver 1.2 -----------------------*/
        ELSIF p_process = gc_po_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                log_records (gc_debug_flag,
                             'Code Pointer: ' || gc_code_pointer);
            END IF;

            EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_DROP_SHIP_PO_CONV_STG_T';

            log_records (gc_debug_flag,
                         'Woking on extract the data for the OU ');
            extract_1206_po_data (p_org_name       => p_org_name,
                                  x_total_rec      => x_total_rec,
                                  x_validrec_cnt   => ln_valid_rec_cnt,
                                  x_errbuf         => x_errbuf,
                                  x_retcode        => x_retcode);
        ---------------------------------- commented in ver 1.2----------------------------
        /*  ELSIF p_Process = gc_pur_release
          THEN
             --------------------------------------------------------------------------------  ver 1.2
        */
        ELSIF p_Process = gc_req_import
        THEN
            fnd_file.put_line (
                fnd_file.output,
                LPAD ('Purchase requisition Program Started ', 70));
            /* req_import_prc (p_org_name      => p_org_name,
                             x_return_mesg   => x_errbuf,
                             x_return_code   => x_retcode);*/
            ln_cntr   := 0;
            log_records (
                gc_debug_flag,
                'Fetching Distinct batch id from XXD_DROP_SHIP_SO_CONV_STG_T ');

            FOR I
                IN (  SELECT DISTINCT batch_id
                        FROM xxd_drop_ship_so_conv_stg_t
                       WHERE     batch_id IS NOT NULL
                             AND RECORD_STATUS = gc_new_status
                    ORDER BY batch_id)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;

            --  COMMIT;
            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_AR_CUST_CHILD_CONV for batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM xxd_drop_ship_so_conv_stg_t
                     WHERE batch_id = ln_hdr_batch_id (i);

                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                    '',
                                    '',
                                    FALSE,
                                    p_org_name,
                                    p_debug_flag,
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
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        ELSIF p_Process = gc_load_only
        THEN
            ln_cntr   := 0;
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_DROP_SHIP_PO_CONV_STG_T stage to call worker process');

            FOR I
                IN (  SELECT DISTINCT batch_id
                        FROM XXD_DROP_SHIP_PO_CONV_STG_T
                       WHERE     batch_id IS NOT NULL
                             AND RECORD_STATUS = gc_validate_status
                    ORDER BY batch_id)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_DROP_SHIP_PO_CONV_STG_T');
            log_records (gc_debug_flag,
                         'ln_hdr_batch_id.COUNT' || ln_hdr_batch_id.COUNT);
            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_AR_CUST_CHILD_CONV in batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM XXD_DROP_SHIP_PO_CONV_STG_T
                     WHERE batch_id = ln_hdr_batch_id (i);

                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                    '',
                                    '',
                                    FALSE,
                                    p_org_name,
                                    p_debug_flag,
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
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        /* po_interface_insert (p_org_name      => p_org_name,
                         x_errbuf   => x_errbuf,
                          x_retcode    => x_retcode);*/
        ELSIF p_Process = gc_po_import_only
        THEN
            ln_cntr   := 0;
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_ONT_SO_HEADERS_CONV_STG_T stage to call worker process');

            FOR I
                IN (  SELECT DISTINCT batch_id
                        FROM XXD_DROP_SHIP_PO_CONV_STG_T
                       WHERE     batch_id IS NOT NULL
                             AND RECORD_STATUS = gc_interfaced
                    ORDER BY batch_id)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_ONT_SO_HEADERS_CONV_STG_T');
            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_AR_CUST_CHILD_CONV in batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM XXD_DROP_SHIP_PO_CONV_STG_T
                     WHERE batch_id = ln_hdr_batch_id (i);

                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                    '',
                                    '',
                                    FALSE,
                                    p_org_name,
                                    p_debug_flag,
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
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        /* po_import_prc (p_org_name      => p_org_name,
                         x_return_mesg   => x_errbuf,
                         x_return_code   => x_retcode);*/
        /*ELSIF p_Process = gc_po_update_only
        THEN
           update_drop_ship_prc (p_org_name      => p_org_name,
                                 x_return_mesg   => x_errbuf,
                                 x_return_code   => x_retcode);
         */
        ELSIF p_process = gc_rcv_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                log_records (gc_debug_flag,
                             'Code Pointer: ' || gc_code_pointer);
            END IF;

            EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_DROP_SHIP_RCV_CONV_STG_T';

            log_records (gc_debug_flag,
                         'Woking on extract the data for the OU ');
            extract_1206_rcv_data (p_org_name       => p_org_name,
                                   x_total_rec      => x_total_rec,
                                   x_validrec_cnt   => ln_valid_rec_cnt,
                                   x_errbuf         => x_errbuf,
                                   x_retcode        => x_retcode);
        ELSIF p_Process = gc_rcv_load_only
        THEN
            ln_cntr   := 0;
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_ONT_SO_HEADERS_CONV_STG_T stage to call worker process');

            FOR I
                IN (  SELECT DISTINCT batch_id
                        FROM XXD_DROP_SHIP_RCV_CONV_STG_T
                       WHERE     batch_id IS NOT NULL
                             AND RECORD_STATUS = gc_validate_status
                    ORDER BY batch_id)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_ONT_SO_HEADERS_CONV_STG_T');
            log_records (gc_debug_flag,
                         'ln_hdr_batch_id.COUNT' || ln_hdr_batch_id.COUNT);
            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_AR_CUST_CHILD_CONV in batch '
                    || ln_hdr_batch_id.COUNT);
                log_records (
                    gc_debug_flag,
                    'ln_hdr_batch_id.FIRST ' || ln_hdr_batch_id.FIRST);
                log_records (gc_debug_flag,
                             'ln_hdr_batch_id.LAST ' || ln_hdr_batch_id.LAST);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    log_records (
                        gc_debug_flag,
                        ' ln_hdr_batch_id (i):: ' || ln_hdr_batch_id (i));

                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM XXD_DROP_SHIP_RCV_CONV_STG_T
                     WHERE batch_id = ln_hdr_batch_id (i);

                    IF ln_cntr > 0
                    THEN
                        log_records (gc_debug_flag, 'before child progran');
                        log_records (
                            gc_debug_flag,
                            'ln_hdr_batch_id(i):=' || ln_hdr_batch_id (i));

                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                    '',
                                    '',
                                    FALSE,
                                    p_org_name,
                                    p_debug_flag,
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
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        /*  rcv_interface_insert (p_org_name      => p_org_name,
                          x_errbuf   => x_errbuf,
                           x_retcode    => x_retcode);*/
        ELSIF p_Process = gc_rcv_import_only
        THEN
            rcv_import_prc (p_org_name      => p_org_name,
                            x_return_mesg   => x_errbuf,
                            x_return_code   => x_retcode);
        ELSIF p_Process = gc_rcv_validate_only
        THEN
            SELECT COUNT (DISTINCT RECEIPT_NUM)
              INTO ln_valid_rec_cnt
              FROM XXD_DROP_SHIP_RCV_CONV_STG_T
             WHERE batch_id IS NULL AND RECORD_STATUS = gc_new_status;

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT RCV_INTERFACE_GROUPS_S.NEXTVAL --XXD_ONT_DS_SO_rcv_BATCH_S.NEXTVAL
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

                BEGIN
                    UPDATE XXD_DROP_SHIP_RCV_CONV_STG_T x
                       SET batch_id = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id, RECORD_STATUS = 'BU'
                     WHERE     batch_id IS NULL
                           AND x.RECEIPT_NUM IN
                                   (SELECT T.RECEIPT_NUM
                                      FROM (SELECT DISTINCT RECEIPT_NUM
                                              FROM XXD_DROP_SHIP_RCV_CONV_STG_T
                                             WHERE RECORD_STATUS = 'N') T
                                     WHERE ROWNUM <=
                                           CEIL (
                                                 ln_valid_rec_cnt
                                               / p_no_of_process))
                           AND RECORD_STATUS = gc_new_status;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_records (gc_debug_flag,
                                     'exception receipt update ' || SQLERRM);
                END;
            END LOOP;

            COMMIT;

            BEGIN
                UPDATE XXD_DROP_SHIP_RCV_CONV_STG_T
                   SET RECORD_STATUS   = gc_new_status
                 WHERE RECORD_STATUS = 'BU';
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                        'exception receipt RECORD_STATUS update ' || SQLERRM);
            END;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_DROP_SHIP_RCV_CONV_STG_T
                 WHERE     record_status = gc_new_status
                       AND batch_id = ln_hdr_batch_id (l);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                '',
                                '',
                                FALSE,
                                p_org_name,
                                p_debug_flag,
                                p_process,
                                ln_hdr_batch_id (l),
                                ln_parent_request_id);
                        log_records (gc_debug_flag,
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
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        /* validate_rcv_data (p_org_name      => p_org_name,
                          x_errbuf   => x_errbuf,
                           x_retcode    => x_retcode);*/
        ELSIF p_Process = gc_po_validate_only
        THEN
            SELECT COUNT (DISTINCT po_number)
              INTO ln_valid_rec_cnt
              FROM XXD_DROP_SHIP_PO_CONV_STG_T
             WHERE     1 = 1
                   AND ((batch_id IS NULL AND RECORD_STATUS = gc_new_status) OR (batch_id IS NOT NULL AND RECORD_STATUS IN (gc_validate_status, gc_error_status)));

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT PO_CONTROL_GROUPS_S.NEXTVAL
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

                BEGIN
                    UPDATE XXD_DROP_SHIP_PO_CONV_STG_T x
                       SET batch_id = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id, RECORD_STATUS = 'BU'
                     WHERE     1 = 1
                           AND x.po_number IN
                                   (SELECT T.po_number
                                      FROM (SELECT DISTINCT po_number
                                              FROM XXD_DROP_SHIP_PO_CONV_STG_T
                                             WHERE RECORD_STATUS IN
                                                       ('N', 'E', 'V')) T
                                     WHERE ROWNUM <=
                                           CEIL (
                                                 ln_valid_rec_cnt
                                               / p_no_of_process))
                           AND ((batch_id IS NULL AND RECORD_STATUS = gc_new_status) OR (batch_id IS NOT NULL AND RECORD_STATUS IN (gc_validate_status, gc_error_status)));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_records (gc_debug_flag,
                                     'exception PO update ' || SQLERRM);
                END;
            END LOOP;

            COMMIT;

            BEGIN
                UPDATE XXD_DROP_SHIP_PO_CONV_STG_T
                   SET RECORD_STATUS   = gc_new_status
                 WHERE RECORD_STATUS = 'BU';
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                        'exception PO RECORD_STATUS update ' || SQLERRM);
            END;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_DROP_SHIP_PO_CONV_STG_T
                 WHERE     record_status = gc_new_status
                       AND batch_id = ln_hdr_batch_id (l);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_ONT_DROP_SHIP_CNV_CHILD',
                                '',
                                '',
                                FALSE,
                                p_org_name,
                                p_debug_flag,
                                p_process,
                                ln_hdr_batch_id (l),
                                ln_parent_request_id);
                        log_records (gc_debug_flag,
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
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_DROP_SHIP_CNV_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        /*validate_po_data (p_org_name      => p_org_name,
                         x_errbuf   => x_errbuf,
                          x_retcode    => x_retcode);*/
        END IF;
    END main;



    PROCEDURE drop_ship_order_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'Y', p_action IN VARCHAR2, p_batch_number IN NUMBER
                                     , p_parent_request_id IN NUMBER)
    AS
        le_invalid_param            EXCEPTION;
        ln_new_ou_id                hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12
        ln_request_id               NUMBER := 0;
        lc_username                 fnd_user.user_name%TYPE;
        lc_operating_unit           hr_operating_units.NAME%TYPE;
        lc_cust_num                 VARCHAR2 (5);
        lc_pri_flag                 VARCHAR2 (1);
        ld_start_date               DATE;
        ln_ins                      NUMBER := 0;
        lc_create_reciprocal_flag   VARCHAR2 (1) := gc_no_flag;
        --ln_request_id             NUMBER                     := 0;
        lc_phase                    VARCHAR2 (200);
        lc_status                   VARCHAR2 (200);
        lc_delc_phase               VARCHAR2 (200);
        lc_delc_status              VARCHAR2 (200);
        lc_message                  VARCHAR2 (200);
        ln_ret_code                 NUMBER;
        lc_err_buff                 VARCHAR2 (1000);
        ln_count                    NUMBER;
        l_target_org_id             NUMBER;
        --  l_user_id           NUMBER := -1;
        --l_resp_id           NUMBER := -1;
        l_application_id            NUMBER := -1;
        l_user_id                   VARCHAR2 (30) := fnd_global.user_id;
        l_resp_id                   VARCHAR2 (30) := FND_GLOBAL.resp_id;
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        -- Get the user_id
        /*  SELECT user_id
          INTO l_user_id
          FROM fnd_user
          WHERE user_name = l_user_name;*/
        -- Get the application_id and responsibility_id
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility
         WHERE responsibility_id = l_resp_id;

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
        log_records (
            gc_debug_flag,
            '*************************************************************************** ');
        log_records (
            gc_debug_flag,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        log_records (
            gc_debug_flag,
            '*************************************************************************** ');
        log_records (
            gc_debug_flag,
               '                                         Busines Unit:'
            || lc_operating_unit);
        --      log_records (gc_debug_flag, '                                         Run By      :' || lc_username);
        log_records (
            gc_debug_flag,
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        log_records (
            gc_debug_flag,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        log_records (
            gc_debug_flag,
               '                                         Batch ID    :'
            || p_batch_number);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (
            gc_debug_flag,
            '******** START of Drop Ship Sales Order Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        gc_debug_flag        := p_debug_flag;
        l_target_org_id      := get_targetorg_id (p_org_name => p_org_name);

        /*  set_org_context (p_target_org_id    =>     l_target_org_id
                          ,p_resp_id          =>     gn_resp_id
                          ,p_resp_appl_id     =>     gn_resp_appl_id
                               ) ; */
        IF p_action = gc_req_import
        THEN
            req_import_prc (p_org_name => p_org_name, p_batch_id => p_batch_number, x_return_mesg => errbuf
                            , x_return_code => retcode);
        ELSIF p_action = gc_pur_release
        THEN
            update_req_number (p_org_name => p_org_name, p_batch_id => p_batch_number, x_errbuf => errbuf
                               , x_retcode => retcode);
        ELSIF p_action = gc_load_only
        THEN
            po_interface_insert (p_org_name => p_org_name, p_batch_id => p_batch_number, x_errbuf => errbuf
                                 , x_retcode => retcode);
        ELSIF p_action = gc_po_import_only
        THEN
            po_import_prc (p_org_name => p_org_name, p_batch_id => p_batch_number, x_return_mesg => errbuf
                           , x_return_code => retcode);
        /* ELSIF p_action = gc_po_update_only
        THEN
           update_drop_ship_prc (p_org_name      => p_org_name,
                                 x_return_mesg   => errbuf,
                                 x_return_code   => retcode);
         */
        ELSIF p_action = gc_rcv_load_only
        THEN
            rcv_interface_insert (p_org_name => p_org_name, p_batch_id => p_batch_number, x_errbuf => errbuf
                                  , x_retcode => retcode);
        ELSIF p_action = gc_rcv_import_only
        THEN
            rcv_import_prc (p_org_name      => p_org_name,
                            x_return_mesg   => errbuf,
                            x_return_code   => retcode);
        ELSIF p_action = gc_po_validate_only
        THEN
            validate_po_data (p_org_name => p_org_name, p_batch_id => p_batch_number, x_errbuf => errbuf
                              , x_retcode => retcode);
        ELSIF p_action = gc_rcv_validate_only
        THEN
            validate_rcv_data (p_org_name => p_org_name, p_batch_id => p_batch_number, x_errbuf => errbuf
                               , x_retcode => retcode);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During sales_order  Program');
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
    END drop_ship_order_child;
END XXD_ONT_DROP_SHIP_SO_CONV_PKG;
/
