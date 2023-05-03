--
-- XXDOOM_CIT_REMITPROC_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM_CIT_REMITPROC_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Technology Team
    -- Creation Date           : 31-Mar-2015
    -- File Name               : XXDOOM_CIT_REMITPROC_PKG.pks
    -- INCIDENT                : CIT Process Remittance - Deckers
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                 Remarks
    -- =============================================================================
    -- 31-MAR-2015        1.0         BT Technology Team  Initial development.
    -------------------------------------------------------------------------------
    G_ACTIVITY_DATE   VARCHAR2 (100);

    PROCEDURE PRINT_MSG (p_message IN VARCHAR2)
    IS
    BEGIN
        IF G_DEBUG_FLAG = 'Y'
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, p_message);
            DBMS_OUTPUT.PUT_LINE (p_message);
        END IF;
    END;

    FUNCTION FORMAT_AMOUNT (P_AMOUNT IN NUMBER)
        RETURN NUMBER
    AS
        l_formatted_amt   NUMBER;
    BEGIN
        IF P_AMOUNT = 0
        THEN
            l_formatted_amt   := 0;
        ELSIF P_AMOUNT < 100
        THEN
            SELECT TO_NUMBER (0 || '.' || P_AMOUNT)
              INTO l_formatted_amt
              FROM DUAL;
        ELSE
            SELECT TO_NUMBER (SUBSTR (P_AMOUNT, 1, LENGTH (P_AMOUNT) - 2) || '.' || SUBSTR (P_AMOUNT, LENGTH (P_AMOUNT) - 1))
              INTO l_formatted_amt
              FROM DUAL;
        END IF;

        RETURN l_formatted_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN P_AMOUNT;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception while formatting amount');
    END FORMAT_AMOUNT;

    PROCEDURE MAIN (P_ERRBUF OUT VARCHAR2, P_RETCODE OUT VARCHAR2, P_FILE_NAME IN VARCHAR2, P_ACTIVITY_DATE IN VARCHAR2, P_EMAIL IN VARCHAR2, P_DUMMYEMAIL IN VARCHAR2, P_EMAIL_FROM_ADDRESS IN VARCHAR2, P_EMAIL_TO_ADDRESS IN VARCHAR2, P_HELPDESK_EMAIL IN VARCHAR2
                    , P_DEBUG IN VARCHAR2)
    IS
        lv_request_id             NUMBER := 0;
        lv_load_request_id        NUMBER := 0;
        lv_rep_request_id         NUMBER := 0;
        lv_dest_file_name         VARCHAR2 (100)
            := 'CITARActivity' || TO_CHAR (SYSDATE, 'DD-MON-YYYY') || '.txt'; --'CITARActivity'||TO_CHAR(SYSDATE,'DD-MON-YYYY-HHMISS')||'.txt';
        lv_filename               VARCHAR2 (60);          --  := 'CDData.txt';
        lv_PhaseCode              VARCHAR2 (100) := NULL;
        lv_StatusCode             VARCHAR2 (100) := NULL;
        lv_DevPhase               VARCHAR2 (100) := NULL;
        lv_DevStatus              VARCHAR2 (100) := NULL;
        lv_ReturnMsg              VARCHAR2 (200) := NULL;
        lv_ConcReqCallStat        BOOLEAN := FALSE;
        lv_load_ConcReqCallStat   BOOLEAN := FALSE;
        lv_rep_ConcReqCallStat    BOOLEAN := FALSE;
        lv_dest_path              VARCHAR2 (100);
        lv_dest_path1             VARCHAR2 (100);
        lv_fileserver             VARCHAR2 (80);
        l_validate_status         VARCHAR2 (10);
        lv_arch_request_id        NUMBER;
        lv_arch_ConcReqCallStat   BOOLEAN := FALSE;
    BEGIN
        G_DEBUG_FLAG      := P_DEBUG;
        G_ACTIVITY_DATE   := P_ACTIVITY_DATE;
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Debug Flag is ' || P_DEBUG);
        lv_filename       := p_file_name;

        DELETE FROM XXDO_CIT_INBND_AR_ACT_DTL_INT;

        DELETE FROM XXDO_CIT_INBND_AR_ACT_CTL_INT;

        COMMIT;

        BEGIN
            --  mo_global.set_policy_context('S',FND_PROFILE.VALUE('ORG_ID'));
            FND_CLIENT_INFO.set_org_context (FND_PROFILE.VALUE ('ORG_ID'));
            mo_global.init ('AR');
        END;

        SELECT applications_system_name
          INTO lv_dest_path
          FROM APPS.fnd_product_groups
         WHERE ROWNUM <= 1;

        lv_dest_path1     :=
            '/f01/' || lv_dest_path || '/Inbound/Integrations/CIT/Invoices';

        BEGIN
            SELECT DECODE (applications_system_name, 'PROD', APPS.FND_PROFILE.VALUE ('DO CIT: FTP Address'), APPS.FND_PROFILE.VALUE ('DO CIT: Test FTP Address')) FILE_SERVER_NAME
              INTO lv_fileserver
              FROM APPS.fnd_product_groups
             WHERE ROWNUM <= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                p_retcode   := 2;
        END;

        PRINT_MSG ('Executing CIT ftp program');

        lv_request_id     :=
            APPS.FND_REQUEST.SUBMIT_REQUEST (
                application   => 'XXDO',
                program       => 'XXDOOM_CIT_REMITPROC_FTP',
                description   => '',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => lv_filename,
                argument2     => lv_dest_path1,
                argument3     => lv_dest_file_name,
                argument4     => lv_fileserver);

        COMMIT;


        lv_ConcReqCallStat   :=
            APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_request_ID,
                                                  5 -- wait 5 seconds between db checks
                                                   ,
                                                  0,
                                                  lv_PhaseCode,
                                                  lv_StatusCode,
                                                  lv_DevPhase,
                                                  lv_DevStatus,
                                                  lv_ReturnMsg);
        COMMIT;

        PRINT_MSG ('FTP Request id is ' || lv_request_id);



        IF     lv_request_id IS NOT NULL
           AND lv_request_id <> 0
           AND lv_PhaseCode = 'Completed'
        THEN
            PRINT_MSG ('Executing CIT Load program');

            lv_load_request_id   :=
                APPS.FND_REQUEST.SUBMIT_REQUEST (
                    application   => 'XXDO',
                    program       => 'XXDOOM_CIT_REMITPROC_LOAD',
                    description   => '',
                    start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                    sub_request   => FALSE,
                    argument1     => lv_dest_path1 || '/' || lv_dest_file_name);

            COMMIT;


            lv_load_ConcReqCallStat   :=
                APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_load_request_id,
                                                      5 -- wait 5 seconds between db checks
                                                       ,
                                                      0,
                                                      lv_PhaseCode,
                                                      lv_StatusCode,
                                                      lv_DevPhase,
                                                      lv_DevStatus,
                                                      lv_ReturnMsg);
            COMMIT;

            PRINT_MSG (
                   'Load Request id is '
                || lv_load_request_id
                || '  '
                || lv_PhaseCode
                || '  '
                || lv_DevPhase);

            IF     lv_load_request_id IS NOT NULL
               AND lv_load_request_id <> 0
               AND lv_PhaseCode = 'Completed'
            THEN
                PRINT_MSG (
                    'Before Updating Staging table data with customer info');

                UPDATE_STG_DATA;
                PRINT_MSG (
                    'After Updating Staging table data with customer info');
                PRINT_MSG (
                    'Before Validating Staging table data for duplicate data and amount');
                VALIDATE_STG_DATA (l_validate_status);
                PRINT_MSG (
                    'Before Validating Staging table data for duplicate data and amount');

                IF l_validate_status = 'DE'
                THEN
                    CIT_DATA_FILE_ALERT (
                        P_FROM_EMAIL   => P_EMAIL_FROM_ADDRESS,
                        P_TO_EMAIL     => p_helpdesk_email,
                        P_FILE_NAME    => lv_filename);
                    PRINT_MSG (
                           'The control and data summary totals are not matching for the AR activity file '
                        || lv_filename
                        || ' for the date '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                        || '. Data is not processed further.');
                    FND_FILE.PUT_LINE (
                        FND_FILE.OUTPUT,
                           'The control and data summary totals are not matching for the AR activity file '
                        || lv_filename
                        || ' for the date '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                        || '. Data is not processed further.');
                ELSIF l_validate_status = 'DUP'
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.OUTPUT,
                           'The data file '
                        || lv_filename
                        || ' is already processed. File is not processed further.');
                    PRINT_MSG (
                           'The data file '
                        || lv_filename
                        || ' is already processed. File is not processed further.');
                    CIT_DATA_DUP_ALERT (
                        P_FROM_EMAIL   => P_EMAIL_FROM_ADDRESS,
                        P_TO_EMAIL     => p_helpdesk_email,
                        P_FILE_NAME    => lv_filename);
                ELSE
                    PRINT_MSG ('Before Process Data');
                    PROCESS_DATA (p_activity_date => p_activity_date);
                    PRINT_MSG ('After Process Data');
                END IF;
            END IF;
        END IF;

        PRINT_MSG ('Before Submiting Report');
        lv_rep_request_id   :=
            APPS.FND_REQUEST.SUBMIT_REQUEST (
                application   => 'XXDO',
                program       => 'CIT_REMIT_PROCESS_RPT',
                description   => '',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => P_EMAIL_FROM_ADDRESS,
                argument2     => P_EMAIL_TO_ADDRESS);

        COMMIT;


        lv_rep_ConcReqCallStat   :=
            APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_rep_request_id,
                                                  5 -- wait 5 seconds between db checks
                                                   ,
                                                  0,
                                                  lv_PhaseCode,
                                                  lv_StatusCode,
                                                  lv_DevPhase,
                                                  lv_DevStatus,
                                                  lv_ReturnMsg);
        COMMIT;
        PRINT_MSG ('After Submiting Report');

        PRINT_MSG ('Before Submiting Archive Program');
        lv_arch_request_id   :=
            APPS.FND_REQUEST.SUBMIT_REQUEST (
                application   => 'XXDO',
                program       => 'XXDOOM_CIT_REMITPROC_ARCH',
                description   => 'CIT – Archive Remittance File Deckers',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => lv_dest_path1,
                argument2     => lv_dest_file_name,
                argument3     => lv_dest_path1 || '/Archive');

        COMMIT;


        lv_arch_ConcReqCallStat   :=
            APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_arch_request_id,
                                                  5 -- wait 5 seconds between db checks
                                                   ,
                                                  0,
                                                  lv_PhaseCode,
                                                  lv_StatusCode,
                                                  lv_DevPhase,
                                                  lv_DevStatus,
                                                  lv_ReturnMsg);
        COMMIT;
        PRINT_MSG ('After Archive program');
        PRINT_MSG ('End of the Program');
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception in Main program' || SQLERRM);
    END MAIN;

    PROCEDURE UPDATE_STG_DATA
    IS
        CURSOR get_dtl_data_c IS
            SELECT xci.client_group_number, xci.extract_date, xci.client_number,
                   xci.cit_customer_number, xci.customer_name, xci.customer_address1,
                   xci.customer_address2, xci.customer_city, xci.customer_state,
                   xci.customer_zip, xci.customer_country, xci.client_customer_number
              FROM xxdo_cit_inbnd_ar_act_dtl_int xci, xxdo_cit_inbnd_ar_act_dtl_stg xcs
             WHERE     xci.cit_customer_number = xcs.cit_customer_number
                   AND xcs.status = 'N';

        CURSOR get_ctl_data_c IS SELECT * FROM xxdo_cit_inbnd_ar_act_ctl_int;

        TYPE t_get_dtl_data_rec IS TABLE OF get_dtl_data_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_dtl_data_rec   t_get_dtl_data_rec;

        l_get_ctl_data       get_ctl_data_c%ROWTYPE;
    BEGIN
        l_get_ctl_data   := NULL;
        l_get_dtl_data_rec.DELETE;

        OPEN get_dtl_data_c;

        FETCH get_dtl_data_c BULK COLLECT INTO l_get_dtl_data_rec;

        CLOSE get_dtl_data_c;

        IF l_get_dtl_data_rec.COUNT > 0
        THEN
            FOR dtl_data IN 1 .. l_get_dtl_data_rec.COUNT
            LOOP
                UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
                   SET client_group_number = l_get_dtl_data_rec (dtl_data).client_group_number, extract_date = l_get_dtl_data_rec (dtl_data).extract_date, client_number = l_get_dtl_data_rec (dtl_data).client_number,
                       cit_customer_number = l_get_dtl_data_rec (dtl_data).cit_customer_number, customer_name = l_get_dtl_data_rec (dtl_data).customer_name, customer_address1 = l_get_dtl_data_rec (dtl_data).customer_address1,
                       customer_address2 = l_get_dtl_data_rec (dtl_data).customer_address2, customer_city = l_get_dtl_data_rec (dtl_data).customer_city, customer_state = l_get_dtl_data_rec (dtl_data).customer_state,
                       customer_zip = l_get_dtl_data_rec (dtl_data).customer_zip, customer_country = l_get_dtl_data_rec (dtl_data).customer_country
                 WHERE     cit_customer_number =
                           l_get_dtl_data_rec (dtl_data).cit_customer_number
                       AND status = 'N';

                COMMIT;
            END LOOP;

            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
               SET check_amount = FORMAT_AMOUNT (check_amount), gross_amount = FORMAT_AMOUNT (gross_amount), discount_amount = FORMAT_AMOUNT (discount_amount),
                   net_item_amount = FORMAT_AMOUNT (net_item_amount)
             WHERE status = 'N';
        END IF;


        OPEN get_ctl_data_c;

        FETCH get_ctl_data_c INTO l_get_ctl_data;

        CLOSE get_ctl_data_c;

        UPDATE xxdo_cit_inbnd_ar_act_ctl_stg
           SET total_trans_cust_count = l_get_ctl_data.total_trans_cust_count, total_trans_ar_count = l_get_ctl_data.total_trans_ar_count, total_gross_amount = FORMAT_AMOUNT (l_get_ctl_data.total_gross_amount)
         WHERE status = 'N';

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'Executing in UPDATE_STG_DATA' || SQLERRM);
    END UPDATE_STG_DATA;

    PROCEDURE VALIDATE_STG_DATA (P_STATUS OUT VARCHAR2)
    IS
        l_gross_amt_sum_dtl      NUMBER;
        l_gross_amt_sum_ctl      NUMBER;
        l_check_duplicate_data   NUMBER;

        CURSOR check_duplicate_data IS
            SELECT COUNT (*)
              FROM xxdo_cit_inbnd_ar_act_dtl_stg x
             WHERE     status = 'N'
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo_cit_inbnd_ar_act_dtl_stg
                             WHERE     extract_date = x.extract_date
                                   AND status IN ('SP'));

        CURSOR get_dtl_data IS
            SELECT COUNT (DISTINCT cit_customer_number) tot_cust_count, COUNT (item_reference) tot_ar_count, SUM (gross_amount) tot_gross_amount
              FROM xxdo_cit_inbnd_ar_act_dtl_stg
             WHERE status = 'N';

        CURSOR get_ctl_data IS
            SELECT total_gross_amount, total_trans_cust_count, total_trans_ar_count
              FROM xxdo_cit_inbnd_ar_act_ctl_stg
             WHERE status = 'N' AND ROWNUM = 1;

        l_dtl_data               get_dtl_data%ROWTYPE;
        l_ctl_data               get_ctl_data%ROWTYPE;
    BEGIN
        l_dtl_data               := NULL;
        l_ctl_data               := NULL;
        p_status                 := 'DS';
        l_check_duplicate_data   := 0;

        OPEN check_duplicate_data;

        FETCH check_duplicate_data INTO l_check_duplicate_data;

        CLOSE check_duplicate_data;

        IF l_check_duplicate_data > 0
        THEN
            PRINT_MSG ('Duplicate data is there in the file');

            DELETE FROM xxdo_cit_inbnd_ar_act_dtl_stg
                  WHERE STATUS = 'N';

            DELETE FROM xxdo_cit_inbnd_ar_act_ctl_stg
                  WHERE STATUS = 'N';

            COMMIT;

            p_status   := 'DUP';
        END IF;

        OPEN get_dtl_data;

        FETCH get_dtl_data INTO l_dtl_data;

        CLOSE get_dtl_data;

        OPEN get_ctl_data;

        FETCH get_ctl_data INTO l_ctl_data;

        CLOSE get_ctl_data;

        IF ((l_dtl_data.tot_cust_count <> l_ctl_data.total_trans_cust_count) OR (l_dtl_data.tot_ar_count <> l_ctl_data.total_trans_ar_count) OR (l_dtl_data.tot_gross_amount <> l_ctl_data.total_gross_amount))
        THEN
            UPDATE_STATUS (
                p_type                  => 'CTL',
                p_status                => 'DE',
                p_message               => 'Data and control count doesn’t match',
                p_item_ref              => NULL,
                p_ar_transaction_code   => NULL,
                p_activity_ind          => NULL);
            PRINT_MSG ('Data and control count doesn’t match');

            p_status   := 'DE';
        ELSE
            UPDATE_STATUS (p_type                  => 'CTL',
                           p_status                => 'DS',
                           p_message               => NULL,
                           p_item_ref              => NULL,
                           p_ar_transaction_code   => NULL,
                           p_activity_ind          => NULL);
            PRINT_MSG ('Data validation successfull');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'Executing in VALIDATE_STG_DATA' || SQLERRM);
    END VALIDATE_STG_DATA;

    PROCEDURE UPDATE_STATUS (p_type IN VARCHAR2, p_status IN VARCHAR2, p_message IN VARCHAR2
                             , p_item_ref IN VARCHAR2, p_ar_transaction_code IN VARCHAR2, p_activity_ind IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF p_type = 'CTL'
        THEN
            UPDATE xxdo_cit_inbnd_ar_act_ctl_stg
               SET status = p_status, error_message = p_message
             WHERE status = 'N';

            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
               SET status = p_status, error_message = p_message
             WHERE status = 'N';
        ELSIF p_type = 'DTL'
        THEN
            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
               SET status = p_status, error_message = p_message
             WHERE     item_reference = NVL (p_item_ref, item_reference)
                   AND ar_transaction_code =
                       NVL (p_ar_transaction_code, ar_transaction_code)
                   AND activity_indicator =
                       NVL (p_activity_ind, activity_indicator)
                   AND status = 'DS';
        ELSIF p_type = 'REM'
        THEN
            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
               SET status = 'MA', error_message = 'Manual Review Required'
             WHERE     status NOT IN ('E', 'SP', 'DE')
                   AND TO_DATE (activity_date, 'MMDDYY') =
                       fnd_conc_date.string_to_date (g_activity_date);

            COMMIT;
        ELSIF p_type = 'DED'
        THEN
            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
               SET status = 'SP', error_message = 'Successfully Processed'
             WHERE     ar_transaction_code IN ('260', '265', '530',
                                               '535')
                   AND activity_indicator IN ('1', '5')
                   AND orig_item_ref = p_item_ref
                   AND status = 'DS';

            COMMIT;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                    'Executing in UPDATE_STATUS' || SQLERRM);
    END UPDATE_STATUS;

    PROCEDURE PROCESS_DATA (p_activity_date IN VARCHAR2)
    IS
        CURSOR get_cust_data_c IS
              SELECT DISTINCT client_customer_number
                FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
               WHERE     status = 'DS'
                     AND TO_DATE (activity_date, 'MMDDYY') =
                         fnd_conc_date.string_to_date (p_activity_date)
            ORDER BY client_customer_number;

        CURSOR get_remit_data_c (p_cust_number IN VARCHAR2)
        IS
              SELECT xci.*, NULL receipt_id, NULL receipt_amount
                FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
               WHERE     status = 'DS'
                     AND TO_DATE (activity_date, 'MMDDYY') =
                         fnd_conc_date.string_to_date (p_activity_date)
                     AND client_customer_number = p_cust_number
            ORDER BY ar_transaction_code DESC;

        CURSOR get_remit_data_c1 (p_cust_number IN VARCHAR2)
        IS
              SELECT xci.*, NULL receipt_id, NULL receipt_amount
                FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
               WHERE     status = 'DS'
                     AND TO_DATE (activity_date, 'MMDDYY') =
                         fnd_conc_date.string_to_date (p_activity_date)
                     AND client_customer_number = p_cust_number
                     AND ar_transaction_code IN ('450', '330', '300')
                     AND activity_indicator IN ('4')
            ORDER BY ar_transaction_code DESC;

        CURSOR get_dm_data_c (p_inv_number IN VARCHAR2)
        IS
            SELECT xci.*
              FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
             WHERE     cust_dm_num = p_inv_number
                   AND TO_DATE (activity_date, 'MMDDYY') =
                       fnd_conc_date.string_to_date (p_activity_date)
                   AND status = 'DS'
                   AND ar_transaction_code IN ('450', '330', '300')
                   AND activity_indicator = '3';

        CURSOR get_cm_data_c (p_cust_number IN VARCHAR2)
        IS
            SELECT xci.*
              FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
             WHERE     client_customer_number = p_cust_number
                   AND TO_DATE (activity_date, 'MMDDYY') =
                       fnd_conc_date.string_to_date (p_activity_date)
                   AND ((ar_transaction_code IN ('260')              --,'265')
                                                        AND activity_indicator = '1') OR (ar_transaction_code IN ('530') --,'265')
                                                                                                                         AND activity_indicator = '5'))
                   AND status = 'DS';

        CURSOR get_adj_det_c (p_trx_number IN VARCHAR2)
        IS
            SELECT hzc.attribute1 brand, rcta.customer_trx_id, apsa.payment_schedule_id,
                   (aaa.amount * -1) amount, rcta.org_id, aaa.receivables_trx_id,
                   rcta.invoice_currency_code, rcta.trx_number, aaa.TYPE line_type
              FROM ra_customer_trx_all rcta, ra_cust_trx_types_all rctt, ar_adjustments_all aaa,
                   hz_cust_accounts hzc, ar_payment_schedules_all apsa, ar_receivables_trx_all arta
             WHERE     apsa.customer_trx_id = rcta.customer_trx_id
                   AND rctt.cust_trx_type_id = rcta.cust_trx_type_id
                   AND rctt.TYPE = 'INV'
                   AND rcta.org_id = FND_PROFILE.VALUE ('ORG_ID')
                   AND aaa.receivables_trx_id = arta.receivables_trx_id
                   AND rcta.org_id = arta.org_id
                   AND aaa.customer_trx_id = rcta.customer_trx_id
                   AND rcta.bill_to_customer_id = hzc.cust_account_id
                   AND arta.name =
                          hzc.attribute1
                       || '-'
                       || fnd_profile.VALUE (
                              'XXDO: ACTIVITY FOR CIT DEBT TRANSFER')
                   AND rcta.trx_number = LTRIM (p_trx_number, '0')
                   AND aaa.amount < 0;

        CURSOR get_cust_trx_id (p_cust_acct    IN VARCHAR2,
                                p_trx_number   IN VARCHAR2)
        IS
            SELECT customer_trx_id
              FROM ra_customer_trx_all rcta, hz_cust_accounts hca
             WHERE     hca.cust_account_id = rcta.bill_to_customer_id
                   AND rcta.attribute5 = hca.attribute1
                   AND rcta.trx_number = p_trx_number
                   AND hca.party_id = (SELECT party_id
                                         FROM hz_cust_accounts_all
                                        WHERE account_number = p_cust_acct);

        TYPE t_get_cust_data_rec IS TABLE OF get_cust_data_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_cust_data_rec              t_get_cust_data_rec;

        TYPE t_get_adj_det_rec IS TABLE OF get_adj_det_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_adj_det_rec                t_get_adj_det_rec;

        TYPE t_get_remit_data_rec IS TABLE OF get_remit_data_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_remit_data_rec             t_get_remit_data_rec;

        TYPE t_get_remit_data_rec1 IS TABLE OF get_remit_data_c1%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_remit_data_rec1            t_get_remit_data_rec1;

        TYPE t_get_dm_data_rec IS TABLE OF get_dm_data_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_dm_data_rec                t_get_dm_data_rec;

        TYPE t_get_cm_data_rec IS TABLE OF get_cm_data_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_cm_data_rec                t_get_cm_data_rec;

        l_adj_status                     VARCHAR2 (10);
        l_adj_error                      VARCHAR2 (3000);
        l_rcpt_status                    VARCHAR2 (10);
        l_rcpt_error                     VARCHAR2 (3000);
        l_appl_status                    VARCHAR2 (10);
        l_appl_error                     VARCHAR2 (3000);
        l_receipt_id                     NUMBER;
        l_full_gross_amt                 NUMBER;
        l_gross_amt                      NUMBER;
        ln_receipt_num                   VARCHAR2 (100);
        ln_inv_amount                    NUMBER;
        lc_currency_code                 VARCHAR2 (10) := 'USD';
        ln_org_id                        NUMBER := FND_PROFILE.VALUE ('ORG_ID');
        lc_reason_code                   VARCHAR2 (10);
        lc_cust_err_status               VARCHAR2 (10);
        ln_exclude_prc                   NUMBER;
        lc_wrtoff_error                  VARCHAR2 (3000);
        lc_brand                         VARCHAR2 (100);
        lc_misc_error                    VARCHAR2 (3000);
        ln_amt_due_remaining             NUMBER;
        lc_trx_number                    VARCHAR2 (100);
        lc_trx_type                      VARCHAR2 (100);
        lc_interface_header_attribute1   VARCHAR2 (100);
        ln_orig_order_id                 NUMBER;
        ln_orig_order_num                NUMBER;
        lc_sum_gross_amt                 NUMBER;
        lc_clm_status                    VARCHAR2 (100);
        lc_clm_message                   VARCHAR2 (3000);
        ln_gross_amount                  NUMBER := 0;
        l_appl_receipt_id                NUMBER;
        lc_applr_status                  VARCHAR2 (10);
        lc_applr_error                   VARCHAR2 (3000);
        ln_amount_applied                NUMBER;
        ln_cust_trx_id                   NUMBER;
    BEGIN
        l_get_cust_data_rec.DELETE;

        OPEN get_cust_data_c;

        FETCH get_cust_data_c BULK COLLECT INTO l_get_cust_data_rec;

        CLOSE get_cust_data_c;

        IF l_get_cust_data_rec.COUNT = 0
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                'No data found for the Activity data ' || p_activity_date);
            PRINT_MSG (
                'No data found for the Activity data ' || p_activity_date);
        ELSE
            PRINT_MSG ('Customer Count is ' || l_get_cust_data_rec.COUNT);

            FOR l_cust_data IN 1 .. l_get_cust_data_rec.COUNT
            LOOP
                OPEN get_cm_data_c (
                    l_get_cust_data_rec (l_cust_data).client_customer_number);

                FETCH get_cm_data_c BULK COLLECT INTO l_get_cm_data_rec;

                CLOSE get_cm_data_c;

                PRINT_MSG (
                    'CM count to update is ' || l_get_cm_data_rec.COUNT);

                IF l_get_cm_data_rec.COUNT > 0
                THEN
                    FOR l_cm_data IN 1 .. l_get_cm_data_rec.COUNT
                    LOOP
                        lc_trx_number                    := NULL;
                        lc_trx_type                      := NULL;
                        lc_interface_header_attribute1   := NULL;

                        BEGIN
                            SELECT rcta.trx_number, rctt.TYPE, rcta.interface_header_attribute1
                              INTO lc_trx_number, lc_trx_type, lc_interface_header_attribute1
                              FROM ra_customer_trx_all rcta, ra_cust_trx_types_all rctt
                             WHERE     rcta.cust_trx_type_id =
                                       rctt.cust_trx_type_id
                                   AND rcta.org_id = rctt.org_id
                                   AND rcta.org_id =
                                       FND_PROFILE.VALUE ('ORG_ID')
                                   AND trx_number =
                                       l_get_cm_data_rec (l_cm_data).cust_dm_num;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_trx_number                    := NULL;
                                lc_trx_type                      := NULL;
                                lc_interface_header_attribute1   := NULL;
                        END;

                        IF     lc_trx_number IS NOT NULL
                           AND lc_trx_type IS NOT NULL
                        THEN
                            IF lc_trx_type = 'INV'
                            THEN
                                UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
                                   SET orig_item_ref   = lc_trx_number
                                 WHERE     cust_dm_num =
                                           l_get_cm_data_rec (l_cm_data).cust_dm_num
                                       AND activity_date =
                                           l_get_cm_data_rec (l_cm_data).activity_date
                                       AND client_customer_number =
                                           l_get_cm_data_rec (l_cm_data).client_customer_number;

                                COMMIT;
                            ELSIF lc_trx_type = 'CM'
                            THEN
                                BEGIN
                                    SELECT DISTINCT ooha_orig.order_number
                                      INTO ln_orig_order_num
                                      FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_order_headers_all ooha_orig
                                     WHERE     oola.header_id =
                                               ooha.header_id
                                           AND oola.reference_header_id =
                                               ooha_orig.header_id
                                           AND ooha.order_number =
                                               lc_interface_header_attribute1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_orig_order_num   := 0;
                                END;

                                IF ln_orig_order_num <> 0
                                THEN
                                    BEGIN
                                        SELECT rcta.trx_number
                                          INTO lc_trx_number
                                          FROM ra_customer_trx_all rcta
                                         WHERE     rcta.org_id =
                                                   FND_PROFILE.VALUE (
                                                       'ORG_ID')
                                               AND trx_number =
                                                   ln_orig_order_num;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_trx_number   := NULL;
                                    END;

                                    IF lc_trx_number IS NOT NULL
                                    THEN
                                        UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
                                           SET orig_item_ref = lc_trx_number
                                         WHERE     cust_dm_num =
                                                   l_get_cm_data_rec (
                                                       l_cm_data).cust_dm_num
                                               AND activity_date =
                                                   l_get_cm_data_rec (
                                                       l_cm_data).activity_date
                                               AND client_customer_number =
                                                   l_get_cm_data_rec (
                                                       l_cm_data).client_customer_number;

                                        COMMIT;
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                    END LOOP;

                    COMMIT;
                END IF;

                lc_cust_err_status   := 'S';
                l_get_remit_data_rec1.DELETE;

                OPEN get_remit_data_c1 (
                    l_get_cust_data_rec (l_cust_data).client_customer_number);

                FETCH get_remit_data_c1
                    BULK COLLECT INTO l_get_remit_data_rec1;

                CLOSE get_remit_data_c1;

                IF l_get_remit_data_rec1.COUNT > 0
                THEN
                    FOR l_remit_data1 IN 1 .. l_get_remit_data_rec1.COUNT
                    LOOP
                        --************************* Start of 450,330  and  4 **********************************************

                        IF     l_get_remit_data_rec1 (l_remit_data1).ar_transaction_code IN
                                   ('450', '330', '300')
                           AND l_get_remit_data_rec1 (l_remit_data1).activity_indicator IN
                                   ('4')
                        THEN
                            PRINT_MSG (
                                   'Addition of unapplied cash for Item reference  '
                                || l_get_remit_data_rec1 (l_remit_data1).item_reference
                                || ' Transaction code - Activity'
                                || l_get_remit_data_rec1 (l_remit_data1).ar_transaction_code
                                || '-'
                                || l_get_remit_data_rec1 (l_remit_data1).activity_indicator);
                            CREATE_RECEIPT (
                                P_RECEIPT_NUM     =>
                                    l_get_remit_data_rec1 (l_remit_data1).item_reference,
                                P_RECEIPT_DATE    =>
                                    TO_DATE (
                                        l_get_remit_data_rec1 (l_remit_data1).activity_date,
                                        'MMDDYY'),
                                P_GL_DATE         =>
                                    TO_DATE (
                                        l_get_remit_data_rec1 (l_remit_data1).activity_date,
                                        'MMDDYY'),
                                P_RECEIPT_AMT     =>
                                    l_get_remit_data_rec1 (l_remit_data1).gross_amount,
                                P_CUST_NUM        =>
                                    l_get_remit_data_rec1 (l_remit_data1).client_customer_number,
                                P_CURR_CODE       => lc_currency_code,
                                P_ORG_ID          => ln_org_id,
                                P_COMMENTS        => NULL,
                                P_STATUS          => l_rcpt_status,
                                P_ERROR_MESSAGE   => l_rcpt_error,
                                P_RECEIPT_ID      => l_receipt_id);

                            IF l_rcpt_status = 'E'
                            THEN
                                lc_cust_err_status   := 'N';
                                UPDATE_STATUS (
                                    p_type      => 'DTL',
                                    p_status    => l_rcpt_status,
                                    p_message   => 'Rcpt ' || l_rcpt_error,
                                    p_item_ref   =>
                                        l_get_remit_data_rec1 (l_remit_data1).item_reference,
                                    p_ar_transaction_code   =>
                                        l_get_remit_data_rec1 (l_remit_data1).ar_transaction_code,
                                    p_activity_ind   =>
                                        l_get_remit_data_rec1 (l_remit_data1).activity_indicator);
                            ELSE
                                UPDATE_STATUS (
                                    p_type      => 'DTL',
                                    p_status    => 'SP',
                                    p_message   => 'Successfully Processed',
                                    p_item_ref   =>
                                        l_get_remit_data_rec1 (l_remit_data1).item_reference,
                                    p_ar_transaction_code   =>
                                        l_get_remit_data_rec1 (l_remit_data1).ar_transaction_code,
                                    p_activity_ind   =>
                                        l_get_remit_data_rec1 (l_remit_data1).activity_indicator);
                            END IF;
                        END IF;

                        IF lc_cust_err_status = 'N'
                        THEN
                            PRINT_MSG (
                                'Not Processed because of error in processing one or more invoices of this customer');
                            ROLLBACK;

                            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
                               SET status = 'E', error_message = 'Not Processed because of error in processing one or more invoices of this customer'
                             WHERE     status IN ('DS', 'SP')
                                   AND activity_date =
                                       l_get_remit_data_rec1 (l_remit_data1).activity_date
                                   AND client_customer_number =
                                       l_get_cust_data_rec (l_cust_data).client_customer_number;

                            COMMIT;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;

                l_get_remit_data_rec.DELETE;

                OPEN get_remit_data_c (
                    l_get_cust_data_rec (l_cust_data).client_customer_number);

                FETCH get_remit_data_c BULK COLLECT INTO l_get_remit_data_rec;

                CLOSE get_remit_data_c;

                PRINT_MSG (
                    'Remit data count is  ' || l_get_remit_data_rec.COUNT);

                IF l_get_remit_data_rec.COUNT > 0
                THEN
                    FOR l_remit_data IN 1 .. l_get_remit_data_rec.COUNT
                    LOOP
                        l_adj_status       := NULL;
                        l_adj_error        := NULL;
                        l_rcpt_status      := NULL;
                        l_rcpt_error       := NULL;
                        l_appl_status      := NULL;
                        l_appl_error       := NULL;
                        l_receipt_id       := NULL;
                        l_full_gross_amt   := NULL;
                        l_gross_amt        := NULL;
                        ln_receipt_num     := NULL;
                        ln_inv_amount      := NULL;
                        ln_exclude_prc     := NULL;
                        lc_wrtoff_error    := NULL;
                        lc_brand           := NULL;
                        lc_misc_error      := NULL;
                        lc_reason_code     := NULL;


                        --************************* Start of 010  and  2 **********************************************
                        PRINT_MSG (
                               'Full item charge back for Item reference  '
                            || l_get_remit_data_rec (l_remit_data).item_reference
                            || ' Transaction code - Activity'
                            || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                            || '-'
                            || l_get_remit_data_rec (l_remit_data).activity_indicator);

                        IF     l_get_remit_data_rec (l_remit_data).ar_transaction_code =
                               '010'
                           AND l_get_remit_data_rec (l_remit_data).activity_indicator =
                               '2'
                        THEN
                            OPEN get_adj_det_c (
                                l_get_remit_data_rec (l_remit_data).item_reference);

                            FETCH get_adj_det_c
                                BULK COLLECT INTO l_get_adj_det_rec;

                            CLOSE get_adj_det_c;

                            FOR i IN 1 .. l_get_adj_det_rec.COUNT
                            LOOP
                                PRINT_MSG (
                                       'Creating Adjustment for amount '
                                    || l_get_adj_det_rec (i).amount
                                    || ' Item reference  '
                                    || l_get_remit_data_rec (l_remit_data).item_reference
                                    || ' Transaction code - Activity'
                                    || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                                    || '-'
                                    || l_get_remit_data_rec (l_remit_data).activity_indicator);
                                CREATE_ADJUSTMENT (
                                    P_CUST_TRX_ID     =>
                                        l_get_adj_det_rec (i).customer_trx_id,
                                    P_REC_TRX_ID      =>
                                        l_get_adj_det_rec (i).receivables_trx_id,
                                    P_PAY_SCHD_ID     =>
                                        l_get_adj_det_rec (i).payment_schedule_id,
                                    P_AMOUNT          => l_get_adj_det_rec (i).amount,
                                    P_APPLY_DATE      =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    P_APPLY_GL_DATE   =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    P_LINE_TYPE       =>
                                        l_get_adj_det_rec (i).line_type,
                                    P_ORG_ID          => l_get_adj_det_rec (i).org_id,
                                    P_STATUS          => l_adj_status,
                                    P_ERROR_MESSAGE   => l_adj_error);

                                IF l_adj_status = 'E'
                                THEN
                                    PRINT_MSG (
                                           'Adjustment error for  Item reference  '
                                        || l_get_remit_data_rec (
                                               l_remit_data).item_reference
                                        || ' Transaction code - Activity'
                                        || l_get_remit_data_rec (
                                               l_remit_data).ar_transaction_code
                                        || '-'
                                        || l_get_remit_data_rec (
                                               l_remit_data).activity_indicator);

                                    lc_cust_err_status   := 'N';

                                    UPDATE_STATUS (
                                        p_type      => 'DTL',
                                        p_status    => l_adj_status,
                                        p_message   => 'Adj ' || l_adj_error,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                    EXIT;
                                END IF;
                            END LOOP;

                            IF l_adj_status <> 'E'
                            THEN
                                SELECT 'CIT' || LPAD (XXDO.XXDO_OM_CIT_REMIT_S.NEXTVAL, 7, 0)
                                  INTO ln_receipt_num
                                  FROM DUAL;

                                PRINT_MSG (
                                       'Creating receipt for 0 amount for Item reference  '
                                    || l_get_remit_data_rec (l_remit_data).item_reference
                                    || ' Transaction code - Activity'
                                    || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                                    || '-'
                                    || l_get_remit_data_rec (l_remit_data).activity_indicator);
                                CREATE_RECEIPT (
                                    p_receipt_num     => ln_receipt_num,
                                    p_receipt_date    =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_gl_date         =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_receipt_amt     => 0,
                                    p_cust_num        =>
                                        l_get_remit_data_rec (l_remit_data).client_customer_number,
                                    p_curr_code       => lc_currency_code,
                                    p_org_id          => ln_org_id,
                                    p_comments        => NULL,
                                    p_status          => l_rcpt_status,
                                    p_error_message   => l_rcpt_error,
                                    p_receipt_id      => l_receipt_id);

                                IF l_rcpt_status = 'E'
                                THEN
                                    PRINT_MSG (
                                           'Receipt creation for Item reference  '
                                        || l_get_remit_data_rec (
                                               l_remit_data).item_reference
                                        || ' Transaction code - Activity'
                                        || l_get_remit_data_rec (
                                               l_remit_data).ar_transaction_code
                                        || '-'
                                        || l_get_remit_data_rec (
                                               l_remit_data).activity_indicator);
                                    lc_cust_err_status   := 'N';

                                    UPDATE_STATUS (
                                        p_type      => 'DTL',
                                        p_status    => l_rcpt_status,
                                        p_message   => 'Rcpt ' || l_rcpt_error,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                ELSE
                                    PRINT_MSG (
                                           'Applying receipt for 0 amount for Item reference  '
                                        || l_get_remit_data_rec (
                                               l_remit_data).item_reference
                                        || ' Transaction code - Activity'
                                        || l_get_remit_data_rec (
                                               l_remit_data).ar_transaction_code
                                        || '-'
                                        || l_get_remit_data_rec (
                                               l_remit_data).activity_indicator);

                                    OPEN get_cust_trx_id (
                                        l_get_remit_data_rec (l_remit_data).client_customer_number,
                                        l_get_remit_data_rec (l_remit_data).item_reference);

                                    FETCH get_cust_trx_id INTO ln_cust_trx_id;

                                    CLOSE get_cust_trx_id;

                                    PRINT_MSG (
                                           'Customer trx id is '
                                        || ln_cust_trx_id);
                                    PRINT_MSG ('Org id  is ' || ln_org_id);
                                    PRINT_MSG (
                                        'Receipt id is ' || l_receipt_id);
                                    APPLY_RECEIPT (
                                        p_receipt_id       => l_receipt_id,
                                        p_trx_number       => ln_cust_trx_id,
                                        p_amount_applied   => 0,
                                        p_apply_date       =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        p_apply_gl_date    =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        p_reason_code      =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_reason_code,
                                        p_status           => l_appl_status,
                                        p_error_message    => l_appl_error);

                                    IF l_appl_status = 'E'
                                    THEN
                                        PRINT_MSG (
                                               'Error Applying Receipt for Item reference  '
                                            || l_get_remit_data_rec (
                                                   l_remit_data).item_reference
                                            || ' Transaction code - Activity'
                                            || l_get_remit_data_rec (
                                                   l_remit_data).ar_transaction_code
                                            || '-'
                                            || l_get_remit_data_rec (
                                                   l_remit_data).activity_indicator);
                                        lc_cust_err_status   := 'N';
                                        UPDATE_STATUS (
                                            p_type     => 'DTL',
                                            p_status   => l_appl_status,
                                            p_message   =>
                                                'Appl ' || l_appl_error,
                                            p_item_ref   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).ar_transaction_code,
                                            p_activity_ind   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_indicator);
                                    ELSE
                                        PRINT_MSG (
                                               'Successfully processed for Item reference  '
                                            || l_get_remit_data_rec (
                                                   l_remit_data).item_reference
                                            || ' Transaction code - Activity'
                                            || l_get_remit_data_rec (
                                                   l_remit_data).ar_transaction_code
                                            || '-'
                                            || l_get_remit_data_rec (
                                                   l_remit_data).activity_indicator);
                                        UPDATE_STATUS (
                                            p_type     => 'DTL',
                                            p_status   => 'SP',
                                            p_message   =>
                                                'Successfully Processed',
                                            p_item_ref   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).ar_transaction_code,
                                            p_activity_ind   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_indicator);
                                    END IF;
                                END IF;
                            END IF;
                        --************************* Start of 260,265  and  1 **********************************************

                        ELSIF     ((l_get_remit_data_rec (l_remit_data).ar_transaction_code IN ('260', '265') AND l_get_remit_data_rec (l_remit_data).activity_indicator = '1') OR (l_get_remit_data_rec (l_remit_data).ar_transaction_code IN ('535', '530') AND l_get_remit_data_rec (l_remit_data).activity_indicator = '5'))
                              AND l_get_remit_data_rec (l_remit_data).orig_item_ref
                                      IS NULL
                        THEN
                            PRINT_MSG (
                                   'Immediate Chargeback/Creditback for Item reference  '
                                || l_get_remit_data_rec (l_remit_data).item_reference
                                || ' Transaction code - Activity'
                                || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                                || '-'
                                || l_get_remit_data_rec (l_remit_data).activity_indicator);

                            BEGIN
                                SELECT cash_receipt_id
                                  INTO l_receipt_id
                                  FROM (  SELECT cash_receipt_id
                                            FROM ar_cash_receipts_all acra, hz_cust_accounts hca
                                           WHERE     SUBSTR (
                                                         acra.comments,
                                                         1,
                                                           INSTR (
                                                               acra.comments,
                                                               CHR (10),
                                                               1)
                                                         - 1) =
                                                     l_get_remit_data_rec (
                                                         l_remit_data).check_number
                                                 AND TO_CHAR (
                                                         acra.receipt_date,
                                                         'MMDDYY') =
                                                     l_get_remit_data_rec (
                                                         l_remit_data).activity_date
                                                 AND hca.cust_account_id =
                                                     acra.pay_from_customer
                                                 AND hca.account_number =
                                                     l_get_remit_data_rec (
                                                         l_remit_data).client_customer_number
                                        ORDER BY acra.creation_date DESC)
                                 WHERE ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_receipt_id   := -99;
                            END;

                            IF l_receipt_id = -99
                            THEN
                                SELECT 'CIT' || LPAD (XXDO.XXDO_OM_CIT_REMIT_S.NEXTVAL, 7, 0)
                                  INTO ln_receipt_num
                                  FROM DUAL;

                                l_rcpt_status   := 'S';

                                CREATE_RECEIPT (
                                    p_receipt_num     => ln_receipt_num,
                                    p_receipt_date    =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_gl_date         =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_receipt_amt     =>
                                        l_get_remit_data_rec (l_remit_data).check_amount,
                                    p_cust_num        =>
                                        l_get_remit_data_rec (l_remit_data).client_customer_number,
                                    p_curr_code       => lc_currency_code,
                                    p_org_id          => ln_org_id,
                                    p_comments        =>
                                           l_get_remit_data_rec (
                                               l_remit_data).check_number
                                        || CHR (10),
                                    p_status          => l_rcpt_status,
                                    p_error_message   => l_rcpt_error,
                                    p_receipt_id      => l_receipt_id);
                            END IF;

                            IF l_rcpt_status = 'E'
                            THEN
                                lc_cust_err_status   := 'N';

                                UPDATE_STATUS (
                                    p_type      => 'DTL',
                                    p_status    => l_rcpt_status,
                                    p_message   => 'Rcpt ' || l_rcpt_error,
                                    p_item_ref   =>
                                        l_get_remit_data_rec (l_remit_data).item_reference,
                                    p_ar_transaction_code   =>
                                        l_get_remit_data_rec (l_remit_data).ar_transaction_code,
                                    p_activity_ind   =>
                                        l_get_remit_data_rec (l_remit_data).activity_indicator);
                            ELSE
                                IF l_get_remit_data_rec (l_remit_data).ar_transaction_code IN
                                       ('260', '530')
                                THEN
                                    l_get_remit_data_rec (l_remit_data).gross_amount   :=
                                          l_get_remit_data_rec (l_remit_data).gross_amount
                                        * -1;
                                END IF;

                                lc_brand   := NULL;

                                BEGIN
                                    SELECT attribute1
                                      INTO lc_brand
                                      FROM hz_cust_accounts_all
                                     WHERE account_number =
                                           l_get_remit_data_rec (
                                               l_remit_data).client_customer_number;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lc_brand   := NULL;
                                END;

                                CLAIM_INVESTIGATION (
                                    p_receipt_id   => l_receipt_id,
                                    p_activity_date   =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_amount       =>
                                        l_get_remit_data_rec (l_remit_data).gross_amount,
                                    p_reason_code   =>
                                        l_get_remit_data_rec (l_remit_data).ar_reason_code,
                                    p_brand        => lc_brand,
                                    p_status       => lc_clm_status,
                                    p_message      => lc_clm_message);

                                IF lc_clm_status = 'E'
                                THEN
                                    lc_cust_err_status   := 'N';
                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'E',
                                        p_message   =>
                                            'CLM ' || lc_clm_message,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                ELSE
                                    UPDATE ar_cash_receipts_all
                                       SET comments = comments || ' CM is ' || l_get_remit_data_rec (l_remit_data).cust_dm_num || CHR (10)
                                     WHERE cash_receipt_id = l_receipt_id;

                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'SP',
                                        p_message   =>
                                            'Successfully Processed',
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                END IF;
                            END IF;
                        --************************* Start of '450','330','300'  and  2 **********************************************

                        ELSIF     l_get_remit_data_rec (l_remit_data).ar_transaction_code IN
                                      ('450', '330', '300')
                              AND l_get_remit_data_rec (l_remit_data).activity_indicator =
                                  '2'
                        THEN
                            PRINT_MSG (
                                   'Full Item Creditback for Item reference  '
                                || l_get_remit_data_rec (l_remit_data).item_reference
                                || ' Transaction code - Activity'
                                || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                                || '-'
                                || l_get_remit_data_rec (l_remit_data).activity_indicator);

                            BEGIN
                                SELECT cash_receipt_id
                                  INTO l_receipt_id
                                  FROM (  SELECT cash_receipt_id
                                            FROM ar_cash_receipts_all
                                           WHERE receipt_number =
                                                 l_get_remit_data_rec (
                                                     l_remit_data).item_reference
                                        ORDER BY creation_date DESC)
                                 WHERE ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_receipt_id   := -99;
                            END;

                            IF l_receipt_id = -99
                            THEN
                                l_rcpt_status   := 'S';

                                CREATE_RECEIPT (
                                    p_receipt_num     =>
                                        l_get_remit_data_rec (l_remit_data).item_reference,
                                    p_receipt_date    =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_gl_date         =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_receipt_amt     =>
                                        l_get_remit_data_rec (l_remit_data).check_amount,
                                    p_cust_num        =>
                                        l_get_remit_data_rec (l_remit_data).client_customer_number,
                                    p_curr_code       => lc_currency_code,
                                    p_org_id          => ln_org_id,
                                    p_comments        =>
                                           l_get_remit_data_rec (
                                               l_remit_data).check_number
                                        || CHR (10),
                                    p_status          => l_rcpt_status,
                                    p_error_message   => l_rcpt_error,
                                    p_receipt_id      => l_receipt_id);
                            END IF;

                            IF l_rcpt_status = 'E'
                            THEN
                                lc_cust_err_status   := 'N';

                                UPDATE_STATUS (
                                    p_type      => 'DTL',
                                    p_status    => l_rcpt_status,
                                    p_message   => 'Rcpt ' || l_rcpt_error,
                                    p_item_ref   =>
                                        l_get_remit_data_rec (l_remit_data).item_reference,
                                    p_ar_transaction_code   =>
                                        l_get_remit_data_rec (l_remit_data).ar_transaction_code,
                                    p_activity_ind   =>
                                        l_get_remit_data_rec (l_remit_data).activity_indicator);
                            ELSE
                                lc_brand   := NULL;

                                BEGIN
                                    SELECT attribute1
                                      INTO lc_brand
                                      FROM hz_cust_accounts_all
                                     WHERE account_number =
                                           l_get_remit_data_rec (
                                               l_remit_data).client_customer_number;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lc_brand   := NULL;
                                END;

                                CLAIM_INVESTIGATION (
                                    p_receipt_id   => l_receipt_id,
                                    p_activity_date   =>
                                        TO_DATE (
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_date,
                                            'MMDDYY'),
                                    p_amount       => lc_sum_gross_amt,
                                    p_reason_code   =>
                                        l_get_remit_data_rec (l_remit_data).ar_reason_code,
                                    p_brand        => lc_brand,
                                    p_status       => lc_clm_status,
                                    p_message      => lc_clm_message);

                                IF lc_clm_status = 'E'
                                THEN
                                    lc_cust_err_status   := 'N';
                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'E',
                                        p_message   =>
                                            'CLM ' || lc_clm_message,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                ELSE
                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'SP',
                                        p_message   =>
                                            'Successfully Processed',
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                END IF;
                            END IF;
                        --************************* Start of 010  and  3 **********************************************
                        ELSIF     l_get_remit_data_rec (l_remit_data).ar_transaction_code IN
                                      ('010')
                              AND l_get_remit_data_rec (l_remit_data).activity_indicator IN
                                      ('3', '5')
                        THEN
                            PRINT_MSG (
                                   'Full Item payment for Item reference  '
                                || l_get_remit_data_rec (l_remit_data).item_reference
                                || ' Transaction code - Activity'
                                || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                                || '-'
                                || l_get_remit_data_rec (l_remit_data).activity_indicator);

                            OPEN get_adj_det_c (
                                l_get_remit_data_rec (l_remit_data).item_reference);

                            FETCH get_adj_det_c
                                BULK COLLECT INTO l_get_adj_det_rec;

                            CLOSE get_adj_det_c;

                            FOR i IN 1 .. l_get_adj_det_rec.COUNT
                            LOOP
                                IF l_get_adj_det_rec (i).customer_trx_id
                                       IS NULL
                                THEN
                                    lc_cust_err_status   := 'N';
                                    l_adj_status         := 'E';
                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'E',
                                        p_message   =>
                                            'No adjustment is found for this invoice',
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                    EXIT;
                                ELSE
                                    CREATE_ADJUSTMENT (
                                        P_CUST_TRX_ID     =>
                                            l_get_adj_det_rec (i).customer_trx_id,
                                        P_REC_TRX_ID      =>
                                            l_get_adj_det_rec (i).receivables_trx_id,
                                        P_PAY_SCHD_ID     =>
                                            l_get_adj_det_rec (i).payment_schedule_id,
                                        P_AMOUNT          =>
                                            l_get_adj_det_rec (i).amount,
                                        P_APPLY_DATE      =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        P_APPLY_GL_DATE   =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        P_LINE_TYPE       =>
                                            l_get_adj_det_rec (i).line_type,
                                        P_ORG_ID          =>
                                            l_get_adj_det_rec (i).org_id,
                                        P_STATUS          => l_adj_status,
                                        P_ERROR_MESSAGE   => l_adj_error);

                                    IF l_adj_status = 'E'
                                    THEN
                                        lc_cust_err_status   := 'N';

                                        UPDATE_STATUS (
                                            p_type     => 'DTL',
                                            p_status   => l_adj_status,
                                            p_message   =>
                                                'Adj ' || l_adj_error,
                                            p_item_ref   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).ar_transaction_code,
                                            p_activity_ind   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_indicator);
                                        EXIT;
                                    END IF;
                                END IF;
                            END LOOP;

                            IF l_adj_status <> 'E'
                            THEN
                                BEGIN
                                    SELECT cash_receipt_id
                                      INTO l_receipt_id
                                      FROM (  SELECT cash_receipt_id
                                                FROM ar_cash_receipts_all acra, hz_cust_accounts hca
                                               WHERE     SUBSTR (
                                                             acra.comments,
                                                             1,
                                                               INSTR (
                                                                   acra.comments,
                                                                   CHR (10),
                                                                   1)
                                                             - 1) =
                                                         l_get_remit_data_rec (
                                                             l_remit_data).check_number
                                                     AND TO_CHAR (
                                                             acra.receipt_date,
                                                             'MMDDYY') =
                                                         l_get_remit_data_rec (
                                                             l_remit_data).activity_date
                                                     AND hca.cust_account_id =
                                                         acra.pay_from_customer
                                                     AND hca.account_number =
                                                         l_get_remit_data_rec (
                                                             l_remit_data).client_customer_number
                                            ORDER BY acra.creation_date DESC)
                                     WHERE ROWNUM = 1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_receipt_id   := -99;
                                END;

                                IF l_receipt_id = -99
                                THEN
                                    SELECT 'CIT' || LPAD (XXDO.XXDO_OM_CIT_REMIT_S.NEXTVAL, 7, 0)
                                      INTO ln_receipt_num
                                      FROM DUAL;

                                    l_rcpt_status   := 'S';

                                    CREATE_RECEIPT (
                                        p_receipt_num     => ln_receipt_num,
                                        p_receipt_date    =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        p_gl_date         =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        p_receipt_amt     =>
                                            l_get_remit_data_rec (
                                                l_remit_data).check_amount,
                                        p_cust_num        =>
                                            l_get_remit_data_rec (
                                                l_remit_data).client_customer_number,
                                        p_curr_code       => lc_currency_code,
                                        p_org_id          => ln_org_id,
                                        p_comments        =>
                                               l_get_remit_data_rec (
                                                   l_remit_data).check_number
                                            || CHR (10),
                                        p_status          => l_rcpt_status,
                                        p_error_message   => l_rcpt_error,
                                        p_receipt_id      => l_receipt_id);
                                END IF;

                                IF l_rcpt_status = 'E'
                                THEN
                                    lc_cust_err_status   := 'N';

                                    UPDATE_STATUS (
                                        p_type      => 'DTL',
                                        p_status    => l_rcpt_status,
                                        p_message   => 'Rcpt ' || l_rcpt_error,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                ELSE
                                    l_get_dm_data_rec.DELETE;

                                    OPEN get_dm_data_c (
                                        l_get_remit_data_rec (l_remit_data).item_reference);

                                    FETCH get_dm_data_c
                                        BULK COLLECT INTO l_get_dm_data_rec;

                                    CLOSE get_dm_data_c;

                                    IF l_get_dm_data_rec.COUNT > 0
                                    THEN
                                        FOR l_dm_data IN 1 ..
                                                         l_get_dm_data_rec.COUNT
                                        LOOP
                                            l_appl_receipt_id   := -99;

                                            BEGIN
                                                SELECT cash_receipt_id
                                                  INTO l_appl_receipt_id
                                                  FROM (  SELECT cash_receipt_id
                                                            FROM ar_cash_receipts_all
                                                           WHERE receipt_number =
                                                                 l_get_dm_data_rec (
                                                                     l_dm_data).item_reference
                                                        ORDER BY creation_date DESC)
                                                 WHERE ROWNUM = 1;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    l_appl_receipt_id   :=
                                                        -99;
                                            END;

                                            APPLY_RECPT_ON_RCPT (
                                                p_receipt_id   => l_receipt_id,
                                                p_appl_receipt_id   =>
                                                    l_appl_receipt_id,
                                                p_amount_applied   =>
                                                    l_get_dm_data_rec (
                                                        l_dm_data).gross_amount,
                                                p_activity_date   =>
                                                    TO_DATE (
                                                        l_get_dm_data_rec (
                                                            l_dm_data).activity_date,
                                                        'MMDDYY'),
                                                p_status       =>
                                                    lc_applr_status,
                                                p_message      =>
                                                    lc_applr_error);

                                            IF lc_applr_status = 'E'
                                            THEN
                                                lc_cust_err_status   := 'N';
                                                UPDATE_STATUS (
                                                    p_type     => 'DTL',
                                                    p_status   => 'E',
                                                    p_message   =>
                                                           'APPLR '
                                                        || lc_applr_error,
                                                    p_item_ref   =>
                                                        l_get_dm_data_rec (
                                                            l_dm_data).item_reference,
                                                    p_ar_transaction_code   =>
                                                        l_get_dm_data_rec (
                                                            l_dm_data).ar_transaction_code,
                                                    p_activity_ind   =>
                                                        l_get_dm_data_rec (
                                                            l_dm_data).activity_indicator);
                                            ELSE
                                                UPDATE_STATUS (
                                                    p_type     => 'DTL',
                                                    p_status   => 'SP',
                                                    p_message   =>
                                                        'Successfully Processed',
                                                    p_item_ref   =>
                                                        l_get_dm_data_rec (
                                                            l_dm_data).item_reference,
                                                    p_ar_transaction_code   =>
                                                        l_get_dm_data_rec (
                                                            l_dm_data).ar_transaction_code,
                                                    p_activity_ind   =>
                                                        l_get_dm_data_rec (
                                                            l_dm_data).activity_indicator);
                                            END IF;
                                        END LOOP;
                                    END IF;

                                    BEGIN
                                        SELECT MIN (xci.ar_reason_code), NVL (SUM (xci.gross_amount), 0)
                                          INTO lc_reason_code, ln_gross_amount
                                          FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
                                         WHERE     orig_item_ref =
                                                   l_get_remit_data_rec (
                                                       l_remit_data).item_reference
                                               AND activity_date =
                                                   l_get_remit_data_rec (
                                                       l_remit_data).activity_date
                                               AND status = 'DS'
                                               AND (ar_transaction_code = '260' AND activity_indicator = '1' OR ar_transaction_code = '530' AND activity_indicator = '5');
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_reason_code    := '99';
                                            ln_gross_amount   := 0;
                                    END;

                                    OPEN get_cust_trx_id (
                                        l_get_remit_data_rec (l_remit_data).client_customer_number,
                                        l_get_remit_data_rec (l_remit_data).item_reference);

                                    FETCH get_cust_trx_id INTO ln_cust_trx_id;

                                    CLOSE get_cust_trx_id;

                                    APPLY_RECEIPT (
                                        p_receipt_id      => l_receipt_id,
                                        p_trx_number      => ln_cust_trx_id,
                                        P_AMOUNT_APPLIED   =>
                                              l_get_remit_data_rec (
                                                  l_remit_data).gross_amount
                                            - ln_gross_amount,
                                        P_APPLY_DATE      =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        P_APPLY_GL_DATE   =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        P_REASON_CODE     => lc_reason_code,
                                        P_STATUS          => l_appl_status,
                                        P_ERROR_MESSAGE   => l_appl_error);

                                    IF l_appl_status = 'E'
                                    THEN
                                        lc_cust_err_status   := 'N';
                                        UPDATE_STATUS (
                                            p_type     => 'DTL',
                                            p_status   => 'E',
                                            p_message   =>
                                                'APPL ' || l_appl_error,
                                            p_item_ref   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).ar_transaction_code,
                                            p_activity_ind   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_indicator);
                                    ELSE
                                        UPDATE_STATUS (
                                            p_type                  => 'DED',
                                            p_status                => 'SP',
                                            p_message               =>
                                                'Successfully Processed',
                                            p_item_ref              =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   => NULL,
                                            p_activity_ind          => NULL);

                                        UPDATE_STATUS (
                                            p_type     => 'DTL',
                                            p_status   => 'SP',
                                            p_message   =>
                                                'Successfully Processed',
                                            p_item_ref   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).ar_transaction_code,
                                            p_activity_ind   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_indicator);
                                    END IF;
                                END IF;
                            END IF;
                        -- END IF;

                        --************************* Start of '450','330','300','339','309','459'  and  3 **********************************************

                        ELSIF     l_get_remit_data_rec (l_remit_data).ar_transaction_code IN
                                      ('450', '330', '300',
                                       '339', '309', '459')
                              AND l_get_remit_data_rec (l_remit_data).activity_indicator IN
                                      ('3')
                        THEN
                            PRINT_MSG (
                                   'Removal of on account for Item reference  '
                                || l_get_remit_data_rec (l_remit_data).item_reference
                                || ' Transaction code - Activity'
                                || l_get_remit_data_rec (l_remit_data).ar_transaction_code
                                || '-'
                                || l_get_remit_data_rec (l_remit_data).activity_indicator);
                            ln_exclude_prc   := 0;

                            SELECT COUNT (*)
                              INTO ln_exclude_prc
                              FROM xxdo_cit_inbnd_ar_act_dtl_stg
                             WHERE     item_reference =
                                       l_get_remit_data_rec (l_remit_data).cust_dm_num
                                   AND l_get_remit_data_rec (l_remit_data).ar_transaction_code IN
                                           ('450', '330', '300',
                                            '339', '309', '459')
                                   AND l_get_remit_data_rec (l_remit_data).activity_indicator IN
                                           ('3')
                                   AND activity_date =
                                       l_get_remit_data_rec (l_remit_data).activity_date
                                   AND activity_indicator = '3';

                            print_msg (
                                   'Exclude ln_exclude_prc is '
                                || ln_exclude_prc);

                            IF ln_exclude_prc = 0
                            THEN
                                BEGIN
                                    SELECT cash_receipt_id
                                      INTO l_receipt_id
                                      FROM (  SELECT cash_receipt_id
                                                FROM ar_cash_receipts_all acra, hz_cust_accounts hca
                                               WHERE     acra.receipt_number =
                                                         l_get_remit_data_rec (
                                                             l_remit_data).item_reference
                                                     -- AND TO_CHAR(acra.receipt_date,'MMDDYY') = l_get_remit_data_rec(l_remit_data).activity_date
                                                     AND hca.cust_account_id =
                                                         acra.pay_from_customer
                                                     AND hca.account_number =
                                                         l_get_remit_data_rec (
                                                             l_remit_data).client_customer_number
                                            ORDER BY acra.creation_date DESC)
                                     WHERE ROWNUM = 1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_receipt_id   := -99;
                                END;

                                BEGIN
                                    SELECT attribute1
                                      INTO lc_brand
                                      FROM hz_cust_accounts_all
                                     WHERE account_number =
                                           l_get_remit_data_rec (
                                               l_remit_data).client_customer_number;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lc_brand   := NULL;
                                END;

                                IF lc_brand = NULL
                                THEN
                                    lc_cust_err_status   := 'N';
                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'E',
                                        p_message   =>
                                               'Wrtoff '
                                            || 'Brand is not available for cust account '
                                            || l_get_remit_data_rec (
                                                   l_remit_data).client_customer_number,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                END IF;

                                IF l_receipt_id = -99
                                THEN
                                    lc_cust_err_status   := 'N';
                                    UPDATE_STATUS (
                                        p_type     => 'DTL',
                                        p_status   => 'E',
                                        p_message   =>
                                               'Wrtoff '
                                            || 'Receipt is not available with refernce '
                                            || l_get_remit_data_rec (
                                                   l_remit_data).item_reference,
                                        p_item_ref   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).item_reference,
                                        p_ar_transaction_code   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).ar_transaction_code,
                                        p_activity_ind   =>
                                            l_get_remit_data_rec (
                                                l_remit_data).activity_indicator);
                                END IF;

                                IF     l_receipt_id <> -99
                                   AND lc_brand IS NOT NULL
                                THEN
                                    FND_FILE.PUT_LINE (
                                        FND_FILE.LOG,
                                           'l_get_remit_data_rec(l_remit_data).gross_amount '
                                        || l_get_remit_data_rec (
                                               l_remit_data).gross_amount
                                        || ' AND  ln_amount_applied '
                                        || ln_amount_applied);
                                    RECEIPT_WRITE_OFF (
                                        p_Cash_Receipt_ID   => l_receipt_id,
                                        p_Amt_Applied       =>
                                            l_get_remit_data_rec (
                                                l_remit_data).gross_amount,
                                        p_activity_date     =>
                                            TO_DATE (
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_date,
                                                'MMDDYY'),
                                        p_Brand             => lc_brand,
                                        x_Error_Msg         => lc_wrtoff_error);

                                    IF lc_wrtoff_error IS NOT NULL
                                    THEN
                                        lc_cust_err_status   := 'N';
                                        UPDATE_STATUS (
                                            p_type     => 'DTL',
                                            p_status   => 'E',
                                            p_message   =>
                                                'Wrtoff ' || lc_wrtoff_error,
                                            p_item_ref   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).item_reference,
                                            p_ar_transaction_code   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).ar_transaction_code,
                                            p_activity_ind   =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).activity_indicator);
                                    ELSE
                                        CREATE_MISC_RECEIPT (
                                            p_currency_code   =>
                                                lc_currency_code,
                                            p_amount    =>
                                                l_get_remit_data_rec (
                                                    l_remit_data).gross_amount,
                                            p_activity_date   =>
                                                TO_DATE (
                                                    l_get_remit_data_rec (
                                                        l_remit_data).activity_date,
                                                    'MMDDYY'),
                                            p_brand     => lc_brand,
                                            p_message   => lc_misc_error);

                                        IF lc_misc_error IS NOT NULL
                                        THEN
                                            lc_cust_err_status   := 'N';
                                            UPDATE_STATUS (
                                                p_type     => 'DTL',
                                                p_status   => 'E',
                                                p_message   =>
                                                    'Misc ' || lc_misc_error,
                                                p_item_ref   =>
                                                    l_get_remit_data_rec (
                                                        l_remit_data).item_reference,
                                                p_ar_transaction_code   =>
                                                    l_get_remit_data_rec (
                                                        l_remit_data).ar_transaction_code,
                                                p_activity_ind   =>
                                                    l_get_remit_data_rec (
                                                        l_remit_data).activity_indicator);
                                        ELSE
                                            UPDATE_STATUS (
                                                p_type     => 'DTL',
                                                p_status   => 'SP',
                                                p_message   =>
                                                    'Successfully Processed',
                                                p_item_ref   =>
                                                    l_get_remit_data_rec (
                                                        l_remit_data).item_reference,
                                                p_ar_transaction_code   =>
                                                    l_get_remit_data_rec (
                                                        l_remit_data).ar_transaction_code,
                                                p_activity_ind   =>
                                                    l_get_remit_data_rec (
                                                        l_remit_data).activity_indicator);
                                        END IF;
                                    END IF;
                                END IF;
                            END IF;
                        END IF;                                     -- Main if

                        IF lc_cust_err_status = 'N'
                        THEN
                            PRINT_MSG (
                                'Not Processed because of error in processing one or more invoices of this customer');
                            ROLLBACK;

                            UPDATE xxdo_cit_inbnd_ar_act_dtl_stg
                               SET status = 'E', error_message = 'Not Processed because of error in processing one or more invoices of this customer'
                             WHERE     status IN ('DS', 'SP')
                                   AND activity_date =
                                       l_get_remit_data_rec (l_remit_data).activity_date
                                   AND client_customer_number =
                                       l_get_cust_data_rec (l_cust_data).client_customer_number;

                            COMMIT;
                            EXIT;
                        ELSE
                            COMMIT;
                        END IF;
                    END LOOP;                               -- remit data loop
                END IF;                                       -- Remit data if
            END LOOP;                                              --cust loop
        END IF;                                                -- Cust loop if

        UPDATE_STATUS (p_type                  => 'REM',
                       p_status                => NULL,
                       p_message               => NULL,
                       p_item_ref              => NULL,
                       p_ar_transaction_code   => NULL,
                       p_activity_ind          => NULL);
    EXCEPTION
        WHEN OTHERS
        THEN
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                    'Executing in PROCESS_DATA' || SQLERRM);
            PRINT_MSG ('Executing in PROCESS_DATA' || SQLERRM);
    END PROCESS_DATA;

    PROCEDURE CREATE_RECEIPT (P_RECEIPT_NUM     IN     VARCHAR2,
                              P_RECEIPT_DATE    IN     DATE,
                              P_GL_DATE         IN     DATE,
                              P_RECEIPT_AMT     IN     NUMBER,
                              P_CUST_NUM        IN     VARCHAR2,
                              P_CURR_CODE       IN     VARCHAR2,
                              P_ORG_ID          IN     NUMBER,
                              P_COMMENTS        IN     VARCHAR2,
                              P_STATUS             OUT VARCHAR2,
                              P_ERROR_MESSAGE      OUT VARCHAR2,
                              P_RECEIPT_ID         OUT NUMBER)
    IS
        x_cash_receipt_id      NUMBER;
        l_return_status        VARCHAR2 (10);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (3000);
        ln_receipt_method_id   NUMBER;
    BEGIN
        SELECT receipt_method_id
          INTO ln_receipt_method_id
          FROM AR_RECEIPT_METHODS
         WHERE name = FND_PROFILE.VALUE ('XXDO: CIT RECEIPT METHOD');

        P_STATUS          := 'Y';
        P_ERROR_MESSAGE   := NULL;

        DBMS_OUTPUT.put_line (
            'Inside before Create Receipt0.1' || x_cash_receipt_id);
        AR_RECEIPT_API_PUB.CREATE_CASH (
            p_api_version         => 1.0,
            p_init_msg_list       => fnd_api.g_true,
            p_receipt_number      => p_receipt_num,
            p_receipt_date        => p_receipt_date,
            p_amount              => p_receipt_amt,
            p_gl_date             => p_gl_date,
            p_receipt_method_id   => ln_receipt_method_id,
            p_customer_number     => p_cust_num,
            p_currency_code       => p_curr_code,
            p_org_id              => p_org_id,
            p_comments            => p_comments,
            p_cr_id               => x_cash_receipt_id,       -- out parameter
            x_return_status       => l_return_status,
            x_msg_count           => l_msg_count,
            x_msg_data            => l_msg_data);

        IF l_return_status <> Fnd_Api.G_RET_STS_SUCCESS
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                l_msg_data   :=
                       l_msg_data
                    || 'Error '
                    || i
                    || ' is: '
                    || ' '
                    || Fnd_Msg_Pub.get (i, 'F');                 --X_MSG_DATA;
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Exception while creating Receipt ' || l_msg_data);
            END LOOP;

            DBMS_OUTPUT.put_line (
                'Inside After Create Receipt0.1' || l_msg_data);
            P_STATUS          := 'E';
            P_ERROR_MESSAGE   := l_msg_data;
        ELSE
            P_RECEIPT_ID   := x_cash_receipt_id;
            DBMS_OUTPUT.put_line (
                'Inside Create Receipt' || x_cash_receipt_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS          := 'E';
            P_ERROR_MESSAGE   := 'Exception at CREATE_RECEIPT ' || SQLERRM;
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                    'Executing in CREATE_RECEIPT' || SQLERRM);
    END CREATE_RECEIPT;

    PROCEDURE APPLY_RECEIPT (P_RECEIPT_ID       IN     NUMBER,
                             P_TRX_NUMBER       IN     VARCHAR2,
                             P_AMOUNT_APPLIED   IN     NUMBER,
                             P_APPLY_DATE       IN     DATE,
                             P_APPLY_GL_DATE    IN     DATE,
                             P_REASON_CODE      IN     VARCHAR2,
                             P_STATUS              OUT VARCHAR2,
                             P_ERROR_MESSAGE       OUT VARCHAR2)
    IS
        l_return_status           VARCHAR2 (10);
        l_msg_count               NUMBER;
        l_msg_data                VARCHAR2 (3000);
        lc_trade_prof_name        VARCHAR2 (1000);
        lc_application_ref_type   VARCHAR2 (1000);

        CURSOR get_trade_prof_c IS
            SELECT DISTINCT orca.reason_code_id, DECODE (orca.reason_code_id, NULL, NULL, 'CLAIM')
              FROM ozf_code_conversions_all occa, ozf_reason_codes_all_tl orca
             WHERE     occa.internal_code = orca.reason_code_id
                   AND code_conversion_type = 'OZF_REASON_CODES'
                   AND external_code = P_REASON_CODE;
    BEGIN
        P_STATUS          := 'Y';
        P_ERROR_MESSAGE   := NULL;

        FND_CLIENT_INFO.set_org_context (FND_PROFILE.VALUE ('ORG_ID'));
        mo_global.init ('AR');

        OPEN get_trade_prof_c;

        FETCH get_trade_prof_c INTO lc_trade_prof_name, lc_application_ref_type;

        CLOSE get_trade_prof_c;

        DBMS_OUTPUT.put_line ('lc_trade_prof_name is ' || lc_trade_prof_name);

        AR_Receipt_API_Pub.Apply (
            p_api_version              => 1.0,
            p_init_msg_list            => FND_API.G_FALSE,
            p_commit                   => FND_API.G_FALSE,
            p_validation_level         => fnd_api.g_valid_level_full,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_cash_receipt_id          => p_receipt_id,
            --  p_trx_number                  =>  p_trx_number,
            p_customer_trx_id          => p_trx_number,
            p_amount_applied           => p_amount_applied,
            p_apply_date               => p_apply_date,        --p_Apply_Date,
            p_apply_gl_date            => p_apply_gl_date, -- Updated 16-SEP-2013 - Was l_gl_date prior (receipt gl date only) ,
            p_show_closed_invoices     => 'N', --IN VARCHAR2 DEFAULT 'N', /* Bug fix 2462013 */
            p_called_from              => 'N', --       IN VARCHAR2 DEFAULT NULL,
            --  p_move_deferred_tax           => 'Y', --  IN VARCHAR2 DEFAULT 'Y',
            p_application_ref_type     => 'CLAIM',
            p_application_ref_reason   => lc_trade_prof_name);

        IF l_return_status <> Fnd_Api.G_RET_STS_SUCCESS
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                l_msg_data   :=
                       l_msg_data
                    || 'Error '
                    || i
                    || ' is: '
                    || ' '
                    || Fnd_Msg_Pub.get (i, 'F');                 --X_MSG_DATA;
            END LOOP;

            P_STATUS          := 'E';
            P_ERROR_MESSAGE   := l_msg_data;
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'Exception while applying Receipt ' || l_msg_data);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS          := 'E';
            P_ERROR_MESSAGE   := 'Exception at APPLY_RECEIPT ' || SQLERRM;
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                    'Executing in APPLY_RECEIPT' || SQLERRM);
    END APPLY_RECEIPT;

    PROCEDURE CREATE_ADJUSTMENT (P_CUST_TRX_ID IN NUMBER, P_REC_TRX_ID IN NUMBER, P_PAY_SCHD_ID IN NUMBER, P_AMOUNT IN NUMBER, P_APPLY_DATE IN DATE, P_APPLY_GL_DATE IN DATE, P_LINE_TYPE IN VARCHAR2, P_ORG_ID IN NUMBER, P_STATUS OUT VARCHAR2
                                 , P_ERROR_MESSAGE OUT VARCHAR2)
    IS
        v_called_from         VARCHAR2 (25) := 'ADJ-API';
        v_msg_data            VARCHAR2 (1000);
        l_msg_count           NUMBER := 0;
        l_ret_status          VARCHAR2 (10) := NULL;
        l_new_adjust_number   ar_adjustments.adjustment_number%TYPE;
        l_new_adjust_id       ar_adjustments.adjustment_id%TYPE;
        v_old_adjust_id       ar_adjustments.adjustment_id%TYPE;
        v_adj_rec             ar_adjustments%ROWTYPE;
    BEGIN
        v_adj_rec.customer_trx_id       := p_cust_trx_id;
        v_adj_rec.TYPE                  := p_line_type;
        v_adj_rec.gl_date               := p_apply_gl_date;
        v_adj_rec.apply_date            := p_apply_date;
        v_adj_rec.amount                := p_amount;
        v_adj_rec.payment_schedule_id   := p_pay_schd_id;
        v_adj_rec.created_from          := 'ADJ-API';
        v_adj_rec.receivables_trx_id    := p_rec_trx_id;

        BEGIN
            P_STATUS          := 'Y';
            P_ERROR_MESSAGE   := NULL;
            ar_adjust_pub.create_adjustment (
                p_api_name              => 'AR_ADJUST_PUB',
                p_api_version           => 1.0,
                p_init_msg_list         => fnd_api.g_false,
                p_commit_flag           => fnd_api.g_false,
                p_validation_level      => fnd_api.g_valid_level_full,
                p_msg_count             => l_msg_count,
                p_msg_data              => v_msg_data,
                p_return_status         => l_ret_status,
                p_adj_rec               => v_adj_rec,
                p_chk_approval_limits   => fnd_api.g_false,
                p_check_amount          => fnd_api.g_false,
                p_move_deferred_tax     => NULL,
                p_new_adjust_number     => l_new_adjust_number,
                p_new_adjust_id         => l_new_adjust_id,
                p_called_from           => v_called_from,
                p_old_adjust_id         => v_old_adjust_id,
                p_org_id                => p_org_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'API Exception' || SQLERRM);
                P_STATUS          := 'E';
                P_ERROR_MESSAGE   := 'Exception in API CALL' || SQLERRM;
                ROLLBACK;
        END;

        IF l_ret_status = fnd_api.g_ret_sts_success
        THEN
            DBMS_OUTPUT.put_line (
                'Inside create adjustment' || l_new_adjust_id);
        ELSE
            FOR i IN 1 .. l_msg_count
            LOOP
                v_msg_data   :=
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                fnd_file.put_line (fnd_file.LOG, 'v_msg_data:' || v_msg_data);
            END LOOP;

            P_STATUS          := 'E';
            P_ERROR_MESSAGE   := v_msg_data;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS          := 'E';
            P_ERROR_MESSAGE   := 'Exception in CREATE_ADJUSTMENT' || SQLERRM;
    END CREATE_ADJUSTMENT;

    PROCEDURE CIT_DATA_FILE_ALERT (P_FROM_EMAIL IN VARCHAR2, P_TO_EMAIL IN VARCHAR2, P_FILE_NAME IN VARCHAR2)
    IS
        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;
    ----------------------------------------------------------------------
    -- End of Changes by BT Technology Team V1.6 05/DEC/2014
    ----------------------------------------------------------------------
    BEGIN
        do_debug_utils.set_level (1);

        v_def_mail_recips (1)   := p_to_email;

        do_mail_utils.send_mail_header (p_from_email, v_def_mail_recips, 'CIT Load Remittance Failure ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                        , l_ret_val);
        do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        do_mail_utils.send_mail_line ('Content-Type: text/plain', l_ret_val);
        do_mail_utils.send_mail_line ('', l_ret_val);
        do_mail_utils.send_mail_line (
               'The control and data summary totals are not matching for the AR activity file '
            || P_FILE_NAME
            || ' for the date '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY')
            || '. Data is not processed further.',
            l_ret_val);

        do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);               --Be Safe
    END CIT_DATA_FILE_ALERT;

    PROCEDURE CIT_DATA_DUP_ALERT (P_FROM_EMAIL IN VARCHAR2, P_TO_EMAIL IN VARCHAR2, P_FILE_NAME IN VARCHAR2)
    IS
        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;
    BEGIN
        do_debug_utils.set_level (1);

        v_def_mail_recips (1)   := p_to_email;

        do_mail_utils.send_mail_header (p_from_email, v_def_mail_recips, 'CIT Load Remittance Failure ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                        , l_ret_val);
        do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        do_mail_utils.send_mail_line ('Content-Type: text/plain', l_ret_val);
        do_mail_utils.send_mail_line ('', l_ret_val);
        do_mail_utils.send_mail_line (
               'The data file '
            || P_FILE_NAME
            || ' is already processed. File is not processed further.',
            l_ret_val);

        do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);               --Be Safe
    END CIT_DATA_DUP_ALERT;


    PROCEDURE CIT_REMITTANCE_REPORT (P_ERRBUF OUT VARCHAR2, P_RET_CODE OUT NUMBER, P_FROM_EMAIL IN VARCHAR2
                                     , P_TO_EMAIL IN VARCHAR2)
    IS
        v_out_line          VARCHAR2 (1000);
        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR c_remit_data IS
              SELECT TO_CHAR (TO_DATE (activity_date, 'mmddyy'), 'DD-MON-YYYY')
                         activity_date1,
                     client_customer_number,
                     customer_name,
                     item_reference,
                     check_number,
                     (SELECT meaning
                        FROM fnd_lookup_values
                       WHERE     lookup_type = 'XXDO_CIT_TRANS_CODES'
                             AND language = USERENV ('LANG')
                             AND lookup_code = xci.ar_transaction_code)
                         transaction_code,
                     (SELECT meaning
                        FROM fnd_lookup_values
                       WHERE     lookup_type = 'XXDO_CIT_ACTIVITY_CODES'
                             AND language = USERENV ('LANG')
                             AND lookup_code = xci.activity_indicator)
                         activity,
                     status,
                     error_message
                FROM xxdo_cit_inbnd_ar_act_dtl_stg xci
               WHERE TRUNC (creation_date) = TRUNC (SYSDATE)
            ORDER BY TO_DATE (activity_date, 'MMDDYY') DESC;

        TYPE t_c_remit_data_rec IS TABLE OF c_remit_data%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_remit_data_rec    t_c_remit_data_rec;
    BEGIN
        l_remit_data_rec.DELETE;

        OPEN c_remit_data;

        FETCH c_remit_data BULK COLLECT INTO l_remit_data_rec;

        CLOSE c_remit_data;

        IF l_remit_data_rec.COUNT > 0
        THEN
            do_debug_utils.set_level (1);

            v_def_mail_recips (1)   := p_to_email;
            fnd_file.put_line (fnd_file.LOG, p_to_email || p_from_email);

            do_mail_utils.send_mail_header (p_from_email, v_def_mail_recips, 'CIT Remittance Process report  ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                            , l_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                l_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                          l_ret_val);
            do_mail_utils.send_mail_line ('', l_ret_val);
            do_mail_utils.send_mail_line (
                'See attachment for report details.',
                l_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          l_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Disposition: attachment; filename="CIT Remittance Process report.xls"',
                l_ret_val);
            do_mail_utils.send_mail_line ('', l_ret_val);
            do_mail_utils.send_mail_line (
                   'Activity Date'
                || CHR (9)
                || 'Customer Number'
                || CHR (9)
                || 'Customer Name'
                || CHR (9)
                || 'Check Number'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'Transaction Code'
                || CHR (9)
                || 'Activity'
                || CHR (9)
                || 'Process Status'
                || CHR (9)
                || 'Status Message'
                || CHR (9),
                l_ret_val);
            fnd_file.put_line (
                fnd_file.output,
                   'Activity Date'
                || CHR (9)
                || 'Customer Number'
                || CHR (9)
                || 'Customer Name'
                || CHR (9)
                || 'Check Number'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'Transaction Code'
                || CHR (9)
                || 'Activity'
                || CHR (9)
                || 'Process Status'
                || CHR (9)
                || 'Status Message'
                || CHR (9));

            FOR r_remit_data IN 1 .. l_remit_data_rec.COUNT
            LOOP
                v_out_line   := NULL;
                v_out_line   :=
                       l_remit_data_rec (r_remit_data).activity_date1
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).client_customer_number
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).customer_name
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).check_number
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).item_reference
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).transaction_code
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).activity
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).status
                    || CHR (9)
                    || l_remit_data_rec (r_remit_data).error_message
                    || CHR (9);
                do_mail_utils.send_mail_line (v_out_line, l_ret_val);
                fnd_file.put_line (fnd_file.output, v_out_line);
                l_counter    := l_counter + 1;
            END LOOP;

            do_mail_utils.send_mail_close (l_ret_val);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);               --Be Safe
    END CIT_REMITTANCE_REPORT;

    PROCEDURE RECEIPT_WRITE_OFF (p_Cash_Receipt_ID   IN     NUMBER,
                                 p_Amt_Applied       IN     NUMBER,
                                 p_activity_date     IN     DATE,
                                 p_Brand             IN     VARCHAR2,
                                 x_Error_Msg            OUT VARCHAR2)
    IS
        l_Trx_ID                         NUMBER;
        l_GL_Date                        DATE;
        l_return_status                  VARCHAR2 (1);
        l_msg_count                      NUMBER;
        l_msg_data                       VARCHAR2 (240);
        l_count                          NUMBER;
        l_cash_receipt_id                NUMBER;
        l_msg_data_out                   VARCHAR2 (240);
        l_mesg                           VARCHAR2 (240);
        p_count                          NUMBER;
        l_application_ref_type           ar_receivable_applications.application_ref_type%TYPE;
        l_application_ref_id             ar_receivable_applications.application_ref_id%TYPE;
        l_application_ref_num            ar_receivable_applications.application_ref_num%TYPE;
        l_secondary_application_ref_id   ar_receivable_applications.secondary_application_ref_id%TYPE;
        l_receivable_application_id      ar_receivable_applications.receivable_application_id%TYPE;
    BEGIN
        SELECT receivables_trx_id
          INTO l_trx_id
          FROM ar_receivables_trx_all
         WHERE     status = 'A'
               AND TYPE = 'WRITEOFF'
               AND name = p_brand || '-CIT WO';

        AR_RECEIPT_API_PUB.activity_application (
            p_api_version                    => 1.0,
            p_init_msg_list                  => FND_API.G_FALSE,
            p_commit                         => FND_API.G_FALSE,
            p_validation_level               => FND_API.G_VALID_LEVEL_FULL,
            x_return_status                  => l_return_status,
            x_msg_count                      => l_msg_count,
            x_msg_data                       => l_msg_data,
            p_cash_receipt_id                => p_Cash_Receipt_ID,
            -- p_receipt_number               => p_Receipt_Number,
            p_applied_payment_schedule_id    => -3,
            p_amount_applied                 => p_Amt_Applied,
            p_receivables_trx_id             => l_Trx_ID,
            p_apply_date                     => p_activity_date,
            p_apply_gl_date                  => p_activity_date,
            p_application_ref_type           => l_application_ref_type,
            p_application_ref_id             => l_application_ref_id,
            p_application_ref_num            => l_application_ref_num,
            p_secondary_application_ref_id   => l_secondary_application_ref_id,
            p_receivable_application_id      => l_receivable_application_id);

        IF l_return_status <> Fnd_Api.G_RET_STS_SUCCESS
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                x_Error_Msg   :=
                       x_Error_Msg
                    || 'Error '
                    || i
                    || ' is: '
                    || ' '
                    || Fnd_Msg_Pub.get (i, 'F');                 --X_MSG_DATA;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_Error_Msg   :=
                   'An unexpected error occured while performing a receipt write-off.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            ROLLBACK;
    END RECEIPT_WRITE_OFF;

    PROCEDURE CREATE_MISC_RECEIPT (p_currency_code   IN     VARCHAR2,
                                   p_amount          IN     NUMBER,
                                   p_activity_date   IN     DATE,
                                   p_brand           IN     VARCHAR2,
                                   p_message            OUT VARCHAR2)
    IS
        l_return_status        VARCHAR2 (1);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (240);
        l_count                NUMBER;
        l_cash_receipt_id      NUMBER;
        l_msg_data_out         VARCHAR2 (240);
        l_mesg                 VARCHAR2 (240);
        p_count                NUMBER;
        ln_receipt_method_id   NUMBER;
        l_receipt_number       VARCHAR (100);
        v_context              VARCHAR2 (10);
        lc_activity_name       VARCHAR2 (100);
    BEGIN
        mo_global.init ('AR');

        SELECT receipt_method_id
          INTO ln_receipt_method_id
          FROM AR_RECEIPT_METHODS
         WHERE name = FND_PROFILE.VALUE ('XXDO: CIT RECEIPT METHOD');

        SELECT name
          INTO lc_activity_name
          FROM ar_receivables_trx_all
         WHERE status = 'A' AND name = p_brand || '-CIT MISC';

        SELECT 'MISCCIT' || LPAD (XXDO.XXDO_OM_CIT_REMIT_S.NEXTVAL, 7, 0)
          INTO l_receipt_number
          FROM DUAL;

        ar_receipt_api_pub.create_misc (
            p_api_version         => 1.0,
            p_init_msg_list       => fnd_api.g_false,
            p_commit              => fnd_api.g_false,
            p_validation_level    => fnd_api.g_valid_level_full,
            x_return_status       => l_return_status,
            x_msg_count           => l_msg_count,
            x_msg_data            => l_msg_data,
            p_currency_code       => p_currency_code,
            p_amount              => -1 * p_amount,
            p_receipt_date        => p_activity_date,
            p_gl_date             => p_activity_date,
            p_receipt_method_id   => ln_receipt_method_id,
            p_activity            => lc_activity_name,
            p_misc_receipt_id     => l_cash_receipt_id,
            p_receipt_number      => l_receipt_number);
        DBMS_OUTPUT.put_line (
            'Message Count is ' || l_msg_count || Fnd_Api.G_RET_STS_SUCCESS);

        IF l_return_status <> Fnd_Api.G_RET_STS_SUCCESS
        THEN
            DBMS_OUTPUT.put_line (
                'Message Count is ' || l_msg_count || Fnd_Api.G_RET_STS_SUCCESS);

            FOR i IN 1 .. l_msg_count
            LOOP
                l_msg_data   :=
                       l_msg_data
                    || 'Error '
                    || i
                    || ' is: '
                    || ' '
                    || Fnd_Msg_Pub.get (i, 'F');                 --X_MSG_DATA;
            END LOOP;

            p_message   := l_msg_data;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_message   :=
                'Exception while creating Misc receipt ' || SQLERRM;
    END CREATE_MISC_RECEIPT;

    PROCEDURE CLAIM_INVESTIGATION (p_receipt_id IN NUMBER, p_activity_date IN DATE, p_amount IN NUMBER, p_reason_code IN VARCHAR2, p_brand IN VARCHAR2, p_status OUT VARCHAR2
                                   , p_message OUT VARCHAR2)
    IS
        l_application_ref_id             VARCHAR2 (100);
        l_application_ref_num            VARCHAR2 (100);
        l_secondary_application_ref_id   VARCHAR2 (100);
        l_receivable_application_id      NUMBER;
        l_return_status                  VARCHAR2 (100);
        l_msg_count                      NUMBER;
        l_msg_data                       VARCHAR2 (100);
        l_application_ref_type           VARCHAR2 (100);
        l_trx_id                         NUMBER;
        lc_trade_prof_name               VARCHAR2 (1000);

        CURSOR get_trade_prof_c IS
            SELECT DISTINCT orca.reason_code_id
              FROM ozf_code_conversions_all occa, ozf_reason_codes_all_tl orca
             WHERE     occa.internal_code = orca.reason_code_id
                   AND code_conversion_type = 'OZF_REASON_CODES'
                   AND external_code = P_REASON_CODE;
    BEGIN
        p_status   := 'S';

        OPEN get_trade_prof_c;

        FETCH get_trade_prof_c INTO lc_trade_prof_name;

        CLOSE get_trade_prof_c;

        SELECT receivables_trx_id
          INTO l_trx_id
          FROM ar_receivables_trx_all
         WHERE     TYPE = 'CLAIM_INVESTIGATION'
               AND name = p_brand || ' US Claim Investigation';

        AR_RECEIPT_API_PUB.APPLY_OTHER_ACCOUNT (
            p_api_version                    => 1.0,
            p_init_msg_list                  => fnd_api.g_true,
            p_commit                         => fnd_api.g_false,
            p_validation_level               => fnd_api.g_valid_level_full,
            x_return_status                  => l_return_status,
            x_msg_count                      => l_msg_count,
            x_msg_data                       => l_msg_data,
            p_receivable_application_id      => l_receivable_application_id,
            p_cash_receipt_id                => p_receipt_id,
            p_amount_applied                 => p_amount --+ NVL (TO_NUMBER(rec_remit_lin.attribute5), 0)
                                                        ,
            p_receivables_trx_id             => l_trx_id,
            p_applied_payment_schedule_id    => -4,
            p_apply_date                     => p_activity_date,
            p_apply_gl_date                  => p_activity_date,
            p_application_ref_type           => 'CLAIM',
            p_application_ref_id             => l_application_ref_id,
            p_application_ref_num            => l_application_ref_num,
            p_secondary_application_ref_id   => l_secondary_application_ref_id,
            p_application_ref_reason         => lc_trade_prof_name,
            p_org_id                         => FND_PROFILE.VALUE ('ORG_ID'));

        IF l_return_status <> Fnd_Api.G_RET_STS_SUCCESS
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                l_msg_data   :=
                       l_msg_data
                    || 'Error '
                    || i
                    || ' is: '
                    || ' '
                    || Fnd_Msg_Pub.get (i, 'F');                 --X_MSG_DATA;
            END LOOP;

            DBMS_OUTPUT.PUT_LINE (
                'Exception while applying Receipt ' || l_msg_data);
            p_status    := 'E';
            p_message   := l_msg_data;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_STATUS    := 'E';
            P_MESSAGE   := 'Exception in CREATE_ADJUSTMENT' || SQLERRM;
    END CLAIM_INVESTIGATION;

    PROCEDURE APPLY_RECPT_ON_RCPT (p_receipt_id IN NUMBER, p_appl_receipt_id IN NUMBER, p_amount_applied IN NUMBER
                                   , p_activity_date IN DATE, p_status OUT VARCHAR2, p_message OUT VARCHAR2)
    IS
        l_application_ref_num         NUMBER;
        l_receivable_application_id   NUMBER;
        l_applied_rec_app_id          NUMBER;
        l_acctd_amount_applied_from   NUMBER;
        l_acctd_amount_applied_to     NUMBER;
        l_payment_schd_id             NUMBER;
        l_return_status               VARCHAR2 (1);
        l_msg_count                   NUMBER;
        l_msg_data                    VARCHAR2 (3000);
    BEGIN
        p_status   := 'S';

        BEGIN
            SELECT payment_schedule_id
              INTO l_payment_schd_id
              FROM ar_payment_schedules_all
             WHERE cash_receipt_id = p_appl_receipt_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_payment_schd_id   := 0;
        END;

        IF l_payment_schd_id <> 0
        THEN
            AR_RECEIPT_API_PUB.APPLY_OPEN_RECEIPT (
                p_api_version                   => 1.0,
                p_init_msg_list                 => FND_API.G_FALSE,
                p_commit                        => FND_API.G_FALSE,
                p_validation_level              => FND_API.G_VALID_LEVEL_FULL,
                x_return_status                 => l_return_status,
                x_msg_count                     => l_msg_count,
                x_msg_data                      => l_msg_data,
                p_cash_receipt_id               => p_receipt_id,
                p_applied_payment_schedule_id   => l_payment_schd_id,
                p_amount_applied                => -1 * p_amount_applied,
                p_apply_date                    => p_activity_date,
                p_apply_gl_date                 => p_activity_date,
                p_org_id                        =>
                    FND_PROFILE.VALUE ('ORG_ID'),
                x_application_ref_num           => l_application_ref_num,
                x_receivable_application_id     => l_receivable_application_id,
                x_applied_rec_app_id            => l_applied_rec_app_id,
                x_acctd_amount_applied_from     => l_acctd_amount_applied_from,
                x_acctd_amount_applied_to       => l_acctd_amount_applied_to);

            IF l_return_status <> Fnd_Api.G_RET_STS_SUCCESS
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    l_msg_data   :=
                           l_msg_data
                        || 'Error '
                        || i
                        || ' is: '
                        || ' '
                        || Fnd_Msg_Pub.get (i, 'F');             --X_MSG_DATA;
                END LOOP;

                p_status    := 'E';
                p_message   := l_msg_data;
            END IF;
        ELSE
            p_status    := 'E';
            p_message   := 'Receipt is not available to apply';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status   := 'E';
            p_message   :=
                'Exception while applying receipt on receipt' || SQLERRM;
    END APPLY_RECPT_ON_RCPT;

    PROCEDURE PURGE_DATA (p_errbuff                 OUT VARCHAR2,
                          p_retcode                 OUT VARCHAR2,
                          p_activity_date_low    IN     VARCHAR2,
                          p_activity_date_high   IN     VARCHAR2,
                          p_status               IN     VARCHAR2)
    IS
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_status IS ' || p_status);
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'p_activity_date_low IS ' || fnd_conc_date.string_to_date (p_activity_date_low));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'p_activity_date_high IS ' || fnd_conc_date.string_to_date (p_activity_date_high));

        DELETE FROM
            xxdo_cit_inbnd_ar_act_dtl_stg
              WHERE     status = NVL (p_status, status)
                    AND TO_DATE (activity_date, 'MMDDYY') BETWEEN fnd_conc_date.string_to_date (
                                                                      p_activity_date_low)
                                                              AND fnd_conc_date.string_to_date (
                                                                      p_activity_date_high);

        DELETE FROM xxdo_cit_inbnd_ar_act_ctl_stg xcs
              WHERE     1 = 1
                    AND NOT EXISTS
                            (SELECT 1
                               FROM xxdo_cit_inbnd_ar_act_dtl_stg
                              WHERE extract_date = xcs.extract_date);

        COMMIT;

        IF SQL%ROWCOUNT > 0
        THEN
            IF p_status IS NOT NULL
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Data of status '
                    || p_status
                    || ' is purged for the dates between '
                    || fnd_conc_date.string_to_date (p_activity_date_low)
                    || ' and '
                    || fnd_conc_date.string_to_date (p_activity_date_high));
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       'Data of status '
                    || p_status
                    || ' is purged for the dates between '
                    || fnd_conc_date.string_to_date (p_activity_date_low)
                    || ' and '
                    || fnd_conc_date.string_to_date (p_activity_date_high));
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Data of All statuses is purged for the dates between '
                    || fnd_conc_date.string_to_date (p_activity_date_low)
                    || ' and '
                    || fnd_conc_date.string_to_date (p_activity_date_high));
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       'Data of All statuses is purged for the dates between '
                    || fnd_conc_date.string_to_date (p_activity_date_low)
                    || ' and '
                    || fnd_conc_date.string_to_date (p_activity_date_high));
            END IF;
        ELSE
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'No data is available to purge for the dates between '
                || fnd_conc_date.string_to_date (p_activity_date_low)
                || ' and '
                || fnd_conc_date.string_to_date (p_activity_date_high));
            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                   'No data is available to purge for for the dates between '
                || fnd_conc_date.string_to_date (p_activity_date_low)
                || ' and '
                || fnd_conc_date.string_to_date (p_activity_date_high));
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception while purging data' || SQLERRM);
    END PURGE_DATA;
END XXDOOM_CIT_REMITPROC_PKG;
/
