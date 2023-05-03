--
-- XXD_GL_AC_SETTING_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_AC_SETTING_EXTRACT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_GL_AC_SETTING_EXTRACT_PKG
    * Design       : This package will be used to fetch the Account settings from value set and send to blackline
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 29-Mar-2021  1.0        Showkath Ali            Initial Version
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    gn_error          CONSTANT NUMBER := 2;

    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

    PROCEDURE check_file_exists (p_file_path     IN     VARCHAR2,
                                 p_file_name     IN     VARCHAR2,
                                 x_file_exists      OUT BOOLEAN,
                                 x_file_length      OUT NUMBER,
                                 x_block_size       OUT BINARY_INTEGER)
    IS
        lv_proc_name     VARCHAR2 (30) := 'CHECK_FILE_EXISTS';
        lb_file_exists   BOOLEAN := FALSE;
        ln_file_length   NUMBER := NULL;
        ln_block_size    BINARY_INTEGER := NULL;
        lv_err_msg       VARCHAR2 (2000) := NULL;
    BEGIN
        --Checking if p_file_name file exists in p_file_dir directory
        --If exists, x_file_exists is true else false
        UTL_FILE.fgetattr (location      => p_file_path,
                           filename      => p_file_name,
                           fexists       => lb_file_exists,
                           file_length   => ln_file_length,
                           block_size    => ln_block_size);

        x_file_exists   := lb_file_exists;
        x_file_length   := ln_file_length;
        x_block_size    := ln_block_size;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_file_exists   := lb_file_exists;
            x_file_length   := ln_file_length;
            x_block_size    := ln_block_size;
            lv_err_msg      :=
                SUBSTR (
                       'When Others expection while checking file is created or not in '
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);

            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
    END check_file_exists;


    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

    PROCEDURE write_extract_file (p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, p_last_run_date IN VARCHAR2, p_override_last_run IN VARCHAR2, p_enabled_flag IN VARCHAR2, x_ret_code OUT VARCHAR2
                                  , x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_account_setting IS
            SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || key_account || CHR (9) || zba || CHR (9) || risk_rating || CHR (9) || frequency || CHR (9) || role1_frequency || CHR (9) || role2_frequency || CHR (9) || role3_frequency || CHR (9) || role5_frequency || CHR (9) || role7_frequency || CHR (9) || company_policy || CHR (9) || purpose || CHR (9) || Reconciliation_Procedure || CHR (9) || template || CHR (9) || team_unique_identifier || CHR (9) || financial_statement || CHR (9) || erp_drilldown || CHR (9) || excluse_from_bulk_certify || CHR (9) || dual_level_review_required || CHR (9) || email_next_person_in_workflow || CHR (9) || Certification_Threshold_Amt || CHR (9) || Certification_Threshold_Pcent || CHR (9) || Certification_Threshold_AndOr line
              FROM xxd_gl_account_settings_v a
             WHERE     1 = 1
                   AND (((a.last_update_date BETWEEN NVL (TO_DATE (p_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), a.last_update_date) AND NVL (SYSDATE, a.last_update_date)) AND NVL (p_override_last_run, 'N') = 'N') OR (1 = 1 AND NVL (p_override_last_run, 'N') = 'Y'))
                   AND a.enabled_flag = NVL (p_enabled_flag, a.enabled_flag);


        --DEFINE VARIABLES

        lv_file_path       VARCHAR2 (360) := p_file_path;
        lv_output_file     UTL_FILE.file_type;
        lv_outbound_file   VARCHAR2 (360) := p_file_name;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
    BEGIN
        IF lv_file_path IS NULL
        THEN                                            -- WRITE INTO FND LOGS
            FOR i IN write_account_setting
            LOOP
                lv_line   := i.line;
                fnd_file.put_line (fnd_file.output, lv_line);
            END LOOP;
        ELSE
            -- WRITE INTO BL FOLDER
            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                   ,
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                FOR i IN write_account_setting
                LOOP
                    lv_line   := i.line;
                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the Account setting data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file);

            -- update the last run in the value set
            BEGIN
                UPDATE apps.fnd_flex_values ffvl
                   SET ffvl.attribute1 = TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS')
                 WHERE     1 = 1
                       AND ffvl.flex_value_set_id =
                           (SELECT flex_value_set_id
                              FROM apps.fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'XXD_GL_ACCSET_GRPMAP_LSTRUN_VS')
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Updation last run date failed in Valueset ');
            END;
        --
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_extract_file;

    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

    PROCEDURE write_extract_file_grp (p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, p_grouped IN VARCHAR2, p_enabled IN VARCHAR2, p_group_name IN VARCHAR2, p_override_last_run IN VARCHAR2
                                      , p_last_run_date IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_grouping_extract IS
            SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || group_entity_unique_identifier || CHR (9) || Group_Name || CHR (9) || group_key3 || CHR (9) || group_key4 || CHR (9) || group_key5 || CHR (9) || group_key6 || CHR (9) || group_key7 || CHR (9) || group_key8 || CHR (9) || group_key9 || CHR (9) || group_key10 || CHR (9) || TO_CHAR (date_added, 'MM/DD/RRRR') || CHR (9) || date_removed || CHR (9) || assignment_type line
              FROM XXD_GL_COMB_GROUPING_EXTRACT_V a
             WHERE     1 = 1
                   AND (((a.last_update_date BETWEEN NVL (TO_DATE (p_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), a.last_update_date) AND NVL (SYSDATE, a.last_update_date)) AND NVL (p_override_last_run, 'N') = 'N') OR (1 = 1 AND NVL (p_override_last_run, 'N') = 'Y'))
                   AND a.enabled_flag = NVL (p_enabled, a.enabled_flag)
                   AND (a.group1 IS NULL AND p_grouped = 'N' OR a.group1 IS NOT NULL AND p_grouped = 'Y' OR 1 = 1 AND p_grouped IS NULL)
                   AND NVL (a.group1, 'X') =
                       NVL (p_group_name, NVL (a.group1, 'X'));

        --DEFINE VARIABLES

        lv_file_path       VARCHAR2 (360) := p_file_path;
        lv_output_file     UTL_FILE.file_type;
        lv_outbound_file   VARCHAR2 (360) := p_file_name;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
    BEGIN
        IF lv_file_path IS NULL
        THEN                                            -- WRITE INTO FND LOGS
            FOR i IN write_grouping_extract
            LOOP
                lv_line   := i.line;
                fnd_file.put_line (fnd_file.output, lv_line);
            END LOOP;
        ELSE
            -- WRITE INTO BL FOLDER
            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                   ,
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                FOR i IN write_grouping_extract
                LOOP
                    lv_line   := i.line;
                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the grouping extract file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file);

            BEGIN
                UPDATE apps.fnd_flex_values ffvl
                   SET ffvl.attribute2 = TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS')
                 WHERE     1 = 1
                       AND ffvl.flex_value_set_id =
                           (SELECT flex_value_set_id
                              FROM apps.fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'XXD_GL_ACCSET_GRPMAP_LSTRUN_VS')
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Updation As-of-Date failed in Valueset ');
            END;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_extract_file_grp;


    -- =====================================================================================================
    -- This procedure is Main procedure calling from concurrent program: Deckers GL Account Settings Extract Program
    -- =====================================================================================================

    PROCEDURE grouping_main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_grouped IN VARCHAR2, p_enabled IN VARCHAR2, p_group_name IN VARCHAR2, p_override_last_run IN VARCHAR2
                             , p_file_path IN VARCHAR2)
    AS
        lv_outbound_cur_file   VARCHAR2 (360)
            :=    'GroupMapping_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';
        l_file_name            VARCHAR2 (240)
            :=    'GroupMapping_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';
        lv_ret_code            VARCHAR2 (30) := NULL;
        lv_ret_message         VARCHAR2 (2000) := NULL;
        lb_file_exists         BOOLEAN;
        ln_file_length         NUMBER := NULL;
        ln_block_size          NUMBER := NULL;
        l_last_run_date        VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT (ffvl.attribute1)
              INTO l_last_run_date
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GL_ACCSET_GRPMAP_LSTRUN_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y';

            fnd_file.put_line (fnd_file.LOG,
                               'Last run date is:' || l_last_run_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_last_run_date   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch last run date from the value set :');
        END;


        --  call procedure to write the data in file at the given location or if file name is not given then write into the log



        write_extract_file_grp (p_file_path, l_file_name, p_grouped,
                                p_enabled, p_group_name, p_override_last_run,
                                l_last_run_date, lv_ret_code, lv_ret_message);

        IF p_file_path IS NOT NULL
        THEN
            IF lv_ret_code = gn_error
            THEN
                p_retcode   := gn_error;
                p_errbuf    :=
                    'After write into group setting - ' || lv_ret_message;
                fnd_file.put_line (fnd_file.LOG, p_errbuf);
                raise_application_error (-20002, p_errbuf);
            END IF;

            check_file_exists (p_file_path     => p_file_path,
                               p_file_name     => l_file_name,
                               x_file_exists   => lb_file_exists,
                               x_file_length   => ln_file_length,
                               x_block_size    => ln_block_size);

            IF lb_file_exists
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Grouping Extract is successfully created in the directory.');
                lv_ret_code      := NULL;
                lv_ret_message   := NULL;
            ELSE
                --If lb_file_exists is FALSE then do the below
                lv_ret_message   :=
                    SUBSTR (
                        'Grouping Extract file creation is not successful, Please check the issue.',
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_ret_message);
                --Complete the program in error
                p_retcode   := gn_error;
                p_errbuf    := lv_ret_message;
            END IF;
        END IF;
    END grouping_main;

    PROCEDURE main (p_errbuf                 OUT VARCHAR2,
                    p_retcode                OUT NUMBER,
                    p_enabled_flag        IN     VARCHAR2,
                    p_override_last_run   IN     VARCHAR2,
                    p_file_path           IN     VARCHAR2)
    AS
        lv_outbound_cur_file   VARCHAR2 (360)
            :=    'AccountSettings_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';
        l_file_name            VARCHAR2 (240)
            :=    'AccountSettings_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';
        lv_ret_code            VARCHAR2 (30) := NULL;
        lv_ret_message         VARCHAR2 (2000) := NULL;
        lb_file_exists         BOOLEAN;
        ln_file_length         NUMBER := NULL;
        ln_block_size          NUMBER := NULL;
        l_last_run_date        VARCHAR2 (30);
    BEGIN
        -- Query to fetch lastrun date from value set
        BEGIN
            SELECT (ffvl.attribute1)
              INTO l_last_run_date
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GL_ACCSET_GRPMAP_LSTRUN_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y';

            fnd_file.put_line (fnd_file.LOG,
                               'Last run date is:' || l_last_run_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_last_run_date   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch last run date from the value set :');
        END;

        --  call procedure to write the data in file at the given location or if file name is not given then write into the log


        write_extract_file (p_file_path, l_file_name, l_last_run_date,
                            p_enabled_flag, p_override_last_run, lv_ret_code,
                            lv_ret_message);

        IF p_file_path IS NOT NULL
        THEN
            IF lv_ret_code = gn_error
            THEN
                p_retcode   := gn_error;
                p_errbuf    :=
                    'After write into account setting - ' || lv_ret_message;
                fnd_file.put_line (fnd_file.LOG, p_errbuf);
                raise_application_error (-20002, p_errbuf);
            END IF;

            check_file_exists (p_file_path     => p_file_path,
                               p_file_name     => l_file_name,
                               x_file_exists   => lb_file_exists,
                               x_file_length   => ln_file_length,
                               x_block_size    => ln_block_size);

            IF lb_file_exists
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Account setting is successfully created in the directory.');
                lv_ret_code      := NULL;
                lv_ret_message   := NULL;
            ELSE
                --If lb_file_exists is FALSE then do the below
                lv_ret_message   :=
                    SUBSTR (
                        'Account setting file creation is not successful, Please check the issue.',
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_ret_message);
                --Complete the program in error
                p_retcode   := gn_error;
                p_errbuf    := lv_ret_message;
            END IF;
        END IF;
    END MAIN;
END XXD_GL_AC_SETTING_EXTRACT_PKG;
/
