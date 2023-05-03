--
-- XXD_PO_AUTORCV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_AUTORCV_PKG"
AS
    --Type to holde processing results for e-mail
    TYPE l_results_rec IS RECORD
    (
        record_number    VARCHAR2 (30),
        record_id        NUMBER,
        record_type      VARCHAR2 (10),
        error_result     VARCHAR2 (1),
        error_msg        VARCHAR2 (2000),
        sku              VARCHAR2 (50),
        quantity         NUMBER
    );

    TYPE tbl_results IS TABLE OF l_results_rec
        INDEX BY PLS_INTEGER;

    --Consolidate logging for the process

    PROCEDURE DoLog (logText IN VARCHAR2)
    IS
    BEGIN
        Fnd_File.PUT_LINE (Fnd_File.LOG, logText);
        DBMS_OUTPUT.put_line (logText);
    END;

    PROCEDURE send_email (p_sender          VARCHAR2,
                          p_recipient       VARCHAR2,
                          p_subject         VARCHAR2,
                          p_body            VARCHAR2,
                          x_status      OUT VARCHAR2,
                          x_message     OUT VARCHAR2)
    IS
        lc_Connection          UTL_SMTP.connection;
        lc_vrData              VARCHAR2 (32000);
        lc_error_status        VARCHAR2 (1) := 'E';
        lc_success_status      VARCHAR2 (1) := 'S';
        lc_recipient_temp      VARCHAR2 (2000) := NULL;
        lc_recipient_mail_id   VARCHAR2 (255);
        lc_port                NUMBER := 25;
        lc_num                 NUMBER := 0;

        lc_reply               UTL_SMTP.reply;
    BEGIN
        DoLog ('EMail sender : ' || p_sender);
        DoLog ('EMail recipient : ' || p_recipient);
        DoLog ('EMail subject : ' || p_subject);

        lc_Connection       := UTL_SMTP.open_connection ('127.0.0.1');
        DoLog ('Connection open');
        UTL_SMTP.helo (lc_Connection, 'localhost');
        lc_num              := 1;

        --TODO : Need to call this multiple times for multiple recipients : format <email address> list is comma seperated

        UTL_SMTP.mail (lc_Connection, p_sender);
        lc_num              := 2;

        lc_recipient_temp   := TRIM (p_recipient);

        IF (INSTR (lc_recipient_temp, ',', 1) = 0)
        THEN
            lc_recipient_mail_id   := lc_recipient_temp;
            DoLog (CHR (10) || 'Email ID: ' || lc_recipient_mail_id);
            UTL_SMTP.rcpt (lc_Connection, TRIM (lc_recipient_mail_id));
        ELSE
            WHILE (LENGTH (lc_recipient_temp) > 0)
            LOOP
                IF (INSTR (lc_recipient_temp, ',', 1) = 0)
                THEN
                    -- Last Mail ID
                    lc_recipient_mail_id   := lc_recipient_temp;
                    DoLog ('Email ID: ' || lc_recipient_mail_id);
                    UTL_SMTP.rcpt (lc_Connection,
                                   TRIM (lc_recipient_mail_id));
                    EXIT;
                ELSE
                    -- Next Mail ID
                    lc_recipient_mail_id   :=
                        TRIM (
                            SUBSTR (lc_recipient_temp,
                                    1,
                                    INSTR (lc_recipient_temp, ',', 1) - 1));
                    doLog ('Email ID: ' || lc_recipient_mail_id);
                    UTL_SMTP.rcpt (lc_Connection,
                                   TRIM (lc_recipient_mail_id));
                END IF;

                lc_recipient_temp   :=
                    TRIM (
                        SUBSTR (lc_recipient_temp,
                                INSTR (lc_recipient_temp, ',', 1) + 1,
                                LENGTH (lc_recipient_temp)));
            END LOOP;
        END IF;

        -- UTL_SMTP.rcpt (lc_Connection, p_recipient);
        lc_num              := 3;
        UTL_SMTP.open_data (lc_Connection); /* ** Sending the header information */
        lc_num              := 4;
        UTL_SMTP.write_data (lc_Connection,
                             'From: ' || p_sender || UTL_TCP.CRLF);
        lc_num              := 5;
        UTL_SMTP.write_data (lc_Connection,
                             'To: ' || p_recipient || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection,
                             'Subject: ' || p_subject || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection,
                             'MIME-Version: ' || '1.0' || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection, 'Content-Type: ' || 'text/html;');
        UTL_SMTP.write_data (
            lc_Connection,
            'Content-Transfer-Encoding: ' || '"8Bit"' || UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF);
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.write_data (
            lc_Connection,
               UTL_TCP.CRLF
            || '<span style="color: black; font-family: Courier New;">'
            || p_body
            || '</span>');
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        UTL_SMTP.write_data (lc_Connection, UTL_TCP.CRLF || '');
        DoLog ('Close data');
        UTL_SMTP.close_data (lc_Connection);

        DoLog ('Lc_reply.code' || lc_reply.code);
        DoLog ('Lc_reply.text' || lc_reply.text);

        UTL_SMTP.quit (lc_Connection);
        DoLog ('Send email status : ' || lc_success_status);

        DoLog ('Lc_reply.code' || lc_reply.code);
        DoLog ('Lc_reply.text' || lc_reply.text);
        x_status            := lc_success_status;
    EXCEPTION
        WHEN UTL_SMTP.INVALID_OPERATION
        THEN
            x_status   := lc_error_status;
            DoLog (' Invalid Operation in Mail attempt using UTL_SMTP.');
        WHEN UTL_SMTP.TRANSIENT_ERROR
        THEN
            x_status   := lc_error_status;
            DoLog (' Temporary e-mail issue - try again');
        WHEN UTL_SMTP.PERMANENT_ERROR
        THEN
            x_status   := lc_error_status;
            DoLog (
                   ' Permanent Error Encountered.: '
                || SQLERRM
                || ' lc_num '
                || lc_num);
            DoLog (' Lc_reply.text' || lc_reply.text);
        WHEN OTHERS
        THEN
            x_status   := lc_error_status;
            DoLog (' Other exception .' || SQLERRM);
    END send_email;

    PROCEDURE create_alert_email (p_results IN tbl_results, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        lc_email_body          VARCHAR2 (32767);
        lc_email_subject       VARCHAR2 (1000)
                                   := 'Deckers Auto Receive ASN and RMA alert';
        lc_mime_type           VARCHAR2 (20) := 'text/html';
        lc_error_code          VARCHAR2 (10);
        lc_error_message       VARCHAR2 (4000);
        lc_status              VARCHAR2 (10);

        lc_email_address       VARCHAR2 (1000) := 'gjensen@deckers.com'; --Rev1 Increased length from 100 to 1000

        lc_from_address        VARCHAR2 (100);
        lc_override_email_id   VARCHAR2 (1996);

        lc_email_body_hdr      VARCHAR2 (1500) := NULL;
        lc_email_body_footer   VARCHAR2 (150) := NULL;

        ln_cnt                 NUMBER := 0;

        lc_main_exeption       EXCEPTION;
        lc_sysdate             DATE;
        lc_db_name             VARCHAR2 (50);
        lc_recipients          VARCHAR2 (1000);

        i                      NUMBER;
    BEGIN
        dolog ('create_alert_email - enter');

        --Email header
        lc_email_body_hdr      :=
               '<html><body>'
            || 'Attention: Deckers Auto Receive ASN and RMA Alert.'
            || ': <br>'
            || '<table border="1" width="106%">'
            || '<tr><b>'
            || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Record Type</td>'
            || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Record_number</td>'
            || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Record ID</td>'
            || '<td width="30%" bgcolor="#909090" align="center" valign="middle">Result</td>'
            || '</b></tr>';

        lc_email_body          := NULL;

        --Get From Email Address
        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';


            dolog ('From email address :' || lc_from_address);
        EXCEPTION
            WHEN OTHERS
            THEN
                dolog (
                       'Error when From Address - '
                    || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300),
                               1,
                               300));
                RAISE lc_main_exeption;
        END;

        --------------------------------------------------------------------------------------
        --***Imlc_portant ***--
        --To avoid sending emails to actual email address from non Production environment,
        --derive overriding address from oracle workflow mail server
        --and send the email to those email address
        --For Production environment, skip this step
        --------------------------------------------------------------------------------------
        lc_override_email_id   := NULL;

        -- Find the environment from V$SESSION
        BEGIN
            SELECT SYS_CONTEXT ('userenv', 'db_name')
              INTO lc_db_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                dolog (
                       'Error when Fetching database name - '
                    || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300),
                               1,
                               300));
                RAISE lc_main_exeption;
        END;

        IF LOWER (lc_db_name) NOT LIKE '%prod%'
        THEN
            BEGIN
                --Fetch override email address for Non Prod Instances
                SELECT fscpv.parameter_value
                  INTO lc_override_email_id
                  FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
                 WHERE     fscpt.parameter_id = fscpv.parameter_id
                       AND fscpv.component_id = fsc.component_id
                       AND fscpt.display_name = 'Test Address'
                       AND fsc.component_name =
                           'Workflow Notification Mailer';


                dolog ('Override Email Address :' || lc_override_email_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    dolog (
                           'Error while deriving override email address :'
                        || SUBSTR (SQLERRM, 300));
                    RAISE lc_main_exeption;
            END;
        END IF;

        BEGIN
            --Get recipients
            SELECT fvt.description email
              INTO lc_email_address
              FROM apps.FND_FLEX_VALUE_SETS fvs, FND_FLEX_VALUES fv, fnd_flex_values_tl fvt
             WHERE     flex_value_set_name = 'XXDO_COMMON_EMAIL_RPT'
                   AND fvs.flex_value_set_id = fv.flex_value_set_id
                   AND fv.flex_value_id = fvt.flex_value_id
                   AND fv.flex_value = 'XXD_PO_AUTORCV_EMAIL'
                   AND fvt.language = 'US'
                   AND fv.ENABLED_FLAG = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (fv.start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (fv.end_date_active,
                                                        SYSDATE));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_error_message   := 'No Recipient list';
                RAISE lc_main_exeption;
            --Rev1 Added Catch all error handler and additional log
            WHEN OTHERS
            THEN
                lc_error_message   := 'Error getting recipients. ' || SQLERRM;
                RAISE lc_main_exeption;
        END;

        doLog ('After get recipients');
        lc_override_email_id   := lc_email_address;


        FOR i IN 1 .. p_results.COUNT
        LOOP
            DoLog (
                   'Record_type '
                || p_results (i).record_type
                || ' Record_number '
                || p_results (i).record_number
                || ' Record ID '
                || p_results (i).record_id
                || ' Process Result '
                || NVL (p_results (i).error_msg, 'Success'));

            --Form email body
            lc_email_body   :=
                   lc_email_body
                || '<tr valign="middle">'
                || '<td width="12%">'
                || p_results (i).record_type
                || '</td>'
                || '<td width="12%">'
                || p_results (i).record_number
                || '</td>'
                || '<td width="12%">'
                || p_results (i).record_id
                || '</td>'
                || '</td>'
                || '<td width="30%">'
                || NVL (p_results (i).error_msg, 'Success')
                || '</td>'
                || '</tr>';
            ln_cnt   := ln_cnt + 1;
        END LOOP;

        lc_email_body          :=
            lc_email_body_hdr || lc_email_body || lc_email_body_footer;

        IF ln_cnt > 0
        THEN
            IF     lc_from_address IS NOT NULL
               AND NVL (lc_override_email_id, lc_email_address) IS NOT NULL
            THEN
                doLog ('call send_email ');

                send_email (lc_from_address, NVL (lc_override_email_id, lc_email_address), lc_email_subject
                            , lc_email_body, lc_status, lc_error_message);

                IF (lc_status <> 'S')
                THEN
                    doLog (
                        'Error after call to send_email:' || lc_error_message);


                    RAISE lc_main_exeption;
                END IF;
            END IF;
        END IF;

        pv_error_stat          := 'S';
        pv_error_msg           := NULL;
        dolog ('create_alert_email - exit . Stat : ' || pv_error_stat);
    EXCEPTION
        WHEN lc_main_exeption
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lc_error_message;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE do_auto_receive_process (p_error_stat OUT VARCHAR2, p_error_msg OUT VARCHAR2, p_org_id IN NUMBER, p_asn_id IN NUMBER:= NULL, p_rma_id IN NUMBER:= NULL, p_dummy IN VARCHAR:= NULL
                                       , p_to_date IN DATE:= NULL)
    IS
        CURSOR c_recs (p_org_id NUMBER, p_record_type VARCHAR2, p_record_id VARCHAR2
                       , p_to_date DATE)
        IS
            SELECT *
              FROM xxdo.xxd_po_autorcv_v
             WHERE     organization_id = p_org_id
                   AND source_document_code =
                       NVL (p_record_type, source_document_code)
                   AND record_id = NVL (p_record_id, record_id)
                   AND record_date <= NVL (p_to_date, record_date);

        l_record_id             VARCHAR2 (30);
        l_record_type           VARCHAR2 (30);
        l_record_date           DATE;
        l_error_msg             VARCHAR2 (200);

        l_error_stat            VARCHAR2 (1);

        ex_invalid_parameters   EXCEPTION;
        l_results               tbl_results;
    BEGIN
        --Parameter listing
        doLog ('Organization ID ' || p_org_id);
        doLog ('ASN ID ' || p_asn_id);
        doLog ('RMA ID ' || p_rma_id);
        doLog ('To Date ' || TO_CHAR (p_to_date, 'YYYY/MM/DD'));



        --Begin prameter validation

        doLog ('Validation - Start');

        /* Requirements
        ORG_ID - Reqired
        Both ASN_ID and RMA_ID cannnot be provided
        TO_DATE is reqired if neither ASN_ID or RMA_ID is provided
        */
        IF p_org_id IS NULL
        THEN
            l_error_msg   := 'ORG ID is required';
            RAISE ex_invalid_parameters;
        END IF;

        IF p_asn_id IS NOT NULL AND p_rma_id IS NOT NULL
        THEN
            l_error_msg   := 'Both RMA # and ASN # cannot be provided';
            RAISE ex_invalid_parameters;
        END IF;

        IF p_asn_id IS NULL AND p_rma_id IS NULL
        THEN
            IF p_to_date IS NULL
            THEN
                l_error_msg   :=
                    'Date required if neither RMA# or ASN# provided';
                RAISE ex_invalid_parameters;
            END IF;

            l_record_date   := p_to_date;
        END IF;

        IF p_asn_id IS NOT NULL
        THEN
            l_record_id     := p_asn_id;
            l_record_type   := 'REQ';
        END IF;

        IF p_rma_id IS NOT NULL
        THEN
            l_record_id     := p_rma_id;
            l_record_type   := 'RMA';
        END IF;

        doLog ('Validation - End');

        --End validation

        FOR rec IN c_recs (p_org_id, l_record_type, l_record_id,
                           l_record_date)
        LOOP
            DoLog ('Processing for record : ' || rec.record_number);
            DoLog ('Processing for record - ID : ' || rec.record_id);

            --Check REQ type ASN for PENDING ASN status. Since we are bypassing the normal
            --3PL process, update the ASN status
            --Running the NVL will allow this process to run w/o the progress cartons process running first
            IF     NVL (rec.asn_status, 'PENDING') = 'PENDING'
               AND rec.source_document_code = 'REQ'
            THEN
                DoLog (
                    'Setting ASN ' || rec.record_number || ' to EXTRACTED');

                UPDATE rcv_shipment_headers
                   SET asn_status = 'EXTRACTED', attribute4 = 'N', --We are not going to do carton level receiving on these
                                                                   attribute2 = TO_CHAR (shipment_header_id) --Makes this ASN visible in the PA views
                 WHERE rec.record_id = shipment_header_id;
            END IF;

            XXDO_WMS_3PL_INTERFACE.Process_auto_receipt (
                p_org_id        => rec.organization_id,
                p_record_id     => rec.record_id, -- ORDER HEADER_ID for RMA, SHIPMENT_HEADER_ID for ASN
                p_record_type   => rec.source_document_code, --REQ (ASN), RET (RETURN)
                p_error_stat    => l_error_stat,
                p_error_msg     => l_error_msg);
            --    l_error_stat:='E';
            --   l_error_msg:=NULL;

            DoLog ('Process_auto_receipt - Error stat : ' || l_error_stat);

            --Populate the results table with the return from the process
            l_results (l_results.COUNT + 1).record_number   :=
                rec.record_number;
            l_results (l_results.COUNT).record_id      := rec.record_id;
            l_results (l_results.COUNT).record_type    :=
                rec.source_document_code;
            l_results (l_results.COUNT).error_result   := l_error_stat;
            l_results (l_results.COUNT).error_msg      := l_error_msg;
        --sku             VARCHAR2 (50),
        --quantity        NUMBER
        END LOOP;

        doLog ('Rec Count : ' || l_results.COUNT);

        IF l_results.COUNT > 0
        THEN
            DoLog ('Executing E-mail');
            --Send alert e-mail
            create_alert_email (l_results, p_error_stat, p_error_msg);
        END IF;
    EXCEPTION
        WHEN ex_invalid_parameters
        THEN
            p_error_msg    := l_error_msg;
            p_error_stat   := 'E';
        WHEN OTHERS
        THEN
            p_error_msg    := 'Unexpected error';
            p_error_stat   := 'U';
    END;
END XXD_PO_AUTORCV_PKG;
/
