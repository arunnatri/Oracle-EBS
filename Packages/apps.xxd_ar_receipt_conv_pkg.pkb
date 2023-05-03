--
-- XXD_AR_RECEIPT_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_RECEIPT_CONV_PKG"
AS
    /*******************************************************************************
    * Program Name : XXD_AR_RECEIPT_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will load Receipt data
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team 1.0                                             15-MAY-2015
    * --------------------------------------------------------------------------- */
    gn_user_id        NUMBER := fnd_global.user_id;
    gn_resp_id        NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   NUMBER := fnd_global.resp_appl_id;
    gn_req_id         NUMBER := fnd_global.conc_request_id;
    gn_login_id       NUMBER := fnd_global.login_id;
    gd_sysdate        DATE := SYSDATE;
    gc_code_pointer   VARCHAR2 (500);
    gn_rct_extract    NUMBER;
    gn_limit          NUMBER := 1000;
    gn_org_id         NUMBER;


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
         WHERE UPPER (name) = UPPER (p_org_name);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_targetorg_id;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_name IN VARCHAR2
                    , pi_type IN VARCHAR2, p_debug IN VARCHAR2)
    IS
        ln_req_id              NUMBER;
        lv_req_phase           VARCHAR2 (240);
        lv_req_status          VARCHAR2 (240);
        lv_req_dev_phase       VARCHAR2 (240);
        lv_req_dev_status      VARCHAR2 (240);
        lv_req_message         VARCHAR2 (240);
        lv_req_return_status   BOOLEAN;
    BEGIN
        -- Call wrapper procs sequentially
        IF pi_type = 'EXTRACT'
        THEN
            gc_code_pointer   := 'Extract Program Call!!';
            print_log_prc (p_debug, gc_code_pointer);

            BEGIN
                ln_req_id   :=
                    fnd_request.submit_request (application => 'XXDCONV', program => 'XXD_AR_RECEIPT_EXTRACT_PRG', description => 'Deckers AR Receipt Conversion Extract Program', start_time => SYSDATE, sub_request => FALSE, argument1 => p_debug
                                                , argument2 => p_org_name);
                COMMIT;

                IF ln_req_id = 0
                THEN
                    gc_code_pointer   :=
                        'Extract Program Request Not Submitted!!';
                    print_log_prc (p_debug, gc_code_pointer);
                ELSE
                    IF ln_req_id > 0
                    THEN
                        LOOP
                            lv_req_return_status   :=
                                fnd_concurrent.wait_for_request (
                                    ln_req_id,
                                    1,
                                    1,
                                    lv_req_phase,
                                    lv_req_status,
                                    lv_req_dev_phase,
                                    lv_req_dev_status,
                                    lv_req_message);
                            EXIT WHEN    UPPER (lv_req_phase) = 'COMPLETED'
                                      OR UPPER (lv_req_status) IN
                                             ('CANCELLED', 'ERROR', 'TERMINATED');
                        END LOOP;

                        IF     UPPER (lv_req_phase) = 'COMPLETED'
                           AND UPPER (lv_req_status) = 'ERROR'
                        THEN
                            gc_code_pointer   :=
                                'Extract Program in ERRROR stage!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        ELSIF     UPPER (lv_req_phase) = 'COMPLETED'
                              AND UPPER (lv_req_status) = 'NORMAL'
                        THEN
                            gc_code_pointer   :=
                                'Extract Program is COMPLETED sucessfully!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        ELSE
                            gc_code_pointer   :=
                                'Extract Program in OTHER ERRROR stage!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gc_code_pointer   :=
                        'Extract Program is going to Exception!!';
                    print_log_prc (p_debug, gc_code_pointer);
            END;
        ELSIF pi_type = 'VALIDATE'
        THEN
            gc_code_pointer   := 'Validate Program Call!!';
            print_log_prc (p_debug, gc_code_pointer);

            BEGIN
                ln_req_id   :=
                    fnd_request.submit_request (application => 'XXDCONV', program => 'XXD_AR_RECEIPT_VALIDATE_PRG', description => 'Deckers AR Receipt Conversion Validate Program', start_time => SYSDATE, sub_request => FALSE, argument1 => p_debug
                                                , argument2 => p_org_name);
                COMMIT;

                IF ln_req_id = 0
                THEN
                    gc_code_pointer   :=
                        'Validate Program Request Not Submitted!!';
                    print_log_prc (p_debug, gc_code_pointer);
                ELSE
                    IF ln_req_id > 0
                    THEN
                        LOOP
                            lv_req_return_status   :=
                                fnd_concurrent.wait_for_request (
                                    ln_req_id,
                                    1,
                                    1,
                                    lv_req_phase,
                                    lv_req_status,
                                    lv_req_dev_phase,
                                    lv_req_dev_status,
                                    lv_req_message);
                            EXIT WHEN    UPPER (lv_req_phase) = 'COMPLETED'
                                      OR UPPER (lv_req_status) IN
                                             ('CANCELLED', 'ERROR', 'TERMINATED');
                        END LOOP;

                        IF     UPPER (lv_req_phase) = 'COMPLETED'
                           AND UPPER (lv_req_status) = 'ERROR'
                        THEN
                            gc_code_pointer   :=
                                'Validate Program is in ERRROR stage!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        ELSIF     UPPER (lv_req_phase) = 'COMPLETED'
                              AND UPPER (lv_req_status) = 'NORMAL'
                        THEN
                            gc_code_pointer   :=
                                'Validate Program is COMPLETED sucessfully!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        ELSE
                            gc_code_pointer   :=
                                'Validate Program is in OTHER ERRROR stage!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gc_code_pointer   :=
                        'Validate Program is going to Exception!!';
                    print_log_prc (p_debug, gc_code_pointer);
            END;
        ELSIF pi_type = 'LOAD'
        THEN
            gc_code_pointer   := 'Load Program Call!!';
            print_log_prc (p_debug, gc_code_pointer);

            BEGIN
                ln_req_id   :=
                    fnd_request.submit_request (application => 'XXDCONV', program => 'XXD_AR_RECEIPT_LOAD_PRG', description => 'Deckers AR Receipt Conversion Load Program', start_time => SYSDATE, sub_request => FALSE, argument1 => p_org_name
                                                , argument2 => p_debug);
                COMMIT;

                IF ln_req_id = 0
                THEN
                    gc_code_pointer   :=
                        'Load Program Request Not Submitted!!';
                    print_log_prc (p_debug, gc_code_pointer);
                ELSE
                    IF ln_req_id > 0
                    THEN
                        LOOP
                            lv_req_return_status   :=
                                fnd_concurrent.wait_for_request (
                                    ln_req_id,
                                    1,
                                    1,
                                    lv_req_phase,
                                    lv_req_status,
                                    lv_req_dev_phase,
                                    lv_req_dev_status,
                                    lv_req_message);
                            EXIT WHEN    UPPER (lv_req_phase) = 'COMPLETED'
                                      OR UPPER (lv_req_status) IN
                                             ('CANCELLED', 'ERROR', 'TERMINATED');
                        END LOOP;

                        IF     UPPER (lv_req_phase) = 'COMPLETED'
                           AND UPPER (lv_req_status) = 'ERROR'
                        THEN
                            gc_code_pointer   :=
                                'Load Program is in ERRROR stage!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        ELSIF     UPPER (lv_req_phase) = 'COMPLETED'
                              AND UPPER (lv_req_status) = 'NORMAL'
                        THEN
                            gc_code_pointer   :=
                                'Load Program is COMPLETED sucessfully!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        ELSE
                            gc_code_pointer   :=
                                'Load Program is in OTHER ERRROR stage!!';
                            print_log_prc (p_debug, gc_code_pointer);
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gc_code_pointer   :=
                        'Load Program is going to Exception!!';
                    print_log_prc (p_debug, gc_code_pointer);
            END;
        END IF;
    END;

    /****************************************************************************************
             * Procedure : RECEIPT_EXTRACT
             * Synopsis  : This Procedure is called by Main procedure
             * Design    : Procedure loads data to staging table for Receipt Conversion
             * Notes     :
             * Return Values: None
             * Modification :
             * Date          Developer     Version    Description
             *--------------------------------------------------------------------------------------
             * 15-MAY-2015     BT Technology Team          1.00       Created
             ****************************************************************************************/
    PROCEDURE receipt_extract (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_debug IN VARCHAR2
                               , p_org_name IN VARCHAR2)
    AS
        TYPE l_receipt_info_type
            IS TABLE OF xxd_conv.xxd_ar_1206_receipt_conv_stg_t%ROWTYPE;

        l_ar_rct_tbl      l_receipt_info_type;

        CURSOR receipt_c IS
            SELECT *
              FROM xxd_conv.xxd_ar_1206_receipt_conv_stg_t xaic
             WHERE     receipt_amount <> 0
                   AND NOT EXISTS
                           (SELECT *
                              FROM xxd_conv.xxd_ar_receipt_conv_stg_t stg
                             WHERE xaic.old_cash_receipt_id =
                                   stg.old_cash_receipt_id)
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                                   AND language = 'US'
                                   AND TO_NUMBER (lookup_code) = org_id
                                   AND attribute1 = p_org_name);

        CURSOR c_receipt_dtls IS
              SELECT receipt_number,
                     receipt_method,
                     receipt_date,
                     customer_number,
                     receipt_amount,
                     old_cash_receipt_id,
                     ROW_NUMBER ()
                         OVER (PARTITION BY receipt_number, receipt_method, receipt_date,
                                            customer_number, receipt_amount
                               ORDER BY
                                   receipt_number, receipt_method, receipt_date,
                                   customer_number, receipt_amount) receipt_suffix
                FROM xxd_ar_receipt_conv_stg_t
               WHERE     record_status = 'N'
                     AND (receipt_number, receipt_method, receipt_date,
                          customer_number, receipt_amount) IN
                             (  SELECT receipt_number, receipt_method, receipt_date,
                                       customer_number, receipt_amount
                                  FROM xxd_ar_receipt_conv_stg_t
                                 WHERE record_status = 'N'
                              GROUP BY receipt_number, receipt_method, receipt_date,
                                       customer_number, receipt_amount
                                HAVING COUNT (1) > 1)
            ORDER BY 1;

        ln_loop_counter   NUMBER;
    BEGIN
        /*gc_code_pointer   := 'Deleting data from Receipt Conversion staging table';
        print_log_prc ( p_debug
                      ,  gc_code_pointer );

        --Deleting data from  staging table
        EXECUTE IMMEDIATE 'truncate table XXD_AR_RECEIPT_CONV_STG_T';*/

        gc_code_pointer   := 'Insert Receipt Conversion staging table';
        print_log_prc (p_debug, gc_code_pointer);

        -- Insert records into Receipt staging table
        BEGIN
            OPEN receipt_c;

            ln_loop_counter   := 0;

            LOOP
                FETCH receipt_c BULK COLLECT INTO l_ar_rct_tbl LIMIT gn_limit;

                FORALL lcu_receipt_rec IN 1 .. l_ar_rct_tbl.COUNT
                    INSERT INTO xxd_conv.xxd_ar_receipt_conv_stg_t (
                                    receipt_number,
                                    old_cash_receipt_id,
                                    receipt_method,
                                    old_receipt_method_id,
                                    receipt_date,
                                    gl_date,
                                    customer_name,
                                    customer_number,
                                    old_customer_id,
                                    old_cust_account_id,
                                    old_cust_acct_site_id,
                                    old_site_use_id,
                                    location,
                                    old_remittance_bank_account_id,
                                    bank_account_name,
                                    bank_account_num,
                                    currency_code,
                                    receipt_status,
                                    receivable_status,
                                    org_id,
                                    org_name,
                                    receipt_amount,
                                    onaccount_amount,
                                    unapplied_amount,
                                    unidentified_amount,
                                    comments,
                                    override_remit_account_flag,
                                    customer_receipt_reference,
                                    postmark_date,
                                    exchange_date,
                                    exchange_rate,
                                    exchange_rate_type,
                                    record_id,
                                    record_status,
                                    error_message,
                                    last_update_date,
                                    last_updated_by,
                                    last_updated_login,
                                    creation_date,
                                    created_by,
                                    request_id)
                         VALUES (l_ar_rct_tbl (lcu_receipt_rec).receipt_number, l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id, l_ar_rct_tbl (lcu_receipt_rec).receipt_method, l_ar_rct_tbl (lcu_receipt_rec).old_receipt_method_id, l_ar_rct_tbl (lcu_receipt_rec).receipt_date, NVL (l_ar_rct_tbl (lcu_receipt_rec).gl_date, SYSDATE), l_ar_rct_tbl (lcu_receipt_rec).customer_name, l_ar_rct_tbl (lcu_receipt_rec).customer_number, l_ar_rct_tbl (lcu_receipt_rec).old_customer_id, l_ar_rct_tbl (lcu_receipt_rec).old_cust_account_id, l_ar_rct_tbl (lcu_receipt_rec).old_cust_acct_site_id, l_ar_rct_tbl (lcu_receipt_rec).old_site_use_id, l_ar_rct_tbl (lcu_receipt_rec).location, l_ar_rct_tbl (lcu_receipt_rec).old_remittance_bank_account_id, l_ar_rct_tbl (lcu_receipt_rec).bank_account_name, l_ar_rct_tbl (lcu_receipt_rec).bank_account_num, l_ar_rct_tbl (lcu_receipt_rec).currency_code, l_ar_rct_tbl (lcu_receipt_rec).receipt_status, l_ar_rct_tbl (lcu_receipt_rec).receivable_status, l_ar_rct_tbl (lcu_receipt_rec).org_id, l_ar_rct_tbl (lcu_receipt_rec).org_name, l_ar_rct_tbl (lcu_receipt_rec).receipt_amount, l_ar_rct_tbl (lcu_receipt_rec).onaccount_amount, l_ar_rct_tbl (lcu_receipt_rec).unapplied_amount, l_ar_rct_tbl (lcu_receipt_rec).unidentified_amount, l_ar_rct_tbl (lcu_receipt_rec).comments, l_ar_rct_tbl (lcu_receipt_rec).override_remit_account_flag, l_ar_rct_tbl (lcu_receipt_rec).customer_receipt_reference, l_ar_rct_tbl (lcu_receipt_rec).postmark_date, l_ar_rct_tbl (lcu_receipt_rec).exchange_date, l_ar_rct_tbl (lcu_receipt_rec).exchange_rate, l_ar_rct_tbl (lcu_receipt_rec).exchange_rate_type, xxd_ar_receipt_conv_stg_s.NEXTVAL, 'N', NULL, gd_sysdate, gn_user_id, gn_login_id, gd_sysdate
                                 , gn_user_id, gn_req_id);

                ln_loop_counter   := ln_loop_counter + 1;

                IF ln_loop_counter = gn_limit
                THEN
                    COMMIT;
                    ln_loop_counter   := 0;
                END IF;

                EXIT WHEN receipt_c%NOTFOUND;
            END LOOP;

            CLOSE receipt_c;

            gc_code_pointer   := 'After insert into Staging table';
            print_log_prc (p_debug, gc_code_pointer);
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   :=
                       'OTHERS Exception while Insert into XXD_AR_RECEIPT_CONV_STG_T Table'
                    || SQLERRM;
                print_log_prc (p_debug, gc_code_pointer);
        END;

        COMMIT;

        FOR lcu_receipt_dtls_rec IN c_receipt_dtls
        LOOP
            UPDATE xxd_ar_receipt_conv_stg_t
               SET receipt_number = receipt_number || '-' || lcu_receipt_dtls_rec.receipt_suffix
             WHERE old_cash_receipt_id =
                   lcu_receipt_dtls_rec.old_cash_receipt_id;
        END LOOP;

        COMMIT;

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE record_status = 'N';
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Records Extracted from 12.0.6 and loaded to 12.2.3 ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);
    END;

    /****************************************************************************************
          * Procedure : RECEIPT_VALIDATE
          * Synopsis  : This Procedure is called by Main procedure
          * Design    : Procedure Validate the staging table data
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 15-MAY-2015     BT Technology Team          1.00       Created
          ****************************************************************************************/
    PROCEDURE receipt_validate (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_debug IN VARCHAR2
                                , p_org_name IN VARCHAR2)
    IS
        TYPE l_receipt_info_type
            IS TABLE OF xxd_conv.xxd_ar_receipt_conv_stg_t%ROWTYPE;

        l_ar_rct_tbl          l_receipt_info_type;

        CURSOR receipt_c IS
            SELECT *
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t xaic
             WHERE     record_status IN ('N', 'E')
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                                   AND language = 'US'
                                   AND TO_NUMBER (lookup_code) = org_id
                                   AND attribute1 = p_org_name);

        ln_loop_counter       NUMBER;
        ln_err_count          NUMBER;
        lc_l_err_msg          VARCHAR2 (1000);
        l_org_id              NUMBER;
        l_org_name            VARCHAR2 (720);
        l_customer_id         NUMBER;
        l_site_use_id         NUMBER;
        l_location            VARCHAR2 (120);
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_cust_acct_site_id   NUMBER;
        l_receipt_count       NUMBER;
        l_bank_account_name   VARCHAR2 (300);
        l_bank_account_num    VARCHAR2 (90);
    BEGIN
        gc_code_pointer   := 'Receipt Validation Start';
        print_log_prc (p_debug, gc_code_pointer);

        -- VAlidate Receipt staging table
        BEGIN
            OPEN receipt_c;

            ln_loop_counter   := 0;

            LOOP
                FETCH receipt_c BULK COLLECT INTO l_ar_rct_tbl LIMIT gn_limit;

                FOR lcu_receipt_rec IN 1 .. l_ar_rct_tbl.COUNT
                LOOP
                    lc_l_err_msg          := NULL;
                    ln_err_count          := 0;
                    l_customer_id         := NULL;
                    l_site_use_id         := NULL;
                    l_location            := NULL;
                    l_receipt_method_id   := NULL;
                    l_bank_account_id     := NULL;
                    l_bank_account_name   := NULL;
                    l_bank_account_num    := NULL;
                    l_cust_acct_site_id   := NULL;
                    l_org_id              := NULL;
                    l_receipt_count       := 0;
                    get_new_org_id (p_old_org_name => l_ar_rct_tbl (lcu_receipt_rec).org_name, p_debug_flag => p_debug, x_new_org_id => l_org_id
                                    , x_new_org_name => l_org_name);
                    print_log_prc (p_debug, 'New ORG Id is :' || l_org_id);
                    print_log_prc (p_debug,
                                   'New Operating Unit :' || l_org_name);

                    IF l_org_id IS NULL
                    THEN
                        gc_code_pointer   :=
                               'Organization mapping derivation failed for org '
                            || l_ar_rct_tbl (lcu_receipt_rec).org_name;
                        lc_l_err_msg   :=
                            lc_l_err_msg || '~' || gc_code_pointer;
                        print_log_prc (p_debug, gc_code_pointer);
                        ln_err_count   := ln_err_count + 1;
                    END IF;

                    BEGIN
                        SELECT DISTINCT arm.receipt_method_id
                          INTO l_receipt_method_id
                          FROM ar_receipt_methods arm, xxd_conv.xxd_receipt_method_mapping_tbl xxr
                         WHERE     UPPER (TRIM (arm.name)) =
                                   UPPER (TRIM (xxr.new_receipt_method))
                               AND UPPER (TRIM (xxr.old_receipt_method)) =
                                   UPPER (
                                       TRIM (
                                           l_ar_rct_tbl (lcu_receipt_rec).receipt_method));
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            gc_code_pointer   :=
                                   'Receipt Method '
                                || l_ar_rct_tbl (lcu_receipt_rec).receipt_method
                                || ' not found';
                            lc_l_err_msg   :=
                                lc_l_err_msg || '~' || gc_code_pointer;
                            print_log_prc (p_debug, gc_code_pointer);
                            ln_err_count   := ln_err_count + 1;
                        WHEN OTHERS
                        THEN
                            gc_code_pointer   :=
                                   'Receipt Method '
                                || l_ar_rct_tbl (lcu_receipt_rec).receipt_method
                                || ' not found';
                            lc_l_err_msg   :=
                                lc_l_err_msg || '~' || gc_code_pointer;
                            print_log_prc (p_debug, gc_code_pointer);
                            ln_err_count   := ln_err_count + 1;
                    END;

                    BEGIN
                        SELECT COUNT (*)
                          INTO l_receipt_count
                          FROM ar_cash_receipts_all arc
                         WHERE     arc.receipt_number =
                                   l_ar_rct_tbl (lcu_receipt_rec).receipt_number
                               AND arc.org_id = l_org_id
                               AND arc.receipt_method_id =
                                   l_receipt_method_id
                               AND arc.amount =
                                   l_ar_rct_tbl (lcu_receipt_rec).receipt_amount
                               AND arc.receipt_date =
                                   l_ar_rct_tbl (lcu_receipt_rec).receipt_date;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_receipt_count   := 0;
                    END;

                    IF l_receipt_count > 0
                    THEN
                        gc_code_pointer   :=
                            'Receipt Already exists in 12.2.3 ';
                        lc_l_err_msg   :=
                            lc_l_err_msg || '~' || gc_code_pointer;
                        print_log_prc (p_debug, gc_code_pointer);
                        ln_err_count   := ln_err_count + 1;
                    END IF;

                    IF l_ar_rct_tbl (lcu_receipt_rec).old_cust_account_id
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT cust_account_id
                              INTO l_customer_id
                              FROM hz_cust_accounts
                             WHERE orig_system_reference =
                                   TO_CHAR (
                                       l_ar_rct_tbl (lcu_receipt_rec).old_cust_account_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                gc_code_pointer   :=
                                       'Customer '
                                    || l_ar_rct_tbl (lcu_receipt_rec).customer_name
                                    || ' not found';
                                lc_l_err_msg   :=
                                    lc_l_err_msg || '~' || gc_code_pointer;
                                print_log_prc (p_debug, gc_code_pointer);
                                ln_err_count   := ln_err_count + 1;
                            WHEN OTHERS
                            THEN
                                gc_code_pointer   :=
                                       'Customer '
                                    || l_ar_rct_tbl (lcu_receipt_rec).customer_name
                                    || ' not found';
                                lc_l_err_msg   :=
                                    lc_l_err_msg || '~' || gc_code_pointer;
                                print_log_prc (p_debug, gc_code_pointer);
                                ln_err_count   := ln_err_count + 1;
                        END;
                    END IF;

                    IF l_ar_rct_tbl (lcu_receipt_rec).old_site_use_id
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT site_use_id, location, cust_acct_site_id
                              INTO l_site_use_id, l_location, l_cust_acct_site_id
                              FROM hz_cust_site_uses_all
                             WHERE     orig_system_reference =
                                       TO_CHAR (
                                           l_ar_rct_tbl (lcu_receipt_rec).old_site_use_id)
                                   AND org_id = l_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                gc_code_pointer   :=
                                       'Customer site use '
                                    || l_ar_rct_tbl (lcu_receipt_rec).old_site_use_id
                                    || ' not found for Customer '
                                    || l_ar_rct_tbl (lcu_receipt_rec).customer_name;
                                lc_l_err_msg   :=
                                    lc_l_err_msg || '~' || gc_code_pointer;
                                print_log_prc (p_debug, gc_code_pointer);
                                ln_err_count   := ln_err_count + 1;
                            WHEN OTHERS
                            THEN
                                gc_code_pointer   :=
                                       'Customer site use '
                                    || ' not found for Customer '
                                    || l_ar_rct_tbl (lcu_receipt_rec).customer_name;
                                lc_l_err_msg   :=
                                    lc_l_err_msg || '~' || gc_code_pointer;
                                print_log_prc (p_debug, gc_code_pointer);
                                ln_err_count   := ln_err_count + 1;
                        END;
                    END IF;

                    IF l_ar_rct_tbl (lcu_receipt_rec).bank_account_num
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT DISTINCT cbau.bank_acct_use_id, ca.bank_account_name, ca.bank_account_num
                              INTO l_bank_account_id, l_bank_account_name, l_bank_account_num
                              FROM ce_bank_accounts ca, ce_bank_acct_uses_all cbau, xxd_conv.xxd_bank_mapping_table xxb
                             WHERE     ca.bank_account_id =
                                       cbau.bank_account_id
                                   AND UPPER (TRIM (ca.bank_account_name)) =
                                       UPPER (
                                           TRIM (xxb.new_bank_account_name))
                                   AND UPPER (TRIM (ca.bank_account_num)) =
                                       UPPER (
                                           TRIM (xxb.new_bank_account_num))
                                   AND UPPER (
                                           TRIM (xxb.old_bank_account_name)) =
                                       UPPER (
                                           TRIM (
                                               l_ar_rct_tbl (lcu_receipt_rec).bank_account_name))
                                   AND UPPER (
                                           TRIM (xxb.old_bank_account_num)) =
                                       UPPER (
                                           TRIM (
                                               l_ar_rct_tbl (lcu_receipt_rec).bank_account_num))
                                   AND UPPER (TRIM (xxb.org_name)) =
                                       UPPER (
                                           TRIM (
                                               l_ar_rct_tbl (lcu_receipt_rec).org_name))
                                   AND cbau.org_id = l_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                gc_code_pointer   :=
                                       'Bank Account '
                                    || l_ar_rct_tbl (lcu_receipt_rec).bank_account_name
                                    || ' not found';
                                lc_l_err_msg   :=
                                    lc_l_err_msg || '~' || gc_code_pointer;
                                print_log_prc (p_debug, gc_code_pointer);
                                ln_err_count   := ln_err_count + 1;
                            WHEN OTHERS
                            THEN
                                gc_code_pointer   :=
                                       'Bank Account '
                                    || l_ar_rct_tbl (lcu_receipt_rec).bank_account_name
                                    || ' not found';
                                lc_l_err_msg   :=
                                    lc_l_err_msg || '~' || gc_code_pointer;
                                print_log_prc (p_debug, gc_code_pointer);
                                ln_err_count   := ln_err_count + 1;
                        END;
                    END IF;

                    IF ln_err_count = 0
                    THEN
                        print_log_prc (
                            p_debug,
                            'Before setting XXD_AR_RECEIPT_CONV_STG_T status to V');

                        UPDATE xxd_conv.xxd_ar_receipt_conv_stg_t
                           SET record_status = 'V', error_message = NULL, request_id = gn_req_id,
                               last_update_date = gd_sysdate, last_updated_by = gn_user_id, new_receipt_method_id = l_receipt_method_id,
                               new_customer_id = l_customer_id, new_site_use_id = l_site_use_id, new_remittance_bank_account_id = l_bank_account_id,
                               new_org_id = l_org_id, new_org_name = l_org_name, new_cust_account_id = l_customer_id,
                               new_cust_acct_site_id = l_cust_acct_site_id, new_location = l_location, new_bank_account_name = l_bank_account_name,
                               new_bank_account_num = l_bank_account_num
                         WHERE     old_cash_receipt_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id
                               AND org_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).org_id;

                        COMMIT;
                        print_log_prc (
                            p_debug,
                            'After setting XXD_AR_RECEIPT_CONV_STG_T status to V');
                    ELSE
                        print_log_prc (
                            p_debug,
                            'Before setting XXD_AR_RECEIPT_CONV_STG_T status to E');

                        UPDATE xxd_conv.xxd_ar_receipt_conv_stg_t
                           SET record_status = 'E', error_message = 'Validation Error ' || '~' || lc_l_err_msg, request_id = gn_req_id,
                               last_update_date = gd_sysdate, last_updated_by = gn_user_id, new_receipt_method_id = l_receipt_method_id,
                               new_customer_id = l_customer_id, new_site_use_id = l_site_use_id, new_remittance_bank_account_id = l_bank_account_id,
                               new_org_id = l_org_id, new_org_name = l_org_name, new_cust_account_id = l_customer_id,
                               new_cust_acct_site_id = l_cust_acct_site_id, new_location = l_location, new_bank_account_name = l_bank_account_name,
                               new_bank_account_num = l_bank_account_num
                         WHERE     old_cash_receipt_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id
                               AND org_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).org_id;

                        COMMIT;
                        print_log_prc (
                            p_debug,
                            'After setting XXD_AR_RECEIPT_CONV_STG_T status to E');
                    END IF;
                END LOOP;

                ln_loop_counter   := ln_loop_counter + 1;

                IF ln_loop_counter = gn_limit
                THEN
                    COMMIT;
                    ln_loop_counter   := 0;
                END IF;

                EXIT WHEN receipt_c%NOTFOUND;
            END LOOP;

            CLOSE receipt_c;

            gc_code_pointer   := 'After Validation of Staging table';
            print_log_prc (p_debug, gc_code_pointer);
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   :=
                    'OTHERS Exception while Validate the XXD_AR_RECEIPT_CONV_STG_T Table';
                print_log_prc (p_debug, gc_code_pointer);
        END;

        COMMIT;

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE record_status = 'V';
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Validate Records ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);
        gn_rct_extract    := 0;

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE record_status = 'E';
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Error Records ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);
    END;

    /****************************************************************************************
            * Procedure : RECEIPT_LOAD
            * Synopsis  : This Procedure is called by Main procedure
            * Design    : Procedure Create receipt
            * Notes     :
            * Return Values: None
            * Modification :
            * Date          Developer     Version    Description
            *--------------------------------------------------------------------------------------
            * 18-MAY-2015     BT Technology Team          1.00       Created
            ****************************************************************************************/
    PROCEDURE receipt_load (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_org_name IN VARCHAR2
                            , p_debug IN VARCHAR2)
    IS
        TYPE l_receipt_info_type
            IS TABLE OF xxd_conv.xxd_ar_receipt_conv_stg_t%ROWTYPE;

        l_ar_rct_tbl           l_receipt_info_type;

        CURSOR receipt_c IS
              SELECT *
                FROM xxd_conv.xxd_ar_receipt_conv_stg_t xaic
               WHERE record_status = 'V' AND new_org_id = gn_org_id
            ORDER BY new_receipt_method_id, receipt_date;

        ln_loop_counter        NUMBER;
        ln_err_count           NUMBER;
        lc_l_err_msg           VARCHAR2 (4000);
        l_attribute_rec_type   ar_receipt_api_pub.attribute_rec_type;
        l_cr_id                INTEGER;
        l_return_status        VARCHAR2 (2000);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (4000);
        l_loop_cnt             NUMBER;
        l_dummy_cnt            NUMBER;
    BEGIN
        gc_code_pointer   := 'Receipt Creation Start';
        print_log_prc (p_debug, gc_code_pointer);

        gn_org_id         := get_targetorg_id (p_org_name => p_org_name);

        BEGIN
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_resp_appl_id);
            mo_global.set_org_context (gn_org_id, NULL, 'AR');
            mo_global.init ('AR');
            mo_global.set_policy_context ('S', gn_org_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   := 'Apps Initialization Failed!!';
                print_log_prc (p_debug, gc_code_pointer);
        END;

        -- VAlidate Receipt staging table
        BEGIN
            OPEN receipt_c;

            ln_loop_counter   := 0;

            LOOP
                FETCH receipt_c BULK COLLECT INTO l_ar_rct_tbl LIMIT gn_limit;

                FOR lcu_receipt_rec IN 1 .. l_ar_rct_tbl.COUNT
                LOOP
                    lc_l_err_msg           := NULL;
                    ln_err_count           := 0;
                    l_cr_id                := NULL;
                    l_attribute_rec_type   := NULL;
                    l_return_status        := NULL;
                    l_msg_count            := NULL;
                    l_msg_data             := NULL;
                    ar_receipt_api_pub.create_cash (
                        p_api_version          => 1.0,
                        p_init_msg_list        => fnd_api.g_true,
                        p_commit               => fnd_api.g_true,
                        p_validation_level     => fnd_api.g_valid_level_full,
                        p_receipt_number       =>
                            l_ar_rct_tbl (lcu_receipt_rec).receipt_number,
                        p_amount               =>
                            l_ar_rct_tbl (lcu_receipt_rec).receipt_amount,
                        p_receipt_date         =>
                            l_ar_rct_tbl (lcu_receipt_rec).receipt_date,
                        p_gl_date              =>
                            l_ar_rct_tbl (lcu_receipt_rec).gl_date,
                        p_receipt_method_id    =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_receipt_method_id,
                        p_customer_id          =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_customer_id,
                        p_customer_site_use_id   =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_site_use_id,
                        p_location             =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_location,
                        p_remittance_bank_account_id   =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_remittance_bank_account_id,
                        p_org_id               =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_org_id,
                        p_usr_currency_code    => NULL,
                        p_comments             =>
                            l_ar_rct_tbl (lcu_receipt_rec).comments,
                        p_override_remit_account_flag   =>
                            l_ar_rct_tbl (lcu_receipt_rec).override_remit_account_flag,
                        p_customer_receipt_reference   =>
                            l_ar_rct_tbl (lcu_receipt_rec).customer_receipt_reference,
                        p_postmark_date        =>
                            l_ar_rct_tbl (lcu_receipt_rec).postmark_date,
                        p_currency_code        =>
                            l_ar_rct_tbl (lcu_receipt_rec).currency_code,
                        p_exchange_rate_type   =>
                            l_ar_rct_tbl (lcu_receipt_rec).exchange_rate_type,
                        p_exchange_rate        =>
                            l_ar_rct_tbl (lcu_receipt_rec).exchange_rate,
                        p_exchange_rate_date   =>
                            l_ar_rct_tbl (lcu_receipt_rec).exchange_date,
                        p_cr_id                => l_cr_id,
                        x_return_status        => l_return_status,
                        x_msg_count            => l_msg_count,
                        x_msg_data             => l_msg_data);

                    IF NVL (l_return_status, 'E') != 'S'
                    THEN
                        IF l_msg_count > 0
                        THEN
                            l_loop_cnt   := 1;

                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => l_loop_cnt,
                                    p_data            => l_msg_data,
                                    p_encoded         => fnd_api.g_false,
                                    p_msg_index_out   => l_dummy_cnt);

                                IF    l_return_status = 'E'
                                   OR l_return_status = 'U'
                                THEN
                                    l_msg_data   :=
                                        CONCAT ('ERROR >>> ', l_msg_data);

                                    IF LENGTH (lc_l_err_msg || l_msg_data) <
                                       3000
                                    THEN
                                        lc_l_err_msg   :=
                                            lc_l_err_msg || l_msg_data;
                                    END IF;
                                END IF;

                                l_loop_cnt   := l_loop_cnt + 1;
                                EXIT WHEN l_loop_cnt > l_msg_count;
                            END LOOP;

                            print_log_prc (
                                p_debug,
                                'Receipt Creation Error ' || lc_l_err_msg);
                        END IF;

                        UPDATE xxd_conv.xxd_ar_receipt_conv_stg_t
                           SET record_status = 'E', error_message = 'Receipt Creation Error ' || '~' || lc_l_err_msg, request_id = gn_req_id,
                               last_update_date = gd_sysdate, last_updated_by = gn_user_id
                         WHERE     old_cash_receipt_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id
                               AND new_org_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).new_org_id;

                        print_log_prc (
                            p_debug,
                            'Receipt Creation Error ~ setting XXD_AR_RECEIPT_CONV_STG_T status to E');
                    ELSE
                        print_log_prc (p_debug, 'Receipt Created!!! ');
                        print_log_prc (p_debug, 'Receipt ID :' || l_cr_id);

                        UPDATE xxd_conv.xxd_ar_receipt_conv_stg_t
                           SET record_status = 'L', new_cash_receipt_id = l_cr_id, request_id = gn_req_id,
                               last_update_date = gd_sysdate, last_updated_by = gn_user_id
                         WHERE     old_cash_receipt_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id
                               AND new_org_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).new_org_id;

                        print_log_prc (
                            p_debug,
                            'Receipt Created Successfully ~ Setting XXD_AR_RECEIPT_CONV_STG_T status to L');
                    END IF;
                END LOOP;

                ln_loop_counter   := ln_loop_counter + 1;

                IF ln_loop_counter = gn_limit
                THEN
                    COMMIT;
                    ln_loop_counter   := 0;
                END IF;

                EXIT WHEN receipt_c%NOTFOUND;
            END LOOP;

            CLOSE receipt_c;
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   :=
                    'OTHERS Exception while Load the XXD_AR_RECEIPT_CONV_STG_T Table';
                print_log_prc (p_debug, gc_code_pointer);
        END;

        COMMIT;

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE record_status = 'L' AND new_org_id = gn_org_id;
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Load Records ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE record_status = 'E' AND new_org_id = gn_org_id;
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Error Records ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        gc_code_pointer   := 'Receipt Creation End';
        print_log_prc (p_debug, gc_code_pointer);
    END;

    /****************************************************************************************
              * Procedure : RECEIPT_ON_ACCOUNT_APPLY
              * Synopsis  : This Procedure is called by Main procedure
              * Design    : Procedure Apply Receipt OnAccount
              * Notes     :
              * Return Values: None
              * Modification :
              * Date          Developer     Version    Description
              *--------------------------------------------------------------------------------------
              * 07-JUNE-2015     BT Technology Team          1.00       Created
              ****************************************************************************************/
    PROCEDURE receipt_on_account_apply (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_org_id IN NUMBER
                                        , p_debug IN VARCHAR2)
    IS
        TYPE l_receipt_info_type
            IS TABLE OF xxd_conv.xxd_ar_receipt_conv_stg_t%ROWTYPE;

        l_ar_rct_tbl      l_receipt_info_type;

        CURSOR receipt_c IS
            SELECT *
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t xaic
             WHERE     record_status = 'L'
                   AND new_org_id = p_org_id
                   AND onaccount_amount <> 0;

        ln_loop_counter   NUMBER;
        ln_err_count      NUMBER;
        lc_l_err_msg      VARCHAR2 (4000);
        l_cr_id           INTEGER;
        l_return_status   VARCHAR2 (2000);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (4000);
        l_loop_cnt        NUMBER;
        l_dummy_cnt       NUMBER;
    BEGIN
        gc_code_pointer   := 'Receipt On Account Apply Start Start';
        print_log_prc (p_debug, gc_code_pointer);

        BEGIN
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_resp_appl_id);
            mo_global.set_org_context (p_org_id, NULL, 'AR');
            mo_global.init ('AR');
            mo_global.set_policy_context ('S', p_org_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   := 'Apps Initialization Failed!!';
                print_log_prc (p_debug, gc_code_pointer);
        END;

        -- VAlidate Receipt staging table
        BEGIN
            OPEN receipt_c;

            ln_loop_counter   := 0;

            LOOP
                FETCH receipt_c BULK COLLECT INTO l_ar_rct_tbl LIMIT gn_limit;

                FOR lcu_receipt_rec IN 1 .. l_ar_rct_tbl.COUNT
                LOOP
                    lc_l_err_msg      := NULL;
                    ln_err_count      := 0;
                    l_return_status   := NULL;
                    l_msg_count       := NULL;
                    l_msg_data        := NULL;
                    gc_code_pointer   :=
                           'Receipt On Account Apply for Receipt Number '
                        || l_ar_rct_tbl (lcu_receipt_rec).receipt_number;
                    print_log_prc (p_debug, gc_code_pointer);
                    ar_receipt_api_pub.apply_on_account (
                        p_api_version        => 1.0,
                        p_init_msg_list      => fnd_api.g_true,
                        p_commit             => fnd_api.g_true,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        x_return_status      => l_return_status,
                        x_msg_count          => l_msg_count,
                        x_msg_data           => l_msg_data,
                        p_cash_receipt_id    =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_cash_receipt_id,
                        p_receipt_number     =>
                            l_ar_rct_tbl (lcu_receipt_rec).receipt_number,
                        p_org_id             =>
                            l_ar_rct_tbl (lcu_receipt_rec).new_org_id,
                        p_amount_applied     =>
                            l_ar_rct_tbl (lcu_receipt_rec).onaccount_amount);

                    IF NVL (l_return_status, 'E') != 'S'
                    THEN
                        IF l_msg_count > 0
                        THEN
                            l_loop_cnt   := 1;

                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => l_loop_cnt,
                                    p_data            => l_msg_data,
                                    p_encoded         => fnd_api.g_false,
                                    p_msg_index_out   => l_dummy_cnt);

                                IF    l_return_status = 'E'
                                   OR l_return_status = 'U'
                                THEN
                                    l_msg_data   :=
                                        CONCAT ('ERROR >>> ', l_msg_data);

                                    IF LENGTH (lc_l_err_msg || l_msg_data) <
                                       3000
                                    THEN
                                        lc_l_err_msg   :=
                                            lc_l_err_msg || l_msg_data;
                                    END IF;
                                END IF;

                                l_loop_cnt   := l_loop_cnt + 1;
                                EXIT WHEN l_loop_cnt > l_msg_count;
                            END LOOP;

                            print_log_prc (
                                p_debug,
                                   'Receipt On Account Apply Error '
                                || lc_l_err_msg);
                        END IF;

                        UPDATE xxd_conv.xxd_ar_receipt_conv_stg_t
                           SET record_status = 'E', error_message = 'Receipt On Account Apply Error' || '~' || lc_l_err_msg, request_id = gn_req_id,
                               last_update_date = gd_sysdate, last_updated_by = gn_user_id
                         WHERE     old_cash_receipt_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id
                               AND new_org_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).new_org_id;

                        print_log_prc (
                            p_debug,
                            'Receipt On Account Apply Error ~ setting XXD_AR_RECEIPT_CONV_STG_T status to E');
                    ELSE
                        UPDATE xxd_conv.xxd_ar_receipt_conv_stg_t
                           SET record_status = 'A', request_id = gn_req_id, last_update_date = gd_sysdate,
                               last_updated_by = gn_user_id
                         WHERE     old_cash_receipt_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).old_cash_receipt_id
                               AND new_org_id =
                                   l_ar_rct_tbl (lcu_receipt_rec).new_org_id;

                        print_log_prc (
                            p_debug,
                            'Receipt On Account Applied Successfully ~ Setting XXD_AR_RECEIPT_CONV_STG_T status to A');
                    END IF;
                END LOOP;

                ln_loop_counter   := ln_loop_counter + 1;

                IF ln_loop_counter = gn_limit
                THEN
                    COMMIT;
                    ln_loop_counter   := 0;
                END IF;

                EXIT WHEN receipt_c%NOTFOUND;
            END LOOP;

            CLOSE receipt_c;
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   :=
                    'OTHERS Exception while Receipt On Account Apply the XXD_AR_RECEIPT_CONV_STG_T Table';
                print_log_prc (p_debug, gc_code_pointer);
        END;

        COMMIT;

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE     record_status = 'A'
                   AND new_org_id = p_org_id
                   AND receivable_status = 'ACC';
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total On Account Records ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);

        BEGIN
            SELECT COUNT (*)
              INTO gn_rct_extract
              FROM xxd_conv.xxd_ar_receipt_conv_stg_t
             WHERE     record_status = 'E'
                   AND new_org_id = p_org_id
                   AND receivable_status = 'ACC';
        END;

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Error Records ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AR_RECEIPT_CONV_STG_T', 40, ' ')
            || '   '
            || gn_rct_extract);
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        gc_code_pointer   := 'Receipt On Account Apply Program End';
        print_log_prc (p_debug, gc_code_pointer);
    END;

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
          * 15-MAY-2015    BT Technology Team        1.00       Created
          ****************************************************************************************/
    PROCEDURE print_log_prc (p_debug_flag IN VARCHAR2, p_message IN VARCHAR2)
    AS
    BEGIN
        IF p_debug_flag = 'Y'
        THEN
            fnd_file.put_line (apps.fnd_file.LOG, p_message);
        END IF;
    END print_log_prc;

    /****************************************************************************************
          * Procedure : GET_NEW_ORG_ID
          * Synopsis  : This Procedure shall provide the new org_id for given 12.0 operating_unit name
          * Design    : Program input old_operating_unit_name is passed
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 15-MAY-2015   BT Technology Team       1.00       Created
          ****************************************************************************************/
    PROCEDURE get_new_org_id (p_old_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, x_new_org_id OUT NUMBER
                              , x_new_org_name OUT VARCHAR2)
    IS
        lc_attribute2    VARCHAR2 (1000);
        lc_error_code    VARCHAR2 (1000);
        lc_error_msg     VARCHAR2 (1000);
        lc_attribute1    VARCHAR2 (1000);
        xc_meaning       VARCHAR2 (1000);
        xc_description   VARCHAR2 (1000);
        xc_lookup_code   VARCHAR2 (1000);
        ln_org_id        NUMBER;

        CURSOR org_id_c (p_org_name VARCHAR2)
        IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name = p_org_name;
    BEGIN
        xc_meaning       := p_old_org_name;
        print_log_prc (p_debug_flag, 'p_old_org_name : ' || p_old_org_name);
        --Passing old operating unit name to fetch corresponding new operating_unit name
        xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING',
            px_lookup_code   => xc_lookup_code,
            px_meaning       => xc_meaning,
            px_description   => xc_description,
            x_attribute1     => lc_attribute1,
            x_attribute2     => lc_attribute2,
            x_error_code     => lc_error_code,
            x_error_msg      => lc_error_msg);
        print_log_prc (p_debug_flag, 'lc_attribute1 : ' || lc_attribute1);
        x_new_org_name   := lc_attribute1;

        -- Calling cursor to fetch Org_id for a given operating_unit name.
        OPEN org_id_c (lc_attribute1);

        ln_org_id        := NULL;

        FETCH org_id_c INTO ln_org_id;

        CLOSE org_id_c;

        x_new_org_id     := ln_org_id;
    END get_new_org_id;
END;
/
