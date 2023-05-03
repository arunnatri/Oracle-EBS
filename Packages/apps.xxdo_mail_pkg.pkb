--
-- XXDO_MAIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_MAIL_PKG"
IS
    ---------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------
    -- Type   : FUNCTION                                                           --
    -- Name       : GET_ADDRESS                                                    --
    -- Parameters : pxv_addr_list - List of email addresses                        --
    -- Purpose    : This function will return the next email address/attachment    --
    --              name in a list of email addresses/attachment names, separated  --
    --              by either a comma "," or a semi-colon";"                       --
    --            --
    ---------------------------------------------------------------------------------
    -- Parameter Name           Description       --
    -- -----------------------  -----------------------------------------------------
    -- pxv_addr_list              String of email addresses/attachment names   --
    --                                                --
    -- Modification History                                              --
    -------------------------------------------------------------------------------------------
    -- Date          Developer       Version                  Description                       --
    -- ----------    -----------     ------------             ---------------------------------
    -- 01/17/2013    Infosys         1.0                      Initial Version                   --
    -- 30/Jun/2021   Srinath         2.0                      CCR0009404                        --
    -- 10/Jan/2022   Balavenu        3.0                      Added Global Variables CCR0009135--
    -------------------------------------------------------------------------------------------

    gv_smtp_host                        VARCHAR2 (256) := fnd_profile.VALUE ('FND_SMTP_HOST');
    gv_smtp_port                        PLS_INTEGER := fnd_profile.VALUE ('FND_SMTP_PORT');
    gv_smtp_domain                      VARCHAR2 (256)
                                            := fnd_profile.VALUE ('XXCMN_SMTP_DOMAIN');
    -- Customize the signature that will appear in the email's MIME header
    gn_mailer_id               CONSTANT VARCHAR2 (256) := 'Mailer by Oracle UTL_SMTP';
    -- A unique string that demarcates boundaries of parts in a multi-part email
    gv_boundary                CONSTANT VARCHAR2 (256) := '-----7D81B75CCC90D2974F7A1CBD';
    gv_first_boundary          CONSTANT VARCHAR2 (256)
                                            := '--' || gv_boundary || UTL_TCP.crlf ;
    gv_last_boundary           CONSTANT VARCHAR2 (256)
        := '--' || gv_boundary || '--' || UTL_TCP.crlf ;
    -- A MIME type that denotes multi-part email (MIME) messages.
    gv_multipart_mime_type     CONSTANT VARCHAR2 (256)
        := 'multipart/mixed; boundary="' || gv_boundary || '"' ;
    gi_max_base64_line_width   CONSTANT PLS_INTEGER := 76 / 4 * 3;

    FUNCTION get_address (pxv_addr_list IN OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_addr    VARCHAR2 (256);
        li_count   PLS_INTEGER;

        FUNCTION lookup_unquoted_char (pv_str    IN VARCHAR2,
                                       pv_chrs   IN VARCHAR2)
            RETURN PLS_INTEGER
        AS
            lv_char           VARCHAR2 (5);
            li_count1         PLS_INTEGER;
            li_len            PLS_INTEGER;
            lb_inside_quote   BOOLEAN;
        BEGIN
            lb_inside_quote   := FALSE;
            li_count1         := 1;
            li_len            := LENGTH (pv_str);

            WHILE (li_count1 <= li_len)
            LOOP
                lv_char     := SUBSTR (pv_str, li_count1, 1);

                IF (lb_inside_quote)
                THEN
                    IF (lv_char = '"')
                    THEN
                        lb_inside_quote   := FALSE;
                    ELSIF (lv_char = '\')
                    THEN
                        li_count1   := li_count1 + 1; -- Skip the quote character
                    END IF;

                    GOTO next_char;
                END IF;

                IF (lv_char = '"')
                THEN
                    lb_inside_quote   := TRUE;
                    GOTO next_char;
                END IF;

                IF (INSTR (pv_chrs, lv_char) >= 1)
                THEN
                    RETURN li_count1;
                END IF;

               <<NEXT_CHAR>>
                li_count1   := li_count1 + 1;
            END LOOP;

            RETURN 0;
        END;
    BEGIN
        pxv_addr_list   := LTRIM (pxv_addr_list);
        li_count        := lookup_unquoted_char (pxv_addr_list, ',;');

        IF (li_count >= 1)
        THEN
            lv_addr         := SUBSTR (pxv_addr_list, 1, li_count - 1);
            pxv_addr_list   := SUBSTR (pxv_addr_list, li_count + 1);
        ELSE
            lv_addr         := pxv_addr_list;
            pxv_addr_list   := '';
        END IF;

        li_count        := lookup_unquoted_char (lv_addr, '<');

        IF (li_count >= 1)
        THEN
            lv_addr    := SUBSTR (lv_addr, li_count + 1);
            li_count   := INSTR (lv_addr, '>');

            IF (li_count >= 1)
            THEN
                lv_addr   := SUBSTR (lv_addr, 1, li_count - 1);
            END IF;
        END IF;

        RETURN lv_addr;
    END get_address;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------
    -- Type  : Procedure        --
    -- Name       : WRITE_MIME_HEADER       --
    -- Purpose    : This function will write the MIME header for the    --
    --              attachment type         --
    -------------------------------------------------------------------------
    -- Parameter Name           Description      --
    -- -----------------------  ---------------------------------------------
    -- px_conn                   SMTP Connection      --
    -- pv_name                   'Content-Type'      --
    -- pv_value                  MIME Type      --
    --                                             --
    -- Modification History                                           --
    -------------------------------------------------------------------------
    -- Date      Developer      Version      Description                --
    -- ----------   -----------     ------------    -------------------------
    -- 01/17/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------
    PROCEDURE write_mime_header (px_conn IN OUT NOCOPY UTL_SMTP.connection, pv_name IN VARCHAR2, pv_value IN VARCHAR2)
    IS
    BEGIN
        UTL_SMTP.write_data (px_conn,
                             pv_name || ': ' || pv_value || UTL_TCP.crlf);
    END write_mime_header;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------
    -- Type  : Procedure        --
    -- Name       : WRITE_BOUNDARY       --
    -- Purpose    : Mark a message-part boundary      --
    --           --
    -------------------------------------------------------------------------
    -- Parameter Name           Description      --
    -- -----------------------  ---------------------------------------------
    -- px_conn                   SMTP Connection      --
    -- pb_last                   Set to TRUE for the last boundary   --
    --                                             --
    -- Modification History                                           --
    -------------------------------------------------------------------------
    -- Date      Developer      Version      Description                --
    -- ----------   -----------     ------------    -------------------------
    -- 01/17/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------
    PROCEDURE write_boundary (px_conn   IN OUT NOCOPY UTL_SMTP.connection,
                              pb_last   IN            BOOLEAN DEFAULT FALSE)
    AS
    BEGIN
        IF (pb_last)
        THEN
            UTL_SMTP.write_data (px_conn, gv_last_boundary);
        ELSE
            UTL_SMTP.write_data (px_conn, gv_first_boundary);
        END IF;
    END write_boundary;

    -------------------------------------------------------------------------
    -------------------------------------------------------------------------
    -- Type  : Procedure        --
    -- Name       : WRITE_TEXT        --
    -- Purpose    : Write text data to message      --
    --           --
    -------------------------------------------------------------------------
    -- Parameter Name           Description      --
    -- -----------------------  ---------------------------------------------
    -- px_conn                   SMTP Connection      --
    -- pv_message                Text data      --
    --                                             --
    -- Modification History                                           --
    -------------------------------------------------------------------------
    -- Date      Developer      Version      Description                --
    -- ----------   -----------     ------------    -------------------------
    -- 01/17/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------
    PROCEDURE write_text (px_conn      IN OUT NOCOPY UTL_SMTP.connection,
                          pv_message   IN            VARCHAR2)
    IS
    BEGIN
        UTL_SMTP.write_data (px_conn, pv_message);
    END write_text;

    -------------------------------------------------------------------------
    -------------------------------------------------------------------------
    -- Type     : Procedure        --
    -- Name  : WRITE_RAW        --
    -- Purpose    : Write raw data to message      --
    --           --
    -------------------------------------------------------------------------
    -- Parameter Name           Description      --
    -- -----------------------  ---------------------------------------------
    -- px_conn                   SMTP Connection      --
    -- pv_message                Raw data      --
    --                                             --
    -- Modification History                                           --
    -------------------------------------------------------------------------
    -- Date      Developer      Version      Description                --
    -- ----------   -----------     ------------    -------------------------
    -- 01/17/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------
    PROCEDURE write_raw (px_conn      IN OUT NOCOPY UTL_SMTP.connection,
                         pv_message   IN            RAW)
    IS
    BEGIN
        UTL_SMTP.write_raw_data (px_conn, pv_message);
    END write_raw;

    -------------------------------------------------------------------------
    -------------------------------------------------------------------------
    -- TYPE        : Function                                              --
    -- NAME        : Begin Session                                         --
    -- PARAMETERS  :          --
    -- PURPOSE     : To open the SMTP connection         --
    --                                             --
    -- Modification History                                           --
    -------------------------------------------------------------------------
    -- Date      Developer      Version      Description                --
    -- ----------   -----------     ------------    -------------------------
    -- 01/17/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------
    FUNCTION begin_session                                                  --
        RETURN UTL_SMTP.connection                                          --
    IS                                                                      --
        l_conn   UTL_SMTP.connection;                                       --
    BEGIN                                                                   --
        ---------------------------------       --
        -- Open SMTP Connection --        --
        --------------------------------       --
        l_conn   := UTL_SMTP.open_connection (gv_smtp_host, gv_smtp_port);  --
        UTL_SMTP.helo (l_conn, gv_smtp_domain);                             --
        RETURN l_conn;                                                      --
    END begin_session;                                                      --

    -------------------------------------------------------------------------
    -----------------------------------------------------------------------------------
    -- Type     : Procedure           --
    -- Name     : BEGIN_MAIL_IN_SESSION          --
    -- Purpose  : Write mail header          --
    --              --
    -----------------------------------------------------------------------------------
    -- Parameter Name           Description         --
    -- -----------------------  -------------------------------------------------------
    -- px_conn                   SMTP Connection         --
    -- pv_sender                 Sender of the email        --
    -- pv_recipients             Recipient list of the email separated by "," or ";" --
    -- pv_ccrecipients           CC Recipient list separated by "," or ";"      --
    -- pv_subject                Email subject         --
    -- pv_mime_type              MIME Type         --
    -- pi_priority               Email priority (1=High, 3=Normal, 5=Low)     --
    --                                                                               --
    -- Modification History                                                          --
    -----------------------------------------------------------------------------------
    -- Date      Developer      Version      Description                --
    -- ----------   -----------     ------------    -----------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version          --
    -----------------------------------------------------------------------------------
    PROCEDURE begin_mail_in_session (
        px_conn           IN OUT NOCOPY UTL_SMTP.connection,
        pv_sender         IN            VARCHAR2,
        pv_recipients     IN            VARCHAR2,
        pv_ccrecipients   IN            VARCHAR2,
        pv_subject        IN            VARCHAR2,
        pv_mime_type      IN            VARCHAR2 DEFAULT 'text/plain',
        pi_priority       IN            PLS_INTEGER DEFAULT NULL)
    IS
        lv_my_recipients     VARCHAR2 (32767) := pv_recipients;
        lv_my_sender         VARCHAR2 (32767) := pv_sender;
        lv_my_ccrecipients   VARCHAR2 (32767) := pv_ccrecipients;
    BEGIN
        UTL_SMTP.mail (px_conn, get_address (lv_my_sender));

        -- Specify recipient(s) of the email.
        WHILE (lv_my_recipients IS NOT NULL)
        LOOP
            UTL_SMTP.rcpt (px_conn, get_address (lv_my_recipients));
        END LOOP;

        -- Specify recipient(s) of the email.
        WHILE (lv_my_ccrecipients IS NOT NULL)
        LOOP
            UTL_SMTP.rcpt (px_conn, get_address (lv_my_ccrecipients));
        END LOOP;

        -- Start body of email
        UTL_SMTP.open_data (px_conn);
        -- Set "From" MIME header
        write_mime_header (px_conn, 'From', pv_sender);
        -- Set "To" MIME header
        write_mime_header (px_conn, 'To', pv_recipients);
        -- Set "CC" MIME header
        write_mime_header (px_conn, 'CC', pv_ccrecipients);
        -- Set "Subject" MIME header
        write_mime_header (px_conn, 'Subject', pv_subject);
        -- Set "Content-Type" MIME header
        write_mime_header (px_conn, 'Content-Type', pv_mime_type);
        -- Set "X-Mailer" MIME header
        write_mime_header (px_conn, 'X-Mailer', gn_mailer_id);

        -- Set priority:
        --   High      Normal       Low
        --   1     2     3     4     5
        IF (pi_priority IS NOT NULL)
        THEN
            write_mime_header (px_conn, 'X-Priority', pi_priority);
        END IF;

        -- Send an empty line to denote end of MIME header and
        -- beginning of message body.
        UTL_SMTP.write_data (px_conn, UTL_TCP.crlf);

        IF (pv_mime_type LIKE 'multipart/mixed%')
        THEN
            write_text (
                px_conn,
                'This is a multi-part message in MIME format.' || UTL_TCP.crlf);
        END IF;
    END begin_mail_in_session;

    -------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------
    -- TYPE      : Function                                                           --
    -- NAME      : BEGIN_MAIL                                                         --
    ------------------------------------------------------------------------------------
    -- Parameter Name           Description          --
    -- -----------------------  --------------------------------------------------------
    -- pv_sender                 Sender of the email         --
    -- pv_recipients             Recipient list of the email separated by "," or ";"  --
    -- pv_ccrecipients           CC Recipient list separated by "," or ";"        --
    -- pv_subject                Email subject          --
    -- pv_mime_type              MIME Type          --
    -- pi_priority               Email priority (1=High, 3=Normal, 5=Low)      --
    -- PURPOSE     : This procedure will be used as wrapper for begin_session         --
    --               and begin_mail_in_session              --
    --                                                                                --
    -- Modification History                                                           --
    ------------------------------------------------------------------------------------
    -- Date      Developer      Version      Description                 --
    -- ----------   -----------     ------------    ------------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version           --
    ------------------------------------------------------------------------------------
    FUNCTION begin_mail (pv_sender IN VARCHAR2, pv_recipients IN VARCHAR2, pv_ccrecipients IN VARCHAR2
                         , pv_subject IN VARCHAR2, pv_mime_type IN VARCHAR2 DEFAULT 'text/plain', pi_priority IN PLS_INTEGER DEFAULT NULL)
        RETURN UTL_SMTP.connection
    IS
        l_conn   UTL_SMTP.connection;
    BEGIN
        l_conn   := begin_session;
        begin_mail_in_session (l_conn, pv_sender, pv_recipients,
                               pv_ccrecipients, pv_subject, pv_mime_type,
                               pi_priority);
        RETURN l_conn;
    END begin_mail;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type  : Procedure       --
    -- Name  : BEGIN_ATTACHMENT      --
    -- Purpose    : Begin attachment by writing first boundary, setting filename --
    --          --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- p_conn                   SMTP Connection     --
    -- p_mime_type              MIME Type     --
    -- p_inline                 Attach inline, true/false   --
    -- p_filename               Attachment filename    --
    -- p_transfer_enc           Transfer encoding    --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE begin_attachment (
        px_conn           IN OUT NOCOPY UTL_SMTP.connection,
        pv_mime_type      IN            VARCHAR2 DEFAULT 'text/plain',
        pb_inline         IN            BOOLEAN DEFAULT TRUE,
        pv_filename       IN            VARCHAR2 DEFAULT NULL,
        pv_transfer_enc   IN            VARCHAR2 DEFAULT NULL)
    IS
    BEGIN
        write_boundary (px_conn);
        write_mime_header (px_conn, 'Content-Type', pv_mime_type);

        IF (pv_filename IS NOT NULL)
        THEN
            IF (pb_inline)
            THEN
                write_mime_header (
                    px_conn,
                    'Content-Disposition',
                    'inline; filename="' || pv_filename || '"');
            ELSE
                write_mime_header (
                    px_conn,
                    'Content-Disposition',
                    'attachment; filename="' || pv_filename || '"');
            END IF;
        END IF;

        IF (pv_transfer_enc IS NOT NULL)
        THEN
            write_mime_header (px_conn,
                               'Content-Transfer-Encoding',
                               pv_transfer_enc);
        END IF;

        UTL_SMTP.write_data (px_conn, UTL_TCP.crlf);
    END begin_attachment;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type  : Procedure       --
    -- Function   : END_ATTACHMENT      --
    -- Purpose    : End attachment by writing last boundary   --
    --          --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- px_conn                   SMTP Connection     --
    -- pb_last                   True if last boundary    --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE end_attachment (px_conn   IN OUT NOCOPY UTL_SMTP.connection,
                              pb_last   IN            BOOLEAN DEFAULT FALSE)
    IS
    BEGIN
        UTL_SMTP.write_data (px_conn, UTL_TCP.crlf);

        IF (pb_last)
        THEN
            write_boundary (px_conn, pb_last);
        END IF;
    END end_attachment;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type       : Procedure       --
    -- Name  : ATTACH_TEXT       --
    -- Purpose    : Wrapper for attaching text document    --
    --          --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- px_conn                   SMTP Connection     --
    -- pv_data                   Text data     --
    -- pv_mime_type              MIME Type     --
    -- pb_inline                 Attach inline,true/false   --
    -- pv_filename               Attachment filename    --
    -- pb_last                   True if last boundary    --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE attach_text (px_conn IN OUT NOCOPY UTL_SMTP.connection, pv_data IN VARCHAR2, pv_mime_type IN VARCHAR2 DEFAULT 'text/plain'
                           , pb_inline IN BOOLEAN DEFAULT TRUE, pv_filename IN VARCHAR2 DEFAULT NULL, pb_last IN BOOLEAN DEFAULT FALSE)
    IS
    BEGIN
        begin_attachment (px_conn, pv_mime_type, pb_inline,
                          pv_filename);
        write_text (px_conn, pv_data);
        end_attachment (px_conn, pb_last);
    END attach_text;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type       : Procedure       --
    -- Name  : END_MAIL_IN_SESSION             --
    -- Purpose    : Ends current session mail     --
    --          --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- px_conn                   SMTP Connection     --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE end_mail_in_session (px_conn IN OUT NOCOPY UTL_SMTP.connection)
    IS
    BEGIN
        UTL_SMTP.close_data (px_conn);
    END end_mail_in_session;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type       : Procedure       --
    -- Name  : END_SESSION              --
    -- Purpose    : Ends current session        --
    --          --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- px_conn                   SMTP Connection     --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE end_session (px_conn IN OUT NOCOPY UTL_SMTP.connection)
    IS
    BEGIN
        UTL_SMTP.quit (px_conn);
    END end_session;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type       : Procedure       --
    -- Name  : END_MAIL              --
    -- Purpose    : Wrapper for ending current session email   --
    --          --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- px_conn                   SMTP Connection     --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE end_mail (px_conn IN OUT NOCOPY UTL_SMTP.connection)
    IS
    BEGIN
        end_mail_in_session (px_conn);
        end_session (px_conn);
    END end_mail;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type  : Procedure       --
    -- Name  : SEND_MAIL       --
    -- Purpose    : Wrapper for sending email     --
    --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description
    -- -----------------------  ---------------------------------------------------
    -- pv_sender                SMTP Connection     --
    -- pv_recipients            Email recipient list, separated by "," or ";" --
    -- pv_ccrecipients          Email CC recipient list, separated by "," or ";" --
    -- pv_subject               Email subject     --
    -- pv_message               Email message text    --
    -- pv_attachments           Full path and filename for attachments, multiple --
    --                          separated by "," or ";"    --
    -- xv_result                SUCCESS/FAILURE result    --
    -- xv_result_msg            Result message     --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description            --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version      --
    -------------------------------------------------------------------------------
    PROCEDURE send_mail (pv_sender         IN     VARCHAR2,
                         pv_recipients     IN     VARCHAR2,
                         pv_ccrecipients   IN     VARCHAR2,
                         pv_subject        IN     VARCHAR2,
                         pv_message        IN     VARCHAR2,
                         pv_attachments    IN     VARCHAR2,
                         xv_result            OUT VARCHAR2,
                         xv_result_msg        OUT VARCHAR2)
    IS
        lv_mime_type           VARCHAR2 (500);
        l_conn                 UTL_SMTP.connection;
        lv_path                VARCHAR2 (3000);
        lv_filename            VARCHAR2 (800);
        lv_extension           VARCHAR2 (1000);
        lv_attachments         VARCHAR2 (1000);
        lv_next_attachment     VARCHAR2 (1000);
        lv_directory           VARCHAR2 (500);
        trec_read_file         UTL_FILE.file_type;
        lv_raw_data            RAW (32767);
        lv_chr_data            VARCHAR (4000);
        l_bfile                BFILE;
        li_amount              BINARY_INTEGER := gi_max_base64_line_width;
        li_offset              INTEGER := 1;
        le_invalid_directory   EXCEPTION;
        le_multi_directory     EXCEPTION;
        lv_operation_code      VARCHAR2 (2000);
    BEGIN
        lv_operation_code   := 'Calling begin_mail';
        --Start 2.0 CCR0009135
        gv_smtp_host        := NVL (gv_smtp_host, pv_smtp_host);
        gv_smtp_port        := NVL (gv_smtp_port, pv_smtp_port);
        gv_smtp_domain      := NVL (gv_smtp_domain, pv_smtp_domain);
        --End 2.0 CCR0009135
        l_conn              :=
            begin_mail (pv_sender         => pv_sender,
                        pv_recipients     => pv_recipients,
                        pv_ccrecipients   => pv_ccrecipients,
                        pv_subject        => pv_subject,
                        pv_mime_type      => gv_multipart_mime_type);
        lv_operation_code   := 'Calling attach_text';
        attach_text (px_conn        => l_conn,
                     pv_data        => pv_message,
                     pv_mime_type   => 'text/plain'              --'text/html'
                                                   );
        lv_attachments      := pv_attachments;

        --get first attachment file name
        WHILE lv_attachments IS NOT NULL
        LOOP
            lv_operation_code    := 'Calling get_address';
            lv_next_attachment   := get_address (lv_attachments);
            lv_operation_code    := 'Deriving filename';
            --determine type from extension
            lv_filename          :=
                SUBSTR (lv_next_attachment,
                          INSTR (lv_next_attachment, '/', -1,
                                 1)
                        + 1,
                          LENGTH (lv_next_attachment)
                        - INSTR (lv_next_attachment, '/', -1,
                                 1));
            lv_operation_code    := 'Deriving lv_path' || lv_next_attachment;
            lv_path              :=
                SUBSTR (lv_next_attachment,
                        1,
                          INSTR (lv_next_attachment, '/', -1,
                                 1)
                        - 1);
            lv_operation_code    :=
                'Deriving lv_extension ' || lv_next_attachment;
            lv_extension         :=
                SUBSTR (lv_next_attachment,
                          INSTR (lv_next_attachment, '.', -1,
                                 1)
                        + 1,
                          LENGTH (lv_next_attachment)
                        - INSTR (lv_next_attachment, '.', -1,
                                 1));
            --find directory
            lv_operation_code    := 'Validating directory path - ' || lv_path;

            BEGIN
                SELECT directory_name
                  INTO lv_directory
                  FROM all_directories
                 WHERE directory_path = lv_path AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT directory_name
                          INTO lv_directory
                          FROM all_directories
                         WHERE directory_name = lv_path;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            RAISE le_invalid_directory;
                    END;
                WHEN OTHERS
                THEN
                    RAISE le_multi_directory;
            END;

            --IF lv_extension IN ('xls', 'doc', 'docx', 'pdf')
            IF lv_extension IN ('xls', 'doc', 'docx',
                                'pdf', 'zip')   -- Added zip as per CCR0009404
            THEN
                IF lv_extension = 'xls'
                THEN
                    lv_mime_type   := 'application/excel';
                ELSIF lv_extension IN ('doc', 'docx')
                THEN
                    lv_mime_type   := 'application/word';
                ELSIF lv_extension = 'pdf'
                THEN
                    lv_mime_type   := 'application/pdf';
                --- Added as per CCR0009404
                ELSIF lv_extension = 'zip'
                THEN
                    lv_mime_type   := 'application/octet-stream';
                -- End of CCR0009404
                END IF;


                lv_operation_code   := 'Calling begin_attachment';
                begin_attachment (px_conn           => l_conn,
                                  pv_mime_type      => lv_mime_type,
                                  pb_inline         => TRUE,
                                  pv_filename       => lv_filename,
                                  pv_transfer_enc   => 'base64');

                ---------------------------------
                -- Writing base64 encoded text --
                ---------------------------------
                BEGIN
                    l_bfile             := BFILENAME (lv_directory, lv_filename);
                    lv_operation_code   := 'Calling DBMS_LOB.OPEN ';
                    DBMS_LOB.open (l_bfile, DBMS_LOB.file_readonly);

                    LOOP
                        DBMS_LOB.read (l_bfile, li_amount, li_offset,
                                       lv_raw_data);
                        write_raw (
                            px_conn   => l_conn,
                            pv_message   =>
                                UTL_ENCODE.base64_encode (lv_raw_data));
                        li_offset   := li_offset + li_amount;
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_LOB.close (l_bfile);
                END;

                DBMS_LOB.close (l_bfile);
                end_attachment (px_conn => l_conn);
            ELSE
                lv_operation_code   :=
                    'Calling begin_attachment for text/html ';
                begin_attachment (px_conn           => l_conn,
                                  pv_mime_type      => 'text/html',
                                  pb_inline         => TRUE,
                                  pv_filename       => lv_filename,
                                  pv_transfer_enc   => 'text');
                lv_operation_code   :=
                    'Before UTL_File.fopen' || lv_directory || lv_filename;
                trec_read_file      :=
                    UTL_FILE.fopen (lv_directory, lv_filename, 'R');
                lv_operation_code   := 'After UTL_File.fopen';

                BEGIN
                    LOOP
                        UTL_FILE.get_line (trec_read_file, lv_chr_data);
                        write_text (px_conn      => l_conn,
                                    pv_message   => lv_chr_data || CHR (13));
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        UTL_FILE.fclose (trec_read_file);
                END;

                UTL_FILE.fclose (trec_read_file);
                end_attachment (px_conn => l_conn);
            END IF;
        END LOOP;

        end_mail (px_conn => l_conn);
        xv_result           := 'SUCCESS';
        xv_result_msg       := NULL;
    EXCEPTION
        WHEN le_invalid_directory
        THEN
            xv_result   := 'FAILURE';
            xv_result_msg   :=
                'Invalid directory or directory path - ' || lv_path;
            end_mail (px_conn => l_conn);
        WHEN le_multi_directory
        THEN
            xv_result   := 'FAILURE';
            xv_result_msg   :=
                   'Multiple records defined for the directory path - '
                || lv_path;
            end_mail (px_conn => l_conn);
        WHEN OTHERS
        THEN
            xv_result   := 'FAILURE';
            xv_result_msg   :=
                   'Error in xxdo_mail_pkg.SEND_MAIL while '
                || lv_operation_code
                || '-'
                || SQLERRM;
            end_mail (px_conn => l_conn);
    END send_mail;

    -------------------------------------------------------------------------------
    -- Type     : Procedure                            --
    -- Name     : SEND_MAIL_AFTER_REQUEST                            --
    -- Purpose    : Wrapper for sending email after a request completes                 --
    --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description
    -- -----------------------  ---------------------------------------------------
    -- pv_sender                SMTP Connection                    --
    -- pv_recipients            Email recipient list, separated by "," or ";"    --
    -- pv_ccrecipients          Email CC recipient list, separated by "," or ";"    --
    -- pv_subject               Email subject                    --
    -- pv_message               Email message text                --
    -- pv_attachments           Full path and filename for attachments, multiple --
    --                          separated by "," or ";"                --
    -- pn_request_id         Request Id of the concurrent program after which send mail
    --                               will send email
    -- xv_result                SUCCESS/FAILURE result                --
    -- xv_result_msg            Result message                    --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description                  --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------------
    PROCEDURE send_mail_after_request (pv_sender IN VARCHAR2, pv_recipients IN VARCHAR2, pv_ccrecipients IN VARCHAR2, pv_subject IN VARCHAR2, pv_message IN VARCHAR2, pv_attachments IN VARCHAR2
                                       , pn_request_id IN NUMBER, xv_result OUT VARCHAR2, xv_result_msg OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        ln_request_id   NUMBER := 0;
    BEGIN
        ln_request_id   :=
            fnd_request.submit_request (
                application   => 'XXCMN',
                program       => 'XXCMN_SEND_EMAIL',
                description   => 'CMN Send Email CSHOW ERRORS',
                start_time    => SYSDATE,
                sub_request   => NULL,
                argument1     => pv_sender,
                argument2     => pv_recipients,
                argument3     => pv_ccrecipients,
                argument4     => pv_subject,
                argument5     => pv_message,
                argument6     => pv_attachments,
                argument7     => pn_request_id);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_result   := 'FAILURE';
            xv_result_msg   :=
                   'Error while submitting request - CMN Send Email Cexit :'
                || SQLERRM;
    END send_mail_after_request;

    -------------------------------------------------------------------------------
    -- Type     : Procedure                            --
    -- Name     : SEND_MAIL_AFTER_REQUEST                            --
    -- Purpose    : Wrapper for sending email after a request completes                 --
    --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description
    -- -----------------------  ---------------------------------------------------
    -- pv_sender                SMTP Connection                    --
    -- pv_recipients            Email recipient list, separated by "," or ";"    --
    -- pv_ccrecipients          Email CC recipient list, separated by "," or ";"    --
    -- pv_subject               Email subject                    --
    -- pv_message               Email message text                --
    -- pv_attachments           Full path and filename for attachments, multiple --
    --                          separated by "," or ";"                --
    -- pn_request_id         Request Id of the concurrent program after which send mail
    --                               will send email
    -- xv_result                SUCCESS/FAILURE result                --
    -- xv_result_msg            Result message                    --
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description                  --
    -- ----------   -----------     ------------    -------------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------------
    PROCEDURE send_mail_after_request (pv_sender IN VARCHAR2, pv_recipients IN VARCHAR2, pv_ccrecipients IN VARCHAR2, pv_subject IN VARCHAR2, pv_message IN VARCHAR2, pv_attachments IN VARCHAR2, pn_request_id IN NUMBER, pv_override_fn IN VARCHAR2 DEFAULT NULL, xv_result OUT VARCHAR2
                                       , xv_result_msg OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        ln_request_id   NUMBER := 0;
    BEGIN
        ln_request_id   :=
            fnd_request.submit_request (application => 'XXCMN', program => 'XXCMN_SEND_EMAIL', description => 'CMN Send Email CSHOW ERRORS', start_time => SYSDATE, sub_request => NULL, argument1 => pv_sender, argument2 => pv_recipients, argument3 => pv_ccrecipients, argument4 => pv_subject, argument5 => pv_message, argument6 => pv_attachments, argument7 => pn_request_id
                                        , argument8 => pv_override_fn);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_result   := 'FAILURE';
            xv_result_msg   :=
                   'Error while submitting request - CMN Send Email Cexit :'
                || SQLERRM;
    END send_mail_after_request;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type     : Procedure                            --
    -- Name     : SEND_EMAIL_WRAPPER                            --
    -- Purpose    : Wrapper for sending email                  --
    --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description
    -- -----------------------  ---------------------------------------------------
    -- xv_errbuf               Result message                 --
    -- xn_retcode            Result code                    --
    -- pv_sender                SMTP Connection                    --
    -- pv_recipients            Email recipient list, separated by "," or ";"    --
    -- pv_ccrecipients          Email CC recipient list, separated by "," or ";"    --
    -- pv_subject               Email subject                    --
    -- pv_message               Email message text                --
    -- pv_attachments           Full path and filename for attachments, multiple --
    --                          separated by "," or ";"                --
    -- pn_request_id         Request Id of the concurrent program after which send mail
    --                               will send email
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description                  --
    -- ----------   -----------     ------------    -------------------------------
    -- 03/15/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------------
    PROCEDURE send_email_wrapper (
        xv_errbuf             OUT VARCHAR2,
        xn_retcode            OUT NUMBER,
        pv_sender          IN     VARCHAR2,
        pv_recipients      IN     VARCHAR2,
        pv_ccrecipients    IN     VARCHAR2,
        pv_subject         IN     VARCHAR2,
        pv_message         IN     VARCHAR2,
        pv_attachments     IN     VARCHAR2,
        pn_request_id      IN     NUMBER,
        pv_override_file   IN     VARCHAR2 DEFAULT NULL)
    IS
        lv_phase            VARCHAR2 (1000);
        lv_status           VARCHAR2 (1000);
        lv_dev_phase        VARCHAR2 (1000);
        lv_dev_status       VARCHAR2 (1000);
        lv_message          VARCHAR2 (1000);
        lb_request_status   BOOLEAN;
        lv_result           VARCHAR2 (100);
        lv_filename         VARCHAR2 (1000);
        lv_path             VARCHAR2 (1000);
        lv_attachments      VARCHAR2 (1000);
        ln_loop             NUMBER := 0;
        lv_wait_time        fnd_profile_option_values.profile_option_value%TYPE
            := fnd_profile.VALUE ('XXCMN_WAIT_TIME');
        ex_beyond_time      EXCEPTION;
    BEGIN
        SELECT STATUS_CODE
          INTO lv_status
          FROM apps.fnd_concurrent_requests
         WHERE request_id = pn_request_id;

        xxdo_error_pkg.log_message (
               'The parent program request_id is : '
            || pn_request_id
            || CHR (10)
            || 'The parent program status is : '
            || lv_status
            || CHR (10)
            || 'pv_sender          is : '
            || pv_sender
            || CHR (10)
            || 'pv_recipients      is : '
            || pv_recipients
            || CHR (10)
            || 'pv_ccrecipients   is : '
            || pv_ccrecipients
            || CHR (10)
            || 'pv_subject         is : '
            || pv_subject
            || CHR (10)
            || 'pv_message       is : '
            || pv_message
            || CHR (10)
            || 'pv_attachments  is : '
            || pv_attachments,
            'LOG');
        lv_status        := NULL;

        IF pn_request_id IS NOT NULL
        THEN
            LOOP
                ln_loop   := ln_loop + 1;
                lb_request_status   :=
                    fnd_concurrent.wait_for_request (pn_request_id,
                                                     30,
                                                     30,
                                                     lv_phase,
                                                     lv_status,
                                                     lv_dev_phase,
                                                     lv_dev_status,
                                                     lv_message);
                --commit;
                xxdo_error_pkg.log_message (
                       'The parent program phase is : '
                    || lv_dev_phase
                    || CHR (10)
                    || 'The parent program status is : '
                    || lv_dev_status
                    || CHR (10)
                    || fnd_date.date_to_canonical (SYSDATE),
                    'LOG');

                IF UPPER (lv_dev_phase) = 'COMPLETE'
                THEN
                    EXIT;
                END IF;

                IF ln_loop * 0.5 >= lv_wait_time
                THEN
                    xxdo_error_pkg.log_message (
                           'Wait the parent program: '
                        || pn_request_id
                        || ' '
                        || ln_loop * 0.5
                        || ' minutes, beyond the wait time limitation: '
                        || lv_wait_time
                        || ' minutes'
                        || CHR (10)
                        || 'The parent program status is : '
                        || lv_status
                        || CHR (10)
                        || 'pv_sender          is : '
                        || pv_sender
                        || CHR (10)
                        || 'pv_recipients      is : '
                        || pv_recipients
                        || CHR (10)
                        || 'pv_ccrecipients   is : '
                        || pv_ccrecipients
                        || CHR (10)
                        || 'pv_subject         is : '
                        || pv_subject
                        || CHR (10)
                        || 'pv_message       is : '
                        || pv_message
                        || CHR (10)
                        || 'pv_attachments  is : '
                        || pv_attachments,
                        'LOG');
                    RAISE ex_beyond_time;
                END IF;
            END LOOP;
        END IF;

        lv_attachments   := pv_attachments;

        IF pv_override_file IS NOT NULL
        THEN
            lv_filename   :=
                SUBSTR (lv_attachments,
                          INSTR (lv_attachments, '/', -1,
                                 1)
                        + 1,
                          LENGTH (lv_attachments)
                        - INSTR (lv_attachments, '/', -1,
                                 1));
            lv_path   :=
                SUBSTR (lv_attachments,
                        1,
                          INSTR (lv_attachments, '/', -1,
                                 1)
                        - 1);
            UTL_FILE.fcopy (src_location => lv_path, src_filename => lv_filename, dest_location => fnd_profile.VALUE ('XXCMN_TRACE_DIR')
                            , dest_filename => pv_override_file);
            lv_attachments   :=
                   fnd_profile.VALUE ('XXCMN_TRACE_DIR')
                || '/'
                || pv_override_file;
        END IF;

        send_mail (pv_sender => pv_sender, pv_recipients => pv_recipients, pv_ccrecipients => pv_ccrecipients, pv_subject => pv_subject, pv_message => pv_message, pv_attachments => lv_attachments
                   , xv_result => lv_result, xv_result_msg => xv_errbuf);

        IF lv_result = 'FAILURE'
        THEN
            xn_retcode   := 1;
            RETURN;
        END IF;
    EXCEPTION
        WHEN ex_beyond_time
        THEN
            xv_errbuf    :=
                'The parenent program run time beyond the limitation.';
            xn_retcode   := 1;
        WHEN OTHERS
        THEN
            xv_errbuf    := SQLERRM;
            xn_retcode   := 2;
    END send_email_wrapper;
END xxdo_mail_pkg;
/
