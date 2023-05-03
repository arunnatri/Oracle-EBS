--
-- XXDOPO_FIRST_SALE_UPLD  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOPO_FIRST_SALE_UPLD"
AS
    /****************************************************************************************
    * Package      :XXDOPO_FIRST_SALE_UPLD
    * Design       : This package is used for First sale WebADI upload
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 22-May-2017  1.0      Greg Jensen          Initial Version
    -- 15-Nov-2017   2.0     Greg Jensen          CCR0006780
    --15-May-2018   3.0      Greg Jensen          CCR0007281
    ******************************************************************************************/

    --Type to holde processing results for e-mail
    TYPE l_results_rec IS RECORD
    (
        po_number        VARCHAR2 (30),
        line_number      VARCHAR2 (40),
        sku              VARCHAR2 (30),
        po_price         NUMBER,
        first_sale       NUMBER,
        error_message    VARCHAR2 (1000)
    );

    TYPE tbl_results IS TABLE OF l_results_rec
        INDEX BY PLS_INTEGER;

    --Internal functions

    --Validate a staging table line record
    --Validation conditions
    --1) PO Number passed is a valid PO
    --2) Item_key is a valid (no-cancelled) po_line
    --3)First _sale is valid in the currency of the PO and is less than the po_line unit price
    --4)PO Line is Open and has no shipments in closed for receiving or closed for invoice status

    PROCEDURE DoLog (logText IN VARCHAR2)
    IS
    BEGIN
        -- Fnd_File.PUT_LINE (Fnd_File.LOG, logText);
        DBMS_OUTPUT.put_line (logText);
    END;

    PROCEDURE validate_line (p_rec_id    IN     NUMBER,
                             p_status       OUT VARCHAR2,
                             p_err_msg      OUT VARCHAR2)
    IS
        ln_first_sale      NUMBER;
        ln_unit_price      NUMBER;
        lv_closed_code     VARCHAR2 (25);
        lv_cancel_flag     VARCHAR2 (10);
        ln_currency_code   VARCHAR2 (15);
        --Begin CCR0007281
        ln_cnt_cl_rcv      NUMBER;
        ln_cnt_cl_inv      NUMBER;
        ln_po_number       VARCHAR2 (20);
        ln_po_line         NUMBER;
        --End CCR0007281

        lv_precision       NUMBER;
    BEGIN
        doLog ('Validate line - Enter');

        SELECT stg.first_sale,
               pha.segment1 po_number,                           -- CCR0007281
               pla.line_num po_line,                             -- CCR0007281
               pla.unit_price,
               pla.closed_code,
               pla.cancel_flag,
               pha.currency_code,
               NVL (cur.precision, 2) cur_precision,
               --Begin CCR0007281
               --Find count of shipments that are closed for receiving
               --Allow for possibility of multiple shipments on PO line
               (SELECT COUNT (*)
                  FROM po_line_locations_all plla
                 WHERE     pla.po_line_id = plla.po_line_id
                       AND NVL (plla.closed_code, 'OPEN') =
                           'CLOSED FOR RECEIVING') cnt_cl_rcv,
               --Find count of shipments that are closed for invoice
               --Allow for possibility of multiple shipments on PO line
               (SELECT COUNT (*)
                  FROM po_line_locations_all plla
                 WHERE     pla.po_line_id = plla.po_line_id
                       AND NVL (plla.closed_code, 'OPEN') =
                           'CLOSED FOR INVOICE') cnt_cl_inv
          --End CCR0007281
          INTO ln_first_sale, ln_po_number, ln_po_line, ln_unit_price,
                            lv_closed_code, lv_cancel_flag, ln_currency_code,
                            lv_precision, ln_cnt_cl_rcv, ln_cnt_cl_inv
          FROM po_headers_all pha, po_lines_all pla, XXDOPO_FIRST_SALE_STG stg,
               fnd_currencies cur
         WHERE     pla.po_line_id = stg.po_line_id
               AND pha.po_header_id = pla.po_header_id
               AND pha.currency_code = cur.currency_code(+)
               AND stg.first_sale_rec_id = p_rec_id
               AND stg.process_code = 'P';

        --Check if PO line is cancelled
        IF NVL (lv_cancel_flag, 'N') = 'Y'
        THEN
            p_status    := 'E';
            p_err_msg   := 'The PO line is cancelled';
            RETURN;
        END IF;

        --Begin CCR0007281
        IF NVL (lv_closed_code, 'OPEN') = 'CLOSED'
        THEN
            p_status    := 'E';
            p_err_msg   := 'The PO line is closed';
            RETURN;
        END IF;


        IF ln_cnt_cl_rcv > 0
        THEN
            p_status   := 'E';
            p_err_msg   :=
                   'First sale cost for PO '
                || ln_po_number
                || ', Line '
                || ln_po_line
                || ' cannot be updated. PO’s are fully received';
            RETURN;
        END IF;

        IF ln_cnt_cl_inv > 0
        THEN
            p_status   := 'E';
            p_err_msg   :=
                   'First sale cost for PO '
                || ln_po_number
                || ', Line '
                || ln_po_line
                || ' cannot be updated. PO’s are fully invoiced';
            RETURN;
        END IF;

        --End CCR0007281

        --Validate first sale price value and precision
        --check the number of decimals in the passsed in price vs the precision of the currency on the PO
        IF TRUNC (ln_first_sale * POWER (10, lv_precision)) !=
           ln_first_sale * POWER (10, lv_precision)
        THEN
            p_status   := 'E';
            p_err_msg   :=
                   'The first sale cost entered is invalid. Please enter the cost only up to '
                || lv_precision
                || ' decimal places';
            RETURN;
        END IF;

        --the first price cannot be greater than the FOB price on the line
        IF ln_first_sale > ln_unit_price
        THEN
            p_status   := 'E';
            p_err_msg   :=
                'The first sale cost entered is invalid. Please enter a cost less than the FOB price.';
            RETURN;
        END IF;

        p_status    := 'S';
        p_err_msg   := '';

        doLog ('Validate line - Exit');
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_status    := 'E';
            p_err_msg   := 'The po line is not found to update.';
        WHEN OTHERS
        THEN
            p_status    := 'E';
            p_err_msg   := SQLERRM;
    END;


    --Populate ID fields from passed in data and po information
    PROCEDURE populate_lookup_fields (p_rec_id IN NUMBER, p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2)
    IS
        ln_po_header_id       NUMBER;
        ln_org_id             NUMBER;
        ln_po_line_id         NUMBER;
        ln_line_location_id   NUMBER;
        ln_vendor_id          NUMBER;
        ln_vendor_site_id     NUMBER;
        ln_item_id            NUMBER;
    BEGIN
        DoLog ('popaulate lookup data - enter : ' || p_rec_id);

        --get po_header_id, org_id
        BEGIN
            SELECT pha.po_header_id, pha.org_id
              INTO ln_po_header_id, ln_org_id
              FROM po_headers_all pha, XXDOPO_FIRST_SALE_STG stg
             WHERE     pha.segment1 = stg.po_number
                   AND stg.process_code = 'P'
                   AND first_sale_rec_id = p_rec_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DoLog ('Data not found - header ');
                --PO not found . No further checking needed.
                RETURN;
            WHEN TOO_MANY_ROWS
            THEN
                DoLog ('too many rows - header');
                --PO # in multiple orgs
                p_status    := 'E';
                p_err_msg   := 'PO number provided exists in multiple orgs';
                RETURN;
        END;

        DoLog (
            'po header_id ' || ln_po_header_id || ' po_org_id ' || ln_org_id);

        --Get po_line_id, line_location_id
        BEGIN
            SELECT DISTINCT pla.po_line_id, plla.line_location_id, pla.item_id
              INTO ln_po_line_id, ln_line_location_id, ln_item_id
              FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                   po_distributions_all pda, XXDOPO_FIRST_SALE_STG stg
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND plla.line_location_id = pda.line_location_id
                   AND pha.po_header_id = ln_po_header_id
                   AND    pla.line_num
                       || '.'
                       || plla.shipment_num
                       || '.'
                       || pda.distribution_num =
                       stg.item_key
                   AND stg.first_sale_rec_id = p_rec_id
                   AND stg.process_code = 'P';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                DoLog ('Data not found - line ');
                --PO/Line not found
                --no need to raise error. the data will not be populated.
                NULL;
            WHEN TOO_MANY_ROWS
            THEN
                DoLog ('too many rows - line');
                --multiple distributions
                p_status    := 'E';
                p_err_msg   := 'PO shipment has multiple distributions';
                RETURN;
        END;

        DoLog (
               'po line_id '
            || ln_po_line_id
            || ' linelocation_id '
            || ln_line_location_id);

        BEGIN
            --Populate vendor data
            SELECT aps.vendor_id
              INTO ln_vendor_id
              FROM ap_suppliers aps, XXDOPO_FIRST_SALE_STG stg
             WHERE     UPPER (aps.vendor_name) = UPPER (stg.vendor_name) --case insensitive search
                   AND stg.first_sale_rec_id = p_rec_id
                   AND stg.process_code = 'P';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    --Get vendor_id from PO if name was not supplied
                    SELECT pha.vendor_id
                      INTO ln_vendor_id
                      FROM po_headers_all pha
                     WHERE pha.po_header_id = ln_po_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            WHEN OTHERS
            THEN
                --Optional data. no need to fail.
                NULL;
        END;


        BEGIN
            --Populate vendor site data
            SELECT apss.vendor_site_id
              INTO ln_vendor_site_id
              FROM ap_supplier_sites_all apss, XXDOPO_FIRST_SALE_STG stg
             WHERE     UPPER (apss.vendor_site_code) =
                       UPPER (stg.factory_site)      --case insensitive search
                   AND apss.org_id = ln_org_id
                   AND stg.first_sale_rec_id = p_rec_id
                   AND stg.process_code = 'P';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    --Get vendor_id from PO if name was not supplied
                    SELECT pha.vendor_site_id
                      INTO ln_vendor_site_id
                      FROM po_headers_all pha
                     WHERE pha.po_header_id = ln_po_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            WHEN OTHERS
            THEN
                --optional data. no need to fail.
                NULL;
        END;

        UPDATE XXDOPO_FIRST_SALE_STG stg
           SET po_header_id = ln_po_header_id, po_line_id = ln_po_line_id, line_location_id = ln_line_location_id,
               vendor_id = ln_vendor_id, vendor_site_id = ln_vendor_site_id, item_id = ln_item_id
         WHERE stg.first_sale_rec_id = p_rec_id AND stg.process_code = 'P';

        -- CCR0006780
        p_status    := 'S';
        p_err_msg   := NULL;
        --end  CCR0006780
        DoLog ('popaulate lookup data - exit : ' || p_rec_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status    := 'E';
            p_err_msg   := SQLERRM;
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
                                   := 'Automated First-Sale Upload Error Alert';
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
            || 'Attention: Automated First-Sale Upload Error Alert'
            || ': <br>'
            || '<table border="1" width="106%">'
            || '<tr><b>'
            || '<td width="15%" bgcolor="#909090" align="center" valign="middle">PO Number</td>'
            || '<td width="10%" bgcolor="#909090" align="center" valign="middle">Line #</td>'
            || '<td width="10%" bgcolor="#909090" align="center" valign="middle">SKU #</td>'
            || '<td width="10%" bgcolor="#909090" align="center" valign="middle">PO Unit Price</td>'
            || '<td width="10%" bgcolor="#909090" align="center" valign="middle">First Sale Cost</td>'
            || '<td width="40%" bgcolor="#909090" align="center" valign="middle">Error Message</td>'
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
                   AND fv.flex_value = 'XXD_PO_FIRSTSALEUPLD_EMAIL'
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
                   'PO Number '
                || p_results (i).po_number
                || ' Line # '
                || p_results (i).line_number
                || ' SKU # '
                || p_results (i).sku
                || ' PO Unit price '
                || p_results (i).po_price
                || ' First Sale Cost '
                || p_results (i).first_sale
                || ' Error Message '
                || p_results (i).error_message);

            --Form email body
            lc_email_body   :=
                   lc_email_body
                || '<tr valign="middle">'
                || '<td width="15%">'
                || p_results (i).po_number
                || '</td>'
                || '<td width="10%">'
                || p_results (i).Line_number
                || '</td>'
                || '<td width="10%">'
                || p_results (i).Sku
                || '</td>'
                || '<td width="10%">'
                || p_results (i).po_price
                || '</td>'
                || '<td width="10%">'
                || p_results (i).first_sale
                || '</td>'
                || '<td width="40%">'
                || p_results (i).error_message
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

    --Perform the update on a staging table record
    --1) update po line attribut12 with first_price value
    PROCEDURE process_line (p_rec_id    IN     NUMBER,
                            p_status       OUT VARCHAR2,
                            p_err_msg      OUT VARCHAR2)
    IS
        ln_po_header_id       NUMBER;
        ln_po_line_id         NUMBER;
        ln_line_location_id   NUMBER;
        ln_first_sale         NUMBER;
        n_count               NUMBER;
        ln_user_id            NUMBER := fnd_global.user_id;
    BEGIN
        SAVEPOINT record_update;
        --first validate record
        DoLog (' REC # ' || p_rec_id);

        --does this record exist
        SELECT COUNT (*)
          INTO n_count
          FROM XXDOPO_FIRST_SALE_STG stg
         WHERE first_sale_rec_id = p_rec_id AND stg.process_code = 'P';

        IF n_count = 0
        THEN
            p_status    := 'E';
            p_err_msg   := 'Record for ID value ' || p_rec_id || ' not found';
            RETURN;
        END IF;

        validate_line (p_rec_id, P_STATUS, P_ERR_MSG);
        dolog ('After validate line' || p_status);

        IF p_status != 'S'
        THEN
            --return error from validate_line function
            RETURN;
        END IF;

        --Now do record processing

        --Get needed data for update
        SELECT first_sale, po_line_id
          INTO ln_first_sale, ln_po_line_id
          FROM XXDOPO_FIRST_SALE_STG
         WHERE first_sale_rec_id = p_rec_id;

        --Update PO line with first_sale price
        UPDATE po_lines_all
           SET attribute12 = TO_NUMBER (ln_first_sale), last_update_date = SYSDATE, last_updated_by = ln_user_id
         WHERE po_line_id = ln_po_line_id;

        p_status    := 'S';
        p_err_msg   := NULL;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO update_data;
            p_status    := 'E';
            p_err_msg   := SQLERRM;
    END;

    --Public access functions

    --first sale has precision matcing PO currency (poh.currency_code)
    --select currency_code, enabled_flag, precision from FND_CURRENCIES where currency_code = 'USD'


    /*******************************************************************************
    FIRST_SALE_INTEGRATOR - Integrator function for WebADI call. This function reads in a record, posts to the staging table.
    The data is then validated for update to the databsase

    Parameters
                                        p_po_number      IN VARCHAR2, req  PO Number
                                        p_po_line_key    IN VARCHAR2, req  x.y.z where x=pol.line_num y=poll.shipment_num z=pda.distribution num
                                        p_first_sale     IN NUMBER,   req  price > 0 and < pol.unit price. also precision must be <= precision of PO currency
                                        p_vendor_name    IN VARCHAR2, Opt
                                        p_factory_site   IN VARCHAR2, Opt
                                        p_style_number   IN VARCHAR2, Opt
                                        p_color_code     IN VARCHAR2  Opt

    ********************************************************************************/
    PROCEDURE FIRST_SALE_INTEGRATOR (p_po_number IN VARCHAR2,      --po_number
                                                              p_po_line_key IN VARCHAR2, --x.y.z where x=pol.line_num y=poll.shipment_num z=pda.distribution num
                                                                                         p_first_sale IN NUMBER, --price > 0 and < pol.unit price
                                                                                                                 p_vendor_name IN VARCHAR2, p_factory_site IN VARCHAR2, p_style_number IN VARCHAR2
                                     , p_color_code IN VARCHAR2)
    IS
        le_webadi_exception   EXCEPTION;
        lc_err_message        VARCHAR2 (2000);
        ln_next_rec           NUMBER;
        ln_user_id            NUMBER := fnd_global.user_id;
        lv_stat               VARCHAR2 (1);
        lv_err_msg            VARCHAR2 (2000);
    BEGIN
        DoLog ('FIRST_SALE_INTEGRATOR - Enter');

        --Insert data into the staging table. Insert data as is. We will validate downstream
        SELECT XXDOPO_FIRST_SALE_STG_S.NEXTVAL INTO ln_next_rec FROM DUAL;

        --Check required fields (NOT NULL fields in table)
        IF    p_po_number IS NULL
           OR p_po_line_key IS NULL
           OR p_first_sale IS NULL
        THEN
            --Required value missing
            lc_err_message   := 'Required field is missing';
            RAISE le_webadi_exception;
        END IF;

        --all other fields in the table allow NULLs so we can now insert.

        INSERT INTO XXDOPO_FIRST_SALE_STG (first_sale_rec_id,
                                           po_number,
                                           item_key,
                                           first_sale,
                                           vendor_name,
                                           factory_site,
                                           style_number,
                                           color_code,
                                           created_by,
                                           last_updated_by,
                                           process_code,
                                           source)
             VALUES (ln_next_rec, p_po_number, p_po_line_key,
                     p_first_sale, p_vendor_name, p_factory_site,
                     p_style_number, p_color_code, ln_user_id,
                     ln_user_id, 'P', 'WEBADI');

        --commit changes at this point.
        COMMIT;

        populate_lookup_fields (ln_next_rec, lv_stat, lv_err_msg);

        --process the current line
        process_line (ln_next_rec, lv_stat, lv_err_msg);

        IF lv_stat <> 'S'
        THEN
            lc_err_message   := lv_err_msg;
            RAISE le_webadi_exception;
        END IF;

        DoLog ('Update process flag');

        --update process status of stage record
        UPDATE XXDOPO_FIRST_SALE_STG
           SET process_code = 'Y', error_message = NULL
         WHERE first_sale_rec_id = ln_next_rec;

        COMMIT;
        DoLog ('FIRST_SALE_INTEGRATOR - End');
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            DoLog ('le_webadi_exception');

            --set status of processing record to error
            UPDATE XXDOPO_FIRST_SALE_STG
               SET process_code = 'E', error_message = lc_err_message
             WHERE first_sale_rec_id = ln_next_rec;

            COMMIT;
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_err_message   := fnd_message.get ();

            raise_application_error (-20000, lc_err_message);
        WHEN OTHERS
        THEN
            DoLog ('others');
            lc_err_message   := SQLERRM;

            --set status of processing record to error
            UPDATE XXDOPO_FIRST_SALE_STG
               SET process_code = 'E', error_message = lc_err_message
             WHERE first_sale_rec_id = ln_next_rec;

            COMMIT;
            raise_application_error (-20001, lc_err_message);
    END;

    --Reset records in staging from 'E' to 'R'
    --CCR0006780 added p_source

    PROCEDURE reset_records (p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2, p_rec_id IN NUMBER:= NULL, p_po_number IN VARCHAR2:= NULL, p_style IN VARCHAR2:= NULL, p_color IN VARCHAR2:= NULL
                             , p_source IN VARCHAR2)
    IS
        CURSOR c_rec IS
            SELECT first_sale_rec_id
              FROM XXDOPO_FIRST_SALE_STG stg,
                   po_headers_all pha,
                   po_lines_all pla,
                   (SELECT *
                      FROM xxd_common_items_v
                     WHERE master_org_flag = 'Y') mtl
             WHERE     stg.po_header_id = pha.po_header_id
                   AND stg.po_line_id = pla.po_line_id
                   AND stg.item_id = mtl.inventory_item_id
                   AND pha.segment1 = NVL (p_po_number, pha.segment1)
                   AND mtl.style_number = NVL (p_style, mtl.style_number)
                   AND mtl.color_code = NVL (p_color, mtl.color_code)
                   AND process_code IN ('P', 'E')
                   AND stg.source = p_source;
    BEGIN
        IF p_rec_id IS NOT NULL
        THEN
            --Single record
            UPDATE XXDOPO_FIRST_SALE_STG
               SET process_code = 'R', error_message = NULL, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE     first_sale_rec_id = p_rec_id
                   AND process_code IN ('P', 'E');
        ELSIF p_po_number IS NULL AND p_style IS NULL AND p_color IS NULL
        --No filters - reset all pending/error
        THEN
            UPDATE XXDOPO_FIRST_SALE_STG
               SET process_code = 'R', error_message = NULL, last_update_date = SYSDATE,
                   last_updated_by = fnd_global.user_id
             WHERE process_code IN ('P', 'E');
        ELSE
            FOR rec IN c_rec
            LOOP
                UPDATE XXDOPO_FIRST_SALE_STG
                   SET process_code = 'R', error_message = NULL, last_update_date = SYSDATE,
                       last_updated_by = fnd_global.user_id
                 WHERE first_sale_rec_id = rec.first_sale_rec_id;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status    := 'E';
            p_err_msg   := SQLERRM;
    END;

    --CCR0006780 added source and reprocess parameters
    /*******************************************************************************
     Entrypoint function for concurrent request used for GTN interface

     Parameters
     p_status         OUT VARCHAR2,
     p_err_msg        OUT VARCHAR2,
     p_source      IN     VARCHAR2,             Source of records WEBADI or GTN
     p_reprocess   IN     VARCHAR2 := 'N'      Reset any E/P records to be reprocessed

   *******************************************************************************/
    PROCEDURE process_records (p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2, p_source IN VARCHAR2
                               , p_reprocess IN VARCHAR2:= 'N')
    IS
        lv_status     VARCHAR2 (1);
        lv_err_msg    VARCHAR2 (2000);
        ln_err_flag   NUMBER := 0;

        lv_sku        VARCHAR2 (30);
        ln_po_price   NUMBER;

        l_results     tbl_results;

        CURSOR c_rec IS
            SELECT first_sale_rec_id, po_number, item_key,
                   first_sale
              FROM XXDOPO_FIRST_SALE_STG stg
             WHERE process_code = 'R' AND source = p_source;
    BEGIN
        DoLog ('process_records - Enter');
        DoLog (' Source =  ' || p_source);
        DoLog (' Reprocess =  ' || p_reprocess);


        IF p_reprocess = 'Y'
        THEN
            reset_records (p_status    => lv_status,
                           p_err_msg   => lv_err_msg,
                           p_source    => p_source);
        END IF;

        DoLog ('after reset');

        IF lv_status != 'S'
        THEN
            p_status    := 'E';
            p_err_msg   := 'Failed to reset records';
            RETURN;
        END IF;

        FOR rec IN c_rec
        LOOP
            lv_sku        := NULL;
            ln_po_price   := NULL;

            UPDATE XXDOPO_FIRST_SALE_STG
               SET process_code   = 'P'
             WHERE first_sale_rec_id = rec.first_sale_rec_id;

            --Populate any needed lookups
            populate_lookup_fields (rec.first_sale_rec_id,
                                    lv_status,
                                    lv_err_msg);

            DoLog ('after populate lookups : ' || lv_status);

            IF lv_status = 'S'
            THEN
                --Process the line
                process_line (p_rec_id    => rec.first_sale_rec_id,
                              p_status    => lv_status,
                              p_err_msg   => lv_err_msg);
            END IF;

            DoLog ('after process line : ' || lv_status);

            IF lv_status != 'S'
            THEN
                --Get PO Unit Price and SKU for e-mail
                BEGIN
                    SELECT msib.sku, pla.unit_price
                      INTO lv_sku, ln_po_price
                      FROM po_lines_all pla,
                           APPS.XXDOPO_FIRST_SALE_STG stg,
                           (SELECT DISTINCT inventory_item_id, sku
                              FROM xxdo.XXDOINT_INV_PRODUCT_CATALOG_V v, mtl_parameters mp
                             WHERE     v.organization_id = mp.organization_id
                                   AND mp.organization_code = 'MST') msib
                     WHERE     stg.po_line_id = pla.po_line_id
                           AND pla.item_id = msib.inventory_item_id
                           AND stg.first_sale_rec_id = rec.first_sale_rec_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                    WHEN TOO_MANY_ROWS
                    THEN
                        NULL;
                END;

                --set status of processing record to error
                UPDATE XXDOPO_FIRST_SALE_STG
                   SET process_code = 'E', error_message = lv_err_msg
                 WHERE first_sale_rec_id = rec.first_sale_rec_id;

                --Populate the results table with the return from the process
                l_results (l_results.COUNT + 1).po_number   := rec.po_number;
                l_results (l_results.COUNT).line_number     := rec.item_key;
                l_results (l_results.COUNT).sku             := lv_sku;
                l_results (l_results.COUNT).po_price        := ln_po_price;
                l_results (l_results.COUNT).first_sale      := rec.first_sale;
                l_results (l_results.COUNT).error_message   := lv_err_msg;

                ln_err_flag                                 := 1;
            ELSE
                --set status of processing record to error
                UPDATE XXDOPO_FIRST_SALE_STG
                   SET process_code = 'Y', error_message = NULL
                 WHERE first_sale_rec_id = rec.first_sale_rec_id;
            END IF;
        END LOOP;

        DoLog (ln_err_flag);

        IF ln_err_flag = 1
        THEN
            DoLog ('Executing E-mail');
            --Send alert e-mail
            create_alert_email (l_results, p_status, p_err_msg);
            p_status    := 'W';
            p_err_msg   := 'One or more records failed to reprocess';
        END IF;

        DoLog ('process_records - Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status    := 'E';
            p_err_msg   := SQLERRM;
            DoLog (p_err_msg);
    END;
END;
/
