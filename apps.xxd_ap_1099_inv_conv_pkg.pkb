--
-- XXD_AP_1099_INV_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_1099_INV_CONV_PKG"
AS
    /*******************************************************************************
    * Program Name : XXD_AP_1099_INV_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will load invoices data in to Oracle Payable base tables
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    *  Swapna N     1.0                                             17-JUN-2014
    *  Krishna H    1.1               ccid and tax code             16-May-2015
    * --------------------------------------------------------------------------- */
    gn_user_id          NUMBER := fnd_global.user_id;
    gn_resp_id          NUMBER := fnd_global.resp_id;
    gn_resp_appl_id     NUMBER := fnd_global.resp_appl_id;
    gn_req_id           NUMBER := fnd_global.conc_request_id;
    gn_sob_id           NUMBER := fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
    gn_org_id           NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_login_id         NUMBER := fnd_global.login_id;
    gd_sysdate          DATE := SYSDATE;
    gc_code_pointer     VARCHAR2 (500);
    gb_boolean          BOOLEAN;
    gn_inv_process      NUMBER;
    gn_inv_reject       NUMBER;
    gn_dist_processed   NUMBER;
    gn_dist_rejected    NUMBER;
    gn_hold_processed   NUMBER;
    gn_hold_rejected    NUMBER;
    gn_inv_found        NUMBER;
    gn_dist_found       NUMBER;
    gn_hold_found       NUMBER;
    gn_inv_extract      NUMBER;
    gn_dist_extract     NUMBER;
    gn_hold_extract     NUMBER;
    gn_limit            NUMBER := 1000;
    gc_yesflag          VARCHAR2 (1) := 'Y';
    gc_noflag           VARCHAR2 (1) := 'N';
    gc_debug_flag       VARCHAR2 (1) := 'Y';


    /****************************************************************************************
          * Procedure : Extract`_invoice_proc
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to staging table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * Aug/6/2014   Swapna N        1.00       Created
          ****************************************************************************************/

    PROCEDURE EXTRACT_INVOICE_PROC (p_extract_date   IN VARCHAR2,
                                    p_gl_date        IN VARCHAR2)
    IS
        --      TYPE l_invoice_info_type IS TABLE OF XXD_AP_1099_INV_CONV_V%ROWTYPE;
        --
        --      l_apinv_tbl   l_invoice_info_type;

        CURSOR invoice_c (p_accounting_date DATE)
        IS
              --SELECT * FROM XXD_AP_1099_INV_CONV_V;
              SELECT pv.vendor_name vendor_name, hou.name operating_unit, aia.org_id org_id,
                     pv.vendor_id vendor_id, pv.segment1 vendor_num, pvs.vendor_site_code vendor_site_code,
                     aia.invoice_currency_code invoice_currency_code, pvs.vendor_site_id vendor_site_id, SUM (aid.amount) amount
                FROM apps.ap_invoices_all@bt_read_1206 aia, apps.ap_suppliers@bt_read_1206 pv, apps.ap_supplier_sites_all@bt_read_1206 pvs,
                     apps.hr_operating_units@bt_read_1206 hou, apps.ap_invoice_distributions_all@bt_read_1206 aid
               WHERE     EXISTS
                             (SELECT 1
                                FROM apps.ap_invoice_payments_all@bt_read_1206 aip
                               WHERE     aip.invoice_id = aia.invoice_id
                                     AND TRUNC (aip.accounting_date) >=
                                         p_accounting_date
                                     AND NVL (reversal_flag, 'N') = 'N')
                     AND pv.vendor_id = pvs.vendor_id
                     AND aia.vendor_site_id = pvs.vendor_site_id(+)
                     AND aia.invoice_type_lookup_code != 'EXPENSE REPORT'
                     AND aia.vendor_id = pvs.vendor_id(+)
                     AND aia.org_id = hou.organization_id(+)
                     AND aia.cancelled_date IS NULL
                     AND aid.invoice_id = aia.invoice_id
                     AND aid.type_1099 IS NOT NULL
                     AND hou.name IN
                             ('Deckers RETAIL', 'Deckers US', 'Deckers US eCommerce')
            GROUP BY pv.vendor_name, hou.name, aia.org_id,
                     pv.vendor_id, pv.segment1, pvs.vendor_site_code,
                     aia.invoice_currency_code, pvs.vendor_site_id;

        -- WHERE VENDOR_NUM = '6137';

        TYPE l_invoice_info_type IS TABLE OF invoice_c%ROWTYPE;

        l_apinv_tbl          l_invoice_info_type;

        ln_counter           NUMBER;
        ld_accounting_date   DATE;
    BEGIN
        ld_accounting_date   := fnd_date.canonical_to_date (p_extract_date);
        gc_code_pointer      :=
            'Deleting data from  Header and line staging table';

        --Deleting data from  Header and line staging table

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AP_1099_INV_CONV_STG_T';

        --EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AP_1099_DIST_CONV_STG_T';

        gc_code_pointer      := 'Insert into   Header  staging table';

        --Insert into   Header  staging table

        BEGIN
            OPEN invoice_c (ld_accounting_date);

            ln_counter        := 0;

            LOOP
                FETCH invoice_c BULK COLLECT INTO l_apinv_tbl LIMIT gn_limit;

                FORALL lcu_invoice_rec IN 1 .. l_apinv_tbl.COUNT
                    INSERT INTO XXD_AP_1099_INV_CONV_STG_T (VENDOR_SITE_CODE, INVOICE_CURRENCY_CODE, VENDOR_NAME, VENDOR_NUM, old_vendor_id, OLD_VENDOR_SITE_ID, ORG_ID, OPERATING_UNIT, TYPE_1099, INVOICE_AMOUNT, GL_DATE, ERROR_MESSAGE, RECORD_STATUS, RECORD_ID, LAST_UPDATE_DATE, LAST_UPDATED_BY, LAST_UPDATED_LOGIN, CREATION_DATE, CREATED_BY, NEW_ATTRIBUTE_CATEGORY, BATCH_NUMBER
                                                            , REQUEST_ID)
                         VALUES (l_apinv_tbl (lcu_invoice_rec).VENDOR_SITE_CODE, l_apinv_tbl (lcu_invoice_rec).INVOICE_CURRENCY_CODE, l_apinv_tbl (lcu_invoice_rec).VENDOR_NAME, l_apinv_tbl (lcu_invoice_rec).VENDOR_NUM, l_apinv_tbl (lcu_invoice_rec).vendor_id, l_apinv_tbl (lcu_invoice_rec).VENDOR_SITE_ID, l_apinv_tbl (lcu_invoice_rec).ORG_ID, l_apinv_tbl (lcu_invoice_rec).OPERATING_UNIT, 'MISC', --l_apinv_tbl (lcu_invoice_rec).TYPE_1099,
                                                                                                                                                                                                                                                                                                                                                                                                              l_apinv_tbl (lcu_invoice_rec).AMOUNT, fnd_date.canonical_to_date (p_gl_date), NULL, 'N', XXD_AP_1099_INV_CONV_STG_S.NEXTVAL, gd_sysdate, gn_user_id, gn_login_id, gd_sysdate, gn_user_id, NULL, --lv_R12_attri,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              NULL
                                 , gn_req_id);

                ln_counter   := ln_counter + 1;

                IF ln_counter = gn_limit
                THEN
                    COMMIT;
                    ln_counter   := 0;
                END IF;

                EXIT WHEN invoice_c%NOTFOUND;
            END LOOP;

            CLOSE invoice_c;

            gc_code_pointer   := 'After insert into Header table';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'OTHERS Exception while Insert into XXD_AP_1099_INV_CONV_STG_T Table');


                XXD_common_utils.record_error (
                    'APINV',
                    XXD_common_utils.get_org_id,
                    'Deckers AP Invoice Conversion Program',
                    DBMS_UTILITY.format_error_backtrace,
                    gd_sysdate,
                    gn_user_id,
                    gn_req_id,
                    'Code pointer : ' || gc_code_pointer,
                    'XXD_AP_1099_INV_CONV_STG_T');
        END;



        BEGIN
            SELECT COUNT (*)
              INTO gn_inv_extract
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE record_status = 'N';
        END;

        -- Writing counts to output file

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers AP Invoice Conversion Program for Extract');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no record extracted to XXD_AP_1099_INV_CONV_STG_T Table '
            || gn_inv_extract);
    END EXTRACT_INVOICE_PROC;


    /****************************************************************************************
          * Procedure : INTERFACE_LOAD_PRC
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to interface table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   Swapna N        1.00       Created
          ****************************************************************************************/
    PROCEDURE INTERFACE_LOAD_PRC (x_retcode         OUT NUMBER,
                                  x_errbuff         OUT VARCHAR2,
                                  p_batch_low    IN     NUMBER,
                                  p_batch_high   IN     NUMBER,
                                  p_debug        IN     VARCHAR2)
    AS
        CURSOR invoice_c IS
            SELECT VENDOR_SITE_CODE, INVOICE_CURRENCY_CODE, VENDOR_NAME,
                   ORG_ID, NEW_ORG_ID, --VENDOR_ID,
                                       TYPE_1099,
                   INVOICE_AMOUNT, NEW_VENDOR_ID, NEW_VENDOR_SITE_ID,
                   terms_id, payment_method_lookup_code, gl_date,
                   goods_received_date, invoice_received_date, terms_date,
                   SOURCE, pay_group_lookup_code, new_acctpay_ccid,
                   --Start Modification by Naveen 23-Jun-2015
                   record_id, --End Modification by Naveen 23-Jun-2015
                              --GROUP_ID,
                              NTILE (10) OVER (ORDER BY RECORD_ID) GROUP_NUM
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE     batch_number BETWEEN p_batch_low AND p_batch_high
                   AND record_status = 'V';



        TYPE invoice_info_type IS TABLE OF invoice_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_tbl          invoice_info_type;



        TYPE request_id_tab_typ IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        CURSOR invoice_source_c IS
            SELECT DISTINCT source
              FROM ap_invoices_interface;

        TYPE invoice_info_source_type IS TABLE OF invoice_source_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_source_tbl   invoice_info_source_type;

        request_id_tab            request_id_tab_typ;

        -- ln_indx                   NUMBER;
        ln_invoice_id             NUMBER;
        ln_invoice_line_id        NUMBER;
        ln_conc_req_id            NUMBER;
        ln_inv_vald_req_id        NUMBER;
        lb_wait_for_request       BOOLEAN;
        lc_phase                  VARCHAR2 (10);
        lc_status                 VARCHAR2 (10);
        lc_dev_phase              VARCHAR2 (10);
        lc_dev_status             VARCHAR2 (10);
        lc_message                VARCHAR2 (500);
        lc_error_message          VARCHAR2 (1000);
        ln_counter                NUMBER;
    BEGIN
        gc_code_pointer   := 'Start Interface Load process';
        print_log_prc (p_debug, gc_code_pointer);

        --Start Interface Load process

        OPEN invoice_c;

        ln_counter        := 0;

        LOOP
            invoice_info_tbl.delete;

            gc_code_pointer   := 'After invoice_info_tbl.delete';
            print_log_prc (p_debug, gc_code_pointer);

            FETCH invoice_c BULK COLLECT INTO invoice_info_tbl LIMIT gn_limit;

            gc_code_pointer   := 'After  BULK COLLECT INTO invoice_info_tbl';
            print_log_prc (p_debug, gc_code_pointer);


            gc_code_pointer   :=
                   'After  BULK COLLECT INTO  invoice_info_tbl.COUNT - '
                || invoice_info_tbl.COUNT;
            print_log_prc (p_debug, gc_code_pointer);

            IF (invoice_info_tbl.COUNT > 0)
            THEN
                FOR lcu_invoice_rec IN 1 .. invoice_info_tbl.COUNT
                LOOP
                    BEGIN
                        FOR i IN 1 .. 2
                        LOOP
                            ln_counter   := ln_counter + 1;

                            SELECT ap_invoices_interface_s.NEXTVAL
                              INTO ln_invoice_id
                              FROM DUAL;

                            --Start Insert into  ap_invoices_interface

                            gc_code_pointer   :=
                                'Start Insert into  ap_invoices_interface';
                            print_log_prc (p_debug, gc_code_pointer);


                            INSERT INTO ap_invoices_interface (
                                            invoice_id,
                                            invoice_num,
                                            invoice_date,
                                            description,
                                            invoice_type_lookup_code,
                                            invoice_amount,
                                            invoice_currency_code,
                                            vendor_id,
                                            vendor_site_id,
                                            org_id,
                                            --terms_id,
                                            --payment_method_lookup_code,
                                            gl_date,
                                            --goods_received_date,
                                            --invoice_received_date,
                                            --terms_date,
                                            add_tax_to_inv_amt_flag, -- added by Krishna 16-May-15
                                            SOURCE,
                                            pay_group_lookup_code,
                                            GROUP_ID,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by      --ATTRIBUTE15
                                                           )
                                 VALUES (ln_invoice_id, invoice_info_tbl (lcu_invoice_rec).NEW_VENDOR_ID || '-' || invoice_info_tbl (lcu_invoice_rec).NEW_VENDOR_SITE_ID || '-' || '1099' || '-' || DECODE (i,  1, 'INV_',  2, 'CM_') || invoice_info_tbl (lcu_invoice_rec).NEW_org_id, SYSDATE, 'Conversion', DECODE (i,  1, 'STANDARD',  2, 'CREDIT'), DECODE (i,  1, invoice_info_tbl (lcu_invoice_rec).INVOICE_AMOUNT,  2, (-1 * invoice_info_tbl (lcu_invoice_rec).INVOICE_AMOUNT)), invoice_info_tbl (lcu_invoice_rec).invoice_currency_code, invoice_info_tbl (lcu_invoice_rec).NEW_VENDOR_ID, invoice_info_tbl (lcu_invoice_rec).NEW_VENDOR_SITE_ID, invoice_info_tbl (lcu_invoice_rec).NEW_org_id, --invoice_info_tbl (lcu_invoice_rec).terms_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            --invoice_info_tbl (lcu_invoice_rec).payment_method_lookup_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            invoice_info_tbl (lcu_invoice_rec).gl_date, --invoice_info_tbl (lcu_invoice_rec).goods_received_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        --invoice_info_tbl (lcu_invoice_rec).invoice_received_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        --invoice_info_tbl (lcu_invoice_rec).terms_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        'N', -- added by Krishna 16-May-15
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             'CONVERSIONS', --invoice_info_tbl (lcu_invoice_rec).PAY_GROUP_LOOKUP_CODE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            'XXD_1099', invoice_info_tbl (lcu_invoice_rec).group_num, gn_req_id, gd_sysdate, gn_user_id
                                         , gd_sysdate, gn_user_id --invoice_info_tbl (lcu_invoice_rec).ATTRIBUTE15
                                                                 );

                            SELECT ap_invoice_lines_interface_s.NEXTVAL
                              INTO ln_invoice_line_id
                              FROM DUAL;

                            gc_code_pointer   :=
                                'Start Insert into  ap_invoice_lines_interface';
                            print_log_prc (p_debug, gc_code_pointer);

                            INSERT INTO ap_invoice_lines_interface (
                                            invoice_id,
                                            invoice_line_id,
                                            line_number,
                                            line_type_lookup_code,
                                            amount,
                                            DIST_CODE_COMBINATION_ID,
                                            org_id,
                                            --description,
                                            accounting_date,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by)
                                     VALUES (
                                                ln_invoice_id,
                                                ln_invoice_line_id,
                                                1,
                                                'ITEM', --decode(invoice_line_info_tbl (lcu_inv_line_rec).line_type_lookup_code,'NONREC_TAX','TAX',invoice_line_info_tbl (lcu_inv_line_rec).line_type_lookup_code),
                                                DECODE (
                                                    i,
                                                    1, invoice_info_tbl (
                                                           lcu_invoice_rec).INVOICE_AMOUNT,
                                                    2, (-1 * invoice_info_tbl (lcu_invoice_rec).INVOICE_AMOUNT)),
                                                invoice_info_tbl (
                                                    lcu_invoice_rec).new_acctpay_ccid,
                                                invoice_info_tbl (
                                                    lcu_invoice_rec).NEW_ORG_ID,
                                                --invoice_line_info_tbl (lcu_inv_line_rec).line_desc,
                                                --gd_sysdate,
                                                invoice_info_tbl (
                                                    lcu_invoice_rec).gl_date,
                                                gd_sysdate,
                                                gn_user_id,
                                                gd_sysdate,
                                                gn_user_id);
                        END LOOP;

                        --Start Modification by Naveen 23-Jun-2015
                        UPDATE XXD_AP_1099_INV_CONV_STG_T
                           SET record_status   = 'L'
                         WHERE record_id =
                               invoice_info_tbl (lcu_invoice_rec).record_id;
                    --End Modification by Naveen 23-Jun-2015
                    END;
                END LOOP;
            --END IF;

            --EXIT WHEN inv_line_c%NOTFOUND;
            --END LOOP;
            --END LOOP;
            END IF;

            IF ln_counter = gn_limit
            THEN
                COMMIT;
                ln_counter   := 0;
            END IF;

            EXIT WHEN invoice_c%NOTFOUND;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   :=
                   'Unexpected error occured in the procedure interface_load_prc while processing :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_error_message);

            XXD_common_utils.record_error (
                'APINV',
                XXD_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Unexpected error occured in the procedure interface_load_prc while processing');
    END INTERFACE_LOAD_PRC;

    /******************************************************
       * Procedure: XXD_AP_INVOICE_MAIN_PRC
       *
       * Synopsis: This procedure will call we be called by the concurrent program
       * Design:
       *
       * Notes:
       *
       * PARAMETERS:
       *   OUT: (x_retcode  Number
       *   OUT: x_errbuf  Varchar2
       *   IN    : p_process  varchar2
       *   IN    : p_debug  varchar2
       *
       * Return Values:
       * Modifications:
       *
       ******************************************************/

    PROCEDURE XXD_AP_1099_INV_MAIN_PRC (x_retcode            OUT NUMBER,
                                        x_errbuf             OUT VARCHAR2,
                                        p_process         IN     VARCHAR2,
                                        p_debug           IN     VARCHAR2,
                                        p_batch_size      IN     NUMBER,
                                        p_validate_item   IN     VARCHAR2,
                                        p_extract_date    IN     VARCHAR2,
                                        p_gl_date         IN     VARCHAR2)
    IS
        x_errcode                     VARCHAR2 (500);
        x_errmsg                      VARCHAR2 (500);
        lc_debug_flag                 VARCHAR2 (1);
        ln_eligible_records           NUMBER;
        ln_total_valid_records        NUMBER;
        ln_total_error_records        NUMBER;
        ln_total_load_records         NUMBER;
        ln_batch_low                  NUMBER;
        ln_total_batch                NUMBER;
        ln_request_id                 NUMBER;
        lc_phase                      VARCHAR2 (100);
        lc_status                     VARCHAR2 (100);
        lc_dev_phase                  VARCHAR2 (100);
        lc_dev_status                 VARCHAR2 (100);
        lc_message                    VARCHAR2 (100);
        lb_wait_for_request           BOOLEAN := FALSE;
        lb_get_request_status         BOOLEAN := FALSE;
        request_submission_failed     EXCEPTION;
        request_completion_abnormal   EXCEPTION;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                      request_table;
        ln_counter                    NUMBER;

        CURSOR invoice_ORG_c IS
            SELECT DISTINCT org_id
              FROM ap_invoices_interface
             WHERE status = 'REJCTED' OR status IS NULL;

        TYPE invoice_info_org_type IS TABLE OF invoice_org_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_org_tbl          invoice_info_org_type;
    BEGIN
        gc_debug_flag   := p_debug;

        --EXTRACT

        IF p_process = 'EXTRACT'
        THEN
            IF p_debug = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            -- Calling extract_invoice_proc proceudre
            extract_invoice_proc (p_extract_date, p_gl_date);
        --Validating Records in stagnig table

        ELSIF     p_process = 'VALIDATE'
              AND NVL (p_validate_item, 'STAGING') = 'STAGING'
        THEN
            ln_eligible_records      := 0;
            ln_batch_low             := 0;
            ln_total_batch           := 0;
            ln_total_valid_records   := 0;
            ln_total_error_records   := 0;

            --Checking if there are eligible records in staging table for Validation

            SELECT COUNT (*)
              INTO ln_eligible_records
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE record_status IN ('N', 'E');


            print_log_prc (p_debug,
                           'ln_eligible_records : ' || ln_eligible_records);

            IF ln_eligible_records > 0
            THEN
                -- Calling Create bathc Process to create divide recors in the staging table into batches.

                create_batch_prc (x_retcode, x_errbuf, p_batch_size,
                                  p_debug);

                -- Fetching Max Batch Number

                SELECT MAX (batch_number)
                  INTO ln_total_batch
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE record_status IN ('N', 'E');

                print_log_prc (p_debug,
                               'ln_total_batch : ' || ln_total_batch);

                -- Fetching Min Batch Number

                SELECT MIN (batch_number)
                  INTO ln_batch_low
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE record_status IN ('N', 'E');

                print_log_prc (p_debug, 'ln_batch_low : ' || ln_batch_low);

                l_req_id.delete;

                -- Looping to launch Validate worker

                FOR l_cnt IN ln_batch_low .. ln_total_batch
                LOOP
                    -- Check if each batch has eligible recors ,if so launch worker program

                    SELECT COUNT (*)
                      INTO ln_counter
                      FROM XXD_AP_1099_INV_CONV_STG_T
                     WHERE     record_status IN ('N', 'E')
                           AND batch_number = l_cnt;

                    IF ln_counter > 0
                    THEN
                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDCONV',
                                program       =>
                                    'XXD_AP_1099_INV_CONV_VAL_WORK',
                                description   =>
                                    'Deckers AP 1099 Invoice Conversion - Validate',
                                start_time    => gd_sysdate,
                                sub_request   => NULL,
                                argument1     => l_cnt,
                                argument2     => l_cnt,
                                argument3     => p_debug);


                        IF ln_request_id > 0
                        THEN
                            l_req_id (l_cnt)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    END IF;
                END LOOP;

                --Waits for the Child requests completion
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    BEGIN
                        IF l_req_id (rec) IS NOT NULL
                        THEN
                            LOOP
                                lc_dev_phase    := NULL;
                                lc_dev_status   := NULL;
                                lb_wait_for_request   :=
                                    fnd_concurrent.wait_for_request (
                                        request_id   => l_req_id (rec),
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
                        ELSE
                            RAISE request_submission_failed;
                        END IF;
                    EXCEPTION
                        WHEN request_submission_failed
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Child Concurrent request submission failed - '
                                || ' XXD_AP_INV_CONV_VAL_WORK - '
                                || ln_request_id
                                || ' - '
                                || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Submitted request completed with error'
                                || ' XXD_INV_CONV_VAL_WORK - '
                                || ln_request_id);
                        WHEN OTHERS
                        THEN
                            print_log_prc (
                                p_debug,
                                   'XXD_INV_CONV_VAL_WORK ERROR: '
                                || SUBSTR (SQLERRM, 0, 240));
                    END;
                END LOOP;

                COMMIT;



                SELECT COUNT (*)
                  INTO ln_total_valid_records
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE     record_status = 'V'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                SELECT COUNT (*)
                  INTO ln_total_error_records
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE     record_status = 'E'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                -- Writing counts to the output file

                fnd_file.put_line (fnd_file.output, '');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('S No.    Entity', 50)
                    || RPAD ('Total_Records', 20)
                    || RPAD ('Total_Records_Valid', 20)
                    || RPAD ('Total_Records_Error', 20));
                fnd_file.put_line (
                    fnd_file.output,
                    RPAD (
                        '********************************************************************************************************************************',
                        120));
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('1  AP Invoices', 50)
                    || RPAD (ln_eligible_records, 20)
                    || RPAD (ln_total_valid_records, 20)
                    || RPAD (ln_total_error_records, 20));
            ELSE
                print_log_prc (
                    p_debug,
                    'No Eligible Records for Validate Found - ' || SQLERRM);
            END IF;
        --LOAD

        ELSIF p_process = 'LOAD'
        THEN
            ln_eligible_records      := 0;
            ln_batch_low             := 0;
            ln_total_batch           := 0;
            ln_total_load_records    := 0;
            ln_total_error_records   := 0;

            --Checking if there are eligible records in staging table for Load

            SELECT COUNT (*)
              INTO ln_eligible_records
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE record_status = 'V' AND batch_number IS NOT NULL;

            IF ln_eligible_records > 0
            THEN
                -- Fetching Max Batch Number

                SELECT MAX (batch_number)
                  INTO ln_total_batch
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE record_status = 'V' AND batch_number IS NOT NULL;

                -- Fetching Min Batch Number

                SELECT MIN (batch_number)
                  INTO ln_batch_low
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE record_status = 'V' AND batch_number IS NOT NULL;

                l_req_id.delete;

                --Looping though batch number to launch Load worker

                FOR l_cnt IN ln_batch_low .. ln_total_batch
                LOOP
                    -- Checking if each batch number has eligible records,if so launch load worker

                    SELECT COUNT (*)
                      INTO ln_counter
                      FROM XXD_AP_1099_INV_CONV_STG_T
                     WHERE record_status IN ('V') AND batch_number = l_cnt;

                    IF ln_counter > 0
                    THEN
                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDCONV',
                                program       =>
                                    'XXD_AP_1099_INV_CONV_LOAD_WORK',
                                description   =>
                                    'Deckers AP 1099 Invoice Conversion - Load',
                                start_time    => gd_sysdate,
                                sub_request   => NULL,
                                argument1     => l_cnt,
                                argument2     => l_cnt,
                                argument3     => p_debug);


                        IF ln_request_id > 0
                        THEN
                            l_req_id (l_cnt)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    END IF;
                END LOOP;


                --Waits for the Child requests completion
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    BEGIN
                        IF l_req_id (rec) IS NOT NULL
                        THEN
                            LOOP
                                lc_dev_phase    := NULL;
                                lc_dev_status   := NULL;
                                lb_wait_for_request   :=
                                    fnd_concurrent.wait_for_request (
                                        request_id   => l_req_id (rec),
                                        interval     => 1,
                                        max_wait     => 1,
                                        phase        => lc_phase,
                                        status       => lc_status,
                                        dev_phase    => lc_dev_phase,
                                        dev_status   => lc_dev_status,
                                        MESSAGE      => lc_message);
                                COMMIT;

                                IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                THEN
                                    EXIT;
                                END IF;
                            END LOOP;
                        ELSE
                            RAISE request_submission_failed;
                        END IF;
                    EXCEPTION
                        WHEN request_submission_failed
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Child Concurrent request submission failed - '
                                || ' XXD_INV_CONV_LOAD_WORK - '
                                || ln_request_id
                                || ' - '
                                || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Submitted request completed with error'
                                || ' XXD_INV_CONV_LOAD_WORK - '
                                || ln_request_id);
                        WHEN OTHERS
                        THEN
                            print_log_prc (
                                p_debug,
                                   'XXD_INV_CONV_VAL_WORK ERROR:'
                                || SUBSTR (SQLERRM, 0, 240));
                    END;
                END LOOP;

                invoice_info_org_tbl.delete;

                gc_code_pointer   := 'After invoice_info_org_tbl.delete';
                print_log_prc (p_debug, gc_code_pointer);

                --Fetch Distinct org_id from Interface tables that are not processed or in error.

                OPEN invoice_org_c;

                FETCH invoice_org_c BULK COLLECT INTO invoice_info_org_tbl;

                CLOSE invoice_org_c;

                gc_code_pointer   :=
                    'After  BULK COLLECT INTO invoice_info_tbl';
                print_log_prc (p_debug, gc_code_pointer);


                gc_code_pointer   :=
                       'After  BULK COLLECT INTO  invoice_info_org_tbl.COUNT - '
                    || invoice_info_org_tbl.COUNT;
                print_log_prc (p_debug, gc_code_pointer);

                --If above fetched org_id has count > 1 call import_invoice _from_interface for each org_id

                IF (invoice_info_org_tbl.COUNT > 0)
                THEN
                    FOR lcu_invoice_rec IN 1 .. invoice_info_org_tbl.COUNT
                    LOOP
                        IMPORT_INVOICE_FROM_INTERFACE (
                            p_ORG_id       =>
                                invoice_info_org_tbl (lcu_invoice_rec).org_id,
                            p_DEBUG_FLAG   => p_debug,
                            p_gl_date      => p_gl_date);
                    END LOOP;
                END IF;



                SELECT COUNT (*)
                  INTO ln_total_load_records
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE     record_status IN ('L', 'P')
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                SELECT COUNT (*)
                  INTO ln_total_error_records
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE                          --book_type_code = p_book_type
                           record_status = 'E'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;


                --Writing counts to output file

                fnd_file.put_line (fnd_file.output, '');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('S No.    Entity', 50)
                    || RPAD ('Total_Records', 20)
                    || RPAD ('Total_Records_Load', 20)
                    || RPAD ('Total_Records_Error', 20));
                fnd_file.put_line (
                    fnd_file.output,
                    RPAD (
                        '********************************************************************************************************************************',
                        120));
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('1     AP Invoices', 50)
                    || RPAD (ln_eligible_records, 20)
                    || RPAD (ln_total_load_records, 20)
                    || RPAD (ln_total_error_records, 20));
            ELSE
                print_log_prc (
                    p_debug,
                    'No Eligible Records for Load Found - ' || SQLERRM);
            END IF;
        -- Validate the invoice once the invoice is created by calling payables open interface

        ELSIF p_process = 'VALIDATE' AND p_validate_item = 'INVOICE'
        THEN
            ln_eligible_records      := 0;
            ln_batch_low             := 0;
            ln_total_batch           := 0;
            ln_total_load_records    := 0;
            ln_total_error_records   := 0;

            --Checking if there are eligible records in staging table for which invoic eis created in AP_INVOICES_ALL table

            SELECT COUNT (stg.old_invoice_id)
              INTO ln_eligible_records
              FROM apps.ap_invoices_all aia, apps.ap_batches_all aba, XXD_CONV.XXD_AP_1099_INV_conv_stg_T stg
             WHERE     aia.batch_id = aba.batch_id
                   AND aia.invoice_num = stg.invoice_num
                   AND stg.record_status = 'P';

            --  calling Invoice_validate Worker

            IF ln_eligible_records > 0
            THEN
                VALIDATE_INVOICE (p_DEBUG_FLAG => p_debug);



                SELECT COUNT (*)
                  INTO ln_total_load_records
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE     record_status = 'CM_VAL'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                SELECT COUNT (*)
                  INTO ln_total_error_records
                  FROM XXD_AP_1099_INV_CONV_STG_T
                 WHERE                          --book_type_code = p_book_type
                           record_status = 'E'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                -- Writing counts to output file

                fnd_file.put_line (fnd_file.output, '');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('S No.    Entity', 50)
                    || RPAD ('Total_Records', 20)
                    || RPAD ('Total_Records_Load', 20)
                    || RPAD ('Total_Records_Error', 20));
                fnd_file.put_line (
                    fnd_file.output,
                    RPAD (
                        '********************************************************************************************************************************',
                        120));
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('1     AP Invoices', 50)
                    || RPAD (ln_eligible_records, 20)
                    || RPAD (ln_total_load_records, 20)
                    || RPAD (ln_total_error_records, 20));
            ELSE
                print_log_prc (
                    p_debug,
                    'No Eligible Records for Load Found - ' || SQLERRM);
            END IF;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Please select a valid process');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in AP Invoice Conversion '
                || SUBSTR (1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                'Error Message extract_cust_prc ' || SUBSTR (1, 250);
    END XXD_AP_1099_INV_MAIN_PRC;


    /****************************************************************************************
   * Procedure : VALIDATE_RECORDS_PRC
   * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
   * Design    : Procedure validates data for AP Invoice conversion
   * Notes     :
   * Return Values: None
   * Modification :
   * Date          Developer     Version    Description
   *--------------------------------------------------------------------------------------
   * 07-JUL-2014   Swapna N        1.00       Created
   ****************************************************************************************/

    PROCEDURE VALIDATE_RECORDS_PRC (x_retcode         OUT NUMBER,
                                    x_errbuff         OUT VARCHAR2,
                                    p_batch_low    IN     NUMBER,
                                    p_batch_high   IN     NUMBER,
                                    p_debug        IN     VARCHAR2)
    AS
        CURSOR invoice_c IS
            SELECT *
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE     batch_number BETWEEN p_batch_low AND p_batch_high
                   AND record_status IN ('E', 'N');


        --Start modification by Naveen on 24-Jun-2015
        /*CURSOR vendor_id_c (p_vendor_name VARCHAR2)
        IS
           SELECT vendor_id
             FROM ap_suppliers
            WHERE vendor_name = p_vendor_name;*/
        CURSOR vendor_id_c (p_vendor_num VARCHAR2)
        IS
            SELECT vendor_id
              FROM ap_suppliers
             WHERE segment1 = p_vendor_num;

        --End Modification by Naveen on 24-Jun-2015


        CURSOR vendor_site_id_c (p_vendor_id NUMBER, p_vendor_site_code VARCHAR2, p_org_id NUMBER)
        IS
            SELECT vendor_site_id
              FROM ap_supplier_sites_all
             WHERE     vendor_id = p_vendor_id
                   AND vendor_site_code = p_vendor_site_code
                   AND org_id = p_org_id;


        TYPE invoice_info_type IS TABLE OF invoice_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_tbl         invoice_info_type;



        lc_lookup_code           fnd_lookup_values.lookup_code%TYPE;
        lc_line_lookup_code      fnd_lookup_values.lookup_code%TYPE;
        ln_invoice_id            NUMBER;
        ln_vendor_site_id        NUMBER;
        lc_payment_method_code   VARCHAR2 (100);
        ln_invoice_num           VARCHAR2 (50);
        lc_source                VARCHAR2 (100);
        ln_term_id               NUMBER;
        ln_vendor_id             NUMBER;
        lc_recvalidation         VARCHAR2 (1);
        LC_REC_LINE_VALIDATION   VARCHAR2 (1);
        lc_h_err_msg             VARCHAR2 (1000);
        lc_l_err_msg             VARCHAR2 (1000);
        lc_error_code            VARCHAR2 (100);
        lc_err_message           VARCHAR2 (1000);
        l_valid_combination      BOOLEAN;
        l_cr_combination         BOOLEAN;
        ln_ccid                  GL_CODE_COMBINATIONS.code_combination_id%TYPE;
        lc_conc_segs             GL_CODE_COMBINATIONS_KFV.CONCATENATED_SEGMENTS%TYPE;
        p_error_msg1             VARCHAR2 (2400);
        p_error_msg2             VARCHAR2 (2400);
        l_coa_id                 GL_CODE_COMBINATIONS_KFV.CHART_OF_ACCOUNTS_ID%TYPE;
        ln_err_count             NUMBER;
        ln_line_err_count        NUMBER;
        ln_org_id                NUMBER;
        lc_org_name              VARCHAR2 (100);
        lc_new_conc_segs         GL_CODE_COMBINATIONS_KFV.CONCATENATED_SEGMENTS%TYPE;
    BEGIN
        --Loop through all the invoices;
        OPEN invoice_c;

        LOOP
            invoice_info_tbl.delete;

            FETCH invoice_c BULK COLLECT INTO invoice_info_tbl LIMIT gn_limit;



            IF (invoice_info_tbl.COUNT > 0)
            THEN
                FOR lcu_invoice_rec IN 1 .. invoice_info_tbl.COUNT
                LOOP
                    BEGIN
                        ln_err_count      := 0;
                        ln_org_id         := NULL;
                        print_log_prc (
                            p_debug,
                            'START**********************************************************************************START');

                        gc_code_pointer   :=
                               'Start Invoice Validation for Vendor Num : '
                            || invoice_info_tbl (lcu_invoice_rec).VENDOR_NUM;
                        print_log_prc (p_debug, gc_code_pointer);


                        get_new_org_id (p_old_org_name => invoice_info_tbl (lcu_invoice_rec).operating_unit, p_debug_flag => p_debug, x_new_org_id => ln_org_id
                                        , x_new_org_name => lc_org_name);

                        print_log_prc (p_debug,
                                       'New ORG Id is :' || ln_org_id);
                        print_log_prc (p_debug,
                                       'New Operating Unit :' || lc_org_name);

                        IF ln_org_id IS NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   :=
                                   'Org ID is not defined for the invoice  '
                                || invoice_info_tbl (lcu_invoice_rec).invoice_num;

                            print_log_prc (p_debug, lc_h_err_msg);

                            XXD_common_utils.record_error (
                                'APINV',
                                XXD_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_INVOICE_CONV_STG_T');
                        END IF;



                        --Vendor validation

                        gc_code_pointer   := 'Vendor Name validation';
                        print_log_prc (p_debug, gc_code_pointer);

                        IF vendor_id_c%ISOPEN
                        THEN
                            CLOSE vendor_id_c;
                        END IF;

                        --Start modification by Naveen on 24-Jun-2015
                        --OPEN vendor_id_c (invoice_info_tbl (lcu_invoice_rec).VENDOR_NAME);
                        OPEN vendor_id_c (
                            invoice_info_tbl (lcu_invoice_rec).vendor_num);

                        --Start modification by Naveen on 24-Jun-2015

                        ln_vendor_id      := NULL;

                        FETCH vendor_id_c INTO ln_vendor_id;

                        CLOSE vendor_id_c;

                        fnd_file.put_line (fnd_file.LOG,
                                           'Vendor id ' || ln_vendor_id);

                        IF ln_vendor_id IS NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   := --   'Vendor  validation failed for vendor  '
                                              --|| invoice_info_tbl (lcu_invoice_rec).VENDOR_NAME;
                                              'Vendor does not exist';

                            print_log_prc (p_debug, lc_h_err_msg);

                            XXD_common_utils.record_error (
                                'APINV',
                                XXD_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_1099_INV_CONV_STG_T');
                        END IF;


                        --Vendor site code validation
                        IF ln_vendor_id IS NOT NULL AND ln_org_id IS NOT NULL
                        THEN
                            gc_code_pointer     :=
                                'Vendor site code validation';
                            print_log_prc (p_debug, gc_code_pointer);

                            IF vendor_site_id_c%ISOPEN
                            THEN
                                CLOSE vendor_site_id_c;
                            END IF;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'VENDOR_SITE_CODE '
                                || invoice_info_tbl (lcu_invoice_rec).VENDOR_SITE_CODE);

                            OPEN vendor_site_id_c (
                                ln_vendor_id,
                                invoice_info_tbl (lcu_invoice_rec).VENDOR_SITE_CODE,
                                ln_org_id);

                            ln_vendor_site_id   := NULL;

                            FETCH vendor_site_id_c INTO ln_vendor_site_id;

                            CLOSE vendor_site_id_c;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'ln_vendor_site_id ' || ln_vendor_site_id);

                            IF ln_vendor_site_id IS NULL
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    --   'Vendor site code validation failed for invoice '
                                    --|| invoice_info_tbl (lcu_invoice_rec).old_invoice_id;
                                     'Vendor site does not exist';

                                print_log_prc (p_debug, lc_h_err_msg);

                                XXD_common_utils.record_error (
                                    'APINV',
                                    XXD_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_1099_INV_CONV_STG_T');
                            END IF;
                        END IF;



                        -- ORG_ID Check


                        -- ccid derivation added by Krishna on 16-May-15 V1.1
                        --Derive code combination id.
                        --Its hardcoded value per OU

                        IF ln_org_id IS NOT NULL
                        THEN
                            BEGIN
                                ln_ccid   := NULL;

                                IF (invoice_info_tbl (lcu_invoice_rec).operating_unit = 'Deckers US')
                                THEN                      -- for Deckers US OU
                                    SELECT code_combination_id
                                      INTO ln_ccid
                                      FROM gl_code_combinations
                                     WHERE    segment1
                                           || '.'
                                           || segment2
                                           || '.'
                                           || segment3
                                           || '.'
                                           || segment4
                                           || '.'
                                           || segment5
                                           || '.'
                                           || segment6
                                           || '.'
                                           || segment7
                                           || '.'
                                           || segment8 =
                                           '100.1000.101.100.1000.11698.100.1000';
                                ELSIF (invoice_info_tbl (lcu_invoice_rec).operating_unit = 'Deckers RETAIL')
                                THEN               -- for Deckers US Retail OU
                                    SELECT code_combination_id
                                      INTO ln_ccid
                                      FROM gl_code_combinations
                                     WHERE    segment1
                                           || '.'
                                           || segment2
                                           || '.'
                                           || segment3
                                           || '.'
                                           || segment4
                                           || '.'
                                           || segment5
                                           || '.'
                                           || segment6
                                           || '.'
                                           || segment7
                                           || '.'
                                           || segment8 =
                                           '700.1000.101.100.1000.11698.700.1000';
                                ELSIF (invoice_info_tbl (lcu_invoice_rec).operating_unit = 'Deckers US eCommerce')
                                THEN            -- for Deckers US eCommerce OU
                                    SELECT code_combination_id
                                      INTO ln_ccid
                                      FROM gl_code_combinations
                                     WHERE    segment1
                                           || '.'
                                           || segment2
                                           || '.'
                                           || segment3
                                           || '.'
                                           || segment4
                                           || '.'
                                           || segment5
                                           || '.'
                                           || segment6
                                           || '.'
                                           || segment7
                                           || '.'
                                           || segment8 =
                                           '600.1000.101.100.1000.11698.600.1000';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_err_count   := ln_err_count + 1;
                                    lc_h_err_msg   :=
                                           'Code combination not defined for OU '
                                        || invoice_info_tbl (lcu_invoice_rec).operating_unit;

                                    print_log_prc (p_debug, lc_h_err_msg);

                                    XXD_common_utils.record_error (
                                        'APINV',
                                        XXD_common_utils.get_org_id,
                                        'Deckers AP Invoice Conversion Program',
                                        lc_h_err_msg,
                                        DBMS_UTILITY.format_error_backtrace,
                                        gn_user_id,
                                        gn_req_id,
                                        'Code pointer : ' || gc_code_pointer,
                                        'XXD_AP_INVOICE_CONV_STG_T');
                            END;
                        END IF;

                        print_log_prc (p_debug, 'ln_org_id :' || ln_org_id);

                        IF ln_err_count = 0        --AND ln_line_err_count = 0
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Before setting invoice record status to V for Invoice :'
                                || invoice_info_tbl (lcu_invoice_rec).old_invoice_id);

                            UPDATE XXD_AP_1099_INV_CONV_STG_T
                               SET NEW_VENDOR_ID = ln_vendor_id, NEW_VENDOR_SITE_ID = ln_vendor_site_id, record_status = 'V',
                                   error_message = NULL, terms_id = ln_term_id, request_id = gn_req_id,
                                   last_update_date = gd_sysdate, last_updated_by = gn_user_id, new_org_id = ln_org_id,
                                   new_acctpay_ccid = ln_ccid
                             WHERE     old_vendor_id =
                                       invoice_info_tbl (lcu_invoice_rec).old_vendor_id
                                   AND old_vendor_site_id =
                                       invoice_info_tbl (lcu_invoice_rec).old_vendor_site_id
                                   AND org_id =
                                       invoice_info_tbl (lcu_invoice_rec).org_id;

                            COMMIT;
                            print_log_prc (
                                p_debug,
                                'After setting invoice record status to V');
                        ELSE
                            print_log_prc (
                                p_debug,
                                'Before setting invoice record status to E');

                            UPDATE XXD_AP_1099_INV_CONV_STG_T
                               SET record_status = 'E', error_message = lc_h_err_msg, request_id = gn_req_id,
                                   last_update_date = gd_sysdate, last_updated_by = gn_user_id, new_org_id = ln_org_id,
                                   NEW_VENDOR_ID = ln_vendor_id, NEW_VENDOR_SITE_ID = ln_vendor_site_id
                             WHERE     old_vendor_id =
                                       invoice_info_tbl (lcu_invoice_rec).old_vendor_id
                                   AND old_vendor_site_id =
                                       invoice_info_tbl (lcu_invoice_rec).old_vendor_site_id
                                   AND org_id =
                                       invoice_info_tbl (lcu_invoice_rec).org_id;
                        END IF;

                        --EXIT WHEN invoice_line_c%NOTFOUND;
                        --END LOOP; */

                        print_log_prc (
                            p_debug,
                            'END**********************************************************************************END');
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_error_code    := SQLCODE;
                            lc_err_message   := SUBSTR (SQLERRM, 1, 250);

                            XXD_common_utils.record_error (
                                'APINV',
                                XXD_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_err_message,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                lc_err_message,
                                'Code pointer : ' || gc_code_pointer);
                    END;
                END LOOP;
            END IF;

            EXIT WHEN invoice_c%NOTFOUND;
        END LOOP;

        BEGIN
            SELECT COUNT (*)
              INTO gn_inv_extract
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE     record_status = 'V'
                   AND batch_number BETWEEN p_batch_low AND p_batch_high;
        END;

        --Writing counts to output file

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers AP Invoice Conversion Program for Validation');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records validated in XXD_AP_1099_INV_CONV_STG_T Table '
            || gn_inv_extract);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF invoice_c%ISOPEN
            THEN
                CLOSE invoice_c;
            END IF;



            lc_err_message   :=
                   'Unexpected error occured in the procedure Validate while processing :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_err_message);

            XXD_common_utils.record_error (
                'APINV',
                XXD_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_err_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_req_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer);
    END VALIDATE_RECORDS_PRC;


    /****************************************************************************************
     * Procedure : CREATE_BATCH_PRC
     * Synopsis  : This Procedure shall create batch Processes
     * Design    : Program input p_batch_size is considered to divide records and batch number is assigned
     * Notes     :
     * Return Values: None
     * Modification :
     * Date          Developer     Version    Description
     *--------------------------------------------------------------------------------------
     * 07-JUL-2014   Swapna N        1.00       Created
     ****************************************************************************************/


    PROCEDURE CREATE_BATCH_PRC (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_batch_size IN NUMBER
                                , p_debug IN VARCHAR2)
    AS
        /* Variable Declaration*/
        ln_count          NUMBER;
        ln_batch_count    NUMBER;
        ln_batch_number   NUMBER;
        ln_first_rec      NUMBER;
        ln_last_rec       NUMBER;
        ln_end_rec        NUMBER;
    BEGIN
        ln_count         := 0;
        ln_batch_count   := 1;
        ln_first_rec     := 1;
        ln_last_rec      := 1;
        ln_end_rec       := 1;

        --Getting count of records and min and max record_id's.

        SELECT COUNT (record_id), MIN (record_id), MAX (record_id)
          INTO ln_count, ln_first_rec, ln_last_rec
          FROM XXD_AP_1099_INV_CONV_STG_T
         WHERE record_status IN ('N', 'E') AND batch_number IS NULL;

        print_log_prc (p_debug, 'ln_count : ' || ln_count);
        print_log_prc (p_debug, 'ln_first_rec : ' || ln_first_rec);
        print_log_prc (p_debug, 'ln_last_rec : ' || ln_last_rec);

        --Caluclating number of batches based on record count and batch size

        SELECT CEIL (ln_count / p_batch_size) INTO ln_batch_count FROM DUAL;

        print_log_prc (p_debug, 'ln_batch_count : ' || ln_batch_count);

        IF ln_batch_count <= 1
        THEN
            ln_batch_count   := 1;
        END IF;

        FOR lcu_batch_rec IN 1 .. ln_batch_count
        LOOP
            IF lcu_batch_rec <> 1
            THEN
                ln_first_rec   := ln_first_rec + p_batch_size;
            END IF;

            ln_end_rec        := (ln_first_rec + (p_batch_size - 1));

            IF lcu_batch_rec = ln_batch_count
            THEN
                ln_end_rec   := ln_last_rec;
            END IF;

            ln_batch_number   := XXD_AP_1099_INV_CONV_BATCH_S.NEXTVAL;
            print_log_prc (p_debug, 'ln_batch_number : ' || ln_batch_number);
            print_log_prc (p_debug, 'ln_first_rec : ' || ln_first_rec);
            print_log_prc (p_debug, 'ln_end_rec : ' || ln_end_rec);

            BEGIN
                print_log_prc (p_debug, 'Before Update : ');

                -- Updating staging tables record with corresponding batch number.

                UPDATE XXD_AP_1099_INV_CONV_STG_T
                   SET batch_number = ln_batch_number, last_update_date = gd_sysdate, last_updated_by = gn_user_id
                 WHERE     record_status IN ('N', 'E') --AND batch_number IS NULL
                       AND record_id BETWEEN ln_first_rec AND ln_end_rec;

                print_log_prc (p_debug, 'After Update : ');

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log_prc (
                        p_debug,
                        'Error while updating batch_number: ' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc (
                p_debug,
                   'Error in XXD_AP_1099_INV_CONV_PKG.create_batch_prc: '
                || SQLERRM);
    END CREATE_BATCH_PRC;


    /****************************************************************************************
          * Procedure : PRINT_LOG_PRC
          * Synopsis  : This Procedure shall write to the concurrent program log file
          * Design    : Program input debug flag is 'Y' then the procedure shall write the message
          *             input to concurrent program log file
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   Swapna N        1.00       Created
          ****************************************************************************************/

    PROCEDURE PRINT_LOG_PRC (p_debug_flag IN VARCHAR2, p_message IN VARCHAR2)
    IS
    BEGIN
        IF p_debug_flag = 'Y'
        THEN
            fnd_file.put_line (apps.fnd_file.LOG, p_message);
        END IF;
    END PRINT_LOG_PRC;

    /****************************************************************************************
         * Procedure : GET_NEW_ORG_ID
         * Synopsis  : This Procedure shall provide the new org_id for given 12.0 operating_unit name
         * Design    : Program input old_operating_unit_name is passed
         * Notes     :
         * Return Values: None
         * Modification :
         * Date          Developer     Version    Description
         *--------------------------------------------------------------------------------------
         * 07-JUL-2014   Swapna N        1.00       Created
         ****************************************************************************************/

    PROCEDURE GET_NEW_ORG_ID (p_old_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, x_NEW_ORG_ID OUT NUMBER
                              , x_new_org_name OUT VARCHAR2)
    IS
        lc_attribute2      VARCHAR2 (1000);
        lc_error_code      VARCHAR2 (1000);
        lC_error_msg       VARCHAR2 (1000);
        lc_attribute1      VARCHAR2 (1000);
        xc_meaning         VARCHAR2 (1000);
        xc_description     VARCHAR2 (1000);
        xc_lookup_code     VARCHAR2 (1000);
        ln_org_id          NUMBER;
        lc_error_message   VARCHAR2 (1000);

        CURSOR org_id_c (p_org_name VARCHAR2)
        IS
            SELECT organization_id
              FROM HR_OPERATING_UNITS
             WHERE name = p_org_name;
    BEGIN
        xc_meaning       := p_old_org_name;

        PRINT_LOG_PRC (p_debug_flag, 'p_old_org_name : ' || p_old_org_name);

        --Passing old operating unit name to fetch corresponding new operating_unit name


        XXD_COMMON_UTILS.GET_MAPPING_VALUE (
            p_lookup_type    => 'XXD_1206_OU_MAPPING',
            px_lookup_code   => xc_lookup_code,
            px_meaning       => xc_meaning,
            px_description   => xc_description,
            x_attribute1     => lc_attribute1,
            x_attribute2     => lc_attribute2,
            x_error_code     => lc_error_code,
            x_error_msg      => lc_error_msg);

        PRINT_LOG_PRC (p_debug_flag, 'lc_attribute1 : ' || lc_attribute1);

        x_new_org_name   := lc_attribute1;

        -- Calling cursor to fetch Org_id for a given operating_unit name.

        OPEN org_id_c (lc_attribute1);

        ln_org_id        := NULL;

        FETCH org_id_c INTO ln_org_id;

        CLOSE org_id_c;

        x_NEW_ORG_ID     := ln_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   :=
                   'Unexpected error occured in the procedure GET_NEW_ORG_ID :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_error_message);

            XXD_common_utils.record_error (
                'APINV',
                XXD_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Unexpected error occured in the procedure GET_NEW_ORG_ID ');
    END GET_NEW_ORG_ID;

    PROCEDURE IMPORT_INVOICE_FROM_INTERFACE (p_org_id IN NUMBER, p_debug_flag IN VARCHAR2, p_gl_date IN VARCHAR2)
    IS
        CURSOR invoice_source_c IS
            SELECT DISTINCT source
              FROM ap_invoices_interface
             WHERE org_id = p_org_id;

        TYPE invoice_info_source_type IS TABLE OF invoice_source_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_source_tbl   invoice_info_source_type;

        TYPE request_id_tab_typ IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        request_id_tab            request_id_tab_typ;
        ln_inv_vald_req_id        NUMBER;
        ln_conc_req_id            NUMBER;
        ln_inv_vald_req_id        NUMBER;
        lb_wait_for_request       BOOLEAN;
        lc_phase                  VARCHAR2 (10);
        lc_status                 VARCHAR2 (10);
        lc_dev_phase              VARCHAR2 (10);
        lc_dev_status             VARCHAR2 (10);
        lc_message                VARCHAR2 (500);
        lc_error_message          VARCHAR2 (1000);
    BEGIN
        PRINT_LOG_PRC (p_debug_flag, 'p_org_id is  : ' || p_org_id);



        gc_code_pointer   := 'fetch distinct source';
        print_log_prc (p_debug_flag, gc_code_pointer);

        -- Get Distinct source for giving operating unit from invoice interface table

        OPEN invoice_source_c;

        gc_code_pointer   :=
            'fetch distinct source count - ' || invoice_info_source_tbl.COUNT;
        print_log_prc (p_debug_flag, gc_code_pointer);

        invoice_info_source_tbl.delete;

        FETCH invoice_source_c BULK COLLECT INTO invoice_info_source_tbl;

        gc_code_pointer   :=
            'fetch distinct source count - ' || invoice_info_source_tbl.COUNT;
        print_log_prc (p_debug_flag, gc_code_pointer);

        -- Loop to launch payables open interface program for each source

        FOR lcu_inv_src_rec IN 1 .. invoice_info_source_tbl.COUNT
        LOOP
            ln_conc_req_id                     :=
                FND_REQUEST.SUBMIT_REQUEST ('SQLAP', 'APXIIMPT', NULL,
                                            NULL, FALSE, p_org_id,
                                            invoice_info_source_tbl (lcu_inv_src_rec).source, -- Source
                                                                                              NULL, -- Group ID
                                                                                                    'N/A', --'Conversion for source ' || i_inv_source.source ||'-'||i_inv_source.org_id||'-'||gn_Conc_request_id, -- Batch
                                                                                                           NULL, -- Hold Code
                                                                                                                 NULL, -- Hold Reason
                                                                                                                       --TO_CHAR (gd_sysdate, 'YYYY/MM/DD HH24:MI:SS'),       -- GL Date
                                                                                                                       p_gl_date, -- GL Date
                                                                                                                                  'N', -- Purge
                                                                                                                                       'N', 'Y', 'N', 1000, gn_user_id
                                            , 0);

            request_id_tab (lcu_inv_src_rec)   := ln_conc_req_id;

            IF ln_conc_req_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Sub-request failed to submit: Retcode-' || 1);
                RETURN;
            ELSE
                request_id_tab (request_id_tab.COUNT + 1)   := ln_conc_req_id;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Sub-request for process'
                    || '1 is '
                    || TO_CHAR (ln_conc_req_id));
            END IF;

            COMMIT;
        END LOOP;


        --Waiting for child program to complete

        FOR rec IN request_id_tab.FIRST .. request_id_tab.LAST
        LOOP
            IF request_id_tab (rec) IS NOT NULL
            THEN
                LOOP
                    lc_dev_phase    := NULL;
                    lc_dev_status   := NULL;
                    lb_wait_for_request   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => request_id_tab (rec), --ln_concurrent_request_id
                            INTERVAL     => 5,
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

        gc_code_pointer   := 'Updating record status in staging tables ';

        --Updating record status in staging tables

        UPDATE XXD_AP_1099_INV_CONV_STG_T XAIC
           SET record_status   = 'P'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM ap_invoices_all aia
                         WHERE     aia.invoice_num = XAIC.INVOICE_NUM
                               AND aia.vendor_id = XAIC.NEW_VENDOR_ID);



        BEGIN
            SELECT COUNT (*)
              INTO gn_inv_extract
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE record_status = 'P';
        END;


        --writing counts to output file

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers AP Invoice Conversion Program for Import');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records Processed in  XXD_AP_1099_INV_CONV_STG_T Table '
            || gn_inv_extract);
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   :=
                   'Unexpected error occured in the procedure interface_load_prc while processing :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_error_message);

            XXD_common_utils.record_error (
                'APINV',
                XXD_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer);
    END import_invoice_from_interface;


    /****************************************************************************************
       * Procedure : VALIDATE_INVOICE
       * Synopsis  : This Procedure will validate invoices created from open interface import
       * Design    :
       * Notes     :
       * Return Values: None
       * Modification :
       * Date          Developer     Version    Description
       *--------------------------------------------------------------------------------------
       * 07-JUL-2014   Swapna N        1.00       Created
       ****************************************************************************************/

    PROCEDURE VALIDATE_INVOICE (p_debug_flag IN VARCHAR2)
    IS
        CURSOR val_inv_c IS
            SELECT DISTINCT aba.batch_name batch_name, stg.org_id org_id, aba.batch_id batch_id
              FROM apps.ap_invoices_all aia, apps.ap_batches_all aba, XXD_CONV.XXD_AP_1099_INV_conv_stg_T stg
             WHERE     aia.batch_id = aba.batch_id
                   AND aia.invoice_num = stg.invoice_num
                   AND stg.record_status = 'P';

        TYPE invoice_val_type IS TABLE OF val_inv_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_val_tbl       invoice_val_type;

        TYPE request_id_tab_typ IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;


        request_id_tab        request_id_tab_typ;

        ln_inv_vald_req_id    NUMBER;
        ln_conc_req_id        NUMBER;
        ln_inv_vald_req_id    NUMBER;
        lb_wait_for_request   BOOLEAN;
        lc_phase              VARCHAR2 (10);
        lc_status             VARCHAR2 (10);
        lc_dev_phase          VARCHAR2 (10);
        lc_dev_status         VARCHAR2 (10);
        lc_message            VARCHAR2 (500);
        lc_error_message      VARCHAR2 (1000);
    BEGIN
        invoice_val_tbl.delete;

        gc_code_pointer   := 'After invoice_val_tbl.delete';
        print_log_prc (p_debug_flag, gc_code_pointer);

        OPEN val_inv_c;

        invoice_val_tbl.delete;

        FETCH val_inv_c BULK COLLECT INTO invoice_val_tbl;

        CLOSE val_inv_c;

        gc_code_pointer   := 'After  BULK COLLECT INTO invoice_val_tbl';
        print_log_prc (p_debug_flag, gc_code_pointer);


        gc_code_pointer   :=
               'After  BULK COLLECT INTO  invoice_val_tbl.COUNT - '
            || invoice_val_tbl.COUNT;
        print_log_prc (p_debug_flag, gc_code_pointer);

        request_id_tab.delete;

        -- Launching Invoice Validation in loop for distinct batch_name,batch_id and org_id from staging tbales for the invoices that got created in Ap_invoices_all table

        IF (invoice_val_tbl.COUNT > 0)
        THEN
            FOR lcu_invoice_rec IN 1 .. invoice_val_tbl.COUNT
            LOOP
                ln_conc_req_id                     :=
                    fnd_request.submit_request ('SQLAP', 'APPRVL', 'Invoice Validation', NULL, FALSE, invoice_val_tbl (lcu_invoice_rec).org_id, 'All', invoice_val_tbl (lcu_invoice_rec).batch_id, NULL, NULL, NULL, NULL
                                                , NULL, NULL, NULL      --'N',
                                                                        --1000
                                                );

                request_id_tab (lcu_invoice_rec)   := ln_conc_req_id;

                IF ln_conc_req_id = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Sub-request failed to submit: Retcode-' || 1);
                    RETURN;
                ELSE
                    request_id_tab (request_id_tab.COUNT + 1)   :=
                        ln_conc_req_id;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Sub-request for process'
                        || '1 is '
                        || TO_CHAR (ln_conc_req_id));
                END IF;

                COMMIT;
            END LOOP;


            FOR rec IN request_id_tab.FIRST .. request_id_tab.LAST
            LOOP
                IF request_id_tab (rec) IS NOT NULL
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait_for_request   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => request_id_tab (rec), --ln_concurrent_request_id
                                INTERVAL     => 5,
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

            gc_code_pointer   := 'Updating record status in staging tables ';

            --Updating record status in staging tables

            UPDATE XXD_AP_1099_INV_CONV_STG_T XAIC
               SET record_status   = 'INV_VAL'
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM ap_invoices_all aia
                             WHERE     aia.vendor_id = XAIC.NEW_VENDOR_ID
                                   AND aia.invoice_num = XAIC.invoice_num
                                   AND APPS.AP_INVOICES_PKG.GET_APPROVAL_STATUS (
                                           AIA.INVOICE_ID,
                                           AIA.INVOICE_AMOUNT,
                                           AIA.PAYMENT_STATUS_FLAG,
                                           AIA.INVOICE_TYPE_LOOKUP_CODE) =
                                       'V');
        END IF;

        BEGIN
            SELECT COUNT (*)
              INTO gn_inv_extract
              FROM XXD_AP_1099_INV_CONV_STG_T
             WHERE record_status = 'INV_VAL';
        END;

        --Writing counts to output file

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers AP Invoice Conversion Program for Import');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records Processed in  XXD_AP_1099_INV_CONV_STG_T Table '
            || gn_inv_extract);
    --      Update_CM (p_debug_flag);
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   :=
                   'Unexpected error occured in the procedure VALIDATE_INVOICE while processing :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_error_message);

            XXD_common_utils.record_error (
                'APINV',
                XXD_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_req_id,
                gn_req_id,
                'Unexpected error occured in the procedure VALIDATE_INVOICE while processing ');
    END VALIDATE_INVOICE;

    /****************************************************************************************
  * Procedure : Update_CM
  * Synopsis  : This Procedure updates creditmemo distribution to set type_1099 and income_tax_region to null
  * Design    :
  * Notes     :
  * Return Values: None
  * Modification :
  * Date          Developer     Version    Description
  *--------------------------------------------------------------------------------------
  * 07-JUL-2014   Swapna N        1.00       Created
  ****************************************************************************************/

    PROCEDURE Update_CM (x_retcode         OUT NUMBER,
                         x_errbuff         OUT VARCHAR2,
                         p_debug_flag   IN     VARCHAR2)
    IS
        l_line_number           NUMBER := NULL;
        l_type_1099             AP_INVOICE_LINES.TYPE_1099%TYPE := NULL;
        l_income_tax_region     AP_INVOICE_LINES.INCOME_TAX_REGION%TYPE := NULL;
        l_vendor_changed_flag   VARCHAR2 (1) := 'Y';
        l_update_base           VARCHAR2 (1) := NULL;
        l_reset_match_status    VARCHAR2 (1) := NULL;
        l_update_occurred       VARCHAR2 (1) := NULL;
        l_calling_sequence      VARCHAR2 (2400)
                                    := 'Deckers AP 1099 Invoice Conversion ';

        CURSOR org_c IS
            SELECT DISTINCT org_id
              FROM ap_invoices_all
             WHERE invoice_num LIKE '%1099%CM%' AND SOURCE = 'CONVERSIONS';


        TYPE INV_ORG_TYPE IS TABLE OF org_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_org_tbl         INV_ORG_TYPE;

        CURSOR creditmemo_c (p_org_id NUMBER)
        IS
            --         SELECT invoice_id
            --           FROM ap_invoices_all
            --          WHERE     invoice_num LIKE '%1099%CM%'
            --                AND SOURCE = 'CONVERSIONS'

            SELECT *
              FROM ap_invoice_distributions_all
             WHERE /*TYPE_1099 IN ('MISC1', 'MISC14', 'MISC7')
               AND INCOME_TAX_REGION IN
                      ('NJ',
                       'MN',
                       'CA',
                       'PR',
                       'VA',
                       'MA',
                       'WI',
                       'MD',
                       'OH',
                       'NH',
                       'IL',
                       'ME',
                       'MI',
                       'UT',
                       'GA',
                       'CO',
                       'NY',
                       'MT',
                       'DC',
                       'SC',
                       'DE',
                       'IA',
                       'FL',
                       'HI',
                       'WA',
                       'TX',
                       'CT',
                       'MO',
                       'IN',
                       'VT',
                       'ID',
                       'NV',
                       'AZ',
                       'OR',
                       'NC',
                       'PA')*/
                       type_1099 IS NOT NULL
                   AND invoice_id IN
                           (SELECT invoice_id
                              FROM ap_invoices_all
                             WHERE     INVOICE_TYPE_LOOKUP_CODE = 'CREDIT'
                                   AND pay_group_lookup_code = 'XXD_1099')
                   AND org_id = p_org_id;



        TYPE CM_TYPE IS TABLE OF creditmemo_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        CM_TBL                  CM_TYPE;

        lc_error_message        VARCHAR2 (1000);
    BEGIN
        print_log_prc (p_debug_flag, 'Start of Update_CM');

        invoice_org_tbl.delete;

        OPEN org_c;

        FETCH org_c BULK COLLECT INTO invoice_org_tbl;

        CLOSE org_c;

        FOR rec IN 1 .. invoice_org_tbl.COUNT
        LOOP
            --setting org context

            print_log_prc (p_debug_flag, 'Start of Loop');

            mo_global.set_policy_context ('S', invoice_org_tbl (rec).org_id);

            CM_TBL.delete;

            OPEN creditmemo_c (invoice_org_tbl (rec).org_id);

            FETCH creditmemo_c BULK COLLECT INTO CM_TBL;

            CLOSE creditmemo_c;

            -- Updating each credit memo in loop

            FOR l_rec IN 1 .. CM_TBL.COUNT
            LOOP
                l_line_number           := NULL;
                l_type_1099             := NULL;
                l_income_tax_region     := NULL;
                l_vendor_changed_flag   := 'Y';
                l_update_base           := NULL;
                l_reset_match_status    := NULL;
                l_update_occurred       := NULL;
                l_calling_sequence      :=
                    'Deckers AP 1099 Invoice Conversion ';

                print_log_prc (
                    p_debug_flag,
                       'Calling API AP_INVOICE_DISTRIBUTIONS_PKG.update_distributions for Invoice id '
                    || CM_TBL (l_rec).invoice_id);


                AP_INVOICE_DISTRIBUTIONS_PKG.update_distributions (
                    X_invoice_id            => CM_TBL (l_rec).invoice_id,
                    X_line_number           => l_line_number,
                    X_type_1099             => l_type_1099,
                    X_income_tax_region     => l_income_tax_region,
                    X_vendor_changed_flag   => l_vendor_changed_flag,
                    X_update_base           => l_update_base,
                    X_reset_match_status    => l_reset_match_status,
                    X_update_occurred       => l_update_occurred,
                    X_calling_sequence      => l_calling_sequence);

                PRINT_LOG_PRC (
                    p_debug_flag,
                       'l_update_occurred : '
                    || l_update_occurred
                    || ' for credit Memo - '
                    || CM_TBL (l_rec).invoice_id);

                COMMIT;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   :=
                   'Unexpected error occured in the procedure Update_CM :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_error_message);

            XXD_common_utils.record_error (
                'APINV',
                XXD_common_utils.get_org_id,
                'Deckers AP 1099 Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Issues in Update CM');
    END Update_CM;
END XXD_AP_1099_INV_CONV_PKG;
/
