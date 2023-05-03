--
-- XXD_PICK_RELEASE_HEAD_ARCHIVE  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PICK_RELEASE_HEAD_ARCHIVE"
AS
    /**********************************************************************************************
       * Package         : APPS.XXD_PICK_RELEASE_HEAD_ARCHIVE
       * Author          : BT Technology Team
       * Created         : 09-SEP-2016
       * Program Name    :
       * Description     :
       *
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       *     Date         Developer             Version     Description
       *-----------------------------------------------------------------------------------------------
       *     09-SEP-2016 BT Technology Team     V1.1         Development
       ************************************************************************************************/
    PROCEDURE MAIN_PROGRAM (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    AS
        v_user_id        NUMBER := fnd_profile.VALUE ('USER_ID');
        v_resp_id        NUMBER;
        v_resp_appl_id   NUMBER;
        vn_request_id    NUMBER;
        vb_wait          BOOLEAN;
        vc_phase         VARCHAR2 (50);
        vc_status        VARCHAR2 (50);
        vc_dev_phase     VARCHAR2 (50);
        vc_dev_status    VARCHAR2 (50);
        vc_message       VARCHAR2 (50);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inserting the data into archive table');

        INSERT INTO xxdo.do_pick_headers_temp_archive
            (SELECT *
               FROM do_custom.do_pick_headers_temp
              WHERE (TRUNC (creation_date) <= (SYSDATE - 7)));

        fnd_file.put_line (fnd_file.LOG,
                           'Deleting the data into Headers table');

        DELETE FROM do_custom.do_pick_headers_temp
              WHERE (TRUNC (creation_date) <= (SYSDATE - 7));

        COMMIT;

        BEGIN
            SELECT frl.application_id, frl.responsibility_id
              INTO v_resp_appl_id, v_resp_id
              FROM fnd_responsibility_tl frl
             WHERE     frl.responsibility_name = 'System Administrator'
                   AND frl.LANGUAGE = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Error while retreiving responsibility and application id  ');
        END;

        --Initializing environment to run the program by SYSADMIN user from SYSTEM ADMINISTRATOR responsibility

        fnd_global.apps_initialize (v_user_id, v_resp_id, v_resp_appl_id);
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'User Id' || v_user_id);

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                ' Responsibility Id ' || v_resp_id);

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Responsibility application Id' || v_resp_appl_id);

        BEGIN
            vn_request_id   :=
                fnd_request.submit_request ('FND',    --application short name
                                                   'FNDGTST', --conc prg short name
                                                              NULL,
                                            NULL, FALSE, 'DO_CUSTOM', --TO_CHAR (pick_sequence_id),
                                            'do_pick_headers_temp', NULL, NULL, NULL, 'NOBACKUP', 'DEFAULT'
                                            , 'LASTRUN', 'Y');
            COMMIT;


            IF vn_request_id <= 0
            THEN
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        ' Request Id ' || vn_request_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || fnd_message.get
                    || '".');
                x_retcode   := 2;
            END IF;
        END;
    END MAIN_PROGRAM;
END XXD_PICK_RELEASE_HEAD_ARCHIVE;
/
