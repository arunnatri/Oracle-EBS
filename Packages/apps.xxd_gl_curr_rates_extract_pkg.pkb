--
-- XXD_GL_CURR_RATES_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_CURR_RATES_EXTRACT_PKG"
AS
         /****************************************************************************************
* Package      : XXD_GL_CURR_RATES_EXTRACT_PKG
* Design       : This package will be used to fetch the daily rates from base table and send to blackline
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 29-Mar-2021  1.0        Showkath Ali            Initial Version
         -- 02-Feb-2023  1.1        SHowkath Ali            CCR00 - File name change
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

    PROCEDURE write_extract_file (p_currency IN VARCHAR2, p_rate_type IN VARCHAR2, p_rate_date IN VARCHAR2, p_period_end_date IN VARCHAR2, p_conversion_method IN VARCHAR2, p_file_path IN VARCHAR2
                                  , p_file_name IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_currency_extract (p_conv_method IN VARCHAR2)
        IS
            SELECT DECODE (p_conversion_method,  'From Currency', to_currency,  'To Currency', from_currency) || CHR (9) || conversion_rate || CHR (9) || TO_CHAR (TO_DATE (p_period_end_date, 'YYYY/MM/DD HH24:MI:SS'), 'MM/DD/YYYY') || CHR (9) || p_conv_method line
              FROM gl_daily_rates a
             WHERE     conversion_type = p_rate_type
                   AND (conversion_date) =
                       TO_DATE (p_rate_date, 'YYYY/MM/DD HH24:MI:SS')
                   AND ((p_conversion_method = 'From Currency' AND from_currency = p_currency) OR (p_conversion_method = 'To Currency' AND to_currency = p_currency));

        --DEFINE VARIABLES

        lv_file_path       VARCHAR2 (360) := p_file_path;
        lv_output_file     UTL_FILE.file_type;
        lv_outbound_file   VARCHAR2 (360) := p_file_name;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
        lv_conv_method     VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT ffvl.description
              INTO lv_conv_method
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_GL_CONV_METHOD_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value = p_conversion_method;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_conv_method   := NULL;
        END;

        IF lv_file_path IS NULL
        THEN                                            -- WRITE INTO FND LOGS
            FOR i IN write_currency_extract (lv_conv_method)
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
                FOR i IN write_currency_extract (lv_conv_method)
                LOOP
                    lv_line   := i.line;
                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the currency conv data file for writing. Error is : '
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

    PROCEDURE main (p_errbuf                 OUT VARCHAR2,
                    p_retcode                OUT NUMBER,
                    p_currency            IN     VARCHAR2,
                    p_rate_type           IN     VARCHAR2,
                    p_rate_date           IN     VARCHAR2,
                    p_period_end_date     IN     VARCHAR2,
                    p_conversion_method   IN     VARCHAR2,
                    p_file_path           IN     VARCHAR2)
    AS
        lv_outbound_cur_file   VARCHAR2 (360)
            := 'CurrencyRates_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        --l_file_name              VARCHAR2(360):='Currency_'|| TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')||'.txt';
        l_file_name            VARCHAR2 (360)
            :=    'CurrencyRates_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';                                               -- 1.1

        lv_ret_code            VARCHAR2 (30) := NULL;
        lv_ret_message         VARCHAR2 (2000) := NULL;
        lb_file_exists         BOOLEAN;
        ln_file_length         NUMBER := NULL;
        ln_block_size          NUMBER := NULL;
    BEGIN
        -- Printing all the parameters
        fnd_file.put_line (
            fnd_file.LOG,
            'Deckers GL Currency Conv Rate extract Program.....');
        fnd_file.put_line (fnd_file.LOG, 'Parameters Are.....');
        fnd_file.put_line (fnd_file.LOG, '-------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'p_currency 					    :' || p_currency);
        fnd_file.put_line (fnd_file.LOG,
                           'p_rate_type 					    :' || p_rate_type);
        fnd_file.put_line (fnd_file.LOG,
                           'p_rate_date 						:' || p_rate_date);
        fnd_file.put_line (fnd_file.LOG,
                           'p_period_end_date				    :' || p_period_end_date);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_conversion_method   			    :' || p_conversion_method);
        fnd_file.put_line (fnd_file.LOG,
                           'p_file_path					    :' || p_file_path);
        --  call procedure to write the data in file at the given location or if file name is not given then write into the log

        write_extract_file (p_currency, p_rate_type, p_rate_date,
                            p_period_end_date, p_conversion_method, p_file_path
                            , l_file_name, lv_ret_code, lv_ret_message);

        IF p_file_path IS NOT NULL
        THEN
            IF lv_ret_code = gn_error
            THEN
                p_retcode   := gn_error;
                p_errbuf    :=
                    'After write into currency rates - ' || lv_ret_message;
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
                    'Currency rates are successfully created in the directory.');
                lv_ret_code      := NULL;
                lv_ret_message   := NULL;
            ELSE
                --If lb_file_exists is FALSE then do the below
                lv_ret_message   :=
                    SUBSTR (
                        'Currency rates file creation is not successful, Please check the issue.',
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_ret_message);
                --Complete the program in error
                p_retcode   := gn_error;
                p_errbuf    := lv_ret_message;
            END IF;
        END IF;
    END MAIN;
END XXD_GL_CURR_RATES_EXTRACT_PKG;
/
