--
-- XXD_INV_VALUE_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_VALUE_EXTRACT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_INV_VALUE_EXTRACT_PKG
    --  Design       : This package is used to get the balances extract of GIVR and sent to Blackline
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  07-APR-2021     1.0        Showkath Ali             Initial Version
    --  03-Feb-2022     1.1        Showkath Ali             CCR0009806 to update XXD_GL_AAR_FILE_DETAILS_VS
    --  ####################################################################################################
    --3.2 changes start
    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

    GN_ERROR   NUMBER := 2;

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

    PROCEDURE write_givr_file (p_file_path     IN     VARCHAR2,
                               p_file_name     IN     VARCHAR2,
                               p_request_id    IN     NUMBER,
                               x_ret_code         OUT VARCHAR2,
                               x_ret_message      OUT VARCHAR2)
    IS
        CURSOR write_givr_extract IS
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (TO_DATE (period_end_date, 'DD-MON-YYYY'), 'MM/DD/YYYY') || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || ROUND (SUM (subledger_acc_bal), 2) line
                FROM xxdo.xxd_inv_givr_acct_detls_t
               WHERE request_id = p_request_id
            GROUP BY entity_unique_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal;

        --DEFINE VARIABLES

        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_file_path           VARCHAR2 (360);
        lv_vs_file_name           VARCHAR2 (360);
        lv_vs_default_file_path   VARCHAR2 (360);
        lv_request_id             NUMBER := fnd_global.conc_request_id;
    BEGIN
        -- WRITE INTO FND LOGS
        FOR i IN write_givr_extract
        LOOP
            lv_line   := i.line;
            fnd_file.put_line (fnd_file.output, lv_line);
        END LOOP;

        IF p_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute2, ffvl.attribute4
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'GIVR'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_file_path:' || p_file_path);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Fie Path from VS:' || lv_vs_file_path);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Fie Name from VS:' || lv_vs_file_name);

            IF     lv_vs_file_name IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
            THEN
                IF lv_vs_file_path IS NOT NULL
                THEN
                    lv_file_path   := lv_vs_file_path;
                ELSE
                    BEGIN
                        SELECT ffvl.description
                          INTO lv_vs_default_file_path
                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                         WHERE     fvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND fvs.flex_value_set_name =
                                   'XXD_AAR_GL_BL_FILE_PATH_VS'
                               AND NVL (TRUNC (ffvl.start_date_active),
                                        TRUNC (SYSDATE)) <=
                                   TRUNC (SYSDATE)
                               AND NVL (TRUNC (ffvl.end_date_active),
                                        TRUNC (SYSDATE)) >=
                                   TRUNC (SYSDATE)
                               AND ffvl.enabled_flag = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_vs_default_file_path   := NULL;
                    END;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Default Fie Path from VS:'
                        || lv_vs_default_file_path);
                    lv_file_path   := lv_vs_default_file_path;
                END IF;

                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    || lv_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';
                -- WRITE INTO BL FOLDER
                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN write_givr_extract
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the givr extract data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            END IF;
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
    END write_givr_file;

    --3.2 changes end

    --Start changes v1.1
    --update_valueset_prc procedure
    PROCEDURE update_valueset_prc (p_file_path IN VARCHAR2)
    IS
        lv_user_name      VARCHAR2 (100);
        lv_request_info   VARCHAR2 (100);
        ln_request_id     NUMBER := fnd_global.conc_request_id;
    BEGIN
        lv_user_name      := NULL;
        lv_request_info   := NULL;

        BEGIN
            SELECT fu.user_name, TO_CHAR (fcr.actual_start_date, 'MM/DD/RRRR HH24:MI:SS')
              INTO lv_user_name, lv_request_info
              FROM apps.fnd_concurrent_requests fcr, apps.fnd_user fu
             WHERE request_id = ln_request_id AND requested_by = fu.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_name      := NULL;
                lv_request_info   := NULL;
        END;

        BEGIN
            UPDATE apps.fnd_flex_values_vl ffvl
               SET ffvl.attribute5 = lv_user_name, ffvl.attribute6 = lv_request_info
             WHERE     NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.description = 'GIVR'
                   AND ffvl.flex_value = p_file_path
                   AND ffvl.flex_value_set_id IN
                           (SELECT flex_value_set_id
                              FROM apps.fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'XXD_GL_AAR_FILE_DETAILS_VS');

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Value set updation has failed: ' || SQLERRM);
        END;
    END update_valueset_prc;

    --End changes v1.1

    PROCEDURE run_cir_report (
        psqlstat                      OUT VARCHAR2,
        perrproc                      OUT VARCHAR2,
        p_retrieve_from            IN     VARCHAR2,
        p_inv_org_id               IN     NUMBER,
        p_region                   IN     VARCHAR2,
        p_as_of_date               IN     VARCHAR2,
        p_brand                    IN     VARCHAR2,
        p_master_inv_org_id        IN     NUMBER,
        p_xfer_price_list_id       IN     NUMBER,
        p_duty_override            IN     NUMBER := 0,
        p_summary                  IN     VARCHAR2,
        p_include_analysis         IN     VARCHAR2,
        p_use_accrual_vals         IN     VARCHAR2 := 'Y',
        p_from_currency            IN     VARCHAR2,
        p_elimination_rate_type    IN     VARCHAR2,
        p_elimination_rate         IN     VARCHAR2,
        p_dummy_elimination_rate   IN     VARCHAR2,
        p_user_rate                IN     NUMBER,
        p_tq_japan                 IN     VARCHAR2,
        p_dummy_tq                 IN     VARCHAR2,
        p_markup_rate_type         IN     VARCHAR2,
        p_jpy_user_rate            IN     NUMBER,
        p_debug_level              IN     NUMBER := NULL,
        p_layered_mrgn             IN     VARCHAR2,
        p_report_type              IN     VARCHAR2,                     -- 3.2
        p_file_path                IN     VARCHAR2                       --3.2
                                                  )
    IS
        v_request_id       NUMBER;
        v_phase            VARCHAR2 (240);
        v_status           VARCHAR2 (240);
        v_request_phase    VARCHAR2 (240);
        v_request_status   VARCHAR2 (240);
        v_finished         BOOLEAN;
        v_message          VARCHAR2 (240);
        v_sub_status       BOOLEAN := FALSE;
        lv_file_name       VARCHAR2 (360);
        lv_errbuff         VARCHAR2 (240);
        lv_retcode         VARCHAR2 (10);
    BEGIN
        BEGIN
            v_request_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXDOINV_CONSOL_INV_EXTRACT',
                    description   => NULL,
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => p_retrieve_from,
                    argument2     => p_inv_org_id,
                    argument3     => p_region,
                    argument4     => p_as_of_date,
                    argument5     => p_brand,
                    argument6     => p_master_inv_org_id,
                    argument7     => p_xfer_price_list_id,
                    argument8     => p_duty_override,
                    argument9     => p_summary,
                    argument10    => p_include_analysis,
                    argument11    => p_use_accrual_vals,
                    argument12    => p_from_Currency,
                    argument13    => p_elimination_rate_type,
                    argument14    => p_elimination_rate,
                    argument15    => p_dummy_elimination_rate,
                    argument16    => p_user_rate,
                    argument17    => p_TQ_Japan,
                    argument18    => p_dummy_tq,
                    argument19    => p_markup_rate_type,
                    argument20    => p_jpy_user_rate,
                    argument21    => p_debug_level,
                    argument22    => p_layered_mrgn,
                    argument23    => p_report_type,
                    argument24    => p_file_path);

            COMMIT;
        END;

        IF (v_request_id = 0)
        THEN
            DBMS_OUTPUT.put_line ('GIVR Program Not Submitted');
            v_sub_status   := FALSE;
        ELSE
            v_finished   :=
                fnd_concurrent.wait_for_request (
                    request_id   => v_request_id,
                    INTERVAL     => 0,
                    max_wait     => 0,
                    phase        => v_phase,
                    status       => v_status,
                    dev_phase    => v_request_phase,
                    dev_status   => v_request_status,
                    MESSAGE      => v_message);

            DBMS_OUTPUT.put_line ('Request Phase  : ' || v_request_phase);
            DBMS_OUTPUT.put_line ('Request Status : ' || v_request_status);
            DBMS_OUTPUT.put_line ('Request id     : ' || v_request_id);
        END IF;

        -- calling procedure to write GIVR file
        write_givr_file (p_file_path, lv_file_name, v_request_id,
                         lv_retcode, lv_errbuff);

        --Start changes v1.1
        update_valueset_prc (p_file_path);
        fnd_file.put_line (fnd_file.LOG, 'Value set updated');
    --End changes v1.1

    END run_cir_report;
END XXD_INV_VALUE_EXTRACT_PKG;
/
