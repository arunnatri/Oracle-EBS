--
-- XXD_FND_DOC_FILES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FND_DOC_FILES_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_FND_DOC_FILES_PKG
    * Description     : Generic Package to Upload FND Document Files by Entities
    *                 : AP_INVOICES\OE_ORDER_HEADERS\REQ_HEADERS\PO_HEADER\AR_CUSTOMERS\GL_JE_HEADERS
    * Notes           : p_file_prefix should be 'Invoices_'\OM_Order_'
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date         Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 04-APR-2018  1.0           Aravind Kannuri           Initial Version for CCR0007106
    * 30-JUL-2018  1.1           Aravind Kannuri     Added Parameter for CCR0007350
    ************************************************************************************************/

    --Upload FND Document files by Entity
    FUNCTION get_doc_files (p_pk1_value_id IN NUMBER, p_entity_name IN fnd_attached_documents.entity_name%TYPE, --Added new parameter as per version 1.1
                                                                                                                p_directory_name IN dba_directories.directory_name%TYPE DEFAULT NULL
                            , p_file_prefix IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_doc_files_c IS
              SELECT fad.seq_num, fad.entity_name, fad.pk1_value,
                     fl.file_name, p_file_prefix || fl.file_name concat_file_name, fl.file_data
                FROM fnd_attached_documents fad, fnd_documents fd, fnd_lobs fl,
                     fnd_document_datatypes fdd
               WHERE     fad.document_id = fd.document_id
                     AND fd.media_id = fl.file_id
                     AND fd.datatype_id = fdd.datatype_id
                     AND fdd.NAME = 'FILE'
                     AND fad.entity_name = p_entity_name
                     --AP_INVOICES\OE_ORDER_HEADERS
                     AND fad.pk1_value = TO_CHAR (p_pk1_value_id)
                     AND fad.seq_num =
                         (SELECT MAX (seq_num)
                            FROM apps.fnd_attached_documents fad1
                           WHERE fad1.pk1_value = TO_CHAR (p_pk1_value_id))
                     AND fdd.LANGUAGE = USERENV ('LANG')
                     AND fl.LANGUAGE = USERENV ('LANG')
            ORDER BY fad.pk1_value;

        lc_file            UTL_FILE.file_type;
        lc_line            VARCHAR2 (1000);
        ln_blob_len        NUMBER;
        ln_pos             NUMBER;
        lc_buffer          RAW (32764);
        ln_amt             BINARY_INTEGER := 32764;
        lc_return_value    VARCHAR2 (1000);
        lv_entity_exists   VARCHAR2 (100) := 0;
        lv_err_msg         VARCHAR2 (4000);
    BEGIN
        -- File Attachments
        FOR get_doc_files_r IN get_doc_files_c
        LOOP
            lc_file       :=
                UTL_FILE.fopen (NVL (p_directory_name, 'XXD_FND_DOCUMENTS'), get_doc_files_r.concat_file_name, 'wb'
                                , ln_amt);
            ln_blob_len   := DBMS_LOB.getlength (get_doc_files_r.file_data);
            ln_pos        := 1;

            WHILE ln_pos < ln_blob_len
            LOOP
                DBMS_LOB.READ (get_doc_files_r.file_data, ln_amt, ln_pos,
                               lc_buffer);
                UTL_FILE.put_raw (lc_file, lc_buffer, TRUE);
                ln_pos   := ln_pos + ln_amt;
            END LOOP;

            UTL_FILE.fclose (lc_file);
        END LOOP;

        RETURN 'S';
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.invalid_mode
        THEN
            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.invalid_filehandle
        THEN
            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.invalid_operation
        THEN
            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.read_error
        THEN
            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.write_error
        THEN
            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.internal_error
        THEN
            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN UTL_FILE.invalid_filename
        THEN
            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Others Exception -Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, ' lv_err_msg => ' || lv_err_msg);
            RETURN 'E';
    END get_doc_files;
END xxd_fnd_doc_files_pkg;
/
