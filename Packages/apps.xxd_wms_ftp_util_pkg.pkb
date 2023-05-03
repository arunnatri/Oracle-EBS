--
-- XXD_WMS_FTP_UTIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_FTP_UTIL_PKG"
AS
    /****************************************************************************************
    * Change#      : CCR0007775
    * Package      : xxd_wms_ftp_util_pkg
    * Description  : This package is used to transfer files from HJ Server to EBS
    *                and load the XML file data into respective staging tables
    * Notes        : File transfer and load into respective staging tables
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 26-Sep-2019  1.0         Kranthi Bollam          Initial Version
    -- 05-Mar-2019  1.1         Tejaswi Gangumalla      Updated for CCR CCR0008227
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/

    ----------------------
    -- Global Variables --
    ----------------------
    -- Return code (0 for success, 1 for failure)
    gv_package_name   VARCHAR2 (30) := 'XXD_WMS_FTP_UTIL_PKG';

    -- ***************************************************************************
    -- Procedure Name      : file_pull_push
    -- Description         : This procedure is used to pull the files from HJ to EBS folders and extract the data in the file into the staging tables
    -- Parameters          : pv_errbuf       OUT : Error Message
    --                       pv_retcode      OUT : Execution Status
    --                       pv_organization IN  : Inv Organization
    --                       pv_entity       IN  : Entity (Ex: SHIP)
    --
    -- Return/Exit         :  None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 26-Sep-2019   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE file_pull_push (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_organization IN VARCHAR2
                              , pv_entity IN VARCHAR2)
    IS
        ln_request_id            NUMBER;
        lv_directory             VARCHAR2 (100) := 'XXDO_ONT_SHIP_CONF_FILE_DIR'; --Ship Conf File Directory
        lv_load_program          VARCHAR2 (100) := 'XXD_HJ_EBS_SC_LOAD_XML_DATA'; --Ship Confirm Extraction and Loader Program
        lv_process_application   VARCHAR2 (100);
        lv_process_program       VARCHAR2 (100);
        lv_transfer_flag         VARCHAR2 (100) := 'N';
        lv_resp_appl             VARCHAR2 (100);
        lv_resp_name             VARCHAR2 (150);
        ln_file_error_count      NUMBER := 0;
        lv_errbuf                VARCHAR2 (4000) := NULL;
        lv_retcode               VARCHAR2 (30) := NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of File Pull and Push process. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        BEGIN
            SELECT fa.application_short_name, fl.meaning, fl.attribute3,
                   fl.attribute4, NVL (fl.attribute8, 'N')
              INTO lv_process_application, lv_process_program, lv_load_program, lv_directory,
                                         lv_transfer_flag
              FROM fnd_lookup_values fl, fnd_concurrent_programs fcp, fnd_application fa
             WHERE     fl.lookup_type LIKE 'XXDO_WMS_INTERFACES_SETUP'
                   AND fl.LANGUAGE = 'US'
                   AND fl.enabled_flag = 'Y'
                   AND fl.attribute1 = 'Inbound'
                   AND fa.application_id = fcp.application_id
                   AND fl.meaning = fcp.concurrent_program_name
                   AND lookup_code = DECODE (pv_entity, 'SHIP', 'XXDO_SHIP');

            SELECT application_short_name
              INTO lv_resp_appl
              FROM fnd_application
             WHERE application_id = gn_resp_appl_id;

            SELECT responsibility_name
              INTO lv_resp_name
              FROM fnd_responsibility_tl
             WHERE responsibility_id = gn_resp_id AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory       := NULL;
                lv_load_program    := NULL;
                lv_transfer_flag   := 'N';
        END;

        --Submit this program which loads the XML file into the staging table and also extracts the XML data and loads into the staging tables
        --Override the program which we get from the above query
        IF pv_entity = 'SHIP'
        THEN
            lv_load_program   := 'XXD_HJ_EBS_SC_LOAD_XML_DATA';

            IF lv_directory IS NULL
            THEN
                lv_directory   := 'XXDO_ONT_SHIP_CONF_FILE_DIR';
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Transfer flag value ' || lv_transfer_flag);

        IF lv_transfer_flag = 'Y'
        THEN
            --Submit "Deckers FTP WMS Files" program with parameter as PULL.
            --It pulls the shipment files from Highkump and places in EBS FTP Directory
            ln_request_id   :=
                fnd_request.submit_request (application => 'XXDO', program => 'XXDOFTPFILES', description => NULL, start_time => NULL, sub_request => FALSE, argument1 => 'PULL', --Mode
                                                                                                                                                                                  argument2 => pv_organization, --Warehouse
                                                                                                                                                                                                                argument3 => pv_entity, --Entity
                                                                                                                                                                                                                                        argument4 => gn_request_id, --Parent Request ID
                                                                                                                                                                                                                                                                    argument5 => NULL, --Load Program
                                                                                                                                                                                                                                                                                       argument6 => NULL, --Load Directory
                                                                                                                                                                                                                                                                                                          argument7 => NULL
                                            ,     --Responsibility Application
                                              argument8 => NULL --Responsibility Name
                                                               );
            COMMIT;
            --Wait for the request to complete
            wait_for_request (ln_request_id);

            IF (lv_directory IS NOT NULL AND lv_load_program IS NOT NULL)
            THEN
                --Reset Request ID
                ln_request_id   := 0;
                --Submit "Deckers FTP WMS Files" program with parameter as PUSH.
                --It pushes the shipment file in EBS FTP Directory to XML staging table
                --And also kicks off the program(Deckers HJ to EBS Ship Confirm - Load XML data) which parses the XML file data
                --and inserts into the shipment staging tables
                ln_request_id   :=
                    fnd_request.submit_request (application => 'XXDO', program => 'XXDOFTPFILES', description => NULL, start_time => NULL, sub_request => FALSE, argument1 => 'PUSH', --Mode
                                                                                                                                                                                      argument2 => pv_organization, --Warehouse
                                                                                                                                                                                                                    argument3 => pv_entity, --Entity
                                                                                                                                                                                                                                            argument4 => gn_request_id, --Parent Request ID
                                                                                                                                                                                                                                                                        argument5 => lv_load_program, --Load Program
                                                                                                                                                                                                                                                                                                      argument6 => lv_directory, --Load Directory
                                                                                                                                                                                                                                                                                                                                 argument7 => lv_resp_appl
                                                , --Responsibility Application
                                                  argument8 => lv_resp_name --Responsibility Name
                                                                           );
                COMMIT;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Directory or load program definitions are missing in XXDO_WMS_INTERFACES_SETUP lookup for Ship Confirm Interface');
                pv_retcode   := '2';
            END IF;

            --Wait for the request to complete
            wait_for_request (ln_request_id);
        END IF;

        --Check if there are any files that uploaded to the staging table with File already exists ERROR
        SELECT COUNT (1)
          INTO ln_file_error_count
          FROM xxdo_ont_ship_conf_xml_stg
         WHERE     1 = 1
               AND SUBSTR (file_name,
                             INSTR (file_name, '.', 1,
                                    2)
                           + 1) = gn_request_id            --Parent Request ID
               AND process_status = 'ERROR';

        IF ln_file_error_count > 0
        THEN
            send_notification (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pv_notification_type => 'FILE_ERROR'
                               , pn_request_id => gn_request_id);

            IF lv_retcode <> '0'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in sending notification for FILE_ERROR. Error is: '
                    || lv_errbuf);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Email notification sent successfully for FILE_ERROR.');
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'End of File Pull and Push process');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected error:' || SQLERRM);
            pv_errbuf    := 'Unexpected error';
            pv_retcode   := '2';
    END file_pull_push;

    -- ***************************************************************************
    -- Procedure Name      : send_notification
    -- Description         : This procedure is used to send notification based on the notification type
    -- Parameters          : pv_errbuf               OUT : Error Message
    --                       pv_retcode              OUT : Execution Status
    --                       pv_notification_type    IN  : Notification Type
    --                       pn_request_id           IN  : Request ID
    --
    -- Return/Exit         :  None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 26-Sep-2019   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE send_notification (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_notification_type IN VARCHAR2
                                 , pn_request_id IN NUMBER)
    IS
        --Local Variables
        lv_proc_name              VARCHAR2 (30) := 'SEND_NOTIFICATION';
        lv_inst_name              VARCHAR2 (20) := NULL;
        ln_ret_val                NUMBER := 0;
        lv_err_msg                VARCHAR2 (4000) := NULL;
        ln_file_err_cnt           NUMBER := 0;
        lv_email_body             VARCHAR2 (4000) := NULL;
        lv_out_line               VARCHAR2 (4000) := NULL;
        l_ex_instance_not_known   EXCEPTION;
        l_ex_no_recips            EXCEPTION;
        lv_def_mail_recips        do_mail_utils.tbl_recips;

        --Error files Cursor
        CURSOR file_error_cur IS
            SELECT process_status, message_id, shipment_num,
                   file_name, error_message, request_id,
                   creation_date
              FROM xxdo_ont_ship_conf_xml_stg
             WHERE     1 = 1
                   AND SUBSTR (file_name,
                                 INSTR (file_name, '.', 1,
                                        2)
                               + 1) = pn_request_id        --Parent Request ID
                   AND process_status = 'ERROR';
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'In Send Notification Procedure - START');

        -- Get the instance name - it will be shown in the report
        BEGIN
            SELECT DECODE (name, 'EBSPROD', 'PRODUCTION', 'TEST(' || name || ')') instance_name
              INTO lv_inst_name
              FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_ex_instance_not_known;
        END;

        IF pv_notification_type = 'FILE_ERROR'
        THEN
            SELECT COUNT (1)
              INTO ln_file_err_cnt
              FROM xxdo_ont_ship_conf_xml_stg
             WHERE     1 = 1
                   AND SUBSTR (file_name,
                                 INSTR (file_name, '.', 1,
                                        2)
                               + 1) = pn_request_id        --Parent Request ID
                   AND process_status = 'ERROR';

            --Now get the email recipients list
            lv_def_mail_recips   := get_email_ids ('XXD_HJ_EBS_SHIP_CONF_DL');

            IF lv_def_mail_recips.COUNT < 1
            THEN
                RAISE l_ex_no_recips;
            END IF;

            --Email statements start
            do_mail_utils.send_mail_header (p_msg_from => fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), p_msg_to => lv_def_mail_recips, p_msg_subject => 'Ship Confirm Interface Error Files Notification.' || ' Email generated from ' || lv_inst_name || ' instance'
                                            , status => ln_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            lv_email_body        :=
                   'Hi All,'
                || CHR (10)
                || CHR (10)
                || 'Please find attached the Ship Confirm Interface Error files.'
                || CHR (10)
                || CHR (10)
                || 'Number of files in error   :'
                || ln_file_err_cnt
                || CHR (10)
                || CHR (10)
                || 'Regards'
                || CHR (10)
                || 'Warehouse Support Team';
            do_mail_utils.send_mail_line (lv_email_body, ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_Ship_Confirm_Duplicate_Files_'
                || TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS')
                || '.xls"',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                   'File Name'
                || CHR (9)
                || 'Message ID'
                || CHR (9)
                || 'Shipment Number'
                || CHR (9)
                || 'Status'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Process Date'
                || CHR (9),
                ln_ret_val);

            FOR file_error_rec IN file_error_cur
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       file_error_rec.file_name
                    || CHR (9)
                    || file_error_rec.message_id
                    || CHR (9)
                    || file_error_rec.shipment_num
                    || CHR (9)
                    || file_error_rec.process_status
                    || CHR (9)
                    || file_error_rec.error_message
                    || CHR (9)
                    || file_error_rec.creation_date
                    || CHR (9);
                do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
            END LOOP;

            do_mail_utils.send_mail_close (ln_ret_val);
        END IF;                                  --pv_notification_type end if

        fnd_file.put_line (fnd_file.LOG,
                           'In Send Notification Procedure - END');
    EXCEPTION
        WHEN l_ex_no_recips
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            lv_err_msg   :=
                SUBSTR (
                       'In When ex_no_recips exception in Package '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' . No Recipient email IDs',
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            pv_errbuf    := lv_err_msg;
            pv_retcode   := '2';
        WHEN l_ex_instance_not_known
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            pv_errbuf    := 'Unable to derive instance name';
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            pv_errbuf    :=
                   'When Others Exception in '
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'When Others Exception in '
                || lv_proc_name
                || ' procedure for notification type: '
                || pv_notification_type);
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END send_notification;

    -- ***********************************************************************************
    -- Procedure/Function Name  : wait_for_request
    -- Description              : The purpose of this procedure is to make the
    --                            parent request to wait until child request completes
    --
    -- parameters               : pn_parent_req_id  in : Parent Request Id
    --
    -- Return/Exit              : N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 26-Sep-2019   Kranthi Bollam        1.0      Initial Version.
    -- ***************************************************************************
    PROCEDURE wait_for_request (pn_req_id IN NUMBER)
    AS
        --Local Variables Declaration
        lv_proc_name            VARCHAR2 (30) := 'WAIT_FOR_REQUEST';
        ln_count                NUMBER := 0;
        ln_interval             NUMBER := 5;
        ln_data_set_id          NUMBER := NULL;
        ln_max_wait             NUMBER := 0;                         --120000;
        lv_phase                VARCHAR2 (250) := NULL;
        lv_status               VARCHAR2 (250) := NULL;
        lv_dev_phase            VARCHAR2 (250) := NULL;
        lv_dev_status           VARCHAR2 (250) := NULL;
        lv_msg                  VARCHAR2 (250) := NULL;
        lb_bol_request_status   BOOLEAN;

        --Cursor to fetch the child request id's--
        CURSOR cur_child_req_id IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE request_id = pn_req_id;
    BEGIN
        --Loop for each child request to wait for completion--
        FOR rec_child_req_id IN cur_child_req_id
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (rec_child_req_id.request_id, ln_interval, ln_max_wait, lv_phase, -- out parameter
                                                                                                                  lv_status, -- out parameter
                                                                                                                             lv_dev_phase
                                                 ,            -- out parameter
                                                   lv_dev_status, -- out parameter
                                                                  lv_msg -- out parameter
                                                                        );

            IF (UPPER (lv_dev_status) = 'WARNING' OR UPPER (lv_dev_status) = 'ERROR')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in submitting the request, request_id = '
                    || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_phase =' || lv_phase);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_status =' || lv_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_dev_status =' || lv_dev_status);
                fnd_file.put_line (fnd_file.LOG, 'Error,lv_msg =' || lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Request completed');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'request_id = ' || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG, 'lv_msg =' || lv_msg);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'When Others Exception in '
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END wait_for_request;

    -- ***************************************************************************
    -- Function Name      : get_email_ids
    -- Description        : This function is used to get list of email recipents for the lookup provided in the parameter
    -- Parameters         : pv_errbuf       OUT : Error Message
    --                      pv_retcode      OUT : Execution Status
    --                      pv_lookup_type  IN  : Lookup Type name
    --
    -- Return/Exit         :  List of email id's in a table type
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 26-Sep-2019   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION get_email_ids (pv_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT flv.description email_id
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = pv_lookup_type
                   AND flv.lookup_code LIKE 'EMAIL_ID%'
                   AND flv.enabled_flag = 'Y'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1);
    BEGIN
        lv_def_mail_recips.DELETE;

        FOR recips_rec IN recips_cur
        LOOP
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                recips_rec.email_id;
        END LOOP;

        IF lv_def_mail_recips.COUNT < 1
        THEN
            lv_def_mail_recips (1)   := 'MVDCApplicationSupport@deckers.com';
            lv_def_mail_recips (2)   := 'gcc-ebs-scm@deckers.com';
        END IF;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (1)   := 'MVDCApplicationSupport@deckers.com';
            lv_def_mail_recips (2)   := 'gcc-ebs-scm@deckers.com';
            RETURN lv_def_mail_recips;
    END get_email_ids;

    -- ***************************************************************************
    -- Procedure/Function Name  :  sc_upload_xml
    --
    -- Description              :  The purpose of this procedure is to load the xml file into the database
    --
    -- parameters               :  pv_errbuf OUT : Error message
    --                                   pv_retcode OUT : Execution status
    --                                   pv_inbound_directory IN : Input file directory
    --                                  pv_file_name IN : Input Xml file name
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Kranthi Bollam     1.0      Initial Version
    -- ***************************************************************************
    PROCEDURE sc_upload_xml (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_inbound_directory VARCHAR2
                             , pv_file_name VARCHAR2)
    AS
        l_bfi_file_location   BFILE;
        l_num_amount          INTEGER := DBMS_LOB.lobmaxsize;
        l_clo_xml_doc         CLOB;
        l_num_warning         NUMBER;
        l_num_lang_ctx        NUMBER := DBMS_LOB.default_lang_ctx;
        l_num_src_off         NUMBER := 1;
        l_num_dest_off        NUMBER := 1;
        l_xml_doc             XMLTYPE;
        lv_errbuf             VARCHAR2 (2000);
        lv_retcode            VARCHAR2 (30);
        ln_message_id         NUMBER := NULL;
        lv_shipment_num       VARCHAR2 (30) := NULL;
        ln_file_cnt           NUMBER := 0;
        lv_file_ins_success   VARCHAR2 (1) := 'N';
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Directory Name: ' || pv_inbound_directory);
        fnd_file.put_line (fnd_file.LOG, 'File Name: ' || pv_file_name);
        -- Reading the OS Location for XML Files
        l_bfi_file_location   :=
            BFILENAME (pv_inbound_directory, pv_file_name);
        DBMS_LOB.createtemporary (l_clo_xml_doc, FALSE);
        DBMS_LOB.OPEN (l_bfi_file_location, DBMS_LOB.lob_readonly);
        fnd_file.put_line (fnd_file.LOG, 'Loading the file into CLOB');
        DBMS_LOB.loadclobfromfile (l_clo_xml_doc, l_bfi_file_location, l_num_amount, l_num_src_off, l_num_dest_off, DBMS_LOB.default_csid
                                   , l_num_lang_ctx, l_num_warning);
        DBMS_LOB.CLOSE (l_bfi_file_location);
        fnd_file.put_line (fnd_file.LOG, 'converting the data into XML type');
        l_xml_doc   := XMLTYPE (l_clo_xml_doc);
        DBMS_LOB.freetemporary (l_clo_xml_doc);

        --Check if file exists in the XML staging table with the same name
        SELECT COUNT (1)
          INTO ln_file_cnt
          FROM xxdo_ont_ship_conf_xml_stg
         WHERE     1 = 1
               AND SUBSTR (file_name, 1, INSTR (file_name, '.') + 3) =
                   SUBSTR (pv_file_name, 1, INSTR (pv_file_name, '.') + 3);

        IF ln_file_cnt > 0
        THEN
            BEGIN
                -- Insert statement to upload the XML files
                INSERT INTO xxdo_ont_ship_conf_xml_stg (process_status,
                                                        error_message,
                                                        xml_document,
                                                        file_name,
                                                        request_id,
                                                        created_by,
                                                        creation_date,
                                                        last_updated_by,
                                                        last_update_date)
                     VALUES ('ERROR', 'File Already Exists', l_xml_doc,
                             pv_file_name, fnd_global.conc_request_id, fnd_global.user_id
                             , SYSDATE, fnd_global.user_id, SYSDATE);

                lv_file_ins_success   := 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_file_ins_success   := 'N';
                    pv_errbuf             :=
                        SUBSTR (
                               'Error while Inserting XML file into XML Staging table with ERROR status. Error is: '
                            || SQLERRM,
                            2000);
                    pv_retcode            := '2';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            COMMIT;
        ELSE
            BEGIN
                -- Insert statement to upload the XML files
                INSERT INTO xxdo_ont_ship_conf_xml_stg (process_status,
                                                        xml_document,
                                                        file_name,
                                                        request_id,
                                                        created_by,
                                                        creation_date,
                                                        last_updated_by,
                                                        last_update_date)
                     VALUES ('NEW', l_xml_doc, pv_file_name,
                             fnd_global.conc_request_id, fnd_global.user_id, SYSDATE
                             , fnd_global.user_id, SYSDATE);

                lv_file_ins_success   := 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_file_ins_success   := 'N';
                    pv_errbuf             :=
                        SUBSTR (
                               'Error while Inserting XML file into XML Staging table. Error is: '
                            || SQLERRM,
                            1,
                            2000);
                    pv_retcode            := '2';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            COMMIT;
        END IF;                                           --ln_file_cnt end if

        IF lv_file_ins_success = 'Y'
        THEN
            --Get Message_id
            BEGIN
                     SELECT xml_ext.message_id
                       INTO ln_message_id
                       FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                            (XMLTABLE (XMLNAMESPACES (DEFAULT 'http://www.example.org'), '/OutboundShipmentsMessage/MessageHeader' PASSING xml_tab.xml_document
                                       COLUMNS message_id NUMBER PATH 'MessageID'))
                            xml_ext
                      WHERE     1 = 1
                            AND file_name = pv_file_name
                            AND request_id = fnd_global.conc_request_id
                            AND xml_tab.ROWID =
                                (SELECT MAX (ROWID) row_id
                                   FROM xxdo_ont_ship_conf_xml_stg xml_tab
                                  WHERE     1 = 1
                                        AND file_name = pv_file_name
                                        AND request_id =
                                            fnd_global.conc_request_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error in getting message id for file:'
                        || pv_file_name);
                    ln_message_id   := NULL;
            END;

            --Get Shipment number
            BEGIN
                            SELECT xml_ext.shipment_number
                              INTO lv_shipment_num
                              FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                   (XMLTABLE (
                                        XMLNAMESPACES (DEFAULT 'http://www.example.org'),
                                        '/OutboundShipmentsMessage/Shipments/Shipment'
                                        PASSING xml_tab.xml_document
                                        COLUMNS shipment_number    VARCHAR2 (20) PATH 'shipment_number'))
                                   xml_ext
                             WHERE     1 = 1
                                   AND file_name = pv_file_name
                                   AND request_id =
                                       fnd_global.conc_request_id
                                   AND xml_tab.ROWID =
                                       (SELECT MAX (ROWID) row_id
                                          FROM xxdo_ont_ship_conf_xml_stg xml_tab
                                         WHERE     1 = 1
                                               AND file_name = pv_file_name
                                               AND request_id =
                                                   fnd_global.conc_request_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error in getting shipment number for file:'
                        || pv_file_name);
                    lv_shipment_num   := NULL;
            END;

            IF ln_message_id IS NOT NULL AND lv_shipment_num IS NOT NULL
            THEN
                --Update Message_id and Shipment_num columns in the XML staging table
                BEGIN
                    UPDATE xxdo_ont_ship_conf_xml_stg xml_tab
                       SET message_id = ln_message_id, shipment_num = lv_shipment_num
                     WHERE     1 = 1
                           AND file_name = pv_file_name
                           AND request_id = fnd_global.conc_request_id
                           AND xml_tab.ROWID =
                               (SELECT MAX (ROWID) row_id
                                  FROM xxdo_ont_ship_conf_xml_stg xml_tab
                                 WHERE     1 = 1
                                       AND file_name = pv_file_name
                                       AND request_id =
                                           fnd_global.conc_request_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in getting message id and shipment number for file:'
                            || pv_file_name);
                END;

                COMMIT;
            END IF;

            IF ln_file_cnt <= 0
            THEN
                --Now call the sc_extract_xml_data procedure to extract the XML_FILE in XML_DOCUMENT column into
                --the shipment staging tables
                BEGIN
                    sc_extract_xml_data (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pn_bulk_limit => 1000
                                         , pv_file_name => pv_file_name);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'XML data is not loaded into database due to :'
                            || SQLERRM);
                        pv_retcode   := '2';
                        pv_errbuf    := SQLERRM;
                END;

                IF lv_retcode <> '0'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'XML data is not loaded into database due to :'
                        || lv_errbuf);
                    pv_retcode   := '2';
                    pv_errbuf    := lv_errbuf;
                ELSE
                    fnd_file.put_line (fnd_file.LOG,
                                       'XML data is loaded into database');
                    pv_retcode   := '0';
                    pv_errbuf    := NULL;
                END IF;
            END IF;                                  --ln_file_cnt <= 0 end if
        END IF;                             --lv_file_ins_success = 'Y' end if
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error while loading the XML into database : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while loading the XML into database.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END sc_upload_xml;

    -- ***************************************************************************
    -- Procedure/Function Name  :  sc_extract_xml_data
    -- Description              :  The purpose of this procedure is to parse the xml file and load the data into staging tables
    -- parameters               :  pv_errbuf OUT : Error message
    --                                   pv_retcode OUT : Execution status
    --                                  pn_bulk_limit IN : Bulk Limit
    -- Return/Exit              :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/05/01    Kranthi Bollam     1.0      Initial Version
    -- ***************************************************************************

    PROCEDURE sc_extract_xml_data (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, --                               pv_shipment_no    IN VARCHAR2,
                                                                                    pn_bulk_limit IN NUMBER
                                   , pv_file_name IN VARCHAR2)
    IS
        ln_request_id              NUMBER := fnd_global.conc_request_id;
        ln_user_id                 NUMBER := fnd_global.user_id;

        CURSOR cur_xml_file_counts IS
            SELECT ROWID row_id, file_name
              FROM xxdo_ont_ship_conf_xml_stg
             WHERE process_status = 'NEW' AND file_name = pv_file_name;

        CURSOR cur_shipment_headers IS
                         SELECT wh_id, shipment_number, master_load_ref,
                                customer_load_id, carrier, service_level,
                                pro_number, comments, TO_DATE (ship_date, 'YYYY-MM-DD HH24:MI:SS'),
                                seal_number, trailer_number, employee_id,
                                employee_name, 'NEW' process_status, NULL error_message,
                                ln_request_id request_id, SYSDATE creation_date, ln_user_id created_by,
                                SYSDATE last_update_date, ln_user_id last_updated_by, 'ORDER' source_type,
                                NULL attribute1, NULL attribute2, NULL attribute3,
                                NULL attribute4, NULL attribute5, NULL attribute6,
                                NULL attribute7, NULL attribute8, NULL attribute9,
                                NULL attribute10, NULL attribute11, NULL attribute12,
                                NULL attribute13, NULL attribute14, NULL attribute15,
                                NULL attribute16, NULL attribute17, NULL attribute18,
                                NULL attribute19, NULL attribute20, 'WMS' SOURCE,
                                'EBS' destination, 'INSERT' record_type, bol_number,
                                shipment_type,       /* Added for change 1.1*/
                                               sales_channel /* Added for change 1.1*/
                           FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                XMLTABLE (
                                    XMLNAMESPACES (DEFAULT 'http://www.example.org'),
                                    'OutboundShipmentsMessage/Shipments/Shipment'
                                    PASSING xml_tab.xml_document
                                    COLUMNS Wh_Id               VARCHAR2 (2000) PATH 'wh_id', Shipment_Number     VARCHAR2 (2000) PATH 'shipment_number', Master_Load_Ref     VARCHAR2 (2000) PATH 'master_load_ref',
                                            Customer_Load_Id    VARCHAR2 (2000) PATH 'customer_load_id', Carrier             VARCHAR2 (2000) PATH 'carrier', Service_Level       VARCHAR2 (2000) PATH 'service_level',
                                            Pro_Number          VARCHAR2 (2000) PATH 'pro_number', Comments            VARCHAR2 (2000) PATH 'comments', Ship_Date           VARCHAR2 (2000) PATH 'ship_date',
                                            Seal_Number         VARCHAR2 (2000) PATH 'seal_number', Trailer_Number      VARCHAR2 (2000) PATH 'trailer_number', Bol_Number          VARCHAR2 (2000) PATH 'bol_number', /* Added for CCR0006947 */
                                            Employee_Id         VARCHAR2 (2000) PATH 'employee_id', Employee_Name       VARCHAR2 (2000) PATH 'employee_name', Shipment_Type       VARCHAR2 (2000) PATH 'shipment_type', /* Added for change 1.1*/
                                            Sales_Channel       VARCHAR2 (2000) PATH 'sales_channel' /* Added for change 1.1*/
                                                                                                    )
                          WHERE     process_status = 'NEW'
                                AND file_name = pv_file_name;

        TYPE shipconf_headers_tab_type
            IS TABLE OF xxdo_ont_ship_conf_head_stg%ROWTYPE;

        l_shipconf_headers_tab     shipconf_headers_tab_type;

        CURSOR cur_deliveries IS
                             SELECT wh_id, shipment_number, order_number,
                                    ship_to_name, ship_to_attention, ship_to_addr1,
                                    ship_to_addr2, ship_to_addr3, ship_to_city,
                                    ship_to_state, ship_to_zip, ship_to_country_code,
                                    'NEW' process_status, NULL error_message, ln_request_id request_id,
                                    SYSDATE creation_date, ln_user_id created_by, SYSDATE last_update_date,
                                    ln_user_id last_updated_by, 'ORDER' source_type, NULL attribute1,
                                    NULL attribute2, NULL attribute3, NULL attribute4,
                                    NULL attribute5, NULL attribute6, NULL attribute7,
                                    NULL attribute8, NULL attribute9, NULL attribute10,
                                    NULL attribute11, NULL attribute12, NULL attribute13,
                                    NULL attribute14, NULL attribute15, NULL attribute16,
                                    NULL attribute17, NULL attribute18, NULL attribute19,
                                    NULL attribute20, 'WMS' SOURCE, 'EBS' destination,
                                    'INSERT' record_type, 'NOT VERIFIED' address_verified, NULL order_header_id,
                                    NULL delivery_id, NULL ship_to_org_id, NULL ship_to_location_id,
                                    NULL edi_eligible, /* Added for change 1.1*/
                                                       NULL edi_creation_status /* Added for change 1.1*/
                               FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                    XMLTABLE (
                                        XMLNAMESPACES (DEFAULT 'http://www.example.org'),
                                        'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder'
                                        PASSING xml_tab.xml_document
                                        COLUMNS Wh_Id                   VARCHAR2 (2000) PATH 'wh_id', Shipment_Number         VARCHAR2 (2000) PATH 'shipment_number', Order_Number            VARCHAR2 (2000) PATH 'order_number',
                                                Ship_To_Name            VARCHAR2 (2000) PATH 'ship_to_name', Ship_To_Attention       VARCHAR2 (2000) PATH 'ship_to_attention', Ship_To_Addr1           VARCHAR2 (2000) PATH 'ship_to_addr1',
                                                Ship_To_Addr2           VARCHAR2 (2000) PATH 'ship_to_addr2', Ship_To_Addr3           VARCHAR2 (2000) PATH 'ship_to_addr3', Ship_To_City            VARCHAR2 (2000) PATH 'ship_to_city',
                                                Ship_To_State           VARCHAR2 (2000) PATH 'ship_to_state', Ship_To_Zip             VARCHAR2 (2000) PATH 'ship_to_zip', Ship_To_Country_Code    VARCHAR2 (2000) PATH 'ship_to_country_code')
                              WHERE     process_status = 'NEW'
                                    AND file_name = pv_file_name;

        TYPE shipconf_orders_tab_type
            IS TABLE OF xxdo_ont_ship_conf_order_stg%ROWTYPE;

        l_shipconf_orders_tab      shipconf_orders_tab_type;

        CURSOR cur_cartons IS
                        SELECT wh_id, shipment_number, order_number,
                               carton_number, tracking_number, freight_list,
                               freight_actual, weight, LENGTH,
                               width, height, 'NEW' process_status,
                               NULL error_message, ln_request_id request_id, SYSDATE creation_date,
                               ln_user_id created_by, SYSDATE last_update_date, ln_user_id last_updated_by,
                               'ORDER' source_type, NULL attribute1, NULL attribute2,
                               NULL attribute3, NULL attribute4, NULL attribute5,
                               NULL attribute6, NULL attribute7, NULL attribute8,
                               NULL attribute9, NULL attribute10, NULL attribute11,
                               NULL attribute12, NULL attribute13, NULL attribute14,
                               NULL attribute15, NULL attribute16, NULL attribute17,
                               NULL attribute18, NULL attribute19, NULL attribute20,
                               'WMS' SOURCE, 'EBS' destination, 'INSERT' record_type,
                               freight_charged           /* FREIGHT_CHARGED */
                          FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                               XMLTABLE (
                                   XMLNAMESPACES (DEFAULT 'http://www.example.org'),
                                   'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder/OutboundOrderCartons/OutboundOrderCarton'
                                   PASSING xml_tab.xml_document
                                   COLUMNS Wh_Id              VARCHAR2 (2000) PATH 'wh_id', Shipment_Number    VARCHAR2 (2000) PATH 'shipment_number', Order_Number       VARCHAR2 (2000) PATH 'order_number',
                                           Carton_Number      VARCHAR2 (2000) PATH 'carton_number', Tracking_Number    VARCHAR2 (2000) PATH 'tracking_number', Freight_List       VARCHAR2 (2000) PATH 'freight_list',
                                           Freight_Actual     VARCHAR2 (2000) PATH 'freight_actual', Freight_Charged    VARCHAR2 (2000) PATH 'freight_charged', /* FREIGHT_CHARGED */
                                                                                                                                                                Weight             VARCHAR2 (2000) PATH 'weight',
                                           LENGTH             VARCHAR2 (2000) PATH 'length', Width              VARCHAR2 (2000) PATH 'width', Height             VARCHAR2 (2000) PATH 'height')
                         WHERE     process_status = 'NEW'
                               AND file_name = pv_file_name;

        TYPE cartons_tab_type
            IS TABLE OF xxdo_ont_ship_conf_carton_stg%ROWTYPE;

        l_cartons_tab              cartons_tab_type;

        CURSOR cur_order_lines IS
                          SELECT wh_id, shipment_number, order_number,
                                 carton_number, line_number, item_number,
                                 qty, uom, host_subinventory,
                                 'NEW' process_status, NULL error_message, ln_request_id request_id,
                                 SYSDATE creation_date, ln_user_id created_by, SYSDATE last_update_date,
                                 ln_user_id last_updated_by, 'ORDER' source_type, NULL attribute1,
                                 NULL attribute2, NULL attribute3, NULL attribute4,
                                 NULL attribute5, NULL attribute6, NULL attribute7,
                                 NULL attribute8, NULL attribute9, NULL attribute10,
                                 NULL attribute11, NULL attribute12, NULL attribute13,
                                 NULL attribute14, NULL attribute15, NULL attribute16,
                                 NULL attribute17, NULL attribute18, NULL attribute19,
                                 NULL attribute20, 'WMS' SOURCE, 'EBS' destination,
                                 'INSERT' record_type
                            FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                 XMLTABLE (
                                     XMLNAMESPACES (DEFAULT 'http://www.example.org'),
                                     'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder/OutboundOrderCartons/OutboundOrderCarton/OutboundOrderCartonDetails/OutboundOrderCartonDetail'
                                     PASSING xml_tab.xml_document
                                     COLUMNS Wh_Id                VARCHAR2 (2000) PATH 'wh_id', Shipment_Number      VARCHAR2 (2000) PATH 'shipment_number', Order_Number         VARCHAR2 (2000) PATH 'order_number',
                                             Carton_Number        VARCHAR2 (2000) PATH 'carton_number', Line_Number          VARCHAR2 (2000) PATH 'line_number', Item_Number          VARCHAR2 (2000) PATH 'item_number',
                                             Qty                  VARCHAR2 (2000) PATH 'qty', UOM                  VARCHAR2 (2000) PATH 'uom', Host_Subinventory    VARCHAR2 (2000) PATH 'host_subinventory')
                           WHERE     process_status = 'NEW'
                                 AND file_name = pv_file_name;

        TYPE carton_dtls_tab_type
            IS TABLE OF xxdo_ont_ship_conf_cardtl_stg%ROWTYPE;

        l_carton_dtls_tab          carton_dtls_tab_type;

        lv_xml_message_type        VARCHAR2 (30);
        ln_error_count             NUMBER := 0;
        l_exe_msg_type_no_match    EXCEPTION;
        l_ex_bulk_fetch_failed     EXCEPTION;
        l_exe_bulk_insert_failed   EXCEPTION;
        l_exe_dml_errors           EXCEPTION;
        PRAGMA EXCEPTION_INIT (l_exe_dml_errors, -24381);
    BEGIN
        pv_retcode   := '0';
        pv_errbuf    := NULL;
        fnd_file.put_line (fnd_file.LOG,
                           'Starting the XML Specific validations');

        -- Get the message type and environment details from XML
        BEGIN
                   SELECT xml_ext.MESSAGE_TYPE
                     INTO lv_xml_message_type
                     FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                          (XMLTABLE (XMLNAMESPACES (DEFAULT 'http://www.example.org'), '/OutboundShipmentsMessage/MessageHeader' PASSING xml_tab.xml_document
                                     COLUMNS MESSAGE_TYPE NUMBER PATH 'MessageType'))
                          xml_ext
                    WHERE     1 = 1
                          AND process_status = 'NEW'
                          AND file_name = pv_file_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_xml_message_type   := '-1';
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Message type in XML: ' || lv_xml_message_type);

        IF lv_xml_message_type <> gv_ship_confirm_msg_type
        THEN
            RAISE l_exe_msg_type_no_match;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Message Type Validation is Successful');

        -- Establish a save point
        -- If error at any stage, rollback to this save point
        SAVEPOINT l_savepoint_before_load;
        fnd_file.put_line (fnd_file.LOG,
                           'l_savepoint_before_load - Savepoint Established');
        fnd_file.put_line (fnd_file.LOG,
                           'Loading the XML file into database');

        -- Logic to insert shipment headers
        OPEN cur_shipment_headers;

        LOOP
            IF l_shipconf_headers_tab.EXISTS (1)
            THEN
                l_shipconf_headers_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_shipment_headers
                    BULK COLLECT INTO l_shipconf_headers_tab
                    LIMIT pn_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_shipment_headers;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Fetch of Shipment Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_ex_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_shipconf_headers_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_shipconf_headers_tab.FIRST ..
                       l_shipconf_headers_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_head_stg
                         VALUES l_shipconf_headers_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    ln_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Shipment Headers: '
                        || ln_error_count);

                    FOR i IN 1 .. ln_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_shipment_headers;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_shipment_headers;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Insert of Shipment Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_shipment_headers;

        fnd_file.put_line (fnd_file.LOG,
                           'Shipment Headers Load is successful');

        -- Logic to insert deliveries
        OPEN cur_deliveries;

        LOOP
            IF l_shipconf_orders_tab.EXISTS (1)
            THEN
                l_shipconf_orders_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_deliveries
                    BULK COLLECT INTO l_shipconf_orders_tab
                    LIMIT pn_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_deliveries;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Fetch of Deliveries : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_ex_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_shipconf_orders_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_shipconf_orders_tab.FIRST ..
                       l_shipconf_orders_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_order_stg
                         VALUES l_shipconf_orders_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    ln_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of deliveries: '
                        || ln_error_count);

                    FOR i IN 1 .. ln_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_deliveries;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_deliveries;

                    pv_errbuf   :=
                           'Unexpected error in BULK Insert of deliveries : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_deliveries;

        fnd_file.put_line (fnd_file.LOG,
                           'Deliveries/Orders Load is successful');

        -- Logic to insert cartons
        OPEN cur_cartons;

        LOOP
            IF l_cartons_tab.EXISTS (1)
            THEN
                l_cartons_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_cartons
                    BULK COLLECT INTO l_cartons_tab
                    LIMIT pn_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_cartons;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Fetch of Cartons : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_ex_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_cartons_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind IN l_cartons_tab.FIRST .. l_cartons_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_carton_stg
                         VALUES l_cartons_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    ln_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Cartons: '
                        || ln_error_count);

                    FOR i IN 1 .. ln_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_cartons;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_cartons;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Insert of Cartons : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_cartons;

        fnd_file.put_line (fnd_file.LOG, 'Cartons Load is successful');

        -- Logic to insert order lines
        OPEN cur_order_lines;

        LOOP
            IF l_carton_dtls_tab.EXISTS (1)
            THEN
                l_carton_dtls_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_order_lines
                    BULK COLLECT INTO l_carton_dtls_tab
                    LIMIT pn_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_order_lines;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Fetch of Carton details/Order lines : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_ex_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_carton_dtls_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_carton_dtls_tab.FIRST .. l_carton_dtls_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_cardtl_stg
                         VALUES l_carton_dtls_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    ln_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Carton details/Order lines: '
                        || ln_error_count);

                    FOR i IN 1 .. ln_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_order_lines;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_order_lines;

                    pv_errbuf   :=
                           'Unexcepted error in BULK Insert of Carton details/Order lines : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_order_lines;

        fnd_file.put_line (fnd_file.LOG,
                           'Carton Details/Order Lines Load is successful');

        fnd_file.put_line (fnd_file.LOG, 'All Details are loaded');

        -- Update the XML file extract status and commit
        BEGIN
            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = ln_user_id
             WHERE process_status = 'NEW' AND file_name = pv_file_name;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to PROCESSED');
            -- Commit the status update along with all the inserts done before
            COMMIT;
            fnd_file.put_line (fnd_file.LOG, 'Commited the changes');
            fnd_file.put_line (fnd_file.LOG, 'End of Loading');
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '2';
                pv_errbuf    :=
                       'Updating the process status in the XML table failed due to : '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Updating the process status in the XML table failed due to : '
                    || SQLERRM);
                ROLLBACK TO l_savepoint_before_load;
        END;
    EXCEPTION
        WHEN l_exe_msg_type_no_match
        THEN
            ROLLBACK;
            pv_retcode   := '2';
            pv_errbuf    := 'Message Type in XML is not correct';

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = pv_errbuf, last_update_date = SYSDATE,
                   last_updated_by = ln_user_id
             WHERE process_status = 'NEW' AND file_name = pv_file_name;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN l_ex_bulk_fetch_failed
        THEN
            pv_retcode   := '2';
            ROLLBACK TO l_savepoint_before_load;

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = pv_errbuf, last_update_date = SYSDATE,
                   last_updated_by = ln_user_id
             WHERE process_status = 'NEW' AND file_name = pv_file_name;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN l_exe_bulk_insert_failed
        THEN
            pv_retcode   := '2';
            ROLLBACK TO l_savepoint_before_load;

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = pv_errbuf, last_update_date = SYSDATE,
                   last_updated_by = ln_user_id
             WHERE process_status = 'NEW' AND file_name = pv_file_name;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error while extracting the data from XML : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while extracting the data from XML.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
            ROLLBACK TO l_savepoint_before_load;

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = pv_errbuf, last_update_date = SYSDATE,
                   last_updated_by = ln_user_id
             WHERE process_status = 'NEW' AND file_name = pv_file_name;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
    END sc_extract_xml_data;
END xxd_wms_ftp_util_pkg;
/
