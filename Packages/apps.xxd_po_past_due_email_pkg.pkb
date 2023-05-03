--
-- XXD_PO_PAST_DUE_EMAIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_PAST_DUE_EMAIL_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_PO_PAST_DUE_EMAIL_PKG
       * Design       : This package is used to send email as Zip file to after concurrent program
                        sent data to oracle directory
       * Notes        :
       * Modification :
       -- ===============================================================================
       -- Date         Version#   Name                    Comments
       -- ===============================================================================
       -- 08-AUG-2021  1.0        Srinath Siricilla      Initial Version
       ******************************************************************************************/
    FUNCTION file_to_blob_fnc (pv_directory_name   IN VARCHAR2,
                               pv_file_name        IN VARCHAR2)
        RETURN BLOB
    IS
        dest_loc   BLOB := EMPTY_BLOB ();
        src_loc    BFILE := BFILENAME (pv_directory_name, pv_file_name);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           ' Start of Convering the file to BLOB');

        DBMS_LOB.OPEN (src_loc, DBMS_LOB.LOB_READONLY);

        DBMS_LOB.CREATETEMPORARY (lob_loc   => dest_loc,
                                  cache     => TRUE,
                                  dur       => DBMS_LOB.session);

        DBMS_LOB.OPEN (dest_loc, DBMS_LOB.LOB_READWRITE);

        DBMS_LOB.LOADFROMFILE (dest_lob   => dest_loc,
                               src_lob    => src_loc,
                               amount     => DBMS_LOB.getLength (src_loc));

        DBMS_LOB.CLOSE (dest_loc);

        DBMS_LOB.CLOSE (src_loc);

        RETURN dest_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in Converting the file to BLOB - ' || SQLERRM);

            RETURN NULL;
    END file_to_blob_fnc;

    PROCEDURE save_zip_prc (pb_zipped_blob     BLOB,
                            pv_dir             VARCHAR2,
                            pv_zip_file_name   VARCHAR2)
    IS
        t_fh    UTL_FILE.file_type;
        t_len   PLS_INTEGER := 32767;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of save_zip_prc Procedure');

        DBMS_OUTPUT.put_line (' Start of save_zip_prc Procedure');

        t_fh   :=
            UTL_FILE.fopen ('XXD_GL_TRAIL_BALANCE_DIR',
                            pv_zip_file_name,
                            'wb');

        DBMS_OUTPUT.put_line (' Start of save_zip_prc Procedure - TEST1');

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (pb_zipped_blob) - 1) / t_len)
        LOOP
            UTL_FILE.put_raw (
                t_fh,
                DBMS_LOB.SUBSTR (pb_zipped_blob, t_len, i * t_len + 1));
        END LOOP;

        UTL_FILE.fclose (t_fh);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);

            DBMS_OUTPUT.put_line (
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);
    END save_zip_prc;


    PROCEDURE create_final_zip_prc (pv_directory_name IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2)
    IS
        lb_file   BLOB;
        lb_zip    BLOB;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of file_to_blob_fnc ');

        lb_file   := file_to_blob_fnc (pv_directory_name, pv_file_name);

        fnd_file.put_line (fnd_file.LOG, ' Start of add_file PROC ');

        APEX_200200.WWV_FLOW_ZIP.add_file (lb_zip, pv_file_name, lb_file);

        fnd_file.put_line (fnd_file.LOG, ' Start of finish PROC ');

        APEX_200200.wwv_flow_zip.finish (lb_zip);

        fnd_file.put_line (fnd_file.LOG, ' Start of Saving ZIP File PROC ');

        save_zip_prc (lb_zip, pv_directory_name, pv_zip_file_name);
    END create_final_zip_prc;

    PROCEDURE zip_email_file_prc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, pn_request_id IN NUMBER
                                  , pv_directory IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2)
    IS
        v_complete         BOOLEAN;
        lv_phase           VARCHAR2 (200);
        lv_status          VARCHAR2 (200);
        lv_dev_phase       VARCHAR2 (200);
        lv_dev_status      VARCHAR2 (200);
        lv_message         VARCHAR2 (200);
        lv_zip_file_name   VARCHAR2 (500);
        lv_mail_status     VARCHAR2 (200) := NULL;
        lv_mail_msg        VARCHAR2 (4000) := NULL;
        lv_dir_path        VARCHAR2 (500);
        lv_email_id        VARCHAR2 (500);
        lv_instance_name   VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Directory is - ' || pv_directory);
        fnd_file.put_line (fnd_file.LOG, 'File Name is - ' || pv_file_name);
        fnd_file.put_line (fnd_file.LOG,
                           'Zip File Name is - ' || pv_zip_file_name);

        DBMS_OUTPUT.put_line ('Directory is - ' || pv_directory);
        DBMS_OUTPUT.put_line ('File Name is - ' || pv_file_name);
        DBMS_OUTPUT.put_line ('Zip File Name is - ' || pv_zip_file_name);
        lv_email_id   := NULL;

        BEGIN
            SELECT directory_path
              INTO lv_dir_path
              FROM dba_directories
             WHERE directory_name = pv_directory;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dir_path   := NULL;
        END;

        LOOP
            v_complete   :=
                fnd_concurrent.wait_for_request (
                    request_id   => pn_request_id,
                    INTERVAL     => 10,
                    max_wait     => 180,
                    phase        => lv_phase,
                    status       => lv_status,
                    dev_phase    => lv_dev_phase,
                    dev_status   => lv_dev_status,
                    MESSAGE      => lv_message);

            EXIT WHEN    UPPER (lv_phase) = 'COMPLETED'
                      OR UPPER (lv_status) IN
                             ('CANCELLED', 'ERROR', 'TERMINATED');
        END LOOP;

        IF UPPER (lv_phase) = 'COMPLETED' AND UPPER (lv_status) = 'NORMAL'
        THEN
            DBMS_LOCK.SLEEP (120);

            create_final_zip_prc (pv_directory_name   => pv_directory,
                                  pv_file_name        => pv_file_name,
                                  pv_zip_file_name    => pv_zip_file_name);

            lv_mail_status   := NULL;
            lv_mail_msg      := NULL;

            -- Send Emails once the Zip File is created

            DBMS_LOCK.SLEEP (60);

            BEGIN
                SELECT fnd_profile.VALUE ('XXDO_SUPPLY_ALERT_CONTACTS')
                  INTO lv_email_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_email_id   := NULL;
            END;

            BEGIN
                SELECT name INTO lv_instance_name FROM v$database;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_instance_name   := NULL;
            END;

            XXDO_MAIL_PKG.send_mail ('erp@deckers.com', lv_email_id, NULL,
                                     lv_instance_name || ' - ' || pv_zip_file_name, ' Hi,' || CHR (10) || CHR (10) || ' Please find attached the details of Past Due Supply. ' || CHR (10) || CHR (10) || ' Thank You' || CHR (10) || CHR (10) || ' Regards,' || CHR (10) || CHR (10) || ' Note: This is auto generated mail, please donot reply.', lv_dir_path || '/' || pv_zip_file_name
                                     , lv_mail_status, lv_mail_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error While Emailing the file' || SQLERRM);
            DBMS_OUTPUT.put_line ('Error While Emailing the file' || SQLERRM);
    END zip_email_file_prc;
END XXD_PO_PAST_DUE_EMAIL_PKG;
/
