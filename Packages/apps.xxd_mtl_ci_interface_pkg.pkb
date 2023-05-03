--
-- XXD_MTL_CI_INTERFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_MTL_CI_INTERFACE_PKG
AS
    /*******************************************************************************
      * Program Name : XXD_MTL_CI_INTERFACE_PKG
      * Language     : PL/SQL
      * Description  : This package will load data in to party, Customer, location, site, uses, contacts, account.
      *
      * History      :
      *
      * WHO                  WHAT              Desc                             WHEN
      * -------------- ---------------------------------------------- ---------------
      * BT Technology Team    1.0                                              17-JUN-2014
      *******************************************************************************/

    TYPE XXD_MTL_CI_INT_TAB IS TABLE OF XXD_MTL_CI_INTERFACE_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_mtl_ci_int_tab   XXD_MTL_CI_INT_TAB;

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

    PROCEDURE extract_1206_data (x_total_rec OUT NUMBER, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM XXD_MTL_CI_INTERFACE_STG_T
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;


        CURSOR lcu_cust_item_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   RECORD_STATUS, PROCESS_FLAG, PROCESS_MODE,
                   LOCK_FLAG, LAST_UPDATED_BY, LAST_UPDATE_DATE,
                   LAST_UPDATE_LOGIN, CREATED_BY, CREATION_DATE,
                   REQUEST_ID, PROGRAM_APPLICATION_ID, PROGRAM_ID,
                   PROGRAM_UPDATE_DATE, TRANSACTION_TYPE, CUSTOMER_NAME,
                   CUSTOMER_NUMBER || '-' || COMMODITY_CODE CUSTOMER_NUMBER, CUSTOMER_ID, CUSTOMER_CATEGORY_CODE,
                   CUSTOMER_CATEGORY, ADDRESS1, ADDRESS2,
                   ADDRESS3, ADDRESS4, CITY,
                   STATE, COUNTY, COUNTRY,
                   POSTAL_CODE, ADDRESS_ID, CUSTOMER_ITEM_NUMBER,
                   ITEM_DEFINITION_LEVEL_DESC, ITEM_DEFINITION_LEVEL, CUSTOMER_ITEM_DESC,
                   MODEL_CUSTOMER_ITEM_NUMBER, MODEL_CUSTOMER_ITEM_ID, COMMODITY_CODE,
                   COMMODITY_CODE_ID, MASTER_CONTAINER_SEGMENT2, MASTER_CONTAINER_SEGMENT3,
                   MASTER_CONTAINER_SEGMENT4, MASTER_CONTAINER_SEGMENT5, MASTER_CONTAINER_SEGMENT6,
                   MASTER_CONTAINER_SEGMENT7, MASTER_CONTAINER_SEGMENT8, MASTER_CONTAINER_SEGMENT9,
                   MASTER_CONTAINER_SEGMENT10, MASTER_CONTAINER_SEGMENT11, MASTER_CONTAINER_SEGMENT12,
                   MASTER_CONTAINER_SEGMENT13, MASTER_CONTAINER_SEGMENT14, MASTER_CONTAINER_SEGMENT15,
                   MASTER_CONTAINER_SEGMENT16, MASTER_CONTAINER_SEGMENT17, MASTER_CONTAINER_SEGMENT18,
                   MASTER_CONTAINER_SEGMENT19, MASTER_CONTAINER_SEGMENT20, MASTER_CONTAINER,
                   MASTER_CONTAINER_ITEM_ID, CONTAINER_ITEM_ORG_NAME, CONTAINER_ITEM_ORG_CODE,
                   CONTAINER_ITEM_ORG_ID, DETAIL_CONTAINER_SEGMENT1, DETAIL_CONTAINER_SEGMENT2,
                   DETAIL_CONTAINER_SEGMENT3, DETAIL_CONTAINER_SEGMENT4, DETAIL_CONTAINER_SEGMENT5,
                   DETAIL_CONTAINER_SEGMENT6, DETAIL_CONTAINER_SEGMENT7, DETAIL_CONTAINER_SEGMENT8,
                   DETAIL_CONTAINER_SEGMENT9, DETAIL_CONTAINER_SEGMENT10, DETAIL_CONTAINER_SEGMENT11,
                   DETAIL_CONTAINER_SEGMENT12, DETAIL_CONTAINER_SEGMENT13, DETAIL_CONTAINER_SEGMENT14,
                   DETAIL_CONTAINER_SEGMENT15, DETAIL_CONTAINER_SEGMENT16, DETAIL_CONTAINER_SEGMENT17,
                   DETAIL_CONTAINER_SEGMENT18, DETAIL_CONTAINER_SEGMENT19, DETAIL_CONTAINER_SEGMENT20,
                   DETAIL_CONTAINER, DETAIL_CONTAINER_ITEM_ID, MIN_FILL_PERCENTAGE,
                   DEP_PLAN_REQUIRED_FLAG, DEP_PLAN_PRIOR_BLD_FLAG, INACTIVE_FLAG,
                   ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE2,
                   ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
                   ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8,
                   ATTRIBUTE9, ATTRIBUTE10, ATTRIBUTE11,
                   ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14,
                   ATTRIBUTE15, DEMAND_TOLERANCE_POSITIVE, DEMAND_TOLERANCE_NEGATIVE,
                   ERROR_CODE, ERROR_EXPLANATION, MASTER_CONTAINER_SEGMENT1
              FROM XXD_MTL_CUSTOMER_ITEMS_V XACI
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM INV.MTL_CUSTOMER_ITEMS mci
                         WHERE XACI.CUSTOMER_ITEM_NUMBER =
                               mci.CUSTOMER_ITEM_NUMBER);
    --        WHERE
    --        EXISTS(SELECT 1
    --                       FROM  XXD_AR_CUST_SITES_STG_T XACS
    --                       WHERE XACI.customer_id = XACS.customer_id
    --                       AND   XACI.record_status=gc_new_status
    --                       ) ;
    --where customer_id   in ( 2020,1453,2002,2079,2255)     ;
    --AND   HSUA.org_id            = p_source_org_id)        ;



    BEGIN
        gtt_mtl_ci_int_tab.delete;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_MTL_CI_INTERFACE_STG_T';

        OPEN lcu_cust_item_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Site Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_mtl_ci_int_tab.delete;

            FETCH lcu_cust_item_data
                BULK COLLECT INTO gtt_mtl_ci_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_mtl_ci_int_tab.COUNT
                INSERT INTO XXD_MTL_CI_INTERFACE_STG_T
                     VALUES gtt_mtl_ci_int_tab (i);

            COMMIT;
            EXIT WHEN lcu_cust_item_data%NOTFOUND;
        END LOOP;

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

    PROCEDURE cust_item_validation (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lc_status                 VARCHAR2 (20);
        ln_cnt                    NUMBER := 0;

        CURSOR cur_cust_item (p_process VARCHAR2)
        IS
            SELECT *
              FROM XXD_MTL_CI_INTERFACE_STG_T cust
             WHERE RECORD_STATUS = p_process;

        TYPE lt_customer_typ IS TABLE OF cur_cust_item%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_data              lt_customer_typ;
        lc_cust_item_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lc_error_msg              VARCHAR2 (2000);
    BEGIN
        x_retcode   := NULL;
        x_errbuf    := NULL;
        log_records (gc_debug_flag,
                     'validate Customer p_process =.  ' || p_process);

        OPEN cur_cust_item (p_process => p_process);

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

                    IF lt_cust_data (xc_custr_rec).CUSTOMER_NUMBER IS NULL
                    THEN
                        lc_cust_item_valid_data   := gc_no_flag;
                        lc_error_msg              :=
                               'CUSTOMER_NUMBER Can not be null for the customer item '
                            || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                            || 'and Item description '
                            || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_DESC;
                    ELSE
                        BEGIN
                            SELECT 1
                              INTO ln_cnt
                              FROM hz_cust_accounts_all
                             WHERE account_number =
                                   lt_cust_data (xc_custr_rec).CUSTOMER_NUMBER;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_item_valid_data   := gc_no_flag;
                                lc_error_msg              :=
                                       'CUSTOMER_NUMBER Not Available in system '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                                    || 'and Item description '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_DESC;
                            WHEN OTHERS
                            THEN
                                lc_error_msg              :=
                                       SQLERRM
                                    || ' CUSTOMER_NUMBER Not Available in system '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                                    || 'and Item description '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_DESC;
                                lc_cust_item_valid_data   := gc_no_flag;
                        END;
                    END IF;

                    IF lt_cust_data (xc_custr_rec).COMMODITY_CODE IS NULL
                    THEN
                        lc_cust_item_valid_data   := gc_no_flag;
                        lc_error_msg              :=
                               lc_error_msg
                            || ' COMMODITY_CODE Can not be null for the customer item '
                            || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                            || 'and Item description '
                            || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_DESC;
                    ELSE
                        BEGIN
                            SELECT 1
                              INTO ln_cnt
                              FROM MTL_COMMODITY_CODES
                             WHERE COMMODITY_CODE =
                                   lt_cust_data (xc_custr_rec).COMMODITY_CODE;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_item_valid_data   := gc_no_flag;
                                lc_error_msg              :=
                                       lc_error_msg
                                    || ' COMMODITY_CODE Not Available in system for the customer item '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                                    || 'and Item description '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_DESC;
                            WHEN OTHERS
                            THEN
                                lc_cust_item_valid_data   := gc_no_flag;
                                lc_error_msg              :=
                                       lc_error_msg
                                    || SQLERRM
                                    || ' for the customer item '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                                    || 'and Item description '
                                    || lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_DESC;
                        END;
                    END IF;

                    --lc_error_msg := NULL;

                    fnd_file.put_line (fnd_file.LOG, lc_cust_item_valid_data);
                    fnd_file.put_line (fnd_file.LOG, lc_error_msg);

                    IF lc_cust_item_valid_data = gc_no_flag
                    THEN
                        UPDATE XXD_MTL_CI_INTERFACE_STG_T
                           SET ERROR_EXPLANATION = lc_error_msg, RECORD_STATUS = gc_error_status
                         WHERE     CUSTOMER_ITEM_NUMBER =
                                   lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                               AND CUSTOMER_NUMBER =
                                   lt_cust_data (xc_custr_rec).CUSTOMER_NUMBER;
                    ELSE
                        UPDATE XXD_MTL_CI_INTERFACE_STG_T
                           SET ERROR_EXPLANATION = NULL, RECORD_STATUS = gc_validate_status
                         WHERE     CUSTOMER_ITEM_NUMBER =
                                   lt_cust_data (xc_custr_rec).CUSTOMER_ITEM_NUMBER
                               AND CUSTOMER_NUMBER =
                                   lt_cust_data (xc_custr_rec).CUSTOMER_NUMBER;
                    END IF;

                    lc_error_msg              := NULL;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_cust_item;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Raised During Price List Validation Program');
            --  ROLLBACK;
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
    END cust_item_validation;

    PROCEDURE transfer_records (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2)
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
        TYPE type_ci_val_t IS TABLE OF MTL_CI_INTERFACE%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_ci_val_type         type_ci_val_t;

        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        ln_int_run_id          NUMBER;
        l_bulk_errors          NUMBER := 0;

        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception   EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
            SELECT *
              FROM XXD_MTL_CI_INTERFACE_STG_T XGPI
             WHERE XGPI.record_status = gc_validate_status;
    BEGIN
        x_retcode         := NULL;
        x_errbuf          := NULL;
        gc_code_pointer   := 'transfer_records';
        log_records (gc_debug_flag, 'Start of transfer_records procedure');

        SAVEPOINT INSERT_TABLE;



        lt_ci_val_type.DELETE;

        FOR rec_get_valid_rec IN c_get_valid_rec
        LOOP
            ln_count           := ln_count + 1;
            ln_valid_rec_cnt   := c_get_valid_rec%ROWCOUNT;
            --
            log_records (gc_debug_flag, 'Row count :' || ln_valid_rec_cnt);

            --
            lt_ci_val_type (ln_valid_rec_cnt).PROCESS_FLAG   :=
                rec_get_valid_rec.PROCESS_FLAG;
            lt_ci_val_type (ln_valid_rec_cnt).PROCESS_MODE   :=
                rec_get_valid_rec.PROCESS_MODE;
            lt_ci_val_type (ln_valid_rec_cnt).LOCK_FLAG   :=
                rec_get_valid_rec.LOCK_FLAG;
            lt_ci_val_type (ln_valid_rec_cnt).LAST_UPDATED_BY   :=
                rec_get_valid_rec.LAST_UPDATED_BY;
            lt_ci_val_type (ln_valid_rec_cnt).LAST_UPDATE_DATE   :=
                rec_get_valid_rec.LAST_UPDATE_DATE;
            lt_ci_val_type (ln_valid_rec_cnt).LAST_UPDATE_LOGIN   :=
                rec_get_valid_rec.LAST_UPDATE_LOGIN;
            lt_ci_val_type (ln_valid_rec_cnt).CREATED_BY   :=
                rec_get_valid_rec.CREATED_BY;
            lt_ci_val_type (ln_valid_rec_cnt).CREATION_DATE   :=
                rec_get_valid_rec.CREATION_DATE;
            lt_ci_val_type (ln_valid_rec_cnt).TRANSACTION_TYPE   :=
                rec_get_valid_rec.TRANSACTION_TYPE;
            lt_ci_val_type (ln_valid_rec_cnt).CUSTOMER_NUMBER   :=
                rec_get_valid_rec.CUSTOMER_NUMBER;
            lt_ci_val_type (ln_valid_rec_cnt).CUSTOMER_ITEM_NUMBER   :=
                rec_get_valid_rec.CUSTOMER_ITEM_NUMBER;
            lt_ci_val_type (ln_valid_rec_cnt).ITEM_DEFINITION_LEVEL   :=
                rec_get_valid_rec.ITEM_DEFINITION_LEVEL;
            lt_ci_val_type (ln_valid_rec_cnt).CUSTOMER_ITEM_DESC   :=
                rec_get_valid_rec.CUSTOMER_ITEM_DESC;
            lt_ci_val_type (ln_valid_rec_cnt).COMMODITY_CODE   :=
                rec_get_valid_rec.COMMODITY_CODE;
            lt_ci_val_type (ln_valid_rec_cnt).CONTAINER_ITEM_ORG_CODE   :=
                rec_get_valid_rec.CONTAINER_ITEM_ORG_CODE;
            lt_ci_val_type (ln_valid_rec_cnt).DEP_PLAN_REQUIRED_FLAG   :=
                rec_get_valid_rec.DEP_PLAN_REQUIRED_FLAG;
            lt_ci_val_type (ln_valid_rec_cnt).DEP_PLAN_PRIOR_BLD_FLAG   :=
                rec_get_valid_rec.DEP_PLAN_PRIOR_BLD_FLAG;
            lt_ci_val_type (ln_valid_rec_cnt).INACTIVE_FLAG   :=
                rec_get_valid_rec.INACTIVE_FLAG;
        END LOOP;

        -------------------------------------------------------------------
        -- do a bulk insert into the MTL_CI_INTERFACE table for the batch
        ----------------------------------------------------------------
        FORALL ln_cnt IN 1 .. lt_ci_val_type.COUNT SAVE EXCEPTIONS
            INSERT INTO MTL_CI_INTERFACE
                 VALUES lt_ci_val_type (ln_cnt);

        -------------------------------------------------------------------
        --Update the records that have been transferred to MTL_CI_INTERFACE
        --as PROCESSED in staging table
        -------------------------------------------------------------------

        UPDATE XXD_MTL_CI_INTERFACE_STG_T XGPI
           SET XGPI.record_status   = gc_process_status
         WHERE EXISTS
                   (SELECT 1
                      FROM MTL_CI_INTERFACE
                     WHERE     CUSTOMER_ITEM_NUMBER =
                               XGPI.CUSTOMER_ITEM_NUMBER
                           AND CUSTOMER_NUMBER = XGPI.CUSTOMER_NUMBER);

        COMMIT;
    --        x_rec_count := ln_valid_rec_cnt;

    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE;
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

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode       := 2;
            x_errbuf        :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                log_records (
                    gc_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE;
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
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_records;

    PROCEDURE main (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                    , p_debug_flag IN VARCHAR2)
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
        ln_parent_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
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

            cust_item_validation (x_retcode   => x_retcode,
                                  x_errbuf    => x_errbuf,
                                  p_process   => gc_new_status);
        ELSIF p_process = gc_load_only
        THEN
            transfer_records (x_retcode => x_retcode, x_errbuf => x_errbuf);
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
    END MAIN;
END XXD_MTL_CI_INTERFACE_PKG;
/
