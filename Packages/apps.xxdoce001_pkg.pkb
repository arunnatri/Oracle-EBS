--
-- XXDOCE001_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOCE001_PKG"
AS
    /******************************************************************************
     NAME:XXDOCE001
     Bank Loader Progarm - Deckers



     REVISIONS:
     Ver Date Author Description
     --------- ---------- --------------- ------------------------------------
     1.0 05/10/2012 Shibu 1. Created this package for XXDO.XXDOCE001_PKG
     2.0 04/22/2014 Madhav Update the package
    ******************************************************************************/
    FUNCTION get_location (p_bank IN VARCHAR2, p_loc_type IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_loc_stmt   VARCHAR2 (360);
        l_loc_arcv   VARCHAR2 (360);
        l_instance   VARCHAR2 (30);
        l_location   VARCHAR2 (360);
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Start of get location function');

        /*SELECT instance_name
        INTO l_instance
        FROM V$INSTANCE;*/
        SELECT NAME INTO l_instance FROM v$database;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Instance Name:' || l_instance);

        /*SELECT distinct meaning
          INTO l_loc
          FROM apps.fnd_lookup_values flv,
               apps.ce_bank_accounts cba,
               apps.hz_parties hp
         WHERE 1 = 1
           AND flv.description = hp.party_name
           AND flv.LANGUAGE = USERENV ('LANG')
           AND cba.bank_id = hp.party_id
           AND UPPER(hp.party_name) = UPPER(p_bank)
           AND UPPER (tag) = UPPER (p_loc_type); */
        BEGIN
            SELECT DISTINCT flv.description, flv.attribute1
              INTO l_loc_stmt, l_loc_arcv
              FROM apps.fnd_lookup_values flv, apps.ce_bank_accounts cba, apps.hz_parties hp
             WHERE     1 = 1
                   AND flv.meaning = hp.party_name
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND flv.lookup_type = 'XXDOCE_BANK_STMT_LOCATION'
                   AND NVL (flv.enabled_flag, 'X') = 'Y'
                   AND SYSDATE >= NVL (flv.start_date_active, SYSDATE)
                   AND SYSDATE < NVL (flv.end_date_active, SYSDATE) + 1
                   AND cba.bank_id = hp.party_id
                   AND UPPER (hp.party_name) = UPPER (p_bank);
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                ' Statement location Name:' || l_loc_stmt);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                ' Archive location Name:' || l_loc_arcv);

        --l_location := '$XXDO_TOP'||'/'||l_loc;
        --/f01/BTDEV/Inbound/GL/Comerica
        IF NVL (p_loc_type, 'X') = 'STMT'
        THEN
            l_location   := '/f01/' || l_instance || '/' || l_loc_stmt;
        ELSIF NVL (p_loc_type, 'X') = 'ARCV'
        THEN
            l_location   := '/f01/' || l_instance || '/' || l_loc_arcv;
        END IF;

        RETURN l_location;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_location;

    PROCEDURE archive_stmt_files (p_file_name     IN     VARCHAR2,
                                  p_source        IN     VARCHAR2,
                                  p_target        IN     VARCHAR2,
                                  x_return_msg       OUT VARCHAR2,
                                  x_return_code      OUT VARCHAR2)
    IS
        l_request_id   NUMBER;
        l_return       BOOLEAN;
        l_phase        VARCHAR2 (100);
        l_status       VARCHAR2 (100);
        l_dev_phase    VARCHAR2 (100);
        l_dev_status   VARCHAR2 (100);
        l_message      VARCHAR2 (100);
    BEGIN
        x_return_msg    := '';
        x_return_code   := '0';
        l_request_id    :=
            apps.fnd_request.submit_request (application   => 'XXDO',
                                             program       => 'XXDOCE006',
                                             description   => NULL,
                                             start_time    => SYSDATE,
                                             sub_request   => FALSE,
                                             argument1     => p_file_name,
                                             argument2     => p_source,
                                             argument3     => p_target);
        COMMIT;

        IF (l_request_id IS NOT NULL)
        THEN
            LOOP
                l_return   :=
                    apps.fnd_concurrent.wait_for_request (l_request_id,
                                                          60,
                                                          0,
                                                          l_phase,
                                                          l_status,
                                                          l_dev_phase,
                                                          l_dev_status,
                                                          l_message);
                EXIT WHEN    UPPER (l_phase) = 'COMPLETED'
                          OR UPPER (l_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            IF UPPER (l_phase) = 'COMPLETED' AND UPPER (l_status) = 'ERROR'
            THEN
                x_return_msg    :=
                    'Unable to Archive processed statment files.';
                x_return_code   := '2';
            ELSIF     UPPER (l_phase) = 'COMPLETED'
                  AND UPPER (l_status) = 'NORMAL'
            THEN
                x_return_msg    := 'Statement Files Successfully Archived.';
                x_return_code   := '0';

                UPDATE xxdo.xxdo_bank_stmt_files
                   SET process_status   = 'ARCHIVED'
                 WHERE     parent_request_id = g_conc_request_id
                       AND file_name = p_file_name
                       AND file_path = p_target;

                COMMIT;
            ELSE
                x_return_msg    := 'Review Log. ' || SQLERRM;
                x_return_code   := '1';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_msg    := 'Error in archive_stmt_files procedure.';
            x_return_code   := '2';
    END archive_stmt_files;

    PROCEDURE load_stmt_files (p_directory     IN     VARCHAR2,
                               p_bank          IN     VARCHAR2,
                               p_request_id    IN     NUMBER,
                               x_return_msg       OUT VARCHAR2,
                               x_return_code      OUT VARCHAR2)
    IS
        l_request_id   NUMBER;
        l_return       BOOLEAN;
        l_phase        VARCHAR2 (100);
        l_status       VARCHAR2 (100);
        l_dev_phase    VARCHAR2 (100);
        l_dev_status   VARCHAR2 (100);
        l_message      VARCHAR2 (100);
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'in load stmt files procedure:');
        x_return_msg    := '';
        x_return_code   := '0';
        l_request_id    :=
            apps.fnd_request.submit_request (application   => 'XXDO',
                                             program       => 'XXDOCE005',
                                             description   => NULL,
                                             start_time    => SYSDATE,
                                             sub_request   => FALSE,
                                             argument1     => p_directory,
                                             argument2     => p_bank,
                                             argument3     => p_request_id);
        COMMIT;

        IF (l_request_id IS NOT NULL)
        THEN
            LOOP
                l_return   :=
                    apps.fnd_concurrent.wait_for_request (l_request_id,
                                                          60,
                                                          0,
                                                          l_phase,
                                                          l_status,
                                                          l_dev_phase,
                                                          l_dev_status,
                                                          l_message);
                EXIT WHEN    UPPER (l_phase) = 'COMPLETED'
                          OR UPPER (l_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            IF UPPER (l_phase) = 'COMPLETED' AND UPPER (l_status) = 'ERROR'
            THEN
                x_return_msg    := 'Unable to get bank statment files.';
                x_return_code   := '2';
            ELSIF     UPPER (l_phase) = 'COMPLETED'
                  AND UPPER (l_status) = 'NORMAL'
            THEN
                x_return_msg    := 'Bank Statement Files Successfully Loaded.';
                x_return_code   := '0';
            ELSE
                x_return_msg    := 'Review Log. ' || SQLERRM;
                x_return_code   := '1';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_msg    := 'Error in load_stmt_files procedure.';
            x_return_code   := '2';
    END load_stmt_files;

    PROCEDURE statement_load1 (x_return_msg           OUT VARCHAR2,
                               x_return_code          OUT VARCHAR2,
                               pv_process_option   IN     VARCHAR2,
                               pn_bank_name        IN     VARCHAR2,
                               pd_file_date        IN     VARCHAR2,
                               pn_mapping_id       IN     NUMBER,
                               pv_filename         IN     VARCHAR2,
                               pv_filepath         IN     VARCHAR2)
    IS
        ln_req_id                NUMBER;
        lv_phase                 VARCHAR2 (50);
        lv_status                VARCHAR2 (50);
        lv_dev_phase             VARCHAR2 (50);
        lv_dev_status            VARCHAR2 (50);
        lv_message               VARCHAR2 (500);
        lv_success               BOOLEAN := FALSE;
        lv_dir_path              VARCHAR2 (500);
        lv_file_name             VARCHAR2 (500);
        ln_file_date             NUMBER;
        ln_request_id            NUMBER;
        ln_ce_req_id             NUMBER;
        lv_return                BOOLEAN := FALSE;
        lv_ret_stat              VARCHAR2 (4000);
        ftp_program_error        EXCEPTION;
        cesqlldr_program_error   EXCEPTION;
        lv_instance              VARCHAR2 (20);
        ln_loading_id            NUMBER;
        lv_file_path             VARCHAR2 (500);
        lv_ftp_username          VARCHAR2 (50);
        lv_ftp_password          VARCHAR2 (50);
        lv_ftp_date_format       VARCHAR2 (10);
        lv_ftp_protocol          VARCHAR2 (10);
        lv_ftp_server            VARCHAR2 (50);
        lv_bank_file_path        VARCHAR2 (50);
        l_return_code1           VARCHAR2 (100);
        l_return_msg1            VARCHAR2 (100);
        l_return_code2           VARCHAR2 (100);
        l_return_msg2            VARCHAR2 (100);
        l_stmt_location          VARCHAR2 (240);
        l_arcv_location          VARCHAR2 (240);
    BEGIN
        ln_request_id   :=
            apps.fnd_request.submit_request (application => 'CE', program => 'CESQLLDR', description => NULL, start_time => TO_CHAR (SYSDATE, 'DD-MON-YY'), sub_request => FALSE, argument1 => pv_process_option, -- SELECT meaning from CE_LOOKUPS where LOOKUP_TYPE = 'LDR_PROCESS_OPTION' and LOOKUP_CODE='LOAD'
                                                                                                                                                                                                                  argument2 => pn_mapping_id, -- 1002 -- Mapping template for BAI2
                                                                                                                                                                                                                                              argument3 => pv_filename, --i.FILE_NAME -- Data File Name
                                                                                                                                                                                                                                                                        argument4 => pv_filepath, -- Directory Path
                                                                                                                                                                                                                                                                                                  argument5 => '', -- Bank Branch Name
                                                                                                                                                                                                                                                                                                                   argument6 => '', -- Bank Account Number
                                                                                                                                                                                                                                                                                                                                    argument7 => pd_file_date, -- GL Date
                                                                                                                                                                                                                                                                                                                                                               argument8 => '', -- Organization
                                                                                                                                                                                                                                                                                                                                                                                argument9 => '', -- Receivables Activity
                                                                                                                                                                                                                                                                                                                                                                                                 argument10 => '', -- Payment Method
                                                                                                                                                                                                                                                                                                                                                                                                                   argument11 => '', -- NSF Handling
                                                                                                                                                                                                                                                                                                                                                                                                                                     argument12 => 'N', -- Display Debug
                                                                                                                                                                                                                                                                                                                                                                                                                                                        argument13 => ''
                                             ,                   -- Debug Path
                                               argument14 => ''  -- Debug File
                                                               );
        COMMIT;

        IF (ln_request_id IS NOT NULL)
        THEN
            LOOP
                lv_return   :=
                    apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                          10,
                                                          300,
                                                          lv_phase,
                                                          lv_status,
                                                          lv_dev_phase,
                                                          lv_dev_status,
                                                          lv_message);
                COMMIT;

                BEGIN
                        SELECT MAX (request_id)
                          INTO ln_request_id
                          FROM apps.fnd_concurrent_requests
                    START WITH request_id = ln_request_id
                    CONNECT BY PRIOR request_id = parent_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Error in parent request SQL');
                        EXIT;
                END;

                lv_return   :=
                    apps.fnd_concurrent.get_request_status (ln_request_id,
                                                            NULL,
                                                            NULL,
                                                            lv_phase,
                                                            lv_status,
                                                            lv_dev_phase,
                                                            lv_dev_status,
                                                            lv_message);

                IF (NVL (lv_dev_phase, 'ERROR') = 'COMPLETE')
                THEN
                    EXIT;
                END IF;
            END LOOP;

            IF (NVL (lv_dev_status, 'ERROR') NOT IN ('NORMAL', 'WARNING'))
            THEN
                RAISE cesqlldr_program_error;
            END IF;
        END IF;

        UPDATE xxdo.xxdo_bank_stmt_files
           SET process_status = NVL (lv_dev_phase, 'ERROR'), load_status = 'IMPORTED'
         WHERE     file_name = pv_filename                       --i.FILE_NAME
               AND bank_name = TO_CHAR (pn_bank_name)
               AND parent_request_id = g_conc_request_id;
    EXCEPTION
        WHEN ftp_program_error
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'FTP Program Terminated Abruptly');
        WHEN cesqlldr_program_error
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'CESQLLDR Program Terminated Abruptly');
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'NO_DATA_FOUND');
            x_return_msg    := 'No Data Found' || SQLCODE || SQLERRM;
            x_return_code   := -1;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'INVALID_CURSOR');
            x_return_msg    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            x_return_code   := -2;
        WHEN TOO_MANY_ROWS
        THEN
            -- DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'TOO_MANY_ROWS');
            x_return_msg    := 'Too Many Rows' || SQLCODE || SQLERRM;
            x_return_code   := -3;
        WHEN PROGRAM_ERROR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'PROGRAM_ERROR');
            x_return_msg    := 'Program Error' || SQLCODE || SQLERRM;
            x_return_code   := -4;
        WHEN OTHERS
        THEN
            -- DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS');
            x_return_msg    := 'Unhandled Error' || SQLCODE || SQLERRM;
            x_return_code   := -5;
    END statement_load1;

    -- Main Program for Bank Load - Deckers
    PROCEDURE statement_load (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_process_option IN VARCHAR2
                              , pn_bank_name IN VARCHAR2, pd_file_date IN VARCHAR2, pn_mapping_id IN NUMBER)
    IS
        CURSOR c_file (pn_bank_name IN VARCHAR2)
        IS
              SELECT *
                FROM xxdo.xxdo_bank_stmt_files
               WHERE     process_status = 'NEW'
                     AND load_status = 'NEW'
                     AND bank_name = pn_bank_name
                     AND parent_request_id = g_conc_request_id
            ORDER BY file_name;

        ln_req_id                NUMBER;
        lv_phase                 VARCHAR2 (50);
        lv_status                VARCHAR2 (50);
        lv_dev_phase             VARCHAR2 (50);
        lv_dev_status            VARCHAR2 (50);
        lv_message               VARCHAR2 (500);
        lv_success               BOOLEAN := FALSE;
        lv_dir_path              VARCHAR2 (500);
        lv_file_name             VARCHAR2 (500);
        ln_file_date             NUMBER;
        ln_request_id            NUMBER;
        ln_ce_req_id             NUMBER;
        lv_return                BOOLEAN := FALSE;
        lv_ret_stat              VARCHAR2 (4000);
        ftp_program_error        EXCEPTION;
        cesqlldr_program_error   EXCEPTION;
        lv_instance              VARCHAR2 (20);
        ln_loading_id            NUMBER;
        lv_file_path             VARCHAR2 (500);
        lv_bank_file_path        VARCHAR2 (50);
        l_return_code1           VARCHAR2 (100);
        l_return_msg1            VARCHAR2 (100);
        l_return_code2           VARCHAR2 (100);
        l_return_msg2            VARCHAR2 (100);
        l_return_code3           VARCHAR2 (100);
        l_return_msg3            VARCHAR2 (100);
        l_stmt_location          VARCHAR2 (240);
        l_arcv_location          VARCHAR2 (240);
    BEGIN
        apps.fnd_global.apps_initialize (apps.fnd_global.user_id, apps.fnd_global.resp_id, apps.fnd_global.resp_appl_id
                                         , NULL, NULL);
        apps.mo_global.set_policy_context ('S', apps.fnd_global.org_id);
        apps.cep_standard.init_security;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'pv_process_option:' || pv_process_option);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'pn_bank_name:' || pn_bank_name);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'pd_file_date:' || pd_file_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'pn_mapping_id:' || pn_mapping_id);
        l_stmt_location   := get_location (pn_bank_name, 'STMT');
        l_arcv_location   := get_location (pn_bank_name, 'ARCV');
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Statment Location : ' || l_stmt_location);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Archive Location : ' || l_arcv_location);
        --Get bank statement files
        load_stmt_files (p_directory     => l_stmt_location,
                         p_bank          => pn_bank_name,
                         p_request_id    => g_conc_request_id,
                         x_return_msg    => l_return_msg1,
                         x_return_code   => l_return_code1);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Return Msg1 : ' || l_return_msg1);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Return Code1 : ' || l_return_code1);

        IF l_return_code1 <> '0'
        THEN
            pv_errbuf    := 'No Files to be processed.';
            pv_retcode   := '2';
        ELSE
            FOR i IN c_file (pn_bank_name)
            LOOP
                l_return_code2   := '0';
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'File Name:' || i.file_name || ' Located at:' || i.file_path);
                --Load the bank statement files using the mapping
                statement_load1 (x_return_msg        => l_return_msg2,
                                 x_return_code       => l_return_code2,
                                 pv_process_option   => pv_process_option,
                                 pn_bank_name        => pn_bank_name,
                                 pd_file_date        => pd_file_date,
                                 pn_mapping_id       => pn_mapping_id,
                                 pv_filename         => i.file_name,
                                 pv_filepath         => i.file_path);

                IF l_return_code2 != '0'
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Return Msg2 : ' || l_return_msg2);
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Return Code2 : ' || l_return_code2);
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Unable to load statement file:'
                        || i.file_name
                        || ' Located at:'
                        || i.file_path);
                    pv_retcode   := '2';
                END IF;

                --IF l_return_code2 = '0' THEN
                --Archive the processed files
                archive_stmt_files (p_file_name     => i.file_name,
                                    p_source        => i.file_path,
                                    p_target        => l_arcv_location,
                                    x_return_msg    => l_return_msg3,
                                    x_return_code   => l_return_code3);

                IF l_return_code3 <> '0'
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Unable to Archive file:'
                        || i.file_name
                        || ' Located at:'
                        || i.file_path);
                    pv_retcode   := '2';
                END IF;
            END LOOP;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN ftp_program_error
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'FTP Program Terminated Abruptly');
        WHEN cesqlldr_program_error
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'CESQLLDR Program Terminated Abruptly');
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'NO_DATA_FOUND');
            pv_errbuf    := 'No Data Found' || SQLCODE || SQLERRM;
            pv_retcode   := -1;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'INVALID_CURSOR');
            pv_errbuf    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            pv_retcode   := -2;
        WHEN TOO_MANY_ROWS
        THEN
            -- DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'TOO_MANY_ROWS');
            pv_errbuf    := 'Too Many Rows' || SQLCODE || SQLERRM;
            pv_retcode   := -3;
        WHEN PROGRAM_ERROR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'PROGRAM_ERROR');
            pv_errbuf    := 'Program Error' || SQLCODE || SQLERRM;
            pv_retcode   := -4;
        WHEN OTHERS
        THEN
            -- DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS');
            pv_errbuf    := 'Unhandled Error' || SQLCODE || SQLERRM;
            pv_retcode   := -5;
    END statement_load;
END;
/
