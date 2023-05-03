--
-- XXDO_FTP_WMS_FILES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_FTP_WMS_FILES_PKG"
AS
    g_num_user_id        NUMBER := fnd_global.user_id;
    g_num_login_id       NUMBER := fnd_global.login_id;
    g_dte_current_date   DATE := SYSDATE;
    g_num_request_id     NUMBER := fnd_global.conc_request_id;
    g_num_resp_appl_id   NUMBER := fnd_global.resp_appl_id;
    g_chr_resp_appl      VARCHAR2 (100);
    g_num_resp_id        NUMBER := fnd_global.resp_id;
    g_chr_resp_name      VARCHAR2 (150);

    -- ***********************************************************************************
    -- Procedure/Function Name  :  wait_for_request
    --
    -- Description              :  The purpose of this procedure is to make the
    --                             parent request to wait untill unless child
    --                             request completes
    --
    -- parameters               :  in_num_parent_req_id  in : Parent Request Id
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2009/08/03    Infosys            12.0.1    Initial Version
    -- 2021/11/22    Showkath Ali       1.1       CCR0009689
    -- ***************************************************************************
    PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
    AS
        ------------------------------
        --Local Variable Declaration--
        ------------------------------
        ln_count                NUMBER := 0;
        ln_num_intvl            NUMBER := 5;
        ln_data_set_id          NUMBER := NULL;
        ln_num_max_wait         NUMBER := 120000;
        lv_chr_phase            VARCHAR2 (250) := NULL;
        lv_chr_status           VARCHAR2 (250) := NULL;
        lv_chr_dev_phase        VARCHAR2 (250) := NULL;
        lv_chr_dev_status       VARCHAR2 (250) := NULL;
        lv_chr_msg              VARCHAR2 (250) := NULL;
        lb_bol_request_status   BOOLEAN;

        ------------------------------------------
        --Cursor to fetch the child request id's--
        ------------------------------------------
        CURSOR cur_child_req_id IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = in_num_parent_req_id;
    ---------------
    --Begin Block--
    ---------------
    BEGIN
        ------------------------------------------------------
        --Loop for each child request to wait for completion--
        ------------------------------------------------------
        FOR rec_child_req_id IN cur_child_req_id
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (rec_child_req_id.request_id,
                                                 ln_num_intvl,
                                                 ln_num_max_wait,
                                                 lv_chr_phase, -- out parameter
                                                 lv_chr_status, -- out parameter
                                                 lv_chr_dev_phase,
                                                 -- out parameter
                                                 lv_chr_dev_status,
                                                 -- out parameter
                                                 lv_chr_msg   -- out parameter
                                                           );

            IF    UPPER (lv_chr_dev_status) = 'WARNING'
               OR UPPER (lv_chr_dev_status) = 'ERROR'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in submitting the request, request_id = '
                    || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_phase =' || lv_chr_phase);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_status =' || lv_chr_status);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error,lv_chr_dev_status =' || lv_chr_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_msg =' || lv_chr_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Request completed');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'request_id = ' || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_chr_msg =' || lv_chr_msg);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error:' || SQLERRM);
    END wait_for_request;


    -- ***********************************************************************************
    -- Procedure/Function Name  :  MAIN
    -- Maintenance History
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    --             1.0      Initial Creation
    -- 08-Jun-2022   Ramesh             1.1      CCR0009936: Do not Invoke ASN Receipt Program
    -- ***************************************************************************
    PROCEDURE main (p_out_var_errbuf OUT VARCHAR2, p_out_var_retcode OUT VARCHAR2, p_organization IN VARCHAR2
                    , p_entity IN VARCHAR2)
    IS
        l_num_request_id            NUMBER;
        l_chr_directory             VARCHAR2 (100);
        l_chr_load_program          VARCHAR2 (100);
        l_chr_process_application   VARCHAR2 (100);
        l_chr_process_program       VARCHAR2 (100);
        l_chr_transfer_flag         VARCHAR2 (100) := 'N';
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of main process');

        BEGIN
            SELECT fa.application_short_name, fl.meaning, fl.attribute3,
                   fl.attribute4, NVL (fl.attribute8, 'N')
              INTO l_chr_process_application, l_chr_process_program, l_chr_load_program, l_chr_directory,
                                            l_chr_transfer_flag
              FROM fnd_lookup_values fl, fnd_concurrent_programs fcp, fnd_application fa
             WHERE     fl.lookup_type LIKE 'XXDO_WMS_INTERFACES_SETUP'
                   AND fl.LANGUAGE = 'US'
                   AND fl.enabled_flag = 'Y'
                   AND fl.attribute1 = 'Inbound'
                   AND fa.application_id = fcp.application_id
                   AND fl.meaning = fcp.concurrent_program_name
                   AND lookup_code =
                       DECODE (p_entity,
                               'SHIP', 'XXDO_SHIP',
                               'INVSYNC', 'XXDO_INVSYNC',
                               'ASNRCPT', 'XXDO_ASNRCPT',
                               'RAREQ', 'XXDO_RAREQ',
                               'RARCPT', 'XXDO_RAREC');

            SELECT application_short_name
              INTO g_chr_resp_appl
              FROM fnd_application
             WHERE application_id = g_num_resp_appl_id;

            SELECT responsibility_name
              INTO g_chr_resp_name
              FROM fnd_responsibility_tl
             WHERE responsibility_id = g_num_resp_id AND LANGUAGE = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_chr_directory       := NULL;
                l_chr_load_program    := NULL;
                l_chr_transfer_flag   := 'N';
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Transfer flag value ' || l_chr_transfer_flag);

        IF l_chr_transfer_flag = 'Y'
        THEN
            l_num_request_id   :=
                fnd_request.submit_request ('XXDO', 'XXDOFTPFILES', NULL,
                                            NULL, FALSE, 'PULL',
                                            p_organization, p_entity, g_num_request_id, NULL, NULL, NULL
                                            , NULL);
            COMMIT;
            wait_for_request (g_num_request_id);

            IF l_chr_directory IS NOT NULL AND l_chr_load_program IS NOT NULL
            THEN
                l_num_request_id   :=
                    fnd_request.submit_request ('XXDO', 'XXDOFTPFILES', NULL,
                                                NULL, FALSE, 'PUSH',
                                                p_organization, p_entity, g_num_request_id, l_chr_load_program, l_chr_directory, g_chr_resp_appl
                                                , g_chr_resp_name);
                COMMIT;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Directory or load program definitions are missing in XXDO_WMS_INTERFACES_SETUP lookup');
                p_out_var_retcode   := '2';
            END IF;

            wait_for_request (g_num_request_id);

            IF p_entity = 'SHIP'
            THEN
                l_num_request_id   :=
                    fnd_request.submit_request (l_chr_process_application, l_chr_process_program, NULL, NULL, FALSE, NULL, 'WMS', 'EBS', 30
                                                , 1000);
            /* --Begin: Commented for CCR0009936
      ELSIF p_entity = 'ASNRCPT'
            THEN
               l_num_request_id :=
                  fnd_request.submit_request (l_chr_process_application,
                                              l_chr_process_program,
                                              NULL,
                                              NULL,
                                              FALSE,
                                              p_organization,-- 1.1 -- NULL,
                                              NULL,
                                              'WMS',
                                              'EBS',
                                              120,
                                              1000
                                             );
      */
            --End: Commented for CCR0009936
            ELSIF p_entity = 'RARCPT'
            THEN
                l_num_request_id   :=
                    fnd_request.submit_request (l_chr_process_application, l_chr_process_program, NULL, NULL, FALSE, NULL, NULL, 'WMS', 'EBS'
                                                , 30, 'N');
            ELSIF p_entity = 'RAREQ'
            THEN
                l_num_request_id   :=
                    fnd_request.submit_request (l_chr_process_application, l_chr_process_program, NULL, NULL, FALSE, NULL, NULL, 'WMS', 'EBS'
                                                , 30, 'N', 30);
            ELSIF p_entity = 'INVSYNC'
            THEN
                l_num_request_id   :=
                    fnd_request.submit_request (l_chr_process_application, l_chr_process_program, NULL
                                                , NULL, FALSE, NULL);
            END IF;

            COMMIT;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'end of main process');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected error:' || SQLERRM);
            p_out_var_errbuf    := 'Unexpected error';
            p_out_var_retcode   := '2';
    END main;
END xxdo_ftp_wms_files_pkg;
/
