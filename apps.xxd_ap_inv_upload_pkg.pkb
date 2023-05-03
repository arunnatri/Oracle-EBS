--
-- XXD_AP_INV_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_INV_UPLOAD_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_AP_INV_UPLOAD_PKG
    REPORT NAME    : Deckers AP Invoice Inbound from Pagero

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    16-NOV-2021     Laltu Sah                 1.0         Created this package using XXD_AP_INV_UPLOAD_PKG to load the
                                                          AP Invoices into staging table from Pagero and process them.
    16-JUL-2022     Laltu Sah                 1.1         CCR0009935
    *********************************************************************************************/

    g_reprocess_period   NUMBER := 1000;

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'XXD_UTL_FILE_LIST.getList( java.lang.String )' ;

    PROCEDURE move_file (p_mode     VARCHAR2,
                         p_source   VARCHAR2,
                         p_target   VARCHAR2)
    AS
        ln_req_id        NUMBER;
        lv_phase         VARCHAR2 (100);
        lv_status        VARCHAR2 (30);
        lv_dev_phase     VARCHAR2 (100);
        lv_dev_status    VARCHAR2 (100);
        lb_wait_req      BOOLEAN;
        lv_message       VARCHAR2 (4000);
        l_mode_disable   VARCHAR2 (10);
    BEGIN
        write_log_prc (
               'Move files Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        IF p_mode <> 'REMOVE'
        THEN
            l_mode_disable   := '2';
        END IF;

        ln_req_id   :=
            fnd_request.submit_request (application   => 'XXDO',
                                        program       => 'XXDO_CP_MV_RM_FILE',
                                        argument1     => p_mode,
                                        argument2     => l_mode_disable,
                                        argument3     => p_source,
                                        argument4     => p_target,
                                        start_time    => SYSDATE,
                                        sub_request   => FALSE);

        COMMIT;

        IF ln_req_id > 0
        THEN
            write_log_prc (
                'Move Files concurrent request submitted successfully.');
            lb_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => ln_req_id, INTERVAL => 5, phase => lv_phase, status => lv_status, dev_phase => lv_dev_phase, dev_status => lv_dev_status
                                                 , MESSAGE => lv_message);

            IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
            THEN
                write_log_prc (
                       'Move Files concurrent request with the request id '
                    || ln_req_id
                    || ' completed with NORMAL status.');
            ELSE
                write_log_prc (
                       'Move Files concurrent request with the request id '
                    || ln_req_id
                    || ' did not complete with NORMAL status.');
            END IF;
        ELSE
            write_log_prc (
                ' Unable to submit move files concurrent program ');
        END IF;

        COMMIT;
        write_log_prc (
            'Move Files Ends...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Error in Move Files -' || SQLERRM);
    END move_file;

    -- Start added for CCR0009935

    FUNCTION file_to_blob (p_dir IN VARCHAR2, p_filename IN VARCHAR2)
        RETURN BLOB
    AS
        lv_bfile   BFILE;
        lv_blob    BLOB;
    BEGIN
        DBMS_LOB.createtemporary (lv_blob, FALSE);
        lv_bfile   := BFILENAME (p_dir, p_filename);
        DBMS_LOB.fileopen (lv_bfile, DBMS_LOB.file_readonly);
        DBMS_LOB.loadfromfile (lv_blob,
                               lv_bfile,
                               DBMS_LOB.getlength (lv_bfile));
        DBMS_LOB.fileclose (lv_bfile);
        RETURN lv_blob;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF DBMS_LOB.fileisopen (lv_bfile) = 1
            THEN
                DBMS_LOB.fileclose (lv_bfile);
            END IF;

            DBMS_LOB.freetemporary (lv_blob);
            RETURN EMPTY_BLOB ();
    END file_to_blob;

    PROCEDURE ap_invoice_attach_file (p_invoice_id NUMBER, p_description VARCHAR2, p_file_name VARCHAR2, p_title VARCHAR2, p_dir VARCHAR2, x_err_status OUT NOCOPY VARCHAR2
                                      , x_err_message OUT NOCOPY VARCHAR2)
    IS
        ln_attach_seq      NUMBER := 0;
        lv_file_id         NUMBER;
        lv_mime_type       fnd_lobs.file_content_type%TYPE := 'application/pdf';
        lc_status          VARCHAR2 (100);
        lc_error_message   VARCHAR2 (1000);
        lb_blob_content    BLOB;
        l_category_id      NUMBER;
    BEGIN
        lc_status          := 'S';
        lc_error_message   := NULL;

        BEGIN
            SELECT NVL (MAX (seq_num), 0) + 10
              INTO ln_attach_seq
              FROM apps.fnd_attached_documents
             WHERE entity_name = 'AP_INVOICES' AND pk1_value = p_invoice_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_attach_seq   := 10;
        END;

        lb_blob_content    :=
            file_to_blob (p_dir => p_dir, p_filename => p_file_name);
        SAVEPOINT before_document;

        BEGIN
            SELECT apps.fnd_lobs_s.NEXTVAL INTO lv_file_id FROM DUAL;
        END;

        BEGIN
            SELECT category_id
              INTO l_category_id
              FROM fnd_document_categories_tl
             WHERE     UPPER (user_name) = 'FROM PAGERO'
                   AND language = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_status   := 'E';
                lc_error_message   :=
                    lc_error_message || '-' || 'File category not Valid';
                ROLLBACK TO before_document;
        END;

        IF DBMS_LOB.getlength (lb_blob_content) > 0
        THEN
            BEGIN
                INSERT INTO fnd_lobs (file_id, file_name, file_content_type,
                                      upload_date, expiration_date, program_name, program_tag, file_data, language
                                      , oracle_charset, file_format)
                     VALUES (lv_file_id, p_file_name, lv_mime_type,
                             SYSDATE, NULL, NULL,
                             NULL, lb_blob_content, 'US',
                             'UTF8', 'binary');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_status   := 'E';
                    lc_error_message   :=
                           lc_error_message
                        || '-'
                        || 'Lobs Exception - '
                        || SUBSTR (SQLERRM, 1, 3950);

                    ROLLBACK TO before_document;
            END;

            IF lc_status <> 'E'
            THEN
                BEGIN
                    fnd_webattch.add_attachment (
                        seq_num                => ln_attach_seq,
                        category_id            => l_category_id,
                        document_description   => p_description,
                        datatype_id            => 6,
                        text                   => NULL,
                        file_name              => p_file_name,
                        url                    => NULL,
                        function_name          => 'APXINWKB',
                        entity_name            => 'AP_INVOICES',
                        pk1_value              => p_invoice_id,
                        pk2_value              => NULL,
                        pk3_value              => NULL,
                        pk4_value              => NULL,
                        pk5_value              => NULL,
                        media_id               => lv_file_id,
                        user_id                => gn_user_id,
                        usage_type             => 'O',
                        title                  => p_title);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_status   := 'E';
                        lc_error_message   :=
                               lc_error_message
                            || '-'
                            || 'Attachment Exception - '
                            || SUBSTR (SQLERRM, 1, 3950);

                        ROLLBACK TO before_document;
                END;
            ELSE
                lc_status   := 'E';
                lc_error_message   :=
                    lc_error_message || '-' || 'File Data is empty';
                ROLLBACK TO before_document;
            END IF;
        ELSE
            lc_status   := 'E';
            lc_error_message   :=
                lc_error_message || '-' || 'File Data is empty1';
            ROLLBACK TO before_document;
        END IF;

        x_err_status       := lc_status;
        x_err_message      := lc_error_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_message   := SQLERRM;
            x_err_status    := 'E';
    END ap_invoice_attach_file;

    PROCEDURE attach_file (pv_file_name VARCHAR2, pv_dir VARCHAR2, pv_directory_path VARCHAR2
                           , pv_arc_directory_path VARCHAR2, pv_reprocess_flag VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        CURSOR get_attach_file_cur (c_file_name VARCHAR2)
        IS
              SELECT filename
                FROM xxd_utl_file_upload_gt
               WHERE     1 = 1
                     AND UPPER (filename) NOT LIKE UPPER ('%ARCHIVE%')
                     AND UPPER (filename) NOT LIKE '%.CSV'
                     AND UPPER (filename) LIKE UPPER (c_file_name) || '%'
            ORDER BY filename;

        CURSOR c_invoice_cur IS
            SELECT DISTINCT invoice_id
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     1 = 1
                   AND UPPER (file_name) = UPPER (pv_file_name)
                   AND request_id = gn_request_id
                   AND invoice_id IS NOT NULL;

        l_attach_file_name            VARCHAR2 (1000);
        l_err_status                  VARCHAR2 (100);
        l_err_message                 VARCHAR2 (1000);
        l_inv_cnt                     NUMBER;
        l_dd_inv_cnt                  NUMBER;
        lv_vendor_name                VARCHAR2 (1000);
        ln_invoice_amount             NUMBER;
        lv_invoice_number             VARCHAR2 (1000);
        lv_dd_attach_directory_path   VARCHAR2 (1000);
        l_file_flag                   VARCHAR2 (10) := 'N';
    BEGIN
        IF pv_reprocess_flag = 'Y'
        THEN
            get_file_names (pv_arc_directory_path);
        END IF;

        write_log_prc ('Start Attach file-');
        l_attach_file_name   :=
            SUBSTR (pv_file_name, 1, INSTR (pv_file_name, '.') - 1);

        BEGIN
            SELECT COUNT (*)
              INTO l_inv_cnt
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     1 = 1
                   AND UPPER (file_name) = UPPER (pv_file_name)
                   AND request_id = gn_request_id
                   AND invoice_id IS NOT NULL
                   AND status <> gc_dd_reported;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_inv_cnt   := 0;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO l_dd_inv_cnt
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     1 = 1
                   AND UPPER (file_name) = UPPER (pv_file_name)
                   AND request_id = gn_request_id
                   AND status = gc_dd_reported;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_dd_inv_cnt   := 0;
        END;

        write_log_prc ('pv_file_name file-' || pv_file_name);
        write_log_prc ('gn_request_id file-' || gn_request_id);
        write_log_prc ('pv_file_name file-' || pv_file_name);
        write_log_prc ('l_inv_cnt file-' || l_inv_cnt);
        write_log_prc ('l_dd_inv_cnt file-' || l_dd_inv_cnt);

        FOR c_rec IN get_attach_file_cur (l_attach_file_name)
        LOOP
            l_file_flag   := 'Y';

            IF l_dd_inv_cnt = 0
            THEN
                FOR c_inv_rec IN c_invoice_cur
                LOOP
                    l_err_status    := NULL;
                    l_err_message   := NULL;
                    ap_invoice_attach_file (p_invoice_id => c_inv_rec.invoice_id, p_description => c_rec.filename, p_file_name => c_rec.filename, p_title => c_rec.filename, p_dir => pv_dir, x_err_status => l_err_status
                                            , x_err_message => l_err_message);

                    write_log_prc ('File name -' || c_rec.filename);
                    write_log_prc ('l_err_status -' || l_err_status);
                    write_log_prc ('l_err_message -' || l_err_message);

                    IF l_err_status <> 'S'
                    THEN
                        UPDATE xxdo.xxd_ap_inv_upload_stg_t
                           SET error_msg = error_msg || '-Missing attachment-' || l_err_message
                         WHERE     1 = 1
                               AND UPPER (file_name) = UPPER (pv_file_name)
                               AND request_id = gn_request_id
                               AND invoice_id = c_inv_rec.invoice_id;
                    END IF;
                END LOOP;

                IF l_inv_cnt > 0
                THEN
                    IF pv_reprocess_flag = 'Y'
                    THEN
                        move_file (
                            p_mode     => 'REMOVE',
                            p_source   =>
                                pv_arc_directory_path || '/' || c_rec.filename,
                            p_target   => NULL);
                    ELSE
                        move_file (
                            p_mode     => 'REMOVE',
                            p_source   => pv_directory_path || '/' || c_rec.filename,
                            p_target   => NULL);
                    END IF;
                ELSE
                    move_file (
                        p_mode     => 'MOVE',
                        p_source   => pv_directory_path || '/' || c_rec.filename,
                        p_target   => pv_arc_directory_path || '/' || c_rec.filename);
                END IF;
            ELSE
                BEGIN
                    lv_dd_attach_directory_path   := NULL;

                    SELECT directory_path
                      INTO lv_dd_attach_directory_path
                      FROM dba_directories
                     WHERE     1 = 1
                           AND directory_name LIKE 'XXD_AP_INV_SDI_DD_DIR';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_dd_attach_directory_path   := NULL;
                END;

                BEGIN
                    lv_vendor_name      := NULL;
                    ln_invoice_amount   := NULL;
                    lv_invoice_number   := NULL;

                    SELECT DISTINCT asp.vendor_name, stg.invoice_amount, stg.invoice_number
                      INTO lv_vendor_name, ln_invoice_amount, lv_invoice_number
                      FROM ap_suppliers asp, xxdo.xxd_ap_inv_upload_stg_t stg
                     WHERE     1 = 1
                           AND stg.vendor_id = asp.vendor_id
                           AND UPPER (stg.file_name) = UPPER (pv_file_name)
                           AND stg.request_id = gn_request_id
                           AND stg.status = gc_dd_reported;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_vendor_name      := NULL;
                        ln_invoice_amount   := NULL;
                        lv_invoice_number   := NULL;
                END;

                move_file (
                    p_mode     => 'MOVE',
                    p_source   => pv_directory_path || '/' || c_rec.filename,
                    p_target   =>
                           lv_dd_attach_directory_path
                        || '/'
                        || lv_vendor_name
                        || '_'
                        || ln_invoice_amount
                        || '_'
                        || lv_invoice_number
                        || '_'
                        || c_rec.filename);
            END IF;
        END LOOP;

        IF l_file_flag = 'N'
        THEN
            UPDATE xxdo.xxd_ap_inv_upload_stg_t
               SET error_msg   = error_msg || '- Attachment file Missing'
             WHERE     1 = 1
                   AND UPPER (file_name) = UPPER (pv_file_name)
                   AND request_id = gn_request_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Error in attach_file: ' || SQLERRM;
            write_log_prc (x_ret_msg);
    END attach_file;

    --end CCR0009935

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END xxd_remove_junk_fnc;

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in write_log_prc Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_desc   VARCHAR2 (240);
    BEGIN
        SELECT description
          INTO l_desc
          FROM apps.fnd_lookup_values
         WHERE     lookup_code = p_rejection_code
               AND lookup_type = 'REJECT CODE'
               AND language = USERENV ('LANG');

        RETURN l_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_error_desc;

    PROCEDURE load_file_into_tbl_prc (
        pv_table                IN     VARCHAR2,
        pv_dir                  IN     VARCHAR2 DEFAULT 'XXD_AP_INV_UPLOAD_INB_DIR',
        pv_filename             IN     VARCHAR2,
        pv_ignore_headerlines   IN     INTEGER DEFAULT 1,
        pv_delimiter            IN     VARCHAR2 DEFAULT ',',
        pv_optional_enclosed    IN     VARCHAR2 DEFAULT '"',
        pv_num_of_columns       IN     NUMBER,
        x_ret_status               OUT VARCHAR2)
    IS
        l_input         UTL_FILE.file_type;
        l_lastline      VARCHAR2 (4000);
        l_cnames        VARCHAR2 (4000);
        l_bindvars      VARCHAR2 (4000);
        l_status        INTEGER;
        l_cnt           NUMBER DEFAULT 0;
        l_rowcount      NUMBER DEFAULT 0;
        l_sep           CHAR (1) DEFAULT NULL;
        l_errmsg        VARCHAR2 (4000);
        v_eof           BOOLEAN := FALSE;
        l_thecursor     NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert        VARCHAR2 (1100);
        l_load_status   VARCHAR2 (10) := 'S';
    BEGIN
        write_log_prc ('Load Data Process Begins...');
        l_cnt           := 0;
        l_load_status   := 'S';

        BEGIN
            FOR tab_columns
                IN (  SELECT column_name, data_type
                        FROM all_tab_columns
                       WHERE     1 = 1
                             AND table_name = pv_table
                             AND column_id <= pv_num_of_columns
                    ORDER BY column_id)
            LOOP
                l_cnt      := l_cnt + 1;
                l_cnames   := l_cnames || tab_columns.column_name || ',';
                l_bindvars   :=
                       l_bindvars
                    || CASE
                           WHEN tab_columns.data_type IN
                                    ('DATE', 'TIMESTAMP(6)')
                           THEN
                               ':b' || l_cnt || ','
                           ELSE
                               ':b' || l_cnt || ','
                       END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_load_status   := 'E';
        END;

        BEGIN
            l_cnames     := RTRIM (l_cnames, ',');
            l_bindvars   := RTRIM (l_bindvars, ',');
            write_log_prc ('Count of Columns is - ' || l_cnt);
            l_input      := UTL_FILE.fopen (pv_dir, pv_filename, 'r');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_load_status   := 'E';
        END;

        BEGIN
            IF pv_ignore_headerlines > 0
            THEN
                BEGIN
                    FOR i IN 1 .. pv_ignore_headerlines
                    LOOP
                        write_log_prc ('No of lines Ignored is - ' || i);
                        UTL_FILE.get_line (l_input, l_lastline);
                    END LOOP;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_eof   := TRUE;
                END;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_load_status   := 'E';
        END;

        BEGIN
            v_insert   :=
                   'insert into '
                || pv_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')';

            IF NOT v_eof
            THEN
                write_log_prc (
                       l_thecursor
                    || '-'
                    || 'insert into '
                    || pv_table
                    || '('
                    || l_cnames
                    || ') values ('
                    || l_bindvars
                    || ')');

                DBMS_SQL.parse (l_thecursor, v_insert, DBMS_SQL.native);

                LOOP
                    BEGIN
                        UTL_FILE.get_line (l_input, l_lastline);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            EXIT;
                    END;

                    IF LENGTH (l_lastline) > 0
                    THEN
                        FOR i IN 1 .. l_cnt
                        LOOP
                            DBMS_SQL.bind_variable (
                                l_thecursor,
                                ':b' || i,
                                xxd_remove_junk_fnc (
                                    RTRIM (
                                        RTRIM (
                                            LTRIM (
                                                LTRIM (REGEXP_SUBSTR (REPLACE (l_lastline, '||', '~~'), '(.*?)(~~|$)', 1
                                                                      , i),
                                                       '~~'),
                                                pv_optional_enclosed),
                                            '~~'),
                                        pv_optional_enclosed)));
                        END LOOP;

                        BEGIN
                            l_status     := DBMS_SQL.execute (l_thecursor);
                            l_rowcount   := l_rowcount + 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_errmsg        := SQLERRM;
                                write_log_prc (
                                       'Exception in executing cursor: '
                                    || l_errmsg);
                                l_load_status   := 'E';
                        END;
                    END IF;
                END LOOP;

                DBMS_SQL.close_cursor (l_thecursor);
                UTL_FILE.fclose (l_input);

                UPDATE xxdo.xxd_ap_inv_upload_stg_t
                   SET file_name = pv_filename, request_id = gn_request_id, creation_date = SYSDATE,
                       last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                       inv_source = 'SDI', status = 'N'
                 WHERE 1 = 1 AND file_name IS NULL AND request_id IS NULL;

                COMMIT;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_load_status   := 'E';
        END;

        IF l_load_status = 'E'
        THEN
            DELETE FROM xxdo.xxd_ap_inv_upload_stg_t
                  WHERE file_name = pv_filename;

            COMMIT;
        END IF;

        x_ret_status    := l_load_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Exception in load_file_into_tbl_prc: ' || SQLERRM);
            l_load_status   := 'E';
            x_ret_status    := l_load_status;
    END load_file_into_tbl_prc;

    PROCEDURE clear_int_tables (pv_in_filename IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        --Delete Invoice Line rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICE_LINES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoice_lines_interface apl, apps.ap_invoices_interface api
                         WHERE     apl.invoice_line_id = apr.parent_id
                               AND api.invoice_id = apl.invoice_id
                               AND api.source IN ('SDI')
                               AND EXISTS
                                       (SELECT 1
                                          FROM xxdo.xxd_ap_inv_upload_stg_t stg
                                         WHERE     stg.file_name =
                                                   pv_in_filename
                                               AND stg.request_id =
                                                   gn_request_id
                                               AND stg.invoice_number =
                                                   api.invoice_num
                                               AND stg.org_id = api.org_id));

        --Delete Invoice rejections

        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoices_interface api
                         WHERE     api.invoice_id = apr.parent_id
                               AND api.source IN ('SDI')
                               AND EXISTS
                                       (SELECT 1
                                          FROM xxdo.xxd_ap_inv_upload_stg_t stg
                                         WHERE     stg.file_name =
                                                   pv_in_filename
                                               AND stg.request_id =
                                                   gn_request_id
                                               AND stg.invoice_number =
                                                   api.invoice_num
                                               AND stg.org_id = api.org_id));

        --Delete Invoice lines interface

        DELETE apps.ap_invoice_lines_interface lint
         WHERE EXISTS
                   (SELECT 1
                      FROM apps.ap_invoices_interface api
                     WHERE     api.invoice_id = lint.invoice_id
                           AND api.source IN ('SDI')
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_ap_inv_upload_stg_t stg
                                     WHERE     stg.file_name = pv_in_filename
                                           AND stg.request_id = gn_request_id
                                           AND stg.invoice_number =
                                               api.invoice_num
                                           AND stg.org_id = api.org_id));

        --Delete Invoices interface

        DELETE apps.ap_invoices_interface api
         WHERE     1 = 1
               AND api.source IN ('SDI')
               AND EXISTS
                       (SELECT 1
                          FROM xxdo.xxd_ap_inv_upload_stg_t stg
                         WHERE     stg.file_name = pv_in_filename
                               AND stg.request_id = gn_request_id
                               AND stg.invoice_number = api.invoice_num
                               AND stg.org_id = api.org_id);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END clear_int_tables;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN VARCHAR2
    IS
        l_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoice_lines_all
         WHERE invoice_id = p_invoice_id AND line_number = p_line_number;

        IF l_count = 1
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END is_line_created;

    FUNCTION is_invoice_created (p_org_id           IN     NUMBER,
                                 p_invoice_num      IN     VARCHAR2,
                                 p_vendor_id        IN     NUMBER,
                                 p_vendor_site_id   IN     NUMBER,
                                 x_invoice_id          OUT NUMBER)
        RETURN VARCHAR2
    IS
        l_invoice_id   NUMBER := 0;
    BEGIN
        SELECT invoice_id
          INTO l_invoice_id
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND invoice_num = p_invoice_num
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND vendor_site_id = p_vendor_site_id;

        x_invoice_id   := l_invoice_id;
        RETURN 'Y';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_invoice_id   := NULL;
            RETURN 'N';
    END is_invoice_created;

    PROCEDURE load_interface (p_inv_hdr_grp_id NUMBER, pv_file_name VARCHAR2)
    IS
        l_err_msg   VARCHAR2 (2000);
    BEGIN
        BEGIN
            l_err_msg   := NULL;

            INSERT INTO apps.ap_invoices_interface (invoice_id, invoice_num, vendor_id, vendor_site_id, invoice_amount, description, source, org_id, terms_id, po_number, invoice_type_lookup_code, gl_date, invoice_date, invoice_currency_code, exchange_date, exchange_rate_type, created_by, creation_date, last_updated_by, last_update_date, GROUP_ID, attribute14, payment_method_code, control_amount
                                                    , attribute1)
                (SELECT DISTINCT inv_header_id, invoice_number, vendor_id,
                                 vendor_site_id, invoice_amount, SUBSTR (invoice_description, 1, 240),
                                 inv_source, org_id, terms_id,
                                 DECODE (po_hdr_include, 'N', NULL, po_number_hdr), transaction_type, gl_date,
                                 TO_DATE (invoice_date, 'DD-MON-YY'), invoice_currency_code, TO_DATE (invoice_date, 'DD-MON-YY') exchange_date,
                                 'Corporate', created_by, creation_date,
                                 last_updated_by, last_update_date, gn_request_id,
                                 file_name, payment_method_code, tax_control_amount,
                                 vendor_charge_tax
                   FROM xxdo.xxd_ap_inv_upload_stg_t
                  WHERE     UPPER (file_name) =
                            UPPER (NVL (pv_file_name, file_name))
                        AND request_id = gn_request_id
                        AND inv_hdr_grp_id = p_inv_hdr_grp_id
                        AND UPPER (line_type) <> 'TAX');

            INSERT INTO apps.ap_invoice_lines_interface (
                            invoice_id,
                            invoice_line_id,
                            line_number,
                            line_type_lookup_code,
                            quantity_invoiced,
                            unit_price,
                            amount,
                            accounting_date,
                            dist_code_combination_id,
                            ship_to_location_id,
                            description,
                            created_by,
                            creation_date,
                            last_updated_by,
                            last_update_date,
                            po_header_id,
                            po_line_id,
                            po_shipment_num,
                            asset_book_type_code,
                            asset_category_id,
                            assets_tracking_flag,
                            prorate_across_flag,
                            deferred_acctg_flag,
                            def_acctg_start_date,
                            def_acctg_end_date,
                            tax_classification_code)
                (SELECT inv_header_id, inv_line_id, ROWNUM,
                        UPPER (line_type), quantity_invoiced, unit_price,
                        line_amount, gl_date, dist_acct_id,
                        location_id, SUBSTR (line_description, 1, 240), created_by,
                        creation_date, last_updated_by, last_update_date,
                        po_header_id_line, po_line_id, 1,
                        NULL, NULL, NULL,
                        'N', NULL, NULL,
                        NULL, NULL
                   FROM xxdo.xxd_ap_inv_upload_stg_t
                  WHERE     UPPER (file_name) =
                            UPPER (NVL (pv_file_name, file_name))
                        AND request_id = gn_request_id
                        AND inv_hdr_grp_id = p_inv_hdr_grp_id
                        AND UPPER (line_type) <> 'TAX');

            UPDATE xxdo.xxd_ap_inv_upload_stg_t
               SET status   = gc_interfaced
             WHERE     UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND request_id = gn_request_id
                   AND inv_hdr_grp_id = p_inv_hdr_grp_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_err_msg   :=
                    'Error while loading into Interface table - ' || SQLERRM;

                UPDATE xxdo.xxd_ap_inv_upload_stg_t
                   SET status = gc_error_status, error_msg = l_err_msg
                 WHERE     UPPER (file_name) =
                           UPPER (NVL (pv_file_name, file_name))
                       AND request_id = gn_request_id
                       AND inv_hdr_grp_id = p_inv_hdr_grp_id;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (SQLERRM || 'load_interface');
    END load_interface;

    /*************************************************************************
    -- PROCEDURE validate_prc
    -- PURPOSE: This Procedure validate the recoreds present in staging table.
    ****************************************************************************/

    PROCEDURE validate_data (pv_file_name VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        ln_check                  NUMBER;
        l_status                  VARCHAR2 (10);
        l_err_msg                 VARCHAR2 (2000);
        l_vendor_id               NUMBER;
        l_vendor_site_id          NUMBER;
        l_gl_date                 DATE;
        l_terms_id                NUMBER;
        l_po_header_id_line       NUMBER;
        l_po_line_id              NUMBER;
        l_location_id             NUMBER;
        l_dist_acct_id            NUMBER;
        l_inv_header_id           NUMBER;
        l_inv_line_number         NUMBER;
        l_hold_flag               VARCHAR2 (10);
        l_track_as_asset          VARCHAR2 (10);
        l_pay_group_lookup_code   VARCHAR2 (100);
        l_asset_book              VARCHAR2 (100);
        l_pay_method              VARCHAR2 (200);
        l_sum_line_amt            NUMBER;
        l_vendor_charge_tax       NUMBER;
        l_inv_date                DATE;
        l_po_hdr_req              VARCHAR2 (10);
        l_po_hdr_header_id        NUMBER;
        l_vendor_site_po_chk      NUMBER;
        l_vendor_site_vat_chk     NUMBER;

        CURSOR c_inv_hdr IS
            SELECT DISTINCT po_number_hdr, invoice_number, org_id,
                            vendor_name, vendor_num, vendor_site_code,
                            invoice_date, invoice_amount, invoice_currency_code,
                            invoice_description, vendor_charged_tax, transaction_type,
                            vendor_vat_reg_num, tax_control_amount, inv_hdr_grp_id
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     request_id = gn_request_id
                   AND status = 'N'
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name));

        CURSOR c_inv_line (p_inv_hdr_grp_id NUMBER)
        IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_ap_inv_upload_stg_t stg
             WHERE     request_id = gn_request_id
                   AND status = 'N'
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND UPPER (line_type) <> 'TAX'
                   AND inv_hdr_grp_id = p_inv_hdr_grp_id;
    BEGIN
        write_log_prc ('Start validate_data');

        MERGE INTO xxdo.xxd_ap_inv_upload_stg_t a
             USING (SELECT ROWID,
                           DENSE_RANK ()
                               OVER (
                                   ORDER BY
                                       po_number_hdr, invoice_number, org_id,
                                       vendor_name, vendor_num, vendor_site_code,
                                       invoice_date, invoice_amount, invoice_currency_code,
                                       invoice_description, vendor_charged_tax, transaction_type,
                                       vendor_vat_reg_num, tax_control_amount) new_seq_num
                      FROM xxdo.xxd_ap_inv_upload_stg_t
                     WHERE     request_id = gn_request_id
                           AND status = 'N'
                           AND UPPER (file_name) =
                               UPPER (NVL (pv_file_name, file_name))) b
                ON (a.ROWID = b.ROWID)
        WHEN MATCHED
        THEN
            UPDATE SET a.inv_hdr_grp_id   = b.new_seq_num;

        COMMIT;

        BEGIN
            FOR c_inv_hdr_rec IN c_inv_hdr
            LOOP
                l_status                  := gc_validate_status;
                l_err_msg                 := NULL;
                l_vendor_id               := NULL;
                l_vendor_site_id          := NULL;
                l_gl_date                 := NULL;
                l_terms_id                := NULL;
                l_inv_header_id           := NULL;
                l_inv_line_number         := NULL;
                l_hold_flag               := 'N';
                l_pay_group_lookup_code   := NULL;
                l_asset_book              := NULL;
                l_pay_method              := NULL;
                l_sum_line_amt            := 0;
                l_inv_date                := NULL;
                l_po_hdr_req              := NULL;

                --Validate the Operating unit ID--
                BEGIN
                    ln_check   := NULL;

                    SELECT COUNT (*)
                      INTO ln_check
                      FROM hr_operating_units
                     WHERE organization_id = c_inv_hdr_rec.org_id;

                    IF ln_check <= 0
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'Operating Unit is not Valid';
                    END IF;
                END;

                --Validate the po_number_hdr and populate the vendor id and vendor site id--

                BEGIN
                    IF c_inv_hdr_rec.po_number_hdr IS NOT NULL
                    THEN
                        BEGIN
                            SELECT vendor_id, vendor_site_id, po_header_id,
                                   vendor_site_id vendor_site_po
                              INTO l_vendor_id, l_vendor_site_id, l_po_hdr_header_id, l_vendor_site_po_chk
                              FROM po_headers_all
                             WHERE     segment1 = c_inv_hdr_rec.po_number_hdr
                                   AND org_id = c_inv_hdr_rec.org_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_po_hdr_req   := 'N';
                                l_hold_flag    := 'Y';
                                l_err_msg      :=
                                       l_err_msg
                                    || ' - '
                                    || 'Invalid PO at header level';
                        END;
                    ELSE
                        l_po_hdr_req   := 'N';
                    END IF;
                END;

                -- populate the vendor id and vendor site id--

                BEGIN
                    --IF l_vendor_id IS NULL OR l_vendor_site_id IS NULL THEN
                    BEGIN
                        SELECT aps.vendor_id, assa.vendor_site_id, NVL (assa.terms_id, aps.terms_id),
                               assa.vendor_site_id vendor_site_vat
                          INTO l_vendor_id, l_vendor_site_id, l_terms_id, l_vendor_site_vat_chk
                          FROM ap_suppliers aps, ap_supplier_sites_all assa
                         WHERE     aps.vendor_id = assa.vendor_id
                               AND assa.org_id = c_inv_hdr_rec.org_id
                               AND (assa.vat_registration_num = c_inv_hdr_rec.vendor_vat_reg_num OR assa.vat_registration_num = c_inv_hdr_rec.vendor_num);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT aps.vendor_id, assa.vendor_site_id, NVL (assa.terms_id, aps.terms_id),
                                       assa.vendor_site_id vendor_site_vat
                                  INTO l_vendor_id, l_vendor_site_id, l_terms_id, l_vendor_site_vat_chk
                                  FROM ap_suppliers aps, ap_supplier_sites_all assa
                                 WHERE     aps.vendor_id = assa.vendor_id
                                       AND assa.org_id = c_inv_hdr_rec.org_id
                                       AND (aps.vat_registration_num = c_inv_hdr_rec.vendor_vat_reg_num OR aps.vat_registration_num = c_inv_hdr_rec.vendor_num);
                            EXCEPTION
                                WHEN TOO_MANY_ROWS
                                THEN
                                    BEGIN
                                        SELECT aps.vendor_id, assa.vendor_site_id, NVL (assa.terms_id, aps.terms_id),
                                               assa.vendor_site_id vendor_site_vat
                                          INTO l_vendor_id, l_vendor_site_id, l_terms_id, l_vendor_site_vat_chk
                                          FROM ap_suppliers aps, ap_supplier_sites_all assa
                                         WHERE     aps.vendor_id =
                                                   assa.vendor_id
                                               AND assa.org_id =
                                                   c_inv_hdr_rec.org_id
                                               AND (aps.vat_registration_num = c_inv_hdr_rec.vendor_vat_reg_num OR aps.vat_registration_num = c_inv_hdr_rec.vendor_num)
                                               AND assa.attribute_category =
                                                   'Default Supplier Site'
                                               AND assa.attribute1 = 'Y';
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_status   := gc_error_status;
                                            l_err_msg   :=
                                                   l_err_msg
                                                || ' - '
                                                || 'Invalid supplier, as Default site not define for Supplier Vat Registration Number';
                                    END;
                                WHEN OTHERS
                                THEN
                                    l_status   := gc_error_status;
                                    l_err_msg   :=
                                           l_err_msg
                                        || ' - '
                                        || 'Invalid supplier, for Supplier Vat Registration Number  ';
                            END;
                        WHEN TOO_MANY_ROWS
                        THEN
                            BEGIN
                                SELECT aps.vendor_id, assa.vendor_site_id, NVL (assa.terms_id, aps.terms_id),
                                       assa.vendor_site_id vendor_site_vat
                                  INTO l_vendor_id, l_vendor_site_id, l_terms_id, l_vendor_site_vat_chk
                                  FROM ap_suppliers aps, ap_supplier_sites_all assa
                                 WHERE     aps.vendor_id = assa.vendor_id
                                       AND assa.org_id = c_inv_hdr_rec.org_id
                                       AND (assa.vat_registration_num = c_inv_hdr_rec.vendor_vat_reg_num OR assa.vat_registration_num = c_inv_hdr_rec.vendor_num)
                                       AND assa.attribute_category =
                                           'Default Supplier Site'
                                       AND assa.attribute1 = 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_status   := gc_error_status;
                                    l_err_msg   :=
                                           l_err_msg
                                        || ' - '
                                        || 'Invalid supplier, as Default site not define for Supplier Site Vat Registration Number  ';
                            END;
                        WHEN OTHERS
                        THEN
                            l_status   := gc_error_status;
                            l_err_msg   :=
                                   l_err_msg
                                || ' - '
                                || 'Invalid supplier, for Supplier Vat Registration Number  ';
                    END;

                    --END IF;

                    IF l_vendor_site_vat_chk <> l_vendor_site_po_chk
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'Vendor Detail From PO and VAT Registration, are not matching.  ';
                    END IF;
                END;

                --Validate the Invoice Number--

                BEGIN
                    IF c_inv_hdr_rec.invoice_number IS NULL
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'Invoice Number Can not be null';
                    ELSE
                        BEGIN
                            ln_check   := NULL;

                            SELECT COUNT (*)
                              INTO ln_check
                              FROM ap_invoices_all
                             WHERE     invoice_num =
                                       c_inv_hdr_rec.invoice_number
                                   AND org_id = c_inv_hdr_rec.org_id
                                   AND vendor_id = l_vendor_id;

                            IF ln_check > 0
                            THEN
                                l_status   := gc_error_status;
                                l_err_msg   :=
                                    l_err_msg || ' - ' || 'Duplicate Invoice';
                            END IF;
                        END;
                    END IF;
                END;

                --Validate the Invoice Date--

                IF c_inv_hdr_rec.invoice_date IS NULL
                THEN
                    l_status   := gc_error_status;
                    l_err_msg   :=
                        l_err_msg || ' - ' || 'Invoice Date can not be null';
                END IF;

                --Validate the Invoice Currency--

                BEGIN
                    ln_check   := NULL;

                    SELECT COUNT (*)
                      INTO ln_check
                      FROM apps.fnd_currencies
                     WHERE     enabled_flag = 'Y'
                           AND UPPER (currency_code) =
                               UPPER (
                                   TRIM (c_inv_hdr_rec.invoice_currency_code));

                    IF ln_check = 0
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'Invoice Currency Code not Valid';
                    END IF;
                END;

                --Validate the Invoice Amount--

                BEGIN
                    IF NVL (c_inv_hdr_rec.invoice_amount, 0) = 0
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'Invoice Amount Can not be Null or 0';
                    END IF;
                END;

                --- Populate the GL Date-------

                BEGIN
                    SELECT SYSDATE
                      INTO l_gl_date
                      FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                     WHERE     gps.application_id = 200
                           AND gps.ledger_id = hou.set_of_books_id
                           AND hou.organization_id = c_inv_hdr_rec.org_id
                           AND SYSDATE BETWEEN gps.start_date
                                           AND gps.end_date
                           AND gps.closing_status = 'O';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            SELECT MIN (gps.start_date)
                              INTO l_gl_date
                              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                             WHERE     gps.application_id = 200
                                   AND gps.ledger_id = hou.set_of_books_id
                                   AND hou.organization_id =
                                       c_inv_hdr_rec.org_id
                                   AND gps.closing_status = 'O';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_status   := gc_error_status;
                                l_err_msg   :=
                                       l_err_msg
                                    || ' - '
                                    || 'GL Period not open with Current date or Any period not open';
                        END;
                    WHEN OTHERS
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'GL Period not open with Current date or Any period not open';
                END;

                --- Populate the Payment Terms-------

                BEGIN
                    IF l_terms_id IS NULL
                    THEN
                        BEGIN
                            SELECT terms_id
                              INTO l_terms_id
                              FROM ap_system_parameters_all
                             WHERE     org_id = c_inv_hdr_rec.org_id
                                   AND terms_id IS NOT NULL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_status   := gc_error_status;
                                l_err_msg   :=
                                       l_err_msg
                                    || ' - '
                                    || 'Unable to populate the Payment Terms';
                        END;
                    END IF;
                END;

                --- Validate the Line Type-------

                BEGIN
                    ln_check   := NULL;

                    SELECT COUNT (*)
                      INTO ln_check
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'INVOICE TYPE'
                           AND language = USERENV ('LANG')
                           AND enabled_flag = 'Y'
                           AND NVL (end_date_active, SYSDATE + 1) > SYSDATE
                           AND UPPER (TRIM (lookup_code)) =
                               UPPER (TRIM (c_inv_hdr_rec.transaction_type));

                    IF ln_check = 0
                    THEN
                        l_status   := gc_error_status;
                        l_err_msg   :=
                               l_err_msg
                            || ' - '
                            || 'Transaction Type is not Valid';
                    END IF;
                END;

                /*==================*/
                --Get Payment Method
                /*==================*/

                IF l_vendor_id IS NOT NULL AND l_vendor_site_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT ieppm.payment_method_code
                          INTO l_pay_method
                          FROM apps.ap_supplier_sites_all assa, apps.ap_suppliers sup, apps.iby_external_payees_all iepa,
                               apps.iby_ext_party_pmt_mthds ieppm
                         WHERE     sup.vendor_id = assa.vendor_id
                               AND assa.vendor_site_id =
                                   iepa.supplier_site_id
                               AND iepa.ext_payee_id = ieppm.ext_pmt_party_id
                               AND NVL (ieppm.inactive_date, SYSDATE + 1) >
                                   SYSDATE
                               AND ieppm.primary_flag = 'Y'
                               AND assa.pay_site_flag = 'Y'
                               AND assa.vendor_site_id = l_vendor_site_id
                               AND assa.org_id = c_inv_hdr_rec.org_id
                               AND sup.vendor_id = l_vendor_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT ibeppm.payment_method_code
                                  INTO l_pay_method
                                  FROM ap_suppliers sup, iby_external_payees_all ibep, iby_ext_party_pmt_mthds ibeppm
                                 WHERE     sup.party_id = ibep.payee_party_id
                                       AND ibeppm.ext_pmt_party_id =
                                           ibep.ext_payee_id
                                       AND ibep.supplier_site_id IS NULL
                                       AND ibeppm.primary_flag = 'Y'
                                       AND NVL (ibeppm.inactive_date,
                                                SYSDATE + 1) >
                                           SYSDATE
                                       AND sup.vendor_id = l_vendor_id;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    l_status   := gc_error_status;
                                    l_err_msg   :=
                                           l_err_msg
                                        || ' - '
                                        || ' Please check the Default Payment method code at Supplier';
                                WHEN OTHERS
                                THEN
                                    l_status   := gc_error_status;
                                    l_err_msg   :=
                                           l_err_msg
                                        || ' - '
                                        || 'Invalid Payment Method at Supplier: '
                                        || SQLERRM;
                            END;
                        WHEN TOO_MANY_ROWS
                        THEN
                            l_status   := gc_error_status;
                            l_err_msg   :=
                                   l_err_msg
                                || ' - '
                                || ' Multiple payment method codes exist with same name.';
                        WHEN OTHERS
                        THEN
                            l_status   := gc_error_status;
                            l_err_msg   :=
                                   l_err_msg
                                || ' - '
                                || 'Invalid Payment Method: '
                                || SQLERRM;
                    END;
                END IF;

                BEGIN
                    SELECT NVL (assa.pay_group_lookup_code, aps.pay_group_lookup_code)
                      INTO l_pay_group_lookup_code
                      FROM ap_suppliers aps, ap_supplier_sites_all assa
                     WHERE     aps.vendor_id = assa.vendor_id
                           AND assa.vendor_site_id = l_vendor_site_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_pay_group_lookup_code   := NULL;
                END;

                BEGIN
                    SELECT SUM (NVL (line_amount, 0))
                      INTO l_sum_line_amt
                      FROM xxdo.xxd_ap_inv_upload_stg_t
                     WHERE     inv_hdr_grp_id = c_inv_hdr_rec.inv_hdr_grp_id
                           AND UPPER (file_name) =
                               UPPER (NVL (pv_file_name, file_name))
                           AND request_id = gn_request_id
                           AND line_amount IS NOT NULL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_sum_line_amt   := 0;
                END;

                IF l_sum_line_amt - c_inv_hdr_rec.invoice_amount <> 0
                THEN
                    l_err_msg   :=
                           l_err_msg
                        || ' - '
                        || 'Invoice Amount and Line Total Amount Not Matching';
                END IF;

                UPDATE xxdo.xxd_ap_inv_upload_stg_t
                   SET error_msg   = l_err_msg
                 WHERE     inv_hdr_grp_id = c_inv_hdr_rec.inv_hdr_grp_id
                       AND UPPER (file_name) =
                           UPPER (NVL (pv_file_name, file_name))
                       AND request_id = gn_request_id;

                IF l_pay_group_lookup_code = 'DIRECTDEBIT'
                THEN
                    UPDATE xxdo.xxd_ap_inv_upload_stg_t
                       SET vendor_id = l_vendor_id, status = gc_dd_reported, error_msg = 'Direct Debit Invoice'
                     WHERE     inv_hdr_grp_id = c_inv_hdr_rec.inv_hdr_grp_id
                           AND UPPER (file_name) =
                               UPPER (NVL (pv_file_name, file_name))
                           AND request_id = gn_request_id;
                ELSE
                    FOR c_inv_line_rec
                        IN c_inv_line (c_inv_hdr_rec.inv_hdr_grp_id)
                    LOOP
                        l_po_header_id_line   := NULL;
                        l_po_line_id          := NULL;
                        l_location_id         := NULL;
                        l_dist_acct_id        := NULL;
                        l_track_as_asset      := 'N';
                        l_err_msg             := NULL;
                        l_inv_line_number     :=
                            NVL (l_inv_line_number, 0) + 1;



                        --- Validate the Line Type-------
                        BEGIN
                            ln_check   := NULL;

                            SELECT COUNT (*)
                              INTO ln_check
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type = 'INVOICE LINE TYPE'
                                   AND language = USERENV ('LANG')
                                   AND enabled_flag = 'Y'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND UPPER (TRIM (lookup_code)) =
                                       UPPER (
                                           TRIM (c_inv_line_rec.line_type));

                            IF ln_check = 0
                            THEN
                                l_status   := gc_error_status;
                                l_err_msg   :=
                                       l_err_msg
                                    || ' - '
                                    || 'Invoice Line Type not Valid';
                            END IF;
                        END;

                        --- Validate the PO and PO Line Number-------

                        IF UPPER (TRIM (c_inv_line_rec.line_type)) = 'ITEM'
                        THEN
                            BEGIN
                                IF (c_inv_line_rec.po_number_line IS NOT NULL OR c_inv_line_rec.po_line_number IS NOT NULL)
                                THEN
                                    BEGIN
                                        ln_check   := NULL;

                                        SELECT pla.po_header_id, pla.po_line_id, pda.code_combination_id
                                          INTO l_po_header_id_line, l_po_line_id, l_dist_acct_id
                                          FROM po_lines_all pla, po_headers_all pha, po_line_locations_all plla,
                                               po_distributions_all pda
                                         WHERE     pha.po_header_id =
                                                   pla.po_header_id
                                               AND pla.po_line_id =
                                                   plla.po_line_id
                                               AND plla.line_location_id =
                                                   pda.line_location_id
                                               AND plla.shipment_num = 1
                                               AND pda.distribution_num = 1
                                               AND pha.segment1 =
                                                   c_inv_line_rec.po_number_line
                                               AND pla.line_num =
                                                   NVL (
                                                       c_inv_line_rec.po_line_number,
                                                       1)
                                               AND pla.org_id =
                                                   c_inv_hdr_rec.org_id
                                               AND NVL (pha.cancel_flag, 'N') =
                                                   'N'
                                               AND NVL (
                                                       pha.authorization_status,
                                                       'APPROVED') =
                                                   'APPROVED'
                                               AND NVL (pha.closed_code,
                                                        'OPEN') =
                                                   'OPEN'
                                               AND NVL (pla.cancel_flag, 'N') =
                                                   'N'
                                               AND NVL (pla.closed_code,
                                                        'OPEN') =
                                                   'OPEN';
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_hold_flag   := 'Y';
                                            l_err_msg     :=
                                                   l_err_msg
                                                || ' - '
                                                || 'PO Number and PO Line Number combination is Invalid';
                                    END;
                                END IF;
                            END;

                            BEGIN
                                IF     c_inv_hdr_rec.po_number_hdr
                                           IS NOT NULL
                                   AND c_inv_line_rec.po_number_line IS NULL
                                THEN
                                    BEGIN
                                        ln_check   := NULL;

                                        SELECT pla.po_header_id, pla.po_line_id, pda.code_combination_id
                                          INTO l_po_header_id_line, l_po_line_id, l_dist_acct_id
                                          FROM po_lines_all pla, po_headers_all pha, po_line_locations_all plla,
                                               po_distributions_all pda
                                         WHERE     pha.po_header_id =
                                                   pla.po_header_id
                                               AND pla.po_line_id =
                                                   plla.po_line_id
                                               AND plla.line_location_id =
                                                   pda.line_location_id
                                               AND plla.shipment_num = 1
                                               AND pda.distribution_num = 1
                                               AND pha.segment1 =
                                                   c_inv_hdr_rec.po_number_hdr
                                               AND pla.org_id =
                                                   c_inv_hdr_rec.org_id
                                               AND NVL (pha.cancel_flag, 'N') =
                                                   'N'
                                               AND NVL (
                                                       pha.authorization_status,
                                                       'APPROVED') =
                                                   'APPROVED'
                                               AND NVL (pha.closed_code,
                                                        'OPEN') =
                                                   'OPEN'
                                               AND NVL (pla.cancel_flag, 'N') =
                                                   'N'
                                               AND NVL (pla.closed_code,
                                                        'OPEN') =
                                                   'OPEN';
                                    EXCEPTION
                                        WHEN TOO_MANY_ROWS
                                        THEN
                                            l_hold_flag   := 'Y';
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;
                                END IF;
                            END;

                            IF     c_inv_line_rec.po_number_line IS NULL
                               AND c_inv_line_rec.po_line_number IS NULL
                               AND c_inv_hdr_rec.po_number_hdr IS NULL
                            THEN
                                l_hold_flag   := 'Y';
                                l_err_msg     :=
                                       l_err_msg
                                    || ' - '
                                    || 'PO details required';
                            END IF;
                        END IF;


                        --- Validate theShip to Location-------

                        IF c_inv_line_rec.ship_to IS NOT NULL
                        THEN
                            BEGIN
                                SELECT location_id
                                  INTO l_location_id
                                  FROM apps.hr_locations_all
                                 WHERE     1 = 1
                                       AND UPPER (TRIM (location_code)) =
                                           UPPER (
                                               TRIM (c_inv_line_rec.ship_to))
                                       AND NVL (inactive_date, SYSDATE + 1) >
                                           SYSDATE;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    BEGIN
                                        SELECT ship_to_location_id
                                          INTO l_location_id
                                          FROM ap_supplier_sites_all
                                         WHERE     vendor_site_id =
                                                   l_vendor_site_id
                                               AND org_id =
                                                   c_inv_hdr_rec.org_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_location_id   := NULL;
                                    END;
                                WHEN OTHERS
                                THEN
                                    l_location_id   := NULL;
                            END;
                        END IF;

                        IF     l_dist_acct_id IS NOT NULL
                           AND l_po_line_id IS NOT NULL
                        THEN
                            BEGIN
                                SELECT 'Y'
                                  INTO l_track_as_asset
                                  FROM fa_book_controls fbc, gl_code_combinations_kfv gcc, hr_operating_units hro,
                                       gl_legal_entities_bsvs glev, xle_entity_profiles lep
                                 WHERE     1 = 1
                                       AND fbc.flexbuilder_defaults_ccid =
                                           gcc.code_combination_id
                                       AND fbc.book_class = 'CORPORATE'
                                       AND glev.flex_segment_value =
                                           gcc.segment1
                                       AND glev.legal_entity_id =
                                           lep.legal_entity_id
                                       AND lep.transacting_entity_flag = 'Y'
                                       AND lep.legal_entity_id =
                                           hro.default_legal_context_id
                                       AND hro.organization_id =
                                           c_inv_hdr_rec.org_id
                                       AND gcc.code_combination_id =
                                           l_dist_acct_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_track_as_asset   := 'N';
                            END;

                            IF l_track_as_asset = 'Y'
                            THEN
                                l_hold_flag   := 'Y';
                                l_err_msg     :=
                                       l_err_msg
                                    || ' - '
                                    || 'Asset details required';
                            END IF;
                        END IF;

                        IF l_dist_acct_id IS NULL
                        THEN
                            l_hold_flag   := 'Y';
                        END IF;

                        IF     l_po_hdr_header_id IS NOT NULL
                           AND l_po_line_id IS NULL
                        THEN
                            l_po_hdr_req   := 'N';
                            l_hold_flag    := 'Y';
                        END IF;

                        UPDATE xxdo.xxd_ap_inv_upload_stg_t
                           SET gl_date = l_gl_date, terms_id = l_terms_id, po_header_id_line = l_po_header_id_line,
                               po_line_id = l_po_line_id, location_id = l_location_id, dist_acct_id = l_dist_acct_id,
                               inv_line_number = l_inv_line_number, payment_method_code = l_pay_method, error_msg = error_msg || l_err_msg
                         WHERE     ROWID = c_inv_line_rec.ROWID
                               AND UPPER (file_name) =
                                   UPPER (NVL (pv_file_name, file_name))
                               AND request_id = gn_request_id;
                    END LOOP;

                    UPDATE xxdo.xxd_ap_inv_upload_stg_t
                       SET status = l_status, hold_flag = l_hold_flag, vendor_id = l_vendor_id,
                           vendor_site_id = l_vendor_site_id, po_hdr_include = l_po_hdr_req
                     WHERE     inv_hdr_grp_id = c_inv_hdr_rec.inv_hdr_grp_id
                           AND UPPER (file_name) =
                               UPPER (NVL (pv_file_name, file_name))
                           AND request_id = gn_request_id;

                    IF l_status = gc_validate_status
                    THEN
                        SELECT ap_invoices_interface_s.NEXTVAL
                          INTO l_inv_header_id
                          FROM DUAL;

                        BEGIN
                            l_vendor_charge_tax   := NULL;

                            SELECT SUM (NVL (line_amount, 0))
                              INTO l_vendor_charge_tax
                              FROM xxdo.xxd_ap_inv_upload_stg_t
                             WHERE     inv_hdr_grp_id =
                                       c_inv_hdr_rec.inv_hdr_grp_id
                                   AND UPPER (file_name) =
                                       UPPER (NVL (pv_file_name, file_name))
                                   AND request_id = gn_request_id
                                   AND UPPER (line_type) = 'TAX'
                                   AND line_amount IS NOT NULL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_vendor_charge_tax   := NULL;
                        END;

                        UPDATE xxdo.xxd_ap_inv_upload_stg_t
                           SET vendor_charge_tax = l_vendor_charge_tax, inv_header_id = l_inv_header_id, inv_line_id = ap_invoice_lines_interface_s.NEXTVAL
                         WHERE     inv_hdr_grp_id =
                                   c_inv_hdr_rec.inv_hdr_grp_id
                               AND UPPER (file_name) =
                                   UPPER (NVL (pv_file_name, file_name))
                               AND request_id = gn_request_id;

                        load_interface (c_inv_hdr_rec.inv_hdr_grp_id,
                                        pv_file_name);
                    END IF;
                END IF;
            END LOOP;
        END;

        COMMIT;
        write_log_prc ('End validate_data');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (SQLERRM || 'validate_data');
            x_ret_msg   := 'validate_data-' || SQLERRM;
    END validate_data;

    PROCEDURE submit_import (pv_file_name VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        l_request_id       NUMBER;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
        l_invoice_count    NUMBER := 0;
        l_inv_source       VARCHAR2 (100);
        ex_no_invoices     EXCEPTION;
        l_cnt              NUMBER;
    BEGIN
        write_log_prc ('Start submit_import');
        l_request_id       := NULL;
        l_req_phase        := NULL;
        l_req_status       := NULL;
        l_req_dev_phase    := NULL;
        l_req_dev_status   := NULL;
        l_req_message      := NULL;
        l_req_boolean      := NULL;
        l_cnt              := 0;

        BEGIN
            SELECT COUNT (*)
              INTO l_cnt
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     1 = 1
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND request_id = gn_request_id
                   AND status = gc_interfaced;
        END;

        write_log_prc ('Start l_cnt-' || l_cnt);
        apps.mo_global.set_policy_context ('S', gn_org_id);
        apps.mo_global.init ('SQLAP');

        IF l_cnt > 0
        THEN
            l_request_id   :=
                apps.fnd_request.submit_request (application => 'SQLAP', program => 'APXIIMPT', description => 'Payables Open Interface Import', start_time => SYSDATE, sub_request => FALSE, argument1 => gn_org_id, argument2 => gc_inv_source, argument3 => gn_request_id, argument4 => 'N/A', argument5 => '', argument6 => '', argument7 => TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'), argument8 => 'N', argument9 => 'N', argument10 => 'N', argument11 => 'N', argument12 => 1000, argument13 => gn_user_id
                                                 , argument14 => gn_login_id);

            IF l_request_id <> 0
            THEN
                COMMIT;
                write_log_prc ('AP Request ID= ' || l_request_id);
            ELSIF l_request_id = 0
            THEN
                write_log_prc (
                       'Request Not Submitted due to "'
                    || apps.fnd_message.get
                    || '".');
            END IF;

            IF l_request_id > 0
            THEN
                LOOP
                    l_req_boolean   :=
                        apps.fnd_concurrent.wait_for_request (
                            l_request_id,
                            15,
                            0,
                            l_req_phase,
                            l_req_status,
                            l_req_dev_phase,
                            l_req_dev_status,
                            l_req_message);

                    EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                              OR UPPER (l_req_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                IF     UPPER (l_req_phase) = 'COMPLETED'
                   AND UPPER (l_req_status) = 'ERROR'
                THEN
                    write_log_prc (
                           'The Payables Open Import prog completed in error. See log for request id:'
                        || l_request_id);
                ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                      AND UPPER (l_req_status) = 'NORMAL'
                THEN
                    write_log_prc (
                           'The Payables Open Import request id: '
                        || l_request_id);
                ELSE
                    write_log_prc (
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id);
                END IF;
            END IF;
        END IF;

        write_log_prc ('End submit_import');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (' Error in create_invoices:' || SQLERRM);
            x_ret_msg   := ' Error in create_invoices:' || SQLERRM;
    END submit_import;

    PROCEDURE apply_hold (p_invoice_id NUMBER, p_invoice_num VARCHAR2)
    IS
        l_hold_type     VARCHAR2 (1000);
        l_hold_reason   VARCHAR2 (1000);
        l_check_flag    VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT hold_type, description
              INTO l_hold_type, l_hold_reason
              FROM ap_hold_codes_v
             WHERE hold_lookup_code = gc_hold_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_hold_type     := NULL;
                l_hold_reason   := NULL;
        END;

        ap_holds_pkg.insert_single_hold (
            x_invoice_id         => p_invoice_id,
            x_hold_lookup_code   => gc_hold_name,
            x_hold_type          => l_hold_type,
            x_hold_reason        => l_hold_reason,
            x_held_by            => gn_user_id,
            x_calling_sequence   => NULL);

        BEGIN
            SELECT 'Y'
              INTO l_check_flag
              FROM ap_holds_all
             WHERE     invoice_id = p_invoice_id
                   AND hold_lookup_code = gc_hold_name;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_check_flag   := 'N';
        END;

        IF l_check_flag = 'Y'
        THEN
            write_log_prc ('Hold Applied to Invoice Id-' || p_invoice_num);
        ELSE
            write_log_prc (
                'Hold not Applied to Invoice Id-' || p_invoice_num);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (' Error in apply_hold: ' || SQLERRM);
    END;

    PROCEDURE check_inv_create (pv_file_name       VARCHAR2,
                                x_ret_msg      OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
            SELECT DISTINCT org_id, invoice_number, vendor_id,
                            vendor_site_id, inv_header_id, hold_flag
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND request_id = gn_request_id
                   AND status = gc_interfaced;

        CURSOR c_line (p_inv_header_id IN NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     1 = 1
                   AND inv_header_id = p_inv_header_id
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND request_id = gn_request_id
                   AND status = gc_interfaced
                   AND UPPER (line_type) <> 'TAX';

        CURSOR c_hdr_rej (p_header_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_header_id
                   AND parent_table = 'AP_INVOICES_INTERFACE';

        CURSOR c_line_rej (p_line_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_line_id
                   AND parent_table = 'AP_INVOICE_LINES_INTERFACE';

        l_hdr_count    NUMBER := 0;
        l_line_count   NUMBER := 0;
        l_invoice_id   NUMBER := 0;
        l_hdr_check    VARCHAR2 (10) := NULL;
        l_line_check   VARCHAR2 (10) := NULL;
        l_hdr_error    VARCHAR2 (2000);
        l_line_error   VARCHAR2 (2000);
        l_status       VARCHAR2 (30);
    BEGIN
        FOR r_hdr IN c_hdr
        LOOP
            l_invoice_id   := NULL;
            l_status       := gc_process_status;
            l_hdr_check    := NULL;
            l_hdr_check    :=
                is_invoice_created (
                    p_org_id           => r_hdr.org_id,
                    p_invoice_num      => r_hdr.invoice_number,
                    p_vendor_id        => r_hdr.vendor_id,
                    p_vendor_site_id   => r_hdr.vendor_site_id,
                    x_invoice_id       => l_invoice_id);

            write_log_prc (
                   'r_hdr.invoice_number-'
                || r_hdr.invoice_number
                || l_hdr_check);

            IF l_hdr_check <> 'Y'
            THEN
                l_status      := gc_error_status;
                l_hdr_error   := NULL;

                FOR r_hdr_rej IN c_hdr_rej (r_hdr.inv_header_id)
                LOOP
                    l_hdr_error   :=
                        l_hdr_error || '. ' || r_hdr_rej.error_message;
                END LOOP;

                UPDATE xxdo.xxd_ap_inv_upload_stg_t
                   SET error_msg   = error_msg || l_hdr_error
                 WHERE     inv_header_id = r_hdr.inv_header_id
                       AND UPPER (file_name) =
                           UPPER (NVL (pv_file_name, file_name))
                       AND request_id = gn_request_id;
            END IF;

            FOR r_line IN c_line (r_hdr.inv_header_id)
            LOOP
                l_line_check   := NULL;
                l_line_check   :=
                    is_line_created (
                        p_invoice_id    => l_invoice_id,
                        p_line_number   => r_line.inv_line_number);

                IF l_line_check = 'Y'
                THEN
                    UPDATE xxdo.xxd_ap_inv_upload_stg_t
                       SET status   = gc_process_status
                     WHERE     inv_line_id = r_line.inv_line_id
                           AND UPPER (file_name) =
                               UPPER (NVL (pv_file_name, file_name))
                           AND request_id = gn_request_id;
                ELSE
                    l_line_error   := NULL;

                    FOR r_line_rej IN c_line_rej (r_line.inv_line_id)
                    LOOP
                        l_line_error   :=
                            l_line_error || '. ' || r_line_rej.error_message;
                    END LOOP;

                    l_status       := gc_error_status;

                    UPDATE xxdo.xxd_ap_inv_upload_stg_t
                       SET error_msg   = error_msg || l_line_error
                     WHERE     inv_line_id = r_line.inv_line_id
                           AND UPPER (file_name) =
                               UPPER (NVL (pv_file_name, file_name))
                           AND request_id = gn_request_id;
                END IF;

                write_log_prc (
                       'r_line.inv_line_number-'
                    || r_line.inv_line_number
                    || l_line_check);
            END LOOP;

            write_log_prc ('r_hdr.l_status-' || l_status);

            UPDATE xxdo.xxd_ap_inv_upload_stg_t
               SET status = l_status, invoice_id = l_invoice_id
             WHERE     inv_header_id = r_hdr.inv_header_id
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND request_id = gn_request_id;

            IF l_invoice_id IS NOT NULL AND r_hdr.hold_flag = 'Y'
            THEN
                apply_hold (l_invoice_id, r_hdr.invoice_number);
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Error in check_data: ' || SQLERRM;
            write_log_prc (x_ret_msg);
    END check_inv_create;

    PROCEDURE generate_exception_report_prc (pv_file_name VARCHAR2, pv_directory_path IN VARCHAR2, pv_exc_file_name OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
            SELECT DISTINCT inv_hdr_grp_id
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     request_id = gn_request_id
                   AND (status NOT IN (gc_dd_reported, gc_process_status) OR error_msg IS NOT NULL)
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name));

        CURSOR c_line (p_inv_hdr_grp_id IN NUMBER)
        IS
              SELECT stg.*, DECODE (stg.status,  gc_process_status, 'Processed',  gc_dd_reported, 'Processed',  'Error') status_desc
                FROM xxdo.xxd_ap_inv_upload_stg_t stg
               WHERE     request_id = gn_request_id
                     AND UPPER (file_name) =
                         UPPER (NVL (pv_file_name, file_name))
                     AND inv_hdr_grp_id = p_inv_hdr_grp_id
            ORDER BY file_name, inv_line_number;

        --DEFINE VARIABLES

        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
    BEGIN
        BEGIN
            UPDATE xxdo.xxd_ap_inv_upload_stg_t stg
               SET error_msg   = 'Please contact IT helpdesk'
             WHERE     request_id = gn_request_id
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND status = gc_error_status
                   AND error_msg IS NULL;
        END;

        lv_outbound_file    :=
               gn_request_id
            || '_Exception_RPT_'
            || TO_CHAR (SYSDATE, 'RRRR-MON-DD HH24:MI:SS')
            || '.xls';

        write_log_prc ('Exception File Name is - ' || lv_outbound_file);
        lv_directory_path   := pv_directory_path;
        lv_output_file      :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'PO Number Header Level '
                || CHR (9)
                || 'Invoice Number'
                || CHR (9)
                || 'Operating Unit'
                || CHR (9)
                || 'Trading Partner'
                || CHR (9)
                || 'Vendor Number'
                || CHR (9)
                || 'Supplier Site Code'
                || CHR (9)
                || 'Invoice Date'
                || CHR (9)
                || ' Invoice Amount'
                || CHR (9)
                || 'Currency Code'
                || CHR (9)
                || 'Invoice Description'
                || CHR (9)
                || 'Vendor Charged Tax'
                || CHR (9)
                || 'Tax Control Amount'
                || CHR (9)
                || 'FAPIO Received'
                || CHR (9)
                || 'Line Type'
                || CHR (9)
                || 'Line Description'
                || CHR (9)
                || 'Line Amount'
                || CHR (9)
                || 'Distribution Account'
                || CHR (9)
                || 'Ship To'
                || CHR (9)
                || 'PO Number'
                || CHR (9)
                || 'PO Line Number'
                || CHR (9)
                || 'Quantity Invoiced'
                || CHR (9)
                || 'Unit Price'
                || CHR (9)
                || 'Tax Classification Code'
                || CHR (9)
                || 'Interco Expense Account'
                || CHR (9)
                || 'Deferred'
                || CHR (9)
                || 'Deferred Start Date'
                || CHR (9)
                || 'Deferred End Date'
                || CHR (9)
                || 'Prorate Across All Item Lines'
                || CHR (9)
                || 'Track As Asset'
                || CHR (9)
                || 'Asset Category'
                || CHR (9)
                || 'Approver'
                || CHR (9)
                || 'Date Sent to Approver'
                || CHR (9)
                || 'Misc Notes'
                || CHR (9)
                || 'Chargeback'
                || CHR (9)
                || 'Invoice Number'
                || CHR (9)
                || 'Payment Ref Number'
                || CHR (9)
                || 'Sample Invoice'
                || CHR (9)
                || 'Asset Book'
                || CHR (9)
                || 'Distribution Set'
                || CHR (9)
                || 'Payment Terms'
                || CHR (9)
                || 'Invoice Addl Info'
                || CHR (9)
                || 'Pay Alone'
                || CHR (9)
                || 'Transaction Type'
                || CHR (9)
                || 'Vendor VAT Registration Number'
                || CHR (9)
                || 'Natura Codes'
                || CHR (9)
                || 'Tax Exemption Reason'
                || CHR (9)
                || 'Record Status'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Pagero File Name';

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR r_hdr IN c_hdr
            LOOP
                FOR r_line IN c_line (r_hdr.inv_hdr_grp_id)
                LOOP
                    write_log_prc (
                        'r_line.invoice_number-' || r_line.invoice_number);
                    lv_line   :=
                           NVL (r_line.po_number_hdr, '')
                        || CHR (9)
                        || NVL (r_line.invoice_number, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.org_id), '')
                        || CHR (9)
                        || NVL (r_line.vendor_name, '')
                        || CHR (9)
                        || NVL (r_line.vendor_num, '')
                        || CHR (9)
                        || NVL (r_line.vendor_site_code, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.invoice_date), '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.invoice_amount), '')
                        || CHR (9)
                        || NVL (r_line.invoice_currency_code, '')
                        || CHR (9)
                        || NVL (r_line.invoice_description, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.vendor_charged_tax), '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.tax_control_amount), '')
                        || CHR (9)
                        || NVL (r_line.fapio_received, '')
                        || CHR (9)
                        || NVL (r_line.line_type, '')
                        || CHR (9)
                        || NVL (r_line.line_description, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.line_amount), '')
                        || CHR (9)
                        || NVL (r_line.dist_account, '')
                        || CHR (9)
                        || NVL (r_line.ship_to, '')
                        || CHR (9)
                        || NVL (r_line.po_number_line, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.po_line_number), '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.quantity_invoiced), '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.unit_price), '')
                        || CHR (9)
                        || NVL (r_line.tax_classification_code, '')
                        || CHR (9)
                        || NVL (r_line.interco_expense_account, '')
                        || CHR (9)
                        || NVL (r_line.deferred, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.deferred_start_date), '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.deferred_end_date), '')
                        || CHR (9)
                        || NVL (r_line.prorate_all_item_lines, '')
                        || CHR (9)
                        || NVL (r_line.track_as_asset, '')
                        || CHR (9)
                        || NVL (r_line.asset_category, '')
                        || CHR (9)
                        || NVL (r_line.approver, '')
                        || CHR (9)
                        || NVL (TO_CHAR (r_line.date_sent_to_approver), '')
                        || CHR (9)
                        || NVL (r_line.misc_notes, '')
                        || CHR (9)
                        || NVL (r_line.chargeback, '')
                        || CHR (9)
                        || NVL (r_line.invoice_num, '')
                        || CHR (9)
                        || NVL (r_line.payment_ref_number, '')
                        || CHR (9)
                        || NVL (r_line.sample_invoice, '')
                        || CHR (9)
                        || NVL (r_line.asset_book, '')
                        || CHR (9)
                        || NVL (r_line.distribution_set, '')
                        || CHR (9)
                        || NVL (r_line.payment_terms, '')
                        || CHR (9)
                        || NVL (r_line.invoice_addl_info, '')
                        || CHR (9)
                        || NVL (r_line.pay_alone, '')
                        || CHR (9)
                        || NVL (r_line.transaction_type, '')
                        || CHR (9)
                        || NVL (r_line.vendor_vat_reg_num, '')
                        || CHR (9)
                        || NVL (r_line.nature_codes, '')
                        || CHR (9)
                        || NVL (r_line.tax_exemption_reason, '')
                        || CHR (9)
                        || NVL (r_line.status_desc, '')
                        || CHR (9)
                        || NVL (SUBSTR (r_line.error_msg, 1, 200), '')
                        || CHR (9)
                        || NVL (r_line.file_name, '');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            END LOOP;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);
        pv_exc_file_name    := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report_prc;

    PROCEDURE gen_file_formate_report_prc (pv_file_name        IN VARCHAR2,
                                           pv_directory_path   IN VARCHAR2)
    IS
        ln_rec_fail         NUMBER;
        ln_rec_total        NUMBER;
        ln_rec_success      NUMBER;
        lv_message          VARCHAR2 (32000);
        lv_recipients       VARCHAR2 (4000);
        lv_result           VARCHAR2 (100);
        lv_result_msg       VARCHAR2 (4000);
        lv_src_file_name    VARCHAR2 (1000);
        lv_mail_delimiter   VARCHAR2 (1) := '/';
    --ln_war_rec NUMBER;
    BEGIN
        ln_rec_total     := 0;
        ln_rec_fail      := 0;
        ln_rec_success   := 0;
        lv_src_file_name   :=
            pv_directory_path || lv_mail_delimiter || pv_file_name;
        write_log_prc (pv_file_name);
        lv_message       :=
               'Hello Team,'
            || CHR (10)
            || CHR (10)
            || 'Please Find the Attached Deckers AP e-Invoice Inbound Program Exception Report. '
            || CHR (10)
            || CHR (10)
            || ' File Name                                            - '
            || pv_file_name
            || CHR (10)
            || ' Number of Rows in the File                           - '
            || ln_rec_total
            || CHR (10)
            || ' Number of Rows Errored                               - '
            || ln_rec_fail
            || CHR (10)
            || ' Number of Rows Successful                            - '
            || ln_rec_success
            || CHR (10)
            || ' File Not Processed due to File Format is not correct'
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please donot reply.';

        BEGIN
            SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
              INTO lv_recipients
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_AP_INV_EMAIL_LKP'
                   AND enabled_flag = 'Y'
                   AND language = 'US'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_recipients   := NULL;
        END;

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => lv_recipients,
            pv_ccrecipients   => NULL,
            pv_subject        =>
                'Deckers AP e-Invoice Inbound Program Exception Report',
            pv_message        => lv_message,
            pv_attachments    => lv_src_file_name,
            xv_result         => lv_result,
            xv_result_msg     => lv_result_msg);

        write_log_prc ('lvresult is - ' || lv_result);
        write_log_prc ('lv_result_msg is - ' || lv_result_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Exception in gen_file_formate_report_prc- ' || SQLERRM);
    END gen_file_formate_report_prc;

    PROCEDURE generate_report_prc (pv_file_name IN VARCHAR2, pv_exc_directory_path IN VARCHAR2, p_reprocess_period NUMBER)
    IS
        ln_rec_fail             NUMBER;
        ln_rec_total            NUMBER;
        ln_rec_success          NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        ln_war_rec              NUMBER;
        l_file_name_str         VARCHAR2 (1000);
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;
        ln_war_rec       := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     request_id = gn_request_id
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name));
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_total   := 0;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_war_rec
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     request_id = gn_request_id
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND error_msg IS NOT NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_war_rec   := 0;
        END;

        IF ln_rec_total <= 0
        THEN
            write_log_prc ('There is nothing to Process...No File Exists.');
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_success
                  FROM xxdo.xxd_ap_inv_upload_stg_t
                 WHERE     request_id = gn_request_id
                       AND UPPER (file_name) =
                           UPPER (NVL (pv_file_name, file_name))
                       AND status IN (gc_dd_reported, gc_process_status);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_success   := 0;
            END;

            IF pv_file_name IS NULL
            THEN
                l_file_name_str   :=
                       '  Reprocessed for                                     - '
                    || p_reprocess_period
                    || ' days';
            ELSE
                l_file_name_str   :=
                       ' File Name                                            - '
                    || pv_file_name;
            END IF;

            ln_rec_fail   := ln_rec_total - ln_rec_success;
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '              Summary of Deckers AP e-Invoice Inbound Program ');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                'Date:' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (apps.fnd_file.output, l_file_name_str);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Considered into Inbound Staging Table - '
                || ln_rec_total);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Errored                               - '
                || ln_rec_fail);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Successful                            - '
                || ln_rec_success);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');

            IF ln_rec_fail > 0 OR ln_war_rec > 0
            THEN
                lv_exc_directory_path   := pv_exc_directory_path;
                generate_exception_report_prc (pv_file_name,
                                               lv_exc_directory_path,
                                               lv_exc_file_name);
                lv_exc_file_name        :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_exc_file_name;
                write_log_prc (lv_exc_file_name);
                lv_message              :=
                       'Hello Team,'
                    || CHR (10)
                    || CHR (10)
                    || 'Please Find the Attached Deckers AP e-Invoice Inbound Program Exception Report. '
                    || CHR (10)
                    || CHR (10)
                    || l_file_name_str
                    || CHR (10)
                    || ' Number of Rows in the File                           - '
                    || ln_rec_total
                    || CHR (10)
                    || ' Number of Rows Errored                               - '
                    || ln_rec_fail
                    || CHR (10)
                    || ' Number of Rows Successful                            - '
                    || ln_rec_success
                    || CHR (10)
                    || CHR (10)
                    || 'Regards,'
                    || CHR (10)
                    || 'SYSADMIN.'
                    || CHR (10)
                    || CHR (10)
                    || 'Note: This is auto generated mail, please donot reply.';

                BEGIN
                    SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
                      INTO lv_recipients
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXD_AP_INV_EMAIL_LKP'
                           AND enabled_flag = 'Y'
                           AND language = 'US'
                           AND SYSDATE BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                     NVL (end_date_active,
                                                          SYSDATE)
                                                   + 1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_recipients   := NULL;
                END;

                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_recipients,
                    pv_ccrecipients   => NULL,
                    pv_subject        =>
                        'Deckers AP e-Invoice Inbound Program Exception Report',
                    pv_message        => lv_message,
                    pv_attachments    => lv_exc_file_name,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);

                BEGIN
                    UTL_FILE.fremove (lv_exc_directory_path,
                                      lv_exc_file_name);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                               'Unable to delete the execption report file- '
                            || SQLERRM);
                END;

                write_log_prc ('lvresult is - ' || lv_result);
                write_log_prc ('lv_result_msg is - ' || lv_result_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Exception in generate_report_prc- ' || SQLERRM);
    END generate_report_prc;

    PROCEDURE main_prc (errbuf               OUT VARCHAR2,
                        retcode              OUT VARCHAR2,
                        p_org_id                 NUMBER,
                        p_reprocess              VARCHAR2,
                        p_file_name              VARCHAR2,
                        p_reprocess_period       NUMBER)
    IS
        CURSOR get_file_cur IS
              SELECT filename
                FROM xxd_utl_file_upload_gt
               WHERE     1 = 1
                     AND UPPER (filename) = UPPER (NVL (p_file_name, filename))
                     AND UPPER (filename) NOT LIKE UPPER ('%ARCHIVE%')
                     AND UPPER (filename) LIKE '%.CSV'
            ORDER BY filename;

        CURSOR c_file_cur IS
            SELECT DISTINCT file_name
              FROM xxdo.xxd_ap_inv_upload_stg_t
             WHERE     1 = 1
                   AND file_name = NVL (p_file_name, file_name)
                   AND status NOT IN (gc_dd_reported, gc_process_status)
                   AND TRUNC (creation_date) >=
                       TRUNC (
                             SYSDATE
                           - NVL (p_reprocess_period, g_reprocess_period));

        lv_directory_path          VARCHAR2 (1000);
        lv_inb_directory_path      VARCHAR2 (1000);
        lv_arc_directory_path      VARCHAR2 (1000);
        lv_exc_directory_path      VARCHAR2 (1000);
        lv_file_name               VARCHAR2 (1000);
        lv_exc_file_name           VARCHAR2 (1000);
        lv_ret_message             VARCHAR2 (4000) := NULL;
        lv_ret_code                VARCHAR2 (30) := NULL;
        ln_file_exists             NUMBER;
        lv_line                    VARCHAR2 (32767) := NULL;
        lv_all_file_names          VARCHAR2 (4000) := NULL;
        ln_rec_fail                NUMBER := 0;
        ln_rec_success             NUMBER;
        ln_rec_total               NUMBER;
        ln_ele_rec_total           NUMBER;
        lv_mail_delimiter          VARCHAR2 (1) := '/';
        lv_result                  VARCHAR2 (100);
        lv_result_msg              VARCHAR2 (4000);
        lv_message                 VARCHAR2 (4000);
        lv_sender                  VARCHAR2 (100);
        lv_recipients              VARCHAR2 (4000);
        lv_ccrecipients            VARCHAR2 (4000);
        l_cnt                      NUMBER := 0;
        ln_req_id                  NUMBER;
        lv_phase                   VARCHAR2 (100);
        lv_status                  VARCHAR2 (30);
        lv_dev_phase               VARCHAR2 (100);
        lv_dev_status              VARCHAR2 (100);
        lb_wait_req                BOOLEAN;
        l_exception                EXCEPTION;
        l_reprocess_cnt            NUMBER;
        lv_file_load_status        VARCHAR (10);
        lv_attach_directory_path   VARCHAR2 (1000);
    BEGIN
        write_log_prc ('Start main_prc-');
        lv_exc_file_name   := NULL;
        lv_file_name       := NULL;

        -- Derive the directory Path
        BEGIN
            lv_directory_path   := NULL;

            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_AP_INV_UPLOAD_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
                lv_message          :=
                       'Exception Occurred while retriving the Inbound Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_arc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_AP_INV_UPLOAD_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Archive Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_AP_INV_UPLOAD_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Exception Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_attach_directory_path   := NULL;

            SELECT directory_path
              INTO lv_attach_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_AP_INV_UPLOAD_ATTACH_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_attach_directory_path   := NULL;
                lv_message                 :=
                       'Exception Occurred while retriving the Attached Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        IF NVL (p_reprocess, 'N') = 'Y'
        THEN
            FOR c_file_rec IN c_file_cur
            LOOP
                lv_file_name   := c_file_rec.file_name;
                write_log_prc (
                    'Start Reprocessing the file-' || lv_file_name);

                BEGIN
                    SELECT COUNT (*)
                      INTO l_reprocess_cnt
                      FROM xxdo.xxd_ap_inv_upload_stg_t
                     WHERE     1 = 1
                           AND file_name = NVL (lv_file_name, file_name)
                           AND status NOT IN
                                   (gc_dd_reported, gc_process_status)
                           AND TRUNC (creation_date) >=
                               TRUNC (
                                     SYSDATE
                                   - NVL (p_reprocess_period,
                                          g_reprocess_period));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_reprocess_cnt   := 0;
                END;

                IF l_reprocess_cnt <= 0
                THEN
                    lv_message   :=
                           'Data with this File name - '
                        || lv_file_name
                        || ' - Now available to Reprocess.  ';
                    write_log_prc (
                        '**************************************************************************************************');
                    write_log_prc (lv_message);
                    write_log_prc (
                        '**************************************************************************************************');
                    generate_report_prc (lv_file_name,
                                         lv_exc_directory_path,
                                         p_reprocess_period);
                    RAISE l_exception;
                END IF;

                BEGIN
                    UPDATE xxdo.xxd_ap_inv_upload_stg_t
                       SET request_id = gn_request_id, last_update_date = SYSDATE, last_updated_by = gn_user_id,
                           status = 'N', error_msg = NULL
                     WHERE     1 = 1
                           AND file_name = NVL (lv_file_name, file_name)
                           AND status NOT IN
                                   (gc_dd_reported, gc_process_status)
                           AND TRUNC (creation_date) >=
                               TRUNC (
                                     SYSDATE
                                   - NVL (p_reprocess_period,
                                          g_reprocess_period));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                               'Error Occured while Updating the Filename, Request ID and WHO Columns-'
                            || SQLERRM);
                END;

                lv_message     := NULL;
                validate_data (lv_file_name, lv_message);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                lv_message     := NULL;
                submit_import (lv_file_name, lv_message);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                lv_message     := NULL;
                check_inv_create (lv_file_name, lv_message);
                --Added for CCR0009935
                attach_file (
                    pv_file_name            => lv_file_name,
                    pv_dir                  => 'XXD_AP_INV_UPLOAD_ATTACH_DIR',
                    pv_directory_path       => lv_directory_path,
                    pv_arc_directory_path   => lv_attach_directory_path,
                    pv_reprocess_flag       => 'Y',
                    x_ret_msg               => lv_message);

                -- end for CCR0009935

                clear_int_tables (lv_file_name);
                generate_report_prc (lv_file_name,
                                     lv_exc_directory_path,
                                     p_reprocess_period);
                write_log_prc ('End Reprocessing the file-' || lv_file_name);
            END LOOP;
        ELSE
            -- Now Get the file names
            write_log_prc ('Start Processing the file from server');
            get_file_names (lv_directory_path);

            FOR data IN get_file_cur
            LOOP
                ln_file_exists   := 0;
                lv_file_name     := NULL;
                lv_file_name     := data.filename;
                ln_req_id        := NULL;
                lv_phase         := NULL;
                lv_status        := NULL;
                lv_dev_phase     := NULL;
                lv_dev_status    := NULL;
                lv_message       := NULL;
                write_log_prc (' File is available - ' || lv_file_name);

                -- Check the file name exists in the table if exists then SKIP
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_file_exists
                      FROM xxdo.xxd_ap_inv_upload_stg_t
                     WHERE 1 = 1 AND UPPER (file_name) = UPPER (lv_file_name);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_file_exists   := 0;
                END;

                IF ln_file_exists = 0
                THEN
                    load_file_into_tbl_prc (
                        pv_table                => 'XXD_AP_INV_UPLOAD_STG_T',
                        pv_dir                  => 'XXD_AP_INV_UPLOAD_INB_DIR',
                        pv_filename             => lv_file_name,
                        pv_ignore_headerlines   => 5,
                        pv_delimiter            => '||',
                        pv_optional_enclosed    => '"',
                        pv_num_of_columns       => 46,
                        x_ret_status            => lv_file_load_status); -- Change the number of columns

                    IF lv_file_load_status = 'E'
                    THEN
                        gen_file_formate_report_prc (
                            pv_file_name        => lv_file_name,
                            pv_directory_path   => lv_directory_path);
                    END IF;

                    BEGIN
                        UPDATE xxdo.xxd_ap_inv_upload_stg_t
                           SET file_name = lv_file_name, request_id = gn_request_id, creation_date = SYSDATE,
                               last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                               status = 'N'
                         WHERE     1 = 1
                               AND file_name IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log_prc (
                                   'Error Occured while Updating the Filename, Request ID and WHO Columns-'
                                || SQLERRM);
                    END;

                    COMMIT;
                    move_file (
                        p_mode     => 'MOVE',
                        p_source   => lv_directory_path || '/' || lv_file_name,
                        p_target   =>
                               lv_arc_directory_path
                            || '/'
                            || SYSDATE
                            || '_'
                            || lv_file_name);
                ELSE
                    write_log_prc (
                        '**************************************************************************************************');
                    write_log_prc (
                           'Data with this File name - '
                        || lv_file_name
                        || ' - is already loaded. Please change the file data.  ');
                    write_log_prc (
                        '**************************************************************************************************');
                    move_file (
                        p_mode     => 'MOVE',
                        p_source   => lv_directory_path || '/' || lv_file_name,
                        p_target   =>
                               lv_arc_directory_path
                            || '/'
                            || SYSDATE
                            || '_'
                            || lv_file_name);
                END IF;

                lv_message       := NULL;
                validate_data (lv_file_name, lv_message);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                lv_message       := NULL;
                submit_import (lv_file_name, lv_message);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                lv_message       := NULL;
                check_inv_create (lv_file_name, lv_message);
                -- added for CCR0009935
                attach_file (
                    pv_file_name            => lv_file_name,
                    pv_dir                  => 'XXD_AP_INV_UPLOAD_INB_DIR',
                    pv_directory_path       => lv_directory_path,
                    pv_arc_directory_path   => lv_attach_directory_path,
                    pv_reprocess_flag       => 'N',
                    x_ret_msg               => lv_message);
                --end for CCR0009935

                clear_int_tables (lv_file_name);
                generate_report_prc (lv_file_name,
                                     lv_exc_directory_path,
                                     p_reprocess_period);
            END LOOP;
        END IF;

        write_log_prc ('End main_prc-');
    EXCEPTION
        WHEN l_exception
        THEN
            write_log_prc (lv_message);
        WHEN OTHERS
        THEN
            write_log_prc ('Error in main_prc-' || SQLERRM);
    END main_prc;
END xxd_ap_inv_upload_pkg;
/
