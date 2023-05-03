--
-- XXDOPO_POC_UTILS_PUB  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOPO_POC_UTILS_PUB"
AS
    /*************************************************************
        Date        Version             Notes
        10-12-16                        Initial deployment
        10/20/16    Rev1                Bug Fixes
        03/09/17    Infosys             Modified for CCR CCR0006035; IDENTIFIED by CCR0006035
                                     1) Updating Last Update Date to SYSDATE for PO Lines and PO Line Locations
             2) Sending Error Message to Users via EMail when Need by date or ship to location is updated
                for a PO when linked with Drop ship SO Line
        05/04/17    Infosys             Modified for CCR CCR0006285; IDENTIFIED by CCR0006285
                                      1) Quantity Update on Distributor SOs when PO in Approved status
                                      2) Quantity Cancellation on Distributor SOs After Quantity is partially rec_received
           3) Added OTHERS Exception for not to end the program abruptly
                                      4) Check Performed if the Stg table quantity is greater than PO quantity when split flag is Yes
        07/19/17    Infosys             Modified for CCR CCR0006517; IDENTIFIED by CCR0006517
                                   1) Added OTHERS Exception for not to end the program abruptly
           2) Check for any standard program which is in Pending/Running. Hold the program to avoid data issues
           3) For Distributor SOs, Promise date is not getting updated when quantity is partially received
           4) For an Intercompany POs, when promise date is updated corresponding ISO request date is getting updated but schedule ship date is not getting updated.
           5) Program not performing any action when there exists a corresponding PO shipment line is in Error Status in Staging table.
        16/02/2018  Infosys             Modified for CCR CCR0007064 ; IDENTIFIED BY CCR0007064
                                   1) Ship Method 'Air Express' needs to be accepted by POC Program
           2) In case of Split Scenario, if only one line comes to Staging table, that Record should be excluded
              for Processing
           3) Emails sent from POC program should send out all the Purchase Orders created /errored out rather than Partial list
        14/05/2018  Infosys             Modified for CCR CCR0007262 ; IDENTIFIED BY CCR0007262
                                   1) Distributor Purchase Orders quantity is not getting GTN sends quantity which is same as quantity received
           2) US Purchese Orders when not getting updated when quantity billed is populated whe split flag is Yes
           3) Modified Last Updated By as BATCH.P2P instead of the user who has created Distributor SO Line.
     28/06/19 GJensen                CCR0007979 - Updated to use new function to get PO Type s part of Macau Project
     28/06/19 GJensen                CCR0008134 - POC Upgrade
     01/03/21 Satyanarayana Kotha    CCR0009182 - POC Changes
  26/10/21 Showkath Ali           CCR0009609 (Updating pla.attribute15 with Original line quantity)
  12/01/22 Shivanshu Talwar       CCR0010003  POC Enhancements
  25/05/22 Aravind Kannuri        CCR0010003  POC Enhancements
  25/05/22 Gaurav Joshi           CCR0008896  Supplier Shipment
    **************************************************************/
    --Consolidate logging for the process

    PROCEDURE DoTiming (logText IN VARCHAR2)
    IS
    BEGIN
        Fnd_File.PUT_LINE (
            Fnd_File.LOG,
            logText || ' : ' || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24:MI:SS'));
        DBMS_OUTPUT.put_line (logText);
    END;


    PROCEDURE DoLog (logText IN VARCHAR2)
    IS
    BEGIN
        Fnd_File.PUT_LINE (Fnd_File.LOG, logText);
        DBMS_OUTPUT.put_line (logText);
    END;

    --Check if passed PO number is a standard PO. Direct delivery to a DC
    --Depreciating this in CCR0008134
    /*   FUNCTION is_standard_po (pv_po_number IN VARCHAR)
          RETURN BOOLEAN
       IS
          -- ln_org_id                    NUMBER;  --CCR0007979
          -- ln_ship_to_organization_id   NUMBER;--CCR0007979
          -- ln_project_id                NUMBER;--CCR0007979

          lv_po_type        VARCHAR2 (20);
          ln_po_header_id   NUMBER;
       BEGIN
          --Begin CCR0007979
          --Check org and destination warehouse
    --            SELECT DISTINCT
    --                   pha.org_id, plla.ship_to_organization_id, pla.project_id
    --              INTO ln_org_id, ln_ship_to_organization_id, ln_project_id
    --              FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla
    --             WHERE     pha.po_header_id = pla.po_header_id
    --                   AND pla.po_line_id = plla.po_line_id
    --                   AND pha.segment1 = pv_po_number;
    --
    --            --not a XDOCK
    --            IF ln_project_id IS NOT NULL
    --            THEN
    --               RETURN FALSE;
    --            END IF;
    --
    --            --US Org
    --            IF ln_org_id = 95
    --            THEN
    --               RETURN TRUE;
    --            END IF;
    --
    --            --US dc
    --            IF    ln_ship_to_organization_id = 107
    --               OR ln_ship_to_organization_id = 108
    --               OR ln_ship_to_organization_id = 109
    --            THEN
    --               RETURN TRUE;
    --            END IF;
    --
    --            RETURN FALSE;
          --End CCR0007979

          SELECT po_header_id
            INTO ln_po_header_id
            FROM po_headers_all
           WHERE segment1 = pv_po_number;

          lv_po_type := XXD_PO_GET_PO_TYPE (ln_po_header_id);         --CCR0007979

          RETURN lv_po_type = 'STANDARD';
       EXCEPTION
          WHEN NO_DATA_FOUND
          THEN
             RETURN FALSE;
          WHEN TOO_MANY_ROWS
          THEN
             RETURN FALSE;
          WHEN OTHERS
          THEN
             RETURN FALSE;
       END;*/

    FUNCTION Get_Next_Batch_id
        RETURN NUMBER
    IS
        ln_BatchID      NUMBER;
        ln_MaxBatchID   NUMBER;
    BEGIN
        LOOP
            SELECT xxdo.xxdo_gtn_poc_batch_id_seq.NEXTVAL
              INTO ln_BatchID
              FROM DUAL;

            BEGIN
                SELECT MAX (batch_id)
                  INTO ln_MaxBatchID
                  FROM xxdo.xxdo_gtn_po_collab_stg;

                IF ln_MaxBatchID IS NULL
                THEN
                    ln_MaxBatchID   := 0;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_MaxBatchID   := 0;
            END;

            EXIT WHEN ln_BatchID > ln_MaxBatchID;
        END LOOP;

        RETURN ln_BatchID;
    END;

    PROCEDURE write_error_to_stg_rec (pn_batch_id NUMBER, pn_order_number NUMBER, pb_set_error_status IN BOOLEAN
                                      , pv_error_text IN VARCHAR2)
    IS
        ln_header_id   NUMBER;
    BEGIN
        --No record ID passed. Update entire batch
        BEGIN
            SELECT header_id
              INTO ln_header_id
              FROM oe_order_headers_all
             WHERE order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN;
        END;

        UPDATE xxdo.xxdo_gtn_po_collab_stg
           SET error_message   = pv_error_text
         WHERE oe_header_id = ln_header_id AND batch_id = pn_batch_id;

        IF pb_set_error_status
        THEN
            UPDATE xxdo.xxdo_gtn_po_collab_stg
               SET processing_status_code   = 'ERROR'
             WHERE oe_header_id = ln_header_id AND batch_id = pn_batch_id;
        END IF;
    -- Start CCR0006517
    EXCEPTION
        WHEN OTHERS
        THEN
            DOLOG (
                'Error in Procedure write_error_to_stg_rec :: ' || SQLERRM);
    -- Start CCR0006517
    END;

    --Write a message to the error message field in the stage table
    PROCEDURE write_error_to_stg_rec (
        pn_batch_id              NUMBER,
        pn_stage_record       IN NUMBER := NULL,
        pn_line_location_id   IN NUMBER := NULL,
        pb_set_error_status   IN BOOLEAN,
        pv_error_text         IN VARCHAR2)
    IS
    BEGIN
        --No record ID passed. Update entire batch

        UPDATE xxdo.xxdo_gtn_po_collab_stg
           SET error_message   = pv_error_text
         WHERE     batch_id = pn_batch_id
               AND gtn_po_collab_stg_id =
                   NVL (pn_stage_record, gtn_po_collab_stg_id)
               AND po_line_location_id =
                   NVL (pn_line_location_id, po_line_location_id);

        IF pb_set_error_status
        THEN
            UPDATE xxdo.xxdo_gtn_po_collab_stg
               SET processing_status_code   = 'ERROR'
             WHERE     batch_id = pn_batch_id
                   AND gtn_po_collab_stg_id =
                       NVL (pn_stage_record, gtn_po_collab_stg_id)
                   AND po_line_location_id =
                       NVL (pn_line_location_id, po_line_location_id);
        END IF;
    -- Start CCR0006517
    EXCEPTION
        WHEN OTHERS
        THEN
            DOLOG (
                   'Error in Procedure write_error_to_stg_rec proc :: '
                || SQLERRM);
    -- Start CCR0006517
    END;

    --Begin CCR0008134
    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;
        ln_user_id          NUMBER := fnd_global.user_id;

        CURSOR recips_cur IS
            SELECT flv.meaning email_id
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = pv_lookup_type
                   AND flv.enabled_flag = 'Y'
                   AND flv.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE));

        CURSOR submitted_by_cur IS
            SELECT NVL (fu.email_address, ppx.email_address) email_id
              FROM fnd_user fu, per_people_x ppx
             WHERE     1 = 1
                   AND fu.user_id = ln_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE))
                   AND fu.employee_id = ppx.person_id(+);
    BEGIN
        IF ln_user_id = -1
        THEN
            ln_user_id   := 1876;                                  --BATCH.P2P
        END IF;

        v_def_mail_recips.DELETE;


        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        ELSE
            FOR submitted_by_rec IN submitted_by_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    submitted_by_rec.email_id;
            END LOOP;


            RETURN v_def_mail_recips;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';

            RETURN v_def_mail_recips;
    END get_email_ids;

    PROCEDURE send_error_rpt_email (pn_request_id IN NUMBER)
    IS
        lv_inst_name        VARCHAR2 (30) := NULL;
        lv_msg              VARCHAR2 (4000) := NULL;
        ln_ret_val          NUMBER := 0;
        lv_out_line         VARCHAR2 (4000);

        ex_no_recips        EXCEPTION;
        v_def_mail_recips   do_mail_utils.tbl_recips;
        ln_cnt              NUMBER;

        CURSOR email_cur IS
            SELECT stg.*
              FROM xxdo.xxd_po_poc_soa_intf_stg_t stg
             WHERE     1 = 1
                   AND process_status = 'ERROR'
                   AND request_id = pn_request_id;
    BEGIN
        dolog ('send_error_rpt_email - Enter');

        --Check if any records are to be returned
        SELECT COUNT (*)
          INTO ln_cnt
          FROM xxdo.xxd_po_poc_soa_intf_stg_t stg
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND request_id = pn_request_id;

        IF ln_cnt = 0
        THEN
            dolog ('send_error_rpt_email - No Records');
            --No records in report
            RETURN;
        END IF;

        BEGIN
            SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inst_name   := '';
                lv_msg         :=
                       'Error getting the instance name in send_email_proc procedure. Error is '
                    || SQLERRM;

                raise_application_error (-20010, lv_msg);
        END;

        v_def_mail_recips   :=
            get_email_ids ('XXD_PO_POC_ERROR_RPT_EMAIL', lv_inst_name);

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'POC Process Error Report. ' || ' Email generated from ' || lv_inst_name || ' instance'
                                             , ln_ret_val);

        do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);                 --Added
        do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);                 --Added
        --            do_mail_utils.send_mail_line ('Content-Type: text/plain', ln_ret_val); --Not Required
        --            do_mail_utils.send_mail_line ('', ln_ret_val); --Not Required
        do_mail_utils.send_mail_line ('Hi Purchasing Support,', ln_ret_val);
        do_mail_utils.send_mail_line (
               'Please find attached the error report of POC Program at .'
            || SYSDATE,
            ln_ret_val);
        do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        do_mail_utils.send_mail_line ('Content-Type: text/xls', ln_ret_val);
        do_mail_utils.send_mail_line (
               'Content-Disposition: attachment; filename="Deckers_Party_webadi_credit_'
            || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
            || '.xls"',
            ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);

        apps.do_mail_utils.send_mail_line (
               'Batch Number'
            || CHR (9)
            || 'PO Number'
            || CHR (9)
            || 'Line Number'
            || CHR (9)
            || 'Item'
            || CHR (9)
            || 'Qty'
            || CHR (9)
            || 'Conf. Ex-Fac Date'
            || CHR (9)
            || 'Promised Date Override'
            || CHR (9)
            || 'Delay Reason'
            || CHR (9)
            || 'Coments'
            || CHR (9)
            || 'Split Qty 1'
            || CHR (9)
            || 'Split Date 1'
            || CHR (9)
            || 'Split Ship Method 1'
            || CHR (9)
            || 'Split Qty 2'
            || CHR (9)
            || 'Split Date 2'
            || CHR (9)
            || 'Split Ship Method 2'
            || CHR (9)
            || 'Status'
            || CHR (9)
            || 'Error Message',
            ln_ret_val);

        FOR email_rec IN email_cur
        LOOP
            lv_out_line   := NULL;
            lv_out_line   :=
                   email_rec.batch_id
                || CHR (9)
                || email_rec.po_number
                || CHR (9)
                || email_rec.line_number
                || CHR (9)
                || email_rec.item_number
                || CHR (9)
                || email_rec.quantity
                || CHR (9)
                || email_rec.Conf_xf_date
                || CHR (9)
                || email_rec.promised_date_override
                || CHR (9)
                || email_rec.delay_reason
                || CHR (9)
                || email_rec.comments1
                || CHR (9)
                || email_rec.split_qty_1
                || CHR (9)
                || email_rec.split_date_1
                || CHR (9)
                || email_rec.split_ship_method_1
                || CHR (9)
                || email_rec.split_qty_2
                || CHR (9)
                || email_rec.split_date_2
                || CHR (9)
                || email_rec.split_ship_method_2
                || CHR (9)
                || email_rec.process_status
                || CHR (9)
                || email_rec.error_message
                || CHR (9);
            apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
        END LOOP;

        apps.do_mail_utils.send_mail_close (ln_ret_val);
        dolog ('send_error_rpt_email - End');
    EXCEPTION
        WHEN ex_no_recips
        THEN
            DoLog (
                'POC Process Error Report : There were no recipients configured to receive the alert');
            do_mail_utils.send_mail_close (ln_ret_val);              --Be Safe
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            lv_msg   :=
                   'In When others exception in send_error_rpt_email procedure. Error is: '
                || SQLERRM;
            raise_application_error (-20010, lv_msg);
    END;

    --End CCR0008134

    --Note: This is no longer called. Calling code was commented.
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
            x_message   :=
                ' Invalid Operation in Mail attempt using UTL_SMTP.';
        WHEN UTL_SMTP.TRANSIENT_ERROR
        THEN
            x_status    := lc_error_status;
            DoLog (' Temporary e-mail issue - try again');
            x_message   := ' Temporary e-mail issue - try again';
        WHEN UTL_SMTP.PERMANENT_ERROR
        THEN
            x_status   := lc_error_status;
            DoLog (
                   ' Permanent Error Encountered.: '
                || SQLERRM
                || ' lc_num '
                || lc_num);
            DoLog (' Lc_reply.text' || lc_reply.text);
            x_message   :=
                   '  Permanent Error Encountered.: '
                || SQLERRM
                || ' lc_num '
                || lc_num;
        WHEN OTHERS
        THEN
            x_status    := lc_error_status;
            DoLog (' Other exception .' || SQLERRM);
            x_message   := SQLERRM;
    END;

    --Commented CCR0007064
    /*PROCEDURE create_alert_email (pn_batch_id     IN     NUMBER,
                                  pv_error_stat      OUT VARCHAR2,
                                  pv_error_msg       OUT VARCHAR2)
    IS
       lc_email_body          VARCHAR2 (32767);
       lc_email_subject       VARCHAR2 (1000)
                                 := 'POs created by PO Collaboration alert';
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

       CURSOR c_po_list
       IS
            SELECT pha.po_header_id,
                   pha.segment1 po_number,
                   stg.from_po_header_id,
                   src_pha.segment1 source_po_number,
                   v.vendor_name,
                   vs.vendor_site_code,
                   msib.style,
                   pla.attribute1 brand,
                   msib.color,
                   SUM (pla.quantity) po_qty
              FROM (SELECT DISTINCT po_header_id, from_po_header_id, batch_id
                      FROM xxdo.xxdo_gtn_po_collab_stg) stg,
                   apps.po_headers_all pha,
                   apps.po_lines_all pla,
                   apps.po_headers_all src_pha,
                   (SELECT *
                      FROM xxdo.XXDOINT_INV_PRODUCT_CATALOG_V
                     WHERE organization_id = 106) msib,
                   po_vendors v,
                   po_vendor_sites_all vs
             WHERE     stg.po_header_id = pha.po_header_id
                   AND stg.from_po_header_id IS NOT NULL
                   AND stg.from_po_header_id = src_pha.po_header_id
                   AND pla.po_header_id = pha.po_header_id
                   AND pla.item_id = msib.inventory_item_id
                   AND stg.po_header_id != stg.from_po_header_id
                   AND pha.vendor_id = v.vendor_id
                   AND pha.vendor_site_id = vs.vendor_site_id
                   AND stg.batch_id = pn_batch_id
          GROUP BY pha.po_header_id,
                   pha.segment1,
                   stg.from_po_header_id,
                   src_pha.segment1,
                   pla.attribute1,
                   msib.style,
                   msib.color,
                   v.vendor_name,
                   vs.vendor_site_code;

       lc_main_exeption       EXCEPTION;
       lc_sysdate             DATE;
       lc_db_name             VARCHAR2 (50);
       lc_recipients          VARCHAR2 (1000);
    BEGIN
       dolog ('create_alert_email - enter');

       --Email header
       lc_email_body_hdr :=
             '<html><body>'
          || 'Attention: New PO Created Based on Cancel/Rebook Process.'
          || ': <br>'
          || '<table border="1" width="106%">'
          || '<tr><b>'
          || '<td width="12%" bgcolor="#909090" align="center" valign="middle">New PO Number</td>'
          || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Origional PO Number</td>'
          || '<td width="10%" bgcolor="#909090" align="center" valign="middle">Brand</td>'
          || '<td width="30%" bgcolor="#909090" align="center" valign="middle">Vendor </td>'
          || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Vendor Site </td>'
          || '<td width="20%" bgcolor="#909090" align="center" valign="middle">Style-Color </td>'
          || '<td width="10%" bgcolor="#909090" align="center" valign="middle">Quantity </td>'
          || '</b></tr>';

       lc_email_body := NULL;

       --Get From Email Address
       BEGIN
          SELECT fscpv.parameter_value
            INTO lc_from_address
            FROM fnd_svc_comp_params_tl fscpt,
                 fnd_svc_comp_param_vals fscpv,
                 fnd_svc_components fsc
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
                || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300), 1, 300));
             RAISE lc_main_exeption;
       END;

       --------------------------------------------------------------------------------------
       --***Imlc_portant ***--
       --To avoid sending emails to actual email address from non Production environment,
       --derive overriding address from oracle workflow mail server
       --and send the email to those email address
       --For Production environment, skip this step
       --------------------------------------------------------------------------------------
       lc_override_email_id := NULL;

       -- Find the environment from V$SESSION
       BEGIN
          SELECT SYS_CONTEXT ('userenv', 'db_name') INTO lc_db_name FROM DUAL;
       EXCEPTION
          WHEN OTHERS
          THEN
             dolog (
                   'Error when Fetching database name - '
                || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300), 1, 300));
             RAISE lc_main_exeption;
       END;

       IF LOWER (lc_db_name) NOT LIKE '%prod%'
       THEN
          BEGIN
             --Fetch override email address for Non Prod Instances
             SELECT fscpv.parameter_value
               INTO lc_override_email_id
               FROM fnd_svc_comp_params_tl fscpt,
                    fnd_svc_comp_param_vals fscpv,
                    fnd_svc_components fsc
              WHERE     fscpt.parameter_id = fscpv.parameter_id
                    AND fscpv.component_id = fsc.component_id
                    AND fscpt.display_name = 'Test Address'
                    AND fsc.component_name = 'Workflow Notification Mailer';


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
            FROM apps.FND_FLEX_VALUE_SETS fvs,
                 FND_FLEX_VALUES fv,
                 fnd_flex_values_tl fvt
           WHERE     flex_value_set_name = 'XXDO_COMMON_EMAIL_RPT'
                 AND fvs.flex_value_set_id = fv.flex_value_set_id
                 AND fv.flex_value_id = fvt.flex_value_id
                 AND fv.flex_value = 'XXDOPO_RUN_POC'
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
             lc_error_message := 'No Recipient list';
             RAISE lc_main_exeption;
          --Rev1 Added Catch all error handler and additional log
          WHEN OTHERS
          THEN
             lc_error_message := 'Error getting recipients. ' || SQLERRM;
             RAISE lc_main_exeption;
       END;

       doLog ('After get recipients');
       lc_override_email_id := lc_email_address;

       FOR rec IN c_po_list
       LOOP
          DoLog (
                'New PO '
             || rec.po_number
             || ' Source PO '
             || rec.source_po_number
             || ' Brand '
             || rec.brand
             || ' po_number '
             || rec.source_po_number
             || ' vendor '
             || rec.vendor_name
             || ' vendor site '
             || rec.vendor_site_code
             || ' style/color '
             || rec.style
             || '-'
             || rec.color
             || ' qty '
             || rec.po_qty);

          --Form email body
          lc_email_body :=
                lc_email_body
             || '<tr valign="middle">'
             || '<td width="12%">'
             || rec.po_number
             || '</td>'
             || '<td width="12%">'
             || rec.source_po_number
             || '</td>'
             || '<td width="10%">'
             || rec.brand
             || '</td>'
             || '<td width="30%">'
             || rec.vendor_name
             || '</td>'
             || '<td width="12%">'
             || rec.vendor_site_code
             || '</td>'
             || '<td width="20%">'
             || rec.style
             || '-'
             || rec.color
             || '</td>'
             || '<td width="10%">'
             || rec.po_qty
             || '</td>'
             || '</tr>';
          ln_cnt := ln_cnt + 1;

    -- Start CCR0006517
    IF length(lc_email_body) > 3000
    THEN
      EXIT;
    END IF;
    -- End CCR0006517
       END LOOP;

    -- Start CCR0006517
    IF LENGTH (lc_email_body_hdr || lc_email_body || lc_email_body_footer) > 3000
    THEN
      --lc_email_body := lc_email_body_hdr || lc_email_body || lc_email_body_footer;
    lc_email_body := SUBSTR((lc_email_body_hdr || lc_email_body || lc_email_body_footer),1,3000);
    lc_email_body := lc_email_body || '</td>' || '</tr>' || 'Please Check with IT Team for more error records';
    ELSE
      lc_email_body := lc_email_body_hdr || lc_email_body || lc_email_body_footer;
    END IF;
    -- End CCR0006517

       IF ln_cnt > 0
       THEN
          IF     lc_from_address IS NOT NULL
             AND NVL (lc_override_email_id, lc_email_address) IS NOT NULL
          THEN
             send_email (lc_from_address,
                         NVL (lc_override_email_id, lc_email_address),
                         lc_email_subject,
                         lc_email_body,
                         lc_status,
                         lc_error_message);

             IF (lc_status <> 'S')
             THEN
                doLog ('Error after call to send_email:' || lc_error_message);


                RAISE lc_main_exeption;
             END IF;
          END IF;
       END IF;

       pv_error_stat := 'S';
       pv_error_msg := NULL;
       dolog ('create_alert_email - exit');
    EXCEPTION
       WHEN lc_main_exeption
       THEN
          pv_error_stat := 'E';
          pv_error_msg := lc_error_message;
    dolog('Error for exception lc_main_exeption :: ' ||  pv_error_msg); -- CCR0006517
       WHEN OTHERS
       THEN
          pv_error_stat := 'U';
          pv_error_msg := SQLERRM;
    dolog('Error in Procedure create_alert_email :: ' || pv_error_msg); -- CCR0006517
    END create_alert_email;*/

    -- Added for CCR0006035
    /*PROCEDURE create_error_alert_email (pn_batch_id     IN     NUMBER,
                                 pv_error_stat      OUT VARCHAR2,
                                 pv_error_msg       OUT VARCHAR2)
   IS
      lc_email_body          VARCHAR2 (32767);
      lc_email_subject       VARCHAR2 (1000)
                                := 'POs created by PO Collaboration alert';
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

      CURSOR c_po_error_list
      IS
     select error_message,
       po_number,
       line_num,
       quantity,
       ship_method,
       split_flag,
       ex_factory_date,
       new_promised_date,
       closed_code,
       segment1 item,
       brand
  from xxdo.xxdo_gtn_po_collab_stg,
       mtl_system_items_b
       where inventory_item_id =item_id
       AND organization_id =106
   AND PROCESSING_STATUS_CODE ='ERROR'
   AND BATCH_ID =pn_batch_id;

      lc_main_exeption       EXCEPTION;
      lc_sysdate             DATE;
      lc_db_name             VARCHAR2 (50);
      lc_recipients          VARCHAR2 (1000);
   BEGIN
      dolog ('create_error_alert_email - enter');

      --Email header
      lc_email_body_hdr :=
            '<html><body>'
         || 'Attention: PO Errored out due to below reason during cancel/rebook process .'
         || ': <br>'
         || '<table border="1" width="106%">'
         || '<tr><b>'
         || '<td width="12%" bgcolor="#909090" align="center" valign="middle">New PO Number</td>'
         || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Line Number</td>'
         || '<td width="10%" bgcolor="#909090" align="center" valign="middle">Brand</td>'
         || '<td width="30%" bgcolor="#909090" align="center" valign="middle">Item</td>'
         || '<td width="12%" bgcolor="#909090" align="center" valign="middle">Quantity</td>'
         || '<td width="20%" bgcolor="#909090" align="center" valign="middle">Error Message</td>'
         || '</b></tr>';

      lc_email_body := NULL;

      --Get From Email Address
      BEGIN
         SELECT fscpv.parameter_value
           INTO lc_from_address
           FROM fnd_svc_comp_params_tl fscpt,
                fnd_svc_comp_param_vals fscpv,
                fnd_svc_components fsc
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
               || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300), 1, 300));
            RAISE lc_main_exeption;
      END;

      --------------------------------------------------------------------------------------
      --***Imlc_portant ***--
      --To avoid sending emails to actual email address from non Production environment,
      --derive overriding address from oracle workflow mail server
      --and send the email to those email address
      --For Production environment, skip this step
      --------------------------------------------------------------------------------------
      lc_override_email_id := NULL;

      -- Find the environment from V$SESSION
      BEGIN
         SELECT SYS_CONTEXT ('userenv', 'db_name') INTO lc_db_name FROM DUAL;
      EXCEPTION
         WHEN OTHERS
         THEN
            dolog (
                  'Error when Fetching database name - '
               || SUBSTR (SQLCODE || ' : ' || SUBSTR (SQLERRM, 300), 1, 300));
            RAISE lc_main_exeption;
      END;

      IF LOWER (lc_db_name) NOT LIKE '%prod%'
      THEN
         BEGIN
            --Fetch override email address for Non Prod Instances
            SELECT fscpv.parameter_value
              INTO lc_override_email_id
              FROM fnd_svc_comp_params_tl fscpt,
                   fnd_svc_comp_param_vals fscpv,
                   fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Test Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';


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
           FROM apps.FND_FLEX_VALUE_SETS fvs,
                FND_FLEX_VALUES fv,
                fnd_flex_values_tl fvt
          WHERE     flex_value_set_name = 'XXDO_COMMON_EMAIL_RPT'
                AND fvs.flex_value_set_id = fv.flex_value_set_id
                AND fv.flex_value_id = fvt.flex_value_id
                AND fv.flex_value = 'XXDOPO_RUN_POC'
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
            lc_error_message := 'No Recipient list';
            RAISE lc_main_exeption;
         --Rev1 Added Catch all error handler and additional log
         WHEN OTHERS
         THEN
            lc_error_message := 'Error getting recipients. ' || SQLERRM;
            RAISE lc_main_exeption;
      END;

      doLog ('After get recipients');
      lc_override_email_id := lc_email_address;

      FOR rec IN c_po_error_list
      LOOP
         DoLog (
               ' PO '
            || rec.po_number
            || ' Line Number '
            || rec.Line_num
            || ' Brand '
            || rec.brand
            || ' style/color '
            || rec.item
            || ' qty '
            || rec.quantity
            || ' Error '
            || rec.error_message);

         --Form email body
         lc_email_body :=
               lc_email_body
            || '<tr valign="middle">'
            || '<td width="12%">'
            || rec.po_number
            || '</td>'
            || '<td width="12%">'
            || rec.line_num
            || '</td>'
            || '<td width="10%">'
            || rec.brand
            || '</td>'
            || '<td width="30%">'
            || rec.item
            || '</td>'
            || '<td width="20%">'
            || rec.quantity
            || '</td>'
            || '<td width="10%">'
            || rec.error_message
            || '</td>'
            || '</tr>';
         ln_cnt := ln_cnt + 1;

   -- Start CCR0006517
   IF length(lc_email_body) > 3000
   THEN
     EXIT;
   END IF;
   -- End CCR0006517
      END LOOP;

      -- Start CCR0006517
   --lc_email_body :=
        -- lc_email_body_hdr || lc_email_body || lc_email_body_footer;

   IF LENGTH (lc_email_body_hdr || lc_email_body || lc_email_body_footer) > 3000
   THEN
     --lc_email_body := lc_email_body_hdr || lc_email_body || lc_email_body_footer;
   lc_email_body := SUBSTR((lc_email_body_hdr || lc_email_body || lc_email_body_footer),1,3000);
   lc_email_body := lc_email_body || '</td>' || '</tr>' || 'Please Check with IT Team for more error records';
   ELSE
     lc_email_body := lc_email_body_hdr || lc_email_body || lc_email_body_footer;
   END IF;
   -- End CCR0006517

      IF ln_cnt > 0
      THEN
         IF     lc_from_address IS NOT NULL
            AND NVL (lc_override_email_id, lc_email_address) IS NOT NULL
         THEN
            send_email (lc_from_address,
                        NVL (lc_override_email_id, lc_email_address),
                        lc_email_subject,
                        lc_email_body,
                        lc_status,
                        lc_error_message);

            IF (lc_status <> 'S')
            THEN
               doLog ('Error after call to send_email:' || lc_error_message);


               RAISE lc_main_exeption;
            END IF;
         END IF;
      END IF;

      pv_error_stat := 'S';
      pv_error_msg := NULL;
      dolog ('create_error_alert_email - exit');
   EXCEPTION
      WHEN lc_main_exeption
      THEN
         pv_error_stat := 'E';
         pv_error_msg := lc_error_message;
   dolog('Error for exception lc_main_exeption :: ' ||  pv_error_msg); -- CCR0006517
      WHEN OTHERS
      THEN
         pv_error_stat := 'U';
         pv_error_msg := SQLERRM;
   dolog('Error for procedure create_error_alert_email :: ' ||  pv_error_msg); -- CCR0006517
   END create_error_alert_email;*/

    --START CCR0007064
    PROCEDURE create_alert_email (pn_batch_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        l_req_id         NUMBER;
        l_phase          VARCHAR2 (100);
        l_status         VARCHAR2 (30);
        l_dev_phase      VARCHAR2 (100);
        l_dev_status     VARCHAR2 (100);
        l_wait_req       BOOLEAN;
        l_message        VARCHAR2 (2000);
        l_user_id        NUMBER := NULL;
        l_resp_id        NUMBER := NULL;
        l_resp_appl_id   NUMBER := NULL;
    BEGIN
        BEGIN
            SELECT user_id
              INTO l_user_id
              FROM fnd_user
             WHERE user_name = 'BATCH.P2P';
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                       'Error in Fetching User id for User Batch.P2P :: '
                    || SQLERRM);
        END;

        BEGIN
            SELECT responsibility_id, application_id
              INTO l_resp_id, l_resp_appl_id
              FROM apps.fnd_responsibility_vl frv
             WHERE frv.responsibility_name =
                   'Deckers Purchasing User - Global';
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                       'Error in Fetching Responsibility and Application ids for Purchasing Global Resp :: '
                    || SQLERRM);
        END;

        fnd_global.apps_initialize (user_id        => l_user_id,
                                    resp_id        => l_resp_id,
                                    resp_appl_id   => l_resp_appl_id);

        COMMIT;

        l_req_id   :=
            fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXDO_POC_NEW_PO_REPORT',
                argument1     => pn_batch_id,
                start_time    => SYSDATE,
                sub_request   => FALSE);
        COMMIT;

        IF l_req_id = 0
        THEN
            doLog (
                'Unable to submit Error Report program Because Req id is zero');
        ELSE
            COMMIT;
            doLog (
                   'Error Report  concurrent request submitted successfully :: '
                || SQLERRM);
            l_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id, INTERVAL => 1, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status
                                                 , MESSAGE => l_message);

            IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
            THEN
                doLog (
                       'Error Report  concurrent request with the request id '
                    || l_req_id
                    || ' completed with NORMAL status.');
            ELSE
                doLog (
                       'Error Report concurrent request with the request id  :: '
                    || l_req_id
                    || ' did not complete with NORMAL status.');
            END IF; -- End of if to check if the status is normal and phase is complete
        END IF;                      -- End of if to check if request ID is 0.

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            doLog ('Error in create_alert_email Procedure :: ' || SQLERRM);
    END create_alert_email;

    PROCEDURE create_error_alert_email (pn_batch_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        l_req_id         NUMBER;
        l_phase          VARCHAR2 (100);
        l_status         VARCHAR2 (30);
        l_dev_phase      VARCHAR2 (100);
        l_dev_status     VARCHAR2 (100);
        l_wait_req       BOOLEAN;
        l_message        VARCHAR2 (2000);
        l_user_id        NUMBER := NULL;
        l_resp_id        NUMBER := NULL;
        l_resp_appl_id   NUMBER := NULL;
    BEGIN
        BEGIN
            SELECT user_id
              INTO l_user_id
              FROM fnd_user
             WHERE user_name = 'BATCH.P2P';
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                       'Error in Fetching User id for User Batch.P2P :: '
                    || SQLERRM);
        END;

        BEGIN
            SELECT responsibility_id, application_id
              INTO l_resp_id, l_resp_appl_id
              FROM apps.fnd_responsibility_vl frv
             WHERE frv.responsibility_name =
                   'Deckers Purchasing User - Global';
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                       'Error in Fetching Responsibility and Application ids for Purchasing Global Resp :: '
                    || SQLERRM);
        END;

        fnd_global.apps_initialize (user_id        => l_user_id,
                                    resp_id        => l_resp_id,
                                    resp_appl_id   => l_resp_appl_id);

        COMMIT;

        l_req_id   :=
            fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXDO_POC_ERROR_ALERT',
                argument1     => pn_batch_id,
                start_time    => SYSDATE,
                sub_request   => FALSE);
        COMMIT;

        IF l_req_id = 0
        THEN
            doLog (
                'Unable to submit Error Report program Because Req id is zero');
        ELSE
            COMMIT;
            doLog (
                   'Error Report  concurrent request submitted successfully :: '
                || SQLERRM);
            l_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id, INTERVAL => 1, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status
                                                 , MESSAGE => l_message);

            IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
            THEN
                doLog (
                       'Error Report  concurrent request with the request id '
                    || l_req_id
                    || ' completed with NORMAL status.');
            ELSE
                doLog (
                       'Error Report concurrent request with the request id  :: '
                    || l_req_id
                    || ' did not complete with NORMAL status.');
            END IF; -- End of if to check if the status is normal and phase is complete
        END IF;                      -- End of if to check if request ID is 0.

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            doLog (
                'Error in create_error_alert_email Procedure :: ' || SQLERRM);
    END create_error_alert_email;

    -- END CCR0007064


    --Log into Deckers Purchasing using the passed ORG ID/User
    PROCEDURE set_purchasing_context (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
                                      , pv_error_msg OUT VARCHAR2)
    IS
        pv_msg            VARCHAR2 (2000);
        pv_stat           VARCHAR2 (1);
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;

        ex_get_resp_id    EXCEPTION;
    BEGIN
        BEGIN
            --TODO : Should we just use Deckers Purcasing User - Global in all cases?
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name      --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_id NOT IN (51395, 51398)      --TEMP
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = pn_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE ex_get_resp_id;
        --ln_resp_id := gn_resp_id;
        -- ln_resp_appl_id := gn_resp_appl_id;
        --lv_err_msg := SUBSTR(SQLERRM,1,900);
        --  pn_err_code := SQLCODE;
        --  pv_err_message :=
        --       'Error in apps intialize while getting resp id'
        --     || '-'
        --    || SUBSTR (SQLERRM, 1, 900);
        END;

        DoLog ('Context Info before');
        DoLog ('Curr ORG: ' || apps.mo_global.get_current_org_id);
        DoLog ('Multi Org Enabled: ' || apps.mo_global.is_multi_org_enabled);

        --do intialize and purchssing setup
        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        /* old way
       apps.mo_global.init ('PO');
       --   apps.mo_global.Set_org_context (pn_org_id, NULL, 'PO');
       apps.mo_global.set_policy_context ('S', pn_org_id);
       */

        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', pn_org_id);
        FND_REQUEST.SET_ORG_ID (pn_org_id);

        DoLog ('Context Info after');
        DoLog ('Curr ORG: ' || apps.mo_global.get_current_org_id);
        DoLog ('Multi Org Enabled: ' || apps.mo_global.is_multi_org_enabled);

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_get_resp_id
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error getting Purchasing context resp_id : ' || SQLERRM;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;

    --Log into Deckers Order Management responsibility using passed ORG_ID/User ID
    PROCEDURE set_om_context (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
                              , pv_error_msg OUT VARCHAR2)
    IS
        pv_msg            VARCHAR2 (2000);
        pv_stat           VARCHAR2 (1);
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;

        ex_get_resp_id    EXCEPTION;
    BEGIN
        DoLog ('Org ID : ' || pn_org_id);

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name_so     --'MO: Operating Unit'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name_so || '%' --'Deckers Order Management User%'
                   AND fpov.profile_option_value = TO_CHAR (pn_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE ex_get_resp_id;
        --ln_resp_id := gn_resp_id;
        -- ln_resp_appl_id := gn_resp_appl_id;
        --lv_err_msg := SUBSTR(SQLERRM,1,900);
        --  pn_err_code := SQLCODE;
        --  pv_err_message :=
        --       'Error in apps intialize while getting resp id'
        --     || '-'
        --    || SUBSTR (SQLERRM, 1, 900);
        END;

        DoLog ('set OM context');
        DoLog ('User ID : ' || pn_user_id);
        DoLog ('Resp ID : ' || ln_resp_id);
        DoLog ('Appl ID : ' || ln_resp_appl_id);

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        -- pass in user_id, responsibility_id, and application_id
        apps.oe_msg_pub.initialize;
        apps.oe_debug_pub.initialize;
        apps.mo_global.Init ('ONT');                       -- Required for R12
        apps.mo_global.Set_org_context (pn_org_id, NULL, 'ONT');
        apps.fnd_global.Set_nls_context ('AMERICAN');
        apps.mo_global.Set_policy_context ('S', pn_org_id); -- Required for R12

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_get_resp_id
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error getting OM Context resp_id : ' || SQLERRM;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE approve_po (pv_po_number IN VARCHAR2, pn_user_id IN NUMBER, pv_error_stat OUT VARCHAR2
                          , pv_error_msg OUT VARCHAR2)
    IS
        v_item_key              VARCHAR2 (100);

        ln_po_header_id         NUMBER;
        ln_org_id               NUMBER;
        ln_agent_id             NUMBER;
        lv_document_type_code   VARCHAR2 (100);
        lv_document_subtype     VARCHAR2 (100);

        ex_validation           EXCEPTION;
    BEGIN
        BEGIN
            SELECT pha.po_header_id, pha.org_id, pha.agent_id,
                   pdt.document_type_code, pdt.document_subtype
              INTO ln_po_header_id, ln_org_id, ln_agent_id, lv_document_type_code,
                                  lv_document_subtype
              FROM po_headers_all pha, apps.po_document_types_all pdt
             WHERE     pha.type_lookup_code = pdt.document_subtype
                   AND pha.org_id = pdt.org_id
                   AND pdt.document_type_code = 'PO'
                   AND pha.segment1 = pv_po_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg   := 'PO ' || pv_po_number || ' not found';
                dolog (pv_error_msg);                            -- CCR0006517
                RAISE ex_validation;
        END;

        set_purchasing_context (pn_user_id, ln_org_id, pv_error_stat,
                                pv_error_msg);


        SELECT ln_po_header_id || '-' || TO_CHAR (po_wf_itemkey_s.NEXTVAL)
          INTO v_item_key
          FROM DUAL;

        DoLog (
               ' Calling po_reqapproval_init1.start_wf_process for po_id=> '
            || pv_po_number);


        po_reqapproval_init1.start_wf_process (ItemType => 'POAPPRV', ItemKey => v_item_key, WorkflowProcess => 'POAPPRV_TOP', ActionOriginatedFrom => 'PO_FORM', DocumentID => ln_po_header_id -- po_header_id
                                                                                                                                                                                               , DocumentNumber => pv_po_number -- Purchase Order Number
                                                                                                                                                                                                                               , PreparerID => ln_agent_id -- Buyer/Preparer_id
                                                                                                                                                                                                                                                          , DocumentTypeCode => lv_document_type_code --'PO'
                                                                                                                                                                                                                                                                                                     , DocumentSubtype => lv_document_subtype --'STANDARD'
                                                                                                                                                                                                                                                                                                                                             , SubmitterAction => 'APPROVE', forwardToID => NULL, forwardFromID => NULL, DefaultApprovalPathID => NULL, Note => NULL, PrintFlag => 'N', FaxFlag => 'N', FaxNumber => NULL, EmailFlag => 'N', EmailAddress => NULL, CreateSourcingRule => 'N', ReleaseGenMethod => 'N', UpdateSourcingRule => 'N', MassUpdateReleases => 'N', RetroactivePriceChange => 'N', OrgAssignChange => 'N', CommunicatePriceChange => 'N', p_Background_Flag => 'N', p_Initiator => NULL, p_xml_flag => NULL, FpdsngFlag => 'N'
                                               , p_source_type_code => NULL);

        DoLog ('The PO which is Approved Now =>' || pv_po_number);
        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_validation
        THEN
            pv_error_stat   := 'E';
            dolog (pv_error_msg);                                -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error. ' || SQLERRM;
            dolog ('Error in procedure approve_po :: ' || pv_error_msg); -- CCR0006517
    END;

    PROCEDURE run_req_import (p_import_source IN VARCHAR2, p_batch_id IN VARCHAR2:= '', p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_user_id IN NUMBER, p_status OUT VARCHAR
                              , p_msg OUT VARCHAR2, p_request_id OUT NUMBER)
    AS
        l_request_id   NUMBER;
        l_req_id       NUMBER;
        l_req_status   BOOLEAN;
        x_ret_stat     VARCHAR2 (1);
        x_error_text   VARCHAR2 (20000);
        l_phase        VARCHAR2 (80);
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        p_resp_id      NUMBER;
        p_app_id       NUMBER;

        n_cnt          NUMBER;

        CURSOR c_err IS
            SELECT transaction_id,
                   process_flag,
                   request_id,
                   interface_source_code,
                   batch_id,
                   preparer_id,
                   org_id,
                   line_attribute14 stg_rec_id,
                   (SELECT COUNT (*)
                      FROM po_interface_errors pie
                     WHERE pie.interface_transaction_id = pria.transaction_id) error_cnt
              FROM apps.po_requisitions_interface_all pria
             WHERE     interface_source_code = p_import_source
                   AND request_id = l_request_id
                   AND batch_id = p_batch_id
                   AND process_flag = 'ERROR';
    BEGIN
        DoLog ('run_req_import - enter');
        DoLog ('     Import Source : ' || p_import_source);
        DoLog ('     Batch ID      : ' || p_batch_id);
        DoLog ('     org ID        : ' || p_org_id);
        DoLog ('     inv org ID    : ' || p_inv_org_id);
        DoLog ('     user_id       : ' || p_user_id);

        set_purchasing_context (p_user_id, p_org_id, p_status,
                                p_msg);

        DoLog ('run_req_import - submit request');
        l_request_id   :=
            apps.fnd_request.submit_request (application   => 'PO',
                                             program       => 'REQIMPORT',
                                             argument1     => p_import_source,
                                             argument2     => p_batch_id,
                                             argument3     => 'VENDOR',
                                             argument4     => '',
                                             argument5     => 'N',
                                             argument6     => 'Y');
        DoLog (l_req_id);

        COMMIT;
        DoLog (
               'run_req_import - wait for request - Request ID :'
            || l_request_id);
        l_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => l_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);

        DoLog ('run_req_import - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text   :=
                NVL (
                    l_message,
                       'The requisition import request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
            p_msg   := x_error_text;
        ELSE
            x_ret_stat   := 'S';
        END IF;

        DoLog ('run_req_import - after wait for request -  ' || x_ret_stat);

        DoLog ('Check for interface records in error state');

        --check for interface records from above request in error state and error out the corresponding stage records
        IF x_ret_stat = 'S'
        THEN
            n_cnt   := 0;

            FOR err_rec IN c_err
            LOOP
                --Update source stage table record fo the errored req_interface line
                UPDATE xxdo.xxdo_gtn_po_collab_stg
                   SET processing_status_code = 'ERROR', error_message = 'Record for stage table record ID : ' || err_rec.stg_rec_id || ' is in error status in requisitions interface'
                 WHERE gtn_po_collab_stg_id = err_rec.stg_rec_id;

                DoLog (
                       'Record for stage table record ID : '
                    || err_rec.stg_rec_id
                    || ' is in error status in requisitions interface');
                n_cnt   := n_cnt + 1;
            END LOOP;

            IF n_cnt > 0
            THEN
                x_ret_stat   := 'W';
                x_error_text   :=
                    'One or more records failed to interface to a requisition line';
            END IF;
        END IF;

        p_status       := x_ret_stat;
        p_msg          := x_error_text;
        p_request_id   := l_request_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status       := 'U';
            p_msg          :=
                   ' requisition import failed with unexpected error '
                || SQLERRM;
            p_request_id   := NULL;
            dolog (
                'Unexpected error in procedure run_req_import :: ' || SQLERRM); -- CCR0006517
    END;

    PROCEDURE run_workflow_bkg (p_user_id IN NUMBER, p_status OUT VARCHAR, p_msg OUT VARCHAR2
                                , p_request_id OUT NUMBER)
    AS
        l_request_id   NUMBER;
        x_ret_stat     VARCHAR2 (1);
        x_error_text   VARCHAR2 (20000);
        l_phase        VARCHAR2 (80);
        l_req_status   BOOLEAN;
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        l_data         VARCHAR2 (200);

        p_resp_id      NUMBER;
        p_app_id       NUMBER;
    BEGIN
        DoLog ('run_workflow_bkg - submit request');
        l_request_id   :=
            apps.fnd_request.submit_request (application => 'FND', program => 'FNDWFBG', argument1 => 'OEOL', argument2 => '', argument3 => '', argument4 => 'Y'
                                             , argument5 => 'N');
        COMMIT;
        DoLog ('run_workflow_bkg - after submit request -  ' || l_request_id);
        l_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => l_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);

        DoLog (
            'run_workflow_bkg - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text   :=
                NVL (
                    l_message,
                       'The workflow background process ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
        ELSE
            x_ret_stat   := 'S';
        END IF;


        p_status       := x_ret_stat;
        p_msg          := x_error_text;
        p_request_id   := l_request_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := 'U';
            x_error_text   :=
                'run_workflow_bkg failed with unexpected error ' || SQLERRM;
            DOLOG ('Error in procedure run_workflow_bkg :: ' || x_error_text); -- CCR0006517
    END;

    --Begin CCR0008134
    FUNCTION get_po_country_code (pn_po_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_organization_id   NUMBER := NULL;
        ln_location_id       NUMBER := NULL;
        lv_country           VARCHAR2 (20) := NULL;
    BEGIN
        lv_country   := NULL;                           --Added for CCR0010003

        BEGIN
            --ICO and Direct Ship
            SELECT DISTINCT prla.destination_organization_id
              INTO ln_organization_id
              FROM po_requisition_lines_all prla, oe_order_lines_all oola, po_line_locations_all plla,
                   po_headers_all pha
             WHERE     1 = 1
                   AND pha.po_header_id = pn_po_header_id
                   AND plla.po_header_id = pha.po_header_id
                   AND oola.attribute16 = TO_CHAR (plla.line_location_id)
                   AND prla.requisition_line_id =
                       oola.source_document_line_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    --JP (TQ Orders)
                    SELECT DISTINCT plla_jp.ship_to_organization_id
                      INTO ln_organization_id
                      FROM po_line_locations_all plla_jp, po_lines_all pla_jp, oe_order_lines_all oola,
                           oe_drop_ship_sources dss
                     WHERE     1 = 1
                           AND plla_jp.po_line_id = pla_jp.po_line_id
                           AND pla_jp.attribute5 = TO_CHAR (oola.line_id)
                           AND oola.line_id = dss.line_id
                           AND dss.po_header_id = pn_po_header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        /* --Commented for CCR0010003
                        --Direct ship
                        SELECT DISTINCT plla.ship_to_organization_id
                          INTO ln_organization_id
                          FROM po_line_locations_all plla
                         WHERE plla.po_header_id = pn_po_header_id; */

                        --Start Added for CCR0010003
                        --Distributor and Direct Procurement (For this POs, ln_transit_days = 0)
                        BEGIN
                            SELECT DISTINCT plla.ship_to_location_id
                              INTO ln_location_id
                              FROM po_line_locations_all plla
                             WHERE     plla.po_header_id = pn_po_header_id
                                   AND plla.ship_to_location_id IS NOT NULL
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_location_id   := NULL;
                                DoLog (
                                       'get_po_country_code - ln_location_id: '
                                    || SQLCODE
                                    || '-'
                                    || SQLERRM);
                        END;
                --End Added for CCR0010003
                END;
        END;

        --Get country
        IF ln_location_id IS NOT NULL
        THEN
            BEGIN                                       --Added for CCR0010003
                SELECT country_code
                  INTO lv_country
                  FROM xxdo.xxdoint_po_locations_v
                 WHERE location_id = ln_location_id;
            --Start Added for CCR0010003
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country   := NULL;
                    DoLog (
                           'get_po_country_code - lv_country: '
                        || SQLCODE
                        || '-'
                        || SQLERRM);
            END;
        --End Added for CCR0010003
        ELSE
            BEGIN                                       --Added for CCR0010003
                SELECT hzl.country
                  INTO lv_country
                  FROM hr_locations hzl, hr_all_organization_units hr
                 --po_hr_locations hzl, hr_all_organization_units hr
                 WHERE     hzl.location_id = hr.location_id
                       AND hr.organization_id = ln_organization_id;
            --Start Added for CCR0010003
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country   := NULL;
                    DoLog (
                           'get_po_country_code - lv_country: '
                        || SQLCODE
                        || '-'
                        || SQLERRM);
            END;
        --End Added for CCR0010003
        END IF;

        RETURN lv_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_pol_transit_days (p_po_number IN VARCHAR2, p_po_line_num IN NUMBER, p_po_ship_method IN VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        ln_po_header_id            NUMBER;
        lv_po_ship_method          VARCHAR2 (30);
        lv_po_country              VARCHAR2 (10);
        ln_po_vendor_id            NUMBER;
        lv_po_vendor_site_code     VARCHAR2 (40);
        ln_transit_days            NUMBER;
        lv_preferred_ship_method   VARCHAR2 (50);
    BEGIN
        doLog (
               'get_pol_transit_days enter PO_NUMBER : '
            || p_po_number
            || ' PO LINE : '
            || p_po_line_num);

        --Get PO line shipment and vendor details
        SELECT pha.po_header_id, plla.attribute10 ship_method_code, pha.vendor_id,
               --  apsa.vendor_site_code --commented as part of CCR0010003
               NVL (pla.attribute7, apsa.vendor_site_code) --added as part of CCR0010003
          INTO ln_po_header_id, lv_po_ship_method, ln_po_vendor_id, lv_po_vendor_site_code
          FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
               ap_supplier_sites_all apsa
         WHERE     1 = 1
               AND pha.po_header_id = pla.po_header_id
               AND pla.po_line_id = plla.po_line_id
               AND pha.vendor_site_id = apsa.vendor_site_id
               AND pha.segment1 = p_po_number
               AND pla.line_num = p_po_line_num;

        --Get PO destination region
        lv_po_country   := get_po_country_code (ln_po_header_id);


        --Lookup transit days from lookup table
        SELECT DECODE (UPPER (NVL (p_po_ship_method, lv_po_ship_method)),  'AIR', NVL (flv.attribute5, 0),  'OCEAN', NVL (flv.attribute6, 0),  'TRUCK', NVL (flv.attribute7, 0),  -1), attribute8
          INTO ln_transit_days, lv_preferred_ship_method
          FROM fnd_lookup_values flv
         WHERE     flv.language = 'US'
               AND flv.lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
               AND flv.attribute1 = ln_po_vendor_id
               AND flv.attribute2 = lv_po_vendor_site_code
               AND flv.attribute3 = lv_po_country
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN flv.start_date_active
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        IF ln_transit_days = 0
        THEN
            RETURN 0;
        END IF;

        --if not found in any matrix setting use preferred ship method
        IF ln_transit_days = -1
        THEN
            --If no preferred ship method, return Ocean
            IF lv_preferred_ship_method IS NULL
            THEN
                lv_preferred_ship_method   := 'Ocean';
            END IF;

            --Lookup transit days from lookup table
            SELECT DECODE (UPPER (NVL (attribute8, lv_po_ship_method)),  'AIR', flv.attribute5,  'OCEAN', flv.attribute6,  'TRUCK', flv.attribute7,  NULL)
              INTO ln_transit_days
              FROM fnd_lookup_values flv
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                   AND flv.attribute1 = ln_po_vendor_id
                   AND flv.attribute2 = lv_po_vendor_site_code
                   AND flv.attribute3 = lv_po_country
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN flv.start_date_active
                                   AND NVL (flv.end_date_active, SYSDATE + 1);
        END IF;

        RETURN ln_transit_days;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --Start changes for CCR0010003
    FUNCTION get_pol_sup_transit_days (p_po_number IN VARCHAR2, pn_vendor_id IN NUMBER, pn_vendor_site_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_po_header_id            NUMBER;
        lv_po_country              VARCHAR2 (10);
        lv_vendor_site_code        VARCHAR2 (50);
        lv_po_vendor_site_code     VARCHAR2 (50);
        ln_transit_days            NUMBER;
        lv_preferred_ship_method   VARCHAR2 (50);
    BEGIN
        --Get PO Header ID
        BEGIN
            SELECT po_header_id
              INTO ln_po_header_id
              FROM po_headers_all
             WHERE segment1 = p_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_po_header_id   := NULL;
        END;

        --Get PO destination region
        lv_po_country   := get_po_country_code (ln_po_header_id);
        DoLog ('get_po_country_code\destination_org : ' || lv_po_country);

        --Get PO Vendor Site Code
        IF pn_vendor_site_id IS NOT NULL
        THEN
            BEGIN
                SELECT apss.vendor_site_code
                  INTO lv_vendor_site_code
                  FROM ap_suppliers aps, ap_supplier_sites_all apss
                 WHERE     aps.vendor_id = apss.vendor_id
                       AND apss.vendor_site_id = pn_vendor_site_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vendor_site_code   := NULL;
            END;
        ELSE
            lv_vendor_site_code   := NULL;
        END IF;

        DoLog ('new supplier site code : ' || lv_vendor_site_code);

        --Lookup transit days from lookup table
        BEGIN
            SELECT DECODE (UPPER (NVL (flv.attribute8, 'OCEAN')),  'AIR', NVL (flv.attribute5, 0),  'OCEAN', NVL (flv.attribute6, 0),  'TRUCK', NVL (flv.attribute7, 0),  -1), NVL (flv.attribute8, 'OCEAN')
              INTO ln_transit_days, lv_preferred_ship_method
              FROM fnd_lookup_values flv
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                   AND flv.attribute1 = pn_vendor_id
                   AND flv.attribute2 = lv_vendor_site_code
                   AND flv.attribute3 = lv_po_country
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN flv.start_date_active
                                   AND NVL (flv.end_date_active, SYSDATE + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_transit_days            := -1;
                lv_preferred_ship_method   := NULL;
        END;

        IF NVL (ln_transit_days, 0) > 0
        THEN
            DoLog (
                   'Transit days : '
                || ln_transit_days
                || ' for preferred shipmethod :'
                || lv_preferred_ship_method);
            RETURN ln_transit_days;
        ELSIF NVL (ln_transit_days, 0) = 0
        THEN
            RETURN 0;
        ELSE
            RETURN -1;
        END IF;

        RETURN ln_transit_days;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --End changes for CCR0010003

    FUNCTION get_jp_po_line (p_line_location_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_po_line_id   NUMBER;
    BEGIN
        BEGIN
            SELECT pla_jp.po_line_id
              INTO ln_po_line_id
              FROM po_line_locations_all plla, oe_drop_ship_sources dss, oe_order_lines_all oola,
                   po_lines_all pla_jp
             WHERE     plla.line_location_id = p_line_location_id
                   AND plla.line_location_id = dss.line_location_id
                   AND dss.line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = pla_jp.attribute5;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
        END;

        RETURN ln_po_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --End CCR0008134

    --Rev3
    --Takes in a PO numb er and an item key in x.x.x format and finds the matching po line_location_id
    FUNCTION get_polla_id_from_item_key (pv_po_number   IN VARCHAR2,
                                         pv_item_key    IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_polla_id       NUMBER;
        ln_cnt            NUMBER := 1;
        ln_instr          NUMBER;
        ln_substr         NUMBER := 1;
        ln_line_num       VARCHAR2 (10);
        ln_shipment_num   VARCHAR2 (10);
        ln_distrb_num     VARCHAR2 (10);
    BEGIN
        --Convert ITEM_KEY to a PO LINE/PO_SHIPMENT/PO_DISTRIBUTION
        --splitting item key to 3 different variables line_num, shipment_num, distribution_num


        WHILE (ln_cnt < 3)
        LOOP
            ln_instr   :=
                INSTR (pv_item_key, '.', 1,
                       ln_cnt);

            IF (ln_cnt = 1)
            THEN
                ln_line_num   :=
                    SUBSTR (pv_item_key, ln_substr, ln_instr - 1);
                ln_substr   := ln_instr;
            ELSIF (ln_cnt = 2)
            THEN
                ln_shipment_num   :=
                    SUBSTR (pv_item_key,
                            ln_substr + 1,
                            ln_instr - ln_substr - 1);
                ln_distrb_num   := SUBSTR (pv_item_key, ln_instr + 1);
            END IF;

            ln_cnt   := ln_cnt + 1;
        END LOOP;

        --find the shipment ID based on item key values
        SELECT line_location_id
          INTO ln_polla_id
          FROM po_lines_all pla, po_line_locations_all plla, po_headers_all pha
         WHERE     pha.segment1 = pv_po_number
               AND pla.line_num = TO_NUMBER (ln_line_num)
               AND plla.shipment_num = TO_NUMBER (ln_shipment_num)
               AND pha.po_header_id = pla.po_header_id
               AND pla.po_line_id = plla.po_line_id;

        RETURN ln_polla_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            DoLog (
                   'Error in procedure Get_POLLA_ID_from_item_key :: '
                || SQLERRM);
            --Any error just return NULL
            RETURN NULL;
    END;

    --Check if the passed in value belongs in the specified value set
    FUNCTION check_for_value_set_value (pn_value_set_id      IN NUMBER,
                                        pv_value_set_value   IN VARCHAR)
        RETURN BOOLEAN
    IS
        ln_cnt   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO ln_cnt
          FROM FND_FLEX_VALUES
         WHERE     flex_value_set_id = pn_value_set_id
               AND flex_value = pv_value_set_value;


        IF ln_cnt > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DoLog (
                'Error in procedure check_for_value_set_value :: ' || SQLERRM);
            RETURN FALSE;
    END;

    --Check the hold status of a given SO and release if requested
    FUNCTION check_so_hold_status (pn_so_header_id   IN     NUMBER,
                                   pb_release_hold   IN     BOOLEAN := FALSE,
                                   pn_user_id        IN     NUMBER,
                                   pv_error_stat        OUT VARCHAR2,
                                   pv_error_msg         OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_hold_count   NUMBER;

        ex_login        EXCEPTION;

        FUNCTION get_hold_count (pn_so_header_id NUMBER)
            RETURN NUMBER
        IS
        BEGIN
              SELECT COUNT (1) "Hold Count"
                INTO ln_hold_count
                FROM oe_order_lines_all hold_lines, oe_order_headers_all ooha, oe_order_holds_all holds,
                     oe_hold_sources_all ohsa, oe_hold_releases ohr, oe_hold_definitions ohd
               WHERE     1 = 1
                     AND holds.released_flag = 'N'
                     AND ohd.name = 'Credit Check Failure'
                     AND holds.line_id = hold_lines.line_id(+)
                     AND holds.header_id = hold_lines.header_id(+)
                     AND holds.hold_release_id = ohr.hold_release_id(+)
                     AND holds.hold_source_id = ohsa.hold_source_id
                     AND ohsa.hold_id = ohd.hold_id
                     AND holds.header_id = ooha.header_id
                     AND ooha.header_id = pn_so_header_id
            ORDER BY ohsa.hold_source_id;

            RETURN ln_hold_count;
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                    'Error in procedure check_so_hold_status :: ' || SQLERRM);
                RETURN 0;
        END;

        PROCEDURE release_so_hold ( -- This procedure is invoked to release hold on SO
                                   pn_so_header_id IN NUMBER, pn_user_id IN NUMBER, pv_error_stat OUT VARCHAR2
                                   , pv_error_msg OUT VARCHAR2)
        IS
            gn_resp_id        NUMBER := apps.fnd_global.resp_id;
            gn_resp_appl_id   NUMBER := apps.fnd_global.resp_appl_id;


            vReturnStatus     VARCHAR2 (150);
            vMsgCount         NUMBER := 0;
            vMsg              VARCHAR2 (2000);
            v_order_tbl       OE_HOLDS_PVT.ORDER_TBL_TYPE;
            ln_resp_id        NUMBER;
            ln_resp_appl_id   NUMBER;
            ln_hold_id        NUMBER;
            ln_ORG_id         NUMBER;

            ex_login          EXCEPTION;
        BEGIN
            BEGIN
                SELECT ohsa.hold_id
                  INTO ln_hold_id
                  FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                 WHERE     1 = 1
                       AND ohd.name = 'Credit Check Failure'
                       AND holds.hold_source_id = ohsa.hold_source_id
                       AND ohsa.hold_id = ohd.hold_id
                       AND ROWNUM <= 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_stat   := 'E';
                    pv_error_msg    :=
                           'Error while getting Hold Id in Release Hold Procedure'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
                    RETURN;
            END;

            SELECT org_id
              INTO ln_org_id
              FROM apps.oe_order_headers_all
             WHERE header_id = pn_so_header_id;

            set_om_context (PN_USER_ID, ln_org_id, PV_ERROR_STAT,
                            PV_ERROR_MSG);

            IF PV_ERROR_STAT <> 'S'
            THEN
                RAISE ex_login;
            END IF;

            v_order_tbl.DELETE;
            v_order_tbl (1).header_id   := pn_so_header_id;

            apps.OE_HOLDS_PUB.Release_Holds (
                p_api_version           => 1.0,
                p_init_msg_list         => FND_API.G_FALSE,
                p_commit                => FND_API.G_FALSE,
                p_validation_level      => FND_API.G_VALID_LEVEL_FULL,
                p_order_tbl             => v_order_tbl,
                p_hold_id               => ln_hold_id,
                p_release_reason_code   => 'CRED-REL',
                p_release_comment       => NULL,
                x_return_status         => vReturnStatus,
                x_msg_count             => vMsgCount,
                x_msg_data              => vMsg);
            DoLog ('Status of Release Holds ' || vReturnStatus);
        EXCEPTION
            WHEN ex_login
            THEN
                pv_error_msg    := 'Login error: ' || pv_error_msg;
                pv_error_stat   := 'E';
            WHEN OTHERS
            THEN
                pv_error_stat   := 'U';
                pv_error_msg    :=
                       'Error in release_so_hold Procedure '
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;
    BEGIN
        DoLog ('check_so_hold_status - Enter');
        ln_hold_count   := get_hold_count (pn_so_header_id);
        DoLog ('Hold count ' || ln_hold_count);

        IF ln_hold_count > 0 AND pb_release_hold
        THEN
            release_so_hold (pn_so_header_id, PN_USER_ID, pv_error_stat,
                             pv_error_msg);

            ln_hold_count   := get_hold_count (pn_so_header_id);
            DoLog ('Hold count after release ' || ln_hold_count);
        END IF;

        pv_error_stat   := 'S';
        RETURN ln_hold_count;
        DoLog ('check_so_hold_status - Enter');
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
            pv_error_stat   := 'U';
            pv_error_msg    :=
                   'Error in get_so_hold_status Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END;


    --Begin CCR0008134
    PROCEDURE update_reservations_for_po (pn_po_header_id IN VARCHAR2, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        CURSOR c_po_line_list IS --get reservations for Interco orders in batch where SO reserv qty not equal reservation qty
            SELECT pha.po_header_id, mr.reservation_id, (plla.quantity - plla.quantity_received - plla.quantity_cancelled) po_open_qty,
                   mr.primary_reservation_quantity, oola.ordered_quantity
              FROM po_headers_all pha, po_line_locations_all plla, mtl_reservations mr,
                   oe_order_lines_all oola
             WHERE     pha.po_header_id = plla.po_header_id
                   AND plla.line_location_id = mr.supply_source_line_id
                   AND mr.demand_source_line_id = oola.line_id
                   AND pha.po_header_id = pn_po_header_id
                   AND oola.ordered_quantity !=
                       mr.primary_reservation_quantity;

        l_rsv_old             inv_reservation_global.mtl_reservation_rec_type;
        l_rsv_new             inv_reservation_global.mtl_reservation_rec_type;
        l_msg_count           NUMBER;
        l_msg_data            VARCHAR2 (240);
        l_rsv_id              NUMBER;
        l_dummy_sn            inv_reservation_global.serial_number_tbl_type;
        l_status              VARCHAR2 (1);
        l_quantity_reserved   NUMBER;

        ln_reservation_id     NUMBER;
        ln_new_quantity       NUMBER;
    BEGIN
        FOR po_line_rec IN c_po_line_list
        LOOP
            doLog (
                ' Update reservation for reservation_id : ' || po_line_rec.reservation_id);
            dolog (
                'Current quantity : ' || po_line_rec.primary_reservation_quantity);
            dolog ('New Quantity : ' || po_line_rec.ordered_quantity);

            l_rsv_old.reservation_id   := po_line_rec.reservation_id;
            -- specify the new values
            l_rsv_new.reservation_id   := po_line_rec.reservation_id;

            l_rsv_new.primary_reservation_quantity   :=
                po_line_rec.ordered_quantity;
            l_rsv_new.reservation_quantity   :=
                po_line_rec.ordered_quantity;

            inv_reservation_pub.update_reservation (
                p_api_version_number       => 1.0,
                p_init_msg_lst             => fnd_api.g_true,
                x_return_status            => l_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_original_rsv_rec         => l_rsv_old,
                p_to_rsv_rec               => l_rsv_new,
                p_original_serial_number   => l_dummy_sn  -- no serial contorl
                                                        ,
                p_to_serial_number         => l_dummy_sn  -- no serial control
                                                        ,
                p_validation_flag          => fnd_api.g_true,
                p_check_availability       => fnd_api.g_false,
                p_over_reservation_flag    => 0);


            IF l_status != fnd_api.g_ret_sts_success
            THEN
                IF l_msg_count >= 1
                THEN
                    FOR I IN 1 .. l_msg_count
                    LOOP
                        DBMS_OUTPUT.put_line (
                               I
                            || '. '
                            || SUBSTR (FND_MSG_PUB.Get (i, 'F'), 1, 255));
                    --fnd_file.put_line(fnd_file.log,I||'. '||SUBSTR(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ),1, 255));

                    END LOOP;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    --End CCR0008134


    --Get the po type Std/DS/Interco/XDOCK for the given passed in PO line
    FUNCTION get_po_type (pv_po_number IN VARCHAR2)
        RETURN NUMBER
    IS
        --      ln_po_header_id       NUMBER;
        --     ln_po_line_id         NUMBER;
        --     ln_line_location_id   NUMBER;
        --     ln_order_cnt          NUMBER;
        --     ln_req_header_id      NUMBER;
        --     lv_drop_ship_flag     VARCHAR2 (1);
        --     lv_order_type         VARCHAR2 (20);
        --     ln_value              NUMBER;
        --     ln_cnt_dss            NUMBER;
        --     ln_cnt_mr             NUMBER;
        --     ln_cnt_attr           NUMBER;

        --     ln_cnt                NUMBER;
        lv_po_type        VARCHAR2 (20);
        ln_po_header_id   NUMBER;
        ln_cnt            NUMBER;
    BEGIN
        --Start CC0007979
        --Find sourcing type of PO
        --Possible types
        -- 'DIRECT' : US delivery or other direct PO
        --'DS': Drop ship PO
        --'INTERCO' : Intercompany PO
        --'XDOCK' : Cross dock
        --'NONP' : Non-factory procurement


        --First check for the PO

        /*        SELECT DISTINCT
                       pla.po_header_id,
                       pla.po_line_id,
                       pha.attribute10,
                       prla.requisition_header_id,
                       NVL (plla.drop_ship_flag, 'N') drop_ship_flag,
                       (SELECT COUNT (*)
                          FROM oe_drop_ship_sources dss
                         WHERE     dss.po_line_id = pla.po_line_id
                               AND dss.po_header_id = pha.po_header_id)
                          cnt_dss,
                       (SELECT COUNT (*)
                          FROM oe_order_lines_all oola,
                               mtl_reservations mr,
                               po_line_locations_all plla
                         WHERE     oola.line_id = mr.demand_source_line_id
                               AND mr.supply_source_line_id = plla.line_location_id
                               AND plla.po_line_id = pla.po_line_id)
                          cnt_mr,
                       (SELECT COUNT (*)
                          FROM oe_order_lines_all oola, po_line_locations_all plla
                         WHERE     oola.attribute16 =
                                      TO_CHAR (plla.line_location_id)
                               AND plla.po_line_id = pla.po_line_id)
                          cnt_attr
                  INTO ln_po_header_id,
                       ln_po_line_id,
                       lv_order_type,
                       ln_req_header_id,
                       lv_drop_ship_flag,
                       ln_cnt_dss,
                       ln_cnt_mr,
                       ln_cnt_attr
                  FROM apps.po_headers_all pha,
                       apps.po_lines_all pla,
                       apps.po_line_locations_all plla,
                       apps.po_requisition_lines_all prla
                 WHERE     1 = 1
                       AND pha.segment1 = pv_po_number
                       AND pla.line_num = pn_line_num
                       AND pla.po_line_id = plla.po_line_id
                       AND plla.line_location_id = prla.line_location_id(+)
                       AND pha.po_header_id = pla.po_header_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   RETURN G_PO_TYPE_ERR;
             END;

             --Check for DROP ship
             IF lv_drop_ship_flag = 'Y' AND ln_cnt_dss > 0
             THEN
                RETURN G_PO_TYPE_DS;
             END IF;

             --Check for XDOCK
             IF lv_order_type = 'XDOCK'
             THEN
                RETURN G_PO_TYPE_XDOCK;
             END IF;                                                  --Check interco

             IF ln_cnt_mr > 0 OR ln_cnt_attr > 0
             THEN
                RETURN G_PO_TYPE_INTERCO;
             END IF;


             --no conditions met: assume std PO at thnis pont
             RETURN G_PO_TYPE_DIRECT;*/

        SELECT po_header_id
          INTO ln_po_header_id
          FROM po_headers_all
         WHERE segment1 = pv_po_number;

        lv_po_type   := XXD_PO_GET_PO_TYPE (ln_po_header_id);     --CCR0007979


        CASE
            WHEN lv_po_type = 'DROP_SHIP'
            THEN
                --Begin CCR0008134
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM po_headers_all pha, oe_drop_ship_sources dss, oe_order_lines_all oola,
                       po_lines_all pla_jp
                 WHERE     pha.po_header_id = ln_po_header_id
                       AND pha.po_header_id = dss.po_header_id
                       AND dss.line_id = oola.line_id
                       AND TO_CHAR (oola.line_id) = pla_jp.attribute5;

                IF ln_cnt > 0
                THEN
                    RETURN G_PO_TYPE_JPTQ;
                END IF;

                --End CCR0008134

                RETURN G_PO_TYPE_DS;
            WHEN lv_po_type = 'XDOCK'
            THEN
                RETURN G_PO_TYPE_XDOCK;
            WHEN lv_po_type = 'INTERCO' OR lv_po_type = 'B2B'
            THEN
                RETURN G_PO_TYPE_INTERCO;
            WHEN lv_po_type = 'DIRECT_SHIP'                      ---CCR0008134
            THEN
                RETURN G_PO_TYPE_DSHIP;
            ELSE
                RETURN G_PO_TYPE_DIRECT;
        END CASE;

        --End  CC0007979

        RETURN G_PO_TYPE_DIRECT;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN G_PO_TYPE_ERR;
    END;

    PROCEDURE create_req_iface_from_stg (pn_stg_record_id IN NUMBER, pv_source_code IN VARCHAR2, pn_req_batch_id IN NUMBER
                                         , pn_line_num IN NUMBER:= NULL, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        ln_org_id                    NUMBER;
        ln_quantity                  NUMBER;
        ln_item_id                   NUMBER;
        ln_unit_price                NUMBER;
        ln_ship_to_organization_id   NUMBER;
        ln_ship_to_location_id       NUMBER;
        ln_source_organization_id    NUMBER;
        lv_req_type                  VARCHAR2 (10);
        lv_dest_type_code            VARCHAR2 (20);
        -- lv_dest_subinventory         VARCHAR2 (20) := 'FACTORY'; --TODO Do we need this?
        lv_authorization_status      VARCHAR2 (20) := 'APPROVED';
        ld_promised_date             DATE;
        ld_po_promised_date          DATE;
        ld_need_by_date              DATE;
        lv_description               VARCHAR2 (100);
        ln_preparer_id               NUMBER;
        ln_requestor_id              NUMBER;
        lv_src_type_code             VARCHAR2 (20);
        ln_vendor_id                 NUMBER;
        ln_vendor_site_id            NUMBER;
        ln_oe_line_id                NUMBER;
        ln_oe_header_id              NUMBER;
        ln_order_number              NUMBER;
        ln_from_oe_line_id           NUMBER;
        lv_ir_req_number             VARCHAR2 (20);
        ln_created_by                NUMBER;
        ln_to_person_id              NUMBER;
        ln_src_header_id             NUMBER;
        ln_src_line_id               NUMBER;
        ln_src_po_type_id            NUMBER;
        ln_po_header_id              NUMBER;
        lv_organization_code         VARCHAR2 (3);
        lv_brand                     VARCHAR2 (10);
    BEGIN
        DoLog ('create_req_iface_from_stg - Enter');

        SELECT stg.quantity, stg.unit_price, stg.item_id,
               stg.ship_to_organization_id, stg.ship_to_location_id, stg.req_type,
               stg.new_promised_date, stg.org_id, stg.oe_header_id,
               ooha.order_number, ooha.attribute5, stg.oe_line_id,
               stg.from_oe_line_id, stg.vendor_id, stg.vendor_site_id,
               stg.created_by, stg.src_po_type_id, stg.po_header_id
          INTO ln_quantity, ln_unit_price, ln_item_id, ln_ship_to_organization_id,
                          ln_ship_to_location_id, lv_req_type, ld_promised_date,
                          ln_org_id, ln_oe_header_id, ln_order_number,
                          lv_brand, ln_oe_line_id, ln_from_oe_line_id,
                          ln_vendor_id, ln_vendor_site_id, ln_created_by,
                          ln_src_po_type_id, ln_po_header_id
          FROM xxdo.xxdo_gtn_po_collab_stg stg, oe_order_headers_all ooha
         WHERE     stg.oe_header_id = ooha.header_id(+)
               AND gtn_po_collab_stg_id = pn_stg_record_id;

        DoLog ('create_req_iface_from_stg - after select');

        --TODO: does requestor/preparer vary between INT/EXT
        IF lv_req_type = 'INTERNAL'
        THEN
            DoLog ('create_req_iface_from_stg - Internal REQ');

            --Get detination org/location from IR sourcing original OE line from which this line was copied
            BEGIN
                SELECT ir.destination_organization_id, hr.location_id, ir.source_organization_id,
                       ir.org_id, ir_h.segment1 req_number, ir.created_by,
                       ir_h.preparer_id, ir.to_person_id, ir.requisition_header_id,
                       ir.requisition_line_id, ir.need_by_date, ooha.order_number,
                       ooha.attribute5
                  INTO ln_ship_to_organization_id, ln_ship_to_location_id, ln_source_organization_id, ln_org_id,
                                                 lv_ir_req_number, ln_created_by, ln_preparer_id,
                                                 ln_to_person_id, ln_src_header_id, ln_src_line_id,
                                                 ld_need_by_date, ln_order_number, lv_brand
                  FROM po_requisition_lines_all ir, po_requisition_headers_all ir_h, oe_order_lines_all oola,
                       oe_order_headers_all ooha, hr_all_organization_units hr
                 WHERE     ir.requisition_line_id =
                           oola.source_document_line_id
                       AND ir.destination_organization_id =
                           hr.organization_id
                       AND ir.requisition_header_id =
                           ir_h.requisition_header_id
                       AND oola.header_id = ooha.header_id
                       AND oola.line_id =
                           NVL (ln_from_oe_line_id, ln_oe_line_id);

                --If Stg Promised date is not passed then use promised date from sourcing JP PO Line
                ld_promised_date   := NVL (ld_promised_date, ld_need_by_date);


                DoLog ('Preparer ID : ' || ln_preparer_id);
                DoLog ('to person ID : ' || ln_to_person_id);
            --Validate IDs are still active / Otherwise set to fallback IDs

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            --Not set for INTERNAL REQ
            ln_order_number     := NULL;
            lv_brand            := NULL;

            ln_vendor_id        := NULL;
            ln_vendor_site_id   := NULL;
            lv_src_type_code    := 'INVENTORY';
        ELSIF lv_req_type = 'TQ'
        THEN
            DoLog ('create_req_iface_from_stg - Japan TQ');

            BEGIN
                SELECT plla.ship_to_organization_id, plla.ship_to_location_id, plla.promised_date,
                       NULL, pha.org_id, pha.segment1 po_number,
                       pha.created_by, NULL,                --pha.preparer_id,
                                             NULL,         --pha.to_person_id,
                       pha.po_header_id, pla.po_line_id, ooha.order_number,
                       ooha.attribute5, pha.vendor_id, pha.vendor_site_id
                  INTO ln_ship_to_organization_id, ln_ship_to_location_id, ld_po_promised_date, ln_source_organization_id,
                                                 ln_org_id, lv_ir_req_number, --po_number
                                                                              ln_created_by,
                                                 ln_preparer_id, ln_to_person_id, ln_src_header_id, --po_header_id
                                                 ln_src_line_id,  --po_line_id
                                                                 ln_order_number, lv_brand,
                                                 ln_vendor_id, ln_vendor_site_id
                  FROM po_lines_all pla, po_headers_all pha, po_line_locations_all plla,
                       oe_order_lines_all oola, oe_order_headers_all ooha, hr_all_organization_units hr
                 WHERE     pla.attribute5 = TO_CHAR (oola.line_id)
                       AND pha.po_header_id = pla.po_header_id
                       AND pla.po_line_id = plla.po_line_id
                       AND plla.ship_to_organization_id = hr.organization_id
                       AND oola.header_id = ooha.header_id
                       AND oola.line_id =
                           NVL (ln_from_oe_line_id, ln_oe_line_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            lv_src_type_code            := 'VENDOR';
            ln_source_organization_id   := NULL;

            --If Stg Promised date is not passed then use promised date from sourcing JP PO Line
            ld_promised_date            :=
                NVL (ld_promised_date, ld_po_promised_date);

            DoLog ('PO Header ID : ' || ln_po_header_id);
            DoLog ('PO Src Type : ' || ln_src_po_type_id);
            DoLog ('PO Promised Date : ' || ld_promised_date);

            BEGIN
                SELECT DISTINCT NVL (prla.to_person_id, gDefREQPreparerID), NVL (prha.preparer_id, gDefREQPreparerID) --NVL in case NUlL values exist in source PO
                  INTO ln_to_person_id, ln_preparer_id
                  FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                 WHERE     line_location_id IN
                               (SELECT line_location_id
                                  FROM oe_drop_ship_sources
                                 WHERE line_id =
                                       NVL (ln_from_oe_line_id,
                                            ln_oe_line_id))
                       AND prla.requisition_header_id =
                           prha.requisition_header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_preparer_id    := gDefREQPreparerID;
                    ln_to_person_id   := gDefREQPreparerID;
                --Added for CCR0009182
                WHEN OTHERS
                THEN
                    ln_preparer_id    := gDefREQPreparerID;
                    ln_to_person_id   := gDefREQPreparerID;
            --End for CCR0009182
            END;

            DoLog ('PO Preparer : ' || ln_preparer_id);
            DoLog ('PO Agent ID : ' || ln_to_person_id);
        --Get TQ PO data for insert into REQ IFACE
        ELSE
            DoLog ('create_req_iface_from_stg - Purchase REQ');
            lv_src_type_code            := 'VENDOR';
            ln_source_organization_id   := NULL;

            DoLog ('PO Header ID : ' || ln_po_header_id);
            DoLog ('PO Src Type : ' || ln_src_po_type_id);

            IF (ln_src_po_type_id = G_PO_TYPE_DIRECT OR ln_src_po_type_id = G_PO_TYPE_DSHIP)
            THEN
                --get PO creator and employee id from PO
                BEGIN
                    SELECT DISTINCT NVL (prla.to_person_id, gDefREQPreparerID), NVL (prha.preparer_id, gDefREQPreparerID) --NVL in case NUlL values exist in source PO
                      INTO ln_to_person_id, ln_preparer_id
                      FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                     WHERE     line_location_id IN
                                   (SELECT line_location_id
                                      FROM po_line_locations_all
                                     WHERE po_header_id = ln_po_header_id)
                           AND prla.requisition_header_id =
                               prha.requisition_header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_preparer_id    := gDefREQPreparerID;
                        ln_to_person_id   := gDefREQPreparerID;
                    --Added for CCR0009182
                    WHEN TOO_MANY_ROWS
                    THEN
                        BEGIN
                            SELECT DISTINCT NVL (prla.to_person_id, gDefREQPreparerID), NVL (prha.preparer_id, gDefREQPreparerID) --NVL in case NUlL values exist in source PO
                              INTO ln_to_person_id, ln_preparer_id
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_line_id =
                                       (SELECT MIN (prla1.requisition_line_id)
                                          FROM apps.po_requisition_lines_all prla1
                                         WHERE prla1.line_location_id IN
                                                   ((SELECT line_location_id
                                                       FROM po_line_locations_all
                                                      WHERE po_header_id =
                                                            ln_po_header_id)))
                                   AND prla.requisition_header_id =
                                       prha.requisition_header_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_preparer_id    := gDefREQPreparerID;
                                ln_to_person_id   := gDefREQPreparerID;
                            WHEN OTHERS
                            THEN
                                pv_error_msg   :=
                                       'Error in while derive the person and prepare ids for Multiple  : '
                                    || SQLERRM;
                                DoLog (
                                       'Error in while derive the person and prepare ids for Multiple: '
                                    || SQLERRM);
                        END;
                    WHEN OTHERS
                    THEN
                        pv_error_msg   :=
                               'Error in while derive the person and prepare ids : '
                            || SQLERRM;
                        DoLog (
                               'Error in while derive the person and prepare ids : '
                            || SQLERRM);
                --End for CCR0009182
                END;

                DoLog ('PO Preparer : ' || ln_preparer_id);
                DoLog ('PO Agent ID : ' || ln_to_person_id);
            END IF;
        END IF;

        DoLog ('ORDER NUMBER : ' || ln_order_number);
        DoLog ('BRAND :        ' || lv_brand);
        DoLog ('ORG CODE :     ' || lv_organization_code);


        DoLog ('create_req_iface_from_stg - Before insert');

        INSERT INTO APPS.PO_REQUISITIONS_INTERFACE_ALL (
                        BATCH_ID,
                        INTERFACE_SOURCE_CODE,
                        ORG_ID,
                        DESTINATION_TYPE_CODE,
                        AUTHORIZATION_STATUS,
                        PREPARER_ID,
                        CHARGE_ACCOUNT_ID,
                        SOURCE_TYPE_CODE,
                        SOURCE_ORGANIZATION_ID,
                        UOM_CODE,
                        LINE_TYPE_ID,
                        QUANTITY,
                        UNIT_PRICE,
                        DESTINATION_ORGANIZATION_ID,
                        DELIVER_TO_LOCATION_ID,
                        DELIVER_TO_REQUESTOR_ID,
                        ITEM_ID,
                        LINE_NUM,
                        SUGGESTED_VENDOR_ID,
                        SUGGESTED_VENDOR_SITE_ID,
                        HEADER_DESCRIPTION,
                        NEED_BY_DATE,               --DESTINATION_SUBINVENTORY
                        CREATION_DATE,
                        CREATED_BY,
                        LAST_UPDATE_DATE,
                        LAST_UPDATED_BY,
                        HEADER_ATTRIBUTE15, --Src Internal REQ ID/JP TQ PO Header ID
                        LINE_ATTRIBUTE14,                 --Stage table rec ID
                        LINE_ATTRIBUTE15, --Src Internal REQ line ID/JP TQ PO Line ID
                        LINE_ATTRIBUTE7,           --Place brand in this field
                        LINE_ATTRIBUTE8,     --Place Sales Order in this field
                        LINE_ATTRIBUTE9,
                        AUTOSOURCE_FLAG) --Place SO organization code in this field
                 VALUES (
                            pn_req_batch_id,
                            pv_source_code,
                            ln_org_id,
                            'INVENTORY',
                            lv_authorization_status,
                            ln_preparer_id,
                            (SELECT material_account
                               FROM apps.mtl_parameters
                              WHERE organization_id =
                                    ln_ship_to_organization_id), --Code Combination ID from dest Inv Org Parameters
                            lv_src_type_code,
                            ln_source_organization_id,
                            (SELECT primary_uom_code
                               FROM apps.mtl_system_items_b
                              WHERE     inventory_item_id = ln_item_id
                                    AND organization_id =
                                        ln_ship_to_organization_id),
                            1,
                            ln_quantity,
                            ln_unit_price,
                            ln_ship_to_organization_id,
                            ln_ship_to_location_id,
                            ln_to_person_id,
                            ln_item_id,
                            pn_line_num,  --seed line number to preserve order
                            ln_vendor_id,
                            ln_vendor_site_id,
                            lv_description,
                            ld_promised_date,
                            SYSDATE,
                            ln_created_by,
                            SYSDATE,                 -- , lv_dest_subinventory
                            ln_created_by,
                            ln_src_header_id,
                            pn_stg_record_id,
                            ln_src_line_id,
                            lv_brand,
                            ln_order_number,
                            lv_organization_code,
                            'P'); --Set autosource to P so that passed in vendor/vendor site is used

        DoLog ('create_req_iface_from_stg - Exit');

        pv_error_stat   := 'S';
        pv_error_msg    := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error in Procedure create_req_iface_from_stg :: ' || SQLERRM;
            DoLog (
                'Error in Procedure create_req_iface_from_stg :: ' || SQLERRM);
    END;

    --Create one or more purchase requisitions from a given internal Sales Order

    PROCEDURE Create_pr_from_iso (pn_order_number   IN     NUMBER, --ISO to process
                                  pn_user_id        IN     NUMBER := NULL, --USER ID to use for processing
                                  pv_error_stat        OUT VARCHAR2,
                                  pv_error_msg         OUT VARCHAR2,
                                  pn_request_id        OUT NUMBER) --Request ID from REQ Import
    IS
        ln_user_id             NUMBER;
        ln_org_id              NUMBER;
        ln_ship_from_org_id    NUMBER;
        ln_request_id          NUMBER;

        x_ret_stat             VARCHAR2 (1);
        x_error_text           VARCHAR2 (2000);
        ln_req_status          BOOLEAN;
        l_phase                VARCHAR2 (80);
        l_status               VARCHAR2 (80);
        l_dev_phase            VARCHAR2 (80);
        l_dev_status           VARCHAR2 (80);
        l_message              VARCHAR2 (255);
        ln_def_user_id         NUMBER;
        ln_employee_id         NUMBER;
        lv_brand               VARCHAR2 (20);
        ln_order_number        NUMBER;
        lv_organization_code   VARCHAR2 (5);

        ln_rec_count           NUMBER;
        ln_cnt                 NUMBER;

        ex_update              EXCEPTION;
    BEGIN
        DoLog ('Create_pr_from_iso - enter');

        --If user ID not passed, pull defalt user for this type of transaction
        SELECT user_id
          INTO ln_def_user_id
          FROM fnd_user
         WHERE user_name = gBatchO2F_User;

        DoLog ('Default user ID : ' || ln_def_user_id);

        --Check passed in user
        BEGIN
            SELECT employee_id
              INTO ln_employee_id
              FROM fnd_user
             WHERE user_id = pn_user_id;

            DoLog ('Emloyee ID : ' || ln_employee_id);

            IF ln_employee_id IS NULL
            THEN
                ln_user_id   := ln_def_user_id;
            ELSE
                ln_user_id   := pn_user_id;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_user_id   := ln_def_user_id;
        END;

        DoLog ('User ID : ' || ln_user_id);

        --Get SO org and organization ID
        BEGIN
            SELECT DISTINCT ooha.org_id, oola.ship_from_org_id, ooha.attribute5,
                            ooha.order_number, mp.organization_code
              INTO ln_org_id, ln_ship_from_org_id, lv_brand, ln_order_number,
                            lv_organization_code
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, po_requisition_lines_all prla,
                   mtl_parameters mp
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.order_number = pn_order_number
                   AND oola.source_document_line_id =
                       prla.requisition_line_id
                   AND prla.destination_organization_id = mp.organization_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order ' || pn_order_number || 'not found';
                dolog (pv_error_msg);                            -- CCR0006517
                RETURN;
        END;

        --Log into Deckers Order Management
        set_om_context (ln_user_id, ln_org_id, pv_error_stat,
                        pv_error_msg);

        --Run Autocreate request to push ISO lines to the requisitions interface
        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'BOM',
                program       => 'CTOACREQ',
                argument1     => pn_order_number,
                argument2     => pn_order_number,
                argument3     => '',
                argument4     => ln_ship_from_org_id,
                argument5     => ln_ship_from_org_id,
                argument6     => '');

        COMMIT;
        DoLog ('ctoareq - wait for request - Request ID :' || ln_request_id);

        ln_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => ln_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);


        DoLog ('ctoareq - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text    :=
                NVL (
                    l_message,
                       'The ctoareq request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
            pv_error_stat   := x_ret_stat;
            pv_error_msg    := x_error_text;
            dolog (pv_error_msg);                                -- CCR0006517
            RAISE ex_update;
        ELSE
            x_ret_stat   := 'S';
        END IF;


        --Find data about created requisition records so we can import only those specific records to a requisition
        BEGIN
            SELECT COUNT (*)
              INTO ln_rec_count
              FROM apps.po_requisitions_interface_all prla, oe_order_lines_all oola, oe_order_headers_all ooha
             WHERE     prla.interface_source_line_id = oola.line_id
                   AND oola.header_id = ooha.header_id
                   AND ooha.order_number = ln_order_number;

            DoLog (
                   ln_rec_count
                || ' records found with Order Number = '
                || ln_order_number);

            DoLog (
                   'Order # : '
                || ln_order_number
                || ' Brand : '
                || lv_brand
                || ' Organization ID : '
                || lv_organization_code);

            --Set the batch ID equal to the current request ID so that only therse records are considerd in REQ import
            IF ln_rec_count > 0
            THEN
                DoLog (
                       'Updating req interface records for SO # '
                    || ln_order_number);

                --Set the batch ID on the REQ interface recoreds to the request ID
                UPDATE apps.po_requisitions_interface_all
                   SET batch_id = ln_order_number, line_attribute8 = ln_order_number, line_attribute7 = lv_brand,
                       line_attribute9 = lv_organization_code, autosource_flag = 'P'
                 WHERE interface_source_line_id IN
                           (SELECT oola.line_id
                              FROM oe_order_lines_all oola, oe_order_headers_all ooha
                             WHERE     oola.header_id = ooha.header_id
                                   AND ooha.order_number = ln_order_number);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_msg   :=
                       'Error checking if REQ interface records were added '
                    || SQLERRM;
                dolog (pv_error_msg);                            -- CCR0006517
                RAISE ex_update;
        END;

        DoLog ('before req_import');
        --Run req import

        run_req_import (p_import_source => NULL, p_batch_id => ln_order_number, p_org_id => ln_org_id, --ln_org_id,
                                                                                                       p_inv_org_id => ln_ship_from_org_id, p_user_id => ln_user_id, p_status => PV_ERROR_STAT
                        , p_msg => PV_ERROR_MSG, p_request_id => ln_request_id);
        DoLog ('After req_import.');
        DoLog ('Stat :' || PV_ERROR_STAT);
        DoLog ('Msg :' || PV_ERROR_MSG);

        IF PV_ERROR_STAT = 'S' OR PV_ERROR_STAT = 'W'
        THEN
            DoLog ('Updating stage data for Purchase Req');

            --Update REQ information back to the staging table data fields
            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
               SET req_created          = 'Y',
                   req_line_id         =
                       (SELECT supply_source_line_id
                          FROM mtl_reservations mr
                         WHERE     mr.demand_source_line_id = stg.oe_line_id
                               AND mr.supply_source_type_id = 17),
                   req_header_id       =
                       (SELECT requisition_header_id
                          FROM mtl_reservations mr, apps.po_requisition_lines_all prla
                         WHERE     mr.demand_source_line_id = stg.oe_line_id
                               AND prla.requisition_line_id =
                                   mr.supply_source_line_id
                               AND mr.supply_source_type_id = 17),
                   reservation_id      =
                       (SELECT reservation_id
                          FROM mtl_reservations mr
                         WHERE     mr.demand_source_line_id = stg.oe_line_id
                               AND mr.supply_source_type_id = 17),
                   from_req_header_id   = req_header_id,
                   from_req_line_id     = req_line_id
             WHERE oe_line_id IN
                       (SELECT line_id
                          FROM oe_order_lines_all oola, oe_order_headers_all ooha
                         WHERE     oola.header_id = ooha.header_id
                               AND oola.flow_status_code =
                                   'EXTERNAL_REQ_OPEN' --<--This may not be needed
                               AND ooha.order_number = pn_order_number);
        ELSE
            --REQs were not created from REQ import
            pv_error_msg   :=
                'No requisition records were created. Check for records in po_interface_errors';
            dolog (pv_error_msg);                                -- CCR0006517
            RAISE ex_update;
        END IF;

        DoLog ('ctoareq - after wait for request -  ' || x_ret_stat);
        pv_error_stat   := x_ret_stat;
        pv_error_msg    := x_error_text;
        dolog (pv_error_msg);                                    -- CCR0006517
        pn_request_id   := ln_request_id; --REQ import request ID. ? do the generated REQ records have this value in the REQUEST_ID field?
    EXCEPTION
        WHEN ex_update
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error ' || pv_error_msg;
            dolog (
                   'ex_update exception in Procedure Create_pr_from_iso :: '
                || pv_error_msg);                                -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error ' || SQLERRM;
            pn_request_id   := -1;
            dolog (
                'Error in Procedure Create_pr_from_iso :: ' || pv_error_msg); -- CCR0006517
    END;

    --Create Purchase Requisitions from a drop ship SO

    PROCEDURE Create_pr_from_drop_ship_so (
        pn_order_number   IN     NUMBER,
        pn_user_id        IN     NUMBER := NULL,
        pv_error_stat        OUT VARCHAR2,
        pv_error_msg         OUT VARCHAR2,
        pn_request_id        OUT NUMBER)
    IS
        ln_user_id               NUMBER;
        ln_org_id                NUMBER;
        ln_ship_from_org_id      NUMBER;
        ln_request_id            NUMBER;

        x_ret_stat               VARCHAR2 (1);
        x_error_text             VARCHAR2 (2000);
        ln_req_status            BOOLEAN;
        l_phase                  VARCHAR2 (80);
        l_status                 VARCHAR2 (80);
        l_dev_phase              VARCHAR2 (80);
        l_dev_status             VARCHAR2 (80);
        l_message                VARCHAR2 (255);
        ln_hold_count            NUMBER;
        ln_header_id             NUMBER;
        p_schedule_date          DATE;
        ln_rec_count             NUMBER;
        lv_brand                 VARCHAR (5);

        ln_def_user_id           NUMBER;
        ln_employee_id           NUMBER;

        ex_update                EXCEPTION;
        ex_hold                  EXCEPTION;

        l_activity_status_code   VARCHAR2 (10);

        CURSOR c_lines (p_order_number NUMBER)
        IS
            SELECT oola.line_id
              FROM oe_order_lines_all oola, oe_order_headers_all ooha
             WHERE     oola.header_id = ooha.header_id
                   AND ooha.order_number = p_order_number
                   AND schedule_ship_date IS NULL;
    BEGIN
        DoLog ('Create_pr_from_drop_ship_so - enter');

        --If user ID not passed, pull defalt user for this type of transaction
        SELECT user_id
          INTO ln_def_user_id
          FROM fnd_user
         WHERE user_name = gBatchO2F_User;

        DoLog ('Default user ID : ' || ln_def_user_id);

        --Check pased in user
        BEGIN
            SELECT employee_id
              INTO ln_employee_id
              FROM fnd_user
             WHERE user_id = pn_user_id;

            DoLog ('Emloyee ID : ' || ln_employee_id);

            IF ln_employee_id IS NULL
            THEN
                ln_user_id   := ln_def_user_id;
            ELSE
                ln_user_id   := pn_user_id;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_user_id   := ln_def_user_id;
        END;

        DoLog ('User ID : ' || ln_user_id);

        --Find the SO org and ship from source
        BEGIN
            SELECT DISTINCT ooha.org_id, oola.ship_from_org_id, ooha.header_id,
                            ooha.attribute5
              INTO ln_org_id, ln_ship_from_org_id, ln_header_id, lv_brand
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND oola.flow_status_code != 'CANCELLED'
                   AND ooha.order_number = pn_order_number;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                DoLog ('Order has multiple orgs or ship from locations.');
                pv_error_stat   := 'E';
                pv_error_msg    :=
                    'Order has multiple orgs or ship from locations.';
                RETURN;
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order ' || pn_order_number || 'not found';
                dolog (pv_error_msg);                            -- CCR0006517
                RETURN;
        END;

        --Log into Deckers Order Management
        set_purchasing_context (ln_def_user_id, ln_org_id, pv_error_stat,
                                pv_error_msg);

        --TODO: should we validate Order Type and source inv org?

        DoLog ('running workflow background process');
        --run workflow_background_process
        run_workflow_bkg (p_user_id => ln_def_user_id, p_status => pv_error_stat, p_msg => pv_error_msg
                          , p_request_id => ln_request_id);
        DoLog ('after running workflow background process ' || pv_error_stat);


        --Log into Deckers Order Management
        set_om_context (ln_user_id, ln_org_id, pv_error_stat,
                        pv_error_msg);

        --Schedule any unscheduled lines
        BEGIN
            FOR line_rec IN c_lines (pn_order_number)
            LOOP
                DoLog ('schedule line. Line ID : ' || line_rec.line_id);
                apps.do_oe_utils.schedule_line (line_rec.line_id, NULL, p_schedule_date
                                                , 1);


                BEGIN
                    SELECT wias.ACTIVITY_STATUS
                      INTO l_activity_status_code
                      FROM wf_item_activity_statuses wias, wf_process_activities wpa
                     WHERE     wias.process_activity = wpa.instance_id
                           AND wpa.activity_name =
                               'PURCHASE RELEASE ELIGIBLE'
                           AND wias.item_type = 'OEOL'
                           AND wias.item_key = TO_CHAR (line_rec.line_id)
                           AND wias.activity_status = 'NOTIFIED';

                    DoLog (
                           'Line '
                        || line_rec.line_id
                        || ' is purchase_release eligible');
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DoLog (
                               'Line '
                            || line_rec.line_id
                            || ' is not purchase_release eligible');
                    WHEN OTHERS
                    THEN
                        NULL;
                        dolog (
                               'Error in making line '
                            || line_rec.line_id
                            || ' to purchase release eligible because of error :: '
                            || SQLERRM);
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Error occurres scheduling lines';
                dolog ('Unexpected error in scheduling lines :: ' || SQLERRM);
                RAISE ex_update;
        END;

        --Check/release any holds before continuing
        DoLog ('Before purchase release - Check SO hold status');
        --Check and release any holds
        ln_hold_count   :=
            check_so_hold_status (ln_header_id, TRUE, ln_user_id,
                                  x_ret_stat, x_error_text);


        --If hold release fails then ??
        IF x_ret_stat <> 'S'
        THEN
            x_error_text   :=
                'Error checking/releasing hold ' || x_error_text;
            dolog (x_error_text);                                -- CCR0006517
            RAISE ex_hold;
        END IF;

        IF ln_hold_count > 0
        THEN
            x_error_text   := 'Holds exist on SO';
            dolog (x_error_text);                                -- CCR0006517
            RAISE ex_hold;
        END IF;

        --run workflow_background_process one more time to catch any last updates
        run_workflow_bkg (p_user_id => ln_def_user_id, p_status => pv_error_stat, p_msg => pv_error_msg
                          , p_request_id => ln_request_id);



        DoLog ('Before Purchase Release');
        DoLog ('ORG ID : ' || ln_org_id);
        DoLog ('ORDER NUMBER : ' || pn_order_number);


        --Run OM Purchase release for the passed order
        ln_request_id   :=
            apps.fnd_request.submit_request (application   => 'ONT',
                                             program       => 'OMPREL',
                                             argument1     => ln_org_id,
                                             argument2     => pn_order_number,
                                             argument3     => pn_order_number,
                                             argument4     => '',
                                             argument5     => '',
                                             argument6     => '',
                                             argument7     => '',
                                             argument8     => '',
                                             argument9     => '',
                                             argument10    => '');

        COMMIT;
        DoLog ('omprel - wait for request - Request ID :' || ln_request_id);
        ln_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => ln_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);


        DoLog ('omprel - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text    :=
                NVL (
                    l_message,
                       'The omprel request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
            pv_error_stat   := x_ret_stat;
            pv_error_msg    := x_error_text;
            RAISE ex_update;
        ELSE
            x_ret_stat   := 'S';
        END IF;

        DoLog ('before req_import');

        --Find data about created requisition records so we can import only those specific records to a requisition.
        BEGIN
            BEGIN
                  SELECT prla.org_id, COUNT (*)
                    INTO ln_org_id, ln_rec_count
                    FROM apps.po_requisitions_interface_all prla, oe_drop_ship_sources dss, oe_order_lines_all oola,
                         oe_order_headers_all ooha
                   WHERE     prla.interface_source_line_id =
                             dss.drop_ship_source_id
                         AND dss.line_id = oola.line_id
                         AND oola.header_id = ooha.header_id
                         AND ooha.order_number = pn_order_number
                GROUP BY prla.org_id;

                DoLog (
                       ln_rec_count
                    || ' records found from DS order = '
                    || ln_request_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    DoLog ('No req interface records found');
                    ln_rec_count   := 0;
            END;

            DoLog (
                'Order # : ' || pn_order_number || ' Brand : ' || lv_brand);

            --Set the batch ID equal to the current request ID so that only therse records are considerd in REQ import
            IF ln_rec_count > 0
            THEN
                --Set the batch ID on the REQ interface recoreds to the request ID
                UPDATE apps.po_requisitions_interface_all prla
                   SET batch_id          = ln_request_id,
                       line_attribute1   = lv_brand, --Update brand of sourcing SO
                       line_attribute2   = pn_order_number, --Update order number of sourcing SO
                       line_attribute14   =
                           (SELECT gtn_po_collab_stg_id
                              FROM xxdo.xxdo_gtn_po_collab_stg stg, oe_drop_ship_sources dss
                             WHERE     stg.oe_line_id = dss.line_id
                                   AND dss.drop_ship_source_id =
                                       prla.interface_source_line_id), --Place Stage record ID into REQ line attribute14
                       autosource_flag   = 'P'
                 WHERE prla.interface_source_line_id IN
                           (SELECT drop_ship_source_id
                              FROM oe_drop_ship_sources dss, oe_order_lines_all oola, oe_order_headers_all ooha
                             WHERE     dss.line_id = oola.line_id
                                   AND oola.header_id = ooha.header_id
                                   AND ooha.order_number = pn_order_number);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_msg   :=
                       'Error checking if REQ interface records were added '
                    || SQLERRM;
                dolog (pv_error_msg);                            -- CCR0006517
                RAISE ex_update;
        END;

        --Log into Deckers Order Management
        set_purchasing_context (ln_user_id, ln_org_id, pv_error_stat,
                                pv_error_msg);

        --Run req import. Use Request ID to limit what is imported.

        run_req_import (p_import_source => 'ORDER ENTRY', p_batch_id => ln_request_id, p_org_id => ln_org_id, --ln_org_id,
                                                                                                              p_inv_org_id => ln_ship_from_org_id, p_user_id => ln_user_id, p_status => PV_ERROR_STAT
                        , p_msg => PV_ERROR_MSG, p_request_id => ln_request_id);
        DoLog ('After req_import.');
        DoLog ('Stat :' || PV_ERROR_STAT);
        DoLog ('Msg :' || PV_ERROR_MSG);

        IF PV_ERROR_STAT = 'S' OR PV_ERROR_STAT = 'W'
        THEN
            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
               SET req_created          = 'Y',
                   req_header_id        =
                       (SELECT dss.requisition_header_id
                          FROM oe_drop_ship_sources dss
                         WHERE stg.oe_line_id = dss.line_id),
                   req_line_id          =
                       (SELECT dss.requisition_line_id
                          FROM oe_drop_ship_sources dss
                         WHERE stg.oe_line_id = dss.line_id),
                   from_req_header_id   = req_header_id,
                   from_req_line_id     = req_line_id
             WHERE oe_line_id IN
                       (SELECT oola.line_id
                          FROM oe_order_lines_all oola, oe_order_headers_all ooha, oe_drop_ship_sources dss
                         WHERE     oola.header_id = ooha.header_id
                               AND oola.line_id = dss.line_id
                               AND dss.requisition_line_id IS NOT NULL
                               AND ooha.order_number = pn_order_number);
        ELSE
            dolog (
                   'Requisition Import failed with error message :: '
                || PV_ERROR_MSG);                                -- CCR0006517
            RAISE ex_update;
        END IF;

        DoLog ('omprel - after req import -  ' || x_ret_stat);
        pv_error_stat   := x_ret_stat;
        pv_error_msg    := x_error_text;
        pn_request_id   := ln_request_id;
    EXCEPTION
        WHEN ex_hold
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := x_error_text;
            DOLOG (
                   'ex_hold exception in procedure Create_pr_from_drop_ship_so :: '
                || pv_error_msg);
        WHEN ex_update
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error ' || pv_error_msg;
            DOLOG (
                   'ex_update exception in procedure Create_pr_from_drop_ship_so :: '
                || pv_error_msg);
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error ' || SQLERRM;
            DOLOG (
                   'when others exception in procedure Create_pr_from_drop_ship_so :: '
                || pv_error_msg);
            pn_request_id   := -1;
    END;


    --Create purchase reqs from US PO lines. This will create reqs for all records of this type in the staging table

    PROCEDURE Create_pr_for_us_pos (pn_batch_id IN NUMBER, pn_user_id IN NUMBER:= NULL, pv_error_stat OUT VARCHAR2
                                    , pv_error_msg OUT VARCHAR2)
    IS
        ln_user_id             NUMBER;
        ln_org_id              NUMBER;
        ln_ship_from_org_id    NUMBER;
        ln_request_id          NUMBER;

        x_ret_stat             VARCHAR2 (1);
        x_error_text           VARCHAR2 (2000);
        ln_req_status          BOOLEAN;
        l_phase                VARCHAR2 (80);
        l_status               VARCHAR2 (80);
        l_dev_phase            VARCHAR2 (80);
        l_dev_status           VARCHAR2 (80);
        l_message              VARCHAR2 (255);
        p_schedule_date        DATE;

        ln_req_imp_batch_id    NUMBER := 1;

        ln_new_req_header_id   NUMBER;

        ln_group_cnt           NUMBER;
        ln_group_qty           NUMBER;

        ln_request_id          NUMBER;
        ln_req_import_req_id   NUMBER;
        ln_batch_rec_id        NUMBER;
        ln_cnt                 NUMBER;
        ld_promised_date       DATE;                              --CCR0008134
        ln_line_num            NUMBER := 1;                       --CCR0008134
        ln_calc_transit_days   NUMBER;

        ex_update              EXCEPTION;

        CURSOR c_header IS
              SELECT DISTINCT batch_id, po_number, ship_method,
                              ex_factory_date, new_promised_date, freight_pay_party,
                              po_header_id, org_id, po_type,
                              src_po_type_id, preparer_id, ship_to_organization_id,
                              ship_to_location_id, create_req, req_type,
                              req_created, vendor_id, vendor_site_id,
                              created_by, COUNT (*) cnt_recs, SUM (quantity) total_qty,
                              oe_header_id, oe_line_id
                FROM xxdo.xxdo_gtn_po_collab_stg stg
               WHERE     create_req = 'Y'
                     AND req_created = 'N'
                     AND processing_status_code = 'RUNNING'
                     AND batch_id = pn_batch_id
            GROUP BY batch_id, po_number, ship_method,
                     ex_factory_date, new_promised_date, freight_pay_party,
                     po_header_id, org_id, po_type,
                     src_po_type_id, preparer_id, ship_to_organization_id,
                     ship_to_location_id, create_req, req_type,
                     req_created, vendor_id, vendor_site_id,
                     created_by, oe_header_id, oe_line_id;


        --gets specific records within the group
        --Updated for CCR0008134
        CURSOR c_line (n_batch_id                  NUMBER,
                       n_org_id                    NUMBER,
                       v_po_number                 VARCHAR2,
                       n_ship_to_organization_id   NUMBER,
                       d_new_promised_date         DATE,
                       d_ex_factory_date           DATE,
                       v_ship_method               VARCHAR2,
                       v_freight_pay_party         VARCHAR2)
        IS
              SELECT stg.gtn_po_collab_stg_id, stg.line_num, stg.po_line_location_id,
                     vw.style_number, vw.color_code, vw.size_sort_code
                FROM xxdo.xxdo_gtn_po_collab_stg stg, xxd_common_items_v vw
               WHERE     stg.batch_id = n_batch_id
                     AND stg.org_id = n_org_id
                     AND stg.po_number = v_po_number
                     AND stg.ship_to_organization_id =
                         n_ship_to_organization_id
                     AND NVL (stg.new_promised_date, TRUNC (SYSDATE)) =
                         NVL (d_new_promised_date, TRUNC (SYSDATE))
                     AND stg.ex_factory_date = d_ex_factory_date
                     AND stg.ship_method = v_ship_method
                     AND stg.freight_pay_party = v_freight_pay_party
                     AND stg.item_id = vw.inventory_item_id
                     AND stg.ship_to_organization_id = vw.organization_id
                     AND stg.create_req = 'Y'
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM po_requisitions_interface_all pori
                               WHERE     pori.interface_source_code =
                                         gv_source_code
                                     AND TO_CHAR (stg.gtn_po_collab_stg_id) =
                                         pori.line_attribute14) --Do not select records that are already on interface
            ORDER BY vw.style_number, vw.color_code, TO_NUMBER (vw.size_sort_code); --Sort new lines by SKU/size run
    BEGIN
        DoLog ('Create_pr_for_us_pos - Enter');

        FOR header_rec IN c_header
        LOOP
            ln_line_num   := 1;

            --Is the PO for this group a std PO
            IF header_rec.src_po_type_id = G_PO_TYPE_DIRECT --We only create PRs of this type for POs not linked to a SO (Direct procurement only)--CCR0008134
            --is_standard_po (header_rec.po_number)
            THEN
                --Get totals for validation
                ln_group_cnt          := header_rec.cnt_recs;
                ln_group_qty          := header_rec.total_qty;


                DoLog ('--Outer loop');
                DoLog ('Batch loop counter : ' || ln_req_imp_batch_id);
                DoLog ('PO Number:           ' || header_rec.po_number);
                DoLog (
                    'ST Org ID:           ' || header_rec.ship_to_organization_id);
                DoLog (
                       'Promised Date:       '
                    || TO_CHAR (header_rec.new_promised_date));
                DoLog (
                       'Ex Factory Date:       '
                    || TO_CHAR (header_rec.ex_factory_date));
                DoLog ('Ship Method:         ' || header_rec.ship_method);
                DoLog (
                    'Freight Pay Party:   ' || header_rec.freight_pay_party);

                DoLog (
                       'Group Count : '
                    || ln_group_cnt
                    || ' Group Qty : '
                    || ln_group_qty);

                --create req_interface records for this group then import the reqs
                FOR line_rec
                    IN c_line (header_rec.batch_id,
                               header_rec.org_id,
                               header_rec.po_number,
                               header_rec.ship_to_organization_id,
                               header_rec.new_promised_date,
                               header_rec.ex_factory_date,
                               header_rec.ship_method,
                               header_rec.freight_pay_party)
                LOOP
                    --insert into req interface
                    DoLog (
                        'In inner loop : Record ID : ' || line_rec.gtn_po_collab_stg_id);

                    ln_calc_transit_days   :=
                        get_pol_transit_days (header_rec.po_number,
                                              line_rec.line_num,
                                              header_rec.ship_method);

                    IF NVL (ln_calc_transit_days, 0) = 0
                    THEN
                        doLog ('Not defined transit time');
                        pv_error_msg   :=
                            'Transit time not defined for ship method';
                        RAISE ex_update;
                    END IF;


                    ---Begin CCR0008134
                    --Update promised date if it is NULL but XFDate is passed
                    --Promised date not updated but CXF date is. Get new promised date from transit matrix
                    IF     header_rec.new_promised_date IS NULL
                       AND header_rec.ex_factory_date IS NOT NULL
                    THEN
                        ld_promised_date   :=
                            header_rec.ex_factory_date + ln_calc_transit_days;
                    ELSE
                        ld_promised_date   := header_rec.new_promised_date;
                    END IF;

                    DoLog (
                           'Updated promised date : '
                        || TO_CHAR (ld_promised_date));

                    --Update stg table record for new promised date
                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                       SET new_promised_date   = ld_promised_date
                     WHERE     gtn_po_collab_stg_id =
                               line_rec.gtn_po_collab_stg_id
                           AND new_promised_date IS NULL;

                    DoLog ('Updated stg table record');
                    ---End CCR0008134

                    create_req_iface_from_stg (line_rec.gtn_po_collab_stg_id,
                                               gv_source_code,
                                               ln_req_imp_batch_id,
                                               ln_line_num,
                                               PV_ERROR_STAT,
                                               PV_ERROR_MSG);

                    DoLog ('--After create_req_iface_from_stg ');
                    DoLog ('--Error Stat : ' || PV_ERROR_STAT);
                    --carry last rec ID over to get modified values for internal req
                    --assumption : these values are the same for all elements in this group
                    ln_batch_rec_id   := line_rec.gtn_po_collab_stg_id;
                    ln_line_num       := ln_line_num + 1; --invrement req line num--CCR0008134
                END LOOP;

                --If created by user does not have EMP ID (this would be true for converted IRs) then replace with BATCH.O2F user
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM apps.fnd_user
                 WHERE     user_id = header_rec.created_by
                       AND employee_id IS NOT NULL;

                IF ln_cnt = 0
                THEN
                    SELECT user_id
                      INTO header_rec.created_by
                      FROM fnd_user
                     WHERE user_name = gBatchO2F_User;
                END IF;

                DoLog ('Before run_req_import');
                --Run req import
                run_req_import (
                    p_import_source   => gv_source_code,
                    p_batch_id        => TO_CHAR (ln_req_imp_batch_id),
                    p_org_id          => header_rec.org_id,
                    p_inv_org_id      => header_rec.ship_to_organization_id,
                    p_user_id         => header_rec.created_by,
                    p_status          => PV_ERROR_STAT,
                    p_msg             => PV_ERROR_MSG,
                    p_request_id      => ln_req_import_req_id);

                DoLog ('After run_req_import');
                DoLog ('Status : ' || PV_ERROR_STAT);
                DoLog ('Msg : ' || PV_ERROR_MSG);
                DoLog ('Request_id : ' || ln_req_import_req_id);

                IF PV_ERROR_STAT = 'E' OR PV_ERROR_STAT = 'U'
                THEN
                    RAISE ex_update;
                END IF;

                DoLog ('Get created REQ data');

                --Get the req header ID created and the count of created records
                BEGIN
                      SELECT COUNT (*), prha.requisition_header_id
                        INTO ln_cnt, ln_new_req_header_id
                        FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla
                       WHERE     prha.requisition_header_id =
                                 prla.requisition_header_id
                             AND prha.interface_source_code = gv_source_code
                             AND prha.request_id = ln_req_import_req_id
                    GROUP BY prha.requisition_header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        doLog ('Req Import did not create records');
                    --TODO : No recs created (REQ Import faied to generate a requisition)
                    -- NULL;
                    -- Start CCR0006517
                    WHEN OTHERS
                    THEN
                        dolog (
                            'Error in Fetching Req Header id :: ' || SQLERRM);
                -- End CCR0006517
                END;

                DoLog ('Update stg table flags');

                --Update status flags on stg records for created new req lines
                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                   SET req_created          = 'Y',
                       req_header_id        = ln_new_req_header_id,
                       req_line_id         =
                           (SELECT requisition_line_id
                              FROM po_requisition_lines_all prla
                             WHERE     requisition_header_id =
                                       ln_new_req_header_id
                                   AND prla.attribute14 =
                                       TO_CHAR (stg.gtn_po_collab_stg_id)),
                       from_req_header_id   = req_header_id,
                       from_req_line_id     = req_line_id
                 WHERE gtn_po_collab_stg_id IN
                           (SELECT TO_NUMBER (attribute14)
                              FROM po_requisition_lines_all prla
                             WHERE prla.request_id = ln_req_import_req_id);

                DoLog ('REQ lines created : ' || ln_cnt);

                --Increment batch loop counter
                ln_req_imp_batch_id   := ln_req_imp_batch_id + 1;
            END IF;
        END LOOP;

        pv_error_stat   := 'S';
        DoLog ('Create_pr_for_us_pos - Exit');
    EXCEPTION
        WHEN ex_update
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Update error : ' || pv_error_msg;
            dolog ('Create_pr_for_us_pos Update Error : ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
            dolog (
                   'Create_pr_for_us_pos Update Unexpected Error : '
                || pv_error_msg);                                -- CCR0006517
    END;

    --Creates a new SO line on a drop ship sales order

    PROCEDURE create_drop_ship_so_line (pn_header_id      IN     NUMBER,
                                        pn_from_line_id   IN     NUMBER,
                                        pn_new_quantity   IN     NUMBER,
                                        pn_user_id        IN     NUMBER,
                                        pd_request_date   IN     DATE,
                                        pn_new_line_id       OUT NUMBER,
                                        pv_error_stat        OUT VARCHAR2,
                                        pv_error_msg         OUT VARCHAR2)
    IS
        lv_error_msg                   VARCHAR2 (4000);
        lv_error_stat                  VARCHAR2 (1);
        ln_so_ordered_qty              NUMBER;



        l_header_rec                   apps.oe_order_pub.header_rec_type;
        l_line_tbl                     apps.oe_order_pub.line_tbl_type;
        l_action_request_tbl           apps.oe_order_pub.request_tbl_type;
        l_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               apps.oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  apps.oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := apps.fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := apps.fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := apps.fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        x_header_rec                   apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        p_old_header_rec               apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        p_header_val_rec               apps.oe_order_pub.header_val_rec_type
                                           := apps.oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           apps.oe_order_pub.header_val_rec_type
                                           := apps.oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type
                                           := apps.oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           apps.oe_order_pub.header_adj_tbl_type
                                           := apps.oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           apps.oe_order_pub.header_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       apps.oe_order_pub.header_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         apps.oe_order_pub.header_price_att_tbl_type
            := apps.oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     apps.oe_order_pub.header_price_att_tbl_type
            := apps.oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           apps.oe_order_pub.header_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       apps.oe_order_pub.header_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         apps.oe_order_pub.header_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     apps.oe_order_pub.header_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           apps.oe_order_pub.header_scredit_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       apps.oe_order_pub.header_scredit_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       apps.oe_order_pub.header_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   apps.oe_order_pub.header_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_val_tbl;
        x_line_tbl                     apps.oe_order_pub.line_tbl_type
            := apps.oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 apps.oe_order_pub.line_tbl_type
            := apps.oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 apps.oe_order_pub.line_val_tbl_type
            := apps.oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             apps.oe_order_pub.line_val_tbl_type
            := apps.oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             apps.oe_order_pub.line_adj_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             apps.oe_order_pub.line_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         apps.oe_order_pub.line_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           apps.oe_order_pub.line_price_att_tbl_type
            := apps.oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       apps.oe_order_pub.line_price_att_tbl_type
            := apps.oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             apps.oe_order_pub.line_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         apps.oe_order_pub.line_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           apps.oe_order_pub.line_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       apps.oe_order_pub.line_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         apps.oe_order_pub.line_scredit_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         apps.oe_order_pub.line_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     apps.oe_order_pub.line_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               apps.oe_order_pub.lot_serial_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           apps.oe_order_pub.lot_serial_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           apps.oe_order_pub.lot_serial_val_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       apps.oe_order_pub.lot_serial_val_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           apps.oe_order_pub.request_tbl_type
            := apps.oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               apps.oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           apps.oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         apps.oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           apps.oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         apps.oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           apps.oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       apps.oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 apps.oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             apps.oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           apps.oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             apps.oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           apps.oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         apps.oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               apps.oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           apps.oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           apps.oe_order_pub.request_tbl_type;

        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;

        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_item_id                     NUMBER;
        ln_ship_from_org_id            NUMBER;
        ln_order_source_id             NUMBER;
        lv_subinventory                VARCHAR2 (1000);
        ln_attribute1                  VARCHAR2 (1000);
        ld_promise_date                DATE;
        ld_request_date                DATE;
        ln_line_type_id                NUMBER;
        ln_salesrep_id                 NUMBER;

        ln_def_user_id                 NUMBER;
        ln_employee_id                 NUMBER;
        ln_user_id                     NUMBER;

        ex_validation                  EXCEPTION;
        ex_login                       EXCEPTION;
        ex_update                      EXCEPTION;
    BEGIN
        DoLog ('>>>create_drop_ship_so_line - Enter');
        DoLog ('Header ID : ' || pn_header_id);
        DoLog ('New Qty : ' || pn_new_quantity);

        DoLog ('User ID : ' || pn_user_id);
        DoLog ('Request Date : ' || TO_CHAR (pd_request_date, 'MM-DD-YYYY'));

        --If user ID not passed, pull defalt user for this type of transaction
        SELECT user_id
          INTO ln_def_user_id
          FROM fnd_user
         WHERE user_name = gBatchO2F_User;

        --Check pased in user
        BEGIN
            SELECT employee_id
              INTO ln_employee_id
              FROM fnd_user
             WHERE user_id = pn_user_id;

            DoLog ('Emloyee ID : ' || ln_employee_id);

            IF ln_employee_id IS NULL
            THEN
                ln_user_id   := ln_def_user_id;
            ELSE
                ln_user_id   := pn_user_id;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_user_id   := ln_def_user_id;
        END;

        --validation step
        --Validate type of SO (is a drop ship order type)
        --Validate new quantity

        SELECT org_id
          INTO ln_org_id
          FROM oe_order_lines_all
         WHERE line_id = pn_from_line_id;

        DoLog ('set OM context');
        --do OM login
        set_om_context (ln_user_id, ln_org_id, lv_error_stat,
                        lv_error_msg);

        --Get om_data
        IF lv_error_stat <> 'S'
        THEN
            DoLog ('error with login : ' || lv_error_msg);
            RAISE ex_login;
        END IF;

        BEGIN
            DoLog ('Get SO line data');


            SELECT inventory_item_id, ship_from_org_id, subinventory,
                   promise_date, request_date, line_type_id,
                   salesrep_id, attribute1, order_source_id
              INTO ln_item_id, ln_ship_from_org_id, lv_subinventory, ld_promise_date,
                             ld_request_date, ln_line_type_id, ln_salesrep_id,
                             ln_attribute1, ln_order_source_id
              FROM apps.oe_order_lines_all
             WHERE header_id = pn_header_id AND line_id = pn_from_line_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DoLog ('no order found');
                RAISE ex_validation;
        END;

        l_line_tbl_index                                     := 1;
        -- Changed attributes
        l_line_tbl (l_line_tbl_index)                        := apps.oe_order_pub.G_MISS_LINE_REC;

        IF pd_request_date IS NOT NULL
        THEN
            ld_request_date   := pd_request_date;
        END IF;


        --Mandatory fields like qty, inventory item id are to be passed
        L_line_tbl (l_line_tbl_index).header_id              := pn_header_id;
        L_line_tbl (l_line_tbl_index).ordered_quantity       := pn_new_quantity;
        L_line_tbl (l_line_tbl_index).inventory_item_id      := ln_item_id;
        L_line_tbl (l_line_tbl_index).ship_from_org_id       :=
            ln_ship_from_org_id;
        L_line_tbl (l_line_tbl_index).subinventory           := lv_subinventory;
        L_line_tbl (l_line_tbl_index).promise_date           := ld_promise_date;
        L_line_tbl (l_line_tbl_index).request_date           := ld_request_date;
        l_line_tbl (l_line_tbl_index).order_source_id        :=
            ln_order_source_id;
        --L_line_tbl(l_line_tbl_index).schedule_ship_date := ld_request_date;
        L_line_tbl (l_line_tbl_index).salesrep_id            := ln_salesrep_id;
        L_line_tbl (l_line_tbl_index).schedule_status_code   := 'SCHEDULED';
        L_line_tbl (l_line_tbl_index).attribute1             := ln_attribute1;
        L_line_tbl (l_line_tbl_index).operation              :=
            apps.oe_globals.g_opr_create;
        L_line_tbl (l_line_tbl_index).line_type_id           :=
            ln_line_type_id;
        L_line_tbl (l_line_tbl_index).source_type_code       := 'EXTERNAL';


        DoLog ('Before apps.oe_order_pub.Process_order');

        SELECT ordered_quantity
          INTO ln_so_ordered_qty
          FROM oe_order_lines_all
         WHERE line_id = pn_from_line_id;

        DoLog ('SO Ordered quantity : ' || ln_so_ordered_qty);

        -- CALL TO PROCESS ORDER
        apps.oe_order_pub.Process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => apps.fnd_api.g_false,
            p_return_values            => apps.fnd_api.g_false,
            p_action_commit            => apps.fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl -- OUT PARAMETERS
                                                              ,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => x_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => x_action_request_tbl);
        DoLog (
               'After apps.oe_order_pub.Process_order. Return status :'
            || l_return_status
            || ' Msg Cnt : '
            || l_msg_count);



        FOR i IN 1 .. l_msg_count
        LOOP
            apps.oe_msg_pub.Get (p_msg_index => i, p_encoded => apps.fnd_api.g_false, p_data => l_msg_data
                                 , p_msg_index_out => l_msg_index_out);
            DoLog ('message is: ' || l_msg_data);
            DoLog ('message index is: ' || l_msg_index_out);
        END LOOP;

        --Check the return status
        IF l_return_status != apps.fnd_api.g_ret_sts_success
        THEN
            lv_error_msg   :=
                   'Error while processing UPDATE at SO line level in Sales order Procedure '
                || l_msg_data
                || 'index: '
                || l_msg_index_out;
            RAISE ex_update;
        END IF;

        pn_new_line_id                                       :=
            x_line_tbl (l_line_tbl_index).line_id;

        DoLog ('>>>New line created - ID : ' || pn_new_line_id);

        pv_error_stat                                        := 'S';
        DoLog ('>>>create_drop_ship_so_line - Exit');
    EXCEPTION
        WHEN ex_validation
        THEN
            DoLog ('create_drop_ship_so_line : validation Exception');
            pv_error_msg    := lv_error_msg;
            pv_error_stat   := 'E';
        WHEN ex_login
        THEN
            pv_error_msg    := 'Login error: ' || lv_error_msg;
            pv_error_stat   := 'E';
            DoLog ('create_drop_ship_so_line : Login Error ' || pv_error_msg);
        WHEN ex_update
        THEN
            pv_error_msg    := 'Update error : ' || lv_error_msg;
            DoLog (lv_error_msg);
            pv_error_stat   := 'E';
            DoLog (
                'create_drop_ship_so_line : Update Error ' || pv_error_msg);
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
            DoLog (
                   'create_drop_ship_so_line : Unexpected Error '
                || pv_error_msg);
    END;

    --Update an existing sales order line

    PROCEDURE update_so_line (pn_header_id IN NUMBER, pn_line_id IN NUMBER, pn_new_quantity IN NUMBER, pn_user_id IN NUMBER, pd_request_date DATE, pv_error_stat OUT VARCHAR2
                              , pv_error_msg OUT VARCHAR2)
    IS
        lv_error_msg                   VARCHAR2 (4000) := NULL;
        lv_error_stat                  VARCHAR2 (1);
        ln_so_ordered_qty              NUMBER;



        l_header_rec                   apps.oe_order_pub.header_rec_type;
        l_line_tbl                     apps.oe_order_pub.line_tbl_type;
        l_action_request_tbl           apps.oe_order_pub.request_tbl_type;
        l_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               apps.oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  apps.oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := apps.fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := apps.fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := apps.fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        lv_open_flag                   VARCHAR2 (1);

        p_header_rec                   apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        x_header_rec                   apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        p_old_header_rec               apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        p_header_val_rec               apps.oe_order_pub.header_val_rec_type
                                           := apps.oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           apps.oe_order_pub.header_val_rec_type
                                           := apps.oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type
                                           := apps.oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           apps.oe_order_pub.header_adj_tbl_type
                                           := apps.oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           apps.oe_order_pub.header_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       apps.oe_order_pub.header_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         apps.oe_order_pub.header_price_att_tbl_type
            := apps.oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     apps.oe_order_pub.header_price_att_tbl_type
            := apps.oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           apps.oe_order_pub.header_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       apps.oe_order_pub.header_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         apps.oe_order_pub.header_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     apps.oe_order_pub.header_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           apps.oe_order_pub.header_scredit_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       apps.oe_order_pub.header_scredit_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       apps.oe_order_pub.header_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   apps.oe_order_pub.header_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_val_tbl;
        x_line_tbl                     apps.oe_order_pub.line_tbl_type
            := apps.oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 apps.oe_order_pub.line_tbl_type
            := apps.oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 apps.oe_order_pub.line_val_tbl_type
            := apps.oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             apps.oe_order_pub.line_val_tbl_type
            := apps.oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             apps.oe_order_pub.line_adj_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             apps.oe_order_pub.line_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         apps.oe_order_pub.line_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           apps.oe_order_pub.line_price_att_tbl_type
            := apps.oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       apps.oe_order_pub.line_price_att_tbl_type
            := apps.oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             apps.oe_order_pub.line_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         apps.oe_order_pub.line_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           apps.oe_order_pub.line_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       apps.oe_order_pub.line_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         apps.oe_order_pub.line_scredit_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         apps.oe_order_pub.line_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     apps.oe_order_pub.line_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               apps.oe_order_pub.lot_serial_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           apps.oe_order_pub.lot_serial_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           apps.oe_order_pub.lot_serial_val_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       apps.oe_order_pub.lot_serial_val_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           apps.oe_order_pub.request_tbl_type
            := apps.oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               apps.oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           apps.oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         apps.oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           apps.oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         apps.oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           apps.oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       apps.oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 apps.oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             apps.oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           apps.oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             apps.oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           apps.oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         apps.oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               apps.oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           apps.oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           apps.oe_order_pub.request_tbl_type;

        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;

        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_item_id                     NUMBER;
        ln_ship_from_org_id            NUMBER;
        lv_subinventory                VARCHAR2 (1000);
        ln_attribute1                  VARCHAR2 (1000);
        ld_promise_date                DATE;
        ld_request_date                DATE;
        ln_line_type_id                NUMBER;
        ln_salesrep_id                 NUMBER;

        ln_def_user_id                 NUMBER;
        ln_employee_id                 NUMBER;
        ln_user_id                     NUMBER;

        ex_validation                  EXCEPTION;
        ex_login                       EXCEPTION;
        ex_update                      EXCEPTION;
    BEGIN
        DoLog ('update_so_line - Enter');
        DoLog ('Header ID : ' || pn_header_id);
        DoLog ('Line ID :   ' || pn_line_id);
        DoLog ('New Qty : ' || pn_new_quantity);
        DoLog ('User ID : ' || pn_user_id);

        --validation step
        --Validate type of SO (is a drop ship order type)
        --Validate new quantity
        BEGIN
            SELECT org_id, open_flag
              INTO ln_org_id, lv_open_flag
              FROM oe_order_lines_all
             WHERE line_id = pn_line_id;

            IF lv_open_flag = 'N'
            THEN
                pv_error_stat   := 'E';
                lv_error_msg    :=
                       'Order line - Line ID : '
                    || pn_line_id
                    || ' is closed/cancelled';
                dolog (lv_error_msg);                            -- CCR0006517
                RAISE ex_validation;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                lv_error_msg    :=
                    'Order line - Line ID : ' || pn_line_id || ' not found';
                dolog (lv_error_msg);                            -- CCR0006517
                RAISE ex_validation;
        END;

        --If user ID not passed, pull defalt user for this type of transaction
        SELECT user_id
          INTO ln_def_user_id
          FROM fnd_user
         WHERE user_name = gBatchO2F_User;

        --Check pased in user
        --Commented Start CCR0007252
        /*BEGIN
           SELECT employee_id
             INTO ln_employee_id
             FROM fnd_user
            WHERE user_id = pn_user_id;

           DoLog ('Emloyee ID : ' || ln_employee_id);

           IF ln_employee_id IS NULL
           THEN
              ln_user_id := ln_def_user_id;
           ELSE
              ln_user_id := pn_user_id;
           END IF;
        EXCEPTION
           WHEN NO_DATA_FOUND
           THEN
              ln_user_id := ln_def_user_id;
        END;*/
        --Commented End CCR0007252

        DoLog ('set OM context');
        --do OM login
        set_om_context (pn_user_id,  -- Commented ln_user_id, Added pn_user_id
                                    ln_org_id, lv_error_stat,
                        lv_error_msg);

        --Get om_data
        IF lv_error_stat <> 'S'
        THEN
            DoLog ('error with login : ' || lv_error_msg);
            RAISE ex_login;
        END IF;

        BEGIN
            DoLog ('Get SO line data');


            SELECT inventory_item_id, ship_from_org_id, subinventory,
                   promise_date, request_date, line_type_id,
                   salesrep_id, attribute1
              INTO ln_item_id, ln_ship_from_org_id, lv_subinventory, ld_promise_date,
                             ld_request_date, ln_line_type_id, ln_salesrep_id,
                             ln_attribute1
              FROM apps.oe_order_lines_all
             WHERE header_id = pn_header_id AND line_id = pn_line_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DoLog ('no order found');
                lv_error_msg   := 'no order found';
                RAISE ex_validation;
        END;

        l_line_tbl_index                                     := 1;
        -- Changed attributes
        l_line_tbl (l_line_tbl_index)                        := apps.oe_order_pub.G_MISS_LINE_REC;

        IF pd_request_date IS NOT NULL
        THEN
            ld_request_date                              := pd_request_date;
            l_line_tbl (l_line_tbl_index).request_date   := ld_request_date; -- Added CCR0006517
        END IF;

        --set fields for process
        --Mandatory fields like qty, inventory item id are to be passed
        l_line_tbl (l_line_tbl_index).ordered_quantity       := pn_new_quantity;
        l_line_tbl (l_line_tbl_index).line_id                := pn_line_id;
        l_line_tbl (l_line_tbl_index).header_id              := pn_header_id;
        l_line_tbl (l_line_tbl_index).org_id                 := ln_org_id;
        l_line_tbl (l_line_tbl_index).change_reason          := 'SYSTEM';
        -- l_line_tbl(l_line_tbl_index).promise_date := pd_request_date;
        l_line_tbl (l_line_tbl_index).request_date           := ld_request_date;
        --L_line_tbl(l_line_tbl_index).schedule_ship_date := ld_request_date;
        --L_line_tbl(l_line_tbl_index).schedule_status_code := 'SCHEDULED';
        L_line_tbl (l_line_tbl_index).schedule_action_code   :=
            apps.OE_GLOBALS.G_SCHEDULE_LINE;
        l_line_tbl (l_line_tbl_index).operation              :=
            apps.OE_GLOBALS.G_OPR_UPDATE;

        DoLog ('Before apps.oe_order_pub.Process_order');

        SELECT ordered_quantity
          INTO ln_so_ordered_qty
          FROM oe_order_lines_all
         WHERE line_id = pn_line_id;

        DoLog ('SO Ordered quantity : ' || ln_so_ordered_qty);

        apps.oe_order_pub.Process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => apps.fnd_api.g_false,
            p_return_values            => apps.fnd_api.g_false,
            p_action_commit            => apps.fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl -- OUT PARAMETERS
                                                              ,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => x_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => x_action_request_tbl);

        DoLog (
               'After apps.oe_order_pub.Process_order. Return status :'
            || l_return_status
            || ' record count : '
            || l_msg_count);

        FOR i IN 1 .. l_msg_count
        LOOP
            apps.oe_msg_pub.Get (p_msg_index => i, p_encoded => apps.fnd_api.g_false, p_data => l_msg_data
                                 , p_msg_index_out => l_msg_index_out);
            DoLog ('message is: ' || l_msg_data);
            DoLog ('message index is: ' || l_msg_index_out);
        END LOOP;

        --Check the return status
        IF l_return_status != apps.fnd_api.g_ret_sts_success
        THEN
            lv_error_msg   :=
                   'Error while processing UPDATE at SO line level in Sales order Procedure'
                || l_msg_data
                || 'index: '
                || l_msg_index_out;
            dolog (lv_error_msg);                                -- CCR0006517
            RAISE ex_update;
        END IF;

        pv_error_stat                                        := 'S';
        DoLog ('update_drop_ship_so_line - Exit');
    EXCEPTION
        WHEN ex_validation
        THEN
            DoLog ('update_so_line : validation Exception' || lv_error_msg);
            pv_error_msg    := lv_error_msg;
            pv_error_stat   := 'E';
        WHEN ex_login
        THEN
            pv_error_msg    := 'Login error: ' || lv_error_msg;
            pv_error_stat   := 'E';
            DoLog ('update_so_line : ' || pv_error_msg);
        WHEN ex_update
        THEN
            pv_error_msg    := 'Update error : ' || lv_error_msg;
            DoLog ('update_so_line ex_update :: ' || pv_error_msg);
            pv_error_stat   := 'E';
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            dolog ('Update SO Line Unexpected Error :: ' || SQLERRM); -- CCR0006517
    END;

    --Cancel a sales order line

    PROCEDURE cancel_so_line (pn_line_id       IN     NUMBER,
                              pn_user_id       IN     NUMBER,
                              pv_reason_code   IN     VARCHAR2,
                              pv_error_stat       OUT VARCHAR2,
                              pv_error_msg        OUT VARCHAR2)
    IS
        p_header_rec              apps.oe_order_pub.header_rec_type;
        p_line_tbl                apps.oe_order_pub.line_tbl_type;
        p_price_adj_tbl           apps.oe_order_pub.line_adj_tbl_type;
        x_header_rec              apps.oe_order_pub.header_rec_type;
        x_header_adj_tbl          apps.oe_order_pub.header_adj_tbl_type;
        x_line_tbl                apps.oe_order_pub.line_tbl_type;
        x_line_adj_tbl            apps.oe_order_pub.line_adj_tbl_type;
        lv_cancel_reason          VARCHAR2 (100) := 'SYSTEM';

        ln_header_id              NUMBER;
        ln_org_id                 NUMBER;
        ln_user_id                NUMBER;

        ex_missing_order_number   EXCEPTION;
        ex_no_lines               EXCEPTION;
        ex_login                  EXCEPTION;
    BEGIN
        lv_cancel_reason                                 := NVL (pv_reason_code, lv_cancel_reason);

        BEGIN
            SELECT header_id, org_id, created_by
              INTO ln_header_id, ln_org_id, ln_user_id
              FROM apps.oe_order_lines_all
             WHERE line_id = pn_line_id AND open_flag = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DOLOG ('Could Not Find Order Line Information'); -- CCR0006517
                RAISE ex_missing_order_number;
        END;

        --Log into Deckers Order Management
        set_om_context (pn_user_id, ln_ORG_ID, PV_ERROR_STAT,
                        PV_ERROR_MSG);

        IF PV_ERROR_STAT <> 'S'
        THEN
            RAISE ex_login;
        END IF;


        DoLog ('Working on HEADER_ID: ' || ln_header_id);
        p_header_rec                                     := apps.OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_rec.operation                           := apps.OE_GLOBALS.G_OPR_UPDATE;
        p_header_rec.header_id                           := ln_header_id;
        --p_header_rec.payment_term_id := 1019;



        DoLog ('Working on LINE_ID: ' || pn_line_id);
        p_line_tbl (p_line_tbl.COUNT + 1)                :=
            apps.OE_ORDER_PUB.G_MISS_LINE_REC;
        p_line_tbl (p_line_tbl.COUNT).operation          :=
            apps.OE_GLOBALS.G_OPR_UPDATE;

        p_line_tbl (p_line_tbl.COUNT).header_id          := ln_header_id;
        p_line_tbl (p_line_tbl.COUNT).line_id            := pn_line_id;
        p_line_tbl (p_line_tbl.COUNT).ordered_quantity   := 0;
        p_line_tbl (p_line_tbl.COUNT).attribute15        := 'C';
        p_line_tbl (p_line_tbl.COUNT).attribute16        := ''; --Clear out the Attribute16 flag for ISO orders
        p_line_tbl (p_line_tbl.COUNT).change_reason      := lv_cancel_reason;
        DoLog (p_line_tbl (p_line_tbl.COUNT).change_reason);

        apps.DO_OE_UTILS.CALL_PROCESS_ORDER (
            p_header_rec       => p_header_rec,
            p_line_tbl         => p_line_tbl,
            x_header_rec       => x_header_rec,
            x_header_adj_tbl   => x_header_adj_tbl,
            x_line_tbl         => x_line_tbl,
            x_line_adj_tbl     => x_line_adj_tbl,
            x_return_status    => pv_error_stat,
            x_error_text       => pv_error_msg,
            p_do_commit        => 0);

        --
        IF NVL (pv_error_stat, 'U') != 'S'
        THEN
            DoLog ('  Error (' || NVL (pv_error_stat, 'U') || ').');
        ELSE
            DoLog ('  Success.');
        END IF;

        --
        DoLog ('  Warnings/Errors: ' || NVL (pv_error_msg, 'None'));
        pv_error_stat                                    := 'S';
        pv_error_msg                                     := '';
    --
    --rollback;
    EXCEPTION
        WHEN ex_no_lines
        THEN
            DoLog ('cancel_so_line :: There are no lines to change.');
        WHEN ex_missing_order_number
        THEN
            DoLog ('cancel_so_line procedure :: Missing Order #.');
        WHEN ex_login
        THEN
            DoLog ('cancel_so_line procedure :: Error setting OM context.');
        WHEN OTHERS
        THEN
            DoLog (
                'Global Exception in procedure cancel_so_line : ' || SQLERRM);
            ROLLBACK;
    END;


    --Cancel a specific requisition line

    FUNCTION cancel_requisition_line (pn_requisition_header_id   IN NUMBER,
                                      pn_requisition_line_id     IN NUMBER)
        RETURN VARCHAR2
    IS
        l_api_version   CONSTANT NUMBER := 1.0;
        x_return_status          VARCHAR2 (2000);
        x_msg_count              NUMBER;
        x_msg_data               VARCHAR2 (2000);
        lv_header_id             po_tbl_number;
        lv_line_id               po_tbl_number;
    BEGIN
        DoLog ('cancel_requisition_line - enter');
        DoLog ('req_line_id : ' || pn_requisition_line_id);
        lv_header_id   := po_tbl_number (pn_requisition_header_id);
        lv_line_id     := po_tbl_number (pn_requisition_line_id);
        --Call the private procedure to cancel requisition
        apps.PO_REQ_DOCUMENT_CANCEL_PVT.cancel_requisition (
            p_api_version     => l_api_version,
            p_req_header_id   => lv_header_id,
            p_req_line_id     => lv_line_id,
            p_cancel_date     => SYSDATE,
            p_source          => 'SYSADMIN',
            p_cancel_reason   => 'CANCEL FOR SPLIT',
            x_return_status   => x_return_status,
            x_msg_count       => x_msg_count,
            x_msg_data        => x_msg_data);

        IF x_return_status <> FND_API.G_RET_STS_SUCCESS
        THEN
            RETURN 'E';
        END IF;

        RETURN 'S';
        DoLog ('cancel_requisition_line - exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            DoLog (
                   ' Cancel Requisition Line Procedure failed with error : '
                || SQLERRM);
            RETURN 'U';
    END;

    --Close a PO line. All shipments on this line will be close

    PROCEDURE close_po_line (pv_po_number    IN     VARCHAR2,
                             pn_line_num     IN     NUMBER,
                             --pn_shipment_num   IN     NUMBER,
                             pn_user_id      IN     NUMBER,
                             pv_error_stat      OUT VARCHAR2,
                             pv_error_msg       OUT VARCHAR2)
    IS
        lv_doc_type        PO_DOCUMENT_TYPES.document_type_code%TYPE := 'PO';
        lv_doc_subtype     PO_DOCUMENT_TYPES.document_subtype%TYPE
                               := 'STANDARD';
        lv_return_status   VARCHAR2 (1);
        ln_po_header_id    NUMBER;
        ln_po_line_id      NUMBER;
        ln_line_loc_id     NUMBER := NULL;
        ld_action_date     DATE := TRUNC (SYSDATE);
        ln_org_id          NUMBER;
        lv_error_stat      VARCHAR2 (1);
        lv_error_msg       VARCHAR2 (4000);
        ln_resp_id         NUMBER;
        ln_resp_appl_id    NUMBER;
        ln_user_id         NUMBER;

        ln_cnt             NUMBER;
        l_result           BOOLEAN;

        CURSOR cur_ship IS
            SELECT line_location_id, closed_code
              FROM po_line_locations_all plla
             WHERE po_line_id = ln_po_line_id;

        ex_validation      EXCEPTION;
        ex_warning         EXCEPTION;
        ex_login           EXCEPTION;
        ex_update          EXCEPTION;

        ex_no_action       EXCEPTION;
    BEGIN
        --validation
        DoLog ('close_po_line - Enter');

        --Check if the line provided is already closed
        SELECT COUNT (*)
          INTO ln_cnt
          FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla
         WHERE     pha.po_header_id = pla.po_header_id
               AND pla.po_line_id = plla.po_line_id
               AND pla.line_num = pn_line_num
               AND pha.segment1 = pv_po_number
               AND pla.closed_code IN ('CLOSED', 'FINALLY CLOSED');

        DoLog ('cnt closed lines : ' || ln_cnt);

        IF ln_cnt > 0
        THEN
            --This line is already closed
            dolog ('This PO line is already closed');            -- CCR0006517
            RAISE ex_no_action;
        END IF;

        -- Set Org Context
        BEGIN
            SELECT DISTINCT pha.org_id, pha.po_header_id, pla.po_line_id
              INTO ln_org_id, ln_po_header_id, ln_po_line_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_msg   := 'po line not found';
                dolog (lv_error_msg);                            -- CCR0006517
                --Set to warning as there is no real issue in attempting to cancel a PO line that does not exist.
                RAISE ex_warning;
        END;


        DoLog ('before set_purchasing_context');
        set_purchasing_context (pn_user_id, ln_org_id, lv_error_stat,
                                lv_error_msg);
        DoLog ('after set_purchasing_context. Result :' || lv_error_stat);

        IF lv_error_stat <> 'S'
        THEN
            RAISE ex_login;
        END IF;

        DoLog ('before close PO API');

        FOR l_rec IN cur_ship
        LOOP
            l_result   :=
                PO_ACTIONS.CLOSE_PO (P_DOCID          => ln_po_header_id,
                                     P_DOCTYP         => 'PO',
                                     P_DOCSUBTYP      => 'STANDARD',
                                     P_LINEID         => ln_po_line_id,
                                     P_SHIPID         => l_rec.line_location_id,
                                     P_ACTION         => 'CLOSE',
                                     P_REASON         => 'Cancel Rebook',
                                     P_CALLING_MODE   => 'PO',
                                     P_CONC_FLAG      => 'N',
                                     P_RETURN_CODE    => lv_return_status,
                                     P_AUTO_CLOSE     => 'Y' --P_ACTION_DATE => SYSDATE
                                                            --P_ORIGIN_DOC_ID => NULL
                                                            );


            DoLog ('API returned status ;' || lv_return_status);

            IF l_result = FALSE
            THEN
                DoLog ('Exception ex_update raised');
                RAISE ex_update;
            END IF;
        END LOOP;

        BEGIN
            DoLog ('Update attribute 11 and 13');

            UPDATE apps.po_lines_all                   -- POC Negotiation flag
               SET attribute13 = 'True', last_update_date = SYSDATE -- Added for CCR0006035
             WHERE     line_num = pn_line_num
                   AND po_header_id = (SELECT po_header_id
                                         FROM apps.po_headers_all
                                        WHERE segment1 = pv_po_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_msg   :=
                    'Error while updating POC Negotiation flag in update po line proc';
        END;

        DoLog ('close_po_line - Exit');
        pv_error_msg    := '';
        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_validation
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Validation error : ' || lv_error_msg;
            dolog ('Close PO Line ex_validation :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_login
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_error_msg;
            dolog ('Close PO Line ex_login :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_update
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_error_msg;
            dolog ('Close PO Line ex_update :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_warning
        THEN
            pv_error_stat   := 'W';
            pv_error_msg    := lv_error_msg;
            dolog ('Close PO Line ex_warning :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_no_action
        THEN
            pv_error_stat   := 'S';
            pv_error_msg    := 'PO line already closed';
            dolog ('Close PO Line ex_no_action :: ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
            dolog ('Close PO Line :: ' || pv_error_msg);         -- CCR0006517
    END;

    --Cancel a PO line. All shipments on this line will be cancelled

    PROCEDURE cancel_po_line (pv_po_number    IN     VARCHAR2,
                              pn_line_num     IN     NUMBER,
                              --pn_shipment_num   IN     NUMBER,
                              pn_user_id      IN     NUMBER,
                              pv_error_stat      OUT VARCHAR2,
                              pv_error_msg       OUT VARCHAR2)
    IS
        lv_doc_type        PO_DOCUMENT_TYPES.document_type_code%TYPE := 'PO';
        lv_doc_subtype     PO_DOCUMENT_TYPES.document_subtype%TYPE
                               := 'STANDARD';
        lv_return_status   VARCHAR2 (1);
        ln_po_header_id    NUMBER;
        ln_po_line_id      NUMBER;
        ln_line_loc_id     NUMBER := NULL;
        ld_action_date     DATE := TRUNC (SYSDATE);
        ln_org_id          NUMBER;
        lv_error_stat      VARCHAR2 (1);
        lv_error_msg       VARCHAR2 (1);
        ln_resp_id         NUMBER;
        ln_resp_appl_id    NUMBER;
        ln_user_id         NUMBER;

        ln_cnt             NUMBER;

        ex_validation      EXCEPTION;
        ex_warning         EXCEPTION;
        ex_login           EXCEPTION;
        ex_update          EXCEPTION;

        ex_no_action       EXCEPTION;
    BEGIN
        --validation
        DoLog ('cancel_po_line - Enter');

        --Check if the line provided is already cancelled
        SELECT COUNT (*)
          INTO ln_cnt
          FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla
         WHERE     pha.po_header_id = pla.po_header_id
               AND pla.po_line_id = plla.po_line_id
               AND pla.line_num = pn_line_num
               AND pha.segment1 = pv_po_number
               AND NVL (pla.cancel_flag, 'N') = 'Y';

        IF ln_cnt > 0
        THEN
            --This line is already cancelled
            DOLOG ('PO Line is Already Cancelled. Hence cannot be processed'); -- CCR0006517
            RAISE ex_no_action;
        END IF;

        -- Set Org Context
        BEGIN
            SELECT DISTINCT pha.org_id, pha.po_header_id, pla.po_line_id
              INTO ln_org_id, ln_po_header_id, ln_po_line_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_msg   := 'po line not found';
                DOLOG (lv_error_msg);                            -- CCR0006517
                --Set to warning as there is no real issue in attempting to cancel a PO line that does not exist.
                RAISE ex_warning;
        END;

        BEGIN
            DoLog ('before set_purchasing_context');
            set_purchasing_context (pn_user_id, ln_org_id, lv_error_stat,
                                    lv_error_msg);
            DoLog ('after set_purchasing_context. Result :' || lv_error_stat);

            IF lv_error_stat <> 'S'
            THEN
                RAISE ex_login;
            END IF;

            DoLog ('before cancel PO API');
            PO_DOCUMENT_CONTROL_PUB.CONTROL_DOCUMENT (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, x_return_status => lv_return_status, p_doc_type => lv_doc_type, p_doc_subtype => lv_doc_subtype, p_doc_id => ln_po_header_id, p_doc_num => NULL, p_release_id => NULL, p_release_num => NULL, p_doc_line_id => ln_po_line_id, p_doc_line_num => NULL, p_doc_line_loc_id => ln_line_loc_id, p_doc_shipment_num => NULL, p_action => 'CANCEL', p_action_date => ld_action_date, p_cancel_reason => NULL, p_cancel_reqs_flag => 'Y', p_print_flag => NULL, p_note_to_vendor => NULL, p_use_gldate => NULL
                                                      , p_org_id => ln_org_id);
        END;

        DoLog ('API returned status ;' || lv_return_status);

        IF lv_return_status <> 'S'
        THEN
            RAISE ex_update;
        END IF;

        DoLog ('cancel_po_line - Exit');
        pv_error_msg    := '';
        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_validation
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Validation error : ' || lv_error_msg;
            dolog ('cancel_po_line ex_validation :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_login
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_error_msg;
            dolog ('cancel_po_line ex_login :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_update
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_error_msg;
            dolog ('cancel_po_line ex_update :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_warning
        THEN
            pv_error_stat   := 'W';
            pv_error_msg    := lv_error_msg;
            dolog ('cancel_po_line ex_warning :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_no_action
        THEN
            pv_error_stat   := 'S';
            pv_error_msg    := 'PO line already cancelled';
            dolog ('cancel_po_line ex_no_action :: ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
            dolog ('cancel_po_line :: ' || pv_error_msg);        -- CCR0006517
    END;

    -- Start CCR0006285 DS Changes

    PROCEDURE update_po_line_ds (pv_po_number IN VARCHAR2, pn_line_num IN NUMBER, pn_shipment_num IN NUMBER:= NULL, pn_quantity IN NUMBER:= NULL, pn_unit_price IN NUMBER:= NULL, pd_promised_date IN DATE:= NULL, pv_ship_method IN VARCHAR:= NULL, pv_freight_pay_party IN VARCHAR:= NULL, pd_cxf_date IN DATE:= NULL, pv_supplier_site_code IN VARCHAR2:= NULL, --CCR0008134
                                                                                                                                                                                                                                                                                                                                                                   pn_user_id IN NUMBER, pv_error_stat OUT VARCHAR2
                                 , pv_error_msg OUT VARCHAR2)
    IS
        ln_org_id                 NUMBER;
        ln_line_location_id       NUMBER;
        ln_resp_id                NUMBER;
        ln_app_id                 NUMBER;
        pv_msg                    VARCHAR2 (2000);
        pv_stat                   VARCHAR2 (1);

        ln_po_header_id           NUMBER;
        ln_po_line_id             NUMBER;
        ln_line_location          NUMBER;
        lv_cancel_flag            VARCHAR2 (1);
        lv_closed_code            VARCHAR2 (25);
        ln_created_by             NUMBER;
        ln_quantity               NUMBER;
        lv_authorization_status   VARCHAR2 (25);
        ld_promised_date          DATE;
        ln_shipment_num           NUMBER;
        ln_revision_num           NUMBER;
        ln_result                 NUMBER;
        ln_unit_price             NUMBER;
        ln_orig_unit_price        NUMBER;
        ln_shipment_cnt           NUMBER;
        lv_drop_ship_flag         VARCHAR2 (1);

        ln_header_id              NUMBER;
        ln_line_id                NUMBER;
        lb_run_po_update          BOOLEAN := FALSE;
        lb_po_update_flag         BOOLEAN := FALSE;

        l_api_errors              apps.po_api_errors_rec_type;

        ex_validation             EXCEPTION;
        ex_login                  EXCEPTION;
        ex_update                 EXCEPTION;
        ln_original_line_qty      NUMBER;                         --CCR0009609
        ln_attribute15            NUMBER;                         --CCR0009609
    BEGIN
        pv_msg             := NULL;                -- Added for CCR CCR0006035
        DoLog ('update_po_line_ds : Enter');
        DoLog (
               ' PO Number : '
            || pv_po_number
            || ' Line_num : '
            || pn_line_num
            || ' Shipment_num : '
            || pn_shipment_num
            || ' New Promosed Date : '
            || TO_CHAR (pd_promised_date));

        --Validation segment
        --Qty must be greater than 0 and an integer
        IF pn_quantity <= 0 OR pn_quantity != TRUNC (pn_quantity)
        THEN
            pv_msg   := TO_CHAR (pn_quantity) || ' is not a valid quantity';
            DOLOG (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --Unit Price must be greater than 0 --TODO: validate against currency settings
        IF pn_unit_price < 0
        THEN
            pv_msg   := TO_CHAR (pn_unit_price) || ' is not a valid price';
            DOLOG (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        IF NVL (TRUNC (pd_promised_date), TRUNC (SYSDATE)) < TRUNC (SYSDATE)
        THEN
            pv_msg   := 'New promised date cannot be in the past';
            dolog (pv_msg);
            RAISE ex_validation;
        END IF;


        BEGIN
            --Get po data for additional validation
            --ASSUMPTION : A PO_LINE will only have 1 SHIPMENT record
            --Getting MAX of the promised date on the shipments should return only 1 valid value
            SELECT pha.org_id,
                   pha.po_header_id,
                   pla.po_line_id,
                   pla.cancel_flag,
                   pla.closed_code,
                   pla.created_by,
                   pla.quantity,
                   pha.authorization_status,
                   (SELECT MAX (promised_date)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       promised_date,
                   (SELECT MAX (shipment_num)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       shipment_num,
                   pha.revision_num,
                   pla.unit_price,
                   (SELECT COUNT (*)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       shipment_cnt,
                   (SELECT DECODE (MIN (NVL (drop_ship_flag, 'N')), MAX (NVL (drop_ship_flag, 'N')), MIN (NVL (drop_ship_flag, 'N')), 'Y')
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       drop_ship_flag
              INTO ln_org_id, ln_po_header_id, ln_po_line_id, lv_cancel_flag,
                            lv_closed_code, ln_created_by, ln_quantity,
                            lv_authorization_status, ld_promised_date, ln_shipment_num,
                            ln_revision_num, ln_unit_price, ln_shipment_cnt,
                            lv_drop_ship_flag
              FROM po_headers_all pha, po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_msg   := 'PO shipment record not found';
                DOLOG (pv_msg);                                  -- CCR0006517
                RAISE ex_validation;
        END;

        DoLog (' Shipment num : ' || ln_shipment_num);

        --Check count of shipments tied to the PO line. Currently we only support 1 shipment per line for this functionality
        IF ln_shipment_cnt > 1
        THEN
            pv_msg   := 'Only 1 shipment per line is supported';
            DOLOG (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --Check if PO line is open and approved
        IF lv_closed_code != 'OPEN' OR NVL (lv_cancel_flag, 'N') = 'Y'
        THEN
            pv_msg   := 'PO line closed/cancelled';
            DOLOG (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --End validation

        --check context

        set_purchasing_context (pn_user_id, ln_org_id, pv_stat,
                                pv_msg);

        IF pv_stat <> 'S'
        THEN
            RAISE ex_login;
        END IF;


        --Price/Quantity

        --Update quantity and price

        --if new quantity matches current quantity then pass NULL to po_update
        DoLog (
               'update PO Line ds. Curr Qty : '
            || ln_quantity
            || ' New Qty : '
            || pn_quantity);

        --Check for net change on quantity
        IF ln_quantity = NVL (pn_quantity, ln_quantity)
        THEN
            ln_quantity   := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_quantity        := pn_quantity;                    --CCR0008134
        END IF;

        --Check for net change on price
        IF ln_unit_price = NVL (pn_unit_price, ln_unit_price)
        THEN
            ln_orig_unit_price   := ln_unit_price;
            ln_unit_price        := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_unit_price      := pn_unit_price;
        END IF;

        DoLog ('Drop ship flag :' || lv_drop_ship_flag);

        --Drop_ship PO and qty is changing then get sourcing SO for qty update
        IF pn_quantity IS NOT NULL AND lv_drop_ship_flag = 'Y'
        THEN
            BEGIN
                --DoLog ('looking up order data');
                --DoLog ('PO Number ; '|| p_po_number|| '   Line Nnum : '|| p_line_num|| ' Shipment num : '|| l_shipment_num);

                SELECT oola.header_id, oola.line_id
                  INTO ln_header_id, ln_line_id
                  FROM oe_order_lines_all oola, oe_drop_ship_sources dss, po_lines_all pla,
                       po_line_locations_all plla, po_headers_all pha
                 WHERE     oola.line_id = dss.line_id
                       AND dss.line_location_id = plla.line_location_id
                       AND pla.po_line_id = plla.po_line_id
                       AND pla.line_num = pn_line_num
                       AND plla.shipment_num = ln_shipment_num
                       AND pha.segment1 = pv_po_number
                       AND pla.po_header_id = pha.po_header_id;

                DoLog ('Header ID ' || ln_header_id);
            --Run the function to update the sales order quantity
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    DoLog ('no order data found');
                    ln_header_id   := NULL;
                    ln_line_id     := NULL;
            END;
        END IF;

        --Check for net change on Promised date
        /*IF ld_promised_date = NVL (pd_promised_date, ld_promised_date)
        THEN
           ld_promised_date := NULL;
           ln_shipment_num := NULL;
        ELSE
           lb_run_po_update := TRUE;
           ld_promised_date := pd_promised_date;
        END IF;*/

        lb_run_po_update   := TRUE;

        DoLog ('before call apps.po_change_api1_s.update_po-1');
        DoLog (
               ' PO Number : '
            || pv_po_number
            || ' Line # : '
            || pn_line_num
            || ' Quantity : '
            || ln_quantity
            || ' Promised Date : '
            || TO_CHAR (ld_promised_date)
            || ' New Promised Date : '
            || TO_CHAR (pd_promised_date));

        --CCR0009609
        BEGIN
            SELECT SUM (plla.quantity - NVL (plla.quantity_cancelled, 0))
              INTO ln_original_line_qty
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_line_id = plla.po_line_id
                   AND pla.line_num = pn_line_num
                   AND pla.po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_original_line_qty   := 0;
                DoLog ('Failed to fetch PO line quantity');
        END;

        -- CCR0009609


        --Call update PO API
        --Only called if change on quantity, price or promised date
        IF lb_run_po_update
        THEN
            ln_result           :=
                apps.po_change_api1_s.update_po (
                    x_po_number             => pv_po_number, --Enter the PO Number
                    x_release_number        => NULL,   --Enter the Release Num
                    x_revision_number       => ln_revision_num, --Enter the Revision Number
                    x_line_number           => pn_line_num, --Enter the Line Number
                    x_shipment_number       => ln_shipment_num, --Enter the Shipment Number
                    new_quantity            => NULL, --ln_quantity, --Enter the new quantity
                    new_price               => NULL, --ln_unit_price, --Enter the new price,
                    new_promised_date       => pd_promised_date, -- New Promise Date coming from POC interface
                    new_need_by_date        => NULL, --pd_promised_date, --this may happen in future, so just replace with ld_promised_date when needed.
                    launch_approvals_flag   => 'N', -- Change: 2.6 - Pass as 'N', to remove Auto approval, we are only approving at end of the POC file
                    update_source           => NULL,
                    VERSION                 => '1.0',
                    x_override_date         => NULL,
                    x_api_errors            => l_api_errors,
                    p_buyer_name            => NULL,
                    p_secondary_quantity    => NULL,
                    p_preferred_grade       => NULL,
                    p_org_id                => ln_org_id);
            DoLog ('PO Update API result : ' || ln_result);

            IF (ln_result = 1)
            THEN
                DoLog ('Successfully update the PO :=>');
            END IF;

            IF (ln_result <> 1)
            THEN
                IF l_api_errors IS NOT NULL
                THEN                                   -- Added for CCR0009182
                    DoLog (
                        'Failed to update the PO Due to Following Reasons');

                    -- Display the errors
                    FOR j IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                    LOOP
                        DoLog (l_api_errors.MESSAGE_TEXT (j));

                        -- Added Start CCR0006035
                        IF j = 1
                        THEN
                            pv_msg   := l_api_errors.MESSAGE_TEXT (j);
                        ELSE
                            pv_msg   :=
                                   pv_msg
                                || ','
                                || l_api_errors.MESSAGE_TEXT (j);
                        END IF;
                    -- Added End CCR0006035
                    END LOOP;

                    RAISE ex_update;
                ELSE
                    pv_msg   := 'No messages returned from API';
                    DoLog (pv_msg);
                END IF;

                DoLog (pv_msg);                                  -- CCR0006517
            END IF;

            lb_po_update_flag   := TRUE; --set the total update flag for the rest of the process
        ELSE
            DoLog ('update_po not needed');
        END IF;

        --Second round of PO line updates
        --These are updates outside of the Oracle API

        --Get line location ID to update
        BEGIN
            SELECT line_location_id
              INTO ln_line_location_id
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_line_id = plla.po_line_id
                   AND pla.line_num = pn_line_num
                   AND plla.shipment_num = pn_shipment_num
                   AND pla.po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                --NULL;     --This should not fail due to previous validation checks
                DoLog (
                       'PO Line location not found : should not get here :: '
                    || SQLERRM);                                 -- CCR0006517
        END;

        DoLog (
               'updating attribute fields for line location id : '
            || ln_line_location_id);

        --Run other PO field updates

        IF pv_ship_method IS NOT NULL
        THEN
            DoLog ('Updating ship_method : ' || pv_ship_method);

            UPDATE po_line_locations_all plla
               SET attribute10 = pv_ship_method, last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035
            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        IF pv_freight_pay_party IS NOT NULL
        THEN
            DoLog ('Updating freight pay party : ' || pv_freight_pay_party);

            UPDATE po_line_locations_all
               SET attribute7 = pv_freight_pay_party, last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035
            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        --CCR0009609
        BEGIN
            SELECT attribute15
              INTO ln_attribute15
              FROM po_lines_all
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                    ' failed to fetch attribute15 for line_id : ' || SQLERRM);
        END;

        IF ln_attribute15 IS NULL
        THEN
            -- Updating attribute15 with Original line quantity
            BEGIN
                UPDATE po_lines_all
                   SET attribute15 = ln_original_line_qty, last_update_date = SYSDATE
                 WHERE po_line_id =
                       (SELECT po_line_id
                          FROM apps.po_line_locations_all
                         WHERE     line_location_id = ln_line_location_id
                               AND ROWNUM = 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    DoLog (
                           'Updating attribute15 failed for line_id : '
                        || SQLERRM);
            END;
        END IF;

        --CCR0009609

        IF pd_cxf_date IS NOT NULL
        THEN
            DoLog (
                   'Updating conf ex factory date : '
                || TO_CHAR (pd_cxf_date, 'MM/DD/YYYY'));

            --Rev1
            --Also update Orig CFX date if not populated
            UPDATE po_line_locations_all
               SET attribute8 = NVL (attribute5, TO_CHAR (pd_cxf_date, 'YYYY/MM/DD')), last_update_date = SYSDATE -- Added for CCR0006035
             WHERE     line_location_id = ln_line_location_id
                   AND attribute8 IS NULL;

            UPDATE po_line_locations_all
               SET attribute5 = TO_CHAR (pd_cxf_date, 'YYYY/MM/DD'), last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035
            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        --Added for CCR0008134
        IF pv_supplier_site_code IS NOT NULL
        THEN
            DoLog ('Updating supplier site code : ' || pv_supplier_site_code);

            --Update DFF in PO Line
            UPDATE po_lines_all
               SET attribute7 = pv_supplier_site_code, last_update_date = SYSDATE
             WHERE     NVL (attribute7, 'NONE') != pv_supplier_site_code
                   AND po_line_id =
                       (SELECT po_line_id
                          FROM apps.po_line_locations_all
                         WHERE     line_location_id = ln_line_location_id
                               AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        --Rev3 : only set POC negotiation flag if an update above occurred
        IF lb_po_update_flag
        THEN
            BEGIN
                DoLog ('Update attribute 11 and 13');

                UPDATE apps.po_lines_all               -- POC Negotiation flag
                   SET attribute13 = 'True', attribute11 = NVL (ln_unit_price, ln_orig_unit_price) - (NVL (attribute8, 0) + NVL (attribute9, 0)), last_update_date = SYSDATE -- Added for CCR0006035
                 WHERE     line_num = pn_line_num
                       AND po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_msg   :=
                        'Error while updating POC Negotiation flag in update po line proc';
                    RAISE ex_update;
            END;
        ELSE
            DoLog ('No PO update for this line');
        END IF;

        DoLog ('update_po_line_ds : PO Line update complete');

        pv_error_msg       := '';
        pv_error_stat      := 'S';
        DoLog ('update_po_line_ds : Exit');
    EXCEPTION
        WHEN ex_validation
        THEN
            DoLog ('update_po_line_ds : validation Exception' || pv_msg);
            pv_error_msg    := pv_msg;
            pv_error_stat   := 'E';
        WHEN ex_login
        THEN
            pv_error_msg    := 'Login error: ' || pv_msg;
            pv_error_stat   := 'E';
            dolog ('update_po_line_ds ex_login :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_update
        THEN
            pv_error_msg    := 'Update error : ' || pv_msg;
            pv_error_stat   := 'E';
            dolog ('update_po_line_ds ex_update :: ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_msg    := SQLERRM;
            pv_error_stat   := 'U';
            DoLog ('update_po_line_ds : unexpected error ::' || pv_error_msg);
    END update_po_line_ds;

    PROCEDURE update_po_line_ads (pv_po_number IN VARCHAR2, pn_line_num IN NUMBER, pn_shipment_num IN NUMBER:= NULL, pn_quantity IN NUMBER:= NULL, pn_unit_price IN NUMBER:= NULL, pd_promised_date IN DATE:= NULL, pv_ship_method IN VARCHAR:= NULL, pv_freight_pay_party IN VARCHAR:= NULL, pd_cxf_date IN DATE:= NULL, pv_supplier_site_code IN VARCHAR2:= NULL, --CCR0008134
                                                                                                                                                                                                                                                                                                                                                                    pn_user_id IN NUMBER, pv_error_stat OUT VARCHAR2
                                  , pv_error_msg OUT VARCHAR2)
    IS
        ln_org_id                 NUMBER;
        ln_line_location_id       NUMBER;
        ln_resp_id                NUMBER;
        ln_app_id                 NUMBER;
        pv_msg                    VARCHAR2 (2000);
        pv_stat                   VARCHAR2 (1);

        ln_po_header_id           NUMBER;
        ln_po_line_id             NUMBER;
        ln_line_location          NUMBER;
        lv_cancel_flag            VARCHAR2 (1);
        lv_closed_code            VARCHAR2 (25);
        ln_created_by             NUMBER;
        ln_quantity               NUMBER;
        lv_authorization_status   VARCHAR2 (25);
        ld_promised_date          DATE;
        ln_shipment_num           NUMBER;
        ln_revision_num           NUMBER;
        ln_result                 NUMBER;
        ln_unit_price             NUMBER;
        ln_orig_unit_price        NUMBER;
        ln_shipment_cnt           NUMBER;
        lv_drop_ship_flag         VARCHAR2 (1);
        ld_req_xf_date            DATE;
        ld_cxf_date               DATE;
        ln_calc_in_transit_days   NUMBER;

        ln_header_id              NUMBER;
        ln_line_id                NUMBER;
        lb_run_po_update          BOOLEAN := FALSE;
        lb_po_update_flag         BOOLEAN := FALSE;

        l_api_errors              apps.po_api_errors_rec_type;

        ex_validation             EXCEPTION;
        ex_login                  EXCEPTION;
        ex_update                 EXCEPTION;
        ln_error_number           NUMBER := 0;
    BEGIN
        pv_msg          := NULL;                   -- Added for CCR CCR0006035
        DoLog ('update_po_line_ads : Enter');
        DoLog (
               ' PO Number : '
            || pv_po_number
            || ' Line_num : '
            || pn_line_num
            || ' Shipment_num : '
            || pn_shipment_num
            || ' Supplier Site Code : '                           --CCR0008134
            || pv_supplier_site_code);

        --Validation segment
        --Qty must be greater than 0 and an integer
        IF pn_quantity <= 0 OR pn_quantity != TRUNC (pn_quantity)
        THEN
            pv_msg   := TO_CHAR (pn_quantity) || ' is not a valid quantity';
            RAISE ex_validation;
        END IF;

        --Unit Price must be greater than 0 --TODO: validate against currency settings
        IF pn_unit_price < 0
        THEN
            pv_msg   := TO_CHAR (pn_unit_price) || ' is not a valid price';
            dolog (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;


        --Begin CCR0008134
        IF NVL (TRUNC (pd_promised_date), TRUNC (SYSDATE)) < TRUNC (SYSDATE)
        THEN
            pv_msg   := 'New promised date cannot be in the past';
            dolog (pv_msg);
            RAISE ex_validation;
        END IF;

        --End CCR0008134


        BEGIN
            --Get po data for additional validation
            --ASSUMPTION : A PO_LINE will only have 1 SHIPMENT record
            --Getting MAX of the promised date on the shipments should return only 1 valid value
            SELECT pha.org_id,
                   pha.po_header_id,
                   pla.po_line_id,
                   pla.cancel_flag,
                   pla.closed_code,
                   pla.created_by,
                   pla.quantity,
                   pha.authorization_status,
                   (SELECT MAX (promised_date)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       promised_date,
                   (SELECT MAX (shipment_num)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       shipment_num,
                   pha.revision_num,
                   pla.unit_price,
                   (SELECT COUNT (*)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       shipment_cnt,
                   (SELECT DECODE (MIN (NVL (drop_ship_flag, 'N')), MAX (NVL (drop_ship_flag, 'N')), MIN (NVL (drop_ship_flag, 'N')), 'Y')
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       drop_ship_flag,
                   (SELECT MAX (apps.fnd_date.canonical_to_date (plla.attribute4))
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       ld_req_xf_date,
                   (SELECT MAX (apps.fnd_date.canonical_to_date (plla.attribute5))
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       ld_cxf_date
              INTO ln_org_id, ln_po_header_id, ln_po_line_id, lv_cancel_flag,
                            lv_closed_code, ln_created_by, ln_quantity,
                            lv_authorization_status, ld_promised_date, ln_shipment_num,
                            ln_revision_num, ln_unit_price, ln_shipment_cnt,
                            lv_drop_ship_flag, ld_req_xf_date, ld_cxf_date
              FROM po_headers_all pha, po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_msg   := 'PO shipment record not found';
                dolog (pv_msg);                                  -- CCR0006517
                RAISE ex_validation;
        END;

        DoLog (' Shipment num : ' || ln_shipment_num);

        --Check count of shipments tied to the PO line. Currently we only support 1 shipment per line for this functionality
        IF ln_shipment_cnt > 1
        THEN
            pv_msg   := 'Only 1 shipment per line is supported';
            dolog (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --Check if PO line is open and approved
        IF lv_closed_code != 'OPEN' OR NVL (lv_cancel_flag, 'N') = 'Y'
        THEN
            pv_msg   := 'PO line closed/cancelled';
            dolog (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --End validation

        --check context

        set_purchasing_context (pn_user_id, ln_org_id, pv_stat,
                                pv_msg);

        IF pv_stat <> 'S'
        THEN
            RAISE ex_login;
        END IF;


        --Price/Quantity

        --Update quantity and price

        --if new quantity matches current quantity then pass NULL to po_update
        DoLog (
               'update PO Line ads. Curr Qty : '
            || ln_quantity
            || ' New Qty : '
            || pn_quantity);

        --Check for net change on quantity
        IF ln_quantity = NVL (pn_quantity, ln_quantity)
        THEN
            ln_quantity   := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_quantity        := pn_quantity;
        END IF;

        --Check for net change on price
        IF ln_unit_price = NVL (pn_unit_price, ln_unit_price)
        THEN
            ln_orig_unit_price   := ln_unit_price;
            ln_unit_price        := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_unit_price      := pn_unit_price;
        END IF;

        DoLog ('Drop ship flag :' || lv_drop_ship_flag);

        --Drop_ship PO and qty is changing then get sourcing SO for qty update
        IF pn_quantity IS NOT NULL AND lv_drop_ship_flag = 'Y'
        THEN
            BEGIN
                --DoLog ('looking up order data');
                --DoLog ('PO Number ; '|| p_po_number|| '   Line Nnum : '|| p_line_num|| ' Shipment num : '|| l_shipment_num);

                SELECT oola.header_id, oola.line_id
                  INTO ln_header_id, ln_line_id
                  FROM oe_order_lines_all oola, oe_drop_ship_sources dss, po_lines_all pla,
                       po_line_locations_all plla, po_headers_all pha
                 WHERE     oola.line_id = dss.line_id
                       AND dss.line_location_id = plla.line_location_id
                       AND pla.po_line_id = plla.po_line_id
                       AND pla.line_num = pn_line_num
                       AND plla.shipment_num = ln_shipment_num
                       AND pha.segment1 = pv_po_number
                       AND pla.po_header_id = pha.po_header_id
                       AND oola.flow_status_code = 'AWAITING_RECEIPT'; -- CCR0006285 POC Changes

                DoLog ('Header ID ' || ln_header_id);
            --Run the function to update the sales order quantity
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    DoLog ('no order data found');
                    ln_header_id   := NULL;
                    ln_line_id     := NULL;
            END;
        END IF;

        --Check for net change on Promised date
        IF ld_promised_date = NVL (pd_promised_date, ld_promised_date)
        THEN
            ld_promised_date   := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ld_promised_date   := pd_promised_date;
        END IF;

        --Begin CCR0008134
        dolog (
               'update_po_line_ads  : checking for transit time  promised date : '
            || TO_CHAR (pd_promised_date)
            || ' cxf date : '
            || TO_CHAR (pd_cxf_date));

        --Promised date not updated but CXF date is.also req_xf date  is different than conf xf date  Get new promised date from transit matrix
        IF     pd_promised_date IS NULL
           AND pd_cxf_date IS NOT NULL
           AND (ld_req_xf_date != ld_cxf_date)
        THEN
            ln_calc_in_transit_days   :=
                get_pol_transit_days (pv_po_number, pn_line_num);

            IF NVL (ln_calc_in_transit_days, 0) = 0
            THEN
                doLog ('Not defined transit time');
                pv_msg   := 'Transit time not defined for ship method';
                RAISE ex_update;
            END IF;


            ld_promised_date   := pd_cxf_date + ln_calc_in_transit_days;
        END IF;

        IF ld_promised_date IS NULL
        THEN
            ln_shipment_num   := NULL;
        END IF;

        --End CCR0008134

        DoLog ('before call apps.po_change_api1_s.update_po-2');
        DoLog (
               ' PO Number : '
            || pv_po_number
            || ' Line # : '
            || pn_line_num
            || ' Quantity : '
            || ln_quantity
            || ' Promised Date : '
            || TO_CHAR (ld_promised_date));

        --Call update PO API
        --Only called if change on quantity, price or promised date
        IF lb_run_po_update
        THEN
            ln_result           :=
                apps.po_change_api1_s.update_po (
                    x_po_number             => pv_po_number, --Enter the PO Number
                    x_release_number        => NULL,   --Enter the Release Num
                    x_revision_number       => ln_revision_num, --Enter the Revision Number
                    x_line_number           => pn_line_num, --Enter the Line Number
                    x_shipment_number       => ln_shipment_num, --Enter the Shipment Number
                    new_quantity            => ln_quantity, --Enter the new quantity
                    new_price               => ln_unit_price, --Enter the new price,
                    new_promised_date       => ld_promised_date, -- New Promise Date coming from POC interface
                    new_need_by_date        => ld_promised_date, --this may happen in future, so just replace with ld_promised_date when needed.
                    launch_approvals_flag   => 'N', -- Change: 2.6 - Pass as 'N', to remove Auto approval, we are only approving at end of the POC file
                    update_source           => NULL,
                    VERSION                 => '1.0',
                    x_override_date         => NULL,
                    x_api_errors            => l_api_errors,
                    p_buyer_name            => NULL,
                    p_secondary_quantity    => NULL,
                    p_preferred_grade       => NULL,
                    p_org_id                => ln_org_id);
            DoLog ('PO Update API result : ' || ln_result);

            IF (ln_result = 1)
            THEN
                DoLog ('Successfully update the PO :=>');
            END IF;

            IF (ln_result <> 1)
            THEN
                IF l_api_errors IS NOT NULL
                THEN
                    DoLog (
                        'Failed to update the PO Due to Following Reasons');

                    -- Display the errors
                    FOR j IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                    LOOP
                        DoLog (l_api_errors.MESSAGE_TEXT (j));

                        -- Added Start CCR0006035
                        IF j = 1
                        THEN
                            pv_msg   := l_api_errors.MESSAGE_TEXT (j);
                        ELSE
                            pv_msg   :=
                                   pv_msg
                                || ','
                                || l_api_errors.MESSAGE_TEXT (j);
                        END IF;
                    -- Added End CCR0006035
                    END LOOP;

                    RAISE ex_update;
                ELSE
                    pv_msg   := 'No messages returned from API';
                    DoLog (pv_msg);
                END IF;

                DoLog (pv_msg);                                  -- CCR0006517
            END IF;

            lb_po_update_flag   := TRUE; --set the total update flag for the rest of the process
        ELSE
            DoLog ('update_po not needed');
        END IF;

        --Second round of PO line updates
        --These are updates outside of the Oracle API

        --Get line location ID to update
        BEGIN
            SELECT line_location_id
              INTO ln_line_location_id
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_line_id = plla.po_line_id
                   AND pla.line_num = pn_line_num
                   AND plla.shipment_num = pn_shipment_num
                   AND pla.po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL; --This should not fail due to previous validation checks
                DoLog ('PO Line location not found : should not get here');
        END;

        DoLog (
               'updating attribute fields for line location id : '
            || ln_line_location_id);

        --Run other PO field updates

        IF pv_ship_method IS NOT NULL
        THEN
            DoLog ('Updating ship_method : ' || pv_ship_method);

            UPDATE po_line_locations_all plla
               SET attribute10 = pv_ship_method, last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035
            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        IF pv_freight_pay_party IS NOT NULL
        THEN
            DoLog ('Updating freight pay party : ' || pv_freight_pay_party);

            UPDATE po_line_locations_all
               SET attribute7 = pv_freight_pay_party, last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035
            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        IF pd_cxf_date IS NOT NULL
        THEN
            DoLog (
                   'Updating conf ex factory date : '
                || TO_CHAR (pd_cxf_date, 'MM/DD/YYYY'));

            --Rev1
            --Also update Orig CFX date if not populated
            UPDATE po_line_locations_all
               SET attribute8 = NVL (attribute5, TO_CHAR (pd_cxf_date, 'YYYY/MM/DD')), last_update_date = SYSDATE -- Added for CCR0006035
             WHERE     line_location_id = ln_line_location_id
                   AND attribute8 IS NULL;

            UPDATE po_line_locations_all
               SET attribute5 = TO_CHAR (pd_cxf_date, 'YYYY/MM/DD'), last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035
            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;


        --Begin CCR0008134
        IF pv_supplier_site_code IS NOT NULL
        THEN
            DoLog ('Updating supplier site code : ' || pv_supplier_site_code);

            --Update DFF in PO Line
            UPDATE po_lines_all
               SET attribute7 = pv_supplier_site_code, last_update_date = SYSDATE
             WHERE     NVL (attribute7, 'NONE') != pv_supplier_site_code
                   AND po_line_id =
                       (SELECT po_line_id
                          FROM apps.po_line_locations_all
                         WHERE     line_location_id = ln_line_location_id
                               AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        --End CCR0008134

        --Rev3 : only set POC negotiation flag if an update above occurred
        IF lb_po_update_flag
        THEN
            BEGIN
                DoLog ('Update attribute 11 and 13');

                UPDATE apps.po_lines_all               -- POC Negotiation flag
                   SET attribute13 = 'True', attribute11 = NVL (ln_unit_price, ln_orig_unit_price) - (NVL (attribute8, 0) + NVL (attribute9, 0)), last_update_date = SYSDATE -- Added for CCR0006035
                 WHERE     line_num = pn_line_num
                       AND po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_msg   :=
                        'Error while updating POC Negotiation flag in update po line proc';
                    RAISE ex_update;
            END;
        ELSE
            DoLog ('No PO update for this line');
        END IF;

        DoLog ('update_po_line_ads : PO Line update complete');

        pv_error_msg    := '';
        pv_error_stat   := 'S';
        DoLog ('update_po_line_ads : Exit');
    EXCEPTION
        WHEN ex_validation
        THEN
            DoLog ('update_po_line_ads : validation Exception' || pv_msg);
            pv_error_msg    := pv_msg;
            pv_error_stat   := 'E';
        WHEN ex_login
        THEN
            pv_error_msg    := 'Login error: ' || pv_msg;
            pv_error_stat   := 'E';
            dolog ('update_po_line_ads ex_login : ' || pv_error_msg); -- CCR0006517
        WHEN ex_update
        THEN
            pv_error_msg    := 'Update error : ' || pv_msg;
            pv_error_stat   := 'E';
            dolog ('update_po_line_ads ex_update : ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_msg    := SQLERRM;
            pv_error_stat   := 'U';
            DoLog ('update_po_line_ads : unexpected error :: ' || SQLERRM);
    END update_po_line_ads;

    -- End CCR0006285 DS Changes

    --Update a PO line and dependant shipment data
    PROCEDURE update_po_line (pv_po_number IN VARCHAR2, pn_line_num IN NUMBER, pn_shipment_num IN NUMBER:= NULL, pn_quantity IN NUMBER:= NULL, pn_unit_price IN NUMBER:= NULL, pd_promised_date IN DATE:= NULL, pv_ship_method IN VARCHAR:= NULL, pv_freight_pay_party IN VARCHAR:= NULL, pd_cxf_date IN DATE:= NULL, pv_supplier_site_code IN VARCHAR2:= NULL, --CCR0008134
                                                                                                                                                                                                                                                                                                                                                                pn_user_id IN NUMBER, pv_error_stat OUT VARCHAR2
                              , pv_error_msg OUT VARCHAR2)
    IS
        ln_org_id                 NUMBER;
        ln_line_location_id       NUMBER;
        ln_resp_id                NUMBER;
        ln_app_id                 NUMBER;
        pv_msg                    VARCHAR2 (2000);
        pv_stat                   VARCHAR2 (1);

        ln_po_header_id           NUMBER;
        ln_po_line_id             NUMBER;
        ln_line_location          NUMBER;
        lv_cancel_flag            VARCHAR2 (1);
        lv_closed_code            VARCHAR2 (25);
        ln_created_by             NUMBER;
        ln_quantity               NUMBER;
        lv_authorization_status   VARCHAR2 (25);
        ld_promised_date          DATE;
        ln_shipment_num           NUMBER;
        ln_revision_num           NUMBER;
        ln_result                 NUMBER;
        ln_unit_price             NUMBER;
        ln_orig_unit_price        NUMBER;
        ln_shipment_cnt           NUMBER;
        ln_transit_days           NUMBER;
        ln_curr_transit_days      NUMBER;
        lv_drop_ship_flag         VARCHAR2 (1);
        ld_req_xf_date            DATE;
        ld_cxf_date               DATE;
        ld_current_date           DATE := TRUNC (SYSDATE);
        ln_calc_in_transit_days   NUMBER;


        ln_header_id              NUMBER;
        ln_line_id                NUMBER;
        lb_run_po_update          BOOLEAN := FALSE;
        lb_po_update_flag         BOOLEAN := FALSE;

        l_api_errors              apps.po_api_errors_rec_type;

        ex_validation             EXCEPTION;
        ex_login                  EXCEPTION;
        ex_update                 EXCEPTION;
        ln_original_line_qty      NUMBER;                         --CCR0009609
        ln_attribute15            NUMBER;                         --CCR0009609

        --Start Added for CCR0010003
        ln_vendor_id              NUMBER;
        ln_vendor_site_id         NUMBER;
        ln_new_vendor_id          NUMBER;
        lv_new_vendor_name        VARCHAR2 (100);
        ln_new_vendor_site_id     NUMBER;
        ln_calc_transit_days      NUMBER;
    --End Added for CCR0010003
    BEGIN
        pv_msg             := NULL;                -- Added for CCR CCR0006035
        DoLog ('update_po_line : Enter');
        DoLog (
               ' PO Number : '
            || pv_po_number
            || ' Line_num : '
            || pn_line_num
            || ' Shipment_num : '
            || pn_shipment_num
            || ' Supplier Site Code : '
            || pv_supplier_site_code);                            --CCR0008134

        --Validation segment
        --Qty must be greater than 0 and an integer
        IF pn_quantity <= 0 OR pn_quantity != TRUNC (pn_quantity)
        THEN
            pv_msg   := TO_CHAR (pn_quantity) || ' is not a valid quantity';
            RAISE ex_validation;
        END IF;

        --Unit Price must be greater than 0 --TODO: validate against currency settings
        IF pn_unit_price < 0
        THEN
            pv_msg   := TO_CHAR (pn_unit_price) || ' is not a valid price';
            RAISE ex_validation;
        END IF;


        --Begin CCR0008134
        IF NVL (TRUNC (pd_promised_date), TRUNC (SYSDATE)) < TRUNC (SYSDATE)
        THEN
            pv_msg   := 'New promised date cannot be in the past';
            dolog (pv_msg);
            RAISE ex_validation;
        END IF;

        --End CCR0008134

        BEGIN
            --Get po data for additional validation
            --ASSUMPTION : A PO_LINE will only have 1 SHIPMENT record
            --Getting MAX of the promised date on the shipments should return only 1 valid value
            SELECT pha.org_id,
                   pha.po_header_id,
                   pla.po_line_id,
                   pla.cancel_flag,
                   pla.closed_code,
                   pla.created_by,
                   pla.quantity,
                   pha.authorization_status,
                   pha.vendor_id,                       --Added for CCR0010003
                   pha.vendor_site_id,                  --Added for CCR0010003
                   (SELECT MAX (promised_date)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       promised_date,
                   (SELECT MAX (shipment_num)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       shipment_num,
                   pha.revision_num,
                   pla.unit_price,
                   (SELECT COUNT (*)
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       shipment_cnt,
                   (SELECT DECODE (MIN (NVL (drop_ship_flag, 'N')), MAX (NVL (drop_ship_flag, 'N')), MIN (NVL (drop_ship_flag, 'N')), 'Y')
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       drop_ship_flag,
                   --Begin CCR0008134
                   (SELECT MAX (apps.fnd_date.canonical_to_date (plla.attribute4))
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       req_xf_date,
                   (SELECT MAX (apps.fnd_date.canonical_to_date (plla.attribute5))
                      FROM po_line_locations_all plla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.closed_code != 'CLOSED'
                           AND NVL (plla.cancel_flag, 'N') = 'N')
                       cxf_date
              --End CCR0008134
              INTO ln_org_id, ln_po_header_id, ln_po_line_id, lv_cancel_flag,
                            lv_closed_code, ln_created_by, ln_quantity,
                            lv_authorization_status, ln_vendor_id, --Added for CCR0010003
                                                                   ln_vendor_site_id, --Added for CCR0010003
                            ld_promised_date, ln_shipment_num, ln_revision_num,
                            ln_unit_price, ln_shipment_cnt, lv_drop_ship_flag,
                            --Begin CCR0008134
                            ld_req_xf_date, ld_cxf_date
              --End CCR0008134
              FROM po_headers_all pha, po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_msg   := 'PO shipment record not found';
                dolog (pv_msg);                                  -- CCR0006517
                RAISE ex_validation;
        END;

        DoLog (' Shipment num : ' || ln_shipment_num);

        --Check count of shipments tied to the PO line. Currently we only support 1 shipment per line for this functionality
        IF ln_shipment_cnt > 1
        THEN
            pv_msg   := 'Only 1 shipment per line is supported';
            dolog (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --Check if PO line is open and approved
        IF lv_closed_code != 'OPEN' OR NVL (lv_cancel_flag, 'N') = 'Y'
        THEN
            pv_msg   := 'PO line closed/cancelled';
            dolog (pv_msg);                                      -- CCR0006517
            RAISE ex_validation;
        END IF;

        --Start Added for CCR0010003
        --Get New Supplier ID and Supplier Site ID
        IF pv_supplier_site_code IS NOT NULL
        THEN
            BEGIN
                SELECT aps.vendor_id, aps.vendor_name, apsa.vendor_site_id
                  INTO ln_new_vendor_id, lv_new_vendor_name, ln_new_vendor_site_id
                  FROM ap_suppliers aps, ap_supplier_sites_all apsa
                 WHERE     1 = 1
                       AND aps.vendor_id = apsa.vendor_id
                       AND org_id = ln_org_id
                       AND vendor_site_code = pv_supplier_site_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_new_vendor_id        := NULL;
                    lv_new_vendor_name      := NULL;
                    ln_new_vendor_site_id   := NULL;
            END;
        END IF;

        --End Added for CCR0010003

        --End validation

        --check context

        set_purchasing_context (pn_user_id, ln_org_id, pv_stat,
                                pv_msg);

        IF pv_stat <> 'S'
        THEN
            RAISE ex_login;
        END IF;


        --Price/Quantity

        --Update quantity and price

        --if new quantity matches current quantity then pass NULL to po_update
        DoLog (
               'update PO Line. Curr Qty : '
            || ln_quantity
            || ' New Qty : '
            || pn_quantity);

        --Check for net change on quantity
        IF ln_quantity = NVL (pn_quantity, ln_quantity)
        THEN
            ln_quantity   := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_quantity        := pn_quantity;
        END IF;

        --Check for net change on price
        IF ln_unit_price = NVL (pn_unit_price, ln_unit_price)
        THEN
            ln_orig_unit_price   := ln_unit_price;
            ln_unit_price        := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_unit_price      := pn_unit_price;
        END IF;

        --Start Added for CCR0010003
        --Check for net change on price
        IF ln_unit_price = NVL (pn_unit_price, ln_unit_price)
        THEN
            ln_orig_unit_price   := ln_unit_price;
            ln_unit_price        := NULL;
        ELSE
            lb_run_po_update   := TRUE;
            ln_unit_price      := pn_unit_price;
        END IF;

        --End Added for CCR0010003

        DoLog ('Drop ship flag :' || lv_drop_ship_flag);

        --Drop_ship PO and qty is changing then get sourcing SO for qty update
        IF pn_quantity IS NOT NULL AND lv_drop_ship_flag = 'Y'
        THEN
            BEGIN
                --DoLog ('looking up order data');
                --DoLog ('PO Number ; '|| p_po_number|| '   Line Nnum : '|| p_line_num|| ' Shipment num : '|| l_shipment_num);

                SELECT oola.header_id, oola.line_id
                  INTO ln_header_id, ln_line_id
                  FROM oe_order_lines_all oola, oe_drop_ship_sources dss, po_lines_all pla,
                       po_line_locations_all plla, po_headers_all pha
                 WHERE     oola.line_id = dss.line_id
                       AND dss.line_location_id = plla.line_location_id
                       AND pla.po_line_id = plla.po_line_id
                       AND pla.line_num = pn_line_num
                       AND plla.shipment_num = ln_shipment_num
                       AND pha.segment1 = pv_po_number
                       AND pla.po_header_id = pha.po_header_id
                       AND oola.flow_status_code = 'AWAITING_RECEIPT'; -- CCR0006285 POC Changes

                DoLog ('Header ID ' || ln_header_id);
            --Run the function to update the sales order quantity
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    DoLog ('no order data found');
                    ln_header_id   := NULL;
                    ln_line_id     := NULL;
            END;
        END IF;

        ld_promised_date   := TRUNC (ld_promised_date);
        ld_cxf_date        := TRUNC (ld_cxf_date);

        --TRIM all timestamps
        IF NVL (lv_drop_ship_flag, 'N') = 'N'
        THEN
            ln_curr_transit_days   :=
                get_pol_transit_days (pv_po_number, pn_line_num);
            DoLog ('Current transit days : ' || ln_curr_transit_days);

            ln_transit_days   :=
                get_pol_transit_days (pv_po_number,
                                      pn_line_num,
                                      pv_ship_method);
            DoLog ('New transit days : ' || ln_transit_days);
        ELSE                                   --No transit time for drop ship
            ln_curr_transit_days   := 0;
            ln_transit_days        := 0;
            DoLog ('No transit time calc for drop ship');
        END IF;


        DoLog ('Doing Promised date check');
        DoLog ('Inbound promised date override : ' || pd_promised_date);
        DoLog ('Inbound Conf XF date : ' || pd_cxf_date);

        DoLog ('Current Promised Date : ' || ld_promised_date);
        DoLog ('Current PO Conf XF Date : ' || ld_cxf_date);
        DoLog (
               'Transit time for Ship Method of '
            || pv_ship_method
            || ' - '
            || ln_transit_days);

        --   DoLog (
        --       'Curr calc promised date : ' || pd_cxf_date + ln_curr_transit_days);
        --   DoLog ('New calc promised date : ' || ld_cxf_date + ln_transit_days);

        --Start Added for CCR0010003
        --New Supplier validation
        DoLog ('Promise_Date Calculation for New Supplier site starts');

        IF pv_supplier_site_code IS NOT NULL           --Supplier Site Changes
        THEN
            --Calculate Promise Date
            IF NVL (lv_drop_ship_flag, 'N') = 'N' --Calc only for non-drop ship
            THEN
                DoLog (
                    'Non-Drop ship PO, PromiseDate calculation required for change supplier\site');
                --Get In-Transit Days for Supplier\Site
                ln_calc_transit_days   :=
                    get_pol_sup_transit_days (pv_po_number,
                                              ln_new_vendor_id,
                                              ln_new_vendor_site_id);

                IF NVL (ln_calc_transit_days, 0) < 0
                THEN
                    DoLog (
                        'Transit time not defined in lookup for Supplier\Site');
                    pv_msg             := 'Transit time not defined for Supplier\Site';
                    lb_run_po_update   := FALSE;
                    RAISE ex_update;
                END IF;
            ELSE
                DoLog (
                    'Drop ship PO, PromiseDate calculation not required for change supplier\site');
                ln_calc_transit_days   := 0;
                DoLog (
                    'Transit time set as Zero for Supplier\Site(Drop Ship)');
            END IF;

            --Promised date not updated but CXF date is. Get new promised date from transit matrix
            --first check if pased in CXF date differs from CXF date
            IF (ld_cxf_date IS NOT NULL AND NVL (ln_calc_transit_days, 0) > 0)
            THEN
                ld_promised_date   := ld_cxf_date + ln_calc_transit_days;
                DoLog ('Cxf Date : ' || TO_CHAR (ld_cxf_date));
                DoLog (
                       'New Calculated promised date : '
                    || TO_CHAR (ld_promised_date));
                lb_run_po_update   := TRUE;    --flag to run PO update process
            ELSE
                --No update on CXF date check update on Promised date
                IF (pd_promised_date IS NULL OR NVL (pd_promised_date, ld_current_date) = NVL (ld_promised_date, ld_current_date))
                THEN
                    --No Promised date update or passed in promised date = current promised date
                    ld_promised_date   := NULL;
                    lb_run_po_update   := FALSE;
                ELSE   --passed in Promised date differs from PO promised date
                    ld_promised_date   := pd_promised_date;
                    lb_run_po_update   := TRUE; --flag to run PO update process
                END IF;
            END IF;

            --Update po details with calculated promised date
            DoLog ('before call apps.po_change_api1_s.update_po-3');
            DoLog (
                   ' PO Number : '
                || pv_po_number
                || ' Line # : '
                || pn_line_num
                || ' Quantity : '
                || ln_quantity
                || ' Promised Date calculated for Supplier\Site Changes : '
                || TO_CHAR (ld_promised_date));

            --Call update PO API
            --Only called if change on quantity, price or promised date
            IF lb_run_po_update
            THEN
                --Get PO latest Revision
                BEGIN
                    SELECT NVL (revision_num, 0)
                      INTO ln_revision_num
                      FROM po_headers_all
                     WHERE segment1 = pv_po_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_revision_num   := 0;
                END;

                fnd_file.put_line (fnd_file.LOG,
                                   'Revision_num : ' || ln_revision_num);
                DoLog ('lb_run_po_update returns :' || 'TRUE');
                ln_result   :=
                    apps.po_change_api1_s.update_po (
                        x_po_number             => pv_po_number, --Enter the PO Number
                        x_release_number        => NULL, --Enter the Release Num
                        x_revision_number       => ln_revision_num, --Enter the Revision Number
                        x_line_number           => pn_line_num, --Enter the Line Number
                        x_shipment_number       => ln_shipment_num, --Enter the Shipment Number
                        new_quantity            => ln_quantity, --Enter the new quantity
                        new_price               => ln_unit_price, --Enter the new price,
                        new_promised_date       => ld_promised_date, -- New Promise Date coming from POC interface
                        new_need_by_date        => ld_promised_date, --this may happen in future, so just replace with ld_promised_date when needed.
                        launch_approvals_flag   => 'N', -- Change: 2.6 - Pass as 'N', to remove Auto approval, we are only approving at end of the POC file
                        update_source           => NULL,
                        VERSION                 => '1.0',
                        x_override_date         => NULL,
                        x_api_errors            => l_api_errors,
                        p_buyer_name            => NULL,
                        p_secondary_quantity    => NULL,
                        p_preferred_grade       => NULL,
                        p_org_id                => ln_org_id);

                DoLog ('PO Update API result : ' || ln_result);

                IF (ln_result = 1)
                THEN
                    DoLog ('Successfully update the PO :=>');
                END IF;

                IF (ln_result <> 1)
                THEN
                    IF l_api_errors IS NOT NULL
                    THEN
                        DoLog (
                            'Failed to update the PO Due to Following Reasons');

                        -- Display the errors
                        FOR j IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                        LOOP
                            DoLog (l_api_errors.MESSAGE_TEXT (j));

                            -- Added Start CCR0006035
                            IF j = 1
                            THEN
                                pv_msg   := l_api_errors.MESSAGE_TEXT (j);
                            ELSE
                                pv_msg   :=
                                       pv_msg
                                    || ','
                                    || l_api_errors.MESSAGE_TEXT (j);
                            END IF;
                        -- Added End CCR0006035
                        END LOOP;

                        RAISE ex_update;
                    ELSE
                        pv_msg   := 'No messages returned from API';
                        DoLog (pv_msg);
                    END IF;
                END IF;
            END IF;

            DoLog ('Promise_Date Calculation for New Supplier site End');
        --END Added for CCR0010003
        ELSE    --IF pv_supplier_site_code IS NOT NULL (supplier site changes)
            --first check if pased in CXF date differs from CXF date
            IF    pd_cxf_date IS NULL
               OR (NVL (pd_cxf_date + ln_curr_transit_days, TRUNC (SYSDATE)) = NVL (ld_cxf_date + ln_transit_days, TRUNC (SYSDATE)))
            THEN
                --No update on CXF date check update on Promised date
                IF (pd_promised_date IS NULL OR NVL (TRUNC (pd_promised_date), ld_current_date) = NVL (ld_promised_date, ld_current_date))
                THEN
                    --No Promised date update or passed in promised date = current promised date
                    ld_promised_date   := NULL;
                ELSE   --passed in Promised date differs from PO promised date
                    ld_promised_date   := pd_promised_date;
                    lb_run_po_update   := TRUE; --flag to run PO update process
                END IF;
            ELSE             --Passed in CFX date differs fom current CFX date
                IF pd_promised_date IS NULL
                THEN
                    --No PD passed - Do calc from CFX date to post to promised date
                    IF NVL (lv_drop_ship_flag, 'N') = 'N' --Calc only for non-drop ship
                    THEN
                        ln_calc_in_transit_days   :=
                            get_pol_transit_days (pv_po_number,
                                                  pn_line_num,
                                                  pv_ship_method);

                        IF NVL (ln_calc_in_transit_days, 0) = 0
                        THEN
                            doLog ('Not defined transit time');
                            pv_msg   :=
                                'Transit time not defined for ship method';
                            RAISE ex_update;
                        END IF;
                    ELSE                               --No calc for drop ship
                        ln_calc_in_transit_days   := 0;
                    END IF;

                    ld_promised_date   :=
                        pd_cxf_date + ln_calc_in_transit_days;

                    lb_run_po_update   := TRUE;
                ELSE                             --IF pd_promised_date IS NULL
                    IF NVL (pd_promised_date, ld_current_date) !=
                       NVL (ld_promised_date, ld_current_date)
                    THEN
                        ld_promised_date   := pd_promised_date;
                        lb_run_po_update   := TRUE;
                    ELSE
                        ld_promised_date   := NULL;
                    END IF;
                END IF;
            END IF;

            IF lb_run_po_update
            THEN
                DoLog ('Promised date to update : ' || ld_promised_date);
            ELSE
                DoLog ('Promised date not to update');
            END IF;

            -- END IF;
            --CCR0009609
            BEGIN
                SELECT SUM (plla.quantity - NVL (plla.quantity_cancelled, 0))
                  INTO ln_original_line_qty
                  FROM po_lines_all pla, po_line_locations_all plla
                 WHERE     pla.po_line_id = plla.po_line_id
                       AND pla.line_num = pn_line_num
                       AND pla.po_header_id =
                           (SELECT po_header_id
                              FROM apps.po_headers_all
                             WHERE segment1 = pv_po_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_original_line_qty   := 0;
                    DoLog ('Failed to fetch PO line quantity');
            END;

            -- CCR0009609

            DoLog ('before call apps.po_change_api1_s.update_po-4');
            DoLog (
                   ' PO Number : '
                || pv_po_number
                || ' Line # : '
                || pn_line_num
                || ' Quantity : '
                || ln_quantity
                || ' Promised Date : '
                || TO_CHAR (ld_promised_date));

            --Call update PO API
            --Only called if change on quantity, price or promised date
            IF lb_run_po_update
            THEN
                ln_result           :=
                    apps.po_change_api1_s.update_po (
                        x_po_number             => pv_po_number, --Enter the PO Number
                        x_release_number        => NULL, --Enter the Release Num
                        x_revision_number       => ln_revision_num, --Enter the Revision Number
                        x_line_number           => pn_line_num, --Enter the Line Number
                        x_shipment_number       => ln_shipment_num, --Enter the Shipment Number
                        new_quantity            => ln_quantity, --Enter the new quantity
                        new_price               => ln_unit_price, --Enter the new price,
                        new_promised_date       => ld_promised_date, -- New Promise Date coming from POC interface
                        new_need_by_date        => ld_promised_date, --this may happen in future, so just replace with ld_promised_date when needed.
                        launch_approvals_flag   => 'N', -- Change: 2.6 - Pass as 'N', to remove Auto approval, we are only approving at end of the POC file
                        update_source           => NULL,
                        VERSION                 => '1.0',
                        x_override_date         => NULL,
                        x_api_errors            => l_api_errors,
                        p_buyer_name            => NULL,
                        p_secondary_quantity    => NULL,
                        p_preferred_grade       => NULL,
                        p_org_id                => ln_org_id);

                DoLog ('PO Update API result : ' || ln_result);

                IF (ln_result = 1)
                THEN
                    DoLog ('Successfully update the PO :=>');
                END IF;

                IF (ln_result <> 1)
                THEN
                    IF l_api_errors IS NOT NULL
                    THEN
                        DoLog (
                            'Failed to update the PO Due to Following Reasons');

                        -- Display the errors
                        FOR j IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                        LOOP
                            DoLog (l_api_errors.MESSAGE_TEXT (j));

                            -- Added Start CCR0006035
                            IF j = 1
                            THEN
                                pv_msg   := l_api_errors.MESSAGE_TEXT (j);
                            ELSE
                                pv_msg   :=
                                       pv_msg
                                    || ','
                                    || l_api_errors.MESSAGE_TEXT (j);
                            END IF;
                        -- Added End CCR0006035
                        END LOOP;

                        RAISE ex_update;
                    ELSE
                        pv_msg   := 'No messages returned from API';
                        DoLog (pv_msg);
                    END IF;

                    DoLog (pv_msg);                              -- CCR0006517
                END IF;

                lb_po_update_flag   := TRUE; --set the total update flag for the rest of the process
            ELSE
                DoLog ('update_po not needed');
            END IF;
        END IF; --Added for CCR0010003    --IF pv_supplier_site_code IS NOT NULL (supplier site changes)

        --Second round of PO line updates
        --These are updates outside of the Oracle API

        --Get line location ID to update
        BEGIN
            SELECT line_location_id
              INTO ln_line_location_id
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_line_id = plla.po_line_id
                   AND pla.line_num = pn_line_num
                   AND plla.shipment_num = pn_shipment_num
                   AND pla.po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL; --This should not fail due to previous validation checks
                DoLog ('PO Line location not found : should not get here');
        END;

        DoLog (
               'updating attribute fields for line location id : '
            || ln_line_location_id);

        --Run other PO field updates

        IF pv_ship_method IS NOT NULL
        THEN
            DoLog ('Updating ship_method : ' || pv_ship_method);

            UPDATE po_line_locations_all plla
               SET attribute10 = pv_ship_method, last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035

            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        IF pv_freight_pay_party IS NOT NULL
        THEN
            DoLog ('Updating freight pay party : ' || pv_freight_pay_party);

            UPDATE po_line_locations_all
               SET attribute7 = pv_freight_pay_party, last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035

            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        --CCR0009609
        BEGIN
            SELECT attribute15
              INTO ln_attribute15
              FROM po_lines_all
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog (
                    ' failed to fetch attribute15 for line_id : ' || SQLERRM);
        END;

        IF ln_attribute15 IS NULL
        THEN
            -- Updating attribute15 with Original line quantity
            BEGIN
                UPDATE po_lines_all
                   SET attribute15 = ln_original_line_qty, last_update_date = SYSDATE
                 WHERE po_line_id =
                       (SELECT po_line_id
                          FROM apps.po_line_locations_all
                         WHERE     line_location_id = ln_line_location_id
                               AND ROWNUM = 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    DoLog (
                           'Updating attribute15 failed for line_id : '
                        || SQLERRM);
            END;
        END IF;

        --CCR0009609

        IF     pd_cxf_date IS NOT NULL
           AND ((pd_cxf_date != ld_cxf_date) OR ld_cxf_date IS NULL)
        THEN
            DoLog (
                   'Updating conf ex factory date : '
                || TO_CHAR (pd_cxf_date, 'MM/DD/YYYY'));

            --Rev1
            --Also update Orig CFX date if not populated

            UPDATE po_line_locations_all
               SET attribute8 = NVL (attribute5, TO_CHAR (pd_cxf_date, 'YYYY/MM/DD')), last_update_date = SYSDATE -- Added for CCR0006035
             WHERE     line_location_id = ln_line_location_id
                   AND attribute8 IS NULL;

            UPDATE po_line_locations_all
               SET attribute5 = TO_CHAR (pd_cxf_date, 'YYYY/MM/DD'), last_update_date = SYSDATE -- Added for CCR0006035
             WHERE line_location_id = ln_line_location_id;

            -- Added for CCR0006035

            UPDATE po_lines_all
               SET last_update_date   = SYSDATE
             WHERE po_line_id =
                   (SELECT po_line_id
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id = ln_line_location_id
                           AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        IF pv_supplier_site_code IS NOT NULL
        THEN
            DoLog ('Updating supplier site code : ' || pv_supplier_site_code);

            --Update DFF in PO Line

            UPDATE po_lines_all
               SET attribute7 = pv_supplier_site_code, last_update_date = SYSDATE
             WHERE     NVL (attribute7, 'NONE') != pv_supplier_site_code
                   AND po_line_id =
                       (SELECT po_line_id
                          FROM apps.po_line_locations_all
                         WHERE     line_location_id = ln_line_location_id
                               AND ROWNUM = 1);

            lb_po_update_flag   := TRUE;
        END IF;

        --Rev3 : only set POC negotiation flag if an update above occurred
        IF lb_po_update_flag
        THEN
            BEGIN
                DoLog ('Update attribute 11 and 13');

                UPDATE apps.po_lines_all               -- POC Negotiation flag
                   SET attribute13 = 'True', attribute11 = NVL (ln_unit_price, ln_orig_unit_price) - (NVL (attribute8, 0) + NVL (attribute9, 0)), last_update_date = SYSDATE -- Added for CCR0006035
                 WHERE     line_num = pn_line_num
                       AND po_header_id = (SELECT po_header_id
                                             FROM apps.po_headers_all
                                            WHERE segment1 = pv_po_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_msg   :=
                        'Error while updating POC Negotiation flag in update po line proc';
                    RAISE ex_update;
            END;
        ELSE
            DoLog ('No PO update for this line');
        END IF;

        DoLog ('update_po_line : PO Line update complete');

        pv_error_msg       := '';
        pv_error_stat      := 'S';
        DoLog ('update_po_line : Exit');
    EXCEPTION
        WHEN ex_validation
        THEN
            DoLog ('update_po_line : validation Exception' || pv_msg);
            pv_error_msg    := pv_msg;
            pv_error_stat   := 'E';
        WHEN ex_login
        THEN
            pv_error_msg    := 'Login error: ' || pv_msg;
            pv_error_stat   := 'E';
            DoLog ('update_po_line : ex_login ' || pv_error_msg);
        WHEN ex_update
        THEN
            pv_error_msg    := 'Update error : ' || pv_msg;
            pv_error_stat   := 'E';
            DoLog ('update_po_line : ex_update ' || pv_error_msg);
        WHEN OTHERS
        THEN
            pv_error_msg    := SQLERRM;
            pv_error_stat   := 'U';
            DoLog ('update_po_line : unexpected error :: ' || SQLERRM);
    END;

    PROCEDURE update_stg_po_columns (pv_po_number IN VARCHAR2)
    IS
    BEGIN
        --Assumption that the req_line_id field in the stage record points to the REQ line sourcing the PO line
        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
           SET po_header_id   =
                   (SELECT plla.po_header_id
                      FROM po_line_locations_all plla, po_requisition_lines_all prla
                     WHERE     plla.line_location_id = prla.line_location_id
                           AND prla.requisition_line_id = stg.req_line_id),
               po_line_id   =
                   (SELECT plla.po_line_id
                      FROM po_line_locations_all plla, po_requisition_lines_all prla
                     WHERE     plla.line_location_id = prla.line_location_id
                           AND prla.requisition_line_id = stg.req_line_id),
               po_line_location_id   =
                   (SELECT prla.line_location_id
                      FROM po_requisition_lines_all prla
                     WHERE prla.requisition_line_id = stg.req_line_id),
               line_num   =
                   (SELECT pla.line_num
                      FROM po_lines_all pla, po_line_locations_all plla, po_requisition_lines_all prla
                     WHERE     pla.po_line_id = plla.po_line_id
                           AND plla.line_location_id = prla.line_location_id
                           AND prla.requisition_line_id = stg.req_line_id),
               po_number   =
                   (SELECT pha.segment1
                      FROM po_headers_all pha, po_line_locations_all plla, po_requisition_lines_all prla
                     WHERE     pha.po_header_id = plla.po_header_id
                           AND plla.line_location_id = prla.line_location_id
                           AND prla.requisition_line_id = stg.req_line_id),
               shipment_num   =
                   (SELECT shipment_num
                      FROM po_line_locations_all plla, po_requisition_lines_all prla
                     WHERE     plla.line_location_id = prla.line_location_id
                           AND prla.requisition_line_id = stg.req_line_id)
         WHERE from_po_number = pv_po_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            --NULL;
            dolog ('Error in Procedure update_stg_po_columns :: ' || SQLERRM); -- CCR0006517
    END;

    --Begin CCR0008134
    --Depreciated as we are not appending lines to same PO
    /*
       PROCEDURE run_autocreate_docs (pn_batch_id       IN     NUMBER,
                                      pn_org_id         IN     NUMBER,
                                      pn_user_id        IN     NUMBER,
                                      pn_po_header_id   IN     NUMBER,
                                      pv_error_stat        OUT VARCHAR2,
                                      pv_error_msg         OUT VARCHAR2)
       IS
          l_return_status          VARCHAR2 (1);
          l_msg_count              NUMBER;
          l_msg_data               VARCHAR2 (2000) := NULL;
          x_num_lines_processed    NUMBER;
          ln_po_header_id          NUMBER;
          l_document_number        apps.PO_HEADERS_ALL.segment1%TYPE;
          ln_requisition_line_id   NUMBER;
          ln_line_num              NUMBER;
          ln_cnt                   NUMBER;
       BEGIN
          DoLog ('Autocreate Docs ' || pn_batch_id);

          SELECT COUNT (*)
            INTO ln_cnt
            FROM po_headers_interface
           WHERE batch_id = pn_batch_id;

          DoLog ('Header recs ' || ln_cnt);

          APPS.PO_INTERFACE_S.create_documents (
             p_api_version                => 1.0,
             x_return_status              => l_return_status,
             x_msg_count                  => l_msg_count,
             x_msg_data                   => l_msg_data,
             p_batch_id                   => pn_batch_id,
             p_req_operating_unit_id      => pn_org_id,
             p_purch_operating_unit_id    => pn_org_id,
             x_document_id                => ln_po_header_id,
             x_number_lines               => x_num_lines_processed,
             x_document_number            => l_document_number,
             -- Bug 3648268 Use lookup code instead of hardcoded value
             p_document_creation_method   => 'AUTOCREATE',            -- <DBI FPJ>
             p_orig_org_id                => pn_org_id                --<R12 MOAC>
                                                      );
          DoLog ('Autocreate return stat : ' || l_return_status);
          DoLog ('Autocreate return msg : ' || l_msg_data);

          IF l_return_status <> 'S'
          THEN
             pv_error_stat := 'E';
             pv_error_msg := 'Autocreate failed : ' || l_msg_data;
             dolog (pv_error_msg);                                   -- CCR0006517
             RETURN;
          END IF;


          DoLog ('Approve PO : ' || l_document_number);

          approve_po (pv_po_number    => l_document_number,
                      pn_user_id      => pn_user_id,
                      pv_error_stat   => PV_ERROR_STAT,
                      pv_error_msg    => PV_ERROR_MSG);
          DoLog (
                'After approve PO : '
             || l_document_number
             || ' Stat : '
             || PV_ERROR_STAT);


          --Update the stage table PO columns to capture added PO lines.
          update_stg_po_columns (l_document_number);

          pv_error_stat := 'S';
          pv_error_msg := '';
       EXCEPTION
          WHEN OTHERS
          THEN
             pv_error_stat := 'U';
             pv_error_msg := SQLERRM;
             dolog ('Error in Procedure run_autocreate_docs :: ' || SQLERRM);
       END;
    */
    --End CCR0008134

    PROCEDURE update_drop_ship (p_batch_id IN NUMBER)
    IS
        CURSOR cur_update_drop_ship IS
            SELECT DISTINCT phi.po_header_id, pli.po_line_id, plli.line_location_id,
                            porh.requisition_header_id, porl.requisition_line_id
              FROM po_requisition_headers_all porh, po_requisition_lines_all porl, po_line_locations_interface plli,
                   po_lines_interface pli, po_headers_interface phi, po_headers_all poh,
                   oe_drop_ship_sources oedss
             WHERE     porh.requisition_header_id =
                       porl.requisition_header_id
                   AND oedss.requisition_line_id = porl.requisition_line_id
                   AND porl.line_location_id = plli.line_location_id
                   AND plli.interface_line_id = pli.interface_line_id
                   AND pli.interface_header_id = phi.interface_header_id
                   AND phi.po_header_id = poh.po_header_id
                   AND phi.batch_id = p_batch_id;

        v_dropship_return_status   VARCHAR2 (50);
        v_dropship_Msg_Count       VARCHAR2 (50);
        v_dropship_Msg_data        VARCHAR2 (50);
    BEGIN
        DoLog ('--Update Drop Ship : Enter');

        FOR CUR_UPDATE_DROP_SHIP_REC IN CUR_UPDATE_DROP_SHIP
        LOOP
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
                    P_PO_Header_Id    => cur_update_drop_ship_rec.PO_HEADER_ID,
                    P_PO_Line_Id      => cur_update_drop_ship_rec.PO_LINE_ID,
                    P_Line_Location_ID   =>
                        cur_update_drop_ship_rec.LINE_LOCATION_ID);

                IF (v_dropship_return_status = FND_API.g_ret_sts_success)
                THEN
                    DoLog ('drop ship successs' || CHR (10));


                    UPDATE PO_LINE_LOCATIONS_ALL PLLA
                       SET SHIP_TO_LOCATION_ID   =
                               (SELECT DISTINCT PORL.DELIVER_TO_LOCATION_ID
                                  FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL
                                 WHERE     PORH.REQUISITION_HEADER_ID =
                                           PORL.REQUISITION_HEADER_ID
                                       AND PLLA.LINE_LOCATION_ID =
                                           PORL.LINE_LOCATION_ID
                                       AND PORL.LINE_LOCATION_ID =
                                           CUR_UPDATE_DROP_SHIP_REC.LINE_LOCATION_ID)
                     WHERE PLLA.LINE_LOCATION_ID =
                           CUR_UPDATE_DROP_SHIP_REC.LINE_LOCATION_ID;

                    COMMIT;
                ELSIF v_dropship_return_status = (FND_API.G_RET_STS_ERROR)
                THEN
                    FOR i IN 1 .. FND_MSG_PUB.count_msg
                    LOOP
                        DoLog (
                            'DROP SHIP api ERROR:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                    END LOOP;
                ELSIF v_dropship_return_status =
                      FND_API.G_RET_STS_UNEXP_ERROR
                THEN
                    FOR i IN 1 .. FND_MSG_PUB.count_msg
                    LOOP
                        DoLog (
                            'DROP SHIP UNEXPECTED ERROR:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                    END LOOP;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DoLog ('drop ship when others');
            END;
        END LOOP;

        DoLog ('--Update Drop Ship : Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            DoLog ('--Update Drop Ship : Exception ' || SQLERRM);
    END;

    PROCEDURE create_std_po (pn_batch_id IN NUMBER, pn_org_id IN NUMBER, pv_error_stat OUT VARCHAR2
                             , pv_error_msg OUT VARCHAR2)
    IS
        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);

        v_return_status            VARCHAR2 (20);
    BEGIN
        APPS.PO_PDOI_PVT.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => FND_API.G_TRUE,
            p_validation_level             => NULL,
            p_commit                       => FND_API.G_FALSE,
            x_return_status                => v_return_status,
            p_gather_intf_tbl_stat         => 'N',
            p_calling_module               => NULL,
            p_selected_batch_id            => pn_batch_id,
            p_batch_size                   => NULL,
            p_buyer_id                     => NULL,
            p_document_type                => 'STANDARD',
            p_document_subtype             => NULL,
            p_create_items                 => 'N',
            p_create_sourcing_rules_flag   => 'N',
            p_rel_gen_method               => NULL,
            p_sourcing_level               => NULL,
            p_sourcing_inv_org_id          => NULL,
            p_approved_status              => 'APPROVED',
            p_process_code                 => NULL,
            p_interface_header_id          => NULL,
            p_org_id                       => pn_org_id,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_group_lines                  => 'N',
            p_group_shipments              => 'N',
            p_clm_flag                     => NULL,         --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);


        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'Check PO import error in Dist POI ' || v_return_status);

        --Check for process error
        --If this process fails then we need to exit
        IF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'CREATE api error in Dist POI :' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                pv_error_msg   :=
                       pv_error_msg
                    || 'CREATE api error in Dist POI:'
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            pv_error_stat   := 'E';
            RETURN;
        ELSIF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG, 'Dist POI Error = ''E''');
            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Count Dist POI ' || FND_MSG_PUB.count_msg);

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                       'CREATE API UNEXPECTED ERROR in Dist POI :'
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));

                pv_error_msg   :=
                    SUBSTR (
                           pv_error_msg
                        || 'CREATE API UNEXPECTED ERROR in Dist POI :'
                        || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'),
                        1,
                        200);
            END LOOP;

            pv_error_stat   := 'E';
            RETURN;
        END IF;

        --Fix Drop ship links for Dist type POs
        update_drop_ship (pn_batch_id);

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    --Run standard PO import to create a PO from posted PO interface records
    --Begin CCR0008134
    --Depreciated as we are using different API
    /*
       PROCEDURE run_std_po_import (pn_batch_id     IN     NUMBER,
                                    pn_org_id       IN     NUMBER,
                                    pn_user_id      IN     NUMBER,
                                    pn_request_id      OUT NUMBER,
                                    pv_error_stat      OUT VARCHAR2,
                                    pv_error_msg       OUT VARCHAR2)
       IS
          l_phase          VARCHAR2 (80);
          l_req_status     BOOLEAN;
          l_status         VARCHAR2 (80);
          l_dev_phase      VARCHAR2 (80);
          l_dev_status     VARCHAR2 (80);
          l_message        VARCHAR2 (255);
          l_data           VARCHAR2 (200);

          ln_user_id       NUMBER;

          ln_req_status    BOOLEAN;

          x_ret_stat       VARCHAR2 (1);
          x_error_text     VARCHAR2 (20000);
          ln_employee_id   NUMBER;
          ln_def_user_id   NUMBER;

          ex_login         EXCEPTION;
       BEGIN
          pn_request_id := -1;
          DoLog ('run_std_po_import - Enter');
          DoLog ('Batch ID : ' || pn_batch_id);

          --If user ID not passed, pull defalt user for this type of transaction
          SELECT user_id
            INTO ln_def_user_id
            FROM fnd_user
           WHERE user_name = gBatchP2P_User;

          --Check pased in user
          BEGIN
             SELECT employee_id
               INTO ln_employee_id
               FROM fnd_user
              WHERE user_id = pn_user_id;

             DoLog ('Emloyee ID : ' || ln_employee_id);

             IF ln_employee_id IS NULL
             THEN
                ln_user_id := ln_def_user_id;
             ELSE
                ln_user_id := pn_user_id;
             END IF;
          EXCEPTION
             WHEN NO_DATA_FOUND
             THEN
                ln_user_id := ln_def_user_id;
          END;


          DoLog ('before set_purchasing_context');
          DoLog ('     USER_ID : ' || ln_user_id);
          DoLog ('     ORG_ID : ' || pn_org_id);

          set_purchasing_context (ln_user_id,
                                  pn_org_id,
                                  pv_error_stat,
                                  pv_error_msg);

          IF pv_error_stat <> 'S'
          THEN
             RAISE ex_login;
          END IF;

          pn_request_id :=
             apps.fnd_request.submit_request (
                application   => 'PO',
                program       => 'POXPOPDOI',
                argument1     => '',
                argument2     => 'STANDARD',
                argument3     => '',
                argument4     => 'Y',
                argument5     => '',
                argument6     => 'APPROVED',
                argument7     => '',
                argument8     => TO_CHAR (pn_batch_id),
                argument9     => TO_CHAR (pn_org_id),
                argument10    => '',
                argument11    => '',
                argument12    => '',
                argument13    => '');
          DoLog (pn_request_id);

          COMMIT;
          DoLog ('poxpopdoi - wait for request - Request ID :' || pn_request_id);
          ln_req_status :=
             apps.fnd_concurrent.wait_for_request (request_id   => pn_request_id,
                                                   interval     => 10,
                                                   max_wait     => 0,
                                                   phase        => l_phase,
                                                   status       => l_status,
                                                   dev_phase    => l_dev_phase,
                                                   dev_status   => l_dev_status,
                                                   MESSAGE      => l_message);


          DoLog ('poxpopdoi - after wait for request -  ' || l_dev_status);

          IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
          THEN
             IF NVL (l_dev_status, 'ERROR') = 'WARNING'
             THEN
                x_ret_stat := 'W';
             ELSE
                x_ret_stat := apps.fnd_api.g_ret_sts_error;
             END IF;

             x_error_text :=
                NVL (
                   l_message,
                      'The poxpopdoi request ended with a status of '
                   || NVL (l_dev_status, 'ERROR'));
             pv_error_stat := x_ret_stat;
             pv_error_msg := x_error_text;
          END IF;

          --Fix Drop ship links for Dist type POs
          update_drop_ship (pn_batch_id);

          DoLog ('run_std_po_import - Exit');
       EXCEPTION
          WHEN ex_login
          THEN
             pv_error_stat := 'E';
             pv_error_msg := 'Unable to set purchasing context';
             dolog ('Error in Procedure run_std_po_import :: ' || pv_error_msg); -- CCR0006517
          WHEN OTHERS
          THEN
             pv_error_stat := 'U';
             pv_error_msg :=
                'Unexpected error occurred in run_std_po_import.' || SQLERRM;
             dolog (pv_error_msg);                                   -- CCR0006517
       END;
       */
    --End CCR0008134

    -- START CCR0006517

    PROCEDURE check_program_status (pv_conc_short_name IN VARCHAR2, pv_hold_flag IN VARCHAR2, pv_request_id IN OUT NUMBER
                                    , pv_argument1 IN VARCHAR2)
    IS
        lv_exists                  VARCHAR2 (10) := 'N';
        lv_phase_code              VARCHAR2 (20);
        lv_request_id_prev         NUMBER;
        lv_request_id_curr         NUMBER;
        lv_concurrent_program_id   NUMBER;
        l_num_oeimp_req_id         NUMBER;
        l_bool_result              BOOLEAN;
        l_var_phase                VARCHAR2 (100);
        l_var_status               VARCHAR2 (100);
        l_var_dev_phase            VARCHAR2 (100);
        l_var_dev_status           VARCHAR2 (100);
        l_var_message              VARCHAR2 (100);
    BEGIN
        DOLOG ('Pending Hold Request Id :: ' || pv_request_id);
        DOLOG ('Hold Flag :: ' || pv_hold_flag);

        IF pv_hold_flag IS NULL AND pv_request_id IS NULL
        THEN
            BEGIN
                SELECT 'Y', fcr.phase_code, fcr.REQUEST_ID,
                       fcp.concurrent_program_id
                  INTO lv_exists, lv_phase_code, lv_request_id_prev, lv_concurrent_program_id
                  FROM fnd_concurrent_requests fcr, fnd_concurrent_programs fcp
                 WHERE     fcr.concurrent_program_id =
                           fcp.concurrent_program_id
                       AND fcr.phase_code <> 'C'
                       AND fcp.concurrent_program_name = pv_conc_short_name
                       AND NVL (fcr.argument1, '-XXX') =
                           NVL (pv_argument1, '-XXX')
                       AND requested_start_date IN
                               (SELECT MIN (requested_start_date)
                                  FROM fnd_concurrent_requests fcr1
                                 WHERE     fcr.concurrent_program_id =
                                           fcr1.concurrent_program_id
                                       AND fcr1.phase_code <> 'C'
                                       AND NVL (fcr1.argument1, '-XXX') =
                                           NVL (pv_argument1, '-XXX'))
                       AND ROWNUM = 1;

                DoLog (
                       'Entered into CHECK_PROGRAM_STATUS scheduled program :: '
                    || pv_conc_short_name
                    || ' :: '
                    || ' phase code : '
                    || lv_phase_code
                    || ' '
                    || lv_request_id_prev
                    || '   '
                    || lv_concurrent_program_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_exists   := 'N';
                WHEN OTHERS
                THEN
                    lv_exists   := 'N';
                    DOLOG (
                           'Error in finding the scheduled program :: '
                        || SQLERRM);
            END;

            IF lv_exists = 'Y'
            THEN
                IF lv_phase_code = 'R'
                THEN
                    LOOP
                        l_bool_result   :=
                            fnd_concurrent.wait_for_request (
                                lv_request_id_prev,
                                5,
                                86400,
                                l_var_phase,
                                l_var_status,
                                l_var_dev_phase,
                                l_var_dev_status,
                                l_var_message);

                        IF l_bool_result AND l_var_dev_phase = 'COMPLETE'
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                ELSIF lv_phase_code = 'P'
                THEN
                    UPDATE fnd_concurrent_requests
                       SET hold_flag = 'Y', last_update_date = SYSDATE, last_updated_by = apps.fnd_global.user_id
                     WHERE     phase_code = 'P'
                           AND concurrent_program_id =
                               lv_concurrent_program_id
                           AND hold_flag = 'N'
                           AND request_id = lv_request_id_prev;

                    pv_request_id   := lv_request_id_prev;

                    COMMIT;
                END IF;
            END IF;
        ELSIF pv_hold_flag IS NOT NULL AND pv_request_id IS NOT NULL
        THEN
            dolog ('Entered condition to release hold');

            UPDATE fnd_concurrent_requests
               SET hold_flag = 'N', last_update_date = SYSDATE
             WHERE     phase_code = 'P'
                   AND hold_flag = 'Y'
                   AND request_id = pv_request_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            dolog ('Error in Procedure Check_program_status :: ' || SQLERRM);
    END;

    -- END CCR0006517

    PROCEDURE create_tq_po_from_pr (pn_req_header_id IN NUMBER, pv_po_number OUT VARCHAR2, PV_ERROR_STAT OUT VARCHAR2
                                    , PV_ERROR_MSG OUT VARCHAR2)
    IS
        CURSOR c_lines IS
            SELECT prla.requisition_line_id, prla.quantity, pla.unit_price,
                   plla.promised_date, plla.need_by_date, prla.drop_ship_flag,
                   pla.attribute_category line_attribute_category, pla.attribute1 line_attribute1, pla.attribute2 line_attribute2,
                   pla.attribute7 line_attribute7, pla.attribute8 line_attribute8, pla.attribute9 line_attribute9,
                   pla.attribute14 line_attribute14, plla.attribute_category shipment_attribute_category, plla.attribute4 shipment_attribute4,
                   plla.attribute6 shipment_attribute6, plla.attribute8 shipment_attribute8, plla.attribute10 shipment_attribute10,
                   plla.attribute11 shipment_attribute11, plla.attribute12 shipment_attribute12, plla.attribute13 shipment_attribute13,
                   plla.attribute14 shipment_attribute14
              FROM po_requisition_lines_all prla, po_lines_all pla, po_line_locations_all plla
             WHERE     requisition_header_id = pn_req_header_id
                   AND prla.attribute15 = pla.po_line_id
                   AND pla.po_line_id = plla.po_line_id;

        ln_po_import_batch_id    NUMBER;
        ln_header_interface_id   NUMBER;
        ln_line_interface_id     NUMBER;
        ln_employee_id           NUMBER;
        ln_user_id               NUMBER;

        --Header variables
        ln_org_id                NUMBER;
        ln_vendor_id             NUMBER;
        ln_vendor_site_id        NUMBER;
        lv_src_po_number         VARCHAR2 (50);
        lv_attribute_category    VARCHAR2 (240);
        lv_attribute1            VARCHAR2 (240);
        lv_attribute8            VARCHAR2 (240);
        lv_attribute9            VARCHAR2 (240);
        lv_attribute10           VARCHAR2 (240);
        lv_attribute11           VARCHAR2 (240);
        ln_created_by            NUMBER;
        ln_agent_id              NUMBER;
        ln_ship_to_location_id   NUMBER;



        ex_login                 EXCEPTION;
    BEGIN
        DoLog ('create_tq_po_from_pr - Enter');

        --Get next batch ID
        SELECT PO_CONTROL_GROUPS_S.NEXTVAL
          INTO ln_po_import_batch_id
          FROM DUAL;

        DoLog (' ln_po_import_batch_id : ' || ln_po_import_batch_id);

        --TODO : Do we need this at this point?
        /*   set_purchasing_context (ln_user_id,
                                   h_rec.org_id,
                                   pv_error_stat,
                                   pv_error_msg);*/

        --DoLog ('after set_purchasing_context. Result :' || pv_error_stat);

        /*   IF pv_error_stat <> 'S'
           THEN
              RAISE ex_login;
           END IF;*/


        SELECT PO_HEADERS_INTERFACE_S.NEXTVAL
          INTO ln_header_interface_id
          FROM DUAL;

        DoLog (' ln_header_interface_id : ' || ln_header_interface_id);

        BEGIN
            SELECT prha.org_id, pha.vendor_id, pha.vendor_site_id,
                   pha.segment1 src_po_number, pha.attribute_category, pha.attribute1,
                   pha.attribute8, pha.attribute9, pha.attribute10,
                   pha.attribute11, pha.created_by, pha.agent_id,
                   pha.ship_to_location_id, pha.attribute_category
              INTO ln_org_id, ln_vendor_id, ln_vendor_site_id, lv_src_po_number,
                            lv_attribute_category, lv_attribute1, lv_attribute8,
                            lv_attribute9, lv_attribute10, lv_attribute11,
                            ln_created_by, ln_agent_id, ln_ship_to_location_id,
                            lv_attribute_category
              FROM po_requisition_headers_all prha, po_headers_all pha
             WHERE     requisition_header_id = pn_req_header_id
                   AND prha.attribute15 = pha.po_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                dolog ('REQ Header not found for ' || pn_req_header_id);
                PV_ERROR_STAT   := 'E;';
                PV_ERROR_MSG    :=
                    'REQ Header not found for ' || pn_req_header_id;
            WHEN OTHERS
            THEN
                dolog ('Unexpected error. ' || SQLERRM);
                PV_ERROR_STAT   := 'E;';
                PV_ERROR_MSG    := SQLERRM;
        END;

        DoLog ('After header fields fetch');


        --Insert into POI header
        INSERT INTO po_headers_interface (INTERFACE_HEADER_ID, BATCH_ID, ORG_ID, --  INTERFACE_SOURCE_CODE ,
                                                                                 ACTION, -- (ORIGINAL,UPDATE,REPLACE;)
                                                                                         GROUP_CODE, DOCUMENT_TYPE_CODE, CURRENCY_CODE, AGENT_ID, VENDOR_ID, VENDOR_SITE_ID, SHIP_TO_LOCATION_ID, BILL_TO_LOCATION, PAYMENT_TERMS, APPROVAL_STATUS, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, COMMENTS, ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10
                                          , ATTRIBUTE11, ATTRIBUTE14) --PO Number sourcing this PO
             VALUES (ln_header_interface_id, ln_po_import_batch_id, ln_org_id, 'ORIGINAL', --action
                                                                                           NULL, --group_code,
                                                                                                 'STANDARD', --document_type_code
                                                                                                             NULL, --Currency_code
                                                                                                                   ln_agent_id, --agent_id --employee for req.preparer ID
                                                                                                                                ln_vendor_id, ln_vendor_site_id, --NULL, --h_rec.Ship_to_location_id,-- Populate from REQ deliver_to_location_id
                                                                                                                                                                 ln_ship_to_location_id, --h_rec.Ship_to_location_id,                 -- CCR0006035
                                                                                                                                                                                         NULL, --Bill_to_location (get from ship_to_location
                                                                                                                                                                                               NULL, --Payment_term
                                                                                                                                                                                                     'APPROVED', ln_user_id, SYSDATE, ln_user_id, SYSDATE, 'Created from purchase order # ' || lv_src_po_number, lv_attribute_category, lv_attribute1, lv_attribute8, lv_attribute9, lv_attribute10
                     , lv_attribute11, lv_src_po_number);

        dolog ('After insert header');

        FOR l_rec IN c_lines
        LOOP
            SELECT PO_LINES_INTERFACE_S.NEXTVAL
              INTO ln_line_interface_id
              FROM DUAL;

            DoLog (' ln_line_interface_id : ' || ln_line_interface_id);

            --Insert into POI lines
            INSERT INTO po_lines_interface (INTERFACE_LINE_ID,
                                            INTERFACE_HEADER_ID,
                                            ACTION,
                                            LINE_TYPE,
                                            --  ITEM_ID,
                                            REQUISITION_LINE_ID,
                                            QUANTITY,
                                            UNIT_PRICE,
                                            SHIP_TO_LOCATION_ID,
                                            NEED_BY_DATE,
                                            --  PROMISED_DATE,
                                            LIST_PRICE_PER_UNIT,
                                            CREATED_BY,
                                            CREATION_DATE,
                                            LAST_UPDATED_BY,
                                            LAST_UPDATE_DATE,
                                            DROP_SHIP_FLAG,
                                            LINE_ATTRIBUTE_CATEGORY_LINES,
                                            LINE_ATTRIBUTE1,
                                            LINE_ATTRIBUTE2,
                                            LINE_ATTRIBUTE7,
                                            LINE_ATTRIBUTE8,
                                            LINE_ATTRIBUTE9,
                                            --   LINE_ATTRIBUTE11,
                                            LINE_ATTRIBUTE14,
                                            SHIPMENT_ATTRIBUTE_CATEGORY,
                                            --  SHIPMENT_ATTRIBUTE4,
                                            SHIPMENT_ATTRIBUTE6,
                                            SHIPMENT_ATTRIBUTE8,
                                            SHIPMENT_ATTRIBUTE11,
                                            SHIPMENT_ATTRIBUTE12,
                                            SHIPMENT_ATTRIBUTE13,
                                            SHIPMENT_ATTRIBUTE14)
                     VALUES (ln_line_interface_id,
                             ln_header_interface_id,
                             'ORIGINAL',                              --Action
                             NULL,          --Line type (get proper line type)
                             --   l_rec.item_id,
                             l_rec.requisition_line_id,
                             --    NULL,                                             --UOM,
                             l_rec.quantity,
                             l_rec.unit_price,
                             ln_ship_to_location_id, --NULL, --l_rec.Ship_to_location_id,-- popoulate from REQ deliver_to_location_id
                             l_rec.need_by_date,
                             -- l_rec.new_promised_date,
                             l_rec.unit_price,
                             ln_user_id,
                             SYSDATE,
                             ln_user_id,
                             SYSDATE,
                             l_rec.drop_ship_flag,
                             l_rec.line_attribute_category,
                             l_rec.line_attribute1,
                             l_rec.line_attribute2,
                             l_rec.line_attribute7,
                             l_rec.line_attribute8,
                             l_rec.line_attribute9,
                             -- lv_new_line_attribute11,
                             l_rec.line_attribute14,
                             l_rec.shipment_attribute_category,
                             -- lv_shipment_attribute4,
                             l_rec.shipment_attribute6,
                             l_rec.shipment_attribute8,
                             l_rec.shipment_attribute11,
                             l_rec.shipment_attribute12,
                             l_rec.shipment_attribute13,
                             l_rec.shipment_attribute14);
        END LOOP;

        dolog ('Create std PO ' || ln_po_import_batch_id);

        --Run PO create process
        create_std_po (pn_batch_id => ln_po_import_batch_id, pn_org_id => ln_org_id, pv_error_stat => PV_ERROR_STAT
                       , pv_error_msg => PV_ERROR_MSG);

        --check for created PO
        dolog ('Create std PO ' || PV_ERROR_STAT);

        IF pv_error_stat = 'S'
        THEN
            BEGIN
                --Get from POI
                SELECT DISTINCT segment1
                  INTO pv_po_number
                  FROM po_headers_all
                 WHERE po_header_id IN
                           (SELECT po_header_id
                              FROM po_headers_interface
                             WHERE interface_header_id =
                                   ln_header_interface_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        --Get from linked requisition header
                        SELECT DISTINCT segment1
                          INTO pv_po_number
                          FROM po_headers_all pha, po_line_locations_all plla, po_requisition_lines_all prla
                         WHERE     pha.po_header_id = plla.po_header_id
                               AND plla.line_location_id =
                                   prla.line_location_id
                               AND prla.requisition_header_id =
                                   pn_req_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_error_msg    := 'Cannot derive PO created';
                            PV_ERROR_STAT   := 'E';
                            RETURN;
                    END;
            END;
        ELSE
            PV_ERROR_MSG    :=
                   'Failed to create PO from Requisition '
                || ln_po_import_batch_id;
            DoLog (PV_ERROR_MSG);
            PV_ERROR_STAT   := 'E';
            RETURN;
        END IF;

        DoLog ('PO created : ' || pv_po_number);
        DoLog ('create_tq_po_from_pr - Exit');

        PV_ERROR_STAT   := 'S';
    EXCEPTION
        WHEN ex_login
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Login error occurred';
            DoLog ('create_po_from_purchrec_stg ex_login : ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            DoLog ('create_tq_po_from_pr - Error' || SQLERRM);

            PV_ERROR_STAT   := 'U';
            PV_ERROR_MSG    := SQLERRM;
    END;

    PROCEDURE run_tq_recs_to_ds (pn_batch_id IN NUMBER, pv_source_code IN VARCHAR2, pv_error_stat OUT VARCHAR2
                                 , pv_error_msg OUT VARCHAR2)
    IS
        --Gets groups of recs to create requisitions
        CURSOR c_header IS
              SELECT batch_id, org_id, po_number,
                     ship_to_organization_id, new_promised_date, ex_factory_date,
                     ship_method, freight_pay_party, created_by,
                     COUNT (*) cnt_recs, SUM (quantity) total_qty
                FROM xxdo.xxdo_gtn_po_collab_stg
               WHERE     processing_status_code = 'RUNNING'
                     AND batch_id = pn_batch_id
                     AND create_req = 'Y'
                     --  AND req_created = 'N'
                     AND req_type = 'TQ'
            GROUP BY batch_id, org_id, po_number,
                     ship_to_organization_id, new_promised_date, ex_factory_date,
                     ship_method, freight_pay_party, created_by;

        --gets specific records within the group
        CURSOR c_line (n_batch_id                  NUMBER,
                       n_org_id                    NUMBER,
                       v_po_number                 VARCHAR2,
                       n_ship_to_organization_id   NUMBER,
                       d_new_promised_date         DATE,
                       d_ex_factory_date           DATE,
                       v_ship_method               VARCHAR2,
                       v_freight_pay_party         VARCHAR2)
        IS
              SELECT stg.gtn_po_collab_stg_id, stg.line_num, vw.style_number,
                     vw.color_code, vw.size_sort_code
                FROM xxdo.xxdo_gtn_po_collab_stg stg, xxd_common_items_v vw
               WHERE     stg.batch_id = n_batch_id
                     AND stg.org_id = n_org_id
                     AND stg.po_number = v_po_number
                     AND stg.ship_to_organization_id =
                         n_ship_to_organization_id
                     AND NVL (stg.new_promised_date, TRUNC (SYSDATE)) =
                         NVL (d_new_promised_date, TRUNC (SYSDATE))
                     AND stg.ex_factory_date = d_ex_factory_date
                     AND stg.ship_method = v_ship_method
                     AND stg.freight_pay_party = v_freight_pay_party
                     AND STG.ITEM_ID = vw.inventory_item_id
                     AND stg.ship_to_organization_id = vw.organization_id
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM po_requisitions_interface_all pori
                               WHERE     pori.interface_source_code =
                                         gv_source_code
                                     AND TO_CHAR (gtn_po_collab_stg_id) =
                                         pori.line_attribute14)
            ORDER BY vw.style_number, vw.color_code, vw.size_sort_code; --Do not select records already on interface

        CURSOR cur_multiple_reqs (pv_source_code         IN VARCHAR2,
                                  pv_req_import_req_id   IN NUMBER)
        IS
            SELECT prha.requisition_header_id, prla.requisition_line_id, stg.gtn_po_collab_stg_id
              FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla, xxdo.xxdo_gtn_po_collab_stg stg
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prha.interface_source_code = pv_source_code
                   AND prha.request_id = pv_req_import_req_id
                   AND prla.attribute14 = TO_CHAR (stg.gtn_po_collab_stg_id);

        ln_org_id                    NUMBER;
        ln_ship_to_organization_id   NUMBER;
        ln_po_header_id              NUMBER;
        ln_created_by                NUMBER;
        ln_request_id                NUMBER;
        ln_req_import_req_id         NUMBER;
        ln_batch_rec_id              NUMBER;
        ln_cnt                       NUMBER;
        ln_ir_org_id                 NUMBER;
        ln_ir_dest_org_id            NUMBER;

        ln_po_org_id                 NUMBER;
        ln_po_dest_org_id            NUMBER;

        ln_group_cnt                 NUMBER;
        ln_group_qty                 NUMBER;

        ln_ir_header_id              NUMBER;
        ln_ir_line_id                NUMBER;

        ln_new_iso_org_id            NUMBER;
        ln_source_inv_org_id         NUMBER;
        ln_new_cnt                   NUMBER;
        ln_new_quantity              NUMBER;
        ln_new_req_header_id         NUMBER;
        ln_new_po_header_id          NUMBER;
        lv_new_po_number             VARCHAR2 (50);
        ld_promised_date             DATE;
        ln_line_num                  NUMBER := 1;
        ln_calc_in_transit_days      NUMBER;

        ln_new_iso_number            NUMBER;
        ln_new_iso_header_id         NUMBER;

        lv_oe_error_message          VARCHAR2 (2000) := NULL;

        lv_error_msg                 VARCHAR2 (2000);
        ln_ret_code                  NUMBER;

        lv_orig_sys_document_ref     VARCHAR2 (50);
        ln_req_imp_batch_id          NUMBER := pn_batch_id;
        l_mutliple_reqs              VARCHAR2 (10) := 'N';       -- CCR0006517

        ln_new_order_number          NUMBER;
        ln_new_header_id             NUMBER;

        lv_authorization_status      VARCHAR2 (50);

        ex_update                    EXCEPTION;
        ex_header_grp_update         EXCEPTION;
    BEGIN
        DoLog ('run_tq_recs_to_ds - Enter');

        FOR header_rec IN c_header
        LOOP
            --Set header savepoint so we can rollback errors w/in the header group before req-import
            BEGIN
                SAVEPOINT sp_header;
                --Get totals for validation
                ln_group_cnt   := header_rec.cnt_recs;
                ln_group_qty   := header_rec.total_qty;

                ln_line_num    := 1;


                DoLog ('--Outer loop');
                DoLog ('Batch loop counter : ' || ln_req_imp_batch_id);
                DoLog ('PO Number:           ' || header_rec.po_number);
                DoLog (
                    'ST Org ID:           ' || header_rec.ship_to_organization_id);
                DoLog (
                       'Promised Date:       '
                    || TO_CHAR (header_rec.new_promised_date));
                DoLog ('Ship Method:         ' || header_rec.ship_method);
                DoLog (
                    'Freight Pay Party:   ' || header_rec.freight_pay_party);

                DoLog (
                       'Group Count : '
                    || ln_group_cnt
                    || ' Group Qty : '
                    || ln_group_qty);

                FOR line_rec
                    IN c_line (header_rec.batch_id,
                               header_rec.org_id,
                               header_rec.po_number,
                               header_rec.ship_to_organization_id,
                               header_rec.new_promised_date,
                               header_rec.ex_factory_date,
                               header_rec.ship_method,
                               header_rec.freight_pay_party)
                LOOP
                    DoLog ('--Inner loop');

                    --Check Promised date. If not passed then calc from the line xf date
                    IF     header_rec.new_promised_date IS NULL
                       AND header_rec.ex_factory_date IS NOT NULL
                    THEN
                        ln_calc_in_transit_days   :=
                            get_pol_transit_days (header_rec.po_number,
                                                  line_rec.line_num,
                                                  header_rec.ship_method);


                        IF NVL (ln_calc_in_transit_days, 0) = 0
                        THEN
                            doLog ('Not defined transit time');
                            PV_ERROR_MSG   :=
                                'Transit time not defined for ship method';
                            RAISE ex_header_grp_update;
                        END IF;

                        ld_promised_date   :=
                              header_rec.ex_factory_date
                            + ln_calc_in_transit_days;
                    ELSE
                        ld_promised_date   := header_rec.new_promised_date;
                    END IF;

                    doLog ('Promised Date : ' || TO_CHAR (ld_promised_date));

                    --update stage table with promised_date
                    UPDATE xxdo.xxdo_gtn_po_collab_stg
                       SET new_promised_date   = ld_promised_date
                     WHERE     gtn_po_collab_stg_id =
                               line_rec.gtn_po_collab_stg_id
                           AND new_promised_date IS NULL;


                    --insert into req interface
                    DoLog (
                        'In inner loop : Record ID : ' || line_rec.gtn_po_collab_stg_id);
                    create_req_iface_from_stg (line_rec.gtn_po_collab_stg_id,
                                               pv_source_code,
                                               ln_req_imp_batch_id,
                                               ln_line_num,
                                               PV_ERROR_STAT,
                                               PV_ERROR_MSG);

                    DoLog ('--After create_req_iface_from_stg ');
                    DoLog ('--Error Stat : ' || PV_ERROR_STAT);

                    IF PV_ERROR_STAT != 'S'
                    THEN
                        RAISE ex_header_grp_update;
                    END IF;

                    ln_batch_rec_id   := line_rec.gtn_po_collab_stg_id;

                    ln_line_num       := ln_line_num + 1;
                END LOOP;

                DoLog ('After inner loop');
                DoLog ('getting JP PO data');

                --get updates values for req: use last stg rec id in group to filter for values
                SELECT DISTINCT stg.org_id,                   --Orig PO Org ID
                                            stg.ship_to_organization_id, --Orig PO Ship to Org ID (SB 130)
                                                                         stg.created_by, --Orig PO Created by
                                pla.org_id,                  --JP TQ PO Org ID
                                            plla.ship_to_organization_id, --JP TQ PO Ship To Org ID
                                                                          pla.po_header_id --JP TQ Header ID
                  INTO ln_org_id, ln_ship_to_organization_id, ln_created_by, ln_po_org_id,
                                ln_po_dest_org_id, ln_po_header_id
                  FROM xxdo.xxdo_gtn_po_collab_stg stg, oe_order_lines_all oola, po_lines_all pla,
                       po_line_locations_all plla
                 WHERE     gtn_po_collab_stg_id = ln_batch_rec_id
                       AND stg.oe_line_id = oola.line_id
                       AND pla.po_line_id = plla.po_line_id(+)
                       AND TO_CHAR (oola.line_id) = pla.attribute5(+);

                DoLog ('PO_ORG_ID' || ln_po_org_id);
                DoLog ('PO_ST_ORG_ID' || ln_ship_to_organization_id);
                DoLog ('JP_PO_ST_ORG_ID' || ln_po_dest_org_id);

                --If created by user does not have EMP ID (this would be true for converted IRs) then replace with BATCH.O2F user
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM apps.fnd_user
                 WHERE user_id = ln_created_by AND employee_id IS NOT NULL;

                IF ln_cnt = 0
                THEN
                    SELECT user_id
                      INTO ln_created_by
                      FROM fnd_user
                     WHERE user_name = gBatchO2F_User;
                END IF;

                --Check count of created iface records
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM po_requisitions_interface_all
                 WHERE     interface_source_code = pv_source_code
                       AND destination_organization_id = ln_po_dest_org_id
                       AND batch_id = ln_req_imp_batch_id;

                DoLog ('cnt iface records         ' || ln_cnt);
                DoLog ('src_code :                ' || pv_source_code);
                DoLog ('Org_id :                  ' || ln_org_id);
                DoLog (
                       'ship_to_organization_id : '
                    || ln_ship_to_organization_id);
                DoLog ('created_by :              ' || ln_created_by);
            EXCEPTION
                WHEN ex_header_grp_update
                THEN
                    --Error in pre-rec import function. rollback inserts to REQ IFace and mark entire group as error
                    ROLLBACK TO sp_header;

                    --Loop through inner loop cursor and error out all related recors
                    FOR line_rec
                        IN c_line (header_rec.batch_id,
                                   header_rec.org_id,
                                   header_rec.po_number,
                                   header_rec.ship_to_organization_id,
                                   header_rec.new_promised_date,
                                   header_rec.ex_factory_date,
                                   header_rec.ship_method,
                                   header_rec.freight_pay_party)
                    LOOP
                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                           SET processing_status_code = 'ERROR', error_message = PV_ERROR_MSG
                         WHERE gtn_po_collab_stg_id =
                               line_rec.gtn_po_collab_stg_id;
                    END LOOP;

                    COMMIT;
                    --Continue to next group
                    CONTINUE;
                WHEN OTHERS
                THEN
                    ROLLBACK TO sp_header;

                    --Loop through inner loop cursor and error out all related recors
                    FOR line_rec
                        IN c_line (header_rec.batch_id,
                                   header_rec.org_id,
                                   header_rec.po_number,
                                   header_rec.ship_to_organization_id,
                                   header_rec.new_promised_date,
                                   header_rec.ex_factory_date,
                                   header_rec.ship_method,
                                   header_rec.freight_pay_party)
                    LOOP
                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                           SET processing_status_code = 'ERROR', error_message = 'Error' --SQLERRM
                         WHERE gtn_po_collab_stg_id =
                               line_rec.gtn_po_collab_stg_id;
                    END LOOP;

                    COMMIT;
            END;

            --REQ interface records created. Commit at this point for REQ import
            COMMIT;

            ln_req_import_req_id   := NULL;

            DoLog ('Before run_req_import');

            IF ln_cnt > 0                               --Records in REQ IFace
            THEN
                --Run req import
                run_req_import (
                    p_import_source   => pv_source_code,
                    p_batch_id        => TO_CHAR (ln_req_imp_batch_id),
                    p_org_id          => ln_po_org_id,            --ln_org_id,
                    p_inv_org_id      => ln_po_dest_org_id,
                    p_user_id         => ln_created_by,
                    p_status          => PV_ERROR_STAT,
                    p_msg             => PV_ERROR_MSG,
                    p_request_id      => ln_req_import_req_id);

                DoLog ('After run_req_import');
                DoLog ('Status : ' || PV_ERROR_STAT);
                DoLog ('Msg : ' || PV_ERROR_MSG);
                DoLog ('Request_id : ' || ln_req_import_req_id);

                --Handle errors from req import
                --Fail all records for thie REQ import request and continue to next group
                IF PV_ERROR_STAT <> 'S'
                THEN
                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                       SET processing_status_code = 'ERROR', error_message = 'REQ IMPORT failed for JP PR group. Error :' || PV_ERROR_MSG
                     WHERE gtn_po_collab_stg_id IN
                               (SELECT line_attribute14
                                  FROM po_requisitions_interface_all
                                 WHERE     batch_id = ln_req_imp_batch_id
                                       AND interface_source_code =
                                           pv_source_code
                                       AND org_id = ln_po_org_id);

                    COMMIT;
                    CONTINUE;
                END IF;
            ELSE
                --Loop through inner loop cursor and error out all related recors
                FOR line_rec
                    IN c_line (header_rec.batch_id,
                               header_rec.org_id,
                               header_rec.po_number,
                               header_rec.ship_to_organization_id,
                               header_rec.new_promised_date,
                               header_rec.ex_factory_date,
                               header_rec.ship_method,
                               header_rec.freight_pay_party)
                LOOP
                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                       SET processing_status_code = 'ERROR', error_message = 'Requisition Interface records not created for one or more records in group' --SQLERRM
                     WHERE gtn_po_collab_stg_id =
                           line_rec.gtn_po_collab_stg_id;
                END LOOP;

                COMMIT;
                CONTINUE;
            END IF;                                               --REQ import

            --Update req status after req create confirm
            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
               SET req_created   = 'Y'
             WHERE     create_req = 'Y'
                   AND req_created = 'N'
                   AND req_type = 'TQ'
                   AND batch_id = pn_batch_id
                   AND processing_status_code != 'ERROR'
                   AND gtn_po_collab_stg_id IN
                           (SELECT prla.attribute14
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prha.requisition_header_id =
                                       prla.requisition_header_id
                                   AND prha.interface_source_code =
                                       pv_source_code
                                   AND prha.org_id = ln_po_org_id
                                   AND prha.request_id = ln_req_import_req_id);

            --Get the req header ID created and the count of created records

            IF ln_req_import_req_id IS NOT NULL
            THEN
                l_mutliple_reqs   := 'N';                        -- CCR0006517

                BEGIN
                      SELECT COUNT (*), prha.requisition_header_id
                        INTO ln_cnt, ln_new_req_header_id
                        FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla
                       WHERE     prha.requisition_header_id =
                                 prla.requisition_header_id
                             AND prha.interface_source_code = pv_source_code
                             AND prha.request_id = ln_req_import_req_id
                    GROUP BY prha.requisition_header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        --TODO : No recs created (REQ Import faied to generate a requisition)
                        NULL;
                    WHEN TOO_MANY_ROWS
                    THEN
                        dolog (
                               'Multiple Requisitions Created for Request id :: '
                            || ln_req_import_req_id);
                        l_mutliple_reqs   := 'Y';                -- CCR0006517
                    WHEN OTHERS
                    THEN
                        dolog (
                            'Error in Fetching Req Header Id :: ' || SQLERRM);
                END;

                IF ln_cnt != ln_group_cnt
                THEN
                    --Mismatch between the group record count and number of IFACE records generated
                    DoLog (
                        'Mismatch between group count and internal_rec count');
                END IF;

                --Update status flags on stg records for created new IR req lines
                -- Start CCR0006517
                IF l_mutliple_reqs = 'N'
                THEN
                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                       SET req_created         = 'Y',
                           new_req_header_id   = ln_new_req_header_id,
                           new_req_line_id    =
                               (SELECT requisition_line_id
                                  FROM po_requisition_lines_all prla
                                 WHERE     requisition_header_id =
                                           ln_new_req_header_id
                                       AND prla.attribute14 =
                                           TO_CHAR (stg.gtn_po_collab_stg_id))
                     WHERE gtn_po_collab_stg_id IN
                               (SELECT TO_NUMBER (attribute14)
                                  FROM po_requisition_lines_all prla
                                 WHERE prla.request_id = ln_req_import_req_id);
                ELSIF l_mutliple_reqs = 'Y'
                THEN
                    FOR rec_multiple_reqs
                        IN cur_multiple_reqs (pv_source_code,
                                              ln_req_import_req_id)
                    LOOP
                        BEGIN
                            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                               SET req_created = 'Y', new_req_header_id = rec_multiple_reqs.requisition_header_id, new_req_line_id = rec_multiple_reqs.requisition_line_id
                             WHERE gtn_po_collab_stg_id =
                                   rec_multiple_reqs.gtn_po_collab_stg_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                dolog (
                                       'Error in Updating New Req Header Id and Line Id to New Req Lines :: '
                                    || SQLERRM);
                        END;
                    END LOOP;
                END IF;

                DoLog ('REQ lines created : ' || ln_cnt);
            ELSE
                BEGIN
                    --Req import was not run. get req header from linked req to stg group
                    SELECT DISTINCT prha.requisition_header_id
                      INTO ln_new_req_header_id
                      FROM po_requisition_headers_all prha, po_requisition_lines_all prla
                     WHERE     prla.requisition_header_id =
                               prha.requisition_header_id
                           AND prha.interface_source_code = pv_source_code
                           AND prla.line_location_id IS NULL
                           AND prla.attribute14 IN
                                   (SELECT gtn_po_collab_stg_id
                                      FROM xxdo.xxdo_gtn_po_collab_stg stg
                                     WHERE     stg.batch_id = pn_batch_id
                                           AND stg.req_type = 'TQ'
                                           AND stg.create_req = 'Y'
                                           AND stg.req_created = 'Y');
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        NULL;
                --TODO we found multiple pending reqs
                END;
            END IF;

            DoLog ('REQ ID of PR ' || ln_new_req_header_id);
            --Create PO from the REQ

            COMMIT;


            IF ln_new_req_header_id IS NOT NULL
            THEN
                create_tq_po_from_pr (pn_req_header_id => ln_new_req_header_id, pv_po_number => lv_new_po_number, PV_ERROR_STAT => pv_error_stat
                                      , PV_ERROR_MSG => pv_error_msg);


                IF PV_ERROR_STAT != 'S'
                THEN
                    ROLLBACK;
                    doLog ('Error creating PO ' || PV_ERROR_MSG);

                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                       SET processing_status_code = 'ERROR', error_message = 'PO Create failed for JP PR group. Error :' || PV_ERROR_MSG
                     WHERE gtn_po_collab_stg_id IN
                               (SELECT line_attribute14
                                  FROM po_requisitions_interface_all
                                 WHERE batch_id = ln_req_imp_batch_id);

                    COMMIT;
                    CONTINUE;
                END IF;

                COMMIT;

                --Get created header ID
                BEGIN
                    SELECT po_header_id
                      INTO ln_new_po_header_id
                      FROM po_headers_all
                     WHERE segment1 = lv_new_po_number;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                           SET processing_status_code = 'ERROR', error_message = 'PO not found for PR created'
                         WHERE gtn_po_collab_stg_id IN
                                   (SELECT line_attribute14
                                      FROM po_requisitions_interface_all
                                     WHERE batch_id = ln_req_imp_batch_id);

                        doLog ('Error not finding PO ' || PV_ERROR_MSG);
                        COMMIT;
                        CONTINUE;
                END;

                --Do PO approval
                approve_po (lv_new_po_number, fnd_global.user_id, pv_error_stat
                            , pv_error_msg);

                DoLog ('B2B PO Copy call');
                DoLog ('PO Header ID:' || ln_new_po_header_id);
                DoLog ('Ship to Organization ID:' || ln_po_dest_org_id);

                SELECT authorization_status
                  INTO lv_authorization_status
                  FROM po_headers_all
                 WHERE po_header_id = ln_new_po_header_id;

                dolog (
                       'PO Authorization status PO : '
                    || lv_new_po_number
                    || ' : '
                    || lv_authorization_status);
            ELSE
                --No pending REQ needing PO creation
                --Find an existing PO misssing link to DSS
                BEGIN
                    SELECT DISTINCT pha.po_header_id
                      INTO ln_new_po_header_id
                      FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                           po_requisition_lines_all prla, po_requisition_headers_all prha
                     WHERE     prha.requisition_header_id =
                               prla.requisition_header_id
                           AND prla.line_location_id = plla.line_location_id
                           AND plla.po_line_id = pla.po_line_id
                           AND pla.po_header_id = pha.po_header_id
                           AND pla.attribute5 IS NULL
                           AND prla.attribute14 IN
                                   (SELECT gtn_po_collab_stg_id
                                      FROM xxdo.xxdo_gtn_po_collab_stg stg
                                     WHERE     stg.batch_id = pn_batch_id
                                           AND stg.req_type = 'TQ'
                                           AND stg.create_req = 'Y'
                                           AND stg.req_created = 'Y');
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        --Multiple POs found with no link to SO

                        ln_new_po_header_id   := NULL;
                    WHEN NO_DATA_FOUND
                    THEN
                        --No POs found w/o a link to SO : No issue here
                        ln_new_po_header_id   := NULL;
                END;

                lv_authorization_status   := 'NONE';
            END IF;

            IF lv_authorization_status = 'APPROVED'
            THEN
                --run the B2B PO copy program to create the Drop ship SO from the Japan TQ PO
                xxdo_b2b_po_copy_pkg.main_prc (
                    p_errbuf               => lv_error_msg,
                    p_retcode              => ln_ret_code,
                    P_PO_HEADER_ID         => ln_new_po_header_id,
                    p_destination_org_id   => ln_po_dest_org_id,
                    p_order_type_id        => NULL,
                    p_price_list_id        => NULL);



                DoLog ('B2B PO Copy call. Return ' || ln_ret_code);

                IF ln_ret_code != 0
                THEN
                    doLog ('Error from B2B PO Copy : ' || lv_error_msg);
                END IF;

                --Find created order number from link to PO
                BEGIN
                    SELECT order_number, header_id
                      INTO ln_new_order_number, ln_new_header_id
                      FROM oe_order_headers_all ooha
                     WHERE ooha.cust_po_number = lv_new_po_number;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DoLog ('No SO found');
                --Order failed to create from PO
                END;

                --We need to update stage table records: TQ records must be changed to EXTERNAL to do PR/PO from drop ship SO.

                DoLog ('New DS SO created.Order # ' || ln_new_order_number);
            ELSE
                DoLog ('PO Not approved');

                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                   SET processing_status_code = 'ERROR', error_message = 'JP PO Not in approved status'
                 WHERE gtn_po_collab_stg_id IN
                           (SELECT prla.attribute14
                              FROM po_requisition_lines_all prla, po_line_locations_all plla
                             WHERE     plla.po_header_id =
                                       ln_new_po_header_id
                                   AND plla.line_location_id =
                                       prla.line_location_id);

                COMMIT;
                CONTINUE;
            END IF;
        END LOOP;

        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
           SET create_req    = 'Y',
               req_created   = 'N',
               req_type      = 'EXTERNAL',
               oe_line_id   =
                   (SELECT line_id
                      FROM po_requisition_lines_all prla, po_line_locations_all plla, po_lines_all pla,
                           oe_order_lines_all oola
                     WHERE     prla.attribute14 = stg.gtn_po_collab_stg_id
                           AND prla.line_location_id = plla.line_location_id
                           AND plla.po_line_id = pla.po_line_id
                           AND pla.attribute5 = oola.line_id),
               oe_header_id   =
                   (SELECT header_id
                      FROM po_requisition_lines_all prla, po_line_locations_all plla, po_lines_all pla,
                           oe_order_lines_all oola
                     WHERE     prla.attribute14 = stg.gtn_po_collab_stg_id
                           AND prla.line_location_id = plla.line_location_id
                           AND plla.po_line_id = pla.po_line_id
                           AND pla.attribute5 = oola.line_id)
         WHERE     create_req = 'Y'
               AND req_created = 'Y'
               AND req_type = 'TQ'
               AND processing_status_code != 'ERROR'
               AND batch_id = pn_batch_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            DoLog ('Error occurred : ' || SQLERRM);
    END;


    --Create Internal SOs for Internal Requisition from a given batch of staging table records

    PROCEDURE run_ir_recs_to_iso (pn_batch_id IN NUMBER, pv_source_code IN VARCHAR2, PV_ERROR_STAT OUT VARCHAR2
                                  , PV_ERROR_MSG OUT VARCHAR2)
    IS
        --Gets groups of recs to create requisitions
        CURSOR c_header IS
              SELECT batch_id, org_id, po_number,
                     ship_to_organization_id, new_promised_date, ex_factory_date,
                     ship_method, freight_pay_party, created_by,
                     COUNT (*) cnt_recs, SUM (quantity) total_qty
                FROM xxdo.xxdo_gtn_po_collab_stg
               WHERE     processing_status_code = 'RUNNING'
                     AND batch_id = pn_batch_id
                     AND create_req = 'Y'
                     AND req_created = 'N'
                     AND req_type = 'INTERNAL'
            GROUP BY batch_id, org_id, po_number,
                     ship_to_organization_id, new_promised_date, ex_factory_date,
                     ship_method, freight_pay_party, created_by;

        --gets specific records within the group
        CURSOR c_line (n_batch_id                  NUMBER,
                       n_org_id                    NUMBER,
                       v_po_number                 VARCHAR2,
                       n_ship_to_organization_id   NUMBER,
                       d_new_promised_date         DATE,
                       d_ex_factory_date           DATE,
                       v_ship_method               VARCHAR2,
                       v_freight_pay_party         VARCHAR2)
        IS
              SELECT stg.gtn_po_collab_stg_id, stg.line_num, vw.style_number,
                     vw.color_code, vw.size_sort_code
                FROM xxdo.xxdo_gtn_po_collab_stg stg, xxd_common_items_v vw
               WHERE     stg.batch_id = n_batch_id
                     AND stg.org_id = n_org_id
                     AND stg.po_number = v_po_number
                     AND stg.ship_to_organization_id =
                         n_ship_to_organization_id
                     AND NVL (stg.new_promised_date, TRUNC (SYSDATE)) =
                         NVL (d_new_promised_date, TRUNC (SYSDATE))
                     AND stg.ex_factory_date = d_ex_factory_date
                     AND stg.ship_method = v_ship_method
                     AND stg.freight_pay_party = v_freight_pay_party
                     AND STG.ITEM_ID = vw.inventory_item_id
                     AND stg.ship_to_organization_id = vw.organization_id
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM po_requisitions_interface_all pori
                               WHERE     pori.interface_source_code =
                                         gv_source_code
                                     AND TO_CHAR (gtn_po_collab_stg_id) =
                                         pori.line_attribute14)
            ORDER BY vw.style_number, vw.color_code, vw.size_sort_code; --Do not select records already on interface

        CURSOR cur_multiple_reqs (pv_source_code         IN VARCHAR2,
                                  pv_req_import_req_id   IN NUMBER)
        IS
            SELECT prha.requisition_header_id, prla.requisition_line_id, stg.gtn_po_collab_stg_id
              FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla, xxdo.xxdo_gtn_po_collab_stg stg
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prha.interface_source_code = pv_source_code
                   AND prha.request_id = pv_req_import_req_id
                   AND prla.attribute14 = TO_CHAR (stg.gtn_po_collab_stg_id);

        ln_org_id                    NUMBER;
        ln_ship_to_organization_id   NUMBER;
        ln_created_by                NUMBER;
        ln_request_id                NUMBER;
        ln_req_import_req_id         NUMBER;
        ln_batch_rec_id              NUMBER;
        ln_cnt                       NUMBER;
        ln_ir_org_id                 NUMBER;
        ln_ir_dest_org_id            NUMBER;

        ln_group_cnt                 NUMBER;
        ln_group_qty                 NUMBER;

        ln_ir_header_id              NUMBER;
        ln_ir_line_id                NUMBER;

        ln_new_iso_org_id            NUMBER;
        ln_source_inv_org_id         NUMBER;
        ln_new_cnt                   NUMBER;
        ln_new_quantity              NUMBER;
        ln_new_req_header_id         NUMBER;
        ld_promised_date             DATE;
        ln_line_num                  NUMBER := 1;

        ln_new_iso_number            NUMBER;
        ln_new_iso_header_id         NUMBER;
        ln_calc_transit_days         NUMBER;

        lv_oe_error_message          VARCHAR2 (2000) := NULL;

        lv_orig_sys_document_ref     VARCHAR2 (50);


        ln_req_imp_batch_id          NUMBER := 1;

        OS_Internal         CONSTANT NUMBER := 10;

        ex_update                    EXCEPTION;
        l_mutliple_reqs              VARCHAR2 (10) := 'N';       -- CCR0006517
    BEGIN
        DoLog ('run_ir_recs_to_iso - Enter');

        FOR header_rec IN c_header
        LOOP
            --Get totals for validation
            ln_group_cnt          := header_rec.cnt_recs;
            ln_group_qty          := header_rec.total_qty;

            ln_line_num           := 1;


            DoLog ('--Outer loop');
            DoLog ('Batch loop counter : ' || ln_req_imp_batch_id);
            DoLog ('PO Number:           ' || header_rec.po_number);
            DoLog (
                'ST Org ID:           ' || header_rec.ship_to_organization_id);
            DoLog (
                   'Promised Date:       '
                || TO_CHAR (header_rec.new_promised_date));
            DoLog ('Ship Method:         ' || header_rec.ship_method);
            DoLog ('Freight Pay Party:   ' || header_rec.freight_pay_party);

            DoLog (
                   'Group Count : '
                || ln_group_cnt
                || ' Group Qty : '
                || ln_group_qty);



            FOR line_rec
                IN c_line (header_rec.batch_id,
                           header_rec.org_id,
                           header_rec.po_number,
                           header_rec.ship_to_organization_id,
                           header_rec.new_promised_date,
                           header_rec.ex_factory_date,
                           header_rec.ship_method,
                           header_rec.freight_pay_party)
            LOOP
                BEGIN
                    DoLog ('--Inner loop');

                    --Get the source IR header and lines from the Source ISO
                    SELECT source_document_id, source_document_line_id
                      INTO ln_ir_header_id, ln_ir_line_id
                      FROM oe_order_lines_all oola, xxdo.xxdo_gtn_po_collab_stg stg
                     WHERE     oola.line_id = stg.oe_line_id
                           AND stg.gtn_po_collab_stg_id =
                               line_rec.gtn_po_collab_stg_id;


                    DoLog (
                           'Update IR links IR_H_ID : '
                        || ln_ir_header_id
                        || ' IR_L_ID : '
                        || ln_ir_line_id);

                    --Link the Orig IR data to the stage record
                    UPDATE xxdo.xxdo_gtn_po_collab_stg
                       SET from_ir_header_id = ln_ir_header_id, from_ir_line_id = ln_ir_line_id
                     WHERE gtn_po_collab_stg_id =
                           line_rec.gtn_po_collab_stg_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DoLog (SQLERRM);
                END;

                --Check Promised date. If not passed then calc from the line xf date
                IF     header_rec.new_promised_date IS NULL
                   AND header_rec.ex_factory_date IS NOT NULL
                THEN
                    ln_calc_transit_days   :=
                        get_pol_transit_days (header_rec.po_number,
                                              line_rec.line_num,
                                              header_rec.ship_method);

                    IF NVL (ln_calc_transit_days, 0) = 0
                    THEN
                        doLog ('Not defined transit time');
                        pv_error_msg   :=
                            'Transit time not defined for ship method';
                        RAISE ex_update;
                    END IF;

                    ld_promised_date   :=
                        header_rec.ex_factory_date + ln_calc_transit_days;
                ELSE
                    ld_promised_date   := header_rec.new_promised_date;
                END IF;

                --update stage table with promised_date
                UPDATE xxdo.xxdo_gtn_po_collab_stg
                   SET new_promised_date   = ld_promised_date
                 WHERE     gtn_po_collab_stg_id =
                           line_rec.gtn_po_collab_stg_id
                       AND new_promised_date IS NULL;


                --insert into req interface
                DoLog (
                    'In inner loop : Record ID : ' || line_rec.gtn_po_collab_stg_id);
                create_req_iface_from_stg (line_rec.gtn_po_collab_stg_id,
                                           pv_source_code,
                                           ln_req_imp_batch_id,
                                           ln_line_num,
                                           PV_ERROR_STAT,
                                           PV_ERROR_MSG);

                DoLog ('--After create_req_iface_from_stg ');
                DoLog ('--Error Stat : ' || PV_ERROR_STAT);
                --carry last rec ID over to get modified values for internal req
                --assumption : these values are the same for all elements in this group
                ln_batch_rec_id   := line_rec.gtn_po_collab_stg_id;

                ln_line_num       := ln_line_num + 1;
            END LOOP;

            DoLog ('After inner loop');
            DoLog ('getting IR data');

            --get updates values for req: use last stg rec id in group to filter for values
            SELECT DISTINCT stg.org_id,                       --Orig PO Org ID
                                        stg.ship_to_organization_id, --Orig PO Ship to Org ID (SB 129)
                                                                     stg.created_by, --Orig PO Created by
                            ir.org_id,             --Orig Interrnal Req Org ID
                                       ir.destination_organization_id, --Orig Internal Req dest Organization ID
                                                                       ir.requisition_header_id --Orig Internal Req header ID
              INTO ln_org_id, ln_ship_to_organization_id, ln_created_by, ln_ir_org_id,
                            ln_ir_dest_org_id, ln_ir_header_id
              FROM xxdo.xxdo_gtn_po_collab_stg stg, oe_order_lines_all oola, apps.po_requisition_lines_all ir
             WHERE     gtn_po_collab_stg_id = ln_batch_rec_id
                   AND stg.oe_line_id = oola.line_id
                   AND oola.source_document_line_id =
                       ir.requisition_line_id(+);

            DoLog ('IR_ORG_ID' || ln_ir_org_id);
            DoLog ('IR_ST_ORG_ID' || ln_ship_to_organization_id);

            --If created by user does not have EMP ID (this would be true for converted IRs) then replace with BATCH.O2F user
            SELECT COUNT (*)
              INTO ln_cnt
              FROM apps.fnd_user
             WHERE user_id = ln_created_by AND employee_id IS NOT NULL;

            IF ln_cnt = 0
            THEN
                SELECT user_id
                  INTO ln_created_by
                  FROM fnd_user
                 WHERE user_name = gBatchO2F_User;
            END IF;

            --Get count of created IR REQ interface records created. This should count of records from group
            SELECT COUNT (*)
              INTO ln_cnt
              FROM apps.po_requisitions_interface_all
             WHERE     interface_source_code = pv_source_code
                   AND batch_id = ln_req_imp_batch_id;

            IF ln_cnt != ln_group_cnt
            THEN
                --Mismatch between the group record count and number of IFACE records generated
                DoLog ('Mismatch between group count and rec_iface count');
            END IF;

            DoLog ('cnt iface records         ' || ln_cnt);
            DoLog ('src_code :                ' || pv_source_code);
            DoLog ('Org_id :                  ' || ln_org_id);
            DoLog (
                'ship_to_organization_id : ' || ln_ship_to_organization_id);
            DoLog ('created_by :              ' || ln_created_by);

            DoLog ('Before run_req_import');

            --Run req import
            run_req_import (
                p_import_source   => pv_source_code,
                p_batch_id        => TO_CHAR (ln_req_imp_batch_id),
                p_org_id          => ln_ir_org_id,                --ln_org_id,
                p_inv_org_id      => ln_ship_to_organization_id,
                p_user_id         => ln_created_by,
                p_status          => PV_ERROR_STAT,
                p_msg             => PV_ERROR_MSG,
                p_request_id      => ln_req_import_req_id);

            DoLog ('After run_req_import');
            DoLog ('Status : ' || PV_ERROR_STAT);
            DoLog ('Msg : ' || PV_ERROR_MSG);
            DoLog ('Request_id : ' || ln_req_import_req_id);


            --run create internal orders
            IF PV_ERROR_STAT <> 'S'
            THEN
                dolog (
                       'Requisition Import faied with error message :: '
                    || PV_ERROR_MSG);                            -- CCR0006517
                RAISE ex_update;
            END IF;

            --Get the req header ID created and the count of created records

            l_mutliple_reqs       := 'N';                        -- CCR0006517

            BEGIN
                  SELECT COUNT (*), prha.requisition_header_id
                    INTO ln_cnt, ln_new_req_header_id
                    FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla
                   WHERE     prha.requisition_header_id =
                             prla.requisition_header_id
                         AND prha.interface_source_code = pv_source_code
                         AND prha.request_id = ln_req_import_req_id
                GROUP BY prha.requisition_header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    --TODO : No recs created (REQ Import faied to generate a requisition)
                    NULL;
                WHEN TOO_MANY_ROWS
                THEN
                    dolog (
                           'Multiple Requisitions Created for Request id :: '
                        || ln_req_import_req_id);
                    l_mutliple_reqs   := 'Y';                    -- CCR0006517
                WHEN OTHERS
                THEN
                    dolog ('Error in Fetching Req Header Id :: ' || SQLERRM);
            END;

            IF ln_cnt != ln_group_cnt
            THEN
                --Mismatch between the group record count and number of IFACE records generated
                DoLog ('Mismatch between group count and internal_rec count');
            END IF;

            --Update status flags on stg records for created new IR req lines
            -- Start CCR0006517
            IF l_mutliple_reqs = 'N'
            THEN
                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                   SET req_created         = 'Y',
                       new_req_header_id   = ln_new_req_header_id,
                       new_req_line_id    =
                           (SELECT requisition_line_id
                              FROM po_requisition_lines_all prla
                             WHERE     requisition_header_id =
                                       ln_new_req_header_id
                                   AND prla.attribute14 =
                                       TO_CHAR (stg.gtn_po_collab_stg_id))
                 WHERE gtn_po_collab_stg_id IN
                           (SELECT TO_NUMBER (attribute14)
                              FROM po_requisition_lines_all prla
                             WHERE prla.request_id = ln_req_import_req_id);
            ELSIF l_mutliple_reqs = 'Y'
            THEN
                FOR rec_multiple_reqs
                    IN cur_multiple_reqs (pv_source_code,
                                          ln_req_import_req_id)
                LOOP
                    BEGIN
                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                           SET req_created = 'Y', new_req_header_id = rec_multiple_reqs.requisition_header_id, new_req_line_id = rec_multiple_reqs.requisition_line_id
                         WHERE gtn_po_collab_stg_id =
                               rec_multiple_reqs.gtn_po_collab_stg_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            dolog (
                                   'Error in Updating New Req Header Id and Line Id to New Req Lines :: '
                                || SQLERRM);
                    END;
                END LOOP;
            END IF;

            DoLog ('REQ lines created : ' || ln_cnt);
            DoLog ('REQ ID of IR ' || ln_new_req_header_id);

            --Run req create internal orders
            apps.xxdoom_reroute_iso.run_create_internal_orders (
                p_org_id       => ln_ir_org_id,
                p_inv_org_id   => ln_ir_dest_org_id,
                p_user_id      => ln_created_by,
                p_status       => PV_ERROR_STAT,
                p_msg          => PV_ERROR_MSG,
                p_request_id   => ln_request_id);

            DoLog (
                'After apps.xxdoom_reroute_iso.run_create_internal_orders');
            DoLog ('Status : ' || PV_ERROR_STAT);
            DoLog ('Msg : ' || PV_ERROR_MSG);
            DoLog ('Request_id : ' || ln_request_id);

            --run create internal orders
            IF PV_ERROR_STAT <> 'S'
            THEN
                dolog (
                       'Create Internal Orders Procedure failed :: '
                    || PV_ERROR_MSG);                            -- CCR0006517
                RAISE ex_update;
            END IF;

            DoLog ('before apps.xxdoom_reroute_iso.run_order_import');
            DoLog ('Org_id : ' || ln_org_id);
            DoLog ('ship_from_org_id : ' || ln_ship_to_organization_id);

            --Validate creation of internal order iface records created
            BEGIN
                  SELECT org_id, ship_from_org_id, COUNT (*),
                         SUM (ordered_quantity), orig_sys_document_ref
                    INTO ln_new_iso_org_id, ln_source_inv_org_id, ln_new_cnt, ln_new_quantity,
                                          lv_orig_sys_document_ref
                    FROM oe_lines_iface_all
                   WHERE orig_sys_document_ref = TO_CHAR (ln_new_req_header_id)
                GROUP BY org_id, ship_from_org_id, orig_sys_document_ref;
            EXCEPTION
                WHEN OTHERS
                THEN
                    dolog (
                           'Error Found in findind ISO in Orders Interface table :: '
                        || SQLERRM);
            END;

            DoLog ('After create internal orders');
            DoLog (' Doc Ref : ' || lv_orig_sys_document_ref);
            DoLog (
                   ' No Recs : '
                || ln_new_cnt
                || ' Quantity : '
                || ln_new_quantity);

            IF ln_new_cnt != ln_group_cnt OR ln_new_quantity != ln_group_qty
            THEN
                DoLog (
                    'Count / qty on Internal SO does not match count/qty from group');
            END IF;

            apps.xxdoom_reroute_iso.run_order_import (
                p_org_id       => ln_org_id,
                p_inv_org_id   => ln_ship_to_organization_id,
                p_user_id      => ln_created_by,
                p_status       => PV_ERROR_STAT,
                p_msg          => PV_ERROR_MSG,
                p_request_id   => ln_request_id);

            --update stage table records to reflect external req records
            DoLog ('After xxdoom_reroute_iso.run_order_import');
            DoLog ('Status : ' || PV_ERROR_STAT);
            DoLog ('Msg : ' || PV_ERROR_MSG);
            DoLog ('Request_id : ' || ln_request_id);

            DoLog ('ln_new_req_header_id = ' || ln_new_req_header_id);
            DoLog ('ln_source_inv_org_id = ' || ln_source_inv_org_id);

            -- Start CCR0006517

            IF l_mutliple_reqs = 'N'
            THEN
                --Validate creation of internal order
                --Validate ISO created
                BEGIN
                      SELECT ooha.order_number, ooha.header_id, oola.org_id,
                             oola.ship_from_org_id, COUNT (*), SUM (ordered_quantity)
                        INTO ln_new_iso_number, ln_new_iso_header_id, ln_new_iso_org_id, ln_source_inv_org_id,
                                              ln_new_cnt, ln_new_quantity
                        FROM oe_order_lines_all oola, oe_order_headers_all ooha
                       WHERE     oola.source_document_id = ln_new_req_header_id
                             AND oola.ship_from_org_id = ln_source_inv_org_id
                             -- AND oola.flow_status_code = 'SUPPLY_ELIGIBLE'
                             AND oola.header_id = ooha.header_id
                    GROUP BY ooha.order_number, ooha.header_id, oola.org_id,
                             oola.ship_from_org_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        --check if the interface record is in error. If so pull the error message if able
                        BEGIN
                            SELECT COUNT (*)
                              INTO ln_cnt
                              FROM oe_headers_iface_all
                             WHERE     orig_sys_document_ref =
                                       TO_CHAR (ln_new_req_header_id) -- CCR0006517
                                   AND NVL (error_flag, 'N') = 'Y';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                DOLOG (
                                       'Error in Fetching Records in oe_headers_iface_all :: '
                                    || SQLERRM);
                                pv_error_msg   :=
                                       'Error in Fetching Records in oe_headers_iface_all :: '
                                    || SQLERRM;
                        END;

                        IF ln_cnt > 0
                        THEN
                            BEGIN
                                SELECT opt.MESSAGE_TEXT
                                  INTO lv_oe_error_message
                                  FROM oe_processing_msgs opm, oe_processing_msgs_tl opt
                                 WHERE     opm.transaction_id =
                                           opt.transaction_id
                                       AND opt.language = 'US'
                                       AND source_document_id =
                                           ln_new_req_header_id
                                       AND ROWNUM = 1;

                                DoLog (lv_oe_error_message);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;

                        DoLog (
                               'Validation of ISO created returned no records   Header ID:'
                            || ln_new_req_header_id
                            || ' Src_Inv_Org_id : '
                            || ln_source_inv_org_id);


                        ln_new_cnt        := 0;
                        ln_new_quantity   := 0;
                    --TODO Just continue. If found that proceeding lines fail then we will error out at this popint
                    -- Start CCR0006517
                    WHEN OTHERS
                    THEN
                        dolog (
                               'Unexpected Error found in fetching ISO :: '
                            || SQLERRM);
                -- End CCR0006517
                END;

                DoLog ('After order import');
                DoLog (' ISO Number :          ' || ln_new_iso_number);
                DoLog (' ISO Header ID : ' || ln_new_iso_header_id);
                DoLog (
                       ' No Recs : '
                    || ln_new_cnt
                    || ' Quantity : '
                    || ln_new_quantity);

                IF    ln_new_cnt != ln_group_cnt
                   OR ln_new_quantity != ln_group_qty
                THEN
                    NULL;
                --TODO: Handle mismatches
                END IF;

                DoLog ('Before update stg fields');

                --Update Header ID, Line ID on stg records.
                --update status fields for creation of external req
                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                   SET oe_header_id   = ln_new_iso_header_id,
                       oe_line_id    =
                           (SELECT line_id
                              FROM oe_order_lines_all oola, po_requisition_lines_all prla
                             WHERE     oola.header_id = ln_new_iso_header_id
                                   AND oola.source_document_line_id =
                                       prla.requisition_line_id
                                   AND prla.attribute14 =
                                       TO_CHAR (gtn_po_collab_stg_id)),
                       req_created    = 'N',
                       create_req     = 'Y',
                       req_type       = 'EXTERNAL'
                 WHERE gtn_po_collab_stg_id IN
                           (SELECT TO_NUMBER (attribute14)
                              FROM po_requisition_lines_all prla
                             WHERE prla.request_id = ln_req_import_req_id);

                DoLog ('after update stg fields');
            ELSIF l_mutliple_reqs = 'Y'
            THEN
                FOR rec_multiple_reqs
                    IN cur_multiple_reqs (pv_source_code,
                                          ln_req_import_req_id)
                LOOP
                    --Validate creation of internal order
                    --Validate ISO created
                    BEGIN
                          SELECT ooha.order_number, ooha.header_id, oola.org_id,
                                 oola.ship_from_org_id, COUNT (*), SUM (ordered_quantity)
                            INTO ln_new_iso_number, ln_new_iso_header_id, ln_new_iso_org_id, ln_source_inv_org_id,
                                                  ln_new_cnt, ln_new_quantity
                            FROM oe_order_lines_all oola, oe_order_headers_all ooha
                           WHERE     oola.source_document_id =
                                     rec_multiple_reqs.requisition_header_id
                                 AND oola.ship_from_org_id =
                                     NVL (ln_source_inv_org_id,
                                          oola.ship_from_org_id)
                                 --     AND oola.flow_status_code = 'SUPPLY_ELIGIBLE'
                                 AND oola.header_id = ooha.header_id
                        GROUP BY ooha.order_number, ooha.header_id, oola.org_id,
                                 oola.ship_from_org_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT COUNT (*)
                                  INTO ln_cnt
                                  FROM oe_headers_iface_all
                                 WHERE     orig_sys_document_ref =
                                           TO_CHAR (
                                               rec_multiple_reqs.requisition_header_id)
                                       AND NVL (error_flag, 'N') = 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    DOLOG (
                                           'Error in Fetching Records in oe_headers_iface_all :: '
                                        || SQLERRM);
                                    pv_error_msg   :=
                                           'Error in Fetching Records in oe_headers_iface_all :: '
                                        || SQLERRM;
                            END;

                            IF ln_cnt > 0
                            THEN
                                BEGIN
                                    SELECT opt.MESSAGE_TEXT
                                      INTO lv_oe_error_message
                                      FROM oe_processing_msgs opm, oe_processing_msgs_tl opt
                                     WHERE     opm.transaction_id =
                                               opt.transaction_id
                                           AND opt.language = 'US'
                                           AND source_document_id =
                                               rec_multiple_reqs.requisition_header_id
                                           AND ROWNUM = 1;

                                    DoLog (lv_oe_error_message);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;

                            DoLog (
                                   'Validation of ISO created returned no records   Header ID:'
                                || rec_multiple_reqs.requisition_header_id
                                || ' Src_Inv_Org_id : '
                                || ln_source_inv_org_id);


                            ln_new_cnt        := 0;
                            ln_new_quantity   := 0;
                        --TODO Just continue. If found that proceeding lines fail then we will error out at this popint
                        WHEN OTHERS
                        THEN
                            dolog (
                                   'Unexpected Error found in fetching ISO :: '
                                || SQLERRM);
                    END;

                    DoLog ('After order import');
                    DoLog (' ISO Number :          ' || ln_new_iso_number);
                    DoLog (' ISO Header ID : ' || ln_new_iso_header_id);
                    DoLog (
                           ' No Recs : '
                        || ln_new_cnt
                        || ' Quantity : '
                        || ln_new_quantity);

                    IF    ln_new_cnt != ln_group_cnt
                       OR ln_new_quantity != ln_group_qty
                    THEN
                        NULL;
                    --TODO: Handle mismatches
                    END IF;

                    DoLog ('Before update stg fields');

                    --Update Header ID, Line ID on stg records.
                    --update status fields for creation of external req
                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                       SET oe_header_id   = ln_new_iso_header_id,
                           oe_line_id    =
                               (SELECT line_id
                                  FROM oe_order_lines_all oola, po_requisition_lines_all prla
                                 WHERE     oola.header_id =
                                           ln_new_iso_header_id
                                       AND oola.source_document_line_id =
                                           prla.requisition_line_id
                                       AND prla.attribute14 =
                                           TO_CHAR (
                                               rec_multiple_reqs.gtn_po_collab_stg_id)),
                           req_created    = 'N',
                           create_req     = 'Y',
                           req_type       = 'EXTERNAL'
                     WHERE gtn_po_collab_stg_id =
                           rec_multiple_reqs.gtn_po_collab_stg_id;

                    DoLog ('after update stg fields');
                END LOOP;
            END IF;

            --Increment batch loop counter
            ln_req_imp_batch_id   := ln_req_imp_batch_id + 1;
        END LOOP;

        --Update stg table:
        --REQ_TYPE = 'EXTERNAL'
        --REQ_CREATED = 'N'

        PV_ERROR_STAT   := 'S';
        DoLog ('run_ir_recs_to_iso - Exit Status = ' || PV_ERROR_STAT);
    EXCEPTION
        WHEN ex_update
        THEN
            DoLog (
                'Error running updates run_ir_recs_to_iso : ' || pv_error_msg);
            PV_ERROR_STAT   := 'E';
        WHEN OTHERS
        THEN
            DoLog (
                   'Unexpected Error in Procedure run_ir_recs_to_iso :: '
                || SQLERRM);
            PV_ERROR_STAT   := 'U';
    END;

    --Create POs from purchase req records on staging table

    PROCEDURE create_po_from_purchrec_stg (pn_batch_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        ln_po_import_batch_id       NUMBER;
        ex_login                    EXCEPTION;
        ex_update                   EXCEPTION;

        --Header cursor to get requisition header data for insert into PO interface
        CURSOR c_header IS
            SELECT DISTINCT prha.requisition_header_id, prha.org_id, prha.preparer_id,
                            prha.created_by, stg.vendor_id, stg.vendor_site_id,
                            stg.user_id, stg.ship_to_organization_id, stg.ship_to_location_id,
                            stg.src_po_type_id, NVL (from_po_number, po_number) new_po_number, NVL (from_po_header_id, po_header_id) new_po_header
              FROM po_requisition_headers_all prha, xxdo.xxdo_gtn_po_collab_stg stg
             WHERE     prha.requisition_header_id = stg.req_header_id
                   AND stg.req_type = 'EXTERNAL'
                   AND stg.processing_status_code = 'RUNNING'
                   AND STG.REQ_CREATED = 'Y'
                   AND stg.batch_id = pn_batch_id;

        --Line cursor to get requisition data to insert into lines, line_locations and distributions interface
        CURSOR c_lines (n_req_header_id NUMBER)
        IS
            SELECT stg.gtn_po_collab_stg_id, stg.user_id, stg.new_promised_date,
                   stg.ship_to_organization_id, stg.ship_to_location_id, stg.freight_pay_party,
                   stg.ship_method, prla.quantity, stg.unit_price,
                   TO_CHAR (STG.EX_FACTORY_DATE, 'YYYY/MM/DD') cxfactory_date, NVL (stg.from_po_line_id, stg.po_line_id) new_line_id, NVL (stg.from_po_line_location_id, stg.po_line_location_id) new_line_location_id, --Pointer bact to orig PO for extra data
                   prla.need_by_date, prla.org_id, prla.requisition_line_id,
                   prla.item_id, prla.line_num, NVL (prla.drop_ship_flag, 'N') drop_ship_flag
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, xxdo.xxdo_gtn_po_collab_stg stg
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prla.requisition_line_id = stg.req_line_id
                   AND stg.req_type = 'EXTERNAL'
                   AND prha.requisition_header_id = n_req_header_id
                   AND stg.processing_status_code = 'RUNNING'
                   AND STG.REQ_CREATED = 'Y'
                   AND stg.batch_id = pn_batch_id;

        --List of POs to approve that were created by PO import process
        CURSOR po_list (n_po_number VARCHAR2)
        IS
            SELECT DISTINCT segment1 po_number
              FROM po_headers_all
             WHERE     attribute14 = n_po_number
                   AND authorization_status != 'APPROVED';

        ln_header_interface_id      NUMBER;
        ln_line_interface_id        NUMBER;
        ln_dist_interface_id        NUMBER;
        -- ln_batch_id              NUMBER;
        ln_employee_id              NUMBER;
        ln_def_user_id              NUMBER;
        ln_def_employee_id          NUMBER;
        ln_user_id                  NUMBER;
        ln_poi_req_id               NUMBER;
        ln_ship_to_location_id      NUMBER;

        ln_orig_user                NUMBER;
        ln_orig_agent               NUMBER;

        ln_to_po_header_id          NUMBER;

        ln_cnt                      NUMBER;

        lv_po_type                  VARCHAR2 (20);
        lv_xf_date                  VARCHAR2 (20);
        lv_orig_xf_date             VARCHAR2 (20);
        lv_brand                    VARCHAR2 (20);


        lv_header_attribute1        VARCHAR2 (150);
        lv_header_attribute2        VARCHAR2 (150);
        lv_header_attribute3        VARCHAR2 (150);
        lv_header_attribute4        VARCHAR2 (150);
        lv_header_attribute5        VARCHAR2 (150);
        lv_header_attribute6        VARCHAR2 (150);
        lv_header_attribute7        VARCHAR2 (150);
        lv_header_attribute8        VARCHAR2 (150);
        lv_header_attribute9        VARCHAR2 (150);
        lv_header_attribute10       VARCHAR2 (150);
        lv_header_attribute11       VARCHAR2 (150);
        lv_header_attribute12       VARCHAR2 (150);
        lv_header_attribute13       VARCHAR2 (150);
        lv_header_attribute14       VARCHAR2 (150);
        lv_header_attribute15       VARCHAR2 (150);
        lv_header_attr_category     VARCHAR2 (30);
        lv_line_attribute1          VARCHAR2 (150);
        lv_line_attribute2          VARCHAR2 (150);
        lv_line_attribute3          VARCHAR2 (150);
        lv_line_attribute4          VARCHAR2 (150);
        lv_line_attribute5          VARCHAR2 (150);
        lv_line_attribute6          VARCHAR2 (150);
        lv_line_attribute7          VARCHAR2 (150);
        lv_line_attribute8          VARCHAR2 (150);
        lv_line_attribute9          VARCHAR2 (150);
        lv_line_attribute10         VARCHAR2 (150);
        lv_line_attribute11         VARCHAR2 (150);
        lv_line_attribute12         VARCHAR2 (150);
        lv_line_attribute13         VARCHAR2 (150);
        lv_line_attribute14         VARCHAR2 (150);
        lv_line_attribute15         VARCHAR2 (150);
        lv_line_attr_category       VARCHAR2 (30);
        lv_new_line_attribute11     VARCHAR2 (150);
        lv_shipment_attribute1      VARCHAR2 (150);
        lv_shipment_attribute2      VARCHAR2 (150);
        lv_shipment_attribute3      VARCHAR2 (150);
        lv_shipment_attribute4      VARCHAR2 (150);
        lv_shipment_attribute5      VARCHAR2 (150);
        lv_shipment_attribute6      VARCHAR2 (150);
        lv_shipment_attribute7      VARCHAR2 (150);
        lv_shipment_attribute8      VARCHAR2 (150);
        lv_shipment_attribute9      VARCHAR2 (150);
        lv_shipment_attribute10     VARCHAR2 (150);
        lv_shipment_attribute11     VARCHAR2 (150);
        lv_shipment_attribute12     VARCHAR2 (150);
        lv_shipment_attribute13     VARCHAR2 (150);
        lv_shipment_attribute14     VARCHAR2 (150);
        lv_shipment_attribute15     VARCHAR2 (150);
        lv_shipment_attr_category   VARCHAR2 (30);

        lv_po_number                VARCHAR2 (20);
    BEGIN
        DoLog ('create_po_from_purchrec_stg - Enter');

        --Get next batch ID
        SELECT PO_CONTROL_GROUPS_S.NEXTVAL
          INTO ln_po_import_batch_id
          FROM DUAL;

        DoLog (' ln_po_import_batch_id : ' || ln_po_import_batch_id);

        FOR h_rec IN c_header
        LOOP
            BEGIN
                SELECT created_by, agent_id, segment1,
                       attribute1, attribute8, attribute9,
                       attribute10, attribute11, attribute_category
                  INTO ln_orig_user, ln_orig_agent, lv_po_number, lv_header_attribute1,
                                   lv_header_attribute8, lv_header_attribute9, lv_header_attribute10,
                                   lv_header_attribute11, lv_header_attr_category
                  FROM po_headers_all pha
                 WHERE pha.po_header_id = h_rec.new_po_header;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            DoLog ('Orig PO user : ' || ln_orig_user);
            DoLog ('Orig PO agent : ' || ln_orig_agent);

            --If user ID not passed, pull defalt user for this type of transaction
            SELECT user_id, employee_id
              INTO ln_def_user_id, ln_def_employee_id
              FROM fnd_user
             WHERE user_name = gBatchO2F_User; --TODO : Using this uswer as it has a valid employee_id. Best to use Created by on orig PO

            IF ln_orig_user IS NULL
            THEN
                DoLog ('Default user ID : ' || ln_def_user_id);

                --Check passed in user
                BEGIN
                    SELECT employee_id
                      INTO ln_employee_id
                      FROM fnd_user
                     WHERE user_id = h_rec.created_by;

                    DoLog (
                        '(NULL orig user) Employee ID : ' || ln_employee_id);

                    IF ln_employee_id IS NULL
                    THEN
                        ln_user_id   := ln_def_user_id;
                    ELSE
                        ln_user_id   := h_rec.created_by;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_user_id   := ln_def_user_id;
                END;
            ELSE
                --Check orig user
                BEGIN
                    SELECT employee_id
                      INTO ln_employee_id
                      FROM fnd_user
                     WHERE user_id = ln_orig_user;

                    DoLog (
                           '(not NULL orig user) Employee ID : '
                        || ln_employee_id);

                    IF ln_employee_id IS NULL
                    THEN
                        ln_user_id       := ln_def_user_id;
                        ln_employee_id   := ln_orig_agent;
                    ELSE
                        ln_user_id       := ln_orig_user;
                        ln_employee_id   := ln_orig_agent;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_user_id       := ln_def_user_id;
                        ln_employee_id   := ln_orig_agent;
                END;
            END IF;

            DoLog ('User ID : ' || ln_user_id);
            DoLog ('Agent ID : ' || ln_employee_id);

            set_purchasing_context (ln_user_id, h_rec.org_id, pv_error_stat,
                                    pv_error_msg);
            DoLog ('after set_purchasing_context. Result :' || pv_error_stat);

            IF pv_error_stat <> 'S'
            THEN
                RAISE ex_login;
            END IF;

            SELECT PO_HEADERS_INTERFACE_S.NEXTVAL
              INTO ln_header_interface_id
              FROM DUAL;

            DoLog ('PO Type : ' || h_rec.src_po_type_id);
            DoLog ('New Header Interface ID : ' || ln_header_interface_id);

            IF    h_rec.src_po_type_id = G_PO_TYPE_DS
               OR h_rec.src_po_type_id = G_PO_TYPE_JPTQ
            THEN
                ln_ship_to_location_id   := 186;
            ELSE
                ln_ship_to_location_id   := h_rec.Ship_to_location_id;
            END IF;


            ln_to_po_header_id      := NULL;

            DoLog ('Creating new PO');
            DoLog ('Ship to location ID : ' || ln_ship_to_location_id);



            INSERT INTO po_headers_interface (INTERFACE_HEADER_ID, BATCH_ID, ORG_ID, --  INTERFACE_SOURCE_CODE ,
                                                                                     ACTION, -- (ORIGINAL,UPDATE,REPLACE;)
                                                                                             GROUP_CODE, DOCUMENT_TYPE_CODE, CURRENCY_CODE, AGENT_ID, VENDOR_ID, VENDOR_SITE_ID, SHIP_TO_LOCATION_ID, BILL_TO_LOCATION, PAYMENT_TERMS, APPROVAL_STATUS, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, COMMENTS, ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10
                                              , ATTRIBUTE11, ATTRIBUTE14) --PO Number sourcing this PO
                 VALUES (ln_header_interface_id, ln_po_import_batch_id, h_rec.org_id, 'ORIGINAL', --action
                                                                                                  NULL, --group_code,
                                                                                                        'STANDARD', --document_type_code
                                                                                                                    NULL, --Currency_code
                                                                                                                          ln_employee_id, --agent_id --employee for req.preparer ID
                                                                                                                                          h_rec.vendor_id, h_rec.vendor_site_id, --NULL, --h_rec.Ship_to_location_id,-- Populate from REQ deliver_to_location_id
                                                                                                                                                                                 ln_ship_to_location_id, --h_rec.Ship_to_location_id,                 -- CCR0006035
                                                                                                                                                                                                         NULL, --Bill_to_location (get from ship_to_location
                                                                                                                                                                                                               NULL, --Payment_term
                                                                                                                                                                                                                     'APPROVED', ln_user_id, SYSDATE, ln_user_id, SYSDATE, 'Created from purchase order # ' || lv_po_number, lv_header_attr_category, lv_header_attribute1, lv_header_attribute8, lv_header_attribute9, lv_header_attribute10
                         , lv_header_attribute11, lv_po_number);

            /*     ELSE
                    DoLog ('Adding to existing PO');
                    ln_to_po_header_id := h_rec.new_po_header;

                    INSERT INTO po_headers_interface (INTERFACE_HEADER_ID,
                                                      BATCH_ID,
                                                      ORG_ID,
                                                      INTERFACE_SOURCE_CODE,
                                                      ACTION, -- (ORIGINAL,UPDATE,REPLACE;)
                                                      PROCESS_CODE,
                                                      GROUP_CODE,
                                                      DOCUMENT_TYPE_CODE,
                                                      DOCUMENT_SUBTYPE,
                                                      DOCUMENT_NUM,
                                                      CURRENCY_CODE,
                                                      AGENT_ID,
                                                      VENDOR_ID,
                                                      VENDOR_SITE_ID,
                                                      SHIP_TO_LOCATION_ID,
                                                      BILL_TO_LOCATION,
                                                      PAYMENT_TERMS,
                                                      APPROVAL_STATUS,
                                                      CREATED_BY,
                                                      CREATION_DATE,
                                                      LAST_UPDATED_BY,
                                                      LAST_UPDATE_DATE,
                                                      PO_HEADER_ID,
                                                      STYLE_ID,
                                                      ATTRIBUTE_CATEGORY,
                                                      ATTRIBUTE1,
                                                      ATTRIBUTE8,
                                                      ATTRIBUTE9,
                                                      ATTRIBUTE10,
                                                      ATTRIBUTE11)
                         VALUES (ln_header_interface_id,
                                 ln_header_interface_id,
                                 h_rec.org_id,
                                 'PO',
                                 'ADD',
                                 'ADD',                                       --action
                                 'DEFAULT',                              --group_code,
                                 'PO',                            --document_type_code
                                 'STANDARD',                        --document_subtype
                                 lv_po_number,                          --Document_num
                                 NULL,                                 --Currency_code
                                 NULL,       --agent_id --employee for req.preparer ID
                                 NULL,
                                 NULL,
                                 NULL, --h_rec.Ship_to_location_id,-- Populate from REQ deliver_to_location_id
                                 NULL,   --Bill_to_location (get from ship_to_location
                                 NULL,                                  --Payment_term
                                 'APPROVED',
                                 ln_user_id,
                                 SYSDATE,
                                 ln_user_id,
                                 SYSDATE,
                                 h_rec.new_po_header,
                                 APPS.PO_DOC_STYLE_GRP.get_standard_doc_style,
                                 lv_header_attr_category,
                                 lv_header_attribute1,
                                 lv_header_attribute8,
                                 lv_header_attribute9,
                                 lv_header_attribute10,
                                 lv_header_attribute11);
                 END IF;*/

            FOR l_rec IN c_lines (h_rec.requisition_header_id)
            LOOP
                SELECT PO_LINES_INTERFACE_S.NEXTVAL
                  INTO ln_line_interface_id
                  FROM DUAL;

                --get extra data from orig PO line for copy into new PO line
                DoLog ('--Retriving extra PO data for copy to new PO lines');
                DoLog ('New PO Interface line ID : ' || ln_line_interface_id);

                BEGIN
                    SELECT attribute1, attribute2, attribute5,
                           attribute7, attribute8, attribute9,
                           attribute_category, line_num
                      INTO lv_line_attribute1, lv_line_attribute2, lv_line_attribute5, lv_line_attribute7,
                                             lv_line_attribute8, lv_line_attribute9, lv_line_attr_category,
                                             lv_line_attribute14 -- PO Line number sourcing this PO line
                      FROM po_lines_all
                     WHERE po_line_id = l_rec.new_line_id;

                    BEGIN
                        lv_new_line_attribute11   :=
                              l_rec.unit_price
                            - (NVL (lv_line_attribute8, 0) + NVL (lv_line_attribute9, 0));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_new_line_attribute11   := l_rec.unit_price;
                    END;

                    DoLog (
                           'line_attribute1 : '
                        || lv_line_attribute1
                        || ' line_attribute2 : '
                        || lv_line_attribute2
                        || ' line_attribute5 : '
                        || lv_line_attribute5
                        || ' lv_new_line_attribute11 : '
                        || lv_new_line_attribute11);

                    SELECT attribute4, attribute6, attribute8,
                           attribute11, attribute12, attribute13,
                           attribute14, attribute_category
                      INTO lv_shipment_attribute4, lv_shipment_attribute6, lv_shipment_attribute8, lv_shipment_attribute11,
                                                 lv_shipment_attribute12, lv_shipment_attribute13, lv_shipment_attribute14,
                                                 lv_shipment_attr_category
                      FROM po_line_locations_all
                     WHERE line_location_id = l_rec.new_line_location_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_line_attribute1   := NULL;
                        lv_line_attribute2   := NULL;
                END;

                DoLog (
                       'Shipment_attribute4 : '
                    || lv_shipment_attribute4
                    || ' Shipment_attribute8 : '
                    || lv_shipment_attribute8);


                DoLog ('Add to PO header ID : ' || ln_to_po_header_id);

                INSERT INTO po_lines_interface (
                                INTERFACE_LINE_ID,
                                INTERFACE_HEADER_ID,
                                ACTION,
                                LINE_TYPE,
                                LINE_NUM,
                                --  ITEM_ID,
                                REQUISITION_LINE_ID,
                                QUANTITY,
                                UNIT_PRICE,
                                SHIP_TO_LOCATION_ID,
                                NEED_BY_DATE,
                                PROMISED_DATE,
                                LIST_PRICE_PER_UNIT,
                                CREATED_BY,
                                CREATION_DATE,
                                LAST_UPDATED_BY,
                                LAST_UPDATE_DATE,
                                DROP_SHIP_FLAG,
                                LINE_ATTRIBUTE_CATEGORY_LINES,
                                LINE_ATTRIBUTE1,
                                LINE_ATTRIBUTE2,
                                LINE_ATTRIBUTE5,
                                LINE_ATTRIBUTE7,
                                LINE_ATTRIBUTE8,
                                LINE_ATTRIBUTE9,
                                LINE_ATTRIBUTE11,
                                LINE_ATTRIBUTE13,
                                LINE_ATTRIBUTE14,
                                SHIPMENT_ATTRIBUTE_CATEGORY,
                                SHIPMENT_ATTRIBUTE4,
                                SHIPMENT_ATTRIBUTE5,
                                SHIPMENT_ATTRIBUTE6,
                                SHIPMENT_ATTRIBUTE7,
                                SHIPMENT_ATTRIBUTE8,
                                SHIPMENT_ATTRIBUTE10,
                                SHIPMENT_ATTRIBUTE11,
                                SHIPMENT_ATTRIBUTE12,
                                SHIPMENT_ATTRIBUTE13,
                                SHIPMENT_ATTRIBUTE14,
                                PO_HEADER_ID)
                         VALUES (ln_line_interface_id,
                                 ln_header_interface_id,
                                 'ORIGINAL',                          --Action
                                 NULL,      --Line type (get proper line type)
                                 l_rec.line_num,
                                 --   l_rec.item_id,
                                 l_rec.requisition_line_id,
                                 --    NULL,                                             --UOM,
                                 l_rec.quantity,
                                 l_rec.unit_price,
                                 ln_ship_to_location_id, --NULL, --l_rec.Ship_to_location_id,-- popoulate from REQ deliver_to_location_id
                                 l_rec.need_by_date,
                                 l_rec.new_promised_date,
                                 l_rec.unit_price,
                                 ln_user_id,
                                 SYSDATE,
                                 ln_user_id,
                                 SYSDATE,
                                 l_rec.drop_ship_flag,
                                 lv_line_attr_category,
                                 lv_line_attribute1,
                                 lv_line_attribute2,
                                 lv_line_attribute5,
                                 lv_line_attribute7,
                                 lv_line_attribute8,
                                 lv_line_attribute9,
                                 lv_new_line_attribute11,
                                 'True',                   --Line attribute 13
                                 lv_line_attribute14,
                                 lv_shipment_attr_category,
                                 lv_shipment_attribute4,
                                 l_rec.cxfactory_date,   --Shipment attribute5
                                 'Y', -- lv_shipment_attribute6, -- Added for CCR0009182
                                 l_rec.freight_pay_party, --Shipment attribute7
                                 lv_shipment_attribute8,
                                 l_rec.ship_method,     --Shipment attribute10
                                 lv_shipment_attribute11,
                                 lv_shipment_attribute12,
                                 lv_shipment_attribute13,
                                 lv_shipment_attribute14,
                                 ln_to_po_header_id);

                DoLog (
                       'Interface_header_id : '
                    || ln_header_interface_id
                    || ' set drop_ship_flag : '
                    || l_rec.drop_ship_flag);

                IF l_rec.requisition_line_id IS NULL
                THEN
                    SELECT PO_DISTRIBUTIONS_INTERFACE_S.NEXTVAL
                      INTO ln_dist_interface_id
                      FROM DUAL;

                    DoLog ('Insert into po_distribution_interface');

                    INSERT INTO po_distributions_interface (
                                    INTERFACE_LINE_ID,
                                    INTERFACE_HEADER_ID,
                                    INTERFACE_DISTRIBUTION_ID,
                                    ORG_ID,
                                    QUANTITY_ORDERED,
                                    DESTINATION_ORGANIZATION_ID,
                                    DELIVER_TO_LOCATION_ID,
                                    DELIVER_TO_PERSON_ID,
                                    SET_OF_BOOKS_ID,
                                    --CHARGE_ACCT_ID,
                                    CREATED_BY,
                                    CREATION_DATE,
                                    LAST_UPDATED_BY,
                                    LAST_UPDATE_DATE)
                         VALUES (ln_line_interface_id, ln_header_interface_id, ln_dist_interface_id, l_rec.org_id, l_rec.quantity, l_rec.ship_to_organization_id, l_rec.ship_to_location_id, NULL, --deliver_to_person_id (get from employee for user_id)
                                                                                                                                                                                                   NULL, --set of books ID
                                                                                                                                                                                                         --   NULL,                               --charge_account_id,
                                                                                                                                                                                                         ln_user_id, SYSDATE, ln_user_id
                                 , SYSDATE);
                END IF;

                DoLog (
                    'Updating PO FROM FIELDS for stg record : ' || l_rec.gtn_po_collab_stg_id);
                DoLog ('PO NUMBER : ' || h_rec.new_po_number);
                DoLog ('PO HEADER ID : ' || h_rec.new_po_header);
                DoLog ('PO LINE ID : ' || l_rec.new_line_id);
                DoLog (
                    'PO LINE LOCATION ID : ' || l_rec.new_line_location_id);

                --Post original PO data to the 'From' fields in the staging table
                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                   SET from_po_number = h_rec.new_po_number, from_po_header_id = h_rec.new_po_header, from_po_line_id = l_rec.new_line_id,
                       from_po_line_location_id = l_rec.new_line_location_id
                 WHERE stg.gtn_po_collab_stg_id = l_rec.gtn_po_collab_stg_id;
            END LOOP;

            /*    IF (   h_rec.src_po_type_id = G_PO_TYPE_DS
                    OR h_rec.src_po_type_id = G_PO_TYPE_JPTQ)
                THEN
                   --Use Autocreate docs
                   run_autocreate_docs (ln_header_interface_id,
                                        h_rec.org_id,
                                        ln_user_id,
                                        ln_to_po_header_id,
                                        PV_ERROR_STAT,
                                        PV_ERROR_MSG);
                ELSE                          */
            --Run PO Import
            /*        run_std_po_import (ln_po_import_batch_id,
                                       h_rec.org_id,
                                       ln_user_id,
                                       ln_poi_req_id,
                                       PV_ERROR_STAT,
                                       PV_ERROR_MSG);*/
            --  END IF;

            create_std_po (ln_po_import_batch_id, h_rec.org_id, PV_ERROR_STAT
                           , PV_ERROR_MSG);

            -- DoLog ('POI request ID : ' || ln_poi_req_id);


            IF PV_ERROR_STAT <> 'S'
            THEN
                --This req did not import to PO. TODO: Log error for this req and continue.
                DoLog ('Error occurred importing REQ to PO.' || PV_ERROR_MSG);

                --'reset error flags.
                PV_ERROR_STAT   := 'S';
                PV_ERROR_MSG    := '';
            ELSE
                --Check for rejected records : This seems to be needed for drop ship type POs
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM po_headers_interface
                 WHERE     process_code = 'REJECTED'
                       AND batch_id = ln_po_import_batch_id
                       AND request_id = ln_poi_req_id;

                DoLog ('count of rejected records : ' || ln_cnt);


                --Approve any generated POs
                FOR po_rec IN po_list (lv_po_number)
                LOOP
                    DoLog ('Approve PO : ' || po_rec.po_number);

                    approve_po (pv_po_number => po_rec.po_number, pn_user_id => ln_user_id, pv_error_stat => PV_ERROR_STAT
                                , pv_error_msg => PV_ERROR_MSG);

                    --Failure here is not fatal as only the PO is not in approved state. It can be approved outside this process.
                    DoLog (
                           'After approve PO : '
                        || po_rec.po_number
                        || ' Stat : '
                        || PV_ERROR_STAT);

                    --Update the stage table PO reference fields
                    update_stg_po_columns (h_rec.new_po_number);
                END LOOP;
            END IF;

            --Update sales order line attribute16 for any ISO Orders
            UPDATE oe_order_lines_all oola
               SET attribute16   =
                       (SELECT mr.supply_source_line_id
                          FROM mtl_reservations mr
                         WHERE     mr.demand_source_line_id = oola.line_id
                               AND mr.supply_source_type_id = 1)
             WHERE oola.line_id IN
                       (SELECT oe_line_id
                          FROM po_requisition_headers_all prha, xxdo.xxdo_gtn_po_collab_stg stg
                         WHERE     prha.requisition_header_id =
                                   stg.req_header_id
                               AND stg.req_type = 'EXTERNAL'
                               AND stg.processing_status_code = 'RUNNING'
                               AND stg.src_po_type_id = G_PO_TYPE_INTERCO
                               AND STG.REQ_CREATED = 'Y'
                               AND stg.batch_id = pn_batch_id);


            ln_po_import_batch_id   := ln_po_import_batch_id + 1;
        END LOOP;

        pv_error_stat   := 'S';
        DoLog ('create_po_from_purchrec_stg - Exit stat =' || pv_error_stat);
    EXCEPTION
        WHEN ex_login
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Login error occurred';
            DoLog (
                'create_po_from_purchrec_stg ex_login :: ' || pv_error_msg); -- CCR0006517
        WHEN ex_update
        THEN
            pv_error_stat   := 'E';
            DoLog (
                   'when ex_update error in procedure create_po_from_purchrec_stg :: '
                || pv_error_msg);                                -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error';
            DoLog (
                   'when others error in procedure create_po_from_purchrec_stg :: '
                || SQLERRM);                                     -- CCR0006517
            DoLog (SQLERRM);
    END;

    PROCEDURE validate_stg_record (pn_gtn_po_collab_stg_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    AS
        ex_invalid_po_data        EXCEPTION;
        ex_invalid_date           EXCEPTION;
        ex_missing_req_field      EXCEPTION;
        ex_invalid_lookup_value   EXCEPTION;
        ex_invalid_value          EXCEPTION;
        ex_invalid_status         EXCEPTION;
        ex_misc_error             EXCEPTION;
        rec_gtn_po_collab_stg     xxdo.xxdo_gtn_po_collab_stg%ROWTYPE;

        lv_message                VARCHAR2 (100);
        ln_line_location_id       NUMBER;
        ld_cexfactory_date        DATE;
        ld_new_promised_date      DATE;
        l_stg_quantity            NUMBER;
        l_po_quantity             NUMBER;
        ld_creation_date          apps.po_headers_all.creation_date%TYPE; -- CCR0006517
        l_num_po_line_count       NUMBER := 0;                   -- CCR0007064
        lv_quantity_billed        NUMBER := 0;                   -- CCR0007262
        ln_po_type                NUMBER;
        ln_cnt                    NUMBER;
        ln_line_num               NUMBER;
        lv_closed_code            VARCHAR2 (20);
        lv_cancel_flag            VARCHAR2 (20);
    BEGIN
        DoLog ('validate_stg_record - Enter');

        --Get stage record to check
        BEGIN
            SELECT *
              INTO rec_gtn_po_collab_stg
              FROM xxdo.xxdo_gtn_po_collab_stg
             WHERE gtn_po_collab_stg_id = pn_gtn_po_collab_stg_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg   :=
                       'Stage record '
                    || pn_gtn_po_collab_stg_id
                    || ' not found.';
                RAISE ex_invalid_value;
            WHEN TOO_MANY_ROWS
            THEN
                --This should not happen
                pv_error_msg    := 'Multiple records returned';
                pv_error_stat   := 'E';
                RETURN;
            WHEN OTHERS
            THEN
                pv_error_msg    := SQLERRM;
                pv_error_stat   := 'E';
                RETURN;
        END;

        --Check required fields
        IF rec_gtn_po_collab_stg.po_line_key IS NULL
        THEN
            lv_message   := 'Item key was not passsed';
            RAISE ex_missing_req_field;
        END IF;

        IF rec_gtn_po_collab_stg.po_line_key NOT LIKE '%.%.%'
        THEN
            lv_message   := 'Item key is not proper format';
            RAISE ex_missing_req_field;
        END IF;

        IF rec_gtn_po_collab_stg.po_number IS NULL
        THEN
            lv_message   := 'po_number is null';
            RAISE ex_missing_req_field;
        END IF;


        ---Allow NULL quantity : will mean no qty chg
        /*     IF rec_gtn_po_collab_stg.quantity IS NULL
             THEN
                lv_message := 'quantity is null';
                RAISE ex_missing_req_field;
             END IF;*/

        IF NVL (rec_gtn_po_collab_stg.quantity, 1) <= 0
        THEN
            lv_message   := 'invalid quantity';
            RAISE ex_missing_req_field;
        END IF;

        DoLog ('Split Flag : ' || rec_gtn_po_collab_stg.split_flag);

        --Validate lookup data
        IF rec_gtn_po_collab_stg.split_flag IS NOT NULL
        THEN
            IF NOT check_for_value_set_value (
                       gLookupYN,
                       rec_gtn_po_collab_stg.split_flag)
            THEN
                doLog ('Split flag has invalid value');
                lv_message   := 'Split flag has invalid value';
                RAISE ex_invalid_lookup_value;
            END IF;

            -- START CCR0006285
            l_stg_quantity        := NULL;
            l_po_quantity         := NULL;
            l_num_po_line_count   := NULL;                       -- CCR0007064

            DoLog ('Before check quantities/shipment status');

            BEGIN
                SELECT SUM (quantity)
                  INTO l_stg_quantity
                  FROM xxdo.xxdo_gtn_po_collab_stg
                 WHERE     po_line_location_id =
                           rec_gtn_po_collab_stg.po_line_location_id
                       AND batch_id = rec_gtn_po_collab_stg.batch_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_stg_quantity   := NULL;
                WHEN OTHERS
                THEN
                    l_stg_quantity   := NULL;
                    doLog (
                           'Error in fetching Stg Quantity for Line Location id :: '
                        || rec_gtn_po_collab_stg.po_line_location_id
                        || ' for batch id :: '
                        || rec_gtn_po_collab_stg.batch_id
                        || ' :: '
                        || SQLERRM);
                    lv_message       :=
                           'Error in fetching Stg Quantity for Line Location id :: '
                        || rec_gtn_po_collab_stg.po_line_location_id
                        || ' for batch id :: '
                        || rec_gtn_po_collab_stg.batch_id
                        || ' :: '
                        || SQLERRM;
                    RAISE ex_misc_error;
            END;

            BEGIN
                SELECT quantity,
                       closed_code,
                       cancel_flag,
                       (SELECT DISTINCT line_num
                          FROM po_lines_all pla
                         WHERE pla.po_line_id = plla.po_line_id) line_num
                  INTO l_po_quantity, lv_closed_code, lv_cancel_flag, ln_line_num
                  FROM po_line_locations_all plla
                 WHERE line_location_id =
                       rec_gtn_po_collab_stg.po_line_location_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_po_quantity   := NULL;
                WHEN OTHERS
                THEN
                    l_po_quantity   := NULL;
                    doLog (
                           'Error in fetching PO Quantity for Line Location id :: '
                        || rec_gtn_po_collab_stg.po_line_location_id
                        || ' for batch id :: '
                        || rec_gtn_po_collab_stg.batch_id
                        || ' :: '
                        || SQLERRM);
                    lv_message      :=
                           'Error in fetching PO Quantity for Line Location id :: '
                        || rec_gtn_po_collab_stg.po_line_location_id
                        || ' for batch id :: '
                        || rec_gtn_po_collab_stg.batch_id
                        || ' :: '
                        || SQLERRM;
                    RAISE ex_misc_error;
            END;

            DoLog ('After get quantities/shipment status');

            IF NVL (lv_cancel_flag, 'N') = 'Y'
            THEN
                dolog ('PO shipment is canceled');
                lv_message   := 'PO shipment is canceled';
                RAISE ex_invalid_status;
            END IF;

            IF lv_closed_code IN ('CLOSED', 'CLOSED FOR RECEIVING')
            THEN
                dolog ('PO shipment is not open for receiving');
                lv_message   := 'PO shipment is not open for receiving';
                RAISE ex_invalid_status;
            END IF;



            IF l_stg_quantity IS NOT NULL AND l_po_quantity IS NOT NULL
            THEN
                DoLog ('Qty change');

                IF l_stg_quantity != l_po_quantity
                THEN                                         --quantity change
                    ln_po_type   :=
                        get_po_type (rec_gtn_po_collab_stg.po_number);
                    dolog ('PO Type : ' || ln_po_type);

                    IF    ln_po_type = G_PO_TYPE_XDOCK
                       OR ln_po_type = G_PO_TYPE_DSHIP
                    --  OR ln_po_type = G_PO_TYPE_DS -- Commneted for CCR0009182
                    THEN
                        --Invalid PO type for split
                        doLog (
                            -- 'Quantity change is an invalid action for Drop Ship, XDOCK and Direct Ship POs');
                            'Quantity change is an invalid action for XDOCK and Direct Ship POs');
                        lv_message   :=
                            -- 'Quantity change is an invalid action for Drop ship, XDOCK and Direct Ship POs';
                             'Quantity change is an invalid action for XDOCK and Direct Ship POs';
                        RAISE ex_invalid_value;
                    END IF;
                END IF;

                IF NVL (rec_gtn_po_collab_stg.split_flag, 'N') = 'Y'
                THEN
                    ln_po_type   :=
                        get_po_type (rec_gtn_po_collab_stg.po_number);

                    IF    ln_po_type = G_PO_TYPE_XDOCK
                       OR ln_po_type = G_PO_TYPE_DSHIP
                    THEN
                        --Invalid PO type for split
                        doLog (
                            'Split is an invalid action for XDOCK and Direct Ship POs');
                        lv_message   :=
                            'Split is an invalid action for XDOCK and Direct Ship POs';
                        RAISE ex_invalid_value;
                    END IF;


                    -- START CCR0007064
                    BEGIN
                        SELECT COUNT (1)
                          INTO l_num_po_line_count
                          FROM xxdo.xxdo_gtn_po_collab_stg
                         WHERE     po_line_location_id =
                                   rec_gtn_po_collab_stg.po_line_location_id
                               AND batch_id = rec_gtn_po_collab_stg.batch_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_po_line_count   := 0;
                            doLog (
                                   'Error in fetching PO Line Count When Split Flag is Yes for Line Location id :: '
                                || rec_gtn_po_collab_stg.po_line_location_id
                                || ' for batch id :: '
                                || rec_gtn_po_collab_stg.batch_id
                                || ' :: '
                                || SQLERRM);
                    END;

                    IF NVL (l_num_po_line_count, 0) < 2
                    THEN
                        UPDATE xxdo.xxdo_gtn_po_collab_stg
                           SET processing_status_code = 'ERROR', error_message = 'Receivied One Entry for the PO Line from GTN with Split flag as Y'
                         WHERE     po_line_location_id =
                                   rec_gtn_po_collab_stg.po_line_location_id
                               AND batch_id = rec_gtn_po_collab_stg.batch_id;

                        COMMIT;
                    END IF;
                -- END CCR0007064

                /*          BEGIN
                             SELECT SUM (quantity)
                               INTO l_stg_quantity
                               FROM xxdo.xxdo_gtn_po_collab_stg
                              WHERE     po_line_location_id =
                                           rec_gtn_po_collab_stg.po_line_location_id
                                    AND batch_id = rec_gtn_po_collab_stg.batch_id;
                          EXCEPTION
                             WHEN NO_DATA_FOUND
                             THEN
                                l_stg_quantity := NULL;
                             WHEN OTHERS
                             THEN
                                l_stg_quantity := NULL;
                                doLog (
                                      'Error in fetching Stg Quantity for Line Location id :: '
                                   || rec_gtn_po_collab_stg.po_line_location_id
                                   || ' for batch id :: '
                                   || rec_gtn_po_collab_stg.batch_id
                                   || ' :: '
                                   || SQLERRM);
                          END;

                          BEGIN
                             SELECT quantity
                               INTO l_po_quantity
                               FROM po_line_locations_all
                              WHERE line_location_id =
                                       rec_gtn_po_collab_stg.po_line_location_id;
                          EXCEPTION
                             WHEN NO_DATA_FOUND
                             THEN
                                l_po_quantity := NULL;
                             WHEN OTHERS
                             THEN
                                l_po_quantity := NULL;
                                doLog (
                                      'Error in fetching PO Quantity for Line Location id :: '
                                   || rec_gtn_po_collab_stg.po_line_location_id
                                   || ' for batch id :: '
                                   || rec_gtn_po_collab_stg.batch_id
                                   || ' :: '
                                   || SQLERRM);
                          END;

                          IF l_stg_quantity IS NOT NULL AND l_po_quantity IS NOT NULL
                          THEN
                             IF l_stg_quantity != l_po_quantity
                             THEN                                          --quantity change
                                ln_po_type := get_po_type (rec_gtn_po_collab_stg.po_number);

                                IF    ln_po_type = G_PO_TYPE_XDOCK
                                   OR ln_po_type = G_PO_TYPE_DIRECT
                                   OR ln_po_type = G_PO_TYPE_DS
                                THEN
                                   --Invalid PO type for split
                                   doLog (
                                      'Quantity change is an invalid action for Drop Ship, XDOCK and Direct Ship POs');
                                   lv_message :=
                                      'Quantity change is an invalid action for Drop ship, XDOCK and Direct Ship POs';
                                   RAISE ex_invalid_value;
                                END IF;
                             END IF;*/



                /*   IF l_stg_quantity > l_po_quantity
                   THEN
                      UPDATE xxdo.xxdo_gtn_po_collab_stg
                         SET processing_status_code = 'ERROR',
                             error_message =
                                'Total Staging Quantity is not same as PO Line Quantity'
                       WHERE     po_line_location_id =
                                    rec_gtn_po_collab_stg.po_line_location_id
                             AND batch_id = rec_gtn_po_collab_stg.batch_id;

                      COMMIT;
                   END IF;*/
                END IF;
            END IF;
        -- END CCR0006285
        END IF;

        IF rec_gtn_po_collab_stg.ship_method IS NULL
        THEN
            lv_message   :=
                   'Ship method is NULL for item key.'
                || rec_gtn_po_collab_stg.po_line_key;
            RAISE ex_invalid_po_data;
        ELSE
            IF NOT check_for_value_set_value (
                       gLookupShipMethod,
                       rec_gtn_po_collab_stg.ship_method)
            THEN
                doLog ('Ship Method has invalid value.');
                lv_message   := 'Ship Method has invalid value.';
                RAISE ex_invalid_lookup_value;
            ELSE
                IF ln_po_type != G_PO_TYPE_DS --Don't check Drop Ship for transit Time
                THEN
                    doLog ('Date Check');

                    IF get_pol_transit_days (
                           p_po_number     => rec_gtn_po_collab_stg.po_number,
                           p_po_line_num   => ln_line_num,
                           p_po_ship_method   =>
                               rec_gtn_po_collab_stg.ship_method) =
                       0
                    THEN
                        doLog ('Transit time not defined for ship method.');
                        lv_message   :=
                               'Transit time not defined for ship method.'
                            || rec_gtn_po_collab_stg.po_line_key;
                        RAISE ex_invalid_po_data;
                    END IF;
                END IF;
            END IF;
        END IF;

        IF rec_gtn_po_collab_stg.original_line_flag IS NOT NULL
        THEN
            IF NOT check_for_value_set_value (
                       gLookupYN,
                       rec_gtn_po_collab_stg.original_line_flag)
            THEN
                doLog ('Original Line Flag has invalid value');
                lv_message   := 'Original Line Flag has invalid value';
                RAISE ex_invalid_lookup_value;
            END IF;
        END IF;

        IF rec_gtn_po_collab_stg.supplier_site_code IS NOT NULL
        THEN
            doLog ('Validate supplier site code');

            SELECT COUNT (*)
              INTO ln_cnt
              FROM po_headers_all pha, ap_suppliers aps, ap_supplier_sites_all apsa
             WHERE     pha.vendor_id = aps.vendor_id
                   AND aps.vendor_id = apsa.vendor_id
                   AND apsa.org_id = pha.org_id
                   AND apsa.vendor_site_code =
                       rec_gtn_po_collab_stg.supplier_site_code;

            IF ln_cnt = 0
            THEN
                doLog (
                       rec_gtn_po_collab_stg.supplier_site_code
                    || ' is not a valid supplier site code for the PO');
                RAISE ex_invalid_value;
            END IF;
        END IF;

        ln_line_location_id   :=
            Get_POLLA_ID_from_item_key (rec_gtn_po_collab_stg.po_number,
                                        rec_gtn_po_collab_stg.po_line_key);
        DoLog (
               'POLLA ID found for key : '
            || rec_gtn_po_collab_stg.po_line_key
            || ' is '
            || ln_line_location_id);


        --Item_key not pointing to valid polla id
        IF ln_line_location_id IS NULL
        THEN
            lv_message   :=
                   'Item Key '
                || rec_gtn_po_collab_stg.po_line_key
                || ' does not reference a valid po line/shipment/distribution';
            RAISE ex_invalid_po_data;
        END IF;

        /*     --validate date format of date fields
             BEGIN
                IF rec_gtn_po_collab_stg.ex_factory_date IS NOT NULL
                THEN
                   ld_cexfactory_date :=
                      TO_DATE (rec_gtn_po_collab_stg.ex_factory_date, 'MM/DD/YYYY');
                END IF;

                IF rec_gtn_po_collab_stg.new_promised_date IS NOT NULL
                THEN
                   ld_new_promised_date :=
                      TO_DATE (rec_gtn_po_collab_stg.new_promised_date,
                               'MM/DD/YYYY');
                END IF;
             EXCEPTION
                WHEN OTHERS
                THEN
                   RAISE ex_invalid_date;
             END;*/

        --No longer required CCR0008134
        --The Freight Pay party value is required to be sent from Oracle
        /*
        IF rec_gtn_po_collab_stg.freight_pay_party IS NULL
        THEN
           lv_message :=
                 'Freight Pay party is NULL for item key '
              || rec_gtn_po_collab_stg.po_line_key;
           RAISE ex_invalid_po_data;
        END IF;
        */

        IF rec_gtn_po_collab_stg.freight_pay_party IS NOT NULL
        THEN
            IF NOT check_for_value_set_value (
                       gLookupFreightPayParty,
                       rec_gtn_po_collab_stg.freight_pay_party)
            THEN
                doLog ('Freight Pay Party has invalid value');
                lv_message   := 'Freight Pay Party has invalid value';
                RAISE ex_invalid_lookup_value;
            END IF;
        END IF;

        -- START CCR0006517
        ld_creation_date     := NULL;

        BEGIN
            SELECT creation_date
              INTO ld_creation_date
              FROM po_headers_all
             WHERE segment1 = rec_gtn_po_collab_stg.po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                doLog (
                       'Unable to find Purchase Order :: '
                    || ' :: '
                    || rec_gtn_po_collab_stg.po_number
                    || ' :: '
                    || SQLERRM);
        END;

        IF rec_gtn_po_collab_stg.new_promised_date < ld_creation_date
        THEN
            UPDATE xxdo.xxdo_gtn_po_collab_stg
               SET processing_status_code = 'ERROR', error_message = 'New Promised date cannot be less than Purchase order creation date'
             WHERE     po_line_location_id =
                       rec_gtn_po_collab_stg.po_line_location_id
                   AND batch_id = rec_gtn_po_collab_stg.batch_id;

            COMMIT;
        END IF;

        -- END CCR0006517

        -- START CCR0007262
        lv_quantity_billed   := 0;

        BEGIN
            SELECT NVL (quantity_billed, 0)
              INTO lv_quantity_billed
              FROM po_line_locations_all
             WHERE line_location_id =
                   rec_gtn_po_collab_stg.po_line_location_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_quantity_billed   := 0;
                doLog (
                       'Unable to fetch Quantity Billed for Line Loc Id :: '
                    || ' :: '
                    || rec_gtn_po_collab_stg.po_line_location_id
                    || ' :: '
                    || SQLERRM);
        END;

        IF rec_gtn_po_collab_stg.split_flag = 'N'
        THEN
            IF     lv_quantity_billed > 0
               AND lv_quantity_billed > rec_gtn_po_collab_stg.quantity
            THEN
                UPDATE xxdo.xxdo_gtn_po_collab_stg
                   SET processing_status_code = 'ERROR', error_message = 'Original PO Quantity is less than Billed Quantity' --Added for CCR0009182
                 --'Staging Quantity is Greater than Quantity Billed' --Commented for CCR0009182
                 -- 'Quantity Billed is Greater than Staging Quantity'  -- Commented for CCR0009182
                 WHERE     po_line_location_id =
                           rec_gtn_po_collab_stg.po_line_location_id
                       AND batch_id = rec_gtn_po_collab_stg.batch_id;
            END IF;
        ELSIF     rec_gtn_po_collab_stg.split_flag = 'Y'
              AND rec_gtn_po_collab_stg.original_line_flag = 'Y'
        THEN
            IF     lv_quantity_billed > 0
               AND lv_quantity_billed > rec_gtn_po_collab_stg.quantity
            THEN
                UPDATE xxdo.xxdo_gtn_po_collab_stg
                   SET processing_status_code = 'ERROR', error_message = 'Original PO Quantity is less than Billed Quantity' --Added for CCR0009182
                 --'Staging Quantity is Greater than Quantity Billed' --Commented for CCR0009182
                 -- 'Quantity Billed is Greater than Staging Quantity' -- Commented for CCR0009182
                 WHERE     po_line_location_id =
                           rec_gtn_po_collab_stg.po_line_location_id
                       AND batch_id = rec_gtn_po_collab_stg.batch_id;
            END IF;
        END IF;

        DoLog ('validate_stg_record - End');
    -- END CCR0007262
    EXCEPTION
        WHEN ex_misc_error
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_message;
            dolog ('misc_error: ' || pv_error_msg);
        WHEN ex_invalid_status
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_message;
            dolog (
                'validate_stg_record ex_invalid_status : ' || pv_error_msg); -- CCR0006517
        WHEN ex_invalid_po_data
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_message;
            dolog (
                'validate_stg_record ex_invalid_po_data : ' || pv_error_msg); -- CCR0006517
        WHEN ex_invalid_lookup_value
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_message;
            dolog (
                   'validate_stg_record ex_invalid_lookup_value : '
                || pv_error_msg);                                -- CCR0006517
        WHEN ex_missing_req_field
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_message;
            dolog (
                'validate_stg_record ex_missing_req_field : ' || pv_error_msg); -- CCR0006517
        WHEN ex_invalid_date
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Invalid date format passed';
            dolog ('validate_stg_record ex_invalid_date : ' || pv_error_msg); -- CCR0006517
        WHEN ex_invalid_value
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_message;
            dolog ('validate_stg_record ex_invalid_value : ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Unexpected error ' || SQLERRM;
            dolog ('validate_stg_record : ' || pv_error_msg);    -- CCR0006517
    END;

    --Create REQ interface records for records on Staging table


    --Procedure to be called from external source to populate the base staging table data

    PROCEDURE post_gtn_poc_to_stage (pn_batch_id IN OUT NUMBER, --OPT : If not provided, it will be auto generated and the batch number value will be returned.
                                                                pv_po_number IN VARCHAR2:= NULL, --REQ
                                                                                                 pv_item_key IN VARCHAR2, --REQ (format x.x.x)
                                                                                                                          pv_split_flag IN VARCHAR2:= 'true', --OPT (true/false)LOV TrueFalseValueSet- 1013975
                                                                                                                                                              pv_shipmethod IN VARCHAR2:= NULL, --OPT (Air, Ocean) LOV XXDO_SHIP_METHOD - 1015991
                                                                                                                                                                                                pn_quantity IN NUMBER:= NULL, --OPT (value > 0)
                                                                                                                                                                                                                              pv_cexfactory_date IN VARCHAR2:= NULL, --OPT -DEF value from PLLA
                                                                                                                                                                                                                                                                     pn_unit_price IN NUMBER:= NULL, --OPT -DEF value from PLLA
                                                                                                                                                                                                                                                                                                     pv_new_promised_date IN VARCHAR2:= NULL, --OPT -DEF value from PLLA
                                                                                                                                                                                                                                                                                                                                              pv_freight_pay_party IN VARCHAR2:= NULL, --OPT (Deckers, Factory, Vendor) LOV XXDO_FREIGHT_PAY_PARTY_LOV - 1016006
                                                                                                                                                                                                                                                                                                                                                                                       pv_original_line_flag IN VARCHAR2:= 'false', --OPT (true/false) LOV TrueFalseValueSet - 1013975
                                                                                                                                                                                                                                                                                                                                                                                                                                    pv_supplier_site_code IN VARCHAR2:= NULL, --OPT For supplier site change
                                                                                                                                                                                                                                                                                                                                                                                                                                                                              pv_delay_reason IN VARCHAR2:= NULL, --OPT Delay reason
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  pv_comments1 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   pv_comments2 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    pv_comments3 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     pv_comments4 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      pv_error_stat OUT VARCHAR2
                                     , pv_error_msg OUT VARCHAR2)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ln_line_num               NUMBER;
        ln_shipment_num           NUMBER;
        ln_distrb_num             NUMBER;

        ln_instr                  NUMBER;
        ln_user_id                NUMBER;
        ln_org_id                 NUMBER;
        ln_cnt                    NUMBER := 1;
        ln_substr                 NUMBER := 1;

        ln_item_id                NUMBER;
        ln_preparer_id            NUMBER;

        ld_new_promised_date      DATE;
        ld_cexfactory_date        DATE;

        lv_message                VARCHAR2 (2000);

        ln_po_header_id           NUMBER;
        ln_po_line_id             NUMBER;
        ln_line_location_id       NUMBER;
        ln_distribution_id        NUMBER;

        ld_promised_date          DATE;
        lv_cxf_date               VARCHAR2 (20);
        ln_unit_price             NUMBER;

        ln_gtn_po_collab_stg_id   NUMBER;
        lv_original_line_flag     VARCHAR2 (1);
        lv_drop_ship_flag         VARCHAR2 (1);
        lv_split_flag             VARCHAR2 (1);
        lv_cancel_flag            VARCHAR2 (1);

        lv_shipmethod             VARCHAR2 (40);
        lv_freight_pay_party      VARCHAR2 (40);
    BEGIN
        dolog ('post_gtn_poc_to_stage - Enter');
        --Rev3 Validation removed here
        ln_line_location_id   :=
            Get_POLLA_ID_from_item_key (pv_po_number, pv_item_key);

        --Validate item key points to a valid PO line/shipment/distribution

        BEGIN
            SELECT pha.po_header_id, pla.po_line_id, --  plla.line_location_id,--Rev3
                                                     pda.po_distribution_id,
                   pla.item_id, pha.agent_id, -- pha.created_by, -- commented as part of CCR0010003
                                              pha.agent_id created_by, -- added as part of CCR0010003
                   NVL (plla.drop_ship_flag, 'N') drop_ship_flag, pla.unit_price, pla.line_num,
                   plla.attribute5, plla.promised_date, plla.attribute7,
                   plla.attribute10, plla.shipment_num
              INTO ln_po_header_id, ln_po_line_id, -- ln_line_location_id,--Rev3
                                                   ln_distribution_id, ln_item_id,
                                  ln_preparer_id, ln_user_id, lv_drop_ship_flag,
                                  ln_unit_price, ln_line_num, lv_cxf_date,
                                  ld_promised_date, lv_freight_pay_party, lv_shipmethod,
                                  ln_shipment_num
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla,
                   apps.po_distributions_all pda
             WHERE     1 = 1
                   -- AND plla.shipment_num = TO_NUMBER (ln_shipment_num)
                   -- AND pla.line_num = TO_NUMBER (ln_line_num)
                   -- AND pda.distribution_num = TO_NUMBER (ln_distrb_num)
                   AND plla.line_location_id = ln_line_location_id      --Rev3
                   --  AND pha.segment1 = pv_po_number
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id
                   AND plla.line_location_id = pda.line_location_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DoLog ('No Data');
                NULL; --Rev3 when no data then we will just populate NULL in respective fields
        END;


        --check/set batch ID
        IF pn_batch_id IS NULL
        THEN
            --Batch ID not passed set from sequence.
            pn_batch_id   := Get_Next_Batch_id;
            DoLog ('setting batch ID to ' || pn_batch_id);
        END IF;

        --convert true/false fields to 'Y'/'N' values
        IF pv_original_line_flag = 'true'
        THEN
            lv_original_line_flag   := 'Y';
        ELSIF pv_original_line_flag = 'false'
        THEN
            lv_original_line_flag   := 'N';
        END IF;

        IF pv_split_flag = 'true'
        THEN
            lv_split_flag   := 'Y';
        ELSIF pv_split_flag = 'false'
        THEN
            lv_split_flag   := 'N';
        END IF;

        --Convert string date fields to dates
        BEGIN
            IF pv_cexfactory_date IS NOT NULL
            THEN
                ld_cexfactory_date   :=
                    TO_DATE (pv_cexfactory_date, 'MM/DD/YYYY');
            --         ELSE
            --Get CFX_DATE from PO Shipment
            --           ld_cexfactory_date :=
            --               TO_DATE (lv_cxf_date, 'YYYY/MM/DD HH24:MI:SS');
            END IF;

            DoLog ('ld_exfactory_date : ' || ld_cexfactory_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog ('Invalid date for exfactory date');
        END;

        BEGIN
            IF pv_new_promised_date IS NOT NULL
            THEN
                ld_new_promised_date   :=
                    TO_DATE (pv_new_promised_date, 'MM/DD/YYYY');
            -- ELSE
            --Get Promised date from PO Shipment
            -- ld_new_promised_date := ld_promised_date;
            --ld_new_promised_date := NVL (ld_cexfactory_date, ld_promised_date);

            END IF;

            DoLog ('ld_new_promised_date : ' || ld_new_promised_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                DoLog ('Invalid date for promised date');
        END;

        --We are not cancelling the original PO line in any of the PO source types.
        lv_cancel_flag   := 'N';

        DoLog ('get next sequence');

        --get next ID value

        SELECT xxdo.xxdo_gtn_po_collab_stg_seq.NEXTVAL
          INTO ln_gtn_po_collab_stg_id
          FROM DUAL;

        --insert data into stage table

        INSERT INTO xxdo.xxdo_gtn_po_collab_stg (gtn_po_collab_stg_id,
                                                 batch_id,
                                                 creation_date,
                                                 created_by,
                                                 user_id,
                                                 split_flag,
                                                 cancel_line,
                                                 ship_method,
                                                 quantity,
                                                 ex_factory_date,
                                                 unit_price,
                                                 new_promised_date,
                                                 freight_pay_party,
                                                 original_line_flag,
                                                 po_header_id,
                                                 po_number,
                                                 po_line_id,
                                                 line_num,
                                                 po_line_location_id,
                                                 shipment_num,
                                                 po_distribution_id,
                                                 distribution_num,
                                                 item_id,
                                                 preparer_id,
                                                 drop_ship_flag,
                                                 req_created,
                                                 processing_status_code,
                                                 error_message,
                                                 po_line_key,           --Rev3
                                                 comments1,
                                                 comments2,
                                                 comments3,
                                                 comments4,
                                                 supplier_site_code,
                                                 delay_reason)
             VALUES (ln_gtn_po_collab_stg_id, pn_batch_id, SYSDATE,
                     NVL (ln_user_id, -1), NVL (ln_user_id, -1), lv_split_flag, lv_cancel_flag, NVL (pv_shipmethod, NVL (lv_shipmethod, 'Ocean')), pn_quantity, ld_cexfactory_date, NVL (pn_unit_price, ln_unit_price), ld_new_promised_date, NVL (pv_freight_pay_party, lv_freight_pay_party), lv_original_line_flag, ln_po_header_id, pv_po_number, ln_po_line_id, ln_line_num, ln_line_location_id, ln_shipment_num, ln_distribution_id, ln_distrb_num, ln_item_id, ln_preparer_id, lv_drop_ship_flag, 'N', 'PENDING', NULL, pv_item_key, --Rev3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             pv_comments1, pv_comments2, pv_comments3, pv_comments4
                     , pv_supplier_site_code, pv_delay_reason);

        DoLog ('after insert');
        COMMIT;
        pv_error_stat    := 'S';
        pv_error_msg     := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            dolog (
                   'OTHERS block : post_gtn_poc_to_stage : '
                || SUBSTR (SQLERRM, 1, 900));
            pv_error_stat   := 'U';
            pv_error_msg    :=
                   'Error in validate poc line'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
            ROLLBACK;
    END;


    PROCEDURE populate_stage_data (pn_batch_id IN NUMBER,  --REQ - valid batch
                                                          pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    AS
        ln_revision_num              apps.po_headers_all.revision_num%TYPE;
        lv_po_type                   apps.po_headers_all.attribute10%TYPE;
        lv_cancel_flag               apps.po_line_locations_all.cancel_flag%TYPE;
        lv_closed_code               apps.po_line_locations_all.closed_code%TYPE;
        lv_approved_flag             apps.po_headers_all.approved_flag%TYPE;
        lv_ex_factory_date           apps.po_line_locations_all.attribute5%TYPE;
        lv_orig_ex_factory_date      apps.po_line_locations_all.attribute8%TYPE;
        ld_promised_date             apps.po_line_locations_all.promised_date%TYPE;
        ln_list_price_per_unit       apps.po_lines_all.list_price_per_unit%TYPE;
        lv_brand                     APPS.po_lines_all.attribute1%TYPE;
        ln_quantity                  apps.po_line_locations_all.quantity%TYPE;
        ln_quantity_received         apps.po_line_locations_all.quantity_received%TYPE;
        ln_drop_ship_source_id       apps.oe_drop_ship_sources.drop_ship_source_id%TYPE;
        lv_drop_ship_flag            apps.po_line_locations_all.drop_ship_flag%TYPE;
        ln_line_location_id          apps.po_line_locations_all.line_location_id%TYPE;
        ln_ship_to_organization_id   apps.po_line_locations_all.ship_to_organization_id%TYPE;
        ln_ship_to_location_id       apps.po_line_locations_all.ship_to_location_id%TYPE;

        --Get a cursor for all running stage records that are in RUNNING status for the passed in batch
        CURSOR c_rec IS
            SELECT *
              FROM xxdo.xxdo_gtn_po_collab_stg
             WHERE     batch_id = pn_batch_id
                   AND processing_status_code = 'RUNNING';

        ln_req_header_id             NUMBER;
        ln_req_line_id               NUMBER;
        ln_line_id                   NUMBER;
        ln_header_id                 NUMBER;
        ln_reservation_id            NUMBER;
        ln_order_type_id             NUMBER;
        lv_error_stat                VARCHAR2 (1);
        lv_error_msg                 VARCHAR2 (4000);
        ln_org_id                    NUMBER;
        ln_line_num                  NUMBER;
        ln_shipment_num              NUMBER;

        ln_vendor_id                 NUMBER;
        ln_vendor_site_id            NUMBER;

        lv_msg                       VARCHAR2 (400);
        ex_validation_rec            EXCEPTION;
        ex_validation_proc           EXCEPTION;
    BEGIN
        DoLog ('populate_stage_data - Enter');
        DoLog ('Batch ID     :' || pn_batch_id);

        FOR rec IN c_rec
        LOOP
            BEGIN
                --Rev3
                --Detailed validation moved to this step
                DoLog ('Performing record validation');

                --Rev3 Validate record data
                validate_stg_record (rec.gtn_po_collab_stg_id,
                                     lv_error_stat,
                                     lv_msg);

                --If validation fails, error out this record
                IF lv_error_stat != 'S'
                THEN
                    RAISE ex_validation_rec;
                END IF;

                --To allow for exception block in the loop
                DoLog ('Updating record - ID:' || rec.gtn_po_collab_stg_id);



                DoLog ('--Posting PO data');

                --Get additional PO data
                --Assumption : given a PO Shipment ID (line_location record ID) there will only be one record returned (no multiple distributions).
                BEGIN
                    SELECT pha.revision_num, pha.org_id, pha.attribute10 po_type,
                           pha.vendor_id, pha.vendor_site_id, plla.cancel_flag,
                           plla.closed_code, pha.approved_flag, plla.attribute4 ex_factory_date,
                           plla.attribute8 orig_ex_factory_date, plla.promised_date, pla.list_price_per_unit,
                           pla.attribute1 brand, pla.line_num, plla.quantity,
                           plla.quantity_received, plla.shipment_num, NVL (plla.drop_ship_flag, 'N') drop_ship_flag,
                           plla.line_location_id, plla.ship_to_organization_id, plla.ship_to_location_id,
                           dss.drop_ship_source_id
                      INTO ln_revision_num, ln_org_id, lv_po_type, ln_vendor_id,
                                          ln_vendor_site_id, lv_cancel_flag, lv_closed_code,
                                          lv_approved_flag, lv_ex_factory_date, lv_orig_ex_factory_date,
                                          ld_promised_date, ln_list_price_per_unit, lv_brand,
                                          ln_line_num, ln_quantity, ln_quantity_received,
                                          ln_shipment_num, lv_drop_ship_flag, ln_line_location_id,
                                          ln_ship_to_organization_id, ln_ship_to_location_id, ln_drop_ship_source_id
                      FROM apps.po_headers_all pha,
                           apps.po_lines_all pla,
                           apps.po_line_locations_all plla,
                           (SELECT dss.line_location_id, dss.drop_ship_source_id
                              FROM apps.oe_drop_ship_sources dss, apps.oe_order_lines_all oola
                             WHERE     dss.line_id = oola.line_id
                                   AND oola.open_flag = 'Y'
                                   AND oola.shipped_quantity IS NULL
                                   AND oola.actual_shipment_date IS NULL) dss -- Addd oola conditions to fetch open SO Lines CCR0006285
                     --'Rev1 added handling to multipple dss links. Only link to open SO lines
                     WHERE     pha.po_header_id = pla.po_header_id
                           AND pla.po_line_id = plla.po_line_id
                           AND plla.line_location_id =
                               dss.line_location_id(+)
                           AND plla.line_location_id =
                               rec.po_line_location_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_msg   :=
                               'No PO line found for ID : '
                            || rec.po_line_location_id;
                        RAISE ex_validation_rec;
                    WHEN TOO_MANY_ROWS
                    THEN
                        --there could be multiple DSS records pointing to this Shipment
                        lv_msg   := 'PO Shipment returned too many rows';

                        RAISE ex_validation_rec;
                END;

                --Validate PO data
                DoLog ('--Post PO data');

                --Rev3 Validate active record for POLL matching POL matching POH
                --We have POLL value from table

                --Post PO data to stage record
                UPDATE xxdo.xxdo_gtn_po_collab_stg
                   SET closed_code = lv_closed_code,    --Shipment closed code
                                                     cancel_flag = lv_cancel_flag, --Shipment cancel flag
                                                                                   revision_num = ln_revision_num, --PO revision number
                       po_type = lv_po_type,       --PO type (pha.attribute10)
                                             org_id = ln_org_id,      --PO ORG
                                                                 vendor_id = ln_vendor_id, --PO vendor
                       vendor_site_id = ln_vendor_site_id,    --PO vendor site
                                                           approved_flag = lv_approved_flag, --PO approved flag
                                                                                             line_num = ln_line_num, --line_num
                       shipment_num = ln_shipment_num,          --shipment_num
                                                       ship_to_organization_id = ln_ship_to_organization_id, --Shipment ship_to_organization_id
                                                                                                             ship_to_location_id = ln_ship_to_location_id, --Shipment ship_to_location_id
                       brand = lv_brand                             --PO Brand
                 WHERE     gtn_po_collab_stg_id = rec.gtn_po_collab_stg_id
                       AND from_po_number IS NULL; --Rev3 : for reprocess don't populate PO data if the po_number repreents the new PO created

                BEGIN
                    DoLog ('--Get REQ data' || rec.po_line_location_id);

                    --Get REQ data for PO
                    SELECT requisition_header_id, requisition_line_id
                      INTO ln_req_header_id, ln_req_line_id
                      FROM po_requisition_lines_all prla
                     WHERE line_location_id = rec.po_line_location_id;

                    --Validate REQ data
                    DoLog ('--Post REQ data');

                    --post REQ data to stage record
                    UPDATE xxdo.xxdo_gtn_po_collab_stg
                       SET req_header_id = ln_req_header_id, --Purchase REQ Header for shipment
                                                             req_line_id = ln_req_line_id --Purchase REQ Line for shipment
                     WHERE gtn_po_collab_stg_id = rec.gtn_po_collab_stg_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        --A REQ will not exist for converted PO lines so this will not result in failure
                        NULL;
                END;

                --Initialize SO link data
                ln_line_id          := NULL;
                ln_header_id        := NULL;
                ln_reservation_id   := NULL;

                --Get sales order data from PO
                DoLog ('Drop ship flag : ' || rec.drop_ship_flag);
                DoLog ('Drop ship source id : ' || ln_drop_ship_source_id);

                --First is this a drop ship
                IF     NVL (rec.drop_ship_flag, 'N') = 'Y'
                   AND ln_drop_ship_source_id IS NOT NULL
                THEN
                    DoLog ('select for DS');

                    BEGIN
                        --Get DS order data for this PO shipment line
                        SELECT oola.line_id, oola.header_id
                          INTO ln_line_id, ln_header_id
                          FROM oe_order_lines_all oola, oe_drop_ship_sources dss
                         WHERE     oola.line_id = dss.line_id
                               AND dss.drop_ship_source_id =
                                   ln_drop_ship_source_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            DoLog ('No data from PO. Checking from SO');

                            --check if there is a DS record from the SO side (if the order line was created but no PO was generated)
                            BEGIN
                                SELECT dss.DROP_SHIP_SOURCE_ID, stg.oe_line_id, stg.oe_header_id
                                  INTO ln_drop_ship_source_id, ln_line_id, ln_header_id
                                  FROM xxdo.xxdo_gtn_po_collab_stg stg, oe_drop_ship_sources dss
                                 WHERE     STG.GTN_PO_COLLAB_STG_ID =
                                           rec.GTN_PO_COLLAB_STG_ID
                                       AND stg.oe_line_id = dss.line_id;

                                DoLog (
                                       'From SO - Line ID : '
                                    || ln_line_id
                                    || ' : Header ID '
                                    || ln_header_id
                                    || ' Drop Ship Source ID : '
                                    || ln_drop_ship_source_id);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lv_msg   :=
                                        'Drop ship PO shipment line missing sourcing SO line data';


                                    RAISE ex_validation_rec;
                            END;
                        -- Start CCR0006517
                        WHEN OTHERS
                        THEN
                            DoLog (
                                   'Error Found in Fetching Drop Ship Source id for DS ID :: '
                                || ln_drop_ship_source_id
                                || ' is :: '
                                || SQLERRM);
                            lv_msg   :=
                                'Unexpected Error in fetching SO Line';
                            RAISE ex_validation_rec;
                    -- End CCR0006517
                    END;

                    DoLog (ln_line_id);
                ELSE
                    --Intercompany
                    BEGIN
                        DoLog ('select for Interco - reserv');

                        --Check for reservation data
                        SELECT oola.line_id, oola.header_id, mr.reservation_id
                          INTO ln_line_id, ln_header_id, ln_reservation_id
                          FROM apps.mtl_reservations mr, oe_order_lines_all oola
                         WHERE     mr.supply_source_line_id =
                                   rec.po_line_location_id
                               AND mr.demand_source_line_id = oola.line_id
                               AND mr.supply_source_type_id = 1;

                        DoLog (ln_line_id);                               --PO
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            DoLog ('select for Interco - attr16');

                            --Check the attribute16 link
                            BEGIN
                                SELECT oola.line_id, oola.header_id, ooha.order_type_id
                                  INTO ln_line_id, ln_header_id, ln_order_type_id
                                  FROM oe_order_lines_all oola, oe_order_headers_all ooha
                                 WHERE     oola.attribute16 =
                                           TO_CHAR (rec.po_line_location_id)
                                       AND oola.header_id = ooha.header_id
                                       AND oola.shipped_quantity IS NULL -- CCR0006285 Added condition to pick Open SO Lines
                                       AND ooha.order_type_id = 1135; --Internal orders only

                                DoLog (ln_line_id);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    DoLog ('No SO link found');
                                    --No SO link found. assume a std PO to US
                                    ln_line_id               := NULL;
                                    ln_header_id             := NULL;
                                    ln_reservation_id        := NULL;
                                    ln_drop_ship_source_id   := NULL;
                                -- START CCR0006285
                                WHEN OTHERS
                                THEN
                                    DoLog (
                                           'Could not find SO Link :: '
                                        || SQLERRM);
                                    ln_line_id               := NULL;
                                    ln_header_id             := NULL;
                                    ln_reservation_id        := NULL;
                                    ln_drop_ship_source_id   := NULL;
                            -- END CCR0006285
                            END;
                        -- START CCR0006285
                        WHEN OTHERS
                        THEN
                            DoLog (
                                   'SO Line could not Fetched because :: '
                                || SQLERRM);
                            ln_line_id          := NULL;
                            ln_header_id        := NULL;
                            ln_reservation_id   := NULL;
                    -- END CCR0006285
                    END;
                END IF;

                --validate sales order data
                DoLog ('--Posting SO data');

                --post sales order data to stage record
                IF ln_line_id IS NOT NULL AND ln_header_id IS NOT NULL
                THEN
                    DoLog (
                           'Updating stg SO data Line ID '
                        || ln_line_id
                        || ' Header ID '
                        || ln_header_id
                        || ' Reserv ID '
                        || ln_reservation_id
                        || ' DSS ID '
                        || ln_drop_ship_source_id);

                    UPDATE xxdo.xxdo_gtn_po_collab_stg
                       SET oe_line_id = ln_line_id, oe_header_id = ln_header_id, reservation_id = ln_reservation_id,
                           drop_ship_source_id = ln_drop_ship_source_id
                     WHERE     gtn_po_collab_stg_id =
                               rec.gtn_po_collab_stg_id
                           AND oe_line_id IS NULL --Don't override existing order line data in stage table
                           AND oe_header_id IS NULL;
                END IF;

                COMMIT;                     --COMMIT each record after posting
            --Error handler within loop


            EXCEPTION
                WHEN ex_validation_rec
                THEN
                    DOLOG (lv_msg);                              -- CCR0006517
                    write_error_to_stg_rec (pn_batch_id => pn_batch_id, pn_stage_record => rec.gtn_po_collab_stg_id, pb_set_error_status => TRUE
                                            , pv_error_text => lv_msg);
            END;
        END LOOP;

        pv_error_stat   := 'S';
        --At the completion, any records failing validation will be marked with error
        DoLog ('populate_stage_data - Exit');
    EXCEPTION
        WHEN ex_validation_proc
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_msg;
            dolog (
                'populate_stage_data ex_validation_proc :: ' || pv_error_msg); -- CCR0006517
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Error when updating stg data : ' || SQLERRM;
            dolog ('populate_stage_data :: ' || pv_error_msg);   -- CCR0006517
            ROLLBACK;
    END;

    PROCEDURE pre_process_poc_stage (p_error_stat   OUT VARCHAR2,
                                     p_error_msg    OUT VARCHAR2)
    IS
        ---Get list of new records
        CURSOR c_stg IS
            SELECT *
              FROM XXD_PO_POC_SOA_INTF_STG_T
             WHERE process_status = 'IN PROCESS';

        CURSOR c_duplicate IS
              SELECT po_number, MAX (batch_id) last_batch_id
                FROM (SELECT DISTINCT po_number, batch_id
                        FROM XXD_PO_POC_SOA_INTF_STG_T
                       WHERE process_status = 'NEW')
            GROUP BY po_number
              HAVING COUNT (*) > 1;

        l_item_key     VARCHAR2 (20);
        l_split_flag   VARCHAR2 (10);
        l_cnt          NUMBER;
        l_batch_id     NUMBER;
    BEGIN
        DoLog ('pre_process_poc_stage - Start');

        -- Added for CCR0009182
        UPDATE XXD_PO_POC_SOA_INTF_STG_T stg
           SET process_status = 'NOT APPLICABLE', error_message = 'PO Shipment Canceled', request_id = fnd_global.conc_request_id
         WHERE     process_status = 'NEW'
               AND NVL (poc_line_status, 'None') = 'Confirmed'
               AND EXISTS
                       (SELECT '1'
                          FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla
                         WHERE     pha.segment1 = stg.po_number
                               AND pla.line_num = stg.line_number
                               AND NVL (plla.cancel_flag, 'N') = 'Y'
                               AND pha.po_header_id = pla.po_header_id
                               AND pla.po_line_id = plla.po_line_id)
               AND event_type_code = gn_event_supplier_site;

        -- End for CCR0009182

        --Check for duplicate runs for same PO and take latest batch. mark other batches as NOT APPLICABLE
        FOR rec IN c_duplicate
        LOOP
            UPDATE XXD_PO_POC_SOA_INTF_STG_T
               SET process_status   = 'NOT APPLICABLE'
             WHERE     po_number = rec.po_number
                   AND batch_id != rec.last_batch_id;
        END LOOP;

        --Set new records to IN Process
        UPDATE XXD_PO_POC_SOA_INTF_STG_T
           SET process_status = 'IN PROCESS', request_id = fnd_global.conc_request_id
         WHERE     process_status = 'NEW'
               AND NVL (poc_line_status, 'None') = 'Confirmed';

        --Set any nonconfirmed records to NOT APPLICABLE
        UPDATE XXD_PO_POC_SOA_INTF_STG_T
           SET process_status = 'NOT APPLICABLE', request_id = fnd_global.conc_request_id
         WHERE     process_status = 'NEW'
               AND NVL (poc_line_status, 'None') != 'Confirmed';


        COMMIT;

        --Find any records w/o a batch number
        SELECT COUNT (*)
          INTO l_cnt
          FROM XXD_PO_POC_SOA_INTF_STG_T
         WHERE     process_status = 'IN PROCESS'
               AND request_id = fnd_global.conc_request_id
               AND batch_id IS NULL;

        --If there are pending stg records w/o a batch number generate a new # for those records.
        IF l_cnt > 0
        THEN
            l_batch_id   := Get_Next_Batch_id;
        END IF;

        FOR stg_rec IN c_stg
        LOOP
            --Get first record and add to process stg table using current function
            IF stg_rec.split_qty_1 IS NOT NULL
            THEN
                l_split_flag   := 'true';
            ELSE
                l_split_flag   := 'false';
            END IF;

            l_batch_id   := NVL (stg_rec.batch_id, l_batch_id);

            --Set line key for function. Assume always shipment number 1 and distribution 1
            l_item_key   := stg_rec.line_number || '.1.1';

            IF stg_rec.event_type_code = gn_event_supplier_site
            THEN
                DoLog ('Update supplier site');
                --for this event we are only updating supplier site in the dff / NULL out other values
                XXDOPO_POC_UTILS_PUB.post_gtn_poc_to_stage (
                    pn_batch_id             => l_batch_id,
                    pv_po_number            => stg_rec.po_number,
                    pv_item_key             => l_item_key,
                    pv_split_flag           => 'false',
                    pv_shipmethod           => NULL,
                    pn_quantity             => NULL,       --stg_rec.quantity,
                    pv_cexfactory_date      => NULL,
                    pn_unit_price           => NULL,
                    pv_new_promised_date    => NULL,
                    pv_freight_pay_party    => NULL, --stg_rec.freight_pay_party,
                    pv_original_line_flag   => 'true',
                    pv_supplier_site_code   => stg_rec.supplier_site,
                    pv_delay_reason         => NULL,
                    pv_comments1            => stg_rec.comments1,
                    pv_comments2            => NULL,
                    pv_comments3            => NULL,
                    pv_comments4            => NULL,
                    pv_error_stat           => p_error_stat,
                    pv_error_msg            => p_error_msg);
                DoLog ('Error status : ' || p_error_stat);
                DoLog ('Error message : ' || p_error_msg);
            ELSE
                XXDOPO_POC_UTILS_PUB.post_gtn_poc_to_stage (
                    pn_batch_id             => l_batch_id,
                    pv_po_number            => stg_rec.po_number,
                    pv_item_key             => l_item_key,
                    pv_split_flag           => l_split_flag,
                    pv_shipmethod           => stg_rec.ship_method,
                    pn_quantity             => stg_rec.quantity,
                    pv_cexfactory_date      =>
                        TO_CHAR (stg_rec.Conf_xf_date, 'MM/DD/YYYY'),
                    pn_unit_price           => NULL,
                    pv_new_promised_date    =>
                        TO_CHAR (stg_rec.promised_date_override,
                                 'MM/DD/YYYY'),
                    pv_freight_pay_party    => stg_rec.freight_pay_party,
                    pv_original_line_flag   => 'true',
                    pv_supplier_site_code   => NULL,
                    pv_delay_reason         => stg_rec.delay_reason,
                    pv_comments1            => stg_rec.comments1,
                    pv_comments2            => NULL,
                    pv_comments3            => NULL,
                    pv_comments4            => NULL,
                    pv_error_stat           => p_error_stat,
                    pv_error_msg            => p_error_msg);

                --If there is a first split then add an additional record
                IF stg_rec.split_qty_1 IS NOT NULL
                THEN
                    XXDOPO_POC_UTILS_PUB.post_gtn_poc_to_stage (
                        pn_batch_id             => l_batch_id,
                        pv_po_number            => stg_rec.po_number,
                        pv_item_key             => l_item_key,
                        pv_split_flag           => l_split_flag,
                        pv_shipmethod           => stg_rec.split_ship_method_1,
                        pn_quantity             => stg_rec.split_qty_1,
                        pv_cexfactory_date      =>
                            TO_CHAR (stg_rec.split_date_1, 'MM/DD/YYYY'),
                        pn_unit_price           => NULL,
                        pv_new_promised_date    => NULL, --TO_CHAR (stg_rec.split_date_1,
                        --      'MM/DD/YYYY'),
                        pv_freight_pay_party    =>
                            stg_rec.split_frt_pay_party_1,
                        pv_original_line_flag   => 'false', --'true', Modified for CCR0009182
                        pv_supplier_site_code   => NULL,
                        pv_delay_reason         => stg_rec.delay_reason,
                        pv_comments1            => stg_rec.comments1,
                        pv_comments2            => NULL,
                        pv_comments3            => NULL,
                        pv_comments4            => NULL,
                        pv_error_stat           => p_error_stat,
                        pv_error_msg            => p_error_msg);

                    IF stg_rec.split_qty_2 IS NOT NULL
                    THEN
                        XXDOPO_POC_UTILS_PUB.post_gtn_poc_to_stage (
                            pn_batch_id             => l_batch_id,
                            pv_po_number            => stg_rec.po_number,
                            pv_item_key             => l_item_key,
                            pv_split_flag           => l_split_flag,
                            pv_shipmethod           => stg_rec.split_ship_method_2,
                            pn_quantity             => stg_rec.split_qty_2,
                            pv_cexfactory_date      =>
                                TO_CHAR (stg_rec.split_date_2, 'MM/DD/YYYY'),
                            pn_unit_price           => NULL,
                            pv_new_promised_date    => NULL, --TO_CHAR (stg_rec.split_date_2,
                            --   'MM/DD/YYYY'),
                            pv_freight_pay_party    =>
                                stg_rec.split_frt_pay_party_2,
                            pv_original_line_flag   => 'false', --'true', Modified for CCR0009182
                            pv_supplier_site_code   => NULL,
                            pv_delay_reason         => stg_rec.delay_reason,
                            pv_comments1            => stg_rec.comments1,
                            pv_comments2            => NULL,
                            pv_comments3            => NULL,
                            pv_comments4            => NULL,
                            pv_error_stat           => p_error_stat,
                            pv_error_msg            => p_error_msg);
                    END IF;
                END IF;
            END IF;
        END LOOP;

        --Set SOA stg table records to processed
        UPDATE XXD_PO_POC_SOA_INTF_STG_T
           SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
         WHERE     process_status = 'IN PROCESS'
               AND request_id = fnd_global.conc_request_id;

        COMMIT;
        p_error_stat   := 'S';
        p_error_msg    := NULL;
        DoLog ('pre_process_poc_stage - End');
    EXCEPTION
        WHEN OTHERS
        THEN
            DoLog ('pre_process_poc_stage - Error  ' || SQLERRM);
            p_error_stat   := 'E';
            p_error_msg    := SQLERRM;

            ROLLBACK;

            --Flag records as error
            UPDATE XXD_PO_POC_SOA_INTF_STG_T
               SET process_status = 'ERROR', error_message = SUBSTR (p_error_msg, 1, 2000), last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE     process_status = 'IN PROCESS'
                   AND request_id = fnd_global.conc_request_id;

            COMMIT;
    END;


    --Begin CCR0008134
    PROCEDURE execute_soa_poa_call (pv_po_number IN VARCHAR2, pn_no_retries IN NUMBER:= 3, pv_result_stat OUT VARCHAR2
                                    , pv_result_msg OUT VARCHAR2)
    IS
        l_string_request     VARCHAR2 (2000);
        l_string_url         VARCHAR2 (2000);
        l_response_msg       VARCHAR2 (2000);
        l_status_code        NUMBER;
        nCnt                 NUMBER := 1;

        lv_db_name           VARCHAR2 (30);
        lv_server_name       VARCHAR2 (1000);
        lv_soa_service       VARCHAR2 (1000);
        lv_wallet_path       VARCHAR2 (1000);
        lv_wallet_password   VARCHAR2 (1000);


        l_http_request       UTL_HTTP.req;
        l_http_response      UTL_HTTP.resp;
        lp_http_response     UTL_HTTP.resp;
    BEGIN
        SELECT name INTO lv_db_name FROM v$database;

        DoLog ('Execute SOA call PO # : ' || pv_po_number);
        DoLog ('Database : ' || lv_db_name);

        BEGIN
            --Get lookup for server based on instance
            SELECT DISTINCT attribute1, attribute2, attribute3
              INTO lv_server_name, lv_wallet_path, lv_wallet_password
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_EBS_SOA_SERVER'
                   AND language = 'US'
                   AND lookup_code = lv_db_name;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_result_stat   := 'E';
                pv_result_msg    :=
                       'Error loading SOA server name for instance : '
                    || lv_db_name
                    || ' Error : '
                    || SQLERRM;
                DoLog (
                       'Error loading SOA server name for instance : '
                    || lv_db_name
                    || ' Error : '
                    || SQLERRM);
                RETURN;
        END;


        --Get lookup for PO POA service
        BEGIN
            SELECT DISTINCT description
              INTO lv_soa_service
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PO_SOA_SERVICES'
                   AND language = 'US'
                   AND lookup_code = 'POA_SEND';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_result_stat   := 'E';
                pv_result_msg    :=
                       'Error loading SOA POA_SEND service name :  Error : '
                    || SQLERRM;
                DoLog (
                       'Error loading SOA POA_SEND service name :  Error : '
                    || SQLERRM);
                RETURN;
        END;

        --Build full URL
        l_string_url       := lv_server_name || '/' || lv_soa_service;
        doLog ('URL : ' || l_string_url);

        --Build request string
        l_string_request   :=
               '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">'
            || '<soap:Body>'
            || '<ns1:process xmlns:ns1="http://xmlns.oracle.com/DECKERS/PurchaseOrderEBSReqABCS/PurchaseOrderEBSReqABCSProvImpl">'
            || ' <ns1:PONumber>'
            || pv_po_number
            || '</ns1:PONumber>'
            || '</ns1:process>'
            || '</soap:Body>'
            || '</soap:Envelope>';

       <<retry>>
        IF lv_wallet_path IS NOT NULL AND lv_wallet_password IS NOT NULL
        THEN
            UTL_HTTP.set_wallet (lv_wallet_path, lv_wallet_password);
        END IF;

        l_http_request     :=
            UTL_HTTP.begin_request (url            => l_string_url,
                                    method         => 'POST',
                                    http_version   => 'HTTP/1.1');
        --Keeping the connection persistent
        UTL_HTTP.set_persistent_conn_support (l_http_request, TRUE); -- Addwd by Santosh on 30Apr2016
        -- Set header information --
        UTL_HTTP.set_header (l_http_request,
                             'User-Agent',
                             'Mozilla/4.0 (compatible)');
        UTL_HTTP.set_header (l_http_request, 'Transfer-Encoding', 'chunked');
        UTL_HTTP.set_header (l_http_request,
                             'Content-Type',
                             'text/xml; charset=utf-8');
        UTL_HTTP.set_header (l_http_request,
                             'Content-Length',
                             LENGTH (l_string_request));
        UTL_HTTP.set_header (l_http_request, 'SOAPAction', '');


        UTL_HTTP.write_text (l_http_request, l_string_request);

        l_http_response    := UTL_HTTP.get_response (l_http_request);
        --   UTL_HTTP.read_text (l_http_response, l_response_msg);

        l_response_msg     := l_http_response.reason_phrase;
        l_status_code      := l_http_response.status_code;

        UTL_HTTP.end_response (l_http_response);
        DoLog ('Response : ' || l_status_code);

        --Check for success (202 is success)
        IF l_status_code <> 202
        THEN
            IF nCnt >= pn_no_retries
            THEN
                pv_result_msg    := l_response_msg;
                pv_result_stat   := 'E';
                RETURN;
            ELSE
                nCnt   := nCnt + 1;
                DBMS_LOCK.sleep (10);
                GOTO retry;
            END IF;
        END IF;

        DoLog ('Execute SOA call - Exit');
        pv_result_stat     := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            dolog ('Unexpected error posting POA to SOA : ' || SQLERRM);
            pv_result_msg    := SQLERRM;
            pv_result_stat   := 'E';
    END;

    PROCEDURE send_poa_to_soa (pn_batch_id IN NUMBER)
    IS
        CURSOR c_rec IS
            SELECT DISTINCT po_number
              FROM xxdo.xxdo_gtn_po_collab_stg
             WHERE batch_id = pn_batch_id;

        lv_result_stat   VARCHAR2 (1);
        lv_result_msg    VARCHAR2 (2000) := NULL;
        lv_po_list       VARCHAR2 (2000) := NULL;
    BEGIN
        DoLog ('Send POA to SOA for batch : ' || pn_batch_id);

        FOR rec IN c_rec
        LOOP
            execute_soa_poa_call (pv_po_number     => rec.po_number,
                                  pv_result_stat   => lv_result_stat,
                                  pv_result_msg    => lv_result_msg);

            IF lv_result_stat != 'S'
            THEN
                lv_po_list   := lv_po_list || ' ' || rec.po_number;
            END IF;
        END LOOP;

        IF lv_po_list IS NOT NULL
        THEN
            UPDATE XXD_PO_POC_SOA_INTF_STG_T
               SET process_status = 'E', error_message = 'POC Successful but POA failed for the following POs :' || lv_po_list
             WHERE batch_id = pn_batch_id;
        END IF;
    END;

    PROCEDURE log_errors_to_soa_stg (pn_batch_id IN NUMBER)
    IS
        CURSOR c_recs IS
              --Get all lines errors that are unique and post contactinated list to the SOA table as this is a many to one.
              SELECT batch_id, po_number, line_num,
                     LISTAGG (error_message, ';') WITHIN GROUP (ORDER BY 1) stg_error_msg
                FROM (SELECT DISTINCT batch_id, po_line_key, po_number,
                                      line_num, error_message
                        FROM xxdo.xxdo_gtn_po_collab_stg stg
                       WHERE     stg.processing_status_code = 'ERROR'
                             AND batch_id = pn_batch_id)
            GROUP BY batch_id, po_number, line_num;
    BEGIN
        DoLog ('Log errors to SOA stage table');

        FOR rec IN c_recs
        LOOP
            UPDATE XXDO.XXD_PO_POC_SOA_INTF_STG_T
               SET error_message = SUBSTR (rec.stg_error_msg, 1, 2000), process_status = 'ERROR'
             WHERE     batch_id = rec.batch_id
                   AND po_number = rec.po_number
                   AND line_number = rec.line_num;

            DoLog (
                   'Batch ID : '
                || rec.batch_id
                || ' PO Number : '
                || rec.po_number
                || ' Line Number : '
                || rec.line_num
                || ' Error : '
                || rec.stg_error_msg);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        --Failure here only means lack of logging so just report it.
        THEN
            DoLog (
                   'Failed to propegate process errors to SOA Table.  : '
                || SQLERRM);
    END;

    --End CCR0008134

    PROCEDURE po_process_by_batch (pn_batch_id IN NUMBER, pn_request_id IN NUMBER, pv_error_stat OUT VARCHAR2
                                   , pv_err_msg OUT VARCHAR2)
    IS
        n_cnt         NUMBER;
        ln_ret_code   NUMBER;

        CURSOR c_po_list IS
            SELECT po_header_id, segment1 po_number, authorization_status
              FROM po_headers_all pha
             WHERE EXISTS
                       (SELECT NULL
                          FROM xxdo.xxdo_gtn_po_collab_stg stg
                         WHERE     (stg.po_header_id = pha.po_header_id OR stg.from_po_header_id = pha.po_header_id)
                               AND stg.batch_id = pn_batch_id
                               AND stg.processing_status_code = 'RUNNING');


        CURSOR c_jp_po_list (p_po_header_id NUMBER)
        IS
            SELECT DISTINCT pha.po_header_id, pha.segment1 po_number, plla.ship_to_organization_id
              FROM Po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                   oe_order_lines_all oola, oe_drop_ship_sources dss
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND pla.attribute5 = TO_CHAR (oola.line_id)
                   AND oola.line_id = dss.line_id
                   AND dss.po_header_id = p_po_header_id;
    BEGIN
        DoLog ('po_process_by_batch - Enter');

        SELECT COUNT (*)
          INTO n_cnt
          FROM po_headers_all pha
         WHERE EXISTS
                   (SELECT NULL
                      FROM xxdo.xxdo_gtn_po_collab_stg stg
                     WHERE     (stg.po_header_id = pha.po_header_id OR stg.from_po_header_id = pha.po_header_id)
                           AND stg.batch_id = pn_batch_id
                           AND stg.request_id = pn_request_id
                           AND stg.processing_status_code = 'RUNNING');

        doLog (
               'PO Count for batch ID : '
            || pn_batch_id
            || ' Request ID : '
            || pn_request_id
            || ' :  '
            || n_cnt);



        FOR po_rec IN c_po_list
        LOOP
            DoLog (
                   'Processing PO : '
                || po_rec.po_number
                || ' authorization status : '
                || po_rec.authorization_status);

            --if PO is not approved run process to approve PO
            IF po_rec.authorization_status != 'APPROVED'
            THEN
                approve_po (pv_po_number => po_rec.po_number, pn_user_id => fnd_global.user_id, pv_error_stat => pv_error_stat
                            , pv_error_msg => pv_err_msg);
            END IF;

            DoLog ('approve_po : ' || pv_error_stat);

            IF pv_error_stat != 'S'
            THEN
                NULL;
            END IF;


            DoLog ('Update reservations ');
            --If the PO has any reservations tied to SO#s update reservation quantitiy to match SO qty
            update_reservations_for_po (
                pn_po_header_id   => po_rec.po_header_id,
                pv_error_stat     => pv_error_stat,
                pv_error_msg      => pv_err_msg);

            DoLog ('Update reservations result ' || pv_error_stat);

            IF pv_error_stat != 'S'
            THEN
                NULL;
            END IF;
        END LOOP;

        DoLog ('Send POA to SOA');
        --Do SOA calls for batch
        send_poa_to_soa (pn_batch_id);

        pv_error_stat   := 'S';
        DoLog ('po_process_by_batch - Exit');
    EXCEPTION
        --Global procedure exception
        WHEN OTHERS
        THEN
            DoLog ('po_process_by_batch - Error');
            pv_error_stat   := 'E';
            pv_err_msg      := SQLERRM;
    END;


    PROCEDURE run_poc_batch (pn_batch_id     IN     NUMBER,
                             pv_reprocess    IN     VARCHAR2 := 'No',
                             pv_error_stat      OUT VARCHAR2,
                             pv_err_msg         OUT VARCHAR2,
                             pn_request_id   IN     NUMBER)
    IS
        ln_po_distribution_id     NUMBER;
        ln_batch_id               NUMBER;
        ln_recs                   NUMBER;
        ln_ttl_cnt                NUMBER;
        ln_curr_qty               NUMBER;
        ln_user_id                NUMBER := 1876;    --(BATCH.P2P)  Rev2:1766;
        lv_error_stat             VARCHAR2 (1);
        lv_error_msg              VARCHAR2 (4000) := NULL;
        ln_new_line_num           NUMBER;
        ln_new_shipment_num       NUMBER;
        ln_hold_count             NUMBER;
        ln_new_line_ID            NUMBER;
        lb_first_record           BOOLEAN;
        ln_po_src_type            NUMBER;
        lv_req_type               VARCHAR2 (10);

        ln_request_id             NUMBER;

        lb_split_flag             BOOLEAN;
        lv_ret_val                VARCHAR2 (1);

        old_req_line_id           NUMBER;
        old_req_header_id         NUMBER;
        old_req_cancel_flag       VARCHAR2 (1);
        po_cancel_flag            VARCHAR2 (1);

        lv_flow_status_code       VARCHAR2 (20);
        lv_open_flag              VARCHAR2 (1);

        n_cancelled_qty           NUMBER;
        ln_so_quantity            NUMBER;
        ln_net_po_qty             NUMBER;

        lb_qty_update             BOOLEAN;
        ln_oimp_hold_request_id   NUMBER;                        -- CCR0006517
        ln_acrq_hold_request_id   NUMBER;                        -- CCR0006517
        ln_quantity_billed        NUMBER;                        -- CCR0007262
        lv_cancel_flag            VARCHAR2 (10) := 'N';          -- CCR0007262
        lv_closed_code            VARCHAR2 (100);                -- CCR0007262

        ln_jp_po_line_num         NUMBER;
        ln_jp_po_line_ID          NUMBER;
        lv_jp_po_number           VARCHAR2 (30);

        --Outer group:
        --A group will be all staging table records that affect a specific po line/shipment for the batch
        CURSOR c_grp IS
              SELECT stg.batch_id, stg.po_header_id, stg.po_line_id,
                     stg.po_line_location_id, stg.po_distribution_id, stg.cancel_line,
                     stg.po_line_key, COUNT (*) n_recs, plla.quantity po_shipment_qty,
                     plla.quantity_received po_shipment_rcv, plla.promised_date, NVL (SUM (stg.quantity), plla.quantity) ttl_qty,
                     pha.vendor_id, pha.vendor_site_id, plla.approved_flag,
                     pha.segment1 po_number, pla.line_num, pla.quantity line_quantity,
                     pla.cancel_flag, stg.supplier_site_code
                FROM xxdo.xxdo_gtn_po_collab_stg stg, po_line_locations_all plla, po_lines_all pla,
                     po_headers_all pha
               WHERE     batch_id = pn_batch_id
                     AND pha.po_header_id = pla.po_header_id
                     AND stg.processing_status_code = 'RUNNING'
                     AND stg.po_line_location_id = plla.line_location_id
                     AND plla.po_header_id = pha.po_header_id
                     AND pla.po_line_id = plla.po_line_id
            --  AND pha.segment1 = NVL (pv_po_number, pha.segment1) --Rev3 Support of specific PO to process
            GROUP BY stg.batch_id, stg.po_header_id, stg.po_line_id,
                     stg.cancel_line, stg.po_line_key, stg.po_line_location_id,
                     stg.po_distribution_id, plla.quantity, plla.quantity_received,
                     plla.promised_date, pha.vendor_id, pha.vendor_site_id,
                     plla.approved_flag, pha.segment1, pla.line_num,
                     pla.quantity, pla.cancel_flag, stg.supplier_site_code;

        --Cursor for all rows in the curent grouping
        --Order each group by an ascending order by CXFDate so that the earilest date will be set to the orig PO line
        /*      CURSOR c_proc
              IS
                   SELECT stg.*
                     FROM xxdo.xxdo_gtn_po_collab_stg stg, FND_FLEX_VALUES fv
                    WHERE     po_distribution_id = ln_po_distribution_id
                          AND fv.flex_value_set_id = 1015991  --Shipmenthod lookup set
                          AND stg.ship_method = fv.flex_value
                          AND stg.po_number = NVL (pv_po_number, stg.po_number) --Rev3 Support of specific PO to process
                          AND batch_id = pn_batch_id
                 ORDER BY ex_factory_date ASC,
                          NVL (TO_NUMBER (fv.attribute1), -1) ASC; --Using Attribute1 as a ranking to order priority of ship methods*/


        --TODO: re order so that the inbound sequence is preserved (orig po then split 1 then split 2)
        CURSOR c_proc IS
              SELECT stg.*
                FROM xxdo.xxdo_gtn_po_collab_stg stg
               WHERE     po_distribution_id = ln_po_distribution_id --  AND stg.po_number = NVL (pv_po_number, stg.po_number) --Rev3 Support of specific PO to process
                     AND batch_id = pn_batch_id
            ORDER BY gtn_po_collab_stg_id;


        /*old SQL
                   SELECT stg.*
             FROM xxdo.xxdo_gtn_po_collab_stg stg
            WHERE     po_distribution_id = ln_po_distribution_id
                  AND batch_id = pn_batch_id
         ORDER BY ex_factory_date ASC;*/


        --ASC sort by exf date so that new generated PO lines will have the later xfdate

        --Cursor for SO lines from the proces
        CURSOR c_orders IS
            SELECT DISTINCT stg.src_po_type_id, stg.oe_header_id, ooha.created_by,
                            ooha.order_number, ooha.org_id
              FROM xxdo.xxdo_gtn_po_collab_stg stg, oe_order_headers_all ooha
             WHERE     stg.oe_header_id IS NOT NULL
                   AND stg.create_req = 'Y'
                   AND stg.req_created = 'N'
                   AND stg.processing_status_code = 'RUNNING'
                   AND stg.batch_id = pn_batch_id
                   --     AND STG.PO_NUMBER = NVL (pv_po_number, stg.po_number) --Rev3 Support of specific PO to process
                   AND stg.oe_header_id = ooha.header_id;


        ln_cnt                    NUMBER;

        ex_validation             EXCEPTION;
        ex_login                  EXCEPTION;
        ex_update                 EXCEPTION;
    BEGIN
        DoLog ('** run_poc_batch - Enter ');
        DoLog ('     Batch Number : ' || pn_batch_id);
        --   dolog ('      PO Number : ' || pv_po_number);
        dolog ('      Reprocess : ' || pv_reprocess);

        IF pv_reprocess = 'Yes'
        THEN
            --Rev3 : If reproces flag set then reset records in this batch
            UPDATE xxdo.xxdo_gtn_po_collab_stg
               SET processing_status_code = 'PENDING', error_message = NULL, request_id = pn_request_id -- CCR0006035
             WHERE     batch_id = pn_batch_id --   AND po_number = NVL (pv_po_number, po_number) --Rev3 Support of specific PO to process
                   AND NVL (processing_status_code, 'PENDING') = 'ERROR';

            COMMIT;
        END IF;

        --Set the status of any pending records for the batch
        UPDATE xxdo.xxdo_gtn_po_collab_stg
           SET processing_status_code = 'RUNNING', request_id = pn_request_id -- CCR0006035
         WHERE     batch_id = pn_batch_id --      AND po_number = NVL (pv_po_number, po_number) --Rev3 Support of specific PO to process
               AND NVL (processing_status_code, 'PENDING') = 'PENDING';

        --commit these changes
        COMMIT;

        -- START CCR0007262
        ln_user_id                := NULL;

        BEGIN
            SELECT user_id
              INTO ln_user_id
              FROM fnd_user
             WHERE user_name = FND_PROFILE.VALUE ('XXD_POC_USER');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_user_id   := NULL;
                DoLog (
                       'Error in Fetching User Name from Profile Option :: '
                    || SQLERRM);
        END;

        -- END CCR0007262

        --Rev2
        --set current user
        --Will retrieve current user if run as concurrent request
        --Commented CCR0007262
        /*SELECT DECODE (NVL (apps.fnd_global.user_id (), ln_user_id),
                          -1, ln_user_id,
                          apps.fnd_global.user_id ())
             INTO ln_user_id
             FROM DUAL;*/



        DoLog ('Active user ID : ' || ln_user_id);

        DoLog ('** run_poc_batch - Populate stage data');

        --populate stage data
        populate_stage_data (pn_batch_id, lv_error_stat, lv_error_msg);

        DoLog (
               '** run_poc_batch - Populate stage data. Return :'
            || lv_error_stat);

        --commit before continuing
        COMMIT;
        DoLog ('** run_poc_batch - before outer group');

        --First traverse the lloc/dist groupings
        --For this round we will update/cancel any PO lines and linked REQ lines.
        --Any new PO lines needed we will mark the staging table records so the REQ lines will be generated at the same time in the secound round
        FOR group_rec IN c_grp
        LOOP
            DoLog ('** run_poc_batch - outer loop');

            --Rev1
            --Set savepoint so changes in this step can be rolled back
            BEGIN
                SAVEPOINT POLineProcess;


                --Check if any records in the group were marked as error during posting to staging table. If so , whole group fails.
                -- Commented Start CCR0006517
                /*SELECT COUNT (*)
                           INTO ln_cnt
                           FROM xxdo.xxdo_gtn_po_collab_stg stg
                          WHERE     po_line_location_id = group_rec.po_line_location_id
                                AND processing_status_code = 'ERROR';*/
                -- End CCR0006517

                ln_cnt   := 0;                                   -- CCR0006517

                DoLog ('** ln_cnt :: ' || ln_cnt);


                IF ln_cnt = 0
                THEN
                    IF group_rec.ttl_qty != group_rec.po_shipment_qty
                    THEN --passsed quantity from POC not matching current po shipment qty
                        --This would be a PO inc or a PO reduction
                        IF ln_recs = 1
                        THEN
                            --this is a straight qty change and no split needed
                            lb_split_flag   := FALSE;
                        ELSE
                            --multiple records and therefore a line split is needed, there is also a net qty change here
                            lb_split_flag   := TRUE;
                        END IF;
                    ELSE
                        IF     group_rec.ttl_qty = group_rec.po_shipment_qty
                           AND ln_recs = 1
                        THEN
                            NULL;
                        END IF;
                    END IF;

                    --Initialize qty for loop below. Will decrement as we assign qty to one or more lines
                    ln_curr_qty             := group_rec.ttl_qty;
                    ln_po_distribution_id   := group_rec.po_distribution_id;

                    --set src po type value (constants in spec)
                    ln_po_src_type          :=
                        get_po_type (group_rec.po_number);

                    --set flag for first record
                    lb_first_record         := TRUE;
                    DoLog ('     HEADER ID   : ' || group_rec.po_header_id);
                    DoLog ('     LINE_ID     : ' || group_rec.po_line_id);
                    DoLog (
                        '     LLOC_ID     : ' || group_rec.po_line_location_id);
                    DoLog ('     DIST_ID     : ' || ln_po_distribution_id);
                    DoLog ('     PO_LINE_KEY : ' || group_rec.po_line_key);

                    DoLog (
                        '** before record loop - batch_id = ' || pn_batch_id);

                    FOR rec IN c_proc
                    LOOP
                        DoLog ('     Record loop start');

                        DoLog ('     PO src type : ' || ln_po_src_type);

                        DoLog (
                               '     STG_REC_ID: '
                            || rec.gtn_po_collab_stg_id
                            || ' cancel_flag '
                            || rec.cancel_line
                            || ' user ID : '
                            || ln_user_id
                            || ' OE Header ID '
                            || rec.oe_header_id
                            || ' OE Line ID '
                            || rec.oe_line_id);

                        DoLog (
                               'Stage record quantity : '
                            || rec.quantity
                            || ' - PO Shipment_quantity : '
                            || group_rec.po_shipment_qty
                            || ' - PO shipment received : '
                            || group_rec.po_shipment_rcv);

                        DoLog (
                               'Processing flags - Create_Req : '
                            || rec.create_req
                            || ' Req created : '
                            || rec.req_created
                            || ' Req Type : '
                            || rec.req_type);


                        --Process for first record in each group (each po shipment line)
                        IF lb_first_record
                        THEN
                            DoLog ('>>>     First Record = TRUE');

                            lb_qty_update     :=
                                (rec.quantity - group_rec.po_shipment_qty) !=
                                0;

                            --Rev3 if this part failed in initial run, reprocess should be pass through as no updates would be detected.
                            IF lb_qty_update
                            THEN
                                dolog ('Qty change');

                                ln_net_po_qty   :=
                                      group_rec.po_shipment_qty
                                    - group_rec.po_shipment_rcv;

                                --For first record we will cancel (if flag is set) then generate a new line . If we are not cancelling then we just update the current record
                                IF rec.cancel_line = 'Y'
                                THEN
                                    DoLog (
                                           '** before cancel line. PO Number: '
                                        || rec.po_number
                                        || ' Line Num: '
                                        || rec.line_num);

                                    --IF NVL (rec.cancel_line, 'N') = 'N'  CCR0006285
                                    IF NVL (rec.cancel_line, 'N') = 'Y' -- CCR0006285
                                    THEN
                                        cancel_po_line (
                                            pv_po_number    => rec.po_number,
                                            pn_line_num     => rec.line_num,
                                            pn_user_id      => ln_user_id,
                                            pv_error_stat   => lv_error_stat,
                                            pv_error_msg    => lv_error_msg);

                                        DoLog (
                                               '** after cancel po line. Return :'
                                            || lv_error_stat
                                            || ' :: '
                                            || ' with Message :: '
                                            || lv_error_msg);    -- CCR0006517
                                    ELSE
                                        DoLog (
                                            'PO Line is already cancelled');
                                    END IF; --If the line was already cancelled the we will just continue.

                                    IF lv_error_stat != 'S'
                                    THEN
                                        --For Std POs. Note error but continue as this will not prevent downstream action.
                                        --For Interco/drop ship, this prevents further action on this PO line (raise error for this group)
                                        IF ln_po_src_type = G_PO_TYPE_INTERCO
                                        THEN
                                            lv_error_msg   :=
                                                   'Cancel PO line failed :'
                                                || lv_error_msg;
                                            DOLOG (lv_error_msg); -- CCR0006517
                                            RAISE ex_update;
                                        ELSE
                                            DoLog (
                                                   '     Error when cancelling PO line. PO Number : '
                                                || rec.po_number
                                                || ' Line Number '
                                                || group_rec.line_num
                                                || ' Note: This PO line will need to be cancelled manually'); --TODO: How do we notify on warning type messages
                                        END IF;
                                    END IF;


                                    --Check if sourcing REQ line needs to be canccelled
                                    BEGIN
                                        DoLog ('  check req line to cancel');

                                        SELECT prla.requisition_line_id,
                                               prla.requisition_header_id,
                                               prla.cancel_flag,
                                               CASE
                                                   WHEN plla.line_location_id
                                                            IS NOT NULL
                                                   THEN
                                                       NVL (plla.cancel_flag,
                                                            'N')
                                                   ELSE
                                                       NVL (plla.cancel_flag,
                                                            'Y')
                                               END
                                          INTO old_req_line_id, old_req_header_id, old_req_cancel_flag, po_cancel_flag
                                          FROM apps.po_requisition_lines_all prla, apps.po_line_locations_all plla
                                         WHERE     prla.line_location_id =
                                                   rec.po_line_location_id
                                               AND prla.line_location_id =
                                                   plla.line_location_id(+);

                                        DoLog (
                                               '  REQ Line ID found : '
                                            || old_req_line_id
                                            || ' REQ line cancel flag : '
                                            || old_req_cancel_flag
                                            || ' PO Cancel Flag : '
                                            || po_cancel_flag);

                                        --REQ line exists for this PO line and is not cancelled. Cancel this REQ line

                                        --Also check if REQ line was already cancelled
                                        IF     (NVL (old_req_cancel_flag, 'N') = 'N' AND NVL (po_cancel_flag, 'N') = 'Y')
                                           AND (NVL (old_req_cancel_flag, 'N') = 'N')
                                        THEN
                                            lv_ret_val   :=
                                                cancel_requisition_line (
                                                    pn_requisition_header_id   =>
                                                        old_req_line_id,
                                                    pn_requisition_line_id   =>
                                                        old_req_header_id);
                                            DoLog (
                                                   '** After cancel requisition line: '
                                                || lv_ret_val);
                                        END IF;
                                    --Failure of this cancel is not fatal. It should be noted but processing can continue
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            DoLog (
                                                '  no req found to cancel');
                                            --No req line linked. Just continue
                                            NULL;
                                    END;

                                    DoLog (
                                           '** Before cancel order line. Line ID '
                                        || rec.oe_line_id);

                                    --For intercompany PO, the internal sales order line needs to be cancelled
                                    IF ln_po_src_type = G_PO_TYPE_INTERCO
                                    THEN
                                        lv_req_type   := 'INTERNAL';

                                        --get user ID for SO line to cancel
                                        SELECT --created_by,  -- Commented CCR0007262
                                               flow_status_code, open_flag
                                          INTO --ln_user_id,  -- Commented CCR0007262
                                               lv_flow_status_code, lv_open_flag
                                          FROM oe_order_lines_all
                                         WHERE line_id = rec.oe_line_id;

                                        DoLog (
                                               'Line ID : '
                                            || rec.oe_line_id
                                            || 'Flow Status Code : '
                                            || lv_flow_status_code
                                            || ' open flag : '
                                            || lv_open_flag);

                                        IF (lv_flow_status_code != 'CANCELLED' AND lv_open_flag = 'Y')
                                        THEN
                                            --Cancel ISO line
                                            cancel_so_line (
                                                pn_line_id     => rec.oe_line_id,
                                                pn_user_id     => ln_user_id,
                                                pv_reason_code   =>
                                                    gn_cancel_reason_code,
                                                pv_error_stat   =>
                                                    lv_error_stat,
                                                pv_error_msg   => lv_error_msg);

                                            IF lv_error_stat <> 'S'
                                            THEN
                                                --This could just be a warning because it is not fatal that the SO line was not cancelled
                                                NULL;
                                            END IF;


                                            DoLog (
                                                   '** After cancel order line. Return : '
                                                || pv_error_stat);
                                        END IF;

                                        --Set from values in stg table
                                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                           SET from_oe_header_id = oe_header_id, from_oe_line_id = oe_line_id
                                         WHERE gtn_po_collab_stg_id =
                                               rec.gtn_po_collab_stg_id;
                                    ELSE
                                        lv_req_type   := 'EXTERNAL';

                                        -- Start CCR0006285
                                        --get user ID for SO line to cancel
                                        -- Added Begin Block CCR0006517
                                        BEGIN
                                            SELECT --created_by,   -- Commented CCR0007262
                                                   flow_status_code, open_flag
                                              INTO --ln_user_id,   -- Commented CCR0007262
                                                   lv_flow_status_code, lv_open_flag
                                              FROM oe_order_lines_all
                                             WHERE line_id = rec.oe_line_id;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                lv_open_flag          := NULL;
                                                lv_flow_status_code   := NULL;
                                                DOLOG (
                                                       'There is no SO Mapping for PO Line :: '
                                                    || group_rec.po_line_id);
                                            WHEN OTHERS
                                            THEN
                                                lv_open_flag          := NULL;
                                                lv_flow_status_code   := NULL;
                                                DOLOG (
                                                       'Unexpected error in finding SO Mapping for PO Line :: '
                                                    || group_rec.po_line_id
                                                    || ' :: '
                                                    || SQLERRM);
                                        END;

                                        DoLog (
                                               'Line ID : '
                                            || rec.oe_line_id
                                            || 'Flow Status Code : '
                                            || lv_flow_status_code
                                            || ' open flag : '
                                            || lv_open_flag);

                                        IF (lv_flow_status_code != 'CANCELLED' AND lv_open_flag = 'Y')
                                        THEN
                                            --Cancel Dropship SO line
                                            cancel_so_line (
                                                pn_line_id     => rec.oe_line_id,
                                                pn_user_id     => ln_user_id,
                                                pv_reason_code   =>
                                                    gn_cancel_reason_code,
                                                pv_error_stat   =>
                                                    lv_error_stat,
                                                pv_error_msg   => lv_error_msg);

                                            IF lv_error_stat <> 'S'
                                            THEN
                                                --This could just be a warning because it is not fatal that the SO line was not cancelled
                                                NULL;
                                            END IF;


                                            DoLog (
                                                   '** After cancel SO order line. Return : '
                                                || pv_error_stat
                                                || ' :: with message :: '
                                                || lv_error_msg); -- CCR0006517
                                        END IF;

                                        --Set from values in stg table
                                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                           SET from_oe_header_id = oe_header_id, from_oe_line_id = oe_line_id
                                         WHERE gtn_po_collab_stg_id =
                                               rec.gtn_po_collab_stg_id;
                                    -- End CCR0006285
                                    END IF;

                                    DoLog ('Update stg data');

                                    --Mark stg record as REQ line needed
                                    --If the record is already in this state then do not update
                                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                       SET create_req = 'Y', req_type = lv_req_type, req_created = 'N',
                                           vendor_id = group_rec.vendor_id, vendor_site_id = group_rec.vendor_site_id
                                     WHERE     gtn_po_collab_stg_id =
                                               rec.gtn_po_collab_stg_id
                                           AND req_created = 'N'
                                           AND NVL (req_type, lv_req_type) =
                                               lv_req_type;
                                ELSE
                                    DoLog (
                                           '** before pre-update po_line - approved_flag = '
                                        || group_rec.approved_flag
                                        || ' PO Src Type : '
                                        || ln_po_src_type);

                                    --Rev1
                                    --Check if the remaining balance (partially received PO line) cancelled
                                    IF rec.quantity =
                                       group_rec.po_shipment_rcv
                                    THEN
                                        --cancel PO line as we are setting the shipment qty to the rcv quantity nullifying out any remaining open balance
                                        DoLog (
                                            'New qty = rcv qty : close po line');


                                        --Update the current line (only needed for Drop Ship SOs to allow update of the SO
                                        IF (ln_po_src_type = G_PO_TYPE_DS OR ln_po_src_type = G_PO_TYPE_JPTQ)
                                        THEN
                                            DoLog ('DS - Set to appr-req');

                                            --Before updating the SO lIne we are updating the PO line if it is in APPROVED status
                                            IF group_rec.approved_flag <> 'R'
                                            THEN
                                                DoLog (
                                                    'Before update_po_line');
                                                --update_po_line ( -- CCR0006285
                                                update_po_line_ds ( -- CCR0006285
                                                    pv_po_number     =>
                                                        rec.po_number,
                                                    pn_line_num      =>
                                                        rec.line_num,
                                                    pn_shipment_num   =>
                                                        rec.shipment_num,
                                                    pn_quantity      => NULL,
                                                    pn_unit_price    => NULL,
                                                    --  pd_promised_date        => NVL (rec.new_promised_date,group_rec.promised_date)- 1, --w.r.t CCR0010003
                                                    pd_promised_date   =>
                                                          NVL (
                                                              rec.new_promised_date,
                                                              rec.ex_factory_date)
                                                        - 1, --w.r.t CCR0010003
                                                    pv_ship_method   => NULL,
                                                    pv_freight_pay_party   =>
                                                        NULL,
                                                    pd_cxf_date      => NULL,
                                                    pv_supplier_site_code   =>
                                                        group_rec.supplier_site_code,
                                                    pn_user_id       =>
                                                        ln_user_id,
                                                    pv_error_stat    =>
                                                        lv_error_stat,
                                                    pv_error_msg     =>
                                                        lv_error_msg);

                                                --START -- Added CCR0006035
                                                IF lv_error_msg IS NOT NULL
                                                THEN
                                                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                                       SET error_message = SUBSTR (lv_error_msg, 1, 2000)
                                                     WHERE gtn_po_collab_stg_id =
                                                           rec.gtn_po_collab_stg_id;
                                                END IF;
                                            --END -- Added CCR0006035
                                            END IF;
                                        END IF;

                                        DoLog (
                                               '** after pre-update po_line - approved_flag = '
                                            || group_rec.approved_flag);

                                        --For POs tied to a SO we need to update the SO quantity
                                        IF    ln_po_src_type = G_PO_TYPE_DS
                                           OR ln_po_src_type = G_PO_TYPE_JPTQ
                                           OR ln_po_src_type =
                                              G_PO_TYPE_INTERCO
                                        THEN
                                            BEGIN
                                                DoLog (
                                                       'Checking for SO Line : '
                                                    || rec.oe_line_id);

                                                --get user ID for SO line to cancel
                                                SELECT --created_by,  -- Commented CCR0007262
                                                       flow_status_code, open_flag, cancelled_quantity
                                                  INTO --ln_user_id,  -- Commented CCR0007262
                                                       lv_flow_status_code, lv_open_flag, n_cancelled_qty
                                                  FROM oe_order_lines_all
                                                 WHERE line_id =
                                                       rec.oe_line_id;
                                            EXCEPTION
                                                WHEN NO_DATA_FOUND
                                                THEN
                                                    DoLog ('Line not found');
                                            END;


                                            DoLog (
                                                   '     OOLA cancelled QTY : '
                                                || n_cancelled_qty);
                                            DoLog (
                                                   '** before cancel_so_line. Line ID '
                                                || rec.oe_line_id);

                                            --For a DS record we need to update the SO line first
                                            cancel_so_line (
                                                pn_line_id     => rec.oe_line_id,
                                                pn_user_id     => ln_user_id,
                                                pv_reason_code   =>
                                                    gn_cancel_reason_code,
                                                pv_error_stat   =>
                                                    lv_error_stat,
                                                pv_error_msg   => lv_error_msg);

                                            DoLog (
                                                   '** after cancel_so_line. Return :'
                                                || lv_error_stat);

                                            IF lv_error_stat <> 'S'
                                            THEN
                                                DOLOG (
                                                    'Before Raising Ex_update1');
                                                RAISE ex_update;
                                            END IF;

                                            SELECT cancelled_quantity
                                              INTO n_cancelled_qty
                                              FROM oe_order_lines_all
                                             WHERE line_id = rec.oe_line_id;

                                            DoLog (
                                                   '     OOLA cancelled QTY : '
                                                || n_cancelled_qty);

                                            DoLog (
                                                '     Check SO hold status');

                                            --Check and release any holds
                                            ln_hold_count   :=
                                                check_so_hold_status (
                                                    rec.oe_header_id,
                                                    TRUE,
                                                    ln_user_id,
                                                    lv_error_stat,
                                                    lv_error_msg);


                                            --If hold release fails then ??
                                            IF lv_error_stat <> 'S'
                                            THEN
                                                lv_error_msg   :=
                                                       'Error checking/releasing hold '
                                                    || lv_error_msg;
                                                dolog (lv_error_msg); -- CCR0006517
                                            END IF;

                                            IF ln_hold_count > 0
                                            THEN
                                                lv_error_msg   :=
                                                    'Holds exist on SO';
                                                dolog (lv_error_msg); -- CCR0006517
                                            END IF;

                                            DoLog (
                                                   '** before update_po_line. PO Number '
                                                || rec.po_number
                                                || ' line num '
                                                || rec.line_num);
                                        END IF;


                                        --update_po_line ( -- CCR0006285
                                        -- START CCR0007262  -- IF ln_po_src_type = G_PO_TYPE_DS
                                        ln_quantity_billed   := NULL;
                                        lv_cancel_flag       := NULL;
                                        lv_closed_code       := NULL;

                                        BEGIN
                                            SELECT NVL (plla.quantity_billed, 0), NVL (plla.cancel_flag, 'N'), plla.closed_code
                                              INTO ln_quantity_billed, lv_cancel_flag, lv_closed_code
                                              FROM po_line_locations_all plla, po_lines_all pla, po_headers_all pha
                                             WHERE     pha.po_header_id =
                                                       pla.po_header_id
                                                   AND pla.po_line_id =
                                                       plla.po_line_id
                                                   AND pha.segment1 =
                                                       rec.po_number
                                                   AND pla.line_num =
                                                       rec.line_num
                                                   AND plla.shipment_num =
                                                       rec.shipment_num;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ln_quantity_billed   := NULL;
                                                lv_cancel_flag       := NULL;
                                                lv_closed_code       := NULL;
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Error in Fetching Quantity Billed and Cancel Flag :: '
                                                    || SQLERRM);
                                        END;



                                        --Begin CCR0008134
                                        --If Drop ship then get JP PO LIne. if one exists then close the po line
                                        IF ln_po_src_type = G_PO_TYPE_DS --TODO : G_PO_TYPE_JPTQ
                                        THEN
                                            ln_jp_po_line_ID   :=
                                                get_jp_po_line (
                                                    rec.po_line_location_id);

                                            IF ln_jp_po_line_ID IS NOT NULL
                                            THEN
                                                SELECT segment1 jp_po_number
                                                  INTO lv_jp_po_number
                                                  FROM po_headers_all pha, po_lines_all pla
                                                 WHERE     pha.po_header_id =
                                                           pla.po_header_id
                                                       AND pla.po_line_id =
                                                           ln_jp_po_line_id;

                                                close_po_line (
                                                    pv_po_number   =>
                                                        lv_jp_po_number,
                                                    pn_line_num   =>
                                                        ln_jp_po_line_ID,
                                                    pn_user_id   => ln_user_id,
                                                    pv_error_stat   =>
                                                        lv_error_stat,
                                                    pv_error_msg   =>
                                                        lv_error_msg);

                                                DoLog (
                                                       '** after close jp po line. Return :'
                                                    || lv_error_stat);
                                            END IF;
                                        END IF;

                                        --End CCR0008134

                                        IF     ln_po_src_type <> G_PO_TYPE_DS
                                           AND ln_po_src_type <>
                                               G_PO_TYPE_JPTQ
                                           --AND ln_quantity_billed <> rec.quantity
                                           AND lv_cancel_flag <> 'Y'
                                           AND lv_closed_code <> 'CLOSED'
                                        THEN
                                            update_po_line (     -- CCR0006285
                                                pv_po_number           =>
                                                    rec.po_number,
                                                pn_line_num            => rec.line_num,
                                                pn_shipment_num        =>
                                                    rec.shipment_num,
                                                pn_quantity            => rec.quantity,
                                                pn_unit_price          => NULL,
                                                pd_promised_date       => NULL,
                                                pv_ship_method         => NULL,
                                                pv_freight_pay_party   => NULL,
                                                pd_cxf_date            => NULL,
                                                pv_supplier_site_code   =>
                                                    NULL,
                                                pn_user_id             =>
                                                    ln_user_id,
                                                pv_error_stat          =>
                                                    lv_error_stat,
                                                pv_error_msg           =>
                                                    lv_error_msg);

                                            --START -- Added CCR0006035
                                            IF lv_error_msg IS NOT NULL
                                            THEN
                                                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                                   SET error_message = SUBSTR (lv_error_msg, 1, 2000)
                                                 WHERE gtn_po_collab_stg_id =
                                                       rec.gtn_po_collab_stg_id;
                                            END IF;

                                            --END -- Added CCR0006035

                                            close_po_line (
                                                pv_po_number   =>
                                                    rec.po_number,
                                                pn_line_num    => rec.line_num,
                                                pn_user_id     => ln_user_id,
                                                pv_error_stat   =>
                                                    lv_error_stat,
                                                pv_error_msg   => lv_error_msg);

                                            DoLog (
                                                   '** after close po line. Return :'
                                                || lv_error_stat);

                                            IF lv_error_stat != 'S'
                                            THEN
                                                --For Std POs. Note error but continue as this will not prevent downstream action.
                                                --For Interco/drop ship, this prevents further action on this PO line (raise error for this group)
                                                IF ln_po_src_type =
                                                   G_PO_TYPE_INTERCO
                                                THEN
                                                    lv_error_msg   :=
                                                           'close PO line failed :'
                                                        || lv_error_msg;
                                                    RAISE ex_update;
                                                ELSE
                                                    DoLog (
                                                           '     Error when closing PO line. PO Number : '
                                                        || rec.po_number
                                                        || ' Line Number '
                                                        || group_rec.line_num
                                                        || ' Note: This PO line will need to be closed manually'); --TODO: How do we notify on warning type messages
                                                END IF;
                                            END IF;
                                        --TODO: Check if JP PO then close the JP PO LIne


                                        END IF; -- END OF IF ln_po_src_type = G_PO_TYPE_DS
                                    -- END CCR0007262
                                    --TODO : do we need to cancel upstream items REQ/SO Line
                                    ELSIF rec.quantity >
                                          group_rec.po_shipment_rcv
                                    THEN
                                        --Update the current line (only needed for Drop Ship SOs to allow update of the SO
                                        IF    ln_po_src_type = G_PO_TYPE_DS
                                           OR ln_po_src_type = G_PO_TYPE_JPTQ
                                        THEN
                                            --Before updating the SO lIne we are updating the PO line if it is in APPROVED status
                                            IF group_rec.approved_flag <> 'R'
                                            THEN
                                                DoLog (
                                                    'Before update_po_line');
                                                --update_po_line( -- CCR0006285
                                                update_po_line_ds (
                                                    pv_po_number     =>
                                                        rec.po_number,
                                                    pn_line_num      =>
                                                        rec.line_num,
                                                    pn_shipment_num   =>
                                                        rec.shipment_num,
                                                    pn_quantity      => NULL,
                                                    pn_unit_price    => NULL,
                                                    --  pd_promised_date        => NVL (rec.new_promised_date,group_rec.promised_date)- 1, --w.r.t CCR0010003
                                                    pd_promised_date   =>
                                                          NVL (
                                                              rec.new_promised_date,
                                                              rec.ex_factory_date)
                                                        - 1, --w.r.t CCR0010003
                                                    pv_ship_method   => NULL,
                                                    pv_freight_pay_party   =>
                                                        NULL,
                                                    pd_cxf_date      => NULL,
                                                    pv_supplier_site_code   =>
                                                        group_rec.supplier_site_code,
                                                    pn_user_id       =>
                                                        ln_user_id,
                                                    pv_error_stat    =>
                                                        lv_error_stat,
                                                    pv_error_msg     =>
                                                        lv_error_msg);

                                                --START -- Added CCR0006035
                                                IF lv_error_msg IS NOT NULL
                                                THEN
                                                    UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                                       SET error_message = SUBSTR (lv_error_msg, 1, 2000)
                                                     WHERE gtn_po_collab_stg_id =
                                                           rec.gtn_po_collab_stg_id;
                                                END IF;
                                            --END -- Added CCR0006035
                                            END IF;
                                        END IF;

                                        DoLog (
                                               '** after pre-update po_line - approved_flag = '
                                            || group_rec.approved_flag);

                                        --For POs tied to a SO we need to update the SO quantity
                                        IF    ln_po_src_type = G_PO_TYPE_DS
                                           OR ln_po_src_type = G_PO_TYPE_JPTQ
                                           OR ln_po_src_type =
                                              G_PO_TYPE_INTERCO
                                        THEN
                                            BEGIN
                                                DoLog (
                                                       'Checking for SO Line : '
                                                    || rec.oe_line_id);

                                                --get user ID for SO line to cancel
                                                SELECT --created_by, -- Commented CCR0007262
                                                       flow_status_code, open_flag, cancelled_quantity
                                                  INTO --ln_user_id,  -- Commented CCR0007262
                                                       lv_flow_status_code, lv_open_flag, n_cancelled_qty
                                                  FROM oe_order_lines_all
                                                 WHERE line_id =
                                                       rec.oe_line_id;
                                            EXCEPTION
                                                WHEN NO_DATA_FOUND
                                                THEN
                                                    DoLog (
                                                        'SO Line not found');
                                            END;


                                            DoLog (
                                                   '     OOLA cancelled QTY : '
                                                || n_cancelled_qty);
                                            DoLog (
                                                   '** before update_so_line. Line ID '
                                                || rec.oe_line_id);

                                            --For a DS record we need to update the SO line first
                                            -- Start CCR0006517
                                            IF (ln_po_src_type = G_PO_TYPE_DS OR ln_po_src_type = G_PO_TYPE_JPTQ)
                                            THEN
                                                update_so_line (
                                                    pn_header_id   =>
                                                        rec.oe_header_id,
                                                    pn_line_id   =>
                                                        rec.oe_line_id,
                                                    pn_new_quantity   =>
                                                          rec.quantity
                                                        - group_rec.po_shipment_rcv, --Rev1: Set SO qty to Updated qty - already received qty
                                                    pn_user_id   => ln_user_id,
                                                    pd_request_date   =>
                                                        rec.new_promised_date,
                                                    pv_error_stat   =>
                                                        lv_error_stat,
                                                    pv_error_msg   =>
                                                        lv_error_msg);
                                            ELSIF ln_po_src_type =
                                                  G_PO_TYPE_INTERCO
                                            THEN
                                                update_so_line (
                                                    pn_header_id      =>
                                                        rec.oe_header_id,
                                                    pn_line_id        =>
                                                        rec.oe_line_id,
                                                    pn_new_quantity   =>
                                                          rec.quantity
                                                        - group_rec.po_shipment_rcv,
                                                    pn_user_id        => ln_user_id,
                                                    pd_request_date   => NULL,
                                                    pv_error_stat     =>
                                                        lv_error_stat,
                                                    pv_error_msg      =>
                                                        lv_error_msg);
                                            END IF;

                                            -- END CCR0006517

                                            DoLog (
                                                   '** after update_so_line. Return :'
                                                || lv_error_stat);

                                            IF lv_error_stat <> 'S'
                                            THEN
                                                dolog (
                                                       'Error Message :: '
                                                    || lv_error_msg); -- CCR0006517
                                                RAISE ex_update;
                                            END IF;

                                            SELECT cancelled_quantity
                                              INTO n_cancelled_qty
                                              FROM oe_order_lines_all
                                             WHERE line_id = rec.oe_line_id;

                                            DoLog (
                                                   '     OOLA cancelled QTY : '
                                                || n_cancelled_qty);

                                            DoLog (
                                                '     Check SO hold status');

                                            --Check and release any holds
                                            ln_hold_count   :=
                                                check_so_hold_status (
                                                    rec.oe_header_id,
                                                    TRUE,
                                                    ln_user_id,
                                                    lv_error_stat,
                                                    lv_error_msg);


                                            --If hold release fails then ??
                                            IF lv_error_stat <> 'S'
                                            THEN
                                                lv_error_msg   :=
                                                       'Error checking/releasing hold '
                                                    || lv_error_msg;
                                                dolog (lv_error_msg); -- CCR0006517
                                            END IF;

                                            IF ln_hold_count > 0
                                            THEN
                                                lv_error_msg   :=
                                                    'Holds exist on SO';
                                            END IF;

                                            DoLog (
                                                   '** before update_po_line. PO Number '
                                                || rec.po_number
                                                || ' line num '
                                                || rec.line_num);
                                        END IF;

                                        --Now update the PO line to match the source SO
                                        --Update the current line
                                        --For DS type POs we will modify the underlying SO line
                                        --update_po_line( -- CCR0006285
                                        update_po_line (
                                            pv_po_number    => rec.po_number,
                                            pn_line_num     => rec.line_num,
                                            pn_shipment_num   =>
                                                rec.shipment_num,
                                            pn_quantity     => rec.quantity,
                                            pn_unit_price   => rec.unit_price,
                                            pd_promised_date   =>
                                                rec.new_promised_date,
                                            pv_ship_method   =>
                                                rec.ship_method,
                                            pv_freight_pay_party   =>
                                                rec.freight_pay_party,
                                            pd_cxf_date     =>
                                                rec.ex_factory_date,
                                            pv_supplier_site_code   =>
                                                group_rec.supplier_site_code,
                                            pn_user_id      => ln_user_id,
                                            pv_error_stat   => lv_error_stat,
                                            pv_error_msg    => lv_error_msg);

                                        --START -- Added CCR0006035
                                        IF lv_error_msg IS NOT NULL
                                        THEN
                                            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                               SET error_message = SUBSTR (lv_error_msg, 1, 2000)
                                             WHERE gtn_po_collab_stg_id =
                                                   rec.gtn_po_collab_stg_id;
                                        END IF;

                                        --END -- Added CCR0006035

                                        IF (ln_po_src_type = G_PO_TYPE_DS OR ln_po_src_type = G_PO_TYPE_JPTQ)
                                        THEN
                                            NULL;
                                        --TODO: Check if JP PO line. If so then adjust PO Line quantity
                                        END IF;

                                        DoLog (
                                               '** after update_po_line. Return :'
                                            || lv_error_stat);
                                        DoLog ('    set create req flag = N');

                                        --Mark stg record as REQ line not needed
                                        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                           SET create_req   = 'N'
                                         WHERE gtn_po_collab_stg_id =
                                               rec.gtn_po_collab_stg_id;

                                        --If Drop ship then get JP PO LIne. if one exists then update the quantity
                                        IF (ln_po_src_type = G_PO_TYPE_DS OR ln_po_src_type = G_PO_TYPE_JPTQ)
                                        THEN
                                            ln_jp_po_line_ID   :=
                                                get_jp_po_line (
                                                    rec.po_line_location_id);

                                            IF ln_jp_po_line_ID IS NOT NULL
                                            THEN
                                                SELECT segment1 jp_po_number, line_num
                                                  INTO lv_jp_po_number, ln_jp_po_line_num
                                                  FROM po_headers_all pha, po_lines_all pla
                                                 WHERE     pha.po_header_id =
                                                           pla.po_header_id
                                                       AND pla.po_line_id =
                                                           ln_jp_po_line_id;

                                                update_po_line (
                                                    pv_po_number       =>
                                                        lv_jp_po_number,
                                                    pn_line_num        =>
                                                        ln_jp_po_line_num,
                                                    pn_shipment_num    => 1,
                                                    pn_quantity        =>
                                                        rec.quantity,
                                                    pn_unit_price      => NULL,
                                                    pd_promised_date   => NULL,
                                                    pv_ship_method     => NULL,
                                                    pv_freight_pay_party   =>
                                                        NULL,
                                                    pd_cxf_date        => NULL,
                                                    pv_supplier_site_code   =>
                                                        NULL,
                                                    pn_user_id         =>
                                                        ln_user_id,
                                                    pv_error_stat      =>
                                                        lv_error_stat,
                                                    pv_error_msg       =>
                                                        lv_error_msg);

                                                DoLog (
                                                       '** after close jp po line. Return :'
                                                    || lv_error_stat);
                                            END IF;
                                        END IF;
                                    ELSE --stg qty < qty_rcv : this is an error as we cannot set the shipment quantity to less than what is received'
                                        DoLog ('New qty < rcv qty');
                                        lv_error_msg   :=
                                               'New Qty < recv Qty :'
                                            || lv_error_msg;
                                        RAISE ex_update;
                                    END IF;
                                END IF;
                            ELSE
                                DoLog (' No qty update');

                                --Update PO data but not the quantity
                                -- Start CCR0006517
                                IF NVL (group_rec.po_shipment_rcv, 0) > 0
                                THEN
                                    DoLog (
                                        'Entered Condition where quantity received is greater than zero');
                                    update_po_line (
                                        pv_po_number      => rec.po_number,
                                        pn_line_num       => rec.line_num,
                                        pn_shipment_num   => rec.shipment_num,
                                        pn_quantity       => NULL,
                                        pn_unit_price     => rec.unit_price,
                                        pd_promised_date   =>
                                            rec.new_promised_date,
                                        pv_ship_method    => rec.ship_method,
                                        pv_freight_pay_party   =>
                                            rec.freight_pay_party,
                                        pd_cxf_date       =>
                                            rec.ex_factory_date,
                                        pv_supplier_site_code   =>
                                            group_rec.supplier_site_code,
                                        pn_user_id        => ln_user_id,
                                        pv_error_stat     => lv_error_stat,
                                        pv_error_msg      => lv_error_msg);
                                ELSE
                                    ---- End CCR0006517
                                    DoLog (
                                        'Entered Condition where quantity is not received');
                                    update_po_line (
                                        pv_po_number      => rec.po_number,
                                        pn_line_num       => rec.line_num,
                                        pn_shipment_num   => rec.shipment_num,
                                        pn_unit_price     => rec.unit_price,
                                        pd_promised_date   =>
                                            rec.new_promised_date,
                                        pv_ship_method    => rec.ship_method,
                                        pv_freight_pay_party   =>
                                            rec.freight_pay_party,
                                        pd_cxf_date       =>
                                            rec.ex_factory_date,
                                        pv_supplier_site_code   =>
                                            group_rec.supplier_site_code,
                                        pn_user_id        => ln_user_id,
                                        pv_error_stat     => lv_error_stat,
                                        pv_error_msg      => lv_error_msg);
                                END IF;             -- Added End if CCR0006517
                            END IF;

                            DoLog ('Update source PO type on stg record');

                            --Set the PO source type on the stg record
                            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                               SET src_po_type_id = ln_po_src_type, error_message = SUBSTR (lv_error_msg, 1, 2000) -- Added CCR0006035
                             WHERE gtn_po_collab_stg_id =
                                   rec.gtn_po_collab_stg_id;

                            DoLog ('     End - first record');

                            --For testing only
                            /*        if rec.po_line_location_id = 1378764 then
                                      DoLog('Exception test ID '||rec.po_line_location_id);
                                      raise ex_update;
                                    end if;*/

                            --Set first record flag to false for sucessive records for group
                            lb_first_record   := FALSE;
                        ELSE
                            DoLog ('>>>     First Record = FALSE');
                            DoLog (
                                   '     STG_REC_ID: '
                                || rec.gtn_po_collab_stg_id
                                || ' req_type : '
                                || rec.req_type
                                || ' req_created : '
                                || rec.req_created);

                            BEGIN
                                dolog (
                                       'Line ID : '
                                    || rec.oe_line_id
                                    || ' REC Qty : '
                                    || rec.quantity);

                                --Get source sales order qty
                                --If this is not found or there is no linked SO qty then the PO_shipment qty will be used
                                SELECT ordered_quantity + cancelled_quantity
                                  INTO ln_so_quantity
                                  FROM oe_order_lines_all
                                 WHERE     line_id = rec.oe_line_id
                                       AND open_flag = 'Y';

                                DoLog (
                                    'SO Orig Quantity : ' || ln_so_quantity);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    DoLog (
                                           'No order qty found. setting from PO qty : '
                                        || group_rec.po_shipment_qty);
                                    --If no linked SO then use PO shipment quantity
                                    ln_so_quantity   :=
                                        group_rec.po_shipment_qty;
                            END;

                            DoLog ('Orig Src Qty : ' || ln_so_quantity);
                            DoLog (
                                'Group Rec PO_shipment_qty : ' || group_rec.po_shipment_qty);
                            DoLog ('req.quantity : ' || rec.quantity);

                            --The existance of a record beyond the first is an update as the total qty can change
                            --CCR0008134
                            --TODO: Change to order ordered quantity + cancelled quantity ? to fix 1/2 split issue
                            --     lb_qty_update := (rec.quantity - ln_so_quantity) != 0;

                            --     IF lb_qty_update
                            --     THEN
                            --End CCR0008134
                            --Po line would have already been canelled when the first record was processed. Update these additional ones as well
                            IF rec.cancel_line = 'Y'
                            THEN
                                DoLog (
                                    'Updating PO From Fields for addtl records');

                                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                   SET from_po_number = po_number, from_po_header_id = po_header_id, from_po_line_id = po_line_id,
                                       from_po_line_location_id = po_line_location_id, from_req_header_id = req_header_id, from_req_line_id = req_line_id
                                 WHERE gtn_po_collab_stg_id =
                                       rec.gtn_po_collab_stg_id;
                            END IF; --for drop ship SO, we are adding a new line

                            --For drop ship POs. We will create a new SO line for each additional record for the group
                            IF (ln_po_src_type = G_PO_TYPE_DS)
                            THEN
                                DoLog ('** Before create_drop_ship_so_line');
                                create_drop_ship_so_line (
                                    pn_header_id      => rec.oe_header_id,
                                    pn_from_line_id   => rec.oe_line_id,
                                    pn_new_quantity   => rec.quantity,
                                    pn_user_id        => ln_user_id,
                                    pd_request_date   => rec.new_promised_date,
                                    pn_new_line_id    => ln_new_line_id,
                                    pv_error_stat     => lv_error_stat,
                                    pv_error_msg      => lv_error_msg);
                                DoLog (
                                       '** after create_drop_ship_so_line Return : '
                                    || lv_error_stat);
                                --get new line data to update stage record


                                DoLog ('     set create req flag = Y');

                                IF lv_error_stat = 'S'
                                THEN
                                    DoLog (
                                           'New line ID '
                                        || NVL (ln_new_line_id, 0));

                                    IF ln_new_line_id IS NOT NULL
                                    THEN
                                        UPDATE xxdo.xxdo_gtn_po_collab_stg
                                           SET oe_line_id = ln_new_line_id, from_oe_line_id = rec.oe_line_id, from_oe_header_id = rec.oe_header_id,
                                               drop_ship_source_id = NULL
                                         --  ,from_oe_line_id = rec.oe_line_id
                                         WHERE gtn_po_collab_stg_id =
                                               rec.gtn_po_collab_stg_id;
                                    END IF;
                                ELSE
                                    --SO Line failed to create
                                    DoLog ('SO Line failed to create');
                                    DoLog (
                                        'New Line Value : ' || ln_new_line_id);
                                    write_error_to_stg_rec (
                                        pn_batch_id,
                                        rec.gtn_po_collab_stg_id,
                                        NULL,
                                        TRUE,
                                        lv_error_msg);
                                END IF;
                            ELSIF ln_po_src_type = G_PO_TYPE_INTERCO
                            THEN
                                --Set from values in stg table
                                UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                                   SET from_oe_header_id = oe_header_id, from_oe_line_id = oe_line_id
                                 WHERE gtn_po_collab_stg_id =
                                       rec.gtn_po_collab_stg_id;
                            END IF;

                            --Set Req type flag
                            IF ln_po_src_type = G_PO_TYPE_INTERCO
                            THEN
                                lv_req_type   := 'INTERNAL';
                            ELSE
                                --Begin CCR0008134
                                --For JP TQ type POs we need to create the JP PR/PO
                                IF ln_po_src_type = G_PO_TYPE_JPTQ
                                THEN
                                    lv_req_type   := 'TQ';
                                ELSE
                                    lv_req_type   := 'EXTERNAL';
                                END IF;
                            --End CCR0008134
                            END IF;

                            DoLog ('     REQ type: ' || lv_req_type);

                            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                               SET create_req = 'Y', req_type = lv_req_type, req_created = 'N',
                                   vendor_id = group_rec.vendor_id, vendor_site_id = group_rec.vendor_site_id
                             WHERE gtn_po_collab_stg_id =
                                   rec.gtn_po_collab_stg_id;

                            --CCR0008134
                            --    ELSE
                            --      DoLog ('No update');
                            --    END IF;
                            --End CCR0008134

                            --Set the PO source type on the stg record
                            UPDATE xxdo.xxdo_gtn_po_collab_stg stg
                               SET src_po_type_id   = ln_po_src_type
                             WHERE gtn_po_collab_stg_id =
                                   rec.gtn_po_collab_stg_id;

                            IF lb_qty_update
                            THEN
                                --Decrement the running tally of remaining quantity
                                ln_curr_qty   := ln_curr_qty - rec.quantity;
                            END IF;
                        END IF;

                        DoLog ('     Record loop end');
                    END LOOP;
                /*               --Do not approve updated POs

                            IF group_rec.cancel_line = 'N'
                            THEN
                               --approve the origional PO that was modified
                               --Approve PO that was updated


                               DoLog ('Approve PO : ' || group_rec.po_number);

                               approve_po (pv_po_number    => group_rec.po_number,
                                           pn_user_id      => ln_user_id,
                                           pv_error_stat   => lv_error_stat,
                                           pv_error_msg    => lv_error_msg);

                               DoLog (
                                     'After approve PO : '
                                  || group_rec.po_number
                                  || ' Stat : '
                                  || pv_error_stat);
                            END IF;*/

                ELSE
                    DoLog (
                        ' One or more records for po shipment are in error/ error out all records for this shipment line');
                    write_error_to_stg_rec (
                        pn_batch_id,
                        NULL,
                        group_rec.po_line_location_id,
                        TRUE,
                        'One or more recods for this shipment failed to process');
                END IF;


                DoLog ('     outer loop end');
                COMMIT;
            EXCEPTION
                WHEN ex_update
                THEN
                    --Set error message
                    lv_error_msg    :=
                           'Error occurred when processing record .'
                        || lv_error_msg
                        || ' LLOC_ID : '
                        || group_rec.po_line_location_id;
                    DoLog (lv_error_msg);

                    --rollback to savepoint
                    ROLLBACK TO POLineProcess;

                    --Update stage table record to error
                    write_error_to_stg_rec (pn_batch_id, NULL, group_rec.po_line_location_id
                                            , TRUE, lv_error_msg);
                    COMMIT;

                    --reset error flags
                    lv_error_msg    := NULL;
                    lv_error_stat   := 'S';
                WHEN OTHERS
                THEN
                    --Set error message
                    lv_error_msg    :=
                           'Unexpected error '
                        || SQLERRM
                        || ' when processing record '
                        || ' LLOC_ID : '
                        || group_rec.po_line_location_id
                        || ' :: Check for Corresponding SO Line Information for this PO Line '; -- CCR0007064
                    DoLog (lv_error_msg);

                    --rollback to savepoint
                    ROLLBACK TO POLineProcess;

                    --Update stage table record to error
                    write_error_to_stg_rec (pn_batch_id, NULL, group_rec.po_line_location_id
                                            , TRUE, lv_error_msg);
                    COMMIT;

                    --reset error flags
                    lv_error_msg    := NULL;
                    lv_error_stat   := 'S';
            END;

            DoLog ('End Loop');
        END LOOP;

        COMMIT;

        DoLog (
            'Checking for errors in stg records to prevent partial processing');

        --Flag any STG table records as ERROR where there is another record for the same batch/po already in error. This prevents partial further process
        UPDATE xxdo.xxdo_gtn_po_collab_stg stg
           SET processing_status_code = 'ERROR', error_message = 'PO/BATCH has failures for other lines'
         WHERE     batch_id = pn_batch_id
               AND EXISTS
                       (SELECT NULL
                          FROM xxdo.xxdo_gtn_po_collab_stg stg1
                         WHERE     stg.batch_id = stg1.batch_id
                               AND stg.po_header_id = stg1.po_header_id
                               AND stg1.processing_status_code = 'ERROR')
               AND processing_status_code = 'RUNNING';


        COMMIT;

        --Step to push all internal reqs to pre-PR linke other reqs
        --Stage records with req_type 'INTERNAL' and req_created = 'N' and create_req = 'Y'

        -- START CCR0006517 To Check if there is any Order Import is scheduled for Macau OU
        ln_oimp_hold_request_id   := NULL;
        check_program_status ('OEOIMP',       -- concurrent program short name
                                        NULL,                     -- Hold Flag
                                              ln_oimp_hold_request_id, -- Request id
                              99);
        -- END CCR0006517

        DoLog ('** before Push TQ to PR');
        run_tq_recs_to_ds (pn_batch_id, gv_source_code, lV_ERROR_STAT,
                           lV_ERROR_MSG);

        --The next steps will gather up valid records to process. Any errors reported do not cause the termination of the proces sequence
        DoLog ('** before Push IR to PR');
        run_ir_recs_to_iso (pn_batch_id, gv_source_code, lV_ERROR_STAT,
                            lV_ERROR_MSG);

        DoLog ('** after Push IR to PR - Return : ' || lV_ERROR_STAT);

        -- Start CCR0006517 To Release Hold on Order Import Program
        dolog (
               'Before Entered condition to release hold :: '
            || ln_oimp_hold_request_id);
        check_program_status ('OEOIMP',       -- concurrent program short name
                                        'N',                      -- Hold Flag
                                             ln_oimp_hold_request_id, -- Request id
                              NULL);
        -- END CCR0006517
        --Process all PR rec stage records to req IFACE and import

        DoLog ('** Before create PRs for US POs');
        --Create Purchase REQs for US POs
        Create_pr_for_us_pos (pn_batch_id, ln_user_id, lv_error_stat,
                              lv_error_msg);


        DoLog ('** After create PRs for US POs');
        DoLog ('     Stat : ' || lv_error_stat);
        DoLog ('     Msg  : ' || lv_error_msg);

        IF lv_error_stat != 'S'
        THEN
            write_error_to_stg_rec (pn_batch_id           => pn_batch_id,
                                    pb_set_error_status   => TRUE,
                                    pv_error_text         => lv_error_msg);
            RETURN;
        END IF;

        -- START CCR0006517 To Check if there is any Autocreate Purchase Requisitions is scheduled
        ln_acrq_hold_request_id   := NULL;
        check_program_status ('CTOACREQ',     -- concurrent program short name
                                          NULL,                   -- Hold Flag
                                                ln_acrq_hold_request_id, -- Request Id
                              NULL);

        -- END CCR0006517

        --create Purchase REQs for POs based on SOs (Interco/Drop ship)
        FOR order_rec IN c_orders
        LOOP
            --reset error flags for loop
            lv_error_stat   := 'S';
            lv_error_msg    := NULL;

            DoLog (
                'Processing SO  Order Number : ' || order_rec.order_number);

            IF (order_rec.src_po_type_id = G_PO_TYPE_DS OR order_rec.src_po_type_id = G_PO_TYPE_JPTQ)
            THEN
                DoLog ('** Before create PR from DSS SO');
                Create_pr_from_drop_ship_so (
                    pn_order_number   => order_rec.order_number,
                    pn_user_id        => ln_user_id,
                    pv_error_stat     => lv_error_stat,
                    pv_error_msg      => lv_error_msg,
                    pn_request_id     => ln_request_id);
            END IF;

            IF order_rec.src_po_type_id = G_PO_TYPE_INTERCO
            THEN
                DoLog ('** Before create PR from ISO');
                Create_pr_from_iso (
                    pn_order_number   => order_rec.order_number,
                    pn_user_id        => ln_user_id,
                    pv_error_stat     => lv_error_stat,
                    pv_error_msg      => lv_error_msg,
                    pn_request_id     => ln_request_id);
            END IF;

            DoLog ('    After create PR');
            DoLog ('    Stat : ' || lv_error_stat);
            DoLog ('    Msg  : ' || lv_error_msg);
            DoLog ('    Req ID  : ' || ln_request_id);

            IF lv_error_stat != 'S'
            THEN
                dolog (
                       'after create_pr call Write error for order_number : '
                    || order_rec.order_number);

                --Mark these records as error so that they are skipped in further processing.
                --This is not fatal to other orders.
                write_error_to_stg_rec (pn_batch_id => pn_batch_id, pn_order_number => order_rec.order_number, pb_set_error_status => TRUE
                                        , pv_error_text => lv_error_msg);
            END IF;
        END LOOP;

        -- Start CCR0006517 To Release Hold on Autocreate Purchase Requisitions
        check_program_status ('CTOACREQ',     -- concurrent program short name
                                          'N',                    -- Hold Flag
                                               ln_acrq_hold_request_id, -- Request id
                              NULL);
        -- END CCR0006517

        DoLog ('** run_poc_batch - Create POs for Batch = ' || pn_batch_id);

        --Create POs for the PRs that have been generated
        create_po_from_purchrec_stg (pn_batch_id     => pn_batch_id,
                                     pv_error_stat   => lv_error_stat,
                                     pv_error_msg    => lv_error_msg);

        DoLog ('Calling po_process_by_batch');
        po_process_by_batch (pn_batch_id => pn_batch_id, pn_request_id => ln_request_id, pv_error_stat => lv_error_stat
                             , pv_err_msg => lv_error_msg);
        DoLog ('Return po_process_by_batch' || lv_error_msg);
        --Any final post process validation

        --Do we log out any errored records?
        DoLog ('** run_poc_batch - Update record status to COMPLETE');

        --Update all valid records to complete

        UPDATE xxdo.xxdo_gtn_po_collab_stg
           SET processing_status_code   = 'COMPLETE'
         WHERE     batch_id = pn_batch_id
               AND processing_status_code = 'RUNNING'
               AND error_message IS NULL;                  -- Added CCR0006035

        -- Added CCR0006035
        UPDATE xxdo.xxdo_gtn_po_collab_stg
           SET processing_status_code   = 'ERROR'
         WHERE     batch_id = pn_batch_id
               AND processing_status_code = 'RUNNING'
               AND error_message IS NOT NULL;

        COMMIT;

        --Start CCR0008134
        --send e-mail alert for newly created POs
        --create_alert_email (pn_batch_id, pv_error_stat, pv_err_msg);

        --create_error_alert_email (pn_batch_id, pv_error_stat, pv_err_msg); --W.r.t CCR0006035 
        --End CCR0008134

        --Copy errors from POC stage table to SOA stage table
        log_errors_to_soa_stg (pn_batch_id);

        --Rev1 Added log for any e-mail errors. This error is not fatal to any processing
        --IF pv_error_stat != 'E' -- Commented CCR0006035
        IF pv_error_stat = 'E'                             -- Added CCR0006035
        THEN
            DoLog ('Error with e-mail generation: ' || pv_err_msg);
        END IF;

        --End processing step
        pv_error_stat             := 'S';
        pv_err_msg                := '';
        DoLog ('** run_poc_batch - Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            -- Start CCR0006517
            BEGIN
                check_program_status ('OEOIMP', -- concurrent program short name
                                                'N',              -- Hold Flag
                                                     ln_oimp_hold_request_id, -- Request id
                                      NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    dolog (
                           'Could not release hold for Order Import Request id :: '
                        || ln_oimp_hold_request_id);
            END;

            BEGIN
                check_program_status ('CTOACREQ', -- concurrent program short name
                                                  'N',            -- Hold Flag
                                                       ln_acrq_hold_request_id
                                      ,                          -- Request id
                                        NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    dolog (
                           'Could not release hold for Order Import Request id :: '
                        || ln_oimp_hold_request_id);
            END;

            -- End CCR0006517

            pv_error_stat   := 'U';
            pv_err_msg      := SQLERRM;
            DoLog ('Write to error record main procedure :: ' || pv_err_msg);

            --Set all records in batch to error
            UPDATE xxdo.xxdo_gtn_po_collab_stg
               SET processing_status_code = 'ERROR', error_message = pv_err_msg
             WHERE     batch_id = pn_batch_id
                   AND processing_status_code = 'RUNNING';
    END run_poc_batch;

    /*-------------------------Start  CCR0008896----------------------------------*/
    /*-- Commented due to conflict of CCR0010003 changes seen defect while QA Testing
   PROCEDURE po_delay_reason_copy_prc(pn_batch_id     IN     NUMBER)
   AS
   CURSOR C1 IS
   SELECT GTN_PO_COLLAB_STG_ID,
    BATCH_ID,
    BATCH_CODE,
    CREATION_DATE,
    CREATED_BY,
    USER_ID,
    SPLIT_FLAG,
    SHIP_METHOD,
    QUANTITY,
    EX_FACTORY_DATE,
    UNIT_PRICE,
    CURRENCY_CODE,
    NEW_PROMISED_DATE,
    FREIGHT_PAY_PARTY,
    ORIGINAL_LINE_FLAG,
    PO_HEADER_ID,
    ORG_ID,
    PO_NUMBER,
    SRC_PO_TYPE_ID,
    REVISION_NUM,
    PO_LINE_ID,
    LINE_NUM,
    PO_LINE_LOCATION_ID,
    SHIPMENT_NUM,
    PO_DISTRIBUTION_ID,
    DISTRIBUTION_NUM,
    PO_TYPE,
    CANCEL_LINE,
    CHANGE_TYPE,
    APPROVED_FLAG,
    CLOSED_CODE,
    CANCEL_FLAG,
    ITEM_ID,
    PREPARER_ID,
    SHIP_TO_ORGANIZATION_ID,
    SHIP_TO_LOCATION_ID,
    DROP_SHIP_FLAG,
    PROCESSING_STATUS_CODE,
    ERROR_MESSAGE,
    OE_USER_ID,
    OE_HEADER_ID,
    OE_LINE_ID,
    DROP_SHIP_SOURCE_ID,
    RESERVATION_ID,
    REQ_HEADER_ID,
    REQ_LINE_ID,
    BRAND,
    FROM_PO_NUMBER,
    FROM_OE_HEADER_ID,
    FROM_OE_LINE_ID,
    FROM_PO_HEADER_ID,
    FROM_PO_LINE_ID,
    FROM_PO_LINE_LOCATION_ID,
    FROM_REQ_HEADER_ID,
    FROM_REQ_LINE_ID,
    FROM_IR_HEADER_ID,
    FROM_IR_LINE_ID,
    CREATE_REQ,
    REQ_TYPE,
    REQ_CREATED,
    NEW_REQ_HEADER_ID,
    NEW_REQ_LINE_ID,
    VENDOR_ID,
    VENDOR_SITE_ID,
    REQUEST_ID,
    REQUEST_USER_ID,
    REQUEST_DATE,
    COMMENTS1,
    COMMENTS2,
    COMMENTS3,
    COMMENTS4,
    PO_LINE_KEY,
    SUPPLIER_SITE_CODE,
    DELAY_REASON
    FROM xxdo.xxdo_gtn_po_collab_stg
    WHERE batch_id = pn_batch_id
    AND processing_status_code = 'COMPLETE'
    AND error_message IS NULL
    AND (comments1 IS NOT NULL OR delay_reason IS NOT NULL);

    ln_error_num           NUMBER;
    lv_error_msg           CLOB := NULL;
    lv_error_stat          VARCHAR2(4) := 'S';
    lv_error_code          VARCHAR2(4000) := NULL;

   TYPE po_delay_reason_copy_type IS TABLE OF C1%ROWTYPE;
   inst_type po_delay_reason_copy_type:=po_delay_reason_copy_type();

   BEGIN
  BEGIN
   OPEN C1;
   LOOP
    FETCH C1 BULK COLLECT INTO inst_type LIMIT 10000;
     BEGIN
      FORALL i in inst_type.FIRST..inst_type.LAST SAVE EXCEPTIONS
       INSERT INTO xxd_po_delay_shipment_detail_t
       (
       gtn_po_collab_stg_id,
       batch_id,
       batch_code,
       creation_date,
       created_by,
       ex_factory_date,
       new_promised_date,
       po_header_id,
       org_id,
       po_number,
       revision_num,
       po_line_id,
       line_num,
       po_line_location_id,
       brand,
       comments1,
       delay_reason,
       air_freight_expense,
       trx_id,
       last_updated_by,
       last_update_date,
       last_update_login,
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
       commented_date,
       commented_by
       )
       VALUES
       (
       inst_type(i).gtn_po_collab_stg_id,
       inst_type(i).batch_id,
       inst_type(i).batch_code,
       SYSDATE,
       fnd_global.user_id,
       inst_type(i).ex_factory_date,
       inst_type(i).new_promised_date,
       inst_type(i).po_header_id,
       inst_type(i).org_id,
       inst_type(i).po_number,
       inst_type(i).revision_num,
       inst_type(i).po_line_id,
       inst_type(i).line_num,
       inst_type(i).po_line_location_id,
       inst_type(i).brand,
       inst_type(i).comments1,
       inst_type(i).delay_reason,
       NULL,
       NULL,
       fnd_global.user_id,
       SYSDATE,
       fnd_global.login_id,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       inst_type(i).creation_date,
       'POC'
       );
       COMMIT;
     EXCEPTION WHEN OTHERS THEN
      lv_error_stat := 'E';
                        FOR j IN 1..SQL%bulk_exceptions.count LOOP
                            ln_error_num := SQL%bulk_exceptions(j).error_index;
                            lv_error_code:= SQLERRM(-1 * SQL%bulk_exceptions(j).error_code);
                            lv_error_msg := SUBSTR((lv_error_msg
                                                    || ' Error Inserting Location Id '
                                                    || inst_type(ln_error_num).po_line_location_id
                                                    || lv_error_code
             || ' '
             || CHR(10)), 1, 4000);

                        END LOOP;
      DoLog (' Error Records While Inserting into Table xxd_po_delay_shipment_detail_t :: ' || lv_error_msg);
     END;
    EXIT WHEN C1%NOTFOUND;
   END LOOP;
   CLOSE C1;
  EXCEPTION WHEN OTHERS THEN
   DoLog (' Error While Inserting into Table xxd_po_delay_shipment_detail_t :: ' || SQLERRM);
  END;

   END po_delay_reason_copy_prc;
   /*-------------------------------End  CCR0008896----------------------------*/
    --End Commented for CCR0010003 */

    PROCEDURE run_proc_all (pv_error_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pv_reprocess IN VARCHAR2:= 'No'
                            , pn_batch_id IN NUMBER:= NULL)
    IS
        p_next_batch        NUMBER := 0;
        g_num_request_id    NUMBER := fnd_global.conc_request_id; -- CCR0006035
        ln_counter          NUMBER := 0;                    --w.r.t CCR0010003
        pn_no_poc_retries   NUMBER := 3;                    --w.r.t CCR0010003
    BEGIN
        DoLog ('**** run_proc_all - Enter');

        DoLog ('Run pre-process for SOA posted records ');
        DoLog ('--Parameters--');
        DoLog ('Reprocess : ' || pv_reprocess);
        DoLog ('Batch ID  : ' || pn_batch_id);

        pre_process_poc_stage (pv_error_stat, pv_err_msg);

        doLog (pv_err_msg);

        IF pv_error_stat != 'S'
        THEN
            DoLog ('Pre-process failed with error : ' || pv_err_msg);
            RETURN;
        END IF;


        LOOP
            --get next batch id (do not re pull the same batch id)
            SELECT MIN (batch_id)
              INTO p_next_batch
              FROM xxdo.xxdo_gtn_po_collab_stg
             WHERE    (processing_status_code = 'PENDING' AND pv_reprocess = 'No')
                   OR     (processing_status_code = 'ERROR' AND pv_reprocess = 'Yes' AND batch_id = pn_batch_id)
                      AND batch_id != p_next_batch;

            DoLog ('Next batch : ' || p_next_batch);
            --If none found then exit loop
            EXIT WHEN p_next_batch IS NULL;

            ln_counter   := 0;                          --w.r.t CCR CCR0010003

            --For a batch ID run the specific processing step
            IF p_next_batch IS NOT NULL
            THEN
               <<poc_retry>>
                DoLog ('Run run_proc_batch for batch ID ' || p_next_batch);
                run_poc_batch (p_next_batch, pv_reprocess, pv_error_stat,
                               pv_err_msg, g_num_request_id); -- Added g_num_request_id

                --po_delay_reason_copy_prc(p_next_batch);  --Added for CCR0008896 (Commented for CCR0010003 conflict)

                --start  w.r.t CCR0010003

                IF pv_err_msg =
                   'Update error : You cannot update this document because its status is either Frozen, Canceled, Finally Closed, In Process, or Pre-approved.'
                THEN
                    IF ln_counter >= pn_no_poc_retries
                    THEN
                        NULL;
                    ELSE
                        ln_counter   := ln_counter + 1;
                        DBMS_LOCK.sleep (10);
                        GOTO poc_retry;
                    END IF;
                END IF;
            --end  w.r.t CCR0010003

            END IF;
        END LOOP;

        --Run error report for all batches in the request
        --send_error_rpt_email (g_num_request_id); --CCR0008134

        --Begin CCR0008134
        --send e-mail alert for newly created POs
        create_alert_email (g_num_request_id, pv_error_stat, pv_err_msg);

        create_error_alert_email (g_num_request_id,
                                  pv_error_stat,
                                  pv_err_msg);
        -- End CCR0008134

        pv_error_stat   := 'S';
        DoLog ('**** run_proc_all - Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            DoLog ('Error in main : ' || SQLERRM);
            pv_error_stat   := 'U';
            pv_err_msg      := SQLERRM;
    END run_proc_all;
END xxdopo_poc_utils_pub;
/


GRANT EXECUTE ON APPS.XXDOPO_POC_UTILS_PUB TO SOA_INT
/
