--
-- XXD_MTL_UOM_INTERFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_MTL_UOM_INTERFACE_PKG
AS
    /*******************************************************************************
      * Program Name : XXD_MTL_UOM_INTERFACE_PKG
      * Language     : PL/SQL
      *
      * History      :
      *
      * WHO                  WHAT              Desc                             WHEN
      * -------------- ---------------------------------------------- ---------------
      * BT Technology Team    1.0              UOM Conversion                 07-JAN-2015
      *******************************************************************************/

    TYPE XXD_MTL_UOM_INT_TAB
        IS TABLE OF XXD_MTL_UOM_CONVERSIONS_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_mtl_uom_int_tab   XXD_MTL_UOM_INT_TAB;

    -- gn_error NUMBER := 2;
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


    PROCEDURE uom_validation (x_retcode      OUT NUMBER,
                              x_errbuf       OUT VARCHAR2,
                              p_process   IN     VARCHAR2)
    AS
        lc_status              VARCHAR2 (20);
        ln_cnt                 NUMBER := 0;

        TYPE lt_gl_stg_tbl_type
            IS TABLE OF XXD_MTL_UOM_CONVERSIONS_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_gl_stg_tbl          lt_gl_stg_tbl_type;

        CURSOR c_get_new_rec IS
            SELECT *
              FROM XXD_CONV.XXD_MTL_UOM_CONVERSIONS_STG_T XGPI
             WHERE XGPI.record_status = 'NEW';

        lc_error_msg           VARCHAR2 (2000);
        lc_error_message       VARCHAR2 (6000) := NULL;
        lc_phase               VARCHAR2 (6000);
        ln_item                NUMBER;
        ln_record_error_flag   NUMBER;
        ln_flag                NUMBER;
        ln_class               NUMBER;
        ln_uom                 NUMBER;
    BEGIN
        x_retcode          := NULL;
        x_errbuf           := NULL;
        log_records (gc_debug_flag,
                     'validate Customer p_process =.  ' || p_process);
        lc_error_message   := NULL;
        lc_phase           := NULL;


        OPEN c_get_new_rec;

        FETCH c_get_new_rec BULK COLLECT INTO lt_gl_stg_tbl;

        CLOSE c_get_new_rec;



        FOR i IN 1 .. lt_gl_stg_tbl.COUNT                    --c_get_valid_rec
        LOOP
            ln_record_error_flag   := 0;
            ln_flag                := 0;
            ln_class               := 0;
            ln_item                := 0;
            ln_uom                 := 0;
            log_records (gc_debug_flag, 'INSIDE');

            IF lt_gl_stg_tbl (i).inventory_item_id IS NULL
            THEN
                ln_record_error_flag   := 1;
                lc_phase               := 'item cannot be null';
                ln_flag                := ln_flag + 1;
                lc_error_message       :=
                       lc_error_message
                    || TO_CHAR (ln_flag)
                    || '. '
                    || lc_phase
                    || ' ';
            ELSE
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_item
                      FROM MTL_SYSTEM_ITEMS_B
                     WHERE inventory_item_id =
                           lt_gl_stg_tbl (i).INVENTORY_ITEM_ID;

                    IF ln_item = 0
                    THEN
                        ln_record_error_flag   := 1;
                        ln_flag                := ln_flag + 1;
                        lc_phase               :=
                               'item is invalid, item id = '
                            || lt_gl_stg_tbl (i).inventory_item_id;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_record_error_flag   := 1;
                        lc_phase               :=
                            'item cannot be null' || SQLERRM;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                END;
            END IF;



            IF lt_gl_stg_tbl (i).UOM_CLASS IS NULL
            THEN
                ln_record_error_flag   := 1;
                lc_phase               := 'UOM class cannot be null';
                ln_flag                := ln_flag + 1;
                lc_error_message       :=
                       lc_error_message
                    || TO_CHAR (ln_flag)
                    || '. '
                    || lc_phase
                    || ' ';
            ELSE
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_class
                      FROM MTL_UOM_CLASSES_TL
                     WHERE     uom_class = lt_gl_stg_tbl (i).UOM_CLASS
                           AND language = 'US';

                    IF ln_class = 0
                    THEN
                        ln_record_error_flag   := 1;
                        ln_flag                := ln_flag + 1;
                        lc_phase               :=
                               'UOM class does not exist = '
                            || lt_gl_stg_tbl (i).UOM_CLASS;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_record_error_flag   := 1;
                        lc_phase               :=
                            'UOM class be null' || SQLERRM;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                END;
            END IF;



            IF lt_gl_stg_tbl (i).UNIT_OF_MEASURE IS NULL
            THEN
                ln_record_error_flag   := 1;
                lc_phase               := 'item cannot be null';
                ln_flag                := ln_flag + 1;
                lc_error_message       :=
                       lc_error_message
                    || TO_CHAR (ln_flag)
                    || '. '
                    || lc_phase
                    || ' ';
            ELSE
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_uom
                      FROM mtl_units_of_measure_tl
                     WHERE     unit_of_measure =
                               lt_gl_stg_tbl (i).UNIT_OF_MEASURE
                           AND language = 'US';

                    IF ln_uom = 0
                    THEN
                        ln_record_error_flag   := 1;
                        ln_flag                := ln_flag + 1;
                        lc_phase               :=
                               'UOM is invalid, UOM is = '
                            || lt_gl_stg_tbl (i).UNIT_OF_MEASURE;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_record_error_flag   := 1;
                        lc_phase               :=
                            'UOM cannot be null' || SQLERRM;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                END;
            END IF;



            IF ln_record_error_flag = 1
            THEN
                -- log_records(gc_debug_flag,'in rej update');
                UPDATE XXD_MTL_UOM_CONVERSIONS_STG_T
                   SET error_msg = lc_error_message, record_status = 'REJECTED'
                 WHERE record_id = lt_gl_stg_tbl (i).record_id;
            --  log_records(gc_debug_flag,'inrej 21 update');
            ELSE
                --        log_records(gc_debug_flag,'in update');
                UPDATE XXD_MTL_UOM_CONVERSIONS_STG_T
                   SET record_status   = gc_validate_status      --'VALIDATED'
                 WHERE record_id = lt_gl_stg_tbl (i).record_id;
            --   log_records(gc_debug_flag,'after update');
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception Raised Program');
            --  ROLLBACK;
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
    END uom_validation;


    PROCEDURE extract_1206_data (x_total_rec OUT NUMBER, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM XXD_MTL_UOM_CONVERSIONS_STG_T
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;


        CURSOR lcu_cust_item_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   XXD_UOM_CNV_STG_SEQ.NEXTVAL, XACI.*
              FROM XXD_MTL_UOM_CONVERSIONS_V XACI;
    --  WHERE rownum<3;



    BEGIN
        gtt_mtl_uom_int_tab.delete;


        OPEN lcu_cust_item_data;

        LOOP
            lv_error_stage   := 'stg table';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_mtl_uom_int_tab.delete;

            FETCH lcu_cust_item_data
                BULK COLLECT INTO gtt_mtl_uom_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_mtl_uom_int_tab.COUNT
                INSERT INTO XXD_MTL_UOM_CONVERSIONS_STG_T
                     VALUES gtt_mtl_uom_int_tab (i);

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
            x_retcode   := gn_error;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    --truncte_stage_tables
    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        fnd_file.put_line (
            fnd_file.LOG,
            'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_MTL_UOM_CONVERSIONS_STG_T';

        fnd_file.put_line (fnd_file.LOG, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
    END truncte_stage_tables;

    PROCEDURE transfer_records (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_records                                                    *
    *                                                                                             *
    * Description          :  This procedure call std API                                          *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE lt_gl_stg_tbl_type
            IS TABLE OF XXD_MTL_UOM_CONVERSIONS_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_gl_stg_tbl          lt_gl_stg_tbl_type;

        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        ln_int_run_id          NUMBER;
        l_bulk_errors          NUMBER := 0;
        l_from_uom             VARCHAR2 (4);
        l_to_uom               VARCHAR2 (4);
        l_item_id              NUMBER;


        x_return_status        VARCHAR2 (10);
        x_errorcode            NUMBER;
        x_msg_count            NUMBER;
        x_msg_data             VARCHAR2 (255);
        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception   EXCEPTION;

        l_from_uom_code        VARCHAR2 (10);

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
            SELECT *
              FROM XXD_CONV.XXD_MTL_UOM_CONVERSIONS_STG_T XGPI
             WHERE XGPI.record_status = gc_validate_status;     --'VALIDATED';
    BEGIN
        gc_debug_flag   := 'Y';
        x_retcode       := NULL;
        x_errbuf        := NULL;
        --gc_code_pointer  := 'transfer_records';
        log_records (gc_debug_flag, 'Start of transfer_records procedure');

        SAVEPOINT INSERT_TABLE;

        OPEN c_get_valid_rec;

        FETCH c_get_valid_rec BULK COLLECT INTO lt_gl_stg_tbl;

        CLOSE c_get_valid_rec;

        FOR i IN 1 .. lt_gl_stg_tbl.COUNT                    --c_get_valid_rec
        LOOP
            log_records (gc_debug_flag, 'INSIDE');

            BEGIN
                ln_valid_rec_cnt   := lt_gl_stg_tbl.COUNT;
                --
                log_records (gc_debug_flag,
                             'Row count :' || ln_valid_rec_cnt);

                l_from_uom_code    := 'PR';
                --l_to_uom_code    := 'CSE';

                log_records (
                    gc_debug_flag,
                       'Inventory Item ID: '
                    || lt_gl_stg_tbl (i).INVENTORY_ITEM_ID);

                -- call API to create intra-class conversion
                log_records (
                    gc_debug_flag,
                    '===============================================================================');
                log_records (
                    gc_debug_flag,
                    'Calling Inv_Convert.Create_UOM_Conversion API to create Intra-class Conversions');


                -- Intra class  (Within the same UOM class as the Primary UOM's class)
                -- Source is the Base UOM of the Primary UOM's class

                inv_convert.create_uom_conversion (
                    p_from_uom_code   => l_from_uom_code, -- Source is the Base UOM of Primary UOM's class
                    p_to_uom_code     => lt_gl_stg_tbl (i).UOM_CODE, -- Destination UOM
                    p_item_id         => lt_gl_stg_tbl (i).INVENTORY_ITEM_ID, --10141264 ,
                    p_uom_rate        => lt_gl_stg_tbl (i).CONVERSION_RATE, --6,
                    x_return_status   => x_return_status);


                log_records (
                    gc_debug_flag,
                    '===============================================================================');
                log_records (
                    gc_debug_flag,
                    'Creating conversion between ' || l_from_uom_code);
                log_records (gc_debug_flag,
                             'Return Status: ' || x_return_status);

                IF (x_return_status <> fnd_api.g_ret_sts_success)
                THEN
                    log_records (
                        gc_debug_flag,
                        'Error Message Count :' || fnd_msg_pub.count_msg);
                    x_msg_count   := fnd_msg_pub.count_msg;

                    FOR cnt IN 1 .. x_msg_count
                    LOOP
                        log_records (
                            gc_debug_flag,
                               'Index: '
                            || cnt
                            || ' Error Message :'
                            || fnd_msg_pub.get (cnt, 'T'));
                    END LOOP;
                END IF;


                UPDATE XXD_MTL_UOM_CONVERSIONS_STG_T XGPI
                   SET XGPI.record_status   = gc_process_status
                 WHERE     xgpi.record_id = lt_gl_stg_tbl (i).record_id
                       AND xgpi.inventory_item_id =
                           (SELECT inventory_item_id
                              FROM MTL_UOM_CONVERSIONS
                             WHERE     inventory_item_id =
                                       XGPI.inventory_item_id
                                   AND UNIT_OF_MEASURE = XGPI.UNIT_OF_MEASURE
                                   AND UOM_CODE = XGPI.UOM_CODE
                                   AND CONVERSION_RATE = XGPI.CONVERSION_RATE);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := gn_error;
                    log_records (gc_debug_flag, 'Exception Occured :');
                    log_records (gc_debug_flag,
                                 TO_CHAR (SQLCODE) || ':' || SQLERRM);
                    log_records (
                        gc_debug_flag,
                        '===============================================================================');
            END;
        END LOOP;
    /*
    -------------------------------------------------------------------
    -- do a bulk insert into the MTL_CI_INTERFACE table for the batch
    ----------------------------------------------------------------
    FORALL ln_cnt IN 1..lt_ci_val_type.count save exceptions
    INSERT INTO MTL_CI_INTERFACE
    VALUES lt_ci_val_type(ln_cnt);--        x_rec_count := ln_valid_rec_cnt;
    */

    -------------------------------------------------------------------
    --Update the records that have been transferred to MTL_CI_INTERFACE
    --as PROCESSED in staging table
    -------------------------------------------------------------------


    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE;
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in excep_transfer_records '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := gn_error;
            x_errbuf    :=
                   'Error Message excep_transfer_records '
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
        fnd_file.put_line (fnd_file.LOG, '1');

        IF p_process = gc_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);

            extract_1206_data (x_total_rec   => x_total_rec,
                               x_errbuf      => x_errbuf,
                               x_retcode     => x_retcode);
        ELSIF p_process = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling cust_item_validation :');

            uom_validation (x_retcode   => x_retcode,
                            x_errbuf    => x_errbuf,
                            p_process   => gc_new_status);
        ELSIF p_process = gc_load_only
        THEN
            fnd_file.put_line (fnd_file.LOG, 'here');
            transfer_records (x_retcode => x_retcode, x_errbuf => x_errbuf);
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'OUT');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in excep_transfer_records '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := gn_error;
            x_errbuf    :=
                   'Error Message excep_transfer_records '
                || SUBSTR (SQLERRM, 1, 250);
    END MAIN;
END XXD_MTL_UOM_INTERFACE_PKG;
/
